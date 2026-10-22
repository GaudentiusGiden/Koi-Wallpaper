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
            manualPhase: loadedSettings.manualTimePhase,
            manualTheme: loadedSettings.manualTheme
        )
        self.timeOfDayController = tod

        let scrMgr = screenManager ?? ScreenManager(
            inputCoordinator: input,
            timeOfDayPhase: tod.currentPhase,
            theme: tod.currentTheme,
            showHUD: loadedSettings.showHUD,
            isGloballyPaused: policy.isPaused
        )
        self.screenManager = scrMgr

        super.init()

        self.lifecyclePolicy.delegate = self
        self.inputCoordinator.delegate = self
        self.timeOfDayController.onThemeChanged = { [weak self] newTheme in
            self?.handleThemeChanged(newTheme)
        }
    }

    public func start() {
        logger.info("Starting KoiWallpaper M3 Multi-Monitor Desktop Wallpaper...")

        // Configure screen manager with loaded preferences
        screenManager.applyInteractionMode(inputCoordinator.currentMode)
        screenManager.applyTheme(timeOfDayController.currentTheme)
        screenManager.applyHUDVisibility(settingsManager.settings.showHUD)
        screenManager.applyMood(settingsManager.settings.pondMood)
        screenManager.applyRain(settingsManager.settings.isRainActive)
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
        statusController.updateThemeState(
            mode: settingsManager.settings.timeOfDayMode,
            manualTheme: settingsManager.settings.manualTheme,
            currentTheme: timeOfDayController.currentTheme
        )
        statusController.updateSettingsState(
            pauseOnBattery: settingsManager.settings.pauseOnBattery,
            showHUD: settingsManager.settings.showHUD
        )
        statusController.updateMoodState(mood: settingsManager.settings.pondMood)
        statusController.updateRainState(isRainActive: settingsManager.settings.isRainActive)
        self.statusBarController = statusController

        logger.info("KoiWallpaper M4 started successfully across \(self.screenManager.screenCount) screen(s).")
    }

    private func handleThemeChanged(_ newTheme: PondTheme) {
        screenManager.applyTheme(newTheme)
        statusBarController?.updateThemeState(
            mode: settingsManager.settings.timeOfDayMode,
            manualTheme: settingsManager.settings.manualTheme,
            currentTheme: newTheme
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
        let previousTheme = timeOfDayController.currentTheme
        settingsManager.updateSettings { $0.timeOfDayMode = mode }
        timeOfDayController.setMode(mode)
        if previousTheme == timeOfDayController.currentTheme {
            statusBarController?.updateThemeState(
                mode: mode,
                manualTheme: settingsManager.settings.manualTheme,
                currentTheme: timeOfDayController.currentTheme
            )
        }
    }

    public func statusBarDidSelectManualTheme(_ controller: StatusBarController, theme: PondTheme) {
        logger.info("User selected manual theme: \(theme.rawValue)")
        let previousTheme = timeOfDayController.currentTheme
        settingsManager.updateSettings {
            $0.timeOfDayMode = .manual
            $0.manualTheme = theme
            if let phase = theme.asTimePhase {
                $0.manualTimePhase = phase
            }
        }
        timeOfDayController.selectManualTheme(theme)
        if previousTheme == timeOfDayController.currentTheme {
            statusBarController?.updateThemeState(
                mode: .manual,
                manualTheme: theme,
                currentTheme: timeOfDayController.currentTheme
            )
        }
    }

    public func statusBarDidSelectManualTimePhase(_ controller: StatusBarController, phase: TimeOfDayPhase) {
        statusBarDidSelectManualTheme(controller, theme: phase.theme)
    }

    public func statusBarDidSelectMood(_ controller: StatusBarController, mood: PondMood) {
        logger.info("User selected mood: \(mood.rawValue)")
        settingsManager.updateSettings { $0.pondMood = mood }
        screenManager.applyMood(mood)
        statusBarController?.updateMoodState(mood: mood)
    }

    public func statusBarDidToggleRain(_ controller: StatusBarController) {
        let newRain = !settingsManager.settings.isRainActive
        logger.info("User toggled rain effect to: \(newRain)")
        settingsManager.updateSettings { $0.isRainActive = newRain }
        screenManager.applyRain(newRain)
        statusBarController?.updateRainState(isRainActive: newRain)
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
        let previousTheme = timeOfDayController.currentTheme

        lifecyclePolicy.pauseOnBattery = defaults.pauseOnBattery
        lifecyclePolicy.setManualPause(defaults.isManualPaused)
        inputCoordinator.setMode(defaults.initialInteractionMode)
        timeOfDayController.batchUpdate(mode: defaults.timeOfDayMode, manualTheme: defaults.manualTheme)

        let resolvedTheme = timeOfDayController.currentTheme

        screenManager.applyHUDVisibility(defaults.showHUD)
        screenManager.applyInteractionMode(defaults.initialInteractionMode)
        screenManager.applyMood(defaults.pondMood)
        screenManager.applyRain(defaults.isRainActive)

        statusBarController?.updateInteractionMode(defaults.initialInteractionMode)
        statusBarController?.updateMoodState(mood: defaults.pondMood)
        statusBarController?.updateRainState(isRainActive: defaults.isRainActive)
        if previousTheme == resolvedTheme {
            statusBarController?.updateThemeState(
                mode: defaults.timeOfDayMode,
                manualTheme: defaults.manualTheme,
                currentTheme: resolvedTheme
            )
        }
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
