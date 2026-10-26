import AppKit

public protocol StatusBarControllerDelegate: AnyObject {
    func statusBarDidToggleInteractionMode(_ controller: StatusBarController)
    func statusBarDidToggleManualPause(_ controller: StatusBarController)
    func statusBarDidSelectTimeOfDayMode(_ controller: StatusBarController, mode: TimeOfDayMode)
    func statusBarDidSelectManualTimePhase(_ controller: StatusBarController, phase: TimeOfDayPhase)
    func statusBarDidSelectManualTheme(_ controller: StatusBarController, theme: PondTheme)
    func statusBarDidSelectMood(_ controller: StatusBarController, mood: PondMood)
    func statusBarDidToggleRain(_ controller: StatusBarController)
    func statusBarDidTogglePauseOnBattery(_ controller: StatusBarController)
    func statusBarDidToggleHUD(_ controller: StatusBarController)
    func statusBarDidResetSettings(_ controller: StatusBarController)
    func statusBarDidRequestQuit(_ controller: StatusBarController)
    func statusBarDidRequestSpawnVisitor(_ controller: StatusBarController, type: PondVisitorType)
    func statusBarDidRequestClearVisitors(_ controller: StatusBarController)
    func statusBarDidToggleFullscreen(_ controller: StatusBarController)
    func statusBarDidToggleLaunchAtLogin(_ controller: StatusBarController)
    func statusBarDidRequestOpenLoginItemsSettings(_ controller: StatusBarController)
    func statusBarDidRequestInstallScreenSaver(_ controller: StatusBarController)
    func statusBarDidRequestOpenScreenSaverSettings(_ controller: StatusBarController)
    func statusBarDidRequestStartScreenSaver(_ controller: StatusBarController)
}

extension StatusBarControllerDelegate {
    public func statusBarDidSelectManualTheme(_ controller: StatusBarController, theme: PondTheme) {
        if let phase = theme.asTimePhase {
            statusBarDidSelectManualTimePhase(controller, phase: phase)
        }
    }
    public func statusBarDidSelectMood(_ controller: StatusBarController, mood: PondMood) {}
    public func statusBarDidToggleRain(_ controller: StatusBarController) {}
    public func statusBarDidRequestSpawnVisitor(_ controller: StatusBarController, type: PondVisitorType) {}
    public func statusBarDidRequestClearVisitors(_ controller: StatusBarController) {}
    public func statusBarDidToggleFullscreen(_ controller: StatusBarController) {}
    public func statusBarDidToggleLaunchAtLogin(_ controller: StatusBarController) {}
    public func statusBarDidRequestOpenLoginItemsSettings(_ controller: StatusBarController) {}
    public func statusBarDidRequestInstallScreenSaver(_ controller: StatusBarController) {}
    public func statusBarDidRequestOpenScreenSaverSettings(_ controller: StatusBarController) {}
    public func statusBarDidRequestStartScreenSaver(_ controller: StatusBarController) {}
}

public final class StatusBarController {
    public weak var delegate: StatusBarControllerDelegate?

    private var statusItem: NSStatusItem?
    private let menu = NSMenu()

    // Primary menu items
    private let headerItem = NSMenuItem(title: "Koi Wallpaper (M5)", action: nil, keyEquivalent: "")
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

    // Fullscreen manual mode
    private let fullscreenToggleItem = NSMenuItem(
        title: "Mode Layar Penuh (Escape untuk Keluar)",
        action: #selector(fullscreenToggled),
        keyEquivalent: "f"
    )

    // Screen Saver trigger
    private let startScreenSaverItem = NSMenuItem(
        title: "Mulai Screen Saver Kolam Koi Sekarang",
        action: #selector(startScreenSaverClicked),
        keyEquivalent: "s"
    )

