import AppKit
import OSLog

private let logger = Logger(subsystem: "com.koiwallpaper.KoiWallpaper", category: "ManualFullscreen")

/// Represents the desktop state captured before entering manual fullscreen mode,
/// allowing full restoration when the user exits.
public struct PreviousDesktopState: Sendable {
    public let interactionMode: InputInteractionMode
    public let isGloballyPaused: Bool
}

/// Orchestrates manual fullscreen pond presentation across connected screens.
///
/// Key guarantees:
/// 1. Explicit entry and clear exit: Can be exited via the Escape key, menu bar item, or programmatically.
/// 2. Restoration of previous desktop state: Restores input mode, window levels, and desktop state upon exit.
/// 3. Zero system interference: Does not alter macOS system sleep, screen lock, or display sleep timers.
/// 4. Decoupled from idle policies: Manual fullscreen is strictly distinct from automatic idle decisions.
public final class ManualFullscreenController {

    public private(set) var isFullscreen: Bool = false
    public private(set) var previousState: PreviousDesktopState?
    public private(set) var fullscreenWindows: [FullscreenPondWindow] = []

    public weak var screenManager: ScreenManager?
    public var onFullscreenStateChanged: ((Bool) -> Void)?

    public init(screenManager: ScreenManager? = nil) {
        self.screenManager = screenManager
    }

    deinit {
        exitFullscreen()
    }

    /// Enters manual fullscreen mode, displaying high-level pond presentation windows.
    public func enterFullscreen(targetScreen: NSScreen? = nil) {
        guard !isFullscreen else { return }
        guard let screenMgr = screenManager else {
            logger.warning("Cannot enter fullscreen: screenManager is not set.")
            return
        }

        logger.info("Entering manual fullscreen mode...")

        // 1. Capture previous desktop state
        let wasPausedBeforeFullscreen = screenMgr.isGloballyPaused
        previousState = PreviousDesktopState(
            interactionMode: screenMgr.currentMode,
            isGloballyPaused: wasPausedBeforeFullscreen
        )

        // Pause underlying desktop wallpaper controllers so simulation is not advanced twice
        screenMgr.applyGlobalPause(true)

        // 2. Identify screens to cover (target screen or all active screens)
        let screens = targetScreen.map { [$0] } ?? screenMgr.screenProvider()
        var newWindows: [FullscreenPondWindow] = []

        for screen in screens {
            let window = FullscreenPondWindow(screen: screen)
            window.onEscapePressed = { [weak self] in
                self?.exitFullscreen()
            }

            // Find matching simulation from screenManager to ensure continuity of entities
            let existingSim = screenMgr.controllers.first(where: {
                $0.screen === screen || $0.screen.frame == screen.frame
            })?.wallpaperView.simulation

            let viewFrame = NSRect(origin: .zero, size: screen.frame.size)
            let view = WallpaperView(frame: viewFrame, simulation: existingSim)
            view.theme = screenMgr.currentTheme
            view.showHUD = screenMgr.currentShowHUD
            view.isInteractionMode = true // Full interaction in fullscreen mode
            view.isFullscreenPresentation = true
            view.layer?.contentsScale = screen.backingScaleFactor

            if !wasPausedBeforeFullscreen {
                view.startAnimationTimer()
            }

            window.contentView = view
            window.orderFrontRegardless()
            newWindows.append(window)
        }

        self.fullscreenWindows = newWindows
        self.isFullscreen = true

        // Make primary fullscreen window key to receive Escape key events
        if let primary = newWindows.first {
            primary.makeKeyAndOrderFront(nil)
            NSApplication.shared.activate(ignoringOtherApps: true)
        }

        onFullscreenStateChanged?(true)
        logger.info("Manual fullscreen active with \(newWindows.count) window(s).")
    }

    /// Exits manual fullscreen mode and cleanly restores the previous desktop state.
    public func exitFullscreen() {
        guard isFullscreen else { return }
        logger.info("Exiting manual fullscreen mode and restoring desktop state...")

        // 1. Clean up and close all fullscreen windows
        for window in fullscreenWindows {
            if let view = window.contentView as? WallpaperView {
                view.stopAnimationTimer()
            }
            window.contentView = nil
            window.orderOut(nil)
            window.close()
        }
        fullscreenWindows.removeAll()

        // 2. Restore previous desktop state
        if let previous = previousState, let screenMgr = screenManager {
            screenMgr.applyInteractionMode(previous.interactionMode)
            screenMgr.applyGlobalPause(previous.isGloballyPaused)
            for controller in screenMgr.controllers {
                controller.window.applyMode(previous.interactionMode)
            }
        }
        previousState = nil
        isFullscreen = false

        onFullscreenStateChanged?(false)
        logger.info("Desktop state restored successfully.")
    }

    /// Toggles between manual fullscreen and desktop wallpaper mode.
    public func toggleFullscreen() {
        if isFullscreen {
            exitFullscreen()
        } else {
            enterFullscreen()
        }
    }
}
