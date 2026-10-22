import CoreGraphics
import Foundation

struct PondImagePlacement {
    let image: CGImage
    let rect: CGRect
    let pixelated: Bool
    var angle: CGFloat = 0
}

struct PondStroke {
    let path: CGPath
    let color: CGColor
    let width: CGFloat
}

struct PondRenderFrame {
    let size: CGSize
    let bed: PondImagePlacement?
    let bedTarget: PondImagePlacement?
    let caustics: [PondImagePlacement]
    let causticsTarget: [PondImagePlacement]
    let swimmers: PondImagePlacement?
    let surface: [PondStroke]
    let flora: [PondImagePlacement]
    let floraTarget: [PondImagePlacement]
    let tint: CGColor?
    let transitionProgress: CGFloat
    let isTransitioning: Bool
}

enum PondBitmap {
    static func makeImage(size: CGSize, scale: CGFloat, pixelated: Bool = false, draw: (CGContext) -> Void) -> CGImage? {
        guard let context = CGContext(data: nil, width: max(1, Int(ceil(size.width * scale))),
                                      height: max(1, Int(ceil(size.height * scale))), bitsPerComponent: 8,
                                      bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        context.scaleBy(x: scale, y: scale)
        context.setShouldAntialias(!pixelated)
        draw(context)
        return context.makeImage()
    }
}

/// One asset pipeline for both the CALayer host and deterministic offscreen review.
/// Physics and input remain in points; only the artwork uses a coarse logical grid.
public final class PondRenderer {
    private var waterA = PondWaterSurface()
    private var waterB = PondWaterSurface()
    private var sceneContext: CGContext?
    private var scenePixels: CGSize = .zero
    private var cachedFloraA: [PondImagePlacement] = []
    private var cachedFloraB: [PondImagePlacement] = []
    private var floraSizeA: CGSize = .zero
    private var floraSizeB: CGSize = .zero
    private var floraPixelSizeA: CGFloat = 0
    private var floraPixelSizeB: CGFloat = 0
    private var floraThemeA: PondTheme?
    private var floraThemeB: PondTheme?

    typealias GlimmerStyle = (color: (CGFloat, CGFloat, CGFloat), alpha: CGFloat)

    public private(set) var isSnapshotSource: Bool = false
    private var customSourceShadow: PondLighting.ShadowStyle?
    private var customSourceTint: CGColor?
    private var customSourceGlimmer: GlimmerStyle?
    private(set) var lastFromTheme: PondTheme = .day
    private(set) var lastToTheme: PondTheme = .day

    public init() {}

