import AppKit

/// WallpaperWindow is a borderless, non-activating window that serves as the desktop host.
/// It stays pinned to the desktop level across all Spaces and avoids stealing focus.
public final class WallpaperWindow: NSWindow {

    public override var canBecomeKey: Bool {
        return false
    }

    public override var canBecomeMain: Bool {
        return false
    }

    public init(screen: NSScreen) {
        super.init(
            contentRect: screen.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        self.isOpaque = true
        self.hasShadow = false
        self.hidesOnDeactivate = false
        self.isReleasedWhenClosed = false

        // Ensure the window appears on all Spaces, stays stationary during Mission Control / Expose,
        // and does not participate in Cmd+` window cycling.
        self.collectionBehavior = [
            .canJoinAllSpaces,
            .stationary,
            .ignoresCycle,
            .fullScreenAuxiliary
        ]

        applyMode(.clickThrough)
    }

    public func updateFrame(for screen: NSScreen) {
        setFrame(screen.frame, display: true)
    }

    public func applyMode(_ mode: InputInteractionMode) {
        switch mode {
        case .clickThrough:
            self.ignoresMouseEvents = true
            // Place window at desktop level, behind desktop icons (Finder)
            self.level = NSWindow.Level(Int(CGWindowLevelForKey(.desktopWindow)))
            self.orderBack(nil)
        case .interactive:
            self.ignoresMouseEvents = false
            // Raise window just above desktop icons so it captures mouse events
            self.level = NSWindow.Level(Int(CGWindowLevelForKey(.desktopIconWindow)) + 1)
            self.orderFront(nil)
        }
    }
}
