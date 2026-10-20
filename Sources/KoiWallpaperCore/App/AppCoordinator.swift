import AppKit
import OSLog

private let logger = Logger(subsystem: "com.koiwallpaper.KoiWallpaper", category: "Coordinator")

public final class AppCoordinator: NSObject,
                                    LifecyclePolicyDelegate,
                                    InputCoordinatorDelegate,
                                    StatusBarControllerDelegate {

    public let settingsManager: SettingsManager
    public let lifecyclePolicy: LifecyclePolicy
    public let inputCoordinator: InputCoordinator
    public let timeOfDayController: TimeOfDayController
    public let screenManager: ScreenManager

    public var desktopWindowController: DesktopWindowController? {
        screenManager.primaryController
    }

    public var desktopWindowControllers: [DesktopWindowController] {
        screenManager.controllers
    }

    public private(set) var statusBarController: StatusBarController?

    public init(
        settingsManager: SettingsManager = SettingsManager(),
        lifecyclePolicy: LifecyclePolicy? = nil,
        inputCoordinator: InputCoordinator? = nil,
        timeOfDayController: TimeOfDayController? = nil,
        screenManager: ScreenManager? = nil
    ) {
        self.settingsManager = settingsManager

        let loadedSettings = settingsManager.settings
        let policy = lifecyclePolicy ?? LifecyclePolicy()
        policy.pauseOnBattery = loadedSettings.pauseOnBattery
        if loadedSettings.isManualPaused {
            policy.setManualPause(true)
        }
        self.lifecyclePolicy = policy

        let input = inputCoordinator ?? InputCoordinator(initialMode: loadedSettings.initialInteractionMode)
        self.inputCoordinator = input

        let tod = timeOfDayController ?? TimeOfDayController(
            mode: loadedSettings.timeOfDayMode,
            manualPhase: loadedSettings.manualTimePhase
        )
        self.timeOfDayController = tod

        let scrMgr = screenManager ?? ScreenManager(
            inputCoordinator: input,
            timeOfDayPhase: tod.currentPhase,
            showHUD: loadedSettings.showHUD,
            isGloballyPaused: policy.isPaused
        )
        self.screenManager = scrMgr

        super.init()

        self.lifecyclePolicy.delegate = self
        self.inputCoordinator.delegate = self
        self.timeOfDayController.onPhaseChanged = { [weak self] newPhase in
            self?.handlePhaseChanged(newPhase)
        }
    }

    public func start() {
        logger.info("Starting KoiWallpaper M3 Multi-Monitor Desktop Wallpaper...")

        // Configure screen manager with loaded preferences
        screenManager.applyInteractionMode(inputCoordinator.currentMode)
        screenManager.applyTimeOfDayPhase(timeOfDayController.currentPhase)
        screenManager.applyHUDVisibility(settingsManager.settings.showHUD)
        screenManager.applyGlobalPause(lifecyclePolicy.isPaused)

        // Bind all active host windows to lifecycle policy for occlusion tracking
        for controller in screenManager.controllers {
            lifecyclePolicy.bindWindow(controller.window)
        }

        screenManager.onControllersChanged = { [weak self] controllers in
            guard let self = self else { return }
            for controller in controllers {
                self.lifecyclePolicy.bindWindow(controller.window)
            }
        }

        screenManager.onControllerRemoved = { [weak self] controller in
            self?.lifecyclePolicy.unbindWindow(controller.window)
        }

        screenManager.onOcclusionChanged = { [weak self] controller in
            guard self != nil else { return }
            logger.info("Screen occlusion changed on display \(controller.displayID ?? 0): isOccluded=\(controller.isOccluded)")
        }

        // Start time of day progression monitoring
        timeOfDayController.startMonitoring()

        // Initialize menu bar status item
        let statusController = StatusBarController()
        statusController.delegate = self
        statusController.updateInteractionMode(inputCoordinator.currentMode)
        statusController.updatePauseState(
            isPaused: lifecyclePolicy.isPaused,
            reasons: lifecyclePolicy.activePauseReasons
        )
        statusController.updateTimeOfDayState(
            mode: settingsManager.settings.timeOfDayMode,
            manualPhase: settingsManager.settings.manualTimePhase,
            currentPhase: timeOfDayController.currentPhase
        )
        statusController.updateSettingsState(
            pauseOnBattery: settingsManager.settings.pauseOnBattery,
            showHUD: settingsManager.settings.showHUD
        )
        self.statusBarController = statusController

        logger.info("KoiWallpaper M3 started successfully across \(self.screenManager.screenCount) screen(s).")
    }

    private func handlePhaseChanged(_ newPhase: TimeOfDayPhase) {
        screenManager.applyTimeOfDayPhase(newPhase)
        statusBarController?.updateTimeOfDayState(
            mode: settingsManager.settings.timeOfDayMode,
            manualPhase: settingsManager.settings.manualTimePhase,
            currentPhase: newPhase
        )
    }

    // MARK: - LifecyclePolicyDelegate

    public func lifecyclePolicy(_ policy: LifecyclePolicy, didUpdatePauseReasons reasons: Set<PauseReason>, isPaused: Bool) {
        logger.info("Lifecycle pause state updated. isPaused: \(isPaused), reasons: \(reasons.map(\.rawValue).joined(separator: ", "))")
        screenManager.applyGlobalPause(isPaused)
        statusBarController?.updatePauseState(isPaused: isPaused, reasons: reasons)
    }

    public func lifecyclePolicyDidRequestScreenReconfiguration(_ policy: LifecyclePolicy) {
        logger.info("Screen reconfiguration requested.")
        screenManager.reconfigureScreens()
    }

    // MARK: - InputCoordinatorDelegate

    public func inputCoordinator(_ coordinator: InputCoordinator, didChangeMode mode: InputInteractionMode) {
        logger.info("Input mode changed to: \(mode.rawValue)")
        screenManager.applyInteractionMode(mode)
        statusBarController?.updateInteractionMode(mode)
    }

    public func inputCoordinator(_ coordinator: InputCoordinator, didReceiveClickAt point: CGPoint, isOptionClick: Bool) {
        logger.info("Input received in interactive mode at (\(point.x), \(point.y)), isOptionClick: \(isOptionClick)")
    }

    // MARK: - StatusBarControllerDelegate

    public func statusBarDidToggleInteractionMode(_ controller: StatusBarController) {
        inputCoordinator.toggleMode()
    }

    public func statusBarDidToggleManualPause(_ controller: StatusBarController) {
        let isManualPaused = lifecyclePolicy.activePauseReasons.contains(.manual)
        let newManualPaused = !isManualPaused
        lifecyclePolicy.setManualPause(newManualPaused)
        settingsManager.updateSettings { $0.isManualPaused = newManualPaused }
    }

    public func statusBarDidSelectTimeOfDayMode(_ controller: StatusBarController, mode: TimeOfDayMode) {
        logger.info("User selected Time of Day mode: \(mode.rawValue)")
        settingsManager.updateSettings { $0.timeOfDayMode = mode }
        timeOfDayController.setMode(mode)
        statusBarController?.updateTimeOfDayState(
            mode: mode,
            manualPhase: settingsManager.settings.manualTimePhase,
            currentPhase: timeOfDayController.currentPhase
        )
    }

    public func statusBarDidSelectManualTimePhase(_ controller: StatusBarController, phase: TimeOfDayPhase) {
        logger.info("User selected manual Time of Day phase: \(phase.rawValue)")
        settingsManager.updateSettings {
            $0.timeOfDayMode = .manual
            $0.manualTimePhase = phase
        }
        timeOfDayController.setMode(.manual)
        timeOfDayController.setManualPhase(phase)
        statusBarController?.updateTimeOfDayState(
            mode: .manual,
            manualPhase: phase,
            currentPhase: timeOfDayController.currentPhase
        )
    }

    public func statusBarDidTogglePauseOnBattery(_ controller: StatusBarController) {
        let newPauseOnBattery = !settingsManager.settings.pauseOnBattery
        logger.info("User toggled pauseOnBattery to: \(newPauseOnBattery)")
        settingsManager.updateSettings { $0.pauseOnBattery = newPauseOnBattery }
        lifecyclePolicy.pauseOnBattery = newPauseOnBattery
        statusBarController?.updateSettingsState(
            pauseOnBattery: newPauseOnBattery,
            showHUD: settingsManager.settings.showHUD
        )
    }

    public func statusBarDidToggleHUD(_ controller: StatusBarController) {
        let newShowHUD = !settingsManager.settings.showHUD
        logger.info("User toggled showHUD to: \(newShowHUD)")
        settingsManager.updateSettings { $0.showHUD = newShowHUD }
        screenManager.applyHUDVisibility(newShowHUD)
        statusBarController?.updateSettingsState(
            pauseOnBattery: settingsManager.settings.pauseOnBattery,
            showHUD: newShowHUD
        )
    }

    public func statusBarDidResetSettings(_ controller: StatusBarController) {
        logger.info("User reset settings to defaults.")
        settingsManager.resetToDefaults()
        let defaults = settingsManager.settings

        lifecyclePolicy.pauseOnBattery = defaults.pauseOnBattery
        lifecyclePolicy.setManualPause(defaults.isManualPaused)
        inputCoordinator.setMode(defaults.initialInteractionMode)
        timeOfDayController.setMode(defaults.timeOfDayMode)
        timeOfDayController.setManualPhase(defaults.manualTimePhase)

        screenManager.applyHUDVisibility(defaults.showHUD)
        screenManager.applyInteractionMode(defaults.initialInteractionMode)
        screenManager.applyTimeOfDayPhase(timeOfDayController.currentPhase)

        statusBarController?.updateInteractionMode(defaults.initialInteractionMode)
        statusBarController?.updateTimeOfDayState(
            mode: defaults.timeOfDayMode,
            manualPhase: defaults.manualTimePhase,
            currentPhase: timeOfDayController.currentPhase
        )
        statusBarController?.updateSettingsState(
            pauseOnBattery: defaults.pauseOnBattery,
            showHUD: defaults.showHUD
        )
    }

    /// Cleanly tears down screen managers, unbinds window observers from lifecycle policy, and stops timers.
    public func teardown() {
        timeOfDayController.stopMonitoring()
        for controller in screenManager.controllers {
            lifecyclePolicy.unbindWindow(controller.window)
        }
        screenManager.teardown()
    }

    public func statusBarDidRequestQuit(_ controller: StatusBarController) {
        logger.info("User requested quit. Terminating application.")
        NSApplication.shared.terminate(nil)
    }
}