    @discardableResult
    public func snapshotTransition(
        size: CGSize,
        scale: CGFloat,
        progress: CGFloat,
        fromTheme: PondTheme? = nil,
        toTheme: PondTheme? = nil
    ) -> Bool {
        guard size.width.isFinite, size.height.isFinite, scale.isFinite, progress.isFinite,
              size.width > 0, size.height > 0, scale > 0 else { return false }
        let p = max(0, min(1, progress))
        let effectiveFrom = fromTheme ?? lastFromTheme
        let effectiveTo = toTheme ?? lastToTheme

        // Build candidate surfaces away from the active renderer state. A failed allocation must
        // leave the currently displayed transition source byte-for-byte available to render.
        let candidateWaterA = waterA.copyForSnapshot()
        let candidateWaterB = waterB.copyForSnapshot()
        if !isSnapshotSource && !candidateWaterA.isPrepared(size: size, scale: scale, theme: effectiveFrom) {
            candidateWaterA.prepare(size: size, scale: scale, theme: effectiveFrom)
        }
        if !candidateWaterB.isPrepared(size: size, scale: scale, theme: effectiveTo) {
            candidateWaterB.prepare(size: size, scale: scale, theme: effectiveTo)
        }

        let isSourceReady = isSnapshotSource
            ? candidateWaterA.hasCompleteAssets(for: size, scale: scale)
            : candidateWaterA.isPrepared(size: size, scale: scale, theme: effectiveFrom)
        let isTargetReady = candidateWaterB.isPrepared(size: size, scale: scale, theme: effectiveTo)
        guard isSourceReady, isTargetReady else { return false }

        // 1. Snapshot bed and caustics into the candidate water surface.
        guard candidateWaterA.snapshotBlend(with: candidateWaterB, progress: p) else { return false }

        // 2. Prepare both flora inputs without changing either active flora cache.
        let short = min(size.width, size.height)
        let pixelSize = max(1, (short * scale / 270).rounded()) / scale
        let local = PondFloraArtwork.localBounds(shortSide: short)
        let crop = CGRect(x: floor(local.minX / pixelSize) * pixelSize, y: floor(local.minY / pixelSize) * pixelSize,
                          width: ceil(local.width / pixelSize) * pixelSize, height: ceil(local.height / pixelSize) * pixelSize)

        let sourceFlora: [PondImagePlacement]?
        if isSnapshotSource, cachedFloraA.count == PondFloraArtwork.anchors.count {
            sourceFlora = cachedFloraA
        } else if floraSizeA == size, floraPixelSizeA == pixelSize, floraThemeA == effectiveFrom,
                  cachedFloraA.count == PondFloraArtwork.anchors.count {
            sourceFlora = cachedFloraA
        } else {
            sourceFlora = Self.makeFlora(size: size, short: short, pixelSize: pixelSize, crop: crop, theme: effectiveFrom)
        }

        let targetFlora: [PondImagePlacement]?
        if floraSizeB == size, floraPixelSizeB == pixelSize, floraThemeB == effectiveTo,
           cachedFloraB.count == PondFloraArtwork.anchors.count {
            targetFlora = cachedFloraB
        } else {
            targetFlora = Self.makeFlora(size: size, short: short, pixelSize: pixelSize, crop: crop, theme: effectiveTo)
        }
        guard let sourceFlora, let targetFlora,
              sourceFlora.count == PondFloraArtwork.anchors.count,
              targetFlora.count == PondFloraArtwork.anchors.count else { return false }

        var blendedFlora: [PondImagePlacement] = []
        blendedFlora.reserveCapacity(sourceFlora.count)
        for i in sourceFlora.indices {
            let placementA = sourceFlora[i]
            let placementB = targetFlora[i]
            guard let image = PondBitmap.makeImage(size: crop.size, scale: 1 / pixelSize, pixelated: true, draw: { ctx in
                ctx.saveGState()
                // Flora A drawn at full 1.0 opacity; incoming Flora B fades in at p (source-over compositing)
                ctx.draw(placementA.image, in: CGRect(origin: .zero, size: crop.size))
                ctx.setAlpha(p)
                ctx.draw(placementB.image, in: CGRect(origin: .zero, size: crop.size))
                ctx.restoreGState()
            }) else { return false }
            blendedFlora.append(PondImagePlacement(image: image, rect: placementA.rect, pixelated: true))
        }

        guard blendedFlora.count == sourceFlora.count else { return false }

        // 3. Prepare intermediate lighting state as candidates too.
        let styleA = customSourceShadow ?? PondLighting.shadowStyle(for: effectiveFrom)
        let styleB = PondLighting.shadowStyle(for: effectiveTo)
        let candidateShadow = PondLighting.ShadowStyle.lerp(from: styleA, to: styleB, t: p)

        let tintA = customSourceTint ?? Self.themeTint(effectiveFrom)
        let tintB = Self.themeTint(effectiveTo)
        let candidateTint = Self.lerpColor(from: tintA, to: tintB, t: p)

        let gA = customSourceGlimmer ?? Self.glimmerStyle(for: effectiveFrom)
        let gB = Self.glimmerStyle(for: effectiveTo)
        let candidateGlimmer = Self.lerpGlimmer(from: gA, to: gB, t: p)

        // Commit only after every image and lighting value has been prepared successfully.
        waterA = candidateWaterA
        waterB = candidateWaterB
        cachedFloraA = blendedFlora
        cachedFloraB = targetFlora
        floraSizeA = size
        floraPixelSizeA = pixelSize
        floraThemeA = nil
        floraSizeB = size
        floraPixelSizeB = pixelSize
        floraThemeB = effectiveTo
        customSourceShadow = candidateShadow
        customSourceTint = candidateTint
        customSourceGlimmer = candidateGlimmer
        isSnapshotSource = true
        return true
    }

