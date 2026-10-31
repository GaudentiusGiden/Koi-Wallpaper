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
    func statusBarDidSelectSeasonMode(_ controller: StatusBarController, mode: SeasonMode)
    func statusBarDidSelectManualSeason(_ controller: StatusBarController, season: PondSeason)
    func statusBarDidToggleFloatingDebris(_ controller: StatusBarController)
    func statusBarDidSelectKoiPaletteMode(_ controller: StatusBarController, mode: KoiPaletteMode)
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
    public func statusBarDidSelectSeasonMode(_ controller: StatusBarController, mode: SeasonMode) {}
    public func statusBarDidSelectManualSeason(_ controller: StatusBarController, season: PondSeason) {}
    public func statusBarDidToggleFloatingDebris(_ controller: StatusBarController) {}
    public func statusBarDidSelectKoiPaletteMode(_ controller: StatusBarController, mode: KoiPaletteMode) {}
}

public final class StatusBarController {
    public weak var delegate: StatusBarControllerDelegate?

    private var statusItem: NSStatusItem?
    private let menu = NSMenu()

    // Primary menu items
    private let headerItem = NSMenuItem(title: "Koi Wallpaper v1.0", action: nil, keyEquivalent: "")
    private let pauseStatusItem = NSMenuItem(title: "Status: Animasi Aktif (Live)", action: nil, keyEquivalent: "")
    private let pauseToggleItem = NSMenuItem(
        title: "Jeda Animasi (Jadikan Wallpaper Statis)",
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

    // Season submenu
    private let seasonMenuItem = NSMenuItem(title: "Musim Kolam (Season)", action: nil, keyEquivalent: "")
    private let seasonMenu = NSMenu(title: "Musim")
    private let autoSeasonItem = NSMenuItem(title: "Otomatis Sesuai Kalender (Auto)", action: #selector(autoSeasonSelected), keyEquivalent: "")
    private let springItem = NSMenuItem(title: "Musim Semi (Sakura)", action: #selector(springSelected), keyEquivalent: "")
    private let summerItem = NSMenuItem(title: "Musim Panas (Teratai)", action: #selector(summerSelected), keyEquivalent: "")
    private let autumnItem = NSMenuItem(title: "Musim Gugur (Momiji)", action: #selector(autumnSelected), keyEquivalent: "")
    private let winterItem = NSMenuItem(title: "Musim Dingin (Salju)", action: #selector(winterSelected), keyEquivalent: "")
    private let currentSeasonInfoItem = NSMenuItem(title: "Musim Aktif: Musim Semi", action: nil, keyEquivalent: "")
    private let floatingDebrisToggleItem = NSMenuItem(
        title: "Tampilkan Objek Mengapung",
        action: #selector(floatingDebrisToggled),
        keyEquivalent: ""
    )

    // Palette submenu
    private let paletteMenuItem = NSMenuItem(title: "Palet Ikan Koi (Palette)", action: nil, keyEquivalent: "")
    private let paletteMenu = NSMenu(title: "Palet Koi")
    private let classicPaletteItem = NSMenuItem(title: "Classic (Autentik Jepang)", action: #selector(classicPaletteSelected), keyEquivalent: "")
    private let neonPaletteItem = NSMenuItem(title: "Neon (Bioluminescent)", action: #selector(neonPaletteSelected), keyEquivalent: "")

    // Visitors submenu
    private let visitorsMenuItem = NSMenuItem(title: "Pengunjung Kolam (Visitors)", action: nil, keyEquivalent: "")
    private let visitorsMenu = NSMenu(title: "Pengunjung")
    private let automaticSwanInfoItem = NSMenuItem(title: "Rotasi otomatis: Angsa & Bebek", action: nil, keyEquivalent: "")
    private let spawnDuckItem = NSMenuItem(title: "Lepas Bebek Nagomi (Duck)", action: #selector(spawnDuckClicked), keyEquivalent: "")
    private let spawnSwanItem = NSMenuItem(title: "Lepas Angsa Megah (Swan)", action: #selector(spawnSwanClicked), keyEquivalent: "")
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
        currentSeasonInfoItem.isEnabled = false
        automaticSwanInfoItem.isEnabled = false
        visitorsStatusItem.isEnabled = false

        // Action targets
        pauseToggleItem.target = self
        interactionToggleItem.target = self
        fullscreenToggleItem.target = self
        classicPaletteItem.target = self
        neonPaletteItem.target = self
        autoTimeItem.target = self
        systemThemeItem.target = self
        dawnItem.target = self
        dayItem.target = self
        goldenHourItem.target = self
        duskItem.target = self
        nightItem.target = self
        deepClearItem.target = self
        rainItem.target = self
        autoSeasonItem.target = self
        springItem.target = self
        summerItem.target = self
        autumnItem.target = self
        winterItem.target = self
        floatingDebrisToggleItem.target = self
        calmMoodItem.target = self
        playfulMoodItem.target = self
        rainToggleItem.target = self
        spawnDuckItem.target = self
        spawnSwanItem.target = self
        spawnBallItem.target = self
        clearVisitorsItem.target = self
        launchAtLoginItem.target = self
        launchAtLoginItem.toolTip = "Buka Koi Wallpaper secara otomatis setiap kali MacBook dinyalakan atau setelah pengguna login"
        pauseOnBatteryItem.target = self
        showHUDItem.target = self
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

        // Build Season submenu
        seasonMenu.addItem(autoSeasonItem)
        seasonMenu.addItem(NSMenuItem.separator())
        seasonMenu.addItem(springItem)
        seasonMenu.addItem(summerItem)
        seasonMenu.addItem(autumnItem)
        seasonMenu.addItem(winterItem)
        seasonMenu.addItem(NSMenuItem.separator())
        seasonMenu.addItem(currentSeasonInfoItem)
        seasonMenu.addItem(NSMenuItem.separator())
        seasonMenu.addItem(floatingDebrisToggleItem)
        seasonMenuItem.submenu = seasonMenu

        // Build Mood submenu
        moodMenu.addItem(calmMoodItem)
        moodMenu.addItem(playfulMoodItem)
        moodMenuItem.submenu = moodMenu

        // Build Palette submenu
        paletteMenu.addItem(classicPaletteItem)
        paletteMenu.addItem(neonPaletteItem)
        paletteMenuItem.submenu = paletteMenu

        // Build Visitors submenu
        visitorsMenu.addItem(automaticSwanInfoItem)
        visitorsMenu.addItem(spawnDuckItem)
        visitorsMenu.addItem(spawnSwanItem)
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
        settingsMenu.addItem(resetSettingsItem)
        settingsMenuItem.submenu = settingsMenu

        // Assemble root menu
        menu.addItem(headerItem)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(pauseToggleItem)
        menu.addItem(pauseStatusItem)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(fullscreenToggleItem)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(interactionToggleItem)
        menu.addItem(interactionDescItem)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(timeOfDayMenuItem)
        menu.addItem(seasonMenuItem)
        menu.addItem(paletteMenuItem)
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
            let isManual = reasons.contains(.manual)
            if isManual {
                pauseStatusItem.title = "Status: Wallpaper Statis (Hemat Daya)"
                pauseToggleItem.title = "Lanjutkan Animasi (Live Wallpaper)"
                pauseToggleItem.state = .on
            } else {
                let reasonStr = reasons.map(\.rawValue).sorted().joined(separator: ", ")
                pauseStatusItem.title = "Status: Dijeda Otomatis (\(reasonStr))"
                pauseToggleItem.title = "Jeda Animasi (Jadikan Wallpaper Statis)"
                pauseToggleItem.state = .off
            }
        } else {
            pauseStatusItem.title = "Status: Animasi Aktif (Live)"
            pauseToggleItem.title = "Jeda Animasi (Jadikan Wallpaper Statis)"
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

    public var seasonMenuItemsTitles: [String] {
        seasonMenu.items.map(\.title)
    }

    public var seasonMenuActionTargetsValid: Bool {
        let actionItems = [autoSeasonItem, springItem, summerItem, autumnItem, winterItem, floatingDebrisToggleItem]
        return actionItems.allSatisfy { $0.target === self && $0.action != nil }
    }

    public func updateMoodState(mood: PondMood) {
        calmMoodItem.state = (mood == .calm) ? .on : .off
        playfulMoodItem.state = (mood == .playful) ? .on : .off
    }

    public func updateRainState(isRainActive: Bool) {
        rainToggleItem.state = isRainActive ? .on : .off
    }

    public func updateKoiPaletteModeState(mode: KoiPaletteMode) {
        classicPaletteItem.state = (mode == .classic) ? .on : .off
        neonPaletteItem.state = (mode == .neon) ? .on : .off
    }

    public func updateSeasonState(mode: SeasonMode, manualSeason: PondSeason, currentSeason: PondSeason, isDebrisEnabled: Bool) {
        autoSeasonItem.state = (mode == .autoCalendar) ? .on : .off
        springItem.state = (mode == .manual && manualSeason == .spring) ? .on : .off
        summerItem.state = (mode == .manual && manualSeason == .summer) ? .on : .off
        autumnItem.state = (mode == .manual && manualSeason == .autumn) ? .on : .off
        winterItem.state = (mode == .manual && manualSeason == .winter) ? .on : .off

        currentSeasonInfoItem.title = "Musim Aktif: \(currentSeason.displayName)"
        floatingDebrisToggleItem.state = isDebrisEnabled ? .on : .off
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

    public var headerTitle: String {
        headerItem.title
    }

    public func popUpMenu() {
        statusItem?.button?.performClick(nil)
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

    private static func interpolateZenSpline(_ pts: [CGPoint], subdivisions: Int = 8) -> [CGPoint] {
        guard pts.count >= 2 else { return pts }
        var result: [CGPoint] = []
        for i in 0..<(pts.count - 1) {
            let p0 = pts[max(0, i - 1)]
            let p1 = pts[i]
            let p2 = pts[i + 1]
            let p3 = pts[min(pts.count - 1, i + 2)]
            for step in 0..<subdivisions {
                let t = CGFloat(step) / CGFloat(subdivisions)
                let t2 = t * t
                let t3 = t2 * t
                let x = 0.5 * ((2.0 * p1.x) + (-p0.x + p2.x) * t + (2.0 * p0.x - 5.0 * p1.x + 4.0 * p2.x - p3.x) * t2 + (-p0.x + 3.0 * p1.x - 3.0 * p2.x + p3.x) * t3)
                let y = 0.5 * ((2.0 * p1.y) + (-p0.y + p2.y) * t + (2.0 * p0.y - 5.0 * p1.y + 4.0 * p2.y - p3.y) * t2 + (-p0.y + 3.0 * p1.y - 3.0 * p2.y + p3.y) * t3)
                result.append(CGPoint(x: x, y: y))
            }
        }
        if let last = pts.last {
            result.append(last)
        }
        return result
    }

    private static func zenKoiProfileWidth(t: CGFloat, maxHalfWidth: CGFloat) -> CGFloat {
        if t < 0.24 {
            let u = t / 0.24
            return maxHalfWidth * sqrt(max(0.0, 1.0 - (1.0 - u) * (1.0 - u)))
        } else {
            let u = (t - 0.24) / 0.76
            let taper = pow(1.0 - u, 1.35) * 0.82 + (1.0 - u) * 0.18
            return maxHalfWidth * max(0.18, taper)
        }
    }

    public static func makeStatusIcon(isInteractive: Bool = false, isPaused: Bool = false) -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size, flipped: true) { rect in
            guard let ctx = NSGraphicsContext.current?.cgContext else { return false }

            ctx.saveGState()
            let cx = rect.midX + rect.width * 0.02
            let cy = rect.midY + rect.height * 0.02
            let s = min(rect.width, rect.height)
            let arcR = s * 0.275
            let maxHalfWidth = s * 0.112
            let finScale: CGFloat = 0.92
            let tailScale: CGFloat = 0.92
            let baseAlpha: CGFloat = isPaused ? 0.45 : 1.0

            let angles: [CGFloat] = [-0.42, -0.95, -1.52, -2.10, -2.65, -3.15]
            let controlSpine = angles.map { a in
                CGPoint(x: cx + cos(a) * arcR, y: cy + sin(a) * arcR)
            }
            let spine = interpolateZenSpline(controlSpine, subdivisions: 8)
            let n = spine.count
            var tangents: [CGPoint] = []
            var normals: [CGPoint] = []

            for i in 0..<n {
                let prev = spine[max(0, i - 1)]
                let next = spine[min(n - 1, i + 1)]
                let dx = next.x - prev.x
                let dy = next.y - prev.y
                let len = max(0.0001, hypot(dx, dy))
                let tx = dx / len
                let ty = dy / len
                tangents.append(CGPoint(x: tx, y: ty))
                normals.append(CGPoint(x: -ty, y: tx))
            }

            var leftPts: [CGPoint] = []
            var rightPts: [CGPoint] = []
            for i in 0..<n {
                let t = CGFloat(i) / CGFloat(n - 1)
                let w = zenKoiProfileWidth(t: t, maxHalfWidth: maxHalfWidth)
                let p = spine[i]
                let nm = normals[i]
                leftPts.append(CGPoint(x: p.x + nm.x * w, y: p.y + nm.y * w))
                rightPts.append(CGPoint(x: p.x - nm.x * w, y: p.y - nm.y * w))
            }

            let torso = CGMutablePath()
            let noseTip = CGPoint(
                x: spine[0].x - tangents[0].x * maxHalfWidth * 0.22,
                y: spine[0].y - tangents[0].y * maxHalfWidth * 0.22
            )
            torso.move(to: noseTip)
            for pt in leftPts {
                torso.addLine(to: pt)
            }
            for pt in rightPts.reversed() {
                torso.addLine(to: pt)
            }
            torso.closeSubpath()

            // Swept-back pectoral fins
            let finStartIdx = max(1, Int(Double(n - 1) * 0.21))
            let finEndIdx = min(n - 1, Int(Double(n - 1) * 0.39))
            let finMidIdx = (finStartIdx + finEndIdx) / 2
            let finTan = tangents[finMidIdx]
            let finNorm = normals[finMidIdx]
            let finSpan = maxHalfWidth * 1.18 * finScale
            let finSweep = maxHalfWidth * 1.35 * finScale

            let leftFin = CGMutablePath()
            let lStart = leftPts[finStartIdx]
            let lEnd = leftPts[finEndIdx]
            let lTip = CGPoint(
                x: lStart.x + finNorm.x * finSpan + finTan.x * finSweep * 0.72,
                y: lStart.y + finNorm.y * finSpan + finTan.y * finSweep * 0.72
            )
            leftFin.move(to: lStart)
            leftFin.addQuadCurve(
                to: lTip,
                control: CGPoint(
                    x: lStart.x + finNorm.x * finSpan * 1.05 + finTan.x * finSweep * 0.08,
                    y: lStart.y + finNorm.y * finSpan * 1.05 + finTan.y * finSweep * 0.08
                )
            )
            leftFin.addQuadCurve(
                to: lEnd,
                control: CGPoint(
                    x: lEnd.x + finNorm.x * finSpan * 0.45 + finTan.x * finSweep * 0.25,
                    y: lEnd.y + finNorm.y * finSpan * 0.45 + finTan.y * finSweep * 0.25
                )
            )
            leftFin.closeSubpath()

            let rightFin = CGMutablePath()
            let rStart = rightPts[finStartIdx]
            let rEnd = rightPts[finEndIdx]
            let rTip = CGPoint(
                x: rStart.x - finNorm.x * (finSpan * 0.92) + finTan.x * finSweep * 0.72,
                y: rStart.y - finNorm.y * (finSpan * 0.92) + finTan.y * finSweep * 0.72
            )
            rightFin.move(to: rStart)
            rightFin.addQuadCurve(
                to: rTip,
                control: CGPoint(
                    x: rStart.x - finNorm.x * finSpan * 0.96 + finTan.x * finSweep * 0.08,
                    y: rStart.y - finNorm.y * finSpan * 0.96 + finTan.y * finSweep * 0.08
                )
            )
            rightFin.addQuadCurve(
                to: rEnd,
                control: CGPoint(
                    x: rEnd.x - finNorm.x * finSpan * 0.42 + finTan.x * finSweep * 0.25,
                    y: rEnd.y - finNorm.y * finSpan * 0.42 + finTan.y * finSweep * 0.25
                )
            )
            rightFin.closeSubpath()

            // Flowing crescent caudal tail
            let tailBase = spine[n - 1]
            let tailTan = tangents[n - 1]
            let tailNorm = normals[n - 1]
            let tailLen = maxHalfWidth * 2.05 * tailScale
            let tailSpread = maxHalfWidth * 1.55 * tailScale

            let lobeL = CGPoint(
                x: tailBase.x + tailTan.x * tailLen + tailNorm.x * tailSpread,
                y: tailBase.y + tailTan.y * tailLen + tailNorm.y * tailSpread
            )
            let notch = CGPoint(
                x: tailBase.x + tailTan.x * (tailLen * 0.56) + tailNorm.x * (tailSpread * 0.06),
                y: tailBase.y + tailTan.y * (tailLen * 0.56) + tailNorm.y * (tailSpread * 0.06)
            )
            let lobeR = CGPoint(
                x: tailBase.x + tailTan.x * (tailLen * 0.92) - tailNorm.x * (tailSpread * 0.85),
                y: tailBase.y + tailTan.y * (tailLen * 0.92) - tailNorm.y * (tailSpread * 0.85)
            )

            let tail = CGMutablePath()
            tail.move(to: leftPts[n - 1])
            tail.addQuadCurve(
                to: lobeL,
                control: CGPoint(
                    x: tailBase.x + tailTan.x * tailLen * 0.45 + tailNorm.x * tailSpread * 0.98,
                    y: tailBase.y + tailTan.y * tailLen * 0.45 + tailNorm.y * tailSpread * 0.98
                )
            )
            tail.addQuadCurve(
                to: notch,
                control: CGPoint(
                    x: tailBase.x + tailTan.x * tailLen * 0.82 + tailNorm.x * tailSpread * 0.28,
                    y: tailBase.y + tailTan.y * tailLen * 0.82 + tailNorm.y * tailSpread * 0.28
                )
            )
            tail.addQuadCurve(
                to: lobeR,
                control: CGPoint(
                    x: tailBase.x + tailTan.x * tailLen * 0.78 - tailNorm.x * tailSpread * 0.25,
                    y: tailBase.y + tailTan.y * tailLen * 0.78 - tailNorm.y * tailSpread * 0.25
                )
            )
            tail.addQuadCurve(
                to: rightPts[n - 1],
                control: CGPoint(
                    x: tailBase.x + tailTan.x * tailLen * 0.42 - tailNorm.x * tailSpread * 0.82,
                    y: tailBase.y + tailTan.y * tailLen * 0.42 - tailNorm.y * tailSpread * 0.82
                )
            )
            tail.closeSubpath()

            // Render Zen Arc Koi body, tail, and fins
            ctx.setFillColor(gray: 1.0, alpha: baseAlpha)
            ctx.addPath(torso)
            ctx.fillPath()
            ctx.addPath(tail)
            ctx.fillPath()
            ctx.addPath(leftFin)
            ctx.fillPath()
            ctx.addPath(rightFin)
            ctx.fillPath()

            // Complementary Enso ripple arc on opposite side
            ctx.setStrokeColor(gray: 1.0, alpha: baseAlpha)
            ctx.setLineWidth(s * 0.072)
            ctx.setLineCap(.round)
            let rippleEnd: CGFloat = (isPaused || isInteractive) ? 1.35 : 1.80
            ctx.addArc(center: CGPoint(x: cx, y: cy), radius: arcR, startAngle: 0.15, endAngle: rippleEnd, clockwise: false)
            ctx.strokePath()

            // Water pearl dot near nose
            let dropCenter = CGPoint(x: cx + cos(-0.10) * arcR, y: cy + sin(-0.10) * arcR)
            let dotR = s * 0.052
            ctx.fillEllipse(in: CGRect(x: dropCenter.x - dotR, y: dropCenter.y - dotR, width: dotR * 2, height: dotR * 2))

            ctx.restoreGState()

            // Subtle state badges in bottom-right corner (flipped coordinates: maxY is bottom)
            if isPaused {
                ctx.setFillColor(gray: 1.0, alpha: 0.90)
                ctx.fill(CGRect(x: rect.maxX - 5.5, y: rect.maxY - 6.0, width: 1.5, height: 4.5))
                ctx.fill(CGRect(x: rect.maxX - 3.0, y: rect.maxY - 6.0, width: 1.5, height: 4.5))
            } else if isInteractive {
                ctx.setFillColor(gray: 1.0, alpha: 0.95)
                ctx.fillEllipse(in: CGRect(x: rect.maxX - 4.5, y: rect.maxY - 5.0, width: 3.5, height: 3.5))
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

    @objc private func classicPaletteSelected() {
        delegate?.statusBarDidSelectKoiPaletteMode(self, mode: .classic)
    }

    @objc private func neonPaletteSelected() {
        delegate?.statusBarDidSelectKoiPaletteMode(self, mode: .neon)
    }

    @objc private func autoSeasonSelected() {
        delegate?.statusBarDidSelectSeasonMode(self, mode: .autoCalendar)
    }

    @objc private func springSelected() {
        delegate?.statusBarDidSelectManualSeason(self, season: .spring)
    }

    @objc private func summerSelected() {
        delegate?.statusBarDidSelectManualSeason(self, season: .summer)
    }

    @objc private func autumnSelected() {
        delegate?.statusBarDidSelectManualSeason(self, season: .autumn)
    }

    @objc private func winterSelected() {
        delegate?.statusBarDidSelectManualSeason(self, season: .winter)
    }

    @objc private func floatingDebrisToggled() {
        delegate?.statusBarDidToggleFloatingDebris(self)
    }

    @objc private func fullscreenToggled() {
        delegate?.statusBarDidToggleFullscreen(self)
    }

    @objc private func spawnDuckClicked() {
        delegate?.statusBarDidRequestSpawnVisitor(self, type: .duck)
    }

    @objc private func spawnSwanClicked() {
        delegate?.statusBarDidRequestSpawnVisitor(self, type: .swan)
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

    @objc private func quitClicked() {
        delegate?.statusBarDidRequestQuit(self)
    }
}
