import CoreGraphics
import Foundation

/// Bounded, viewport-local water textures shared by the native layer host and
/// offscreen renderer. No texture allocation or tessellation occurs on warm frames.
public final class PondWaterSurface {
    private var keySize: CGSize = .zero
    private var keyScale: CGFloat = 0
    private(set) var keyTheme: PondTheme?
    private(set) var bed: CGImage?
    public private(set) var networks: [CGImage] = []
    private var overscan: CGFloat = 48

    public init() {}

    func clear() {
        bed = nil
        networks.removeAll(keepingCapacity: false)
        keyTheme = nil
        keySize = .zero
        keyScale = 0
    }

    func adopt(from other: PondWaterSurface) {
        self.keySize = other.keySize
        self.keyScale = other.keyScale
        self.keyTheme = other.keyTheme
        self.bed = other.bed
        self.networks = other.networks
        self.overscan = other.overscan
        other.clear()
    }

    func copyForSnapshot() -> PondWaterSurface {
        let copy = PondWaterSurface()
        copy.keySize = keySize
        copy.keyScale = keyScale
        copy.keyTheme = keyTheme
        copy.bed = bed
        copy.networks = networks
        copy.overscan = overscan
        return copy
    }

    var hasCompleteAssets: Bool {
        bed != nil && networks.count == 3
    }

    func hasCompleteAssets(for size: CGSize, scale: CGFloat) -> Bool {
        keySize == size && keyScale == scale && bed != nil && networks.count == 3
    }

    func isPrepared(size: CGSize, scale: CGFloat, theme: PondTheme) -> Bool {
        keyTheme == theme && hasCompleteAssets(for: size, scale: scale)
    }

    public func prepare(size: CGSize, scale: CGFloat, theme: PondTheme) {
        guard size != keySize || scale != keyScale || theme != keyTheme || bed == nil || networks.count != 3 else { return }
        keySize = size
        keyScale = scale
        keyTheme = theme
        overscan = max(24, min(size.width, size.height) * 0.055)
        let meshSize = CGSize(width: size.width + overscan * 2, height: size.height + overscan * 2)
        // Keep the water treatment softly stepped instead of rendering a full
        // Retina texture. Bounding all three caches also limits multi-monitor memory.
        let bedRasterScale = min(scale, 0.50, 1024 / max(size.width, size.height), sqrt(800_000 / (size.width * size.height)))
        guard let newBed = PondBitmap.makeImage(size: size, scale: bedRasterScale, draw: {
            PondArtwork.drawWater(in: $0, rect: CGRect(origin: .zero, size: size), theme: theme)
        }) else {
            bed = nil
            networks = []
            keyTheme = nil
            return
        }
        let meshRasterScale = min(scale * 0.45, 0.45, 800 / max(meshSize.width, meshSize.height), sqrt(500_000 / (meshSize.width * meshSize.height)))
        let newNetworks = (0..<3).compactMap { layer in
            PondBitmap.makeImage(size: meshSize, scale: meshRasterScale) { bitmap in
                Self.drawVoronoi(in: bitmap, size: meshSize, layer: layer, theme: theme)
            }
        }
        guard newNetworks.count == 3 else {
            bed = nil
            networks = []
            keyTheme = nil
            return
        }
        bed = newBed
        networks = newNetworks
    }

    func prepare(size: CGSize, scale: CGFloat, phase: TimeOfDayPhase) {
        prepare(size: size, scale: scale, theme: phase.theme)
    }

    @discardableResult
    func snapshotBlend(with target: PondWaterSurface, progress: CGFloat) -> Bool {
        guard let bedA = self.bed, let bedB = target.bed,
              self.networks.count == 3, target.networks.count == 3,
              keySize.width > 0, keySize.height > 0 else {
            return false
        }
        let p = max(0, min(1, progress))
        let bedRasterScale = min(keyScale > 0 ? keyScale : 1.0, 1536 / max(keySize.width, keySize.height), sqrt(2_250_000 / (keySize.width * keySize.height)))

        guard let newBed = PondBitmap.makeImage(size: keySize, scale: bedRasterScale, draw: { ctx in
            ctx.saveGState()
            // Base layer remains at full opacity; incoming layer fades in at p (source-over compositing)
            ctx.draw(bedA, in: CGRect(origin: .zero, size: keySize))
            ctx.setAlpha(p)
            ctx.draw(bedB, in: CGRect(origin: .zero, size: keySize))
            ctx.restoreGState()
        }) else {
            return false
        }

        let meshSize = CGSize(width: keySize.width + overscan * 2, height: keySize.height + overscan * 2)
        // Bound meshRasterScale by meshSize (including overscan) to ensure mesh textures never exceed 800 px or 500k pixels
        let meshRasterScale = min(keyScale > 0 ? keyScale * 0.45 : 0.45, 0.45, 800 / max(meshSize.width, meshSize.height), sqrt(500_000 / (meshSize.width * meshSize.height)))

        let newNetworks: [CGImage] = (0..<3).compactMap { i in
            let netA = self.networks[i]
            let netB = target.networks[i]
            return PondBitmap.makeImage(size: meshSize, scale: meshRasterScale) { ctx in
                ctx.saveGState()
                ctx.setAlpha(1.0 - p)
                ctx.draw(netA, in: CGRect(origin: .zero, size: meshSize))
                ctx.setBlendMode(.plusLighter)
                ctx.setAlpha(p)
                ctx.draw(netB, in: CGRect(origin: .zero, size: meshSize))
                ctx.restoreGState()
            }
        }

        guard newNetworks.count == 3 else { return false }

        self.bed = newBed
        self.networks = newNetworks
        self.keyTheme = nil
        return true
    }

