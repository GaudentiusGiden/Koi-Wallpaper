import CoreGraphics
import Foundation

/// Procedural artwork generator for pond elements: deep water, underwater caustics,
/// lily pads, lotus flowers, food pellets, and surface ripples.
public enum PondArtwork {

    // MARK: - Water Background & Caustics

    public static func drawWater(in context: CGContext, rect: CGRect, theme: PondTheme = .day) {
        guard rect.width > 0, rect.height > 0 else { return }
        context.saveGState()
        context.translateBy(x: rect.minX, y: rect.minY)
        let w = rect.width, h = rect.height
        let space = CGColorSpaceCreateDeviceRGB()
        let palette = theme.renderPalette
        let depthColors = palette.waterDepth.map(\.cgColor)
        let lightColor = palette.opening.components
        let deepTealColor = palette.deepWater.components
        let oliveColor = palette.shelteredWater.components
        let gain = palette.waterLightGain

        context.setFillColor(depthColors.last!)
        context.fill(CGRect(x: 0, y: 0, width: w, height: h))
        if let gradient = CGGradient(colorsSpace: space, colors: depthColors as CFArray,
                                     locations: [0, 0.15, 0.34, 0.58, 0.88]) {
            context.drawRadialGradient(gradient,
                startCenter: CGPoint(x: w * 0.50, y: h * 0.96), startRadius: 0,
                endCenter: CGPoint(x: w * 0.52, y: h * 0.50), endRadius: max(w, h) * 0.76,
                options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
        }

        func wash(_ x: CGFloat, _ y: CGFloat, _ rx: CGFloat, _ ry: CGFloat,
                  _ angle: CGFloat, color: (CGFloat, CGFloat, CGFloat), alpha: CGFloat) {
            context.saveGState()
            context.translateBy(x: x * w, y: y * h)
            context.rotate(by: angle)
            context.scaleBy(x: rx * w, y: ry * h)
            let colors = [0.95, 0.57, 0.15, 0.0].map {
                CGColor(red: color.0, green: color.1, blue: color.2, alpha: alpha * $0)
            }
            if let gradient = CGGradient(colorsSpace: space, colors: colors as CFArray, locations: [0, 0.30, 0.65, 1]) {
                context.drawRadialGradient(gradient, startCenter: .zero, startRadius: 0,
                                           endCenter: .zero, endRadius: 1, options: [])
            }
            context.restoreGState()
        }

        // Wide overhead opening and an oblique shaft filtering past the left
        // shoreline. Confined to upper opening so middle-to-bottom pool stays deep.
        wash(0.50, 0.96, 0.50, 0.22, -0.08, color: lightColor, alpha: 0.98 * gain)
        wash(0.78, 0.94, 0.34, 0.19, -0.22, color: lightColor, alpha: 0.78 * gain)

        wash(0.13, 0.58, 0.20, 0.42, -0.52, color: lightColor, alpha: 0.82 * gain)
        wash(0.29, 0.77, 0.14, 0.25, -0.60, color: lightColor, alpha: 0.32 * gain)

        // 1. Deep aquatic jade/teal washes: sunken basin floor and shoreline edges.
        wash(0.52, 0.18, 0.54, 0.28, -0.05, color: deepTealColor, alpha: 0.36)
        wash(0.50, -0.05, 0.60, 0.22, 0, color: deepTealColor, alpha: 0.45)
        wash(1.08, 0.45, 0.16, 0.46, 0.10, color: deepTealColor, alpha: 0.35)
        wash(-0.04, 0.04, 0.22, 0.22, -0.15, color: deepTealColor, alpha: 0.35)

        // 2. Sheltered corner nuances with subtle olive-green warmth:
        // Placed in sheltered recesses beneath vegetation clusters.
        wash(0.08, 0.03, 0.24, 0.24, 0.15, color: oliveColor, alpha: 0.45)
        wash(0.92, 0.03, 0.26, 0.26, -0.20, color: oliveColor, alpha: 0.45)
        wash(-0.02, 0.90, 0.22, 0.24, -0.20, color: oliveColor, alpha: 0.38)
        wash(0.98, 0.92, 0.24, 0.24, 0.20, color: oliveColor, alpha: 0.36)
        wash(0.50, 1.08, 0.44, 0.16, 0.05, color: oliveColor, alpha: 0.28)

        // Seeded sediment is part of the cached bed, never random screen noise.
        var random = SeededRandomNumberGenerator(seed: 405)
        let unit = min(w, h) / 270
        for _ in 0..<1600 {
            let x = CGFloat(Double.random(in: 0...1, using: &random)) * w
            let y = CGFloat(Double.random(in: 0...1, using: &random)) * h
            let size = CGFloat(Double.random(in: 0.35...0.95, using: &random)) * unit
            let exposure = PondLighting.causticExposure(at: CGPoint(x: x / w, y: y / h))
            let isMineral = Double.random(in: 0...1, using: &random) < Double(exposure * 0.19)
            if isMineral {
                context.setFillColor(red: lightColor.0, green: lightColor.1, blue: lightColor.2, alpha: 0.055 * gain)
            } else {
                context.setFillColor(red: deepTealColor.0, green: deepTealColor.1, blue: deepTealColor.2,
                                     alpha: 0.045 + exposure * 0.025)
            }
            context.fill(CGRect(x: x, y: y, width: size, height: size))
        }
        context.restoreGState()
    }

    public static func drawWater(in context: CGContext, rect: CGRect, phase: TimeOfDayPhase = .day) {
        drawWater(in: context, rect: rect, theme: phase.theme)
    }

    /// Atmospheric overlay representing ambient lighting (e.g. night darkness, dusk glow, dawn warmth).
    public static func drawAtmosphere(in context: CGContext, rect: CGRect, theme: PondTheme) {
        guard let atmosphere = theme.renderPalette.atmosphere else { return }
        context.saveGState()
        context.setFillColor(atmosphere.cgColor)
        context.fill(rect)
        context.restoreGState()
    }

    public static func drawAtmosphere(in context: CGContext, rect: CGRect, phase: TimeOfDayPhase) {
        drawAtmosphere(in: context, rect: rect, theme: phase.theme)
    }

    // MARK: - Food Pellets

    public static func drawPellets(_ pellets: [FoodPellet], in context: CGContext) {
        guard !pellets.isEmpty else { return }
        context.saveGState()

        for pellet in pellets where !pellet.isConsumed {
            let p = CGPoint(x: CGFloat(pellet.position.x), y: CGFloat(pellet.position.y))
            let r = CGFloat(pellet.radius)
            let bob = CGFloat(sin(pellet.bobbingPhase) * 0.8)

            // 1. Pellet Soft Shadow
            context.setFillColor(red: 0.01, green: 0.04, blue: 0.05, alpha: 0.4)
            context.fillEllipse(in: CGRect(x: p.x - r + 2.0, y: p.y - r - 3.0, width: r * 2.0, height: r * 2.0))

            // 2. Pellet Sphere Base (Golden amber brown)
            context.setFillColor(red: 0.76, green: 0.48, blue: 0.20, alpha: 1.0)
            context.fillEllipse(in: CGRect(x: p.x - r, y: p.y - r + bob, width: r * 2.0, height: r * 2.0))

            // 3. Highlight Specular Spot
            context.setFillColor(red: 0.95, green: 0.78, blue: 0.45, alpha: 0.85)
            context.fillEllipse(in: CGRect(x: p.x - r * 0.4, y: p.y + bob + r * 0.1, width: r * 0.7, height: r * 0.7))
        }

        context.restoreGState()
    }

    // MARK: - Surface Visitors Artwork (Swan & Temari Ball)

    public static func drawVisitorShadow(
        _ visitor: PondVisitor,
        in context: CGContext,
        shadowStyle: PondLighting.ShadowStyle
    ) {
        context.saveGState()
        let offset = PondLighting.shadowOffset(distance: 22.0)
        context.translateBy(x: CGFloat(visitor.position.x) + offset.x, y: CGFloat(visitor.position.y) + offset.y)
        context.rotate(by: CGFloat(visitor.heading))

        let c = shadowStyle.color
        switch visitor.type {
        case .swan:
            // Soft underwater drop shadow of the swan hull
            context.setFillColor(red: c.0, green: c.1, blue: c.2, alpha: shadowStyle.penumbraAlpha)
            context.fillEllipse(in: CGRect(x: -22, y: -12, width: 44, height: 24))
            context.setFillColor(red: c.0, green: c.1, blue: c.2, alpha: shadowStyle.coreAlpha)
            context.fillEllipse(in: CGRect(x: -18, y: -9, width: 36, height: 18))

        case .ball:
            // Circular shadow of the floating ball
            let r = CGFloat(visitor.radius)
            context.setFillColor(red: c.0, green: c.1, blue: c.2, alpha: shadowStyle.penumbraAlpha)
            context.fillEllipse(in: CGRect(x: -r * 1.1, y: -r * 1.1, width: r * 2.2, height: r * 2.2))
            context.setFillColor(red: c.0, green: c.1, blue: c.2, alpha: shadowStyle.coreAlpha)
            context.fillEllipse(in: CGRect(x: -r * 0.85, y: -r * 0.85, width: r * 1.7, height: r * 1.7))
        }
        context.restoreGState()
    }

    public static func drawVisitor(
        _ visitor: PondVisitor,
        in context: CGContext,
        theme: PondTheme = .day
    ) {
        context.saveGState()
        let bob = CGFloat(sin(visitor.bobbingPhase) * 1.6)
        context.translateBy(x: CGFloat(visitor.position.x), y: CGFloat(visitor.position.y))

        switch visitor.type {
        case .swan:
            context.rotate(by: CGFloat(visitor.heading))

            // Waterline gentle wake contact ring
            context.setStrokeColor(red: 0.85, green: 0.95, blue: 0.95, alpha: 0.35)
            context.setLineWidth(1.5)
            context.strokeEllipse(in: CGRect(x: -24, y: -14 + bob * 0.5, width: 48, height: 28))

            // Swan body (smooth white/cream plumage)
            context.setFillColor(red: 0.96, green: 0.97, blue: 0.95, alpha: 1.0)
            context.fillEllipse(in: CGRect(x: -20, y: -11 + bob, width: 38, height: 22))

            // Wing contours & feather shading
            context.setStrokeColor(red: 0.82, green: 0.86, blue: 0.88, alpha: 0.70)
            context.setLineWidth(1.2)
            context.strokeEllipse(in: CGRect(x: -16, y: -9 + bob, width: 30, height: 18))

            // Back tail plumage tip
            let tailPath = CGMutablePath()
            tailPath.move(to: CGPoint(x: -18, y: 0 + bob))
            tailPath.addLine(to: CGPoint(x: -26, y: 2 + bob))
            tailPath.addLine(to: CGPoint(x: -20, y: -4 + bob))
            tailPath.closeSubpath()
            context.setFillColor(red: 0.94, green: 0.95, blue: 0.92, alpha: 1.0)
            context.addPath(tailPath)
            context.fillPath()

            // Neck & head
            context.setFillColor(red: 0.97, green: 0.98, blue: 0.96, alpha: 1.0)
            context.fillEllipse(in: CGRect(x: 10, y: -6 + bob, width: 14, height: 12))

            // Orange beak
            let beakPath = CGMutablePath()
            beakPath.move(to: CGPoint(x: 21, y: 1 + bob))
            beakPath.addLine(to: CGPoint(x: 28, y: 0 + bob))
            beakPath.addLine(to: CGPoint(x: 21, y: -3 + bob))
            beakPath.closeSubpath()
            context.setFillColor(red: 0.98, green: 0.48, blue: 0.12, alpha: 1.0)
            context.addPath(beakPath)
            context.fillPath()

            // Black facial basal mask & eye
            context.setFillColor(red: 0.10, green: 0.10, blue: 0.12, alpha: 0.90)
            context.fillEllipse(in: CGRect(x: 18, y: -1 + bob, width: 3.5, height: 3.5))

        case .ball:
            let r = CGFloat(visitor.radius)

            // Surface water contact halo
            context.setStrokeColor(red: 0.90, green: 0.95, blue: 1.0, alpha: 0.40)
            context.setLineWidth(1.2)
            context.strokeEllipse(in: CGRect(x: -r * 1.25, y: -r * 1.25 + bob * 0.4, width: r * 2.5, height: r * 2.5))

            // Spherical base: rich Japanese vermilion
            context.setFillColor(red: 0.88, green: 0.22, blue: 0.16, alpha: 1.0)
            context.fillEllipse(in: CGRect(x: -r, y: -r + bob, width: r * 2, height: r * 2))

            // Temari decorative geometric bands (arcs)
            context.setStrokeColor(red: 0.96, green: 0.82, blue: 0.25, alpha: 0.95)
            context.setLineWidth(2.2)
            let arc1 = CGMutablePath()
            arc1.addArc(center: CGPoint(x: 0, y: bob), radius: r * 0.85, startAngle: -.pi * 0.7, endAngle: .pi * 0.3, clockwise: false)
            context.addPath(arc1)
            context.strokePath()

            context.setStrokeColor(red: 0.20, green: 0.72, blue: 0.75, alpha: 0.95)
            context.setLineWidth(1.6)
            let arc2 = CGMutablePath()
            arc2.addArc(center: CGPoint(x: 0, y: bob), radius: r * 0.85, startAngle: .pi * 0.2, endAngle: .pi * 1.2, clockwise: false)
            context.addPath(arc2)
            context.strokePath()

            // Center gold star / cross intersection
            context.setFillColor(red: 1.0, green: 0.92, blue: 0.55, alpha: 1.0)
            context.fillEllipse(in: CGRect(x: -2.5, y: -2.5 + bob, width: 5.0, height: 5.0))

            // Top-left specular gloss highlight
            context.setFillColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.75)
            context.fillEllipse(in: CGRect(x: -r * 0.55, y: bob + r * 0.15, width: r * 0.5, height: r * 0.5))
        }

        context.restoreGState()
    }

