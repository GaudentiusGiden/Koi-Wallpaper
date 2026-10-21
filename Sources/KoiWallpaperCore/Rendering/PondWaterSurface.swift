import CoreGraphics
import Foundation

/// Bounded, viewport-local water textures shared by the native layer host and
/// offscreen renderer. No texture allocation or tessellation occurs on warm frames.
final class PondWaterSurface {
    private var keySize: CGSize = .zero
    private var keyScale: CGFloat = 0
    private var keyPhase: TimeOfDayPhase?
    private(set) var bed: CGImage?
    private var networks: [CGImage] = []
    private var overscan: CGFloat = 48

    func prepare(size: CGSize, scale: CGFloat, phase: TimeOfDayPhase) {
        guard size != keySize || scale != keyScale || phase != keyPhase else { return }
        keySize = size
        keyScale = scale
        keyPhase = phase
        overscan = max(24, min(size.width, size.height) * 0.055)
        let meshSize = CGSize(width: size.width + overscan * 2, height: size.height + overscan * 2)
        // Soft light does not need a full Retina backing store. The GPU samples it
        // linearly; bounding all three textures avoids multiplying monitor memory.
        let rasterScale = min(scale, 1536 / max(meshSize.width, meshSize.height), sqrt(2_250_000 / (meshSize.width * meshSize.height)))
        bed = PondBitmap.makeImage(size: size, scale: rasterScale) {
            PondArtwork.drawWater(in: $0, rect: CGRect(origin: .zero, size: size), phase: phase)
        }
        networks = (0..<2).compactMap { layer in
            PondBitmap.makeImage(size: meshSize, scale: rasterScale) { bitmap in
                Self.drawVoronoi(in: bitmap, size: meshSize, layer: layer, phase: phase)
            }
        }
    }

    func placements(time: Double) -> [PondImagePlacement] {
        let short = min(keySize.width, keySize.height)
        return networks.enumerated().map { index, image in
            let speed = index == 0 ? 0.11 : -0.075
            let x = (CGFloat(sin(time * speed + Double(index) * 2)) * short * 0.014 * keyScale).rounded() / keyScale
            let y = (CGFloat(cos(time * speed * 0.8 + Double(index))) * short * 0.010 * keyScale).rounded() / keyScale
            return PondImagePlacement(image: image,
                rect: CGRect(x: -overscan + x, y: -overscan + y,
                             width: keySize.width + overscan * 2, height: keySize.height + overscan * 2), pixelated: false)
        }
    }

    private static func drawVoronoi(in context: CGContext, size: CGSize, layer: Int, phase: TimeOfDayPhase) {
        let short = min(size.width, size.height)
        let spacing = short * (layer == 0 ? 0.105 : 0.047)
        let cols = Int(ceil(size.width / spacing)) + 4
        let rows = Int(ceil(size.height / spacing)) + 4
        var rng = SeededRandomNumberGenerator(seed: UInt64(8191 + layer * 457))
        var sites: [CGPoint] = []
        for y in 0..<rows {
            for x in 0..<cols {
                sites.append(CGPoint(x: (CGFloat(x - 2) + CGFloat(Double.random(in: -0.43...0.43, using: &rng))) * spacing,
                                     y: (CGFloat(y - 2) + CGFloat(Double.random(in: -0.43...0.43, using: &rng))) * spacing))
            }
        }
        func warp(_ p: CGPoint) -> CGPoint {
            CGPoint(x: p.x + sin(p.y / short * 14 + p.x / short * 9) * short * 0.012,
                    y: p.y + sin(p.x / short * 17 - p.y / short * 8) * short * 0.010)
        }
        // Bake visibility into four paths rather than applying a uniform bright
        // web across the deep water. No mask texture or per-frame work is needed.
        let luminous = (0..<4).map { _ in CGMutablePath() }
        let faint = (0..<4).map { _ in CGMutablePath() }

        for row in 1..<(rows - 1) {
            for col in 1..<(cols - 1) {
                let site = sites[row * cols + col]
                var polygon = [CGPoint(x: site.x - spacing * 1.8, y: site.y - spacing * 1.8),
                               CGPoint(x: site.x + spacing * 1.8, y: site.y - spacing * 1.8),
                               CGPoint(x: site.x + spacing * 1.8, y: site.y + spacing * 1.8),
                               CGPoint(x: site.x - spacing * 1.8, y: site.y + spacing * 1.8)]
                for dy in -2...2 {
                    for dx in -2...2 {
                        let nx = col + dx, ny = row + dy
                        guard nx >= 0, ny >= 0, nx < cols, ny < rows, dx != 0 || dy != 0 else { continue }
                        let other = sites[ny * cols + nx]
                        let normal = CGPoint(x: other.x - site.x, y: other.y - site.y)
                        let limit = (other.x * other.x + other.y * other.y - site.x * site.x - site.y * site.y) / 2
                        polygon = clip(polygon, normal: normal, limit: limit)
                    }
                }
                guard polygon.count > 2 else { continue }
                for i in polygon.indices {
                    let selector = (row * 17 + col * 31 + i * 7) % 13
                    if selector == 0 { continue }
                    let a = polygon[i], b = polygon[(i + 1) % polygon.count]
                    let midpoint = CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2)
                    let exposure = PondLighting.causticExposure(at: CGPoint(
                        x: midpoint.x / size.width, y: midpoint.y / size.height))
                    let band = min(3, max(0, Int(exposure * 4)))
                    let path = selector < 5 ? luminous[band] : faint[band]
                    let wa = warp(a)
                    let wb = warp(b)
                    path.move(to: wa)
                    path.addQuadCurve(to: wb, control: warp(midpoint))
                }
            }
        }
        let unit = short / 270
        context.setLineCap(.round)
        context.setLineJoin(.round)

