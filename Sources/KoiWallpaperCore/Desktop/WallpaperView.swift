import AppKit

public final class WallpaperView: NSView {
    public var inputCoordinator: InputCoordinator?

    public var backgroundColor: NSColor = NSColor(
        calibratedRed: 0.05,
        green: 0.16,
        blue: 0.14,
        alpha: 1.0
    ) {
        didSet {
            layer?.backgroundColor = backgroundColor.cgColor
            needsDisplay = true
        }
    }

    public var isInteractionMode: Bool = false {
        didSet {
            needsDisplay = true
        }
    }

    public var isPaused: Bool = false {
        didSet {
            guard oldValue != isPaused else { return }
            if isPaused {
                rippleTimer?.invalidate()
                rippleTimer = nil
            } else if !ripples.isEmpty {
                startRippleAnimation()
            }
            needsDisplay = true
        }
    }

    public var activeRippleCount: Int {
        ripples.count
    }

    public var isAnimating: Bool {
        rippleTimer != nil
    }

    private struct Ripple {
        let center: CGPoint
        var radius: CGFloat
        var alpha: CGFloat
        let isFood: Bool
    }

    private var ripples: [Ripple] = []
    private var rippleTimer: Timer?

    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = backgroundColor.cgColor
        layerContentsRedrawPolicy = .onSetNeedsDisplay
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        wantsLayer = true
        layer?.backgroundColor = backgroundColor.cgColor
        layerContentsRedrawPolicy = .onSetNeedsDisplay
    }

    public override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        // Draw pond base color
        backgroundColor.setFill()
        dirtyRect.fill()

        // Draw ripples from user interaction
        for ripple in ripples {
            let strokeColor = ripple.isFood
                ? NSColor.systemOrange.withAlphaComponent(ripple.alpha)
                : NSColor.cyan.withAlphaComponent(ripple.alpha)
            strokeColor.setStroke()

            let path = NSBezierPath(
                ovalIn: NSRect(
                    x: ripple.center.x - ripple.radius,
                    y: ripple.center.y - ripple.radius,
                    width: ripple.radius * 2,
                    height: ripple.radius * 2
                )
            )
            path.lineWidth = ripple.isFood ? 3.0 : 1.5
            path.stroke()
        }

        // Draw interaction mode indicator if active
        if isInteractionMode {
            drawInteractionModeBanner()
        }
    }

    private func drawInteractionModeBanner() {
        let bannerRect = NSRect(x: 24, y: bounds.height - 70, width: 480, height: 46)
        let bgPath = NSBezierPath(roundedRect: bannerRect, xRadius: 8, yRadius: 8)
        NSColor.black.withAlphaComponent(0.65).setFill()
        bgPath.fill()

        NSColor.systemTeal.withAlphaComponent(0.8).setStroke()
        bgPath.lineWidth = 1.0
        bgPath.stroke()

        let title = "Mode Interaksi Aktif"
        let subtitle = "Klik memanggil air · Option+Klik memberi makan · Menu Bar untuk kembali"

        let titleAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 13, weight: .semibold),
            .foregroundColor: NSColor.white
        ]
        let subAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 11, weight: .regular),
            .foregroundColor: NSColor.lightGray
        ]

        title.draw(at: NSPoint(x: bannerRect.minX + 14, y: bannerRect.minY + 24), withAttributes: titleAttrs)
        subtitle.draw(at: NSPoint(x: bannerRect.minX + 14, y: bannerRect.minY + 8), withAttributes: subAttrs)
    }

    // MARK: - Mouse Event Handling

    public override func mouseDown(with event: NSEvent) {
        guard isInteractionMode, !isPaused else { return }

        let location = convert(event.locationInWindow, from: nil)
        let isOption = event.modifierFlags.contains(.option)

        // Spawn visual ripple
        addRipple(at: location, isFood: isOption)

        // Forward to coordinator
        inputCoordinator?.handleClick(at: location, modifierFlags: event.modifierFlags)
    }

    public var firstRippleRadius: CGFloat? {
        ripples.first?.radius
    }

    public func addRipple(at point: CGPoint, isFood: Bool) {
        guard !isPaused else { return }
        let newRipple = Ripple(center: point, radius: 4.0, alpha: 1.0, isFood: isFood)
        ripples.append(newRipple)

        if rippleTimer == nil {
            startRippleAnimation()
        }
        needsDisplay = true
    }

    private func startRippleAnimation() {
        guard rippleTimer == nil, !isPaused else { return }

        let timer = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }

            if self.isPaused {
                timer.invalidate()
                self.rippleTimer = nil
                return
            }

            var updated: [Ripple] = []
            for var r in self.ripples {
                r.radius += r.isFood ? 1.5 : 2.5
                r.alpha -= r.isFood ? 0.02 : 0.03
                if r.alpha > 0 {
                    updated.append(r)
                }
            }

            self.ripples = updated
            self.needsDisplay = true

            if self.ripples.isEmpty {
                timer.invalidate()
                self.rippleTimer = nil
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.rippleTimer = timer
    }
}
