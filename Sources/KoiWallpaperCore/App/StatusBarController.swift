import AppKit

public protocol StatusBarControllerDelegate: AnyObject {
    func statusBarDidToggleInteractionMode(_ controller: StatusBarController)
    func statusBarDidToggleManualPause(_ controller: StatusBarController)
    func statusBarDidSelectTimeOfDayMode(_ controller: StatusBarController, mode: TimeOfDayMode)
    func statusBarDidSelectManualTimePhase(_ controller: StatusBarController, phase: TimeOfDayPhase)
    func statusBarDidTogglePauseOnBattery(_ controller: StatusBarController)
    func statusBarDidToggleHUD(_ controller: StatusBarController)
    func statusBarDidResetSettings(_ controller: StatusBarController)
    func statusBarDidRequestQuit(_ controller: StatusBarController)
}

public final class StatusBarController {
    public weak var delegate: StatusBarControllerDelegate?

    private var statusItem: NSStatusItem?
    private let menu = NSMenu()

    // Primary menu items
    private let headerItem = NSMenuItem(title: "Koi Wallpaper (M3)", action: nil, keyEquivalent: "")
    private let pauseStatusItem = NSMenuItem(title: "Status Kolam: Aktif", action: nil, keyEquivalent: "")
    private let pauseToggleItem = NSMenuItem(
        title: "Jeda Kolam (Pause)",
        action: #selector(pauseToggled),
        keyEquivalent: "p"
    )

    private let interactionToggleItem = NSMenuItem(
        title: "Mode Interaksi (Tangkap Klik)",
        action: #selector(interactionToggled),
        keyEquivalent: "i"
    )
    private let interactionDescItem = NSMenuItem(title: "Status: Tembus Klik Finder (Default)", action: nil, keyEquivalent: "")

