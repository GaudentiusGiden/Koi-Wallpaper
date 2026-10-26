import AppKit
import Foundation
import ScreenSaver
import OSLog
import KoiWallpaperCore

private let logger = Logger(subsystem: "com.koiwallpaper.KoiWallpaper", category: "ScreenSaver")

/// KoiWallpaperSaverView hosts the living pond simulation within the macOS Lock Screen and Screen Saver.
@objc(KoiWallpaperSaverView)
open class KoiWallpaperSaverView: ScreenSaverView {
    public private(set) var wallpaperView: WallpaperView?
    public let settingsManager: SettingsManager
    public private(set) var timeOfDayController: TimeOfDayController?

    public override init?(frame: NSRect, isPreview: Bool) {
        self.settingsManager = SettingsManager(store: SharedFileSettingsStore())
        super.init(frame: frame, isPreview: isPreview)
        self.animationTimeInterval = 1.0 / 30.0
        setupPondView(frame: frame)
    }

    required public init?(coder: NSCoder) {
        self.settingsManager = SettingsManager(store: SharedFileSettingsStore())
        super.init(coder: coder)
        self.animationTimeInterval = 1.0 / 30.0
        setupPondView(frame: self.bounds)
    }

    private func setupPondView(frame: NSRect) {
        wantsLayer = true
        let view = WallpaperView(frame: NSRect(origin: .zero, size: frame.size))
        view.autoresizingMask = [.width, .height]
        view.isInteractionMode = false
        view.showHUD = false

        applySettings(to: view)
        addSubview(view)
        self.wallpaperView = view
    }

    public func applySettings(to view: WallpaperView) {
        let settings = settingsManager.settings

        let tod = TimeOfDayController(
            mode: settings.timeOfDayMode,
            manualPhase: settings.manualTimePhase,
            manualTheme: settings.manualTheme
        )
        tod.onThemeChanged = { [weak view] newTheme in
            view?.setTheme(newTheme, animated: true)
        }
        self.timeOfDayController = tod

        view.setTheme(tod.currentTheme, animated: false)
        view.pondMood = settings.pondMood
        view.isRainActive = settings.isRainActive
    }

    open override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        wallpaperView?.frame = NSRect(origin: .zero, size: newSize)
        wallpaperView?.setFrameSize(newSize)
    }

    open override func startAnimation() {
        super.startAnimation()
        if let view = wallpaperView {
            applySettings(to: view)
            view.isPaused = false
            view.startAnimationTimer()
        }
    }

    open override func stopAnimation() {
        super.stopAnimation()
        wallpaperView?.isPaused = true
        wallpaperView?.stopAnimationTimer()
    }

    open override func animateOneFrame() {
        // Notifies WindowServer layer dirty rects in synchronization with ScreenSaverEngine
        wallpaperView?.needsDisplay = true
    }

    open override var hasConfigureSheet: Bool {
        false
    }
}