    private static func makeFlora(
        size: CGSize,
        short: CGFloat,
        pixelSize: CGFloat,
        crop: CGRect,
        theme: PondTheme
    ) -> [PondImagePlacement]? {
        var placements: [PondImagePlacement] = []
        placements.reserveCapacity(PondFloraArtwork.anchors.count)
        for (index, anchor) in PondFloraArtwork.anchors.enumerated() {
            guard let image = PondBitmap.makeImage(size: crop.size, scale: 1 / pixelSize, pixelated: true, draw: { bitmap in
                bitmap.translateBy(x: -crop.minX, y: -crop.minY)
                PondFloraArtwork.drawCluster(index, in: bitmap, shortSide: short, theme: theme)
            }) else { return nil }
            let x = (anchor.x * size.width / pixelSize).rounded() * pixelSize
            let y = (anchor.y * size.height / pixelSize).rounded() * pixelSize
            placements.append(PondImagePlacement(image: image, rect: crop.offsetBy(dx: x, dy: y), pixelated: true))
        }
        return placements
    }

    public func clearSnapshotSource() {
        isSnapshotSource = false
        customSourceShadow = nil
        customSourceTint = nil
        customSourceGlimmer = nil
    }

    public func render(simulation: PondSimulation, in context: CGContext, rect: CGRect) {
        render(simulation: simulation, in: context, rect: rect, fromTheme: .day, toTheme: .day, progress: 1.0)
    }

    public func render(simulation: PondSimulation, in context: CGContext, rect: CGRect, theme: PondTheme) {
        render(simulation: simulation, in: context, rect: rect, fromTheme: theme, toTheme: theme, progress: 1.0)
    }

    public func render(simulation: PondSimulation, in context: CGContext, rect: CGRect, phase: TimeOfDayPhase) {
        render(simulation: simulation, in: context, rect: rect, fromTheme: phase.theme, toTheme: phase.theme, progress: 1.0)
    }