    // Time of Day submenu
    private let timeOfDayMenuItem = NSMenuItem(title: "Waktu Kolam (Time of Day)", action: nil, keyEquivalent: "")
    private let timeOfDayMenu = NSMenu(title: "Time of Day")
    private let autoTimeItem = NSMenuItem(title: "Otomatis Sesuai Jam (Auto)", action: #selector(autoTimeSelected), keyEquivalent: "")
    private let systemThemeItem = NSMenuItem(title: "Ikuti Tema Sistem (Light/Dark)", action: #selector(systemThemeSelected), keyEquivalent: "")
    private let dawnItem = NSMenuItem(title: "Fajar (Dawn)", action: #selector(dawnSelected), keyEquivalent: "")
    private let dayItem = NSMenuItem(title: "Siang (Day)", action: #selector(daySelected), keyEquivalent: "")
    private let duskItem = NSMenuItem(title: "Senja (Dusk)", action: #selector(duskSelected), keyEquivalent: "")
    private let nightItem = NSMenuItem(title: "Malam (Night)", action: #selector(nightSelected), keyEquivalent: "")
    private let currentPhaseInfoItem = NSMenuItem(title: "Fase Aktif: Siang (Day)", action: nil, keyEquivalent: "")

    // Settings submenu
    private let settingsMenuItem = NSMenuItem(title: "Pengaturan (Settings)", action: nil, keyEquivalent: "")
    private let settingsMenu = NSMenu(title: "Settings")
    private let pauseOnBatteryItem = NSMenuItem(
        title: "Jeda Saat Menggunakan Baterai",
        action: #selector(pauseOnBatteryToggled),
        keyEquivalent: ""
    )
    private let showHUDItem = NSMenuItem(
        title: "Tampilkan HUD Diagnostik",
        action: #selector(hudToggled),
        keyEquivalent: ""
    )
    private let resetSettingsItem = NSMenuItem(
        title: "Reset Pengaturan ke Default",
        action: #selector(resetSettingsClicked),
        keyEquivalent: ""
    )

    // Quit
    private let quitItem = NSMenuItem(
        title: "Keluar Koi Wallpaper",
        action: #selector(quitClicked),
        keyEquivalent: "q"
    )

    public init() {
        setupStatusItem()
    }

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            button.title = "🐟"
            button.toolTip = "Koi Wallpaper (M3)"
        }

        setupMenu()
        item.menu = menu
        self.statusItem = item
    }

    private func setupMenu() {
        headerItem.isEnabled = false
        pauseStatusItem.isEnabled = false
        interactionDescItem.isEnabled = false
        currentPhaseInfoItem.isEnabled = false

        // Action targets
        pauseToggleItem.target = self
        interactionToggleItem.target = self
        autoTimeItem.target = self
        systemThemeItem.target = self
        dawnItem.target = self
        dayItem.target = self
        duskItem.target = self
        nightItem.target = self
        pauseOnBatteryItem.target = self
        showHUDItem.target = self
        resetSettingsItem.target = self
        quitItem.target = self

        // Build Time of Day submenu
        timeOfDayMenu.addItem(autoTimeItem)
        timeOfDayMenu.addItem(systemThemeItem)
        timeOfDayMenu.addItem(NSMenuItem.separator())
        let manualHeader = NSMenuItem(title: "Pilihan Manual:", action: nil, keyEquivalent: "")
        manualHeader.isEnabled = false
        timeOfDayMenu.addItem(manualHeader)
        timeOfDayMenu.addItem(dawnItem)
        timeOfDayMenu.addItem(dayItem)
        timeOfDayMenu.addItem(duskItem)
        timeOfDayMenu.addItem(nightItem)
        timeOfDayMenu.addItem(NSMenuItem.separator())
        timeOfDayMenu.addItem(currentPhaseInfoItem)
        timeOfDayMenuItem.submenu = timeOfDayMenu

        // Build Settings submenu
        settingsMenu.addItem(pauseOnBatteryItem)
        settingsMenu.addItem(showHUDItem)
        settingsMenu.addItem(NSMenuItem.separator())
        settingsMenu.addItem(resetSettingsItem)
        settingsMenuItem.submenu = settingsMenu

        // Assemble root menu
        menu.addItem(headerItem)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(pauseToggleItem)
        menu.addItem(pauseStatusItem)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(interactionToggleItem)
        menu.addItem(interactionDescItem)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(timeOfDayMenuItem)
        menu.addItem(settingsMenuItem)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(quitItem)
    }

    // MARK: - State Updates

    public func updateInteractionMode(_ mode: InputInteractionMode) {
        let isInteractive = (mode == .interactive)
        interactionToggleItem.state = isInteractive ? .on : .off
        interactionDescItem.title = isInteractive
            ? "Status: Tangkap Klik (Kolam Interaktif)"
            : "Status: Tembus Klik Finder (Default)"

        updateStatusIcon(isInteractive: isInteractive, isPaused: pauseToggleItem.title.contains("Lanjutkan"))
    }

    public func updatePauseState(isPaused: Bool, reasons: Set<PauseReason>) {
        if isPaused {
            let reasonStr = reasons.map(\.rawValue).sorted().joined(separator: ", ")
            pauseStatusItem.title = "Status Kolam: Paused (\(reasonStr))"
            let isManual = reasons.contains(.manual)
            pauseToggleItem.title = isManual ? "Lanjutkan Kolam (Resume)" : "Jeda Kolam (Pause)"
            pauseToggleItem.state = isManual ? .on : .off
        } else {
            pauseStatusItem.title = "Status Kolam: Aktif"
            pauseToggleItem.title = "Jeda Kolam (Pause)"
            pauseToggleItem.state = .off
        }

        updateStatusIcon(
            isInteractive: interactionToggleItem.state == .on,
            isPaused: isPaused
        )
    }

    public func updateTimeOfDayState(mode: TimeOfDayMode, manualPhase: TimeOfDayPhase, currentPhase: TimeOfDayPhase) {
        autoTimeItem.state = (mode == .auto) ? .on : .off
        systemThemeItem.state = (mode == .systemTheme) ? .on : .off

        dawnItem.state = (mode == .manual && manualPhase == .dawn) ? .on : .off
        dayItem.state = (mode == .manual && manualPhase == .day) ? .on : .off
        duskItem.state = (mode == .manual && manualPhase == .dusk) ? .on : .off
        nightItem.state = (mode == .manual && manualPhase == .night) ? .on : .off

        currentPhaseInfoItem.title = "Fase Aktif: \(currentPhase.displayName)"
    }

    public func updateSettingsState(pauseOnBattery: Bool, showHUD: Bool) {
        pauseOnBatteryItem.state = pauseOnBattery ? .on : .off
        showHUDItem.state = showHUD ? .on : .off
    }

    private func updateStatusIcon(isInteractive: Bool, isPaused: Bool) {
        guard let button = statusItem?.button else { return }
        if isPaused {
            button.title = "🐟⏸"
        } else if isInteractive {
            button.title = "🐟⚡"
        } else {
            button.title = "🐟"
        }
    }

    // MARK: - Actions

    @objc private func interactionToggled() {
        delegate?.statusBarDidToggleInteractionMode(self)
    }

    @objc private func pauseToggled() {
        delegate?.statusBarDidToggleManualPause(self)
    }

    @objc private func autoTimeSelected() {
        delegate?.statusBarDidSelectTimeOfDayMode(self, mode: .auto)
    }

    @objc private func systemThemeSelected() {
        delegate?.statusBarDidSelectTimeOfDayMode(self, mode: .systemTheme)
    }

    @objc private func dawnSelected() {
        delegate?.statusBarDidSelectManualTimePhase(self, phase: .dawn)
    }

    @objc private func daySelected() {
        delegate?.statusBarDidSelectManualTimePhase(self, phase: .day)
    }

    @objc private func duskSelected() {
        delegate?.statusBarDidSelectManualTimePhase(self, phase: .dusk)
    }

    @objc private func nightSelected() {
        delegate?.statusBarDidSelectManualTimePhase(self, phase: .night)
    }

    @objc private func pauseOnBatteryToggled() {
        delegate?.statusBarDidTogglePauseOnBattery(self)
    }

    @objc private func hudToggled() {
        delegate?.statusBarDidToggleHUD(self)
    }

    @objc private func resetSettingsClicked() {
        delegate?.statusBarDidResetSettings(self)
    }

    @objc private func quitClicked() {
        delegate?.statusBarDidRequestQuit(self)
    }
}
