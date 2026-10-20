import AppKit

public final class DesktopWindowController {
    public let window: WallpaperWindow
    public let wallpaperView: WallpaperView

    public init(screen: NSScreen) {
        self.window = WallpaperWindow(screen: screen)
        self.wallpaperView = WallpaperView(frame: screen.frame)
        self.window.contentView = self.wallpaperView
    }

    public func show() {
        window.orderBack(nil)
    }

    public func updateScreenConfiguration() {
        guard let screen = NSScreen.main ?? NSScreen.screens.first else { return }
        window.updateFrame(for: screen)
        wallpaperView.frame = NSRect(origin: .zero, size: screen.frame.size)
        wallpaperView.simulation.resize(width: Double(screen.frame.width), height: Double(screen.frame.height))
        wallpaperView.needsDisplay = true
    }

    public func applyInteractionMode(_ mode: InputInteractionMode) {
        window.applyMode(mode)
        wallpaperView.isInteractionMode = (mode == .interactive)
    }
}
