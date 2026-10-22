import AppKit

/// A dedicated borderless, high-level window for the manual fullscreen pond presentation.
/// Unlike WallpaperWindow (which strictly disallows key window status to avoid stealing focus on the desktop),
/// FullscreenPondWindow accepts key and main window status so that user keyboard input
/// (specifically the Escape key) and mouse interactions are handled reliably.
open class FullscreenPondWindow: NSWindow {

    /// Callback invoked when the user requests exit via the Escape key or window cancel action.
    public var onEscapePressed: (() -> Void)?

    public override var canBecomeKey: Bool {
        return true
    }

    public override var canBecomeMain: Bool {
        return true
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

        // Float above desktop icons and standard application windows during manual fullscreen mode.
        self.level = NSWindow.Level(Int(CGWindowLevelForKey(.floatingWindow)))
        self.collectionBehavior = [
            .canJoinAllSpaces,
            .fullScreenAuxiliary,
            .stationary
        ]
    }

    public override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if event.keyCode == 53 { // Escape key virtual code
            onEscapePressed?()
            return true
        }
        return super.performKeyEquivalent(with: event)
    }

    public override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 || event.charactersIgnoringModifiers == "\u{1b}" {
            onEscapePressed?()
            return
        }
        super.keyDown(with: event)
    }

    public override func cancelOperation(_ sender: Any?) {
        // AppKit selector invoked when Escape is pressed
        onEscapePressed?()
    }
}
