import AppKit
import Foundation

public final class WallpaperView: NSView {
    public var inputCoordinator: InputCoordinator?

    public let simulation: PondSimulation
    public let renderer: PondRenderer

    public var timeOfDayPhase: TimeOfDayPhase = .day {
        didSet {
            if oldValue != timeOfDayPhase {
                needsDisplay = true
            }
        }
    }

    public var isInteractionMode: Bool = false {
        didSet {
            needsDisplay = true
        }
    }

    public var showHUD: Bool = false {
        didSet {
            needsDisplay = true
        }
    }

    public var isPaused: Bool = false {
        didSet {
            guard oldValue != isPaused else { return }
            simulation.isPaused = isPaused
            if isPaused {
                stopAnimationTimer()
            } else {
                startAnimationTimer()
            }
            needsDisplay = true
        }
    }

    // Backward-compatible properties for verification suites
    public var activeRippleCount: Int {
        simulation.ripples.count
    }

    public var firstRippleRadius: CGFloat? {
        simulation.ripples.first.map { CGFloat($0.radius) }
    }

    public var isAnimating: Bool {
        animationTimer != nil && !isPaused
    }

    private var animationTimer: Timer?
    private var lastFrameTime: TimeInterval = 0.0

    /// Monotonically increasing count of animation timer callback firings.
    public private(set) var totalTimerTicks: Int = 0

    /// Measured frequency (Hz or ticks/sec) of the RunLoop animation timer callbacks.
    /// Note: This measures timer invocation cadence, NOT display VSYNC hardware frame presentation.
    public private(set) var timerCadenceFPS: Double = 60.0

    /// Backward-compatible alias for timer callback cadence.
    public var currentFPS: Double {
        timerCadenceFPS
    }

    public init(frame frameRect: NSRect, simulation: PondSimulation? = nil) {
        let simBounds = PondBounds(
            width: max(100.0, Double(frameRect.width)),
            height: max(100.0, Double(frameRect.height))
        )
        self.simulation = simulation ?? PondSimulation(bounds: simBounds)
        self.renderer = PondRenderer()
        super.init(frame: frameRect)

        wantsLayer = true
        layerContentsRedrawPolicy = .onSetNeedsDisplay
        layer?.contentsScale = NSScreen.main?.backingScaleFactor ?? 2.0
        startAnimationTimer()
    }

    required init?(coder: NSCoder) {
        let simBounds = PondBounds(width: 1024.0, height: 640.0)
        self.simulation = PondSimulation(bounds: simBounds)
        self.renderer = PondRenderer()
        super.init(coder: coder)

        wantsLayer = true
        layerContentsRedrawPolicy = .onSetNeedsDisplay
        layer?.contentsScale = NSScreen.main?.backingScaleFactor ?? 2.0
        startAnimationTimer()
    }

    deinit {
        stopAnimationTimer()
    }

    public override func viewDidChangeBackingProperties() {
        super.viewDidChangeBackingProperties()
        let scale = window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 1.0
        layer?.contentsScale = scale
        needsDisplay = true
    }

