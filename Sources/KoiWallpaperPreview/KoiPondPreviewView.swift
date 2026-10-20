import AppKit
import Foundation
import KoiWallpaperCore

public final class KoiPondPreviewView: NSView {
    public let simulation: PondSimulation
    public let renderer: PondRenderer

    private var displayTimer: Timer?
    private var lastFrameTime: TimeInterval = 0.0
    private var currentFPS: Double = 60.0
    public var showHUD: Bool = true

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
        startAnimationTimer()
    }

    required init?(coder: NSCoder) {
        let simBounds = PondBounds(width: 1024.0, height: 640.0)
        self.simulation = PondSimulation(bounds: simBounds)
        self.renderer = PondRenderer()
        super.init(coder: coder)

        wantsLayer = true
        layerContentsRedrawPolicy = .onSetNeedsDisplay
        startAnimationTimer()
    }

    deinit {
        displayTimer?.invalidate()
    }

    public override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        simulation.resize(width: Double(newSize.width), height: Double(newSize.height))
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

            self.simulation.advance(deltaTime: dt)
            self.needsDisplay = true
        }
        RunLoop.main.add(timer, forMode: .common)
        self.displayTimer = timer
    }

    // MARK: - Drawing

    public override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }

        // Render full layered pond simulation
        renderer.render(simulation: simulation, in: context, rect: bounds)

        // Draw HUD overlay if active
        if showHUD {
            drawHUD(in: context)
        }
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

        "Koi Pond Preview (M1) — ".draw(at: NSPoint(x: hudRect.minX + 12, y: hudRect.maxY - 22), withAttributes: titleAttrs)
        statusText.draw(at: NSPoint(x: hudRect.minX + 185, y: hudRect.maxY - 22), withAttributes: statusAttrs)

        let stats = String(
            format: "FPS: %.0f  ·  Koi: %d  ·  Pellets: %d/%d  ·  Ripples: %d/%d",
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

        let hints2 = "F: Feed Center  ·  C: Splash Center  ·  H: Toggle HUD"
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
        default:
            super.keyDown(with: event)
        }
        needsDisplay = true
    }
}
