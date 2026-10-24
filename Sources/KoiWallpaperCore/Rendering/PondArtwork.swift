import CoreGraphics
import Foundation

/// Procedural artwork generator for pond elements: deep water, underwater caustics,
/// lily pads, lotus flowers, food pellets, and surface ripples.
public enum PondArtwork {
    private static let swanArtworkScale: CGFloat = 1.512

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
        if visitor.type == .swan {
            context.scaleBy(x: swanArtworkScale, y: swanArtworkScale)
        }

        let c = shadowStyle.color
        switch visitor.type {
        case .swan:
            // Soft underwater drop shadow sized to the full hull and curved neck.
            context.setFillColor(red: c.0, green: c.1, blue: c.2, alpha: shadowStyle.penumbraAlpha)
            context.fillEllipse(in: CGRect(x: -36, y: -19, width: 70, height: 38))
            context.setFillColor(red: c.0, green: c.1, blue: c.2, alpha: shadowStyle.coreAlpha)
            context.fillEllipse(in: CGRect(x: -31, y: -14, width: 59, height: 28))

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
            context.scaleBy(x: swanArtworkScale, y: swanArtworkScale)
            context.translateBy(x: 0, y: bob)

            // Fine V-shaped surface wake, trailing behind the swan as it glides.
            context.setStrokeColor(red: 0.82, green: 0.96, blue: 0.95, alpha: 0.30)
            context.setLineWidth(1.2)
            let wake = CGMutablePath()
            wake.move(to: CGPoint(x: 14, y: 8))
            wake.addCurve(to: CGPoint(x: -42, y: 20), control1: CGPoint(x: -4, y: 17), control2: CGPoint(x: -25, y: 20))
            wake.move(to: CGPoint(x: 14, y: -8))
            wake.addCurve(to: CGPoint(x: -42, y: -20), control1: CGPoint(x: -4, y: -17), control2: CGPoint(x: -25, y: -20))
            context.addPath(wake)
            context.strokePath()

            // Rounded, tapered hull with a readable tail and fuller breast.
            let hull = CGMutablePath()
            hull.move(to: CGPoint(x: -36, y: 0))
            hull.addCurve(to: CGPoint(x: -21, y: 16), control1: CGPoint(x: -35, y: 12), control2: CGPoint(x: -29, y: 17))
            hull.addCurve(to: CGPoint(x: 8, y: 14), control1: CGPoint(x: -7, y: 23), control2: CGPoint(x: 3, y: 20))
            hull.addCurve(to: CGPoint(x: 18, y: 2), control1: CGPoint(x: 17, y: 12), control2: CGPoint(x: 22, y: 8))
            hull.addCurve(to: CGPoint(x: 10, y: -12), control1: CGPoint(x: 22, y: -5), control2: CGPoint(x: 17, y: -12))
            hull.addCurve(to: CGPoint(x: -14, y: -16), control1: CGPoint(x: 0, y: -20), control2: CGPoint(x: -8, y: -19))
            hull.addCurve(to: CGPoint(x: -36, y: 0), control1: CGPoint(x: -29, y: -15), control2: CGPoint(x: -37, y: -10))
            hull.closeSubpath()
            context.setFillColor(red: 0.97, green: 0.98, blue: 0.96, alpha: 1.0)
            context.addPath(hull)
            context.fillPath()

            // Soft cool outline separates the white plumage from bright jade water.
            context.setStrokeColor(red: 0.66, green: 0.77, blue: 0.76, alpha: 0.60)
            context.setLineWidth(1.0)
            context.addPath(hull)
            context.strokePath()

            // Folded wing and a few restrained feather arcs.
            let wing = CGMutablePath()
            wing.move(to: CGPoint(x: -25, y: 5))
            wing.addCurve(to: CGPoint(x: 4, y: 8), control1: CGPoint(x: -13, y: 17), control2: CGPoint(x: 0, y: 17))
            wing.addCurve(to: CGPoint(x: -8, y: -9), control1: CGPoint(x: 1, y: -5), control2: CGPoint(x: -1, y: -9))
            wing.addCurve(to: CGPoint(x: -25, y: 5), control1: CGPoint(x: -19, y: -12), control2: CGPoint(x: -27, y: -5))
            wing.closeSubpath()
            context.setFillColor(red: 0.90, green: 0.92, blue: 0.91, alpha: 0.92)
            context.addPath(wing)
            context.fillPath()
            context.setStrokeColor(red: 0.78, green: 0.84, blue: 0.84, alpha: 0.58)
            context.setLineWidth(0.9)
            context.addPath(wing)
            context.strokePath()

            context.setStrokeColor(red: 0.78, green: 0.84, blue: 0.84, alpha: 0.48)
            context.setLineWidth(0.8)
            let featherLines = CGMutablePath()
            featherLines.move(to: CGPoint(x: -20, y: 6))
            featherLines.addQuadCurve(to: CGPoint(x: -2, y: 8), control: CGPoint(x: -12, y: 11))
            featherLines.move(to: CGPoint(x: -18, y: 1))
            featherLines.addQuadCurve(to: CGPoint(x: 1, y: 3), control: CGPoint(x: -8, y: 7))
            context.addPath(featherLines)
            context.strokePath()

            // S-curved neck rises from the breast into a small rounded head.
            let neck = CGMutablePath()
            neck.move(to: CGPoint(x: 6, y: 7))
            neck.addCurve(to: CGPoint(x: 14, y: 25), control1: CGPoint(x: 14, y: 9), control2: CGPoint(x: 8, y: 21))
            neck.addCurve(to: CGPoint(x: 25, y: 30), control1: CGPoint(x: 18, y: 33), control2: CGPoint(x: 23, y: 32))
            context.setLineCap(.round)
            context.setLineJoin(.round)
            context.setStrokeColor(red: 0.72, green: 0.81, blue: 0.81, alpha: 0.88)
            context.setLineWidth(12.5)
            context.addPath(neck)
            context.strokePath()
            context.setStrokeColor(red: 0.98, green: 0.99, blue: 0.97, alpha: 1.0)
            context.setLineWidth(9.2)
            context.addPath(neck)
            context.strokePath()

            context.setFillColor(red: 0.97, green: 0.98, blue: 0.96, alpha: 1.0)
            context.fillEllipse(in: CGRect(x: 21, y: 26, width: 12, height: 8))

            // Small black eye mask and warm orange beak.
            context.setFillColor(red: 0.10, green: 0.12, blue: 0.13, alpha: 0.95)
            context.fillEllipse(in: CGRect(x: 29, y: 28, width: 4.6, height: 3.2))
            context.setFillColor(red: 0.04, green: 0.05, blue: 0.06, alpha: 1.0)
            context.fillEllipse(in: CGRect(x: 27.8, y: 31, width: 1.8, height: 1.8))

            let beak = CGMutablePath()
            beak.move(to: CGPoint(x: 32, y: 30))
            beak.addCurve(to: CGPoint(x: 43, y: 29), control1: CGPoint(x: 37, y: 32), control2: CGPoint(x: 41, y: 31))
            beak.addCurve(to: CGPoint(x: 32, y: 26.5), control1: CGPoint(x: 40, y: 26), control2: CGPoint(x: 35, y: 25))
            beak.closeSubpath()
            context.setFillColor(red: 0.98, green: 0.48, blue: 0.12, alpha: 1.0)
            context.addPath(beak)
            context.fillPath()

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

    /// Generates aligned ripple strokes matching realistic water surface splash reflections.
    static func rippleStrokes(for ripple: WaterRipple) -> [PondStroke] {
        guard !ripple.isDead, ripple.alpha > 0.001 else { return [] }

        let center = CGPoint(x: CGFloat(ripple.center.x), y: CGFloat(ripple.center.y))
        let radius = CGFloat(ripple.radius)
        let alpha = CGFloat(ripple.alpha)

        switch ripple.type {
        case .eatingNibble:
            // Delicate koi nibble with soft surface reflection
            let nibblePath = CGMutablePath()
            nibblePath.addEllipse(in: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
            if radius >= 8.0 {
                let rInner = radius * 0.55
                nibblePath.addEllipse(in: CGRect(x: center.x - rInner, y: center.y - rInner, width: rInner * 2, height: rInner * 2))
            }
            return [
                PondStroke(
                    path: nibblePath,
                    color: CGColor(red: 0.94, green: 0.98, blue: 0.90, alpha: alpha * 0.75),
                    width: 1.1
                )
            ]

        case .rainDrop:
            // Realistic atmospheric rain droplet impact & wide surface wave reflection
            let rainPath = CGMutablePath()
            let baseAngle = CGFloat((ripple.center.x * 0.041 + ripple.center.y * 0.067).truncatingRemainder(dividingBy: .pi))
            let t = CGAffineTransform(translationX: center.x, y: center.y).rotated(by: baseAngle)

            // 1. Primary outer capillary droplet ring with slight organic eccentricity
            let rx = radius * 1.025
            let ry = radius * 0.975
            rainPath.addEllipse(in: CGRect(x: -rx, y: -ry, width: rx * 2, height: ry * 2), transform: t)

            // 2. Specular reflection arc on the outer rim (sky glint)
            let arcPath = CGMutablePath()
            arcPath.addArc(center: .zero, radius: radius, startAngle: .pi * 0.22, endAngle: .pi * 0.80, clockwise: false)
            let arcT = CGAffineTransform(scaleX: 1.025, y: 0.975).concatenating(t)
            rainPath.addPath(arcPath, transform: arcT)

            // 3. Fresnel counter-reflection on the opposing rim for wide splashes
            if radius >= 12.0 {
                let fresnelArc = CGMutablePath()
                fresnelArc.addArc(center: .zero, radius: radius, startAngle: .pi * 1.25, endAngle: .pi * 1.75, clockwise: false)
                rainPath.addPath(fresnelArc, transform: arcT)
            }

            // 4. Secondary graduated rebound droplet ring
            if radius >= 8.0 {
                let rInner = radius * 0.62
                let innerRect = CGRect(x: -rInner * 0.98, y: -rInner * 1.02, width: rInner * 1.96, height: rInner * 2.04)
                rainPath.addEllipse(in: innerRect, transform: t)
            }

            // 5. Tertiary wave crest as the ripple expands wide
            if radius >= 18.0 {
                let rCenter = radius * 0.36
                let centerRect = CGRect(x: -rCenter * 1.01, y: -rCenter * 0.99, width: rCenter * 2.02, height: rCenter * 1.98)
                rainPath.addEllipse(in: centerRect, transform: t)
            }

            // 6. Instant impact splash glint when droplet first touches surface
            if radius <= 10.0 {
                let pingR = max(2.0, radius * 0.38)
                rainPath.addEllipse(in: CGRect(x: -pingR, y: -pingR, width: pingR * 2, height: pingR * 2), transform: t)
            }

            return [
                PondStroke(
                    path: rainPath,
                    color: CGColor(red: 0.88, green: 0.94, blue: 0.98, alpha: min(1.0, alpha * 0.85)),
                    width: 1.0
                )
            ]

        case .waterCall, .foodDrop:
            let isWater = (ripple.type == .waterCall)
            // Color palettes
            // Main wave body lines: clear refraction tone
            let waveColor = isWater
                ? CGColor(red: 0.40, green: 0.84, blue: 0.80, alpha: alpha * 0.65)
                : CGColor(red: 0.96, green: 0.62, blue: 0.24, alpha: alpha * 0.70)
            // Specular water reflection ("pantulan air"): luminous sky reflection
            let specularColor = isWater
                ? CGColor(red: 0.94, green: 0.99, blue: 0.98, alpha: min(1.0, alpha * 0.85))
                : CGColor(red: 1.0, green: 0.96, blue: 0.82, alpha: min(1.0, alpha * 0.90))

            let wavePath = CGMutablePath()
            let highlightPath = CGMutablePath()

            // Unique, deterministic orientation angle for this ripple based on its spawn location
            let baseAngle = CGFloat((ripple.center.x * 0.037 + ripple.center.y * 0.053).truncatingRemainder(dividingBy: .pi))

            // Graduated wave crest configurations: (radius fraction, rx scale, ry scale, angle offset, minRadiusToAppear)
            let crestConfigs: [(fraction: CGFloat, scaleX: CGFloat, scaleY: CGFloat, angleOffset: CGFloat, minR: CGFloat)] = [
                (1.00, 1.025, 0.975, 0.18, 0.0),
                (0.68, 0.980, 1.020, -0.26, 8.0),
                (0.44, 1.020, 0.985, 0.52, 10.0),
                (0.25, 0.985, 1.015, -0.42, 10.0)
            ]

            for (fraction, scaleX, scaleY, angleOffset, minR) in crestConfigs {
                let crestR = radius * fraction
                guard crestR >= minR && crestR > 2.0 else { continue }

                let rx = crestR * scaleX
                let ry = crestR * scaleY
                let angle = baseAngle + angleOffset

                let t = CGAffineTransform(translationX: center.x, y: center.y).rotated(by: angle)
                let rect = CGRect(x: -rx, y: -ry, width: rx * 2, height: ry * 2)
                wavePath.addEllipse(in: rect, transform: t)

                // Specular water reflection arcs on wave crests
                if fraction >= 0.60 && crestR >= 5.0 {
                    let arcPath = CGMutablePath()
                    // Primary sky reflection facing ambient pond lighting (upper-left)
                    let startA: CGFloat = (fraction > 0.9) ? (.pi * 0.22) : (.pi * 0.28)
                    let endA: CGFloat = (fraction > 0.9) ? (.pi * 0.82) : (.pi * 0.76)
                    arcPath.addArc(center: .zero, radius: crestR, startAngle: startA, endAngle: endA, clockwise: false)

                    // Secondary Fresnel reflection on the opposing curved rim (bottom-right)
                    if fraction > 0.9 && crestR >= 12.0 {
                        arcPath.addArc(center: .zero, radius: crestR, startAngle: .pi * 1.25, endAngle: .pi * 1.75, clockwise: false)
                    }

                    let highlightTransform = CGAffineTransform(scaleX: scaleX, y: scaleY).concatenating(t)
                    highlightPath.addPath(arcPath, transform: highlightTransform)
                }
            }

            // Central splash impact reflection glint during the initial disturbance phase
            if radius <= 36.0 {
                let splashR = max(2.5, radius * 0.38)
                let splashRect = CGRect(x: -splashR * 0.96, y: -splashR * 1.04, width: splashR * 1.92, height: splashR * 2.08)
                let tCenter = CGAffineTransform(translationX: center.x, y: center.y).rotated(by: baseAngle + 0.35)
                highlightPath.addEllipse(in: splashRect, transform: tCenter)
            }

            var strokes: [PondStroke] = []
            strokes.append(PondStroke(path: wavePath, color: waveColor, width: 1.1))

            if !highlightPath.isEmpty {
                strokes.append(PondStroke(path: highlightPath, color: specularColor, width: 1.2))
            }

            return strokes
        }
    }

    public static func drawRipples(_ ripples: [WaterRipple], in context: CGContext) {
        guard !ripples.isEmpty else { return }
        context.saveGState()
        context.setLineCap(.round)

        for ripple in ripples where !ripple.isDead {
            for stroke in rippleStrokes(for: ripple) {
                context.setStrokeColor(stroke.color)
                context.setLineWidth(stroke.width)
                context.addPath(stroke.path)
                context.strokePath()
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