    // Time of Day & Theme submenu
    private let timeOfDayMenuItem = NSMenuItem(title: "Tema & Waktu Kolam", action: nil, keyEquivalent: "")
    private let timeOfDayMenu = NSMenu(title: "Tema & Waktu")
    private let autoTimeItem = NSMenuItem(title: "Otomatis Sesuai Jam (Auto)", action: #selector(autoTimeSelected), keyEquivalent: "")
    private let systemThemeItem = NSMenuItem(title: "Ikuti Tema Sistem (Light/Dark)", action: #selector(systemThemeSelected), keyEquivalent: "")
    private let dawnItem = NSMenuItem(title: "Fajar (Dawn)", action: #selector(dawnSelected), keyEquivalent: "")
    private let dayItem = NSMenuItem(title: "Siang (Day)", action: #selector(daySelected), keyEquivalent: "")
    private let goldenHourItem = NSMenuItem(title: "Golden Hour", action: #selector(goldenHourSelected), keyEquivalent: "")
    private let duskItem = NSMenuItem(title: "Senja (Dusk)", action: #selector(duskSelected), keyEquivalent: "")
    private let nightItem = NSMenuItem(title: "Malam (Night)", action: #selector(nightSelected), keyEquivalent: "")

    private let deepClearItem = NSMenuItem(title: "Deep Clear", action: #selector(deepClearSelected), keyEquivalent: "")
    private let rainItem = NSMenuItem(title: "Hujan (Rain Preset)", action: #selector(rainSelected), keyEquivalent: "")

    private let currentPhaseInfoItem = NSMenuItem(title: "Tema Aktif: Siang (Day)", action: nil, keyEquivalent: "")

    // Mood & Weather submenu
    private let moodMenuItem = NSMenuItem(title: "Suasana Kolam (Mood)", action: nil, keyEquivalent: "")
    private let moodMenu = NSMenu(title: "Suasana")
    private let calmMoodItem = NSMenuItem(title: "Tenang (Calm)", action: #selector(calmMoodSelected), keyEquivalent: "")
    private let playfulMoodItem = NSMenuItem(title: "Lincah (Playful)", action: #selector(playfulMoodSelected), keyEquivalent: "")

    private let rainToggleItem = NSMenuItem(
        title: "Efek Hujan Aktif",
        action: #selector(rainToggled),
        keyEquivalent: ""
    )

    // Visitors submenu
    private let visitorsMenuItem = NSMenuItem(title: "Pengunjung Kolam (Visitors)", action: nil, keyEquivalent: "")
    private let visitorsMenu = NSMenu(title: "Pengunjung")
    private let automaticSwanInfoItem = NSMenuItem(title: "Angsa melintas otomatis", action: nil, keyEquivalent: "")
    private let spawnBallItem = NSMenuItem(title: "Lepas Bola Temari (Ball)", action: #selector(spawnBallClicked), keyEquivalent: "")
    private let clearVisitorsItem = NSMenuItem(title: "Bersihkan Pengunjung (Clear)", action: #selector(clearVisitorsClicked), keyEquivalent: "")
    private let visitorsStatusItem = NSMenuItem(title: "Pengunjung manual aktif: 0", action: nil, keyEquivalent: "")

    // Settings submenu
    private let settingsMenuItem = NSMenuItem(title: "Pengaturan (Settings)", action: nil, keyEquivalent: "")
    private let settingsMenu = NSMenu(title: "Settings")
    private let launchAtLoginItem = NSMenuItem(
        title: "Mulai Otomatis Saat MacBook Menyala (Launch at Login)",
        action: #selector(launchAtLoginToggled),
        keyEquivalent: ""
    )
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
    private let installScreenSaverItem = NSMenuItem(
        title: "Pasang di Layar Terkunci (Screen Saver)...",
        action: #selector(installScreenSaverClicked),
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

    private static let normalIcon: NSImage = makeStatusIcon(isInteractive: false, isPaused: false)
    private static let interactiveIcon: NSImage = makeStatusIcon(isInteractive: true, isPaused: false)
    private static let pausedIcon: NSImage = makeStatusIcon(isInteractive: false, isPaused: true)
    private static let pausedInteractiveIcon: NSImage = makeStatusIcon(isInteractive: true, isPaused: true)

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            button.image = Self.normalIcon
            button.imagePosition = .imageOnly
            button.title = ""
            button.toolTip = "Koi Wallpaper"
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
        automaticSwanInfoItem.isEnabled = false
        visitorsStatusItem.isEnabled = false

        // Action targets
        pauseToggleItem.target = self
        startScreenSaverItem.target = self
        interactionToggleItem.target = self
        fullscreenToggleItem.target = self
        autoTimeItem.target = self
        systemThemeItem.target = self
        dawnItem.target = self
        dayItem.target = self
        goldenHourItem.target = self
        duskItem.target = self
        nightItem.target = self
        deepClearItem.target = self
        rainItem.target = self
        calmMoodItem.target = self
        playfulMoodItem.target = self
        rainToggleItem.target = self
        spawnBallItem.target = self
        clearVisitorsItem.target = self
        launchAtLoginItem.target = self
        launchAtLoginItem.toolTip = "Buka Koi Wallpaper secara otomatis setiap kali MacBook dinyalakan atau setelah pengguna login"
        pauseOnBatteryItem.target = self
        showHUDItem.target = self
        installScreenSaverItem.target = self
        resetSettingsItem.target = self
        quitItem.target = self

        // Build Theme submenu
        timeOfDayMenu.addItem(autoTimeItem)
        timeOfDayMenu.addItem(systemThemeItem)
        timeOfDayMenu.addItem(NSMenuItem.separator())

        let phaseHeader = NSMenuItem(title: "Fase Waktu:", action: nil, keyEquivalent: "")
        phaseHeader.isEnabled = false
        timeOfDayMenu.addItem(phaseHeader)
        timeOfDayMenu.addItem(dawnItem)
        timeOfDayMenu.addItem(dayItem)
        timeOfDayMenu.addItem(goldenHourItem)
        timeOfDayMenu.addItem(duskItem)
        timeOfDayMenu.addItem(nightItem)

        timeOfDayMenu.addItem(NSMenuItem.separator())
        let presetHeader = NSMenuItem(title: "Preset Khusus:", action: nil, keyEquivalent: "")
        presetHeader.isEnabled = false
        timeOfDayMenu.addItem(presetHeader)
        timeOfDayMenu.addItem(deepClearItem)
        timeOfDayMenu.addItem(rainItem)

        timeOfDayMenu.addItem(NSMenuItem.separator())
        timeOfDayMenu.addItem(currentPhaseInfoItem)
        timeOfDayMenuItem.submenu = timeOfDayMenu

        // Build Mood submenu
        moodMenu.addItem(calmMoodItem)
        moodMenu.addItem(playfulMoodItem)
        moodMenuItem.submenu = moodMenu

        // Build Visitors submenu
        visitorsMenu.addItem(automaticSwanInfoItem)
        visitorsMenu.addItem(spawnBallItem)
        visitorsMenu.addItem(NSMenuItem.separator())
        visitorsMenu.addItem(clearVisitorsItem)
        visitorsMenu.addItem(NSMenuItem.separator())
        visitorsMenu.addItem(visitorsStatusItem)
        visitorsMenuItem.submenu = visitorsMenu

        // Build Settings submenu
        settingsMenu.addItem(launchAtLoginItem)
        settingsMenu.addItem(pauseOnBatteryItem)
        settingsMenu.addItem(showHUDItem)
        settingsMenu.addItem(NSMenuItem.separator())
        settingsMenu.addItem(installScreenSaverItem)
        settingsMenu.addItem(NSMenuItem.separator())
        settingsMenu.addItem(resetSettingsItem)
        settingsMenuItem.submenu = settingsMenu

        // Assemble root menu
        menu.addItem(headerItem)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(pauseToggleItem)
        menu.addItem(pauseStatusItem)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(startScreenSaverItem)
        menu.addItem(fullscreenToggleItem)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(interactionToggleItem)
        menu.addItem(interactionDescItem)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(timeOfDayMenuItem)
        menu.addItem(moodMenuItem)
        menu.addItem(rainToggleItem)
        menu.addItem(visitorsMenuItem)
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

    public func updateThemeState(mode: TimeOfDayMode, manualTheme: PondTheme, currentTheme: PondTheme) {
        autoTimeItem.state = (mode == .auto) ? .on : .off
        systemThemeItem.state = (mode == .systemTheme) ? .on : .off

        dawnItem.state = (mode == .manual && manualTheme == .dawn) ? .on : .off
        dayItem.state = (mode == .manual && manualTheme == .day) ? .on : .off
        goldenHourItem.state = (mode == .manual && manualTheme == .goldenHour) ? .on : .off
        duskItem.state = (mode == .manual && manualTheme == .dusk) ? .on : .off
        nightItem.state = (mode == .manual && manualTheme == .night) ? .on : .off
        deepClearItem.state = (mode == .manual && manualTheme == .deepClear) ? .on : .off
        rainItem.state = (mode == .manual && manualTheme == .rain) ? .on : .off

        currentPhaseInfoItem.title = "Tema Aktif: \(currentTheme.displayName)"
    }

    public func updateTimeOfDayState(mode: TimeOfDayMode, manualPhase: TimeOfDayPhase, currentPhase: TimeOfDayPhase) {
        updateThemeState(mode: mode, manualTheme: manualPhase.theme, currentTheme: currentPhase.theme)
    }

    public func updateSettingsState(pauseOnBattery: Bool, showHUD: Bool) {
        pauseOnBatteryItem.state = pauseOnBattery ? .on : .off
        showHUDItem.state = showHUD ? .on : .off
    }

    public func updateSettingsState(pauseOnBattery: Bool, showHUD: Bool, launchAtLogin: Bool) {
        pauseOnBatteryItem.state = pauseOnBattery ? .on : .off
        showHUDItem.state = showHUD ? .on : .off
        launchAtLoginItem.state = launchAtLogin ? .on : .off
    }

    public func updateLaunchAtLoginState(isEnabled: Bool) {
        launchAtLoginItem.state = isEnabled ? .on : .off
    }

    // Testing helpers
    public var isLaunchAtLoginMenuItemChecked: Bool {
        launchAtLoginItem.state == .on
    }

    public var settingsMenuItemsTitles: [String] {
        settingsMenu.items.map(\.title)
    }

    public func simulateLaunchAtLoginClick() {
        launchAtLoginToggled()
    }

    public func updateMoodState(mood: PondMood) {
        calmMoodItem.state = (mood == .calm) ? .on : .off
        playfulMoodItem.state = (mood == .playful) ? .on : .off
    }

    public func updateRainState(isRainActive: Bool) {
        rainToggleItem.state = isRainActive ? .on : .off
    }

    public func updateFullscreenState(isFullscreen: Bool) {
        fullscreenToggleItem.state = isFullscreen ? .on : .off
        fullscreenToggleItem.title = isFullscreen
            ? "Keluar dari Layar Penuh (Escape)"
            : "Mode Layar Penuh (Escape untuk Keluar)"
    }

    public func updateVisitorsState(count: Int) {
        visitorsStatusItem.title = "Pengunjung manual aktif: \(count)"
    }

    private func updateStatusIcon(isInteractive: Bool, isPaused: Bool) {
        guard let button = statusItem?.button else { return }
        let icon: NSImage
        if isPaused {
            icon = isInteractive ? Self.pausedInteractiveIcon : Self.pausedIcon
        } else {
            icon = isInteractive ? Self.interactiveIcon : Self.normalIcon
        }
        button.image = icon
        button.imagePosition = .imageOnly
        button.title = ""
    }

    public static func makeStatusIcon(isInteractive: Bool = false, isPaused: Bool = false) -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size, flipped: false) { rect in
            guard let ctx = NSGraphicsContext.current?.cgContext else { return false }

            ctx.saveGState()
            let center = CGPoint(x: rect.midX, y: rect.midY)
            let s = min(rect.width, rect.height)

            ctx.translateBy(x: center.x, y: center.y)
            ctx.rotate(by: -CGFloat.pi * 0.25) // Gracefully swimming upward-right

            let length = s * 0.90
            let halfWidth = length * 0.20

            let flex: CGFloat = 0.18
            let p0 = CGPoint(x: length * 0.45, y: 0)
            let p1 = CGPoint(x: length * 0.25, y: -length * flex * 0.15)
            let p2 = CGPoint(x: 0, y: -length * flex * 0.45)
            let p3 = CGPoint(x: -length * 0.22, y: -length * flex * 0.40)
            let p4 = CGPoint(x: -length * 0.38, y: -length * flex * 0.15)
            let p5 = CGPoint(x: -length * 0.48, y: length * flex * 0.20)

            let spine = [p0, p1, p2, p3, p4, p5]
            let widths: [CGFloat] = [0.12, 0.72, 1.0, 0.82, 0.45, 0.18]

            let baseAlpha: CGFloat = isPaused ? 0.45 : 1.0

            // 1. Pectoral Fins (Left & Right)
            func drawFin(at pt: CGPoint, side: CGFloat) {
                ctx.saveGState()
                let finPath = CGMutablePath()
                let finLen = length * 0.32
                let finW = halfWidth * 1.55
                finPath.move(to: pt)
                let tip = CGPoint(x: pt.x - finLen * 0.7, y: pt.y + side * finW)
                let c1 = CGPoint(x: pt.x + finLen * 0.2, y: pt.y + side * finW * 0.9)
                let c2 = CGPoint(x: pt.x - finLen * 0.9, y: pt.y + side * finW * 0.4)
                finPath.addQuadCurve(to: tip, control: c1)
                finPath.addQuadCurve(to: CGPoint(x: pt.x - finLen * 0.4, y: pt.y + side * halfWidth * 0.6), control: c2)
                finPath.closeSubpath()

                ctx.setFillColor(gray: 1.0, alpha: 0.68 * baseAlpha)
                ctx.addPath(finPath)
                ctx.fillPath()
                ctx.restoreGState()
            }
            drawFin(at: CGPoint(x: p2.x, y: p2.y + halfWidth * 0.7), side: 1.0)
            drawFin(at: CGPoint(x: p2.x, y: p2.y - halfWidth * 0.7), side: -1.0)

            // 2. Caudal Tail Fin (Flowing fan shape)
            let tailPath = CGMutablePath()
            let tailLen = length * 0.35
            let tailW = halfWidth * 1.8
            tailPath.move(to: p5)
            let tailTip1 = CGPoint(x: p5.x - tailLen, y: p5.y + tailW * 0.8)
            let tailNotch = CGPoint(x: p5.x - tailLen * 0.7, y: p5.y)
            let tailTip2 = CGPoint(x: p5.x - tailLen, y: p5.y - tailW * 0.8)
            tailPath.addQuadCurve(to: tailTip1, control: CGPoint(x: p5.x - tailLen * 0.5, y: p5.y + tailW * 0.6))
            tailPath.addLine(to: tailNotch)
            tailPath.addLine(to: tailTip2)
            tailPath.addQuadCurve(to: p5, control: CGPoint(x: p5.x - tailLen * 0.5, y: p5.y - tailW * 0.6))
            tailPath.closeSubpath()

            ctx.setFillColor(gray: 1.0, alpha: 0.72 * baseAlpha)
            ctx.addPath(tailPath)
            ctx.fillPath()

            // 3. Torso Silhouette
            let torsoPath = CGMutablePath()
            for (i, p) in spine.enumerated() {
                let pt = CGPoint(x: p.x, y: p.y + halfWidth * widths[i])
                if i == 0 { torsoPath.move(to: pt) } else { torsoPath.addLine(to: pt) }
            }
            for i in (0..<spine.count).reversed() {
                let pt = CGPoint(x: spine[i].x, y: spine[i].y - halfWidth * widths[i])
                torsoPath.addLine(to: pt)
            }
            torsoPath.closeSubpath()

            ctx.setFillColor(gray: 1.0, alpha: baseAlpha)
            ctx.addPath(torsoPath)
            ctx.fillPath()

            ctx.restoreGState()

            // 4. Subtle badges
            if isPaused {
                // Small crisp pause bars in bottom right corner
                ctx.setFillColor(gray: 1.0, alpha: 0.90)
                ctx.fill(CGRect(x: rect.maxX - 5.5, y: rect.minY + 1.5, width: 1.5, height: 4.5))
                ctx.fill(CGRect(x: rect.maxX - 3.0, y: rect.minY + 1.5, width: 1.5, height: 4.5))
            } else if isInteractive {
                // Small subtle interactive dot badge in bottom right corner
                ctx.setFillColor(gray: 1.0, alpha: 0.95)
                ctx.fillEllipse(in: CGRect(x: rect.maxX - 4.5, y: rect.minY + 1.5, width: 3.5, height: 3.5))
            }

            return true
        }
        image.isTemplate = true
        return image
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
        delegate?.statusBarDidSelectManualTheme(self, theme: .dawn)
    }

    @objc private func daySelected() {
        delegate?.statusBarDidSelectManualTheme(self, theme: .day)
    }

    @objc private func goldenHourSelected() {
        delegate?.statusBarDidSelectManualTheme(self, theme: .goldenHour)
    }

    @objc private func duskSelected() {
        delegate?.statusBarDidSelectManualTheme(self, theme: .dusk)
    }

    @objc private func nightSelected() {
        delegate?.statusBarDidSelectManualTheme(self, theme: .night)
    }

    @objc private func deepClearSelected() {
        delegate?.statusBarDidSelectManualTheme(self, theme: .deepClear)
    }

    @objc private func rainSelected() {
        delegate?.statusBarDidSelectManualTheme(self, theme: .rain)
    }

    @objc private func calmMoodSelected() {
        delegate?.statusBarDidSelectMood(self, mood: .calm)
    }

    @objc private func playfulMoodSelected() {
        delegate?.statusBarDidSelectMood(self, mood: .playful)
    }

    @objc private func rainToggled() {
        delegate?.statusBarDidToggleRain(self)
    }

    @objc private func fullscreenToggled() {
        delegate?.statusBarDidToggleFullscreen(self)
    }

    @objc private func startScreenSaverClicked() {
        delegate?.statusBarDidRequestStartScreenSaver(self)
    }

    @objc private func spawnBallClicked() {
        delegate?.statusBarDidRequestSpawnVisitor(self, type: .ball)
    }

    @objc private func clearVisitorsClicked() {
        delegate?.statusBarDidRequestClearVisitors(self)
    }

    @objc private func launchAtLoginToggled() {
        delegate?.statusBarDidToggleLaunchAtLogin(self)
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

    @objc private func installScreenSaverClicked() {
        delegate?.statusBarDidRequestInstallScreenSaver(self)
    }

    @objc private func quitClicked() {
        delegate?.statusBarDidRequestQuit(self)
    }
}
