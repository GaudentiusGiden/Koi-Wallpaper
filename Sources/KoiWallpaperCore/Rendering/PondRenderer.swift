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
    let caustics: [PondImagePlacement]
    let swimmers: PondImagePlacement?
    let surface: [PondStroke]
    let flora: [PondImagePlacement]
    let tint: CGColor?
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
    private let water = PondWaterSurface()
    private var sceneContext: CGContext?
    private var scenePixels: CGSize = .zero
    private var cachedFlora: [PondImagePlacement] = []
    private var floraSize: CGSize = .zero
    private var floraPixelSize: CGFloat = 0
    private var floraPhase: TimeOfDayPhase = .day

    public init() {}

    public func render(simulation: PondSimulation, in context: CGContext, rect: CGRect, phase: TimeOfDayPhase = .day) {
        guard rect.width > 0, rect.height > 0 else { return }
        let scale = max(1, hypot(context.ctm.a, context.ctm.c))
        let frame = makeFrame(simulation: simulation, size: rect.size, scale: scale, phase: phase)
        context.saveGState()
        context.clip(to: rect)
        context.translateBy(x: rect.minX, y: rect.minY)
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
        context.restoreGState()
    }

    func makeFrame(simulation: PondSimulation, size: CGSize, scale: CGFloat, phase: TimeOfDayPhase) -> PondRenderFrame {
        let short = min(size.width, size.height)
        // Whole backing-pixel enlargement: ~480x270 at 16:9, without stretching.
        let pixelSize = max(1, (short * scale / 270).rounded()) / scale
        let pixels = CGSize(width: ceil(size.width / pixelSize), height: ceil(size.height / pixelSize))
        water.prepare(size: size, scale: scale, phase: phase)
        if sceneContext == nil || pixels != scenePixels {
            scenePixels = pixels
            sceneContext = CGContext(data: nil, width: Int(pixels.width), height: Int(pixels.height),
                                     bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
                                     bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        }
        var swimmers: PondImagePlacement?
        if let bitmap = sceneContext {
            bitmap.clear(CGRect(origin: .zero, size: pixels))
            bitmap.saveGState()
            bitmap.scaleBy(x: 1 / pixelSize, y: 1 / pixelSize)
            bitmap.setShouldAntialias(false)
            DecorativeFishArtwork.draw(in: bitmap, size: size, time: simulation.elapsedTime, phase: phase)
            for fish in simulation.fish { KoiArtwork.draw(fish, in: bitmap, drawShadowOnly: true, phase: phase) }
            for fish in simulation.fish { KoiArtwork.draw(fish, in: bitmap, phase: phase) }
            PondArtwork.drawPellets(simulation.pellets, in: bitmap)
            bitmap.restoreGState()
            if let image = bitmap.makeImage() {
                swimmers = PondImagePlacement(image: image,
                    rect: CGRect(x: 0, y: 0, width: pixels.width * pixelSize, height: pixels.height * pixelSize), pixelated: true)
            }
        }
        if floraSize != size || floraPixelSize != pixelSize || floraPhase != phase {
            floraSize = size
            floraPixelSize = pixelSize
            floraPhase = phase
            let local = PondFloraArtwork.localBounds(shortSide: short)
            // Round crop extents to the same grid as the swimmers.
            let crop = CGRect(x: floor(local.minX / pixelSize) * pixelSize, y: floor(local.minY / pixelSize) * pixelSize,
                              width: ceil(local.width / pixelSize) * pixelSize, height: ceil(local.height / pixelSize) * pixelSize)
            cachedFlora = PondFloraArtwork.anchors.enumerated().compactMap { index, anchor in
                guard let image = PondBitmap.makeImage(size: crop.size, scale: 1 / pixelSize, pixelated: true, draw: { bitmap in
                    bitmap.translateBy(x: -crop.minX, y: -crop.minY)
                    PondFloraArtwork.drawCluster(index, in: bitmap, shortSide: short, phase: phase)
                }) else { return nil }
                let x = (anchor.x * size.width / pixelSize).rounded() * pixelSize
                let y = (anchor.y * size.height / pixelSize).rounded() * pixelSize
                return PondImagePlacement(image: image, rect: crop.offsetBy(dx: x, dy: y), pixelated: true)
            }
        }
        let flora = cachedFlora.enumerated().map { index, source -> PondImagePlacement in
            let t = simulation.elapsedTime
            let dx = (CGFloat(sin(t * 0.18 + Double(index))) * short * 0.0025 * scale).rounded() / scale
            let dy = (CGFloat(cos(t * 0.15 + Double(index) * 1.3)) * short * 0.0018 * scale).rounded() / scale
            return PondImagePlacement(image: source.image, rect: source.rect.offsetBy(dx: dx, dy: dy), pixelated: true,
                                      angle: CGFloat(sin(t * 0.16 + Double(index))) * 0.005)
        }
        return PondRenderFrame(size: size,
            bed: water.bed.map { PondImagePlacement(image: $0, rect: CGRect(origin: .zero, size: size), pixelated: false) },
            caustics: water.placements(time: simulation.elapsedTime), swimmers: swimmers,
            surface: Self.surfaceStrokes(simulation: simulation, size: size, phase: phase), flora: flora, tint: Self.tint(phase))
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

    private static func tint(_ phase: TimeOfDayPhase) -> CGColor? {
        switch phase {
        case .day: return nil
        case .dawn: return CGColor(red: 0.90, green: 0.65, blue: 0.40, alpha: 0.05)
        case .dusk: return CGColor(red: 0.85, green: 0.45, blue: 0.25, alpha: 0.08)
        case .night: return CGColor(red: 0.05, green: 0.12, blue: 0.28, alpha: 0.14)
        }
    }

    private static func surfaceStrokes(simulation: PondSimulation, size: CGSize, phase: TimeOfDayPhase) -> [PondStroke] {
        var strokes: [PondStroke] = []
        let unit = min(size.width, size.height) / 270
        for i in 0..<12 {
            let seed = Double(i)
            let x = size.width * CGFloat(0.10 + (sin(seed * 7.3) * 0.5 + 0.5) * 0.80) + CGFloat(sin(simulation.elapsedTime * 0.11 + seed)) * unit * 2
            let y = size.height * CGFloat(0.10 + (cos(seed * 4.7) * 0.5 + 0.5) * 0.80)
            let path = CGMutablePath()
            path.move(to: CGPoint(x: x - unit * 2, y: y))
            path.addQuadCurve(to: CGPoint(x: x + unit * 5, y: y + unit * 0.3), control: CGPoint(x: x, y: y + unit))
            let visibility = CGFloat(0.5 + 0.5 * sin(simulation.elapsedTime * 0.35 + seed * 2.3))
            strokes.append(PondStroke(path: path, color: CGColor(red: 0.77, green: 0.97, blue: 0.78,
                alpha: visibility * (phase == .night ? 0.015 : 0.07)), width: unit * 0.25))
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
            }
            let path = CGPath(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2), transform: nil)
            strokes.append(PondStroke(path: path, color: CGColor(red: color.0, green: color.1, blue: color.2, alpha: alpha * 0.75), width: 1.5))
            if radius > 16 && ripple.type != .eatingNibble {
                let r = radius * 0.65
                let inner = CGPath(ellipseIn: CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2), transform: nil)
                strokes.append(PondStroke(path: inner, color: CGColor(red: color.0, green: color.1, blue: color.2, alpha: alpha * 0.35), width: 1))
            }
        }
        return strokes
    }
}
