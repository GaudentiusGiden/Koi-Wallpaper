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

    public var theme: PondTheme = .day {
        didSet {
            if oldValue != theme {
                setTheme(theme, animated: true)
            }
        }
    }

    public var timeOfDayPhase: TimeOfDayPhase {
        get { theme.asTimePhase ?? .day }
        set { theme = newValue.theme }
    }

    public var pondMood: PondMood {
        get { simulation.mood }
        set {
            simulation.mood = newValue
            needsDisplay = true
        }
    }

    public var isRainActive: Bool {
        get { simulation.isRainActive }
        set {
            simulation.isRainActive = newValue
            needsDisplay = true
        }
    }

    public private(set) var activeTheme: PondTheme = .day
    public private(set) var targetTheme: PondTheme = .day
    public private(set) var pendingTheme: PondTheme? = nil
    public private(set) var transitionProgress: CGFloat = 1.0
    public var transitionDuration: TimeInterval = 1.8

    public func setTheme(_ newTheme: PondTheme, animated: Bool = true) {
        if !animated {
            pendingTheme = nil
            renderer.clearSnapshotSource()
            activeTheme = newTheme
            targetTheme = newTheme
            transitionProgress = 1.0
            simulation.setTheme(newTheme, animated: false)
            needsDisplay = true
            return
        }

        if transitionProgress < 1.0 {
            // If already waiting for current transition to finish (due to earlier snapshot fallback):
            if pendingTheme != nil {
                if newTheme == targetTheme {
                    // New request matches current destination; cancel pending follow-up.
                    pendingTheme = nil
                } else if newTheme == activeTheme && !renderer.isSnapshotSource {
                    // The failed snapshot left a direct theme-to-theme transition. Reverse it
                    // in place and discard the queued follow-up without changing the visible mix.
                    pendingTheme = nil
                    let previousSource = activeTheme
                    activeTheme = targetTheme
                    targetTheme = previousSource
                    transitionProgress = max(0.0, min(1.0, 1.0 - transitionProgress))
                    needsDisplay = true
                } else {
                    // A snapshot source can be a mixed image, so keep the current transition
                    // and queue the latest requested theme after it completes.
                    pendingTheme = newTheme
                }
                return
            }

            if newTheme == targetTheme {
                return
            }

            // Reversing back to source theme if no intermediate snapshot is in effect
            if newTheme == activeTheme && !renderer.isSnapshotSource {
                let prevTarget = targetTheme
                targetTheme = activeTheme
                activeTheme = prevTarget
                transitionProgress = max(0.0, min(1.0, 1.0 - transitionProgress))
                needsDisplay = true
                return
            }

            // Before the first frame is rendered, there is no visible mixed appearance to preserve.
            // Retarget directly to newTheme without snapshotting or queuing.
            if totalRenderedFrames == 0 {
                renderer.clearSnapshotSource()
                pendingTheme = nil
                targetTheme = newTheme
                transitionProgress = 0.0
                needsDisplay = true
                return
            }

            // Visible transition in flight (totalRenderedFrames > 0):
            // Snapshot the visible in-flight blend into Layer A, target C into Layer B
            let scale = window?.backingScaleFactor ?? layer?.contentsScale ?? 1.0
            let size = (bounds.width > 0 && bounds.height > 0) ? bounds.size : CGSize(width: 1024, height: 640)
            let success = renderer.snapshotTransition(
                size: size,
                scale: scale,
                progress: transitionProgress,
                fromTheme: activeTheme,
                toTheme: targetTheme
            )
            if success {
                activeTheme = targetTheme
                targetTheme = newTheme
                transitionProgress = 0.0
                pendingTheme = nil
            } else {
                // Snapshot failed during a visible in-flight transition.
                // Do NOT interrupt the current visible appearance or snap back to source theme.
                // Allow the current transition (activeTheme -> targetTheme) to finish smoothly,
                // saving newTheme as the pending target to start immediately upon completion.
                pendingTheme = newTheme
            }
        } else {
            guard newTheme != targetTheme else { return }
            pendingTheme = nil
            renderer.clearSnapshotSource()
            targetTheme = newTheme
            transitionProgress = 0.0
        }
        needsDisplay = true
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
        layerUsesCoreImageFilters = true
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
        layerUsesCoreImageFilters = true
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

            // If paused, keep lastFrameTime fresh so resuming does not produce a huge dt catch-up
            if self.simulation.isPaused {
                self.lastFrameTime = now
                return
            }

            let dt = (self.lastFrameTime > 0) ? (now - self.lastFrameTime) : (1.0 / 60.0)
            self.lastFrameTime = now

            // Compute exponential moving average for FPS display
            if dt > 0.001 {
                let instantFPS = 1.0 / dt
                self.currentFPS = self.currentFPS * 0.9 + instantFPS * 0.1
            }

            if self.transitionProgress < 1.0 {
                let duration = max(0.001, self.transitionDuration)
                self.transitionProgress = min(1.0, self.transitionProgress + CGFloat(dt / duration))
                if self.transitionProgress >= 1.0 {
                    self.activeTheme = self.targetTheme
                    self.renderer.clearSnapshotSource()
                    if let nextTheme = self.pendingTheme {
                        self.pendingTheme = nil
                        if nextTheme != self.activeTheme {
                            self.setTheme(nextTheme, animated: true)
                        }
                    }
                }
            }

            self.simulation.updateThemeTransition(
                from: self.activeTheme,
                to: self.targetTheme,
                progress: Double(self.transitionProgress)
            )
            self.simulation.advance(deltaTime: dt)
            self.needsDisplay = true
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
        simulation.updateThemeTransition(
            from: activeTheme,
            to: targetTheme,
            progress: Double(transitionProgress)
        )
        sceneLayer.update(
            simulation: simulation,
            bounds: bounds,
            backingScale: window?.backingScaleFactor ?? 1,
            fromTheme: activeTheme,
            toTheme: targetTheme,
            progress: transitionProgress
        )
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

        let hints = "Click: Splash  ·  Opt+Click: Feed  ·  V: Swan  ·  B: Ball  ·  X: Clear"
        hints.draw(at: NSPoint(x: hudRect.minX + 12, y: hudRect.maxY - 62), withAttributes: hintAttrs)

        let hints2 = "T: Theme  ·  M: Mood (\(simulation.mood.displayName))  ·  W: Rain  ·  Space: Pause"
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
            lastFrameTime = CACurrentMediaTime()
        case "r":
            simulation.reset()
        case "f":
            simulation.handleFoodDrop(at: simulation.bounds.center)
        case "c":
            simulation.handleWaterClick(at: simulation.bounds.center)
        case "h":
            showHUD.toggle()
        case "m":
            let nextMood: PondMood = (simulation.mood == .calm) ? .playful : .calm
            simulation.mood = nextMood
            print("[KoiPondPreviewView] Mood toggled to: \(nextMood.displayName)")
        case "w":
            simulation.isRainActive.toggle()
            print("[KoiPondPreviewView] Rain effect toggled: \(simulation.isRainActive ? "ON" : "OFF")")
        case "v":
            let v = simulation.spawnVisitor(type: .swan)
            print("[KoiPondPreviewView] Spawned Swan visitor: id=\(v.id) pos=\(v.position)")
        case "b":
            let b = simulation.spawnVisitor(type: .ball)
            print("[KoiPondPreviewView] Spawned Temari Ball visitor: id=\(b.id) pos=\(b.position)")
        case "x":
            simulation.clearVisitors()
            print("[KoiPondPreviewView] Cleared all visitors. Remaining fish targets reset.")
        case "g":
            let (shouldGreet, msg) = simulation.dailyGreetingManager.checkAndTriggerGreeting()
            print("[KoiPondPreviewView] Daily Greeting: shouldGreet=\(shouldGreet), msg=\(msg ?? "already shown today")")
        case "t":
            let all = PondTheme.allCases
            if let idx = all.firstIndex(of: targetTheme) {
                let nextTheme = all[(idx + 1) % all.count]
                setTheme(nextTheme, animated: true)
                print("[KoiPondPreviewView] Transitioning to theme: \(nextTheme.displayName) (\(nextTheme.rawValue))")
            }
        default:
            super.keyDown(with: event)
        }
        needsDisplay = true
    }
}