    public func render(
        simulation: PondSimulation,
        in context: CGContext,
        rect: CGRect,
        fromTheme: PondTheme,
        toTheme: PondTheme,
        progress: CGFloat
    ) {
        guard rect.width > 0, rect.height > 0 else { return }
        let scale = max(1, hypot(context.ctm.a, context.ctm.c))
        let frame = makeTransitionFrame(
            simulation: simulation,
            size: rect.size,
            scale: scale,
            fromTheme: fromTheme,
            toTheme: toTheme,
            progress: progress
        )
        context.saveGState()
        context.clip(to: rect)
        context.translateBy(x: rect.minX, y: rect.minY)

        if !frame.isTransitioning {
            if let bed = frame.bed { draw(bed, in: context) }
            for placement in frame.caustics { draw(placement, in: context) }
            if let swimmers = frame.swimmers { draw(swimmers, in: context) }
            context.setLineCap(.round)
            for stroke in frame.surface {
                context.setStrokeColor(stroke.color)
                context.setLineWidth(stroke.width)
                context.addPath(stroke.path)
                context.strokePath()
            }
            for placement in frame.flora { draw(placement, in: context) }
            if let tint = frame.tint {
                context.setFillColor(tint)
                context.fill(CGRect(origin: .zero, size: rect.size))
            }
        } else {
            // Blended offscreen render with source-over compositing:
            // Base opaque layers (bed, flora) stay at alpha 1.0 while target fades in at p,
            // preventing the window background from leaking through during transitions.
            let p = frame.transitionProgress
            if let bedA = frame.bed {
                draw(bedA, in: context)
            }
            if let bedB = frame.bedTarget {
                context.saveGState()
                context.setAlpha(p)
                draw(bedB, in: context)
                context.restoreGState()
            }
            let causticCount = max(frame.caustics.count, frame.causticsTarget.count)
            for i in 0..<causticCount {
                let placeA = i < frame.caustics.count ? frame.caustics[i] : nil
                let placeB = i < frame.causticsTarget.count ? frame.causticsTarget[i] : nil

                if let placeA = placeA, let placeB = placeB {
                    context.beginTransparencyLayer(auxiliaryInfo: nil)
                    context.saveGState()
                    context.setAlpha(1.0 - p)
                    draw(placeA, in: context)
                    context.restoreGState()

                    context.saveGState()
                    context.setBlendMode(.plusLighter)
                    context.setAlpha(p)
                    draw(placeB, in: context)
                    context.restoreGState()
                    context.endTransparencyLayer()
                } else if let placeA = placeA {
                    context.saveGState()
                    context.setAlpha(1.0 - p)
                    draw(placeA, in: context)
                    context.restoreGState()
                } else if let placeB = placeB {
                    context.saveGState()
                    context.setAlpha(p)
                    draw(placeB, in: context)
                    context.restoreGState()
                }
            }
            if let swimmers = frame.swimmers { draw(swimmers, in: context) }
            context.setLineCap(.round)
            for stroke in frame.surface {
                context.setStrokeColor(stroke.color)
                context.setLineWidth(stroke.width)
                context.addPath(stroke.path)
                context.strokePath()
            }
            for placement in frame.flora {
                draw(placement, in: context)
            }
            for placement in frame.floraTarget {
                context.saveGState()
                context.setAlpha(p)
                draw(placement, in: context)
                context.restoreGState()
            }
            if let tint = frame.tint {
                context.setFillColor(tint)
                context.fill(CGRect(origin: .zero, size: rect.size))
            }
        }
        context.restoreGState()
    }

    func makeFrame(simulation: PondSimulation, size: CGSize, scale: CGFloat, phase: TimeOfDayPhase) -> PondRenderFrame {
        makeTransitionFrame(simulation: simulation, size: size, scale: scale, fromTheme: phase.theme, toTheme: phase.theme, progress: 1.0)
    }

    func makeFrame(simulation: PondSimulation, size: CGSize, scale: CGFloat, theme: PondTheme) -> PondRenderFrame {
        makeTransitionFrame(simulation: simulation, size: size, scale: scale, fromTheme: theme, toTheme: theme, progress: 1.0)
    }