    // MARK: - Water Surface Ripples

    public static func drawRipples(_ ripples: [WaterRipple], in context: CGContext) {
        guard !ripples.isEmpty else { return }
        context.saveGState()

        for ripple in ripples where !ripple.isDead {
            let center = CGPoint(x: CGFloat(ripple.center.x), y: CGFloat(ripple.center.y))
            let r = CGFloat(ripple.radius)
            let alpha = CGFloat(ripple.alpha)

            switch ripple.type {
            case .waterCall:
                // Primary cyan ring
                context.setStrokeColor(red: 0.35, green: 0.88, blue: 0.85, alpha: alpha * 0.85)
                context.setLineWidth(2.0)
                context.strokeEllipse(in: CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2))

                // Inner secondary ring if large enough
                if r > 16.0 {
                    let rInner = r * 0.65
                    context.setStrokeColor(red: 0.35, green: 0.88, blue: 0.85, alpha: alpha * 0.45)
                    context.setLineWidth(1.2)
                    context.strokeEllipse(in: CGRect(x: center.x - rInner, y: center.y - rInner, width: rInner * 2, height: rInner * 2))
                }

            case .foodDrop:
                // Vibrant orange / amber ring
                context.setStrokeColor(red: 1.0, green: 0.60, blue: 0.18, alpha: alpha * 0.9)
                context.setLineWidth(2.4)
                context.strokeEllipse(in: CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2))

                if r > 12.0 {
                    let rInner = r * 0.55
                    context.setStrokeColor(red: 1.0, green: 0.75, blue: 0.35, alpha: alpha * 0.5)
                    context.setLineWidth(1.2)
                    context.strokeEllipse(in: CGRect(x: center.x - rInner, y: center.y - rInner, width: rInner * 2, height: rInner * 2))
                }

            case .eatingNibble:
                // Soft white nibble ring
                context.setStrokeColor(red: 0.95, green: 0.98, blue: 1.0, alpha: alpha * 0.8)
                context.setLineWidth(1.4)
                context.strokeEllipse(in: CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2))

            case .rainDrop:
                // Delicate silver-cyan rain droplet ripple
                context.setStrokeColor(red: 0.78, green: 0.88, blue: 0.95, alpha: alpha * 0.65)
                context.setLineWidth(1.0)
                context.strokeEllipse(in: CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2))
            }
        }

        context.restoreGState()
    }

    // MARK: - Shoreline artwork (also used by the renderer's cropped cache)

    public static func drawLilyPads(in context: CGContext, bounds: PondBounds, time: Double = 0) {
        let short = CGFloat(min(bounds.width, bounds.height))
        for (index, anchor) in PondFloraArtwork.anchors.enumerated() {
            context.saveGState()
            context.translateBy(x: anchor.x * CGFloat(bounds.width), y: anchor.y * CGFloat(bounds.height))
            context.rotate(by: CGFloat(sin(time * 0.20 + Double(index))) * 0.006)
            PondFloraArtwork.drawCluster(index, in: context, shortSide: short)
            context.restoreGState()
        }
    }
}