    func placements(time: Double) -> [PondImagePlacement] {
        let short = min(keySize.width, keySize.height)
        let dirA = PondWaterCurrent.waveDirectionA
        let dirB = PondWaterCurrent.waveDirectionB
        let dirC = PondWaterCurrent.waveDirectionC

        return networks.enumerated().map { index, image in
            let dx: CGFloat
            let dy: CGFloat
            if index == 0 {
                // Layer 0: Large caustics (Wave Direction A)
                let phase = time * 0.12 * PondWaterCurrent.waveSpeedA
                dx = CGFloat(cos(phase) * dirA.x - sin(phase * 0.8) * dirA.y) * short * 0.018
                dy = CGFloat(sin(phase) * dirA.y + cos(phase * 0.8) * dirA.x) * short * 0.014
            } else if index == 1 {
                // Layer 1: Secondary large caustics (Wave Direction B)
                let phase = time * 0.16 * PondWaterCurrent.waveSpeedB + 1.2
                dx = CGFloat(cos(phase) * dirB.x + sin(phase * 0.7) * 0.2) * short * 0.014
                dy = CGFloat(sin(phase) * dirB.y - cos(phase * 0.7) * 0.2) * short * 0.014
            } else {
                // Layer 2: Detail sparkling caustics (Wave Direction C shimmer)
                let phase = time * 0.38 + 2.7
                dx = CGFloat(sin(phase) * dirC.x + cos(time * 0.55) * 0.22) * short * 0.010
                dy = CGFloat(cos(phase) * dirC.y - sin(time * 0.55) * 0.22) * short * 0.010
            }
            let quantX = (dx * keyScale).rounded() / keyScale
            let quantY = (dy * keyScale).rounded() / keyScale
            return PondImagePlacement(
                image: image,
                rect: CGRect(x: -overscan + quantX, y: -overscan + quantY,
                             width: keySize.width + overscan * 2, height: keySize.height + overscan * 2),
                pixelated: false
            )
        }
    }

    private static func drawVoronoi(in context: CGContext, size: CGSize, layer: Int, theme: PondTheme) {
        let short = min(size.width, size.height)
        let spacing: CGFloat
        if layer == 0 {
            spacing = short * 0.120 // Large current layer
        } else if layer == 1 {
            spacing = short * 0.055 // Secondary large current layer
        } else {
            spacing = short * 0.028 // Detail current layer
        }
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
                if layer == 2 {
                    // Match Nagomi detail_region: patchy organic distribution
                    let detailRegion = (row * 19 + col * 37) % 11
                    if detailRegion < 4 { continue }
                }
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

        let caustics = theme.renderPalette.caustics
        let outerColor = caustics.outer.components
        let innerColor = caustics.inner.components
        let faintColor = caustics.faint.components
        let phaseAlphaGain = caustics.alphaGain

        let layerOpacity: CGFloat
        let lineWidthOuter: CGFloat
        let lineWidthMid: CGFloat
        let lineWidthInner: CGFloat
        let lineWidthFaint: CGFloat
        let alphaOuterBase: CGFloat
        let alphaMidBase: CGFloat
        let alphaInnerBase: CGFloat
        let alphaFaintBase: CGFloat

        if layer == 0 {
            layerOpacity = caustics.largeOpacity
            lineWidthOuter = unit * 2.2
            lineWidthMid = unit * 0.70
            lineWidthInner = unit * 0.28
            lineWidthFaint = unit * 0.20
            alphaOuterBase = 0.038
            alphaMidBase = 0.080
            alphaInnerBase = 0.20
            alphaFaintBase = 0.060
        } else if layer == 1 {
            layerOpacity = caustics.secondaryOpacity
            lineWidthOuter = unit * 1.1
            lineWidthMid = unit * 0.38
            lineWidthInner = unit * 0.15
            lineWidthFaint = unit * 0.12
            alphaOuterBase = 0.020
            alphaMidBase = 0.045
            alphaInnerBase = 0.10
            alphaFaintBase = 0.035
        } else {
            layerOpacity = caustics.detailOpacity
            lineWidthOuter = unit * 0.60
            lineWidthMid = unit * 0.24
            lineWidthInner = unit * 0.10
            lineWidthFaint = unit * 0.08
            alphaOuterBase = 0.015
            alphaMidBase = 0.035
            alphaInnerBase = 0.075
            alphaFaintBase = 0.025
        }

        for band in 0..<4 {
            let exposure = [0.30, 0.55, 0.95, 1.65][band] * phaseAlphaGain * layerOpacity
            context.setStrokeColor(red: outerColor.0, green: outerColor.1, blue: outerColor.2,
                                   alpha: alphaOuterBase * exposure)
            context.setLineWidth(lineWidthOuter)
            context.addPath(luminous[band])
            context.strokePath()

            context.setStrokeColor(red: outerColor.0, green: outerColor.1, blue: outerColor.2,
                                   alpha: alphaMidBase * exposure)
            context.setLineWidth(lineWidthMid)
            context.addPath(luminous[band])
            context.strokePath()

            context.setStrokeColor(red: innerColor.0, green: innerColor.1, blue: innerColor.2,
                                   alpha: alphaInnerBase * exposure)
            context.setLineWidth(lineWidthInner)
            context.addPath(luminous[band])
            context.strokePath()

            context.setStrokeColor(red: faintColor.0, green: faintColor.1, blue: faintColor.2,
                                   alpha: alphaFaintBase * exposure)
            context.setLineWidth(lineWidthFaint)
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
