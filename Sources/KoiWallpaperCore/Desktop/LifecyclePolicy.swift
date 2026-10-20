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

    private var observers: [NSObjectProtocol] = []
    private weak var observedWindow: NSWindow?

    public init(powerMonitor: PowerSourceMonitoring = IOKitPowerSourceMonitor()) {
        self.powerMonitor = powerMonitor
        setupSystemObservers()
        setupPowerMonitoring()
    }

    deinit {
        powerMonitor.stopMonitoring()
        for observer in observers {
            NotificationCenter.default.removeObserver(observer)
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
    }

    public func bindWindow(_ window: NSWindow) {
        self.observedWindow = window

        // If the window is already composited and visible, evaluate occlusion immediately.
        // If Window Server has not yet reported occlusion (during initial launch), do not
        // falsely pause before the first didChangeOcclusionStateNotification arrives.
        if window.isVisible && window.occlusionState.contains(.visible) {
            activePauseReasons.remove(.covered)
        }

        let obs = NotificationCenter.default.addObserver(
            forName: NSWindow.didChangeOcclusionStateNotification,
            object: window,
            queue: .main
        ) { [weak self, weak window] _ in
            guard let self = self, let window = window else { return }
            self.evaluateWindowOcclusion(window)
        }
        observers.append(obs)
    }

    public func setManualPause(_ pause: Bool) {
        if pause {
            activePauseReasons.insert(.manual)
        } else {
            activePauseReasons.remove(.manual)
        }
    }

    public func evaluateWindowOcclusion(_ window: NSWindow) {
        guard window.isVisible else {
            activePauseReasons.insert(.covered)
            return
        }

        let isVisibleOnScreen = window.occlusionState.contains(.visible)
        if isVisibleOnScreen {
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

        if powerMonitor.isRunningOnBattery {
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

        // Screen sleep / wake
        observers.append(workspaceCenter.addObserver(
            forName: NSWorkspace.screensDidSleepNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.activePauseReasons.insert(.displaySleep)
        })

        observers.append(workspaceCenter.addObserver(
            forName: NSWorkspace.screensDidWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.activePauseReasons.remove(.displaySleep)
        })

        // System sleep / wake
        observers.append(workspaceCenter.addObserver(
            forName: NSWorkspace.willSleepNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.activePauseReasons.insert(.systemSleep)
        })

        observers.append(workspaceCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.activePauseReasons.remove(.systemSleep)
        })

        // User session active / inactive (lock screen, fast user switching)
        observers.append(workspaceCenter.addObserver(
            forName: NSWorkspace.sessionDidResignActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.activePauseReasons.insert(.sessionInactive)
        })

        observers.append(workspaceCenter.addObserver(
            forName: NSWorkspace.sessionDidBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.activePauseReasons.remove(.sessionInactive)
        })

        // Display configuration / screen parameter change
        observers.append(NotificationCenter.default.addObserver(
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