        // Phase-specific caustic color palettes
        let outerColor: (CGFloat, CGFloat, CGFloat)
        let innerColor: (CGFloat, CGFloat, CGFloat)
        let faintColor: (CGFloat, CGFloat, CGFloat)
        let phaseAlphaGain: CGFloat

        switch phase {
        case .day:
            outerColor = (0.58, 0.98, 0.80)
            innerColor = (0.68, 1.00, 0.86)
            faintColor = (0.46, 0.88, 0.68)
            phaseAlphaGain = 1.0
        case .dawn:
            outerColor = (0.88, 0.94, 0.72)
            innerColor = (0.96, 0.98, 0.80)
            faintColor = (0.76, 0.84, 0.62)
            phaseAlphaGain = 0.82
        case .dusk:
            outerColor = (0.80, 0.68, 0.76)
            innerColor = (0.90, 0.78, 0.84)
            faintColor = (0.68, 0.58, 0.66)
            phaseAlphaGain = 0.55
        case .night:
            outerColor = (0.42, 0.70, 0.92)
            innerColor = (0.55, 0.82, 0.98)
            faintColor = (0.32, 0.55, 0.78)
            phaseAlphaGain = 0.38
        }

        for band in 0..<4 {
            let exposure = [0.30, 0.55, 0.95, 1.65][band] * phaseAlphaGain
            context.setStrokeColor(red: outerColor.0, green: outerColor.1, blue: outerColor.2,
                                   alpha: (layer == 0 ? 0.035 : 0.012) * exposure)
            context.setLineWidth(unit * (layer == 0 ? 2.0 : 0.90))
            context.addPath(luminous[band])
            context.strokePath()

            context.setStrokeColor(red: outerColor.0, green: outerColor.1, blue: outerColor.2,
                                   alpha: (layer == 0 ? 0.075 : 0.030) * exposure)
            context.setLineWidth(unit * (layer == 0 ? 0.65 : 0.30))
            context.addPath(luminous[band])
            context.strokePath()

            context.setStrokeColor(red: innerColor.0, green: innerColor.1, blue: innerColor.2,
                                   alpha: (layer == 0 ? 0.19 : 0.065) * exposure)
            context.setLineWidth(unit * (layer == 0 ? 0.25 : 0.12))
            context.addPath(luminous[band])
            context.strokePath()

            context.setStrokeColor(red: faintColor.0, green: faintColor.1, blue: faintColor.2,
                                   alpha: (layer == 0 ? 0.055 : 0.025) * exposure)
            context.setLineWidth(unit * (layer == 0 ? 0.20 : 0.11))
            context.addPath(faint[band])
            context.strokePath()
        }
    }

    private static func clip(_ polygon: [CGPoint], normal: CGPoint, limit: CGFloat) -> [CGPoint] {
        guard let last = polygon.last else { return [] }
        func distance(_ p: CGPoint) -> CGFloat { p.x * normal.x + p.y * normal.y - limit }
        var result: [CGPoint] = []
        var previous = last
        var d0 = distance(previous)
        for point in polygon {
            let d1 = distance(point)
            if (d0 <= 0) != (d1 <= 0) {
                let t = d0 / (d0 - d1)
                result.append(CGPoint(x: previous.x + (point.x - previous.x) * t, y: previous.y + (point.y - previous.y) * t))
            }
            if d1 <= 0 { result.append(point) }
            previous = point
            d0 = d1
        }
        return result
    }
}
