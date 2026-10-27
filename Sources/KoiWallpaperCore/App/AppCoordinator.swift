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
    public let manualFullscreenController: ManualFullscreenController
    public var idleBehaviorPolicy: IdleBehaviorPolicy
    public let launchAtLoginManager: LaunchAtLoginManaging

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
        screenManager: ScreenManager? = nil,
        manualFullscreenController: ManualFullscreenController? = nil,
        idleBehaviorPolicy: IdleBehaviorPolicy = IdleBehaviorPolicy(),
        launchAtLoginManager: LaunchAtLoginManaging = SystemLaunchAtLoginManager()
    ) {
        self.settingsManager = settingsManager
        self.launchAtLoginManager = launchAtLoginManager

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

        let fsCtrl = manualFullscreenController ?? ManualFullscreenController(screenManager: scrMgr)
        fsCtrl.screenManager = scrMgr
        self.manualFullscreenController = fsCtrl
        self.idleBehaviorPolicy = idleBehaviorPolicy

        super.init()

        self.lifecyclePolicy.delegate = self
        self.inputCoordinator.delegate = self
        self.timeOfDayController.onThemeChanged = { [weak self] newTheme in
            self?.handleThemeChanged(newTheme)
        }
        self.manualFullscreenController.onFullscreenStateChanged = { [weak self] isFullscreen in
            self?.statusBarController?.updateFullscreenState(isFullscreen: isFullscreen)
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
        let initialSeason = (settingsManager.settings.seasonMode == .autoCalendar)
            ? PondSeason.currentCalendarSeason()
            : settingsManager.settings.manualSeason
        screenManager.applySeason(initialSeason)
        screenManager.applySeasonMode(settingsManager.settings.seasonMode)
        screenManager.applyFloatingDebrisVisibility(settingsManager.settings.isFloatingDebrisEnabled)
        screenManager.applyGlobalPause(lifecyclePolicy.isPaused)
        screenManager.applyBatteryEcoMode(lifecyclePolicy.powerMonitor.isRunningOnBattery)

        lifecyclePolicy.powerMonitor.onPowerSourceChanged = { [weak self] in
            guard let self = self else { return }
            self.lifecyclePolicy.evaluatePowerState()
            self.screenManager.applyBatteryEcoMode(self.lifecyclePolicy.powerMonitor.isRunningOnBattery)
        }

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
            showHUD: settingsManager.settings.showHUD,
            launchAtLogin: launchAtLoginManager.isEnabled
        )
        statusController.updateMoodState(mood: settingsManager.settings.pondMood)
        statusController.updateRainState(isRainActive: settingsManager.settings.isRainActive)
        statusController.updateSeasonState(
            mode: settingsManager.settings.seasonMode,
            manualSeason: settingsManager.settings.manualSeason,
            currentSeason: initialSeason,
            isDebrisEnabled: settingsManager.settings.isFloatingDebrisEnabled
        )
        statusController.updateFullscreenState(isFullscreen: manualFullscreenController.isFullscreen)
        statusController.updateVisitorsState(count: screenManager.totalVisitorsCount)
        self.statusBarController = statusController

        // Synchronize launch at login state with saved preferences if needed
        if settingsManager.settings.launchAtLogin && !launchAtLoginManager.isEnabled {
            do {
                try launchAtLoginManager.setEnabled(true)
                logger.info("Synchronized launch at login on startup: enabled")
            } catch {
                logger.warning("Could not automatically enable launch at login on startup: \(error.localizedDescription)")
            }
        }
        statusController.updateLaunchAtLoginState(isEnabled: launchAtLoginManager.isEnabled)

        logger.info("KoiWallpaper M5 started successfully across \(self.screenManager.screenCount) screen(s).")
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
            showHUD: settingsManager.settings.showHUD,
            launchAtLogin: launchAtLoginManager.isEnabled
        )
    }

    public func statusBarDidToggleHUD(_ controller: StatusBarController) {
        let newShowHUD = !settingsManager.settings.showHUD
        logger.info("User toggled showHUD to: \(newShowHUD)")
        settingsManager.updateSettings { $0.showHUD = newShowHUD }
        screenManager.applyHUDVisibility(newShowHUD)
        statusBarController?.updateSettingsState(
            pauseOnBattery: settingsManager.settings.pauseOnBattery,
            showHUD: newShowHUD,
            launchAtLogin: launchAtLoginManager.isEnabled
        )
    }

    public func statusBarDidToggleLaunchAtLogin(_ controller: StatusBarController) {
        toggleLaunchAtLogin(showAlertOnError: true)
    }

    public func statusBarDidRequestOpenLoginItemsSettings(_ controller: StatusBarController) {
        openLoginItemsSettings()
    }

    public func openLoginItemsSettings() {
        logger.info("Opening macOS Login Items settings...")
        launchAtLoginManager.openLoginItemsSettings()
    }

    @discardableResult
    public func toggleLaunchAtLogin(showAlertOnError: Bool = false) -> Bool {
        let newState = !launchAtLoginManager.isEnabled
        return setLaunchAtLogin(newState, showAlertOnError: showAlertOnError)
    }

    @discardableResult
    public func setLaunchAtLogin(_ enabled: Bool, showAlertOnError: Bool = false) -> Bool {
        do {
            try launchAtLoginManager.setEnabled(enabled)
            settingsManager.updateSettings { $0.launchAtLogin = enabled }
            statusBarController?.updateLaunchAtLoginState(isEnabled: launchAtLoginManager.isEnabled)
            logger.info("Successfully set launch at login to \(enabled)")
            return true
        } catch {
            logger.error("Failed to set launch at login to \(enabled): \(error.localizedDescription)")
            statusBarController?.updateLaunchAtLoginState(isEnabled: launchAtLoginManager.isEnabled)

            if showAlertOnError {
                let alert = NSAlert()
                if launchAtLoginManager.requiresApproval {
                    alert.messageText = "Persetujuan Diperlukan di Pengaturan Sistem"
                    alert.informativeText = "macOS memerlukan persetujuan manual untuk mengaktifkan Koi Wallpaper agar terbuka otomatis saat login.\n\nSilakan izinkan Koi Wallpaper di Pengaturan Sistem > Umum > Item Masuk (Login Items)."
                    alert.addButton(withTitle: "Buka Pengaturan Sistem")
                    alert.addButton(withTitle: "Batal")
                    alert.alertStyle = .warning
                    let response = alert.runModal()
                    if response == .alertFirstButtonReturn {
                        openLoginItemsSettings()
                    }
                } else {
                    alert.messageText = "Gagal Mengubah Pengaturan Buka Otomatis"
                    alert.informativeText = "Terjadi kesalahan saat mendaftarkan aplikasi: \(error.localizedDescription)\n\nPastikan Koi Wallpaper dijalankan sebagai aplikasi .app dari folder Aplikasi (/Applications)."
                    alert.addButton(withTitle: "Buka Pengaturan Sistem")
                    alert.addButton(withTitle: "Tutup")
                    alert.alertStyle = .warning
                    let response = alert.runModal()
                    if response == .alertFirstButtonReturn {
                        openLoginItemsSettings()
                    }
                }
            }
            return false
        }
    }

    public func statusBarDidResetSettings(_ controller: StatusBarController) {
        logger.info("User reset settings to defaults.")
        try? launchAtLoginManager.setEnabled(false)
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
        let defaultSeason = (defaults.seasonMode == .autoCalendar)
            ? PondSeason.currentCalendarSeason()
            : defaults.manualSeason
        screenManager.applySeason(defaultSeason)
        screenManager.applySeasonMode(defaults.seasonMode)
        screenManager.applyFloatingDebrisVisibility(defaults.isFloatingDebrisEnabled)

        statusBarController?.updateInteractionMode(defaults.initialInteractionMode)
        statusBarController?.updateMoodState(mood: defaults.pondMood)
        statusBarController?.updateRainState(isRainActive: defaults.isRainActive)
        statusBarController?.updateSeasonState(
            mode: defaults.seasonMode,
            manualSeason: defaults.manualSeason,
            currentSeason: defaultSeason,
            isDebrisEnabled: defaults.isFloatingDebrisEnabled
        )
        if previousTheme == resolvedTheme {
            statusBarController?.updateThemeState(
                mode: defaults.timeOfDayMode,
                manualTheme: defaults.manualTheme,
                currentTheme: resolvedTheme
            )
        }
        statusBarController?.updateSettingsState(
            pauseOnBattery: defaults.pauseOnBattery,
            showHUD: defaults.showHUD,
            launchAtLogin: launchAtLoginManager.isEnabled
        )
    }

    public func statusBarDidRequestSpawnVisitor(_ controller: StatusBarController, type: PondVisitorType) {
        logger.info("User requested spawn visitor: \(type.rawValue)")
        screenManager.spawnVisitor(type: type)
        statusBarController?.updateVisitorsState(count: screenManager.totalVisitorsCount)
    }

    public func statusBarDidRequestClearVisitors(_ controller: StatusBarController) {
        logger.info("User requested clear visitors.")
        screenManager.clearVisitors()
        statusBarController?.updateVisitorsState(count: 0)
    }

    public func statusBarDidToggleFullscreen(_ controller: StatusBarController) {
        logger.info("User requested toggle fullscreen mode.")
        manualFullscreenController.toggleFullscreen()
    }

    public func statusBarDidSelectSeasonMode(_ controller: StatusBarController, mode: SeasonMode) {
        logger.info("User selected season mode: \(mode.rawValue)")
        settingsManager.updateSettings { $0.seasonMode = mode }
        let currentSeason = (mode == .autoCalendar)
            ? PondSeason.currentCalendarSeason()
            : settingsManager.settings.manualSeason
        screenManager.applySeason(currentSeason, showBanner: true)
        screenManager.applySeasonMode(mode)
        statusBarController?.updateSeasonState(
            mode: mode,
            manualSeason: settingsManager.settings.manualSeason,
            currentSeason: currentSeason,
            isDebrisEnabled: settingsManager.settings.isFloatingDebrisEnabled
        )
    }

    public func statusBarDidSelectManualSeason(_ controller: StatusBarController, season: PondSeason) {
        logger.info("User selected manual season: \(season.rawValue)")
        settingsManager.updateSettings {
            $0.seasonMode = .manual
            $0.manualSeason = season
        }
        screenManager.applySeason(season, showBanner: true)
        screenManager.applySeasonMode(.manual)
        statusBarController?.updateSeasonState(
            mode: .manual,
            manualSeason: season,
            currentSeason: season,
            isDebrisEnabled: settingsManager.settings.isFloatingDebrisEnabled
        )
    }

    public func statusBarDidToggleFloatingDebris(_ controller: StatusBarController) {
        let newEnabled = !settingsManager.settings.isFloatingDebrisEnabled
        logger.info("User toggled floating debris: \(newEnabled)")
        settingsManager.updateSettings { $0.isFloatingDebrisEnabled = newEnabled }
        screenManager.applyFloatingDebrisVisibility(newEnabled)
        let currentSeason = (settingsManager.settings.seasonMode == .autoCalendar)
            ? PondSeason.currentCalendarSeason()
            : settingsManager.settings.manualSeason
        statusBarController?.updateSeasonState(
            mode: settingsManager.settings.seasonMode,
            manualSeason: settingsManager.settings.manualSeason,
            currentSeason: currentSeason,
            isDebrisEnabled: newEnabled
        )
    }

    public func statusBarDidRequestStartScreenSaver(_ controller: StatusBarController) {
        startScreenSaver()
    }

    public func startScreenSaver() {
        logger.info("User requested start screen saver immediately.")
        let url = URL(fileURLWithPath: "/System/Library/CoreServices/ScreenSaverEngine.app")
        let config = NSWorkspace.OpenConfiguration()
        config.activates = true
        NSWorkspace.shared.openApplication(at: url, configuration: config) { app, error in
            if let error = error {
                logger.error("Failed to launch ScreenSaverEngine via openApplication: \(error.localizedDescription)")
                let script = "tell application \"System Events\" to start current screen saver"
                NSAppleScript(source: script)?.executeAndReturnError(nil)
            }
        }
    }

    public func statusBarDidRequestInstallScreenSaver(_ controller: StatusBarController) {
        installScreenSaver(showAlert: true)
    }

    public func statusBarDidRequestOpenScreenSaverSettings(_ controller: StatusBarController) {
        openScreenSaverSettings()
    }

    @discardableResult
    public func installScreenSaver(
        destinationDirectory: URL? = nil,
        sourceBundleURL: URL? = nil,
        showAlert: Bool = false
    ) -> Bool {
        let fileManager = FileManager.default
        let destDir = destinationDirectory ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Screen Savers")
        let destURL = destDir.appendingPathComponent("KoiWallpaper.saver")

        var sourceURL: URL? = sourceBundleURL
        if sourceURL == nil {
            sourceURL = Bundle.main.url(forResource: "KoiWallpaper", withExtension: "saver")
        }
        if sourceURL == nil {
            let possibleLocations = [
                Bundle.main.resourceURL?.appendingPathComponent("KoiWallpaper.saver"),
                Bundle.main.bundleURL.appendingPathComponent("Contents/Resources/KoiWallpaper.saver"),
                URL(fileURLWithPath: "build/KoiWallpaper.saver"),
                Bundle.main.bundleURL.deletingLastPathComponent().appendingPathComponent("KoiWallpaper.saver")
            ].compactMap { $0 }
            sourceURL = possibleLocations.first(where: { fileManager.fileExists(atPath: $0.path) })
        }

        guard let validSource = sourceURL, fileManager.fileExists(atPath: validSource.path) else {
            logger.error("Failed to locate KoiWallpaper.saver to install.")
            if showAlert {
                let alert = NSAlert()
                alert.messageText = "Screen Saver Belum Ditemukan"
                alert.informativeText = "Berkas KoiWallpaper.saver belum dikompilasi atau dibundel di dalam aplikasi. Silakan jalankan ./scripts/build_app.sh terlebih dahulu."
                alert.alertStyle = .warning
                alert.runModal()
            }
            return false
        }

        do {
            try fileManager.createDirectory(at: destDir, withIntermediateDirectories: true)
            if fileManager.fileExists(atPath: destURL.path) {
                try fileManager.removeItem(at: destURL)
            }
            try fileManager.copyItem(at: validSource, to: destURL)
            logger.info("Successfully installed screen saver to \(destURL.path)")

            if showAlert {
                let alert = NSAlert()
                alert.messageText = "Screen Saver Berhasil Dipasang!"
                alert.informativeText = "Koi Wallpaper telah dipasang ke ~/Library/Screen Savers.\n\nBuka Pengaturan Sistem untuk memilih 'Koi Wallpaper' sebagai Screen Saver / Wallpaper Layar Terkunci Anda."
                alert.addButton(withTitle: "Buka Pengaturan Sistem")
                alert.addButton(withTitle: "Selesai")
                alert.alertStyle = .informational
                let response = alert.runModal()
                if response == .alertFirstButtonReturn {
                    openScreenSaverSettings()
                }
            }
            return true
        } catch {
            logger.error("Failed to copy screen saver: \(error.localizedDescription)")
            if showAlert {
                let alert = NSAlert()
                alert.messageText = "Gagal Memasang Screen Saver"
                alert.informativeText = "Terjadi kesalahan saat menyalin ke ~/Library/Screen Savers: \(error.localizedDescription)"
                alert.alertStyle = .critical
                alert.runModal()
            }
            return false
        }
    }

    public func openScreenSaverSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.ScreenSaver-Settings.extension") {
            NSWorkspace.shared.open(url)
        } else if let fallback = URL(string: "x-apple.systempreferences:com.apple.preference.desktopscreeneffect") {
            NSWorkspace.shared.open(fallback)
        }
    }

    /// Cleanly tears down screen managers, unbinds window observers from lifecycle policy, and stops timers.
    public func teardown() {
        manualFullscreenController.exitFullscreen()
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
