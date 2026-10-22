import AppKit
import Foundation

public final class WallpaperView: NSView {
    public static let targetFramesPerSecond: Double = 30
    public var inputCoordinator: InputCoordinator?

    public let simulation: PondSimulation
    public let renderer: PondRenderer
    private lazy var sceneLayer = PondSceneLayer(renderer: renderer)
    private let overlayView = PondOverlayView(frame: .zero)
    public private(set) var totalRenderedFrames: Int = 0
    public var isFullscreenPresentation: Bool = false
    public override var wantsUpdateLayer: Bool { true }

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

    public private(set) var currentGreetingMessage: String?
    public private(set) var greetingRemainingDuration: Double = 0.0

    public func triggerGreetingIfDue(at date: Date = Date()) {
        let (shouldGreet, message) = simulation.dailyGreetingManager.checkAndTriggerGreeting(at: date)
        if shouldGreet, let msg = message {
            currentGreetingMessage = msg
            greetingRemainingDuration = 8.0
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
    public private(set) var timerCadenceFPS: Double = WallpaperView.targetFramesPerSecond

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
        layerUsesCoreImageFilters = true
        layerContentsRedrawPolicy = .onSetNeedsDisplay
        layer?.contentsScale = NSScreen.main?.backingScaleFactor ?? 2.0
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
        layer?.contentsScale = NSScreen.main?.backingScaleFactor ?? 2.0
        configureSceneLayers()
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

    public override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window != nil {
            let scale = window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 1.0
            layer?.contentsScale = scale
            triggerGreetingIfDue()
        }
        needsDisplay = true
    }

    public override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        simulation.resize(width: Double(newSize.width), height: Double(newSize.height))
        needsDisplay = true
    }

    // MARK: - Animation Loop & Stasis Control

    public func startAnimationTimer() {
        guard animationTimer == nil, !isPaused else { return }
        lastFrameTime = CACurrentMediaTime()

        let timer = Timer(timeInterval: 1.0 / Self.targetFramesPerSecond, repeats: true) { [weak self] _ in
            guard let self = self, !self.isPaused else { return }
            self.totalTimerTicks += 1
            let now = CACurrentMediaTime()
            let dt = (self.lastFrameTime > 0) ? (now - self.lastFrameTime) : (1.0 / Self.targetFramesPerSecond)
            self.lastFrameTime = now

            if dt > 0.005 && dt < 0.10 {
                let instantCadence = 1.0 / dt
                self.timerCadenceFPS = self.timerCadenceFPS * 0.9 + instantCadence * 0.1
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

            if self.greetingRemainingDuration > 0 {
                self.greetingRemainingDuration = max(0.0, self.greetingRemainingDuration - dt)
                if self.greetingRemainingDuration <= 0 {
                    self.currentGreetingMessage = nil
                    self.needsDisplay = true
                }
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

    private func configureSceneLayers() {
        layer?.insertSublayer(sceneLayer, at: 0)
        overlayView.frame = overlayFrame
        overlayView.autoresizingMask = []
        overlayView.wantsLayer = true
        overlayView.drawOverlay = { [weak self] context in
            guard let self else { return }
            context.translateBy(x: -self.overlayView.frame.minX, y: -self.overlayView.frame.minY)
            if self.isFullscreenPresentation {
                self.drawFullscreenBanner()
            } else if self.isInteractionMode {
                self.drawInteractionModeBanner()
            }
            if self.showHUD { self.drawHUD(in: context) }
            if self.greetingRemainingDuration > 0, let msg = self.currentGreetingMessage, !self.isInteractionMode && !self.isFullscreenPresentation {
                self.drawGreetingBanner(message: msg)
            }
        }
        addSubview(overlayView)
    }

    private var overlayFrame: CGRect {
        CGRect(x: 0, y: max(0, bounds.height - 130), width: min(520, bounds.width), height: min(130, bounds.height))
    }

    public override func draw(_ dirtyRect: NSRect) { updateLayer() }

    public override func updateLayer() {
        let scale = window?.backingScaleFactor ?? layer?.contentsScale ?? 1
        sceneLayer.update(
            simulation: simulation,
            bounds: bounds,
            backingScale: scale,
            fromTheme: activeTheme,
            toTheme: targetTheme,
            progress: transitionProgress
        )
        totalRenderedFrames += 1
        overlayView.frame = overlayFrame
        overlayView.isHidden = !showHUD && !isInteractionMode && (greetingRemainingDuration <= 0) && !isFullscreenPresentation
        if !overlayView.isHidden { overlayView.needsDisplay = true }
    }

    private func drawFullscreenBanner() {
        let bannerRect = NSRect(x: 24, y: bounds.height - 70, width: 490, height: 46)
        let bgPath = NSBezierPath(roundedRect: bannerRect, xRadius: 8, yRadius: 8)
        NSColor.black.withAlphaComponent(0.70).setFill()
        bgPath.fill()

        NSColor.systemTeal.withAlphaComponent(0.85).setStroke()
        bgPath.lineWidth = 1.0
        bgPath.stroke()

        let title = "Mode Layar Penuh (Fullscreen)"
        let subtitle = "Tekan tombol Escape (⎋) untuk kembali ke Desktop · Klik untuk berinteraksi"

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

    private func drawGreetingBanner(message: String) {
        let bannerRect = NSRect(x: 24, y: bounds.height - 60, width: min(470, bounds.width - 48), height: 42)
        let bgPath = NSBezierPath(roundedRect: bannerRect, xRadius: 8, yRadius: 8)
        NSColor.black.withAlphaComponent(0.70).setFill()
        bgPath.fill()

        NSColor.systemOrange.withAlphaComponent(0.85).setStroke()
        bgPath.lineWidth = 1.0
        bgPath.stroke()

        let titleAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 12, weight: .medium),
            .foregroundColor: NSColor(calibratedRed: 0.98, green: 0.95, blue: 0.88, alpha: 1.0)
        ]
        message.draw(at: NSPoint(x: bannerRect.minX + 14, y: bannerRect.minY + 12), withAttributes: titleAttrs)
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

        "Koi Wallpaper (M5) — ".draw(at: NSPoint(x: hudRect.minX + 12, y: hudRect.maxY - 22), withAttributes: titleAttrs)
        statusText.draw(at: NSPoint(x: hudRect.minX + 165, y: hudRect.maxY - 22), withAttributes: statusAttrs)

        let stats = String(
            format: "Cadence: %.0f Hz  ·  Koi: %d  ·  Visitors: %d  ·  Pellets: %d/%d",
            timerCadenceFPS,
            simulation.fish.count,
            simulation.visitors.count,
            simulation.pellets.count,
            simulation.maxPellets
        )
        stats.draw(at: NSPoint(x: hudRect.minX + 12, y: hudRect.maxY - 42), withAttributes: bodyAttrs)

        let transitionInfo = transitionProgress < 1.0 ? String(format: " (blending %.0f%%)", transitionProgress * 100) : ""
        let phaseStr = "Theme: \(targetTheme.displayName)\(transitionInfo)  ·  Mood: \(simulation.mood.displayName)"
        phaseStr.draw(at: NSPoint(x: hudRect.minX + 12, y: hudRect.maxY - 62), withAttributes: bodyAttrs)

        let rainStr = simulation.isRainActive ? "Rain: ON" : "Rain: OFF"
        let modeStr = isInteractionMode ? "Mode: Interactive" : "Mode: Passthrough"
        "\(modeStr)  ·  \(rainStr)".draw(at: NSPoint(x: hudRect.minX + 12, y: hudRect.maxY - 80), withAttributes: bodyAttrs)
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
