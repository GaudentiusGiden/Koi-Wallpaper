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
                bitmap.setAlpha(phase == .night ? 0.18 : (phase == .dusk ? 0.35 : 1))
                Self.drawVoronoi(in: bitmap, size: meshSize, layer: layer)
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

    private static func drawVoronoi(in context: CGContext, size: CGSize, layer: Int) {
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
        let luminous = CGMutablePath()
        let faint = CGMutablePath()
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
                    // Variation is spatial and stable, never random from frame to frame.
                    let selector = (row * 17 + col * 31 + i * 7) % 13
                    if selector == 0 { continue }
                    let path = selector < 5 ? luminous : faint
                    let a = polygon[i], b = polygon[(i + 1) % polygon.count]
                    path.move(to: warp(a))
                    path.addQuadCurve(to: warp(b), control: warp(CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2)))
                }
            }
        }
        let unit = short / 270
        context.setLineCap(.round)
        context.setLineJoin(.round)
        context.setStrokeColor(red: 0.58, green: 0.98, blue: 0.77, alpha: layer == 0 ? 0.060 : 0.018)
        context.setLineWidth(unit * (layer == 0 ? 1.8 : 0.8))
        context.addPath(luminous)
        context.strokePath()
        context.setStrokeColor(red: 0.60, green: 0.98, blue: 0.78, alpha: layer == 0 ? 0.210 : 0.075)
        context.setLineWidth(unit * (layer == 0 ? 0.25 : 0.13))
        context.addPath(luminous)
        context.strokePath()
        context.setStrokeColor(red: 0.46, green: 0.88, blue: 0.67, alpha: layer == 0 ? 0.070 : 0.040)
        context.setLineWidth(unit * (layer == 0 ? 0.20 : 0.11))
        context.addPath(faint)
        context.strokePath()
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