    func makeTransitionFrame(
        simulation: PondSimulation,
        size: CGSize,
        scale: CGFloat,
        fromTheme: PondTheme,
        toTheme: PondTheme,
        progress: CGFloat
    ) -> PondRenderFrame {
        lastFromTheme = fromTheme
        lastToTheme = toTheme

        let short = min(size.width, size.height)
        let pixelSize = max(1, (short * scale / 270).rounded()) / scale
        let pixels = CGSize(width: ceil(size.width / pixelSize), height: ceil(size.height / pixelSize))
        let clampedP = max(0, min(1, progress))
        let isTransitioning = (isSnapshotSource || fromTheme != toTheme) && clampedP < 1.0

        if !isTransitioning && isSnapshotSource {
            clearSnapshotSource()
        }

        // Steady-state uses waterA directly; active transition prepares waterA (from) and waterB (to) once.
        if !isSnapshotSource {
            let activeThemeA = isTransitioning ? fromTheme : toTheme
            waterA.prepare(size: size, scale: scale, theme: activeThemeA)
        }
        if isTransitioning {
            waterB.prepare(size: size, scale: scale, theme: toTheme)
        }

        if sceneContext == nil || pixels != scenePixels {
            scenePixels = pixels
            sceneContext = CGContext(data: nil, width: Int(pixels.width), height: Int(pixels.height),
                                     bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
                                     bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        }

        // Swimmer bitmap with smoothly blended shadow styles
        var swimmers: PondImagePlacement?
        if let bitmap = sceneContext {
            bitmap.clear(CGRect(origin: .zero, size: pixels))
            bitmap.saveGState()
            bitmap.scaleBy(x: 1 / pixelSize, y: 1 / pixelSize)
            bitmap.setShouldAntialias(false)

            let shadowStyle: PondLighting.ShadowStyle
            if isTransitioning {
                let styleA = customSourceShadow ?? PondLighting.shadowStyle(for: fromTheme)
                let styleB = PondLighting.shadowStyle(for: toTheme)
                shadowStyle = PondLighting.ShadowStyle.lerp(from: styleA, to: styleB, t: clampedP)
            } else {
                shadowStyle = PondLighting.shadowStyle(for: toTheme)
            }

            DecorativeFishArtwork.draw(
                in: bitmap,
                size: size,
                time: simulation.elapsedTime,
                theme: toTheme,
                customShadowStyle: shadowStyle
            )
            for fish in simulation.fish {
                KoiArtwork.draw(
                    fish,
                    in: bitmap,
                    drawShadowOnly: true,
                    theme: toTheme,
                    customShadowStyle: shadowStyle
                )
            }
            for visitor in simulation.visitors {
                PondArtwork.drawVisitorShadow(visitor, in: bitmap, shadowStyle: shadowStyle)
            }
            for fish in simulation.fish {
                KoiArtwork.draw(fish, in: bitmap, theme: toTheme)
            }
            PondArtwork.drawPellets(simulation.pellets, in: bitmap)
            for visitor in simulation.visitors {
                PondArtwork.drawVisitor(visitor, in: bitmap, theme: toTheme)
            }
            bitmap.restoreGState()

            if let image = bitmap.makeImage() {
                swimmers = PondImagePlacement(
                    image: image,
                    rect: CGRect(x: 0, y: 0, width: pixels.width * pixelSize, height: pixels.height * pixelSize),
                    pixelated: true
                )
            }
        }

        // Flora cache for activeThemeA
        let local = PondFloraArtwork.localBounds(shortSide: short)
        let crop = CGRect(x: floor(local.minX / pixelSize) * pixelSize, y: floor(local.minY / pixelSize) * pixelSize,
                          width: ceil(local.width / pixelSize) * pixelSize, height: ceil(local.height / pixelSize) * pixelSize)

        let activeThemeA = isTransitioning ? fromTheme : toTheme
        if !isSnapshotSource && (floraSizeA != size || floraPixelSizeA != pixelSize || floraThemeA != activeThemeA) {
            floraSizeA = size
            floraPixelSizeA = pixelSize
            floraThemeA = activeThemeA
            cachedFloraA = PondFloraArtwork.anchors.enumerated().compactMap { index, anchor in
                guard let image = PondBitmap.makeImage(size: crop.size, scale: 1 / pixelSize, pixelated: true, draw: { bitmap in
                    bitmap.translateBy(x: -crop.minX, y: -crop.minY)
                    PondFloraArtwork.drawCluster(index, in: bitmap, shortSide: short, theme: activeThemeA)
                }) else { return nil }
                let x = (anchor.x * size.width / pixelSize).rounded() * pixelSize
                let y = (anchor.y * size.height / pixelSize).rounded() * pixelSize
                return PondImagePlacement(image: image, rect: crop.offsetBy(dx: x, dy: y), pixelated: true)
            }
        }

        // Flora cache for toTheme if transitioning
        if isTransitioning {
            if floraSizeB != size || floraPixelSizeB != pixelSize || floraThemeB != toTheme {
                floraSizeB = size
                floraPixelSizeB = pixelSize
                floraThemeB = toTheme
                cachedFloraB = PondFloraArtwork.anchors.enumerated().compactMap { index, anchor in
                    guard let image = PondBitmap.makeImage(size: crop.size, scale: 1 / pixelSize, pixelated: true, draw: { bitmap in
                        bitmap.translateBy(x: -crop.minX, y: -crop.minY)
                        PondFloraArtwork.drawCluster(index, in: bitmap, shortSide: short, theme: toTheme)
                    }) else { return nil }
                    let x = (anchor.x * size.width / pixelSize).rounded() * pixelSize
                    let y = (anchor.y * size.height / pixelSize).rounded() * pixelSize
                    return PondImagePlacement(image: image, rect: crop.offsetBy(dx: x, dy: y), pixelated: true)
                }
            }
        }

        let animateFlora: ([PondImagePlacement]) -> [PondImagePlacement] = { sources in
            let t = simulation.elapsedTime
            return sources.enumerated().map { index, source in
                let dx = (CGFloat(sin(t * 0.18 + Double(index))) * short * 0.0025 * scale).rounded() / scale
                let dy = (CGFloat(cos(t * 0.15 + Double(index) * 1.3)) * short * 0.0018 * scale).rounded() / scale
                return PondImagePlacement(
                    image: source.image,
                    rect: source.rect.offsetBy(dx: dx, dy: dy),
                    pixelated: true,
                    angle: CGFloat(sin(t * 0.16 + Double(index))) * 0.005
                )
            }
        }

        let floraA = animateFlora(cachedFloraA)
        let floraB = isTransitioning ? animateFlora(cachedFloraB) : []

        let bedPlacementA = waterA.bed.map { PondImagePlacement(image: $0, rect: CGRect(origin: .zero, size: size), pixelated: false) }
        let bedPlacementB = isTransitioning ? waterB.bed.map { PondImagePlacement(image: $0, rect: CGRect(origin: .zero, size: size), pixelated: false) } : nil

        let causticsA = waterA.placements(time: simulation.elapsedTime)
        let causticsB = isTransitioning ? waterB.placements(time: simulation.elapsedTime) : []

        let surfaceStrokes = Self.blendedSurfaceStrokes(
            simulation: simulation,
            size: size,
            fromTheme: fromTheme,
            toTheme: toTheme,
            progress: clampedP,
            customSourceGlimmer: isTransitioning ? customSourceGlimmer : nil
        )

        let tintColor: CGColor?
        if isTransitioning {
            let tintA = customSourceTint ?? Self.themeTint(fromTheme)
            let tintB = Self.themeTint(toTheme)
            tintColor = Self.lerpColor(from: tintA, to: tintB, t: clampedP)
        } else {
            tintColor = Self.themeTint(toTheme)
        }

        return PondRenderFrame(
            size: size,
            bed: bedPlacementA,
            bedTarget: bedPlacementB,
            caustics: causticsA,
            causticsTarget: causticsB,
            swimmers: swimmers,
            surface: surfaceStrokes,
            flora: floraA,
            floraTarget: floraB,
            tint: tintColor,
            transitionProgress: clampedP,
            isTransitioning: isTransitioning
        )
    }

    private func draw(_ placement: PondImagePlacement, in context: CGContext) {
        context.saveGState()
        context.interpolationQuality = .none
        context.translateBy(x: placement.rect.midX, y: placement.rect.midY)
        if placement.angle != 0 { context.rotate(by: placement.angle) }
        context.draw(placement.image, in: CGRect(x: -placement.rect.width / 2, y: -placement.rect.height / 2,
                                                width: placement.rect.width, height: placement.rect.height))
        context.restoreGState()
    }

    public static func themeTint(_ theme: PondTheme) -> CGColor? {
        switch theme {
        case .day, .deepClear: return nil
        case .dawn: return CGColor(red: 0.95, green: 0.80, blue: 0.55, alpha: 0.03)
        case .goldenHour: return CGColor(red: 0.98, green: 0.72, blue: 0.35, alpha: 0.05)
        case .dusk: return CGColor(red: 0.80, green: 0.40, blue: 0.50, alpha: 0.06)
        case .night: return CGColor(red: 0.04, green: 0.10, blue: 0.25, alpha: 0.10)
        case .rain: return CGColor(red: 0.60, green: 0.72, blue: 0.78, alpha: 0.07)
        }
    }

    private static func tint(_ phase: TimeOfDayPhase) -> CGColor? {
        themeTint(phase.theme)
    }

    public static func lerpColor(from c1: CGColor?, to c2: CGColor?, t: CGFloat) -> CGColor? {
        let p = max(0, min(1, t))
        guard let color1 = c1 ?? c2, let color2 = c2 ?? c1 else { return nil }
        let a1 = c1?.alpha ?? 0
        let a2 = c2?.alpha ?? 0
        let a = a1 + (a2 - a1) * p
        guard a > 0.001 else { return nil }
        let comps1 = color1.components ?? [0, 0, 0, 0]
        let comps2 = color2.components ?? [0, 0, 0, 0]
        let r1 = comps1.count > 0 ? comps1[0] : 0
        let g1 = comps1.count > 1 ? comps1[1] : 0
        let b1 = comps1.count > 2 ? comps1[2] : 0
        let r2 = comps2.count > 0 ? comps2[0] : 0
        let g2 = comps2.count > 1 ? comps2[1] : 0
        let b2 = comps2.count > 2 ? comps2[2] : 0
        let r = r1 + (r2 - r1) * p
        let g = g1 + (g2 - g1) * p
        let b = b1 + (b2 - b1) * p
        return CGColor(red: r, green: g, blue: b, alpha: a)
    }

    private static func glimmerStyle(for theme: PondTheme) -> (color: (CGFloat, CGFloat, CGFloat), alpha: CGFloat) {
        switch theme {
        case .day:
            return ((0.77, 0.98, 0.82), 0.07)
        case .dawn:
            return ((0.95, 0.90, 0.76), 0.06)
        case .goldenHour:
            return ((1.00, 0.88, 0.60), 0.08)
        case .dusk:
            return ((0.92, 0.75, 0.85), 0.05)
        case .night:
            return ((0.60, 0.85, 1.00), 0.02)
        case .deepClear:
            return ((0.85, 1.00, 0.98), 0.08)
        case .rain:
            return ((0.88, 0.94, 0.96), 0.05)
        }
    }

    private static func lerpGlimmer(
        from g1: GlimmerStyle,
        to g2: GlimmerStyle,
        t: CGFloat
    ) -> GlimmerStyle {
        let p = max(0, min(1, t))
        let r = g1.color.0 + (g2.color.0 - g1.color.0) * p
        let g = g1.color.1 + (g2.color.1 - g1.color.1) * p
        let b = g1.color.2 + (g2.color.2 - g1.color.2) * p
        let a = g1.alpha + (g2.alpha - g1.alpha) * p
        return (color: (r, g, b), alpha: a)
    }

    private static func blendedSurfaceStrokes(
        simulation: PondSimulation,
        size: CGSize,
        fromTheme: PondTheme,
        toTheme: PondTheme,
        progress: CGFloat,
        customSourceGlimmer: GlimmerStyle? = nil
    ) -> [PondStroke] {
        var strokes: [PondStroke] = []
        let unit = min(size.width, size.height) / 270
        let gA = customSourceGlimmer ?? glimmerStyle(for: fromTheme)
        let gB = glimmerStyle(for: toTheme)
        let t = max(0, min(1, progress))
        let gr = gA.color.0 + (gB.color.0 - gA.color.0) * t
        let gg = gA.color.1 + (gB.color.1 - gA.color.1) * t
        let gb = gA.color.2 + (gB.color.2 - gA.color.2) * t
        let gAlpha = gA.alpha + (gB.alpha - gA.alpha) * t

        for i in 0..<12 {
            let seed = Double(i)
            let x = size.width * CGFloat(0.10 + (sin(seed * 7.3) * 0.5 + 0.5) * 0.80) + CGFloat(sin(simulation.elapsedTime * 0.11 + seed)) * unit * 2
            let y = size.height * CGFloat(0.10 + (cos(seed * 4.7) * 0.5 + 0.5) * 0.80)
            let path = CGMutablePath()
            path.move(to: CGPoint(x: x - unit * 2, y: y))
            path.addQuadCurve(to: CGPoint(x: x + unit * 5, y: y + unit * 0.3), control: CGPoint(x: x, y: y + unit))
            let visibility = CGFloat(0.5 + 0.5 * sin(simulation.elapsedTime * 0.35 + seed * 2.3))
            strokes.append(PondStroke(
                path: path,
                color: CGColor(red: gr, green: gg, blue: gb, alpha: visibility * gAlpha),
                width: unit * 0.25
            ))
        }

        if simulation.isRainActive {
            // Strictly bounded atmospheric falling rain streaks (16 streaks max)
            for i in 0..<16 {
                let seed = Double(i)
                let rainX = CGFloat(fmod(Double(size.width) * (0.05 + Double(i) * 0.06) + simulation.elapsedTime * 60.0, Double(size.width)))
                let rainY = CGFloat(fmod(Double(size.height) * (sin(seed * 3.1) * 0.5 + 0.5) + simulation.elapsedTime * 350.0, Double(size.height)))
                let streakLength = unit * 4.5
                let path = CGMutablePath()
                path.move(to: CGPoint(x: rainX - streakLength * 0.35, y: rainY - streakLength))
                path.addLine(to: CGPoint(x: rainX, y: rainY))
                strokes.append(PondStroke(
                    path: path,
                    color: CGColor(red: 0.85, green: 0.92, blue: 0.98, alpha: 0.25),
                    width: 1.0
                ))
            }
        }
        for ripple in simulation.ripples where !ripple.isDead {
            let center = CGPoint(x: ripple.center.x, y: ripple.center.y)
            let radius = CGFloat(ripple.radius)
            let alpha = CGFloat(ripple.alpha)
            let color: (CGFloat, CGFloat, CGFloat)
            switch ripple.type {
            case .waterCall: color = (0.61, 0.91, 0.77)
            case .foodDrop: color = (0.98, 0.71, 0.34)
            case .eatingNibble: color = (0.93, 0.98, 0.86)
            case .rainDrop: color = (0.78, 0.88, 0.95)
            }
            let strokeWidth: CGFloat = (ripple.type == .rainDrop) ? 1.0 : 1.5
            let path = CGPath(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2), transform: nil)
            strokes.append(PondStroke(path: path, color: CGColor(red: color.0, green: color.1, blue: color.2, alpha: alpha * 0.75), width: strokeWidth))
            if radius > 16 && ripple.type != .eatingNibble && ripple.type != .rainDrop {
                let r = radius * 0.65
                let inner = CGPath(ellipseIn: CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2), transform: nil)
                strokes.append(PondStroke(path: inner, color: CGColor(red: color.0, green: color.1, blue: color.2, alpha: alpha * 0.35), width: 1))
            }
        }
        return strokes
    }

    private static func surfaceStrokes(simulation: PondSimulation, size: CGSize, phase: TimeOfDayPhase) -> [PondStroke] {
        blendedSurfaceStrokes(simulation: simulation, size: size, fromTheme: phase.theme, toTheme: phase.theme, progress: 1.0)
    }
}
