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
    private var occlusionObserver: Any?
    private var wasAttachedToWindow = false

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

    deinit {
        if let observer = occlusionObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        wallpaperView?.stopAnimationTimer()
    }

    private func setupPondView(frame: NSRect) {
        wantsLayer = true
        let view = WallpaperView(frame: NSRect(origin: .zero, size: frame.size))
        view.autoresizingMask = [.width, .height]
        view.isInteractionMode = false
        view.showHUD = false

        if isPreview {
            view.isBatteryEcoMode = true
        }

        applySettings(to: view)
        // Ensure the internal timer does not run until startAnimation() is called by the system
        view.isPaused = true
        view.stopAnimationTimer()

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

    open override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window != nil {
            wasAttachedToWindow = true
            setupOcclusionObservation()
            evaluateActiveState()
        } else if wasAttachedToWindow {
            // View was detached from its window hierarchy: immediately freeze animation
            wallpaperView?.isPaused = true
            wallpaperView?.stopAnimationTimer()
        }
    }

    open override func viewWillMove(toWindow newWindow: NSWindow?) {
        super.viewWillMove(toWindow: newWindow)
        if let observer = occlusionObserver {
            NotificationCenter.default.removeObserver(observer)
            occlusionObserver = nil
        }
    }

    private func setupOcclusionObservation() {
        if let observer = occlusionObserver {
            NotificationCenter.default.removeObserver(observer)
            occlusionObserver = nil
        }
        guard let window = self.window else { return }
        occlusionObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didChangeOcclusionStateNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            self?.evaluateActiveState()
        }
    }

    private func evaluateActiveState() {
        guard isAnimating else { return }
        if let window = self.window {
            let isVisible = window.occlusionState.contains(.visible) && !isHiddenOrHasHiddenAncestor
            if isVisible {
                if wallpaperView?.isPaused == true {
                    wallpaperView?.isPaused = false
                    wallpaperView?.startAnimationTimer()
                }
            } else {
                if wallpaperView?.isPaused == false {
                    wallpaperView?.isPaused = true
                    wallpaperView?.stopAnimationTimer()
                }
            }
        }
    }

    open override func startAnimation() {
        super.startAnimation()
        if let window = self.window, !window.occlusionState.contains(.visible) {
            // Attached to a window but currently occluded (e.g. background tab or closed preview)
            wallpaperView?.isPaused = true
            wallpaperView?.stopAnimationTimer()
            return
        }
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
        guard isAnimating else { return }
        if let window = self.window, !window.occlusionState.contains(.visible) {
            return
        }
        // If internal timer is already ticking, animateOneFrame does not need to duplicate needsDisplay
        if wallpaperView?.isAnimating != true {
            wallpaperView?.needsDisplay = true
        }
    }

    open override var hasConfigureSheet: Bool {
        false
    }
}
