import AppKit

/// A native-resolution HUD above the scene sublayers. Hit testing always passes
/// through to the existing parent view, so mouse and keyboard routing are unchanged.
public final class PondOverlayView: NSView {
    public var drawOverlay: ((CGContext) -> Void)?
    public override var isOpaque: Bool { false }
    public override func hitTest(_ point: NSPoint) -> NSView? { nil }
    public override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        context.clear(bounds)
        drawOverlay?(context)
    }
}