    public override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        simulation.resize(width: Double(newSize.width), height: Double(newSize.height))
    }

    // MARK: - Animation Loop & Stasis Control

    public func startAnimationTimer() {
        guard animationTimer == nil, !isPaused else { return }
        lastFrameTime = CACurrentMediaTime()

        let timer = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            guard let self = self, !self.isPaused else { return }
            self.totalTimerTicks += 1
            let now = CACurrentMediaTime()
            let dt = (self.lastFrameTime > 0) ? (now - self.lastFrameTime) : (1.0 / 60.0)
            self.lastFrameTime = now

            if dt > 0.005 && dt < 0.10 {
                let instantCadence = 1.0 / dt
                self.timerCadenceFPS = self.timerCadenceFPS * 0.9 + instantCadence * 0.1
            }

            self.simulation.advance(deltaTime: dt)
            self.needsDisplay = true
        }
        RunLoop.main.add(timer, forMode: .common)
        RunLoop.main.add(timer, forMode: .default)
        if RunLoop.current != RunLoop.main {
            RunLoop.current.add(timer, forMode: .common)
            RunLoop.current.add(timer, forMode: .default)
        }
        self.animationTimer = timer
    }

    public func stopAnimationTimer() {
        animationTimer?.invalidate()
        animationTimer = nil
    }

    // MARK: - Drawing & Layer Composition

    public override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let context = NSGraphicsContext.current?.cgContext else { return }

        // Render full layered pond simulation with active time of day lighting
        renderer.render(
            simulation: simulation,
            in: context,
            rect: bounds,
            phase: timeOfDayPhase
        )

        // Draw interaction banner when in explicit interactive capture mode
        if isInteractionMode {
            drawInteractionModeBanner()
        }

        // Draw diagnostic HUD if enabled
        if showHUD {
            drawHUD(in: context)
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

    private func drawHUD(in context: CGContext) {
        let hudRect = NSRect(x: 16, y: bounds.height - 110, width: 380, height: 94)
        let hudPath = NSBezierPath(roundedRect: hudRect, xRadius: 8, yRadius: 8)

        NSColor.black.withAlphaComponent(0.72).setFill()
        hudPath.fill()
        NSColor.white.withAlphaComponent(0.2).setStroke()
        hudPath.lineWidth = 1.0
        hudPath.stroke()

        let statusText = simulation.isPaused ? "PAUSED" : "RUNNING"
        let statusColor = simulation.isPaused ? NSColor.systemYellow : NSColor.systemGreen

        let titleAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 12, weight: .bold),
            .foregroundColor: NSColor.white
        ]
        let statusAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 12, weight: .bold),
            .foregroundColor: statusColor
        ]
        let bodyAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 11, weight: .regular),
            .foregroundColor: NSColor.lightGray
        ]

        "Koi Wallpaper (M3) — ".draw(at: NSPoint(x: hudRect.minX + 12, y: hudRect.maxY - 22), withAttributes: titleAttrs)
        statusText.draw(at: NSPoint(x: hudRect.minX + 165, y: hudRect.maxY - 22), withAttributes: statusAttrs)

        let stats = String(
            format: "Cadence: %.0f Hz  ·  Koi: %d  ·  Pellets: %d/%d  ·  Ripples: %d/%d",
            timerCadenceFPS,
            simulation.fish.count,
            simulation.pellets.count,
            simulation.maxPellets,
            simulation.ripples.count,
            simulation.maxRipples
        )
        stats.draw(at: NSPoint(x: hudRect.minX + 12, y: hudRect.maxY - 42), withAttributes: bodyAttrs)

        let phaseStr = "Phase: \(timeOfDayPhase.displayName)"
        phaseStr.draw(at: NSPoint(x: hudRect.minX + 12, y: hudRect.maxY - 62), withAttributes: bodyAttrs)

        let modeStr = isInteractionMode ? "Mode: Interactive Capture" : "Mode: Finder Click-Through"
        modeStr.draw(at: NSPoint(x: hudRect.minX + 12, y: hudRect.maxY - 80), withAttributes: bodyAttrs)
    }

    // MARK: - Mouse Event Handling

    public override func mouseDown(with event: NSEvent) {
        guard isInteractionMode, !isPaused else { return }

        let location = convert(event.locationInWindow, from: nil)
        let isOption = event.modifierFlags.contains(.option)
        let simPoint = PondVector(x: Double(location.x), y: Double(location.y))

        if isOption {
            simulation.handleFoodDrop(at: simPoint)
        } else {
            simulation.handleWaterClick(at: simPoint)
        }

        // Forward to coordinator
        inputCoordinator?.handleClick(at: location, modifierFlags: event.modifierFlags)
        needsDisplay = true
    }

    public func addRipple(at point: CGPoint, isFood: Bool) {
        guard !isPaused else { return }
        let simPoint = PondVector(x: Double(point.x), y: Double(point.y))
        if isFood {
            simulation.handleFoodDrop(at: simPoint)
        } else {
            simulation.handleWaterClick(at: simPoint)
        }
        if animationTimer == nil {
            startAnimationTimer()
        }
        needsDisplay = true
    }
}
