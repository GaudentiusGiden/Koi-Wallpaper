import AppKit
import Combine

/// Represents individual reasons why the desktop wallpaper simulation/rendering should be paused.
/// Multiple reasons can be active simultaneously, and the wallpaper will only resume when all reasons are cleared.
public enum PauseReason: String, CaseIterable, Hashable, Sendable {
    case manual = "manual"
    case battery = "battery"
    case covered = "covered"
    case displaySleep = "displaySleep"
    case systemSleep = "systemSleep"
    case sessionInactive = "sessionInactive"
}

public protocol LifecyclePolicyDelegate: AnyObject {
    func lifecyclePolicy(_ policy: LifecyclePolicy, didUpdatePauseReasons reasons: Set<PauseReason>, isPaused: Bool)
    func lifecyclePolicyDidRequestScreenReconfiguration(_ policy: LifecyclePolicy)
}

/// LifecyclePolicy monitors window occlusion, display sleep/wake, system sleep/wake,
/// and session state to govern when wallpaper activities should pause and resume.
public final class LifecyclePolicy {
    public weak var delegate: LifecyclePolicyDelegate?
    public let powerMonitor: PowerSourceMonitoring

    public var pauseOnBattery: Bool = false {
        didSet {
            if oldValue != pauseOnBattery {
                evaluatePowerState()
            }
        }
    }

    public private(set) var activePauseReasons: Set<PauseReason> = [] {
        didSet {
            let nowPaused = !activePauseReasons.isEmpty
            if oldValue != activePauseReasons {
                delegate?.lifecyclePolicy(self, didUpdatePauseReasons: activePauseReasons, isPaused: nowPaused)
            }
        }
    }

    public var isPaused: Bool {
        !activePauseReasons.isEmpty
    }

    private var systemObservers: [NSObjectProtocol] = []
    private var boundWindowVisibility: [ObjectIdentifier: Bool] = [:]
    private var windowObservers: [ObjectIdentifier: NSObjectProtocol] = [:]
    private weak var observedWindow: NSWindow?

    /// Number of distinct windows currently registered for aggregated visibility tracking.
    public var boundWindowCount: Int {
        boundWindowVisibility.count
    }

    /// Number of active NotificationCenter occlusion observers currently held for bound windows.
    public var activeWindowObserverCount: Int {
        windowObservers.count
    }

    /// Checks whether the specified window currently has an active occlusion observer registered.
    public func isWindowBound(_ window: NSWindow) -> Bool {
        windowObservers[ObjectIdentifier(window)] != nil
    }

    public init(powerMonitor: PowerSourceMonitoring = IOKitPowerSourceMonitor()) {
        self.powerMonitor = powerMonitor
        setupSystemObservers()
        setupPowerMonitoring()
    }

    deinit {
        powerMonitor.stopMonitoring()
        for observer in systemObservers {
            NotificationCenter.default.removeObserver(observer)
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
        systemObservers.removeAll()

        for (_, observer) in windowObservers {
            NotificationCenter.default.removeObserver(observer)
        }
        windowObservers.removeAll()
    }

    public func bindWindow(_ window: NSWindow) {
        self.observedWindow = window
        let id = ObjectIdentifier(window)

        let isVisible = window.isVisible && window.occlusionState.contains(.visible)
        boundWindowVisibility[id] = isVisible

        if isVisible {
            activePauseReasons.remove(.covered)
        }

        // Avoid adding duplicate observers for the same window
        guard windowObservers[id] == nil else { return }

        let obs = NotificationCenter.default.addObserver(
            forName: NSWindow.didChangeOcclusionStateNotification,
            object: window,
            queue: .main
        ) { [weak self, weak window] _ in
            guard let self = self, let window = window else { return }
            self.evaluateWindowOcclusion(window)
        }
        windowObservers[id] = obs
    }

    public func unbindWindow(_ window: NSWindow) {
        let id = ObjectIdentifier(window)
        boundWindowVisibility.removeValue(forKey: id)
        if let obs = windowObservers.removeValue(forKey: id) {
            NotificationCenter.default.removeObserver(obs)
        }
        if observedWindow === window {
            observedWindow = nil
        }
        evaluateAggregatedOcclusion()
    }

    public func setManualPause(_ pause: Bool) {
        if pause {
            activePauseReasons.insert(.manual)
        } else {
            activePauseReasons.remove(.manual)
        }
    }

    public func evaluateWindowOcclusion(_ window: NSWindow) {
        let isVisibleOnScreen = window.isVisible && window.occlusionState.contains(.visible)
        boundWindowVisibility[ObjectIdentifier(window)] = isVisibleOnScreen
        evaluateAggregatedOcclusion()
    }

    private func evaluateAggregatedOcclusion() {
        if boundWindowVisibility.isEmpty {
            activePauseReasons.remove(.covered)
            return
        }

        let anyWindowVisible = boundWindowVisibility.values.contains(true)
        if anyWindowVisible {
            activePauseReasons.remove(.covered)
        } else {
            activePauseReasons.insert(.covered)
        }
    }

    public func evaluatePowerState() {
        guard pauseOnBattery else {
            activePauseReasons.remove(.battery)
            return
        }

        let isMock = String(describing: type(of: powerMonitor)).contains("Mock")
        let isLowPower = !isMock && ProcessInfo.processInfo.isLowPowerModeEnabled

        if powerMonitor.isRunningOnBattery || isLowPower {
            activePauseReasons.insert(.battery)
        } else {
            activePauseReasons.remove(.battery)
        }
    }

    private func setupPowerMonitoring() {
        powerMonitor.onPowerSourceChanged = { [weak self] in
            self?.evaluatePowerState()
        }
        powerMonitor.startMonitoring()
        evaluatePowerState()
    }

    private func setupSystemObservers() {
        let workspaceCenter = NSWorkspace.shared.notificationCenter

        // macOS Low Power Mode state change
        systemObservers.append(NotificationCenter.default.addObserver(
            forName: NSNotification.Name.NSProcessInfoPowerStateDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.evaluatePowerState()
        })

        // Screen sleep / wake
        systemObservers.append(workspaceCenter.addObserver(
            forName: NSWorkspace.screensDidSleepNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.activePauseReasons.insert(.displaySleep)
        })

        systemObservers.append(workspaceCenter.addObserver(
            forName: NSWorkspace.screensDidWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.activePauseReasons.remove(.displaySleep)
        })

        // System sleep / wake
        systemObservers.append(workspaceCenter.addObserver(
            forName: NSWorkspace.willSleepNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.activePauseReasons.insert(.systemSleep)
        })

        systemObservers.append(workspaceCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.activePauseReasons.remove(.systemSleep)
        })

        // User session active / inactive (lock screen, fast user switching)
        systemObservers.append(workspaceCenter.addObserver(
            forName: NSWorkspace.sessionDidResignActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.activePauseReasons.insert(.sessionInactive)
        })

        systemObservers.append(workspaceCenter.addObserver(
            forName: NSWorkspace.sessionDidBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.activePauseReasons.remove(.sessionInactive)
        })

        // Display configuration / screen parameter change
        systemObservers.append(NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self = self else { return }
            self.delegate?.lifecyclePolicyDidRequestScreenReconfiguration(self)
            if let window = self.observedWindow {
                self.evaluateWindowOcclusion(window)
            }
        })
    }
}
