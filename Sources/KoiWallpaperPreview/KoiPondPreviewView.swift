import AppKit
import Foundation
import KoiWallpaperCore

public final class KoiPondPreviewView: NSView {
    public let simulation: PondSimulation
    public let renderer: PondRenderer
    private lazy var sceneLayer = PondSceneLayer(renderer: renderer)
    private let overlayView = PondOverlayView(frame: .zero)
    public private(set) var totalRenderedFrames: Int = 0
    public override var wantsUpdateLayer: Bool { true }

    private var displayTimer: Timer?
    private var lastFrameTime: TimeInterval = 0.0
    private var currentFPS: Double = 60.0
    public var showHUD: Bool = true
    public var timeOfDayPhase: TimeOfDayPhase = .day {
        didSet {
            needsDisplay = true
        }
    }

    public override var acceptsFirstResponder: Bool {
        true
    }

    public override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
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
        configureSceneLayers()
        startAnimationTimer()
    }

    required init?(coder: NSCoder) {
        let simBounds = PondBounds(width: 1024.0, height: 640.0)
        self.simulation = PondSimulation(bounds: simBounds)
        self.renderer = PondRenderer()
        super.init(coder: coder)

        wantsLayer = true
        layerContentsRedrawPolicy = .onSetNeedsDisplay
        configureSceneLayers()
        startAnimationTimer()
    }

    deinit {
        displayTimer?.invalidate()
    }

    public override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        simulation.resize(width: Double(newSize.width), height: Double(newSize.height))
        needsDisplay = true
    }

    private func startAnimationTimer() {
        displayTimer?.invalidate()
        lastFrameTime = CACurrentMediaTime()

        let timer = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            let now = CACurrentMediaTime()
            let dt = (self.lastFrameTime > 0) ? (now - self.lastFrameTime) : (1.0 / 60.0)
            self.lastFrameTime = now

            // Compute exponential moving average for FPS display
            if dt > 0.001 {
                let instantFPS = 1.0 / dt
                self.currentFPS = self.currentFPS * 0.9 + instantFPS * 0.1
            }

            if !self.simulation.isPaused {
                self.simulation.advance(deltaTime: dt)
                self.needsDisplay = true
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.displayTimer = timer
    }

    // MARK: - Drawing

    private func configureSceneLayers() {
        layer?.insertSublayer(sceneLayer, at: 0)
        overlayView.frame = overlayFrame
        overlayView.autoresizingMask = []
        overlayView.wantsLayer = true
        overlayView.drawOverlay = { [weak self] context in
            guard let self, self.showHUD else { return }
            context.translateBy(x: -self.overlayView.frame.minX, y: -self.overlayView.frame.minY)
            self.drawHUD(in: context)
        }
        addSubview(overlayView)
    }

    public override func viewDidChangeBackingProperties() {
        super.viewDidChangeBackingProperties()
        layer?.contentsScale = window?.backingScaleFactor ?? 1
        needsDisplay = true
    }

    private var overlayFrame: CGRect {
        CGRect(x: 0, y: max(0, bounds.height - 130), width: min(520, bounds.width), height: min(130, bounds.height))
    }

    public override func draw(_ dirtyRect: NSRect) { updateLayer() }

    public override func updateLayer() {
        sceneLayer.update(simulation: simulation, bounds: bounds,
                          backingScale: window?.backingScaleFactor ?? 1, phase: timeOfDayPhase)
        totalRenderedFrames += 1
        overlayView.frame = overlayFrame
        overlayView.isHidden = !showHUD
        if !overlayView.isHidden { overlayView.needsDisplay = true }
    }

    private func drawHUD(in context: CGContext) {
        let hudRect = NSRect(x: 16, y: bounds.height - 110, width: 360, height: 94)
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
        let hintAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 10, weight: .medium),
            .foregroundColor: NSColor.systemTeal.withAlphaComponent(0.9)
        ]

        "Koi Pond Preview — ".draw(at: NSPoint(x: hudRect.minX + 12, y: hudRect.maxY - 22), withAttributes: titleAttrs)
        statusText.draw(at: NSPoint(x: hudRect.minX + 185, y: hudRect.maxY - 22), withAttributes: statusAttrs)

        let stats = String(
            format: "Timer: %.0f Hz  ·  Koi: %d  ·  Pellets: %d/%d  ·  Ripples: %d/%d",
            currentFPS,
            simulation.fish.count,
            simulation.pellets.count,
            simulation.maxPellets,
            simulation.ripples.count,
            simulation.maxRipples
        )
        stats.draw(at: NSPoint(x: hudRect.minX + 12, y: hudRect.maxY - 42), withAttributes: bodyAttrs)

        let hints = "Click: Splash  ·  Opt+Click: Feed  ·  Space: Pause  ·  R: Reset"
        hints.draw(at: NSPoint(x: hudRect.minX + 12, y: hudRect.maxY - 62), withAttributes: hintAttrs)

        let hints2 = "F: Feed Center  ·  C: Splash Center  ·  H: HUD  ·  T: Phase (\(timeOfDayPhase.rawValue))"
        hints2.draw(at: NSPoint(x: hudRect.minX + 12, y: hudRect.maxY - 80), withAttributes: hintAttrs)
    }

    // MARK: - Mouse Input

    public override func mouseDown(with event: NSEvent) {
        let location = convert(event.locationInWindow, from: nil)
        let simPoint = PondVector(x: Double(location.x), y: Double(location.y))

        if event.modifierFlags.contains(.option) {
            print("[KoiPondPreviewView] Received GUI Event: Option+MouseDown at \(simPoint) -> Dropping food pellets")
            simulation.handleFoodDrop(at: simPoint)
        } else {
            print("[KoiPondPreviewView] Received GUI Event: Regular MouseDown at \(simPoint) -> Water splash ripple")
            simulation.handleWaterClick(at: simPoint)
        }
        needsDisplay = true
    }

    // MARK: - Keyboard Controls

    public override func keyDown(with event: NSEvent) {
        let char = event.charactersIgnoringModifiers?.lowercased() ?? ""
        print("[KoiPondPreviewView] Received GUI Event: KeyDown '\(char)'")
        switch char {
        case " ":
            simulation.isPaused.toggle()
        case "r":
            simulation.reset()
        case "f":
            simulation.handleFoodDrop(at: simulation.bounds.center)
        case "c":
            simulation.handleWaterClick(at: simulation.bounds.center)
        case "h":
            showHUD.toggle()
        case "t":
            let all = TimeOfDayPhase.allCases
            if let idx = all.firstIndex(of: timeOfDayPhase) {
                timeOfDayPhase = all[(idx + 1) % all.count]
                print("[KoiPondPreviewView] Cycled time-of-day phase to: \(timeOfDayPhase.rawValue)")
            }
        default:
            super.keyDown(with: event)
        }
        needsDisplay = true
    }
}
