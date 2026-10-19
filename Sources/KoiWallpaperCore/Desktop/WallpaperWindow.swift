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
        self.animationBehavior = .none
        self.backgroundColor = NSColor(
            calibratedRed: 0.05,
            green: 0.16,
            blue: 0.14,
            alpha: 1.0
        )

        // Ensure the window appears on all Spaces, stays stationary during Mission Control / Expose,
        // does not participate in Cmd+` window cycling, and does not conflict with fullscreen spaces.
        self.collectionBehavior = [
            .canJoinAllSpaces,
            .stationary,
            .ignoresCycle,
            .fullScreenNone
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
