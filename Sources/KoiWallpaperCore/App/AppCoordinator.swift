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
    public private(set) var desktopWindowController: DesktopWindowController?
    public private(set) var statusBarController: StatusBarController?

    public init(
        settingsManager: SettingsManager = SettingsManager(),
        lifecyclePolicy: LifecyclePolicy? = nil,
        inputCoordinator: InputCoordinator? = nil,
        timeOfDayController: TimeOfDayController? = nil
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

        super.init()

        self.lifecyclePolicy.delegate = self
        self.inputCoordinator.delegate = self
        self.timeOfDayController.onPhaseChanged = { [weak self] newPhase in
            self?.handlePhaseChanged(newPhase)
        }
    }

    public func start() {
        logger.info("Starting KoiWallpaper M2 Usable Desktop Wallpaper...")

        guard let screen = NSScreen.main ?? NSScreen.screens.first else {
            logger.error("No active NSScreen found.")
            return
        }

        // Initialize desktop window controller and wallpaper view
        let windowController = DesktopWindowController(screen: screen)
        windowController.wallpaperView.inputCoordinator = inputCoordinator
        windowController.wallpaperView.timeOfDayPhase = timeOfDayController.currentPhase
        windowController.wallpaperView.showHUD = settingsManager.settings.showHUD
        windowController.applyInteractionMode(inputCoordinator.currentMode)
        windowController.show()
        self.desktopWindowController = windowController

        // Bind window to lifecycle policy
        lifecyclePolicy.bindWindow(windowController.window)
        windowController.wallpaperView.isPaused = lifecyclePolicy.isPaused
        if !lifecyclePolicy.isPaused {
            windowController.wallpaperView.startAnimationTimer()
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

        logger.info("KoiWallpaper M2 started successfully on screen \(screen.frame.size.width)x\(screen.frame.size.height) with phase \(self.timeOfDayController.currentPhase.rawValue).")
    }

    private func handlePhaseChanged(_ newPhase: TimeOfDayPhase) {
        desktopWindowController?.wallpaperView.timeOfDayPhase = newPhase
        statusBarController?.updateTimeOfDayState(
            mode: settingsManager.settings.timeOfDayMode,
            manualPhase: settingsManager.settings.manualTimePhase,
            currentPhase: newPhase
        )
    }

    // MARK: - LifecyclePolicyDelegate

    public func lifecyclePolicy(_ policy: LifecyclePolicy, didUpdatePauseReasons reasons: Set<PauseReason>, isPaused: Bool) {
        logger.info("Lifecycle pause state updated. isPaused: \(isPaused), reasons: \(reasons.map(\.rawValue).joined(separator: ", "))")
        desktopWindowController?.wallpaperView.isPaused = isPaused
        statusBarController?.updatePauseState(isPaused: isPaused, reasons: reasons)
    }

    public func lifecyclePolicyDidRequestScreenReconfiguration(_ policy: LifecyclePolicy) {
        logger.info("Screen reconfiguration requested.")
        desktopWindowController?.updateScreenConfiguration()
    }

    // MARK: - InputCoordinatorDelegate

    public func inputCoordinator(_ coordinator: InputCoordinator, didChangeMode mode: InputInteractionMode) {
        logger.info("Input mode changed to: \(mode.rawValue)")
        desktopWindowController?.applyInteractionMode(mode)
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
        desktopWindowController?.wallpaperView.showHUD = newShowHUD
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
        desktopWindowController?.wallpaperView.showHUD = defaults.showHUD

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

    public func statusBarDidRequestQuit(_ controller: StatusBarController) {
        logger.info("User requested quit. Terminating application.")
        NSApplication.shared.terminate(nil)
    }
}
