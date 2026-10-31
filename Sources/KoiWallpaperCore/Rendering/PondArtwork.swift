import CoreGraphics
import Foundation

/// Procedural artwork generator for pond elements: deep water, underwater caustics,
/// lily pads, lotus flowers, food pellets, and surface ripples.
public enum PondArtwork {
    private static let swanArtworkScale: CGFloat = 1.0

    // MARK: - Visitor Bird Palettes

    // Mandarin Duck Palette (Oshidori)
    private static let mandarinChest = CGColor(red: 0.72, green: 0.36, blue: 0.16, alpha: 1.0)      // Copper chestnut #B85C28
    private static let mandarinCrown = CGColor(red: 0.11, green: 0.33, blue: 0.27, alpha: 1.0)      // Forest jade #1D5546
    private static let mandarinCrest = CGColor(red: 0.28, green: 0.19, blue: 0.35, alpha: 1.0)      // Imperial violet #483058
    private static let mandarinWingTeal = CGColor(red: 0.12, green: 0.45, blue: 0.46, alpha: 1.0)   // Speculum teal #1F7275
    private static let mandarinSailOrange = CGColor(red: 0.88, green: 0.52, blue: 0.18, alpha: 1.0) // Sail feathers #E0842E
    private static let mandarinBill = CGColor(red: 0.82, green: 0.30, blue: 0.22, alpha: 1.0)       // Crimson coral bill #D14D38
    private static let mandarinBillTip = CGColor(red: 0.95, green: 0.55, blue: 0.48, alpha: 1.0)
    private static let mandarinFlank = CGColor(red: 0.88, green: 0.78, blue: 0.62, alpha: 1.0)      // Warm beige flank

    // White Call Duck Palette (Call Duck / Pekin)
    private static let duckWhiteBase = CGColor(red: 0.98, green: 0.98, blue: 0.96, alpha: 1.0)      // Warm ivory #FAFAF5
    private static let duckWhiteShadow = CGColor(red: 0.70, green: 0.82, blue: 0.89, alpha: 0.85)   // Water shadow #B3D1E3
    private static let duckWhiteCrease = CGColor(red: 0.56, green: 0.70, blue: 0.79, alpha: 0.90)   // Wing seam line #8FB3C9
    private static let duckWhiteBill = CGColor(red: 0.98, green: 0.54, blue: 0.08, alpha: 1.0)      // Sunny orange bill #FA8A14
    private static let duckWhiteBillHigh = CGColor(red: 1.0, green: 0.76, blue: 0.35, alpha: 1.0)

    // Shared Anatomy
    private static let paddleOrange = CGColor(red: 0.94, green: 0.46, blue: 0.08, alpha: 0.65)     // Translucent webbed foot
    private static let duckInkEye = CGColor(red: 0.045, green: 0.12, blue: 0.105, alpha: 1.0)      // Japanese sumi ink
    private static let duckEyeCatchlight = CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.92)

    // Regal Zen Swan Palette
    private static let swanPure = CGColor(red: 0.98, green: 0.99, blue: 0.98, alpha: 1.0)           // Ethereal white #FAFCFA
    private static let swanFeatherShadow = CGColor(red: 0.68, green: 0.78, blue: 0.82, alpha: 0.60) // Feather curvature
    private static let swanFeatherCrease = CGColor(red: 0.52, green: 0.64, blue: 0.68, alpha: 0.55) // Sculpted wing fold
    private static let swanVividBill = CGColor(red: 0.95, green: 0.45, blue: 0.12, alpha: 1.0)       // Vivid swan orange #F2731F
    private static let swanBasalKnob = CGColor(red: 0.08, green: 0.10, blue: 0.12, alpha: 1.0)       // Basal black knob

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

    /// Renders the atmospheric weather pass (directional sun/moonlight beam, cloud shadow wave, and corner vignette)
    /// conforming directly to Nagomi Desktop `10-weather-pass.wgsl`.
    public static func drawWeatherAtmosphere(
        in context: CGContext,
        rect: CGRect,
        grade: PondWeatherGrade,
        time: Double
    ) {
        guard rect.width > 0, rect.height > 0 else { return }
        guard grade.cloudStrength > 0.02 || grade.lightStrength > 0.02 || grade.vignette > 0.02 else { return }
        let space = CGColorSpaceCreateDeviceRGB()
        let w = rect.width
        let h = rect.height

        context.saveGState()

        // 1. Cloud Shadow Wave Modulation (from 10-weather-pass.wgsl)
        if grade.cloudStrength > 0.005 {
            let cloudAlpha = grade.cloudStrength * CGFloat(0.08 + 0.05 * sin(time * 0.035))
            let cloudShiftX = CGFloat(fmod(time * 0.005, 1.0)) * w
            let cloudShiftY = CGFloat(fmod(time * 0.004, 1.0)) * h
            context.saveGState()
            context.setBlendMode(.normal)
            let cloudGradientColors = [
                CGColor(red: 0.12, green: 0.18, blue: 0.22, alpha: cloudAlpha * 0.8),
                CGColor(red: 0.20, green: 0.25, blue: 0.28, alpha: cloudAlpha * 0.3),
                CGColor(red: 0.12, green: 0.18, blue: 0.22, alpha: cloudAlpha * 0.8)
            ]
            if let cloudGrad = CGGradient(colorsSpace: space, colors: cloudGradientColors as CFArray, locations: [0.0, 0.5, 1.0]) {
                context.drawLinearGradient(
                    cloudGrad,
                    start: CGPoint(x: cloudShiftX - w * 0.5, y: cloudShiftY - h * 0.5),
                    end: CGPoint(x: cloudShiftX + w * 0.5, y: cloudShiftY + h * 0.5),
                    options: [.drawsBeforeStartLocation, .drawsAfterEndLocation]
                )
            }
            context.restoreGState()
        }

        // 2. Directional Sunlight / Moonlight Beam (from 10-weather-pass.wgsl)
        if grade.lightStrength > 0.01 {
            context.saveGState()
            context.setBlendMode(.screen)
            let dirX = CGFloat(grade.lightDirection.0)
            let dirY = CGFloat(grade.lightDirection.1)
            let dirLen = max(0.001, hypot(dirX, dirY))
            let normDirX = dirX / dirLen
            let normDirY = dirY / dirLen

            let beamAlpha = grade.lightStrength * 0.35
            let lightColors = [
                CGColor(red: grade.lightColor.0, green: grade.lightColor.1, blue: grade.lightColor.2, alpha: 0.0),
                CGColor(red: grade.lightColor.0, green: grade.lightColor.1, blue: grade.lightColor.2, alpha: beamAlpha * 0.5),
                CGColor(red: grade.lightColor.0, green: grade.lightColor.1, blue: grade.lightColor.2, alpha: beamAlpha)
            ]
            let startP = CGPoint(x: rect.midX - normDirX * w * 0.55, y: rect.midY - normDirY * h * 0.55)
            let endP = CGPoint(x: rect.midX + normDirX * w * 0.55, y: rect.midY + normDirY * h * 0.55)
            if let grad = CGGradient(colorsSpace: space, colors: lightColors as CFArray, locations: [0.0, 0.45, 1.0]) {
                context.drawLinearGradient(grad, start: startP, end: endP, options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
            }
            context.restoreGState()
        }

        // 3. Atmospheric Edge Vignette (from 10-weather-pass.wgsl)
        if grade.vignette > 0.01 {
            context.saveGState()
            context.setBlendMode(.normal)
            let vigAlpha = grade.vignette * 0.45
            let vigColors = [
                CGColor(red: 0.02, green: 0.04, blue: 0.06, alpha: 0.0),
                CGColor(red: 0.02, green: 0.04, blue: 0.06, alpha: vigAlpha * 0.35),
                CGColor(red: 0.02, green: 0.04, blue: 0.06, alpha: vigAlpha)
            ]
            let center = CGPoint(x: rect.midX, y: rect.midY)
            let maxR = max(w, h) * 0.72
            if let vigGrad = CGGradient(colorsSpace: space, colors: vigColors as CFArray, locations: [0.0, 0.65, 1.0]) {
                context.drawRadialGradient(vigGrad, startCenter: center, startRadius: maxR * 0.35, endCenter: center, endRadius: maxR, options: [.drawsAfterEndLocation])
            }
            context.restoreGState()
        }

        context.restoreGState()
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
            let len: CGFloat = 84.0
            let hw: CGFloat = 28.0
            context.setFillColor(red: c.0, green: c.1, blue: c.2, alpha: shadowStyle.penumbraAlpha)
            context.fillEllipse(in: CGRect(x: -len * 0.48, y: -hw * 1.15, width: len * 0.96, height: hw * 2.30))
            context.setFillColor(red: c.0, green: c.1, blue: c.2, alpha: shadowStyle.coreAlpha)
            context.fillEllipse(in: CGRect(x: -len * 0.40, y: -hw * 0.85, width: len * 0.80, height: hw * 1.70))

        case .duck:
            if visitor.isDabbling {
                let len: CGFloat = 68.0
                let hw: CGFloat = 38.0
                context.setFillColor(red: c.0, green: c.1, blue: c.2, alpha: shadowStyle.penumbraAlpha)
                context.fillEllipse(in: CGRect(x: -len * 0.50, y: -hw * 1.10, width: len, height: hw * 2.20))
                context.setFillColor(red: c.0, green: c.1, blue: c.2, alpha: shadowStyle.coreAlpha)
                context.fillEllipse(in: CGRect(x: -len * 0.38, y: -hw * 0.85, width: len * 0.76, height: hw * 1.70))
            } else {
                let len: CGFloat = 92.0
                let hw: CGFloat = 35.0
                context.setFillColor(red: c.0, green: c.1, blue: c.2, alpha: shadowStyle.penumbraAlpha)
                context.fillEllipse(in: CGRect(x: -len * 0.48, y: -hw * 1.15, width: len * 0.96, height: hw * 2.30))
                context.setFillColor(red: c.0, green: c.1, blue: c.2, alpha: shadowStyle.coreAlpha)
                context.fillEllipse(in: CGRect(x: -len * 0.40, y: -hw * 0.85, width: len * 0.80, height: hw * 1.70))
            }

        case .ball:
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
            drawRegalZenSwan(visitor, in: context, bob: bob)

        case .duck:
            context.rotate(by: CGFloat(visitor.heading))
            if visitor.isDabbling {
                drawDabblingDuck(visitor, in: context, bob: bob)
            } else {
                drawNagomiDuck(visitor, in: context, bob: bob)
            }

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

    // MARK: - Bird Artwork Details (Nagomi Duck & Regal Swan)

    private static func drawPaddleFeet(
        in context: CGContext,
        length: CGFloat,
        paddlePhase: Double,
        color: CGColor
    ) {
        let strokeL = sin(paddlePhase)
        let strokeR = sin(paddlePhase + Double.pi)

        context.saveGState()
        context.setFillColor(color)

        // Left Foot
        context.saveGState()
        let leftX = -length * 0.26 - CGFloat(strokeL * 3.5)
        let leftY = length * 0.28 + CGFloat(strokeL * 2.2)
        context.translateBy(x: leftX, y: leftY)
        context.rotate(by: CGFloat(0.35 + strokeL * 0.30))

        let fl = CGMutablePath()
        fl.move(to: CGPoint(x: length * 0.05, y: 0))
        fl.addLine(to: CGPoint(x: -length * 0.16, y: length * 0.12))
        fl.addQuadCurve(to: CGPoint(x: -length * 0.20, y: 0), control: CGPoint(x: -length * 0.19, y: length * 0.06))
        fl.addQuadCurve(to: CGPoint(x: -length * 0.16, y: -length * 0.08), control: CGPoint(x: -length * 0.20, y: -length * 0.04))
        fl.closeSubpath()
        context.addPath(fl)
        context.fillPath()
        context.restoreGState()

        // Right Foot
        context.saveGState()
        let rightX = -length * 0.26 - CGFloat(strokeR * 3.5)
        let rightY = -length * 0.28 - CGFloat(strokeR * 2.2)
        context.translateBy(x: rightX, y: rightY)
        context.rotate(by: CGFloat(-0.35 - strokeR * 0.30))

        let fr = CGMutablePath()
        fr.move(to: CGPoint(x: length * 0.05, y: 0))
        fr.addLine(to: CGPoint(x: -length * 0.16, y: -length * 0.12))
        fr.addQuadCurve(to: CGPoint(x: -length * 0.20, y: 0), control: CGPoint(x: -length * 0.19, y: -length * 0.06))
        fr.addQuadCurve(to: CGPoint(x: -length * 0.16, y: length * 0.08), control: CGPoint(x: -length * 0.20, y: length * 0.04))
        fr.closeSubpath()
        context.addPath(fr)
        context.fillPath()
        context.restoreGState()

        context.restoreGState()
    }

    private static func drawWaterWake(
        in context: CGContext,
        length: CGFloat,
        intensity: CGFloat = 1.0
    ) {
        context.saveGState()

        // Primary V-Bow wave
        context.setStrokeColor(red: 0.82, green: 0.96, blue: 0.98, alpha: 0.55 * intensity)
        context.setLineWidth(1.6)

        let bow = CGMutablePath()
        bow.move(to: CGPoint(x: length * 0.32, y: length * 0.14))
        bow.addCurve(to: CGPoint(x: -length * 0.80, y: length * 0.60),
                     control1: CGPoint(x: -length * 0.10, y: length * 0.30),
                     control2: CGPoint(x: -length * 0.45, y: length * 0.50))

        bow.move(to: CGPoint(x: length * 0.32, y: -length * 0.14))
        bow.addCurve(to: CGPoint(x: -length * 0.80, y: -length * 0.60),
                     control1: CGPoint(x: -length * 0.10, y: -length * 0.30),
                     control2: CGPoint(x: -length * 0.45, y: -length * 0.50))
        context.addPath(bow)
        context.strokePath()

        // Secondary soft trailing arc
        context.setStrokeColor(red: 0.88, green: 0.98, blue: 1.0, alpha: 0.30 * intensity)
        context.setLineWidth(1.2)
        let wake2 = CGMutablePath()
        wake2.move(to: CGPoint(x: 0, y: length * 0.22))
        wake2.addCurve(to: CGPoint(x: -length * 0.95, y: length * 0.75),
                      control1: CGPoint(x: -length * 0.30, y: length * 0.42),
                      control2: CGPoint(x: -length * 0.65, y: length * 0.65))
        wake2.move(to: CGPoint(x: 0, y: -length * 0.22))
        wake2.addCurve(to: CGPoint(x: -length * 0.95, y: -length * 0.75),
                      control1: CGPoint(x: -length * 0.30, y: -length * 0.42),
                      control2: CGPoint(x: -length * 0.65, y: -length * 0.65))
        context.addPath(wake2)
        context.strokePath()

        // Trailing stern circular eddy
        context.setStrokeColor(red: 0.86, green: 0.98, blue: 1.0, alpha: 0.28 * intensity)
        context.strokeEllipse(in: CGRect(x: -length * 0.65, y: -length * 0.20, width: length * 0.38, height: length * 0.40))

        context.restoreGState()
    }

    private static func drawRegalZenSwan(
        _ visitor: PondVisitor,
        in context: CGContext,
        bob: CGFloat
    ) {
        let length: CGFloat = 84.0
        let halfWidth: CGFloat = 28.0

        // Surface Wake
        drawWaterWake(in: context, length: length * 1.15, intensity: 1.1)

        context.saveGState()
        context.translateBy(x: 0, y: bob)

        // Underwater paddle feet
        drawPaddleFeet(in: context, length: length * 0.9, paddlePhase: visitor.paddlePhase, color: CGColor(red: 0.25, green: 0.28, blue: 0.30, alpha: 0.50))

        // Regal White Hull with sweeping plumage contours
        let hull = CGMutablePath()
        hull.move(to: CGPoint(x: length * 0.32, y: 0))
        hull.addCurve(to: CGPoint(x: -length * 0.05, y: halfWidth * 1.05),
                      control1: CGPoint(x: length * 0.30, y: halfWidth * 0.75),
                      control2: CGPoint(x: length * 0.15, y: halfWidth * 1.05))
        hull.addCurve(to: CGPoint(x: -length * 0.52, y: halfWidth * 0.28),
                      control1: CGPoint(x: -length * 0.30, y: halfWidth * 0.95),
                      control2: CGPoint(x: -length * 0.44, y: halfWidth * 0.65))
        hull.addCurve(to: CGPoint(x: -length * 0.62, y: 0),
                      control1: CGPoint(x: -length * 0.58, y: halfWidth * 0.12),
                      control2: CGPoint(x: -length * 0.60, y: 0))
        hull.addCurve(to: CGPoint(x: -length * 0.52, y: -halfWidth * 0.28),
                      control1: CGPoint(x: -length * 0.60, y: 0),
                      control2: CGPoint(x: -length * 0.58, y: -halfWidth * 0.12))
        hull.addCurve(to: CGPoint(x: -length * 0.05, y: -halfWidth * 1.05),
                      control1: CGPoint(x: -length * 0.44, y: -halfWidth * 0.65),
                      control2: CGPoint(x: -length * 0.30, y: -halfWidth * 0.95))
        hull.addCurve(to: CGPoint(x: length * 0.32, y: 0),
                      control1: CGPoint(x: length * 0.15, y: -halfWidth * 1.05),
                      control2: CGPoint(x: length * 0.30, y: -halfWidth * 0.75))
        hull.closeSubpath()

        context.setFillColor(swanPure)
        context.addPath(hull)
        context.fillPath()

        // Soft feathered contour line (Ukiyo-e sumi-e feather lines)
        context.setStrokeColor(swanFeatherShadow)
        context.setLineWidth(1.4)
        context.addPath(hull)
        context.strokePath()

        // Layered Sculpted Wings
        for side: CGFloat in [-1.0, 1.0] {
            let wingFold = CGMutablePath()
            wingFold.move(to: CGPoint(x: length * 0.12, y: side * halfWidth * 0.78))
            wingFold.addCurve(to: CGPoint(x: -length * 0.44, y: side * halfWidth * 0.20),
                              control1: CGPoint(x: -length * 0.12, y: side * halfWidth * 0.95),
                              control2: CGPoint(x: -length * 0.32, y: side * halfWidth * 0.55))
            context.setStrokeColor(swanFeatherCrease)
            context.setLineWidth(1.3)
            context.addPath(wingFold)
            context.strokePath()

            let innerArc = CGMutablePath()
            innerArc.move(to: CGPoint(x: length * 0.02, y: side * halfWidth * 0.52))
            innerArc.addCurve(to: CGPoint(x: -length * 0.32, y: side * halfWidth * 0.14),
                              control1: CGPoint(x: -length * 0.12, y: side * halfWidth * 0.60),
                              control2: CGPoint(x: -length * 0.24, y: side * halfWidth * 0.35))
            context.addPath(innerArc)
            context.strokePath()
        }

        // Long Arching S-Curved Neck and Head with gentle nod
        let neckStartX = length * 0.28
        let neckNodOffset = CGFloat(sin(visitor.neckNodPhase)) * 2.2
        let headX = neckStartX + length * 0.22 + neckNodOffset
        let headY: CGFloat = 0.0
        let headRadius: CGFloat = length * 0.095

        let neck = CGMutablePath()
        neck.move(to: CGPoint(x: neckStartX, y: length * 0.07))
        neck.addCurve(to: CGPoint(x: headX, y: 0),
                      control1: CGPoint(x: neckStartX + length * 0.12, y: length * 0.05),
                      control2: CGPoint(x: headX - length * 0.05, y: 0))
        neck.addCurve(to: CGPoint(x: neckStartX, y: -length * 0.07),
                      control1: CGPoint(x: headX - length * 0.05, y: 0),
                      control2: CGPoint(x: neckStartX + length * 0.12, y: -length * 0.05))
        neck.closeSubpath()

        context.setFillColor(swanPure)
        context.addPath(neck)
        context.fillPath()
        context.setStrokeColor(swanFeatherShadow)
        context.setLineWidth(1.0)
        context.addPath(neck)
        context.strokePath()

        // Swan Head
        context.setFillColor(swanPure)
        context.fillEllipse(in: CGRect(x: headX - headRadius * 0.6, y: headY - headRadius, width: headRadius * 1.5, height: headRadius * 2))

        // Basal Black Knob
        context.setFillColor(swanBasalKnob)
        context.fillEllipse(in: CGRect(x: headX + headRadius * 0.3, y: -headRadius * 0.45, width: headRadius * 0.6, height: headRadius * 0.90))

        // Vivid Swan Orange Bill
        let bill = CGMutablePath()
        let bLen = length * 0.16
        let bWid = length * 0.07
        bill.move(to: CGPoint(x: headX + headRadius * 0.6, y: bWid * 0.6))
        bill.addCurve(to: CGPoint(x: headX + headRadius * 0.6 + bLen, y: 0),
                      control1: CGPoint(x: headX + headRadius * 0.6 + bLen * 0.6, y: bWid * 0.7),
                      control2: CGPoint(x: headX + headRadius * 0.6 + bLen * 0.9, y: bWid * 0.2))
        bill.addCurve(to: CGPoint(x: headX + headRadius * 0.6, y: -bWid * 0.6),
                      control1: CGPoint(x: headX + headRadius * 0.6 + bLen * 0.9, y: -bWid * 0.2),
                      control2: CGPoint(x: headX + headRadius * 0.6 + bLen * 0.6, y: -bWid * 0.7))
        bill.closeSubpath()

        context.setFillColor(swanVividBill)
        context.addPath(bill)
        context.fillPath()

        // Swan Eye with Catchlight Glint
        let sEyeX = headX + headRadius * 0.15
        let sEyeY = headRadius * 0.45
        let sEyeRad: CGFloat = 2.0
        context.setFillColor(duckInkEye)
        context.fillEllipse(in: CGRect(x: sEyeX - sEyeRad, y: sEyeY - sEyeRad, width: sEyeRad * 2, height: sEyeRad * 2))
        context.fillEllipse(in: CGRect(x: sEyeX - sEyeRad, y: -sEyeY - sEyeRad, width: sEyeRad * 2, height: sEyeRad * 2))

        context.setFillColor(duckEyeCatchlight)
        context.fillEllipse(in: CGRect(x: sEyeX - 0.5, y: sEyeY - 0.5, width: 1.0, height: 1.0))
        context.fillEllipse(in: CGRect(x: sEyeX - 0.5, y: -sEyeY - 0.5, width: 1.0, height: 1.0))

        context.restoreGState()
    }

    private static func drawNagomiDuck(
        _ visitor: PondVisitor,
        in context: CGContext,
        bob: CGFloat
    ) {
        let length: CGFloat = 92.0
        let halfWidth: CGFloat = 35.0

        // Surface Wake
        drawWaterWake(in: context, length: length)

        context.saveGState()
        context.translateBy(x: 0, y: bob)

        // Underwater Paddling Feet
        drawPaddleFeet(in: context, length: length, paddlePhase: visitor.paddlePhase, color: paddleOrange)

        // Main Body Silhouette (Hull with soft sculpted curves)
        let body = CGMutablePath()
        body.move(to: CGPoint(x: length * 0.36, y: 0))
        body.addCurve(to: CGPoint(x: 0, y: halfWidth),
                      control1: CGPoint(x: length * 0.34, y: halfWidth * 0.70),
                      control2: CGPoint(x: length * 0.18, y: halfWidth))
        body.addCurve(to: CGPoint(x: -length * 0.42, y: halfWidth * 0.35),
                      control1: CGPoint(x: -length * 0.22, y: halfWidth),
                      control2: CGPoint(x: -length * 0.36, y: halfWidth * 0.70))
        body.addCurve(to: CGPoint(x: -length * 0.54, y: 0),
                      control1: CGPoint(x: -length * 0.48, y: halfWidth * 0.15),
                      control2: CGPoint(x: -length * 0.52, y: 0))
        body.addCurve(to: CGPoint(x: -length * 0.42, y: -halfWidth * 0.35),
                      control1: CGPoint(x: -length * 0.52, y: 0),
                      control2: CGPoint(x: -length * 0.48, y: -halfWidth * 0.15))
        body.addCurve(to: CGPoint(x: 0, y: -halfWidth),
                      control1: CGPoint(x: -length * 0.36, y: -halfWidth * 0.70),
                      control2: CGPoint(x: -length * 0.22, y: -halfWidth))
        body.addCurve(to: CGPoint(x: length * 0.36, y: 0),
                      control1: CGPoint(x: length * 0.18, y: -halfWidth),
                      control2: CGPoint(x: length * 0.34, y: -halfWidth * 0.70))
        body.closeSubpath()

        // Render Body Base according to variant
        switch visitor.duckVariant {
        case .mandarin:
            context.setFillColor(mandarinFlank)
            context.addPath(body)
            context.fillPath()

            // Breast copper/chestnut mantle
            let breast = CGMutablePath()
            breast.move(to: CGPoint(x: length * 0.36, y: 0))
            breast.addCurve(to: CGPoint(x: length * 0.12, y: halfWidth * 0.85),
                            control1: CGPoint(x: length * 0.32, y: halfWidth * 0.55),
                            control2: CGPoint(x: length * 0.22, y: halfWidth * 0.85))
            breast.addCurve(to: CGPoint(x: length * 0.12, y: -halfWidth * 0.85),
                            control1: CGPoint(x: length * 0.05, y: 0),
                            control2: CGPoint(x: length * 0.05, y: 0))
            breast.addCurve(to: CGPoint(x: length * 0.36, y: 0),
                            control1: CGPoint(x: length * 0.22, y: -halfWidth * 0.85),
                            control2: CGPoint(x: length * 0.32, y: -halfWidth * 0.55))
            breast.closeSubpath()
            context.setFillColor(mandarinChest)
            context.addPath(breast)
            context.fillPath()

            // Left folded wing with iridescent teal speculum & vertical orange sail fan
            let leftWing = CGMutablePath()
            leftWing.move(to: CGPoint(x: length * 0.15, y: halfWidth * 0.75))
            leftWing.addCurve(to: CGPoint(x: -length * 0.36, y: halfWidth * 0.32),
                              control1: CGPoint(x: -length * 0.05, y: halfWidth * 0.95),
                              control2: CGPoint(x: -length * 0.28, y: halfWidth * 0.65))
            leftWing.addCurve(to: CGPoint(x: -length * 0.12, y: halfWidth * 0.18),
                              control1: CGPoint(x: -length * 0.26, y: halfWidth * 0.25),
                              control2: CGPoint(x: -length * 0.18, y: halfWidth * 0.20))
            leftWing.closeSubpath()
            context.setFillColor(mandarinWingTeal)
            context.addPath(leftWing)
            context.fillPath()

            let leftSail = CGMutablePath()
            leftSail.move(to: CGPoint(x: -length * 0.10, y: halfWidth * 0.50))
            leftSail.addCurve(to: CGPoint(x: -length * 0.34, y: halfWidth * 0.22),
                              control1: CGPoint(x: -length * 0.25, y: halfWidth * 0.60),
                              control2: CGPoint(x: -length * 0.32, y: halfWidth * 0.40))
            leftSail.closeSubpath()
            context.setFillColor(mandarinSailOrange)
            context.addPath(leftSail)
            context.fillPath()

            // Right folded wing
            let rightWing = CGMutablePath()
            rightWing.move(to: CGPoint(x: length * 0.15, y: -halfWidth * 0.75))
            rightWing.addCurve(to: CGPoint(x: -length * 0.36, y: -halfWidth * 0.32),
                               control1: CGPoint(x: -length * 0.05, y: -halfWidth * 0.95),
                               control2: CGPoint(x: -length * 0.28, y: -halfWidth * 0.65))
            rightWing.addCurve(to: CGPoint(x: -length * 0.12, y: -halfWidth * 0.18),
                               control1: CGPoint(x: -length * 0.26, y: -halfWidth * 0.25),
                               control2: CGPoint(x: -length * 0.18, y: -halfWidth * 0.20))
            rightWing.closeSubpath()
            context.setFillColor(mandarinWingTeal)
            context.addPath(rightWing)
            context.fillPath()

            let rightSail = CGMutablePath()
            rightSail.move(to: CGPoint(x: -length * 0.10, y: -halfWidth * 0.50))
            rightSail.addCurve(to: CGPoint(x: -length * 0.34, y: -halfWidth * 0.22),
                               control1: CGPoint(x: -length * 0.25, y: -halfWidth * 0.60),
                               control2: CGPoint(x: -length * 0.32, y: -halfWidth * 0.40))
            rightSail.closeSubpath()
            context.setFillColor(mandarinSailOrange)
            context.addPath(rightSail)
            context.fillPath()

            // Dorsal tail fan
            let tail = CGMutablePath()
            tail.move(to: CGPoint(x: -length * 0.30, y: halfWidth * 0.20))
            tail.addLine(to: CGPoint(x: -length * 0.55, y: 0))
            tail.addLine(to: CGPoint(x: -length * 0.30, y: -halfWidth * 0.20))
            tail.closeSubpath()
            context.setFillColor(mandarinCrown)
            context.addPath(tail)
            context.fillPath()

        case .whitePekin:
            context.setFillColor(duckWhiteBase)
            context.addPath(body)
            context.fillPath()

            context.setStrokeColor(duckWhiteShadow)
            context.setLineWidth(1.6)
            context.addPath(body)
            context.strokePath()

            let wingL = CGMutablePath()
            wingL.move(to: CGPoint(x: length * 0.12, y: halfWidth * 0.70))
            wingL.addCurve(to: CGPoint(x: -length * 0.38, y: halfWidth * 0.25),
                           control1: CGPoint(x: -length * 0.10, y: halfWidth * 0.88),
                           control2: CGPoint(x: -length * 0.28, y: halfWidth * 0.55))
            context.setStrokeColor(duckWhiteCrease)
            context.setLineWidth(1.4)
            context.addPath(wingL)
            context.strokePath()

            let wingR = CGMutablePath()
            wingR.move(to: CGPoint(x: length * 0.12, y: -halfWidth * 0.70))
            wingR.addCurve(to: CGPoint(x: -length * 0.38, y: -halfWidth * 0.25),
                           control1: CGPoint(x: -length * 0.10, y: -halfWidth * 0.88),
                           control2: CGPoint(x: -length * 0.28, y: -halfWidth * 0.55))
            context.addPath(wingR)
            context.strokePath()

            let tailTuft = CGMutablePath()
            tailTuft.move(to: CGPoint(x: -length * 0.35, y: halfWidth * 0.15))
            tailTuft.addLine(to: CGPoint(x: -length * 0.52, y: 0))
            tailTuft.addLine(to: CGPoint(x: -length * 0.35, y: -halfWidth * 0.15))
            context.addPath(tailTuft)
            context.strokePath()
        }

        // Head and Neck
        let headCenter = CGPoint(x: length * 0.26, y: 0)
        let headRadX = length * 0.18
        let headRadY = length * 0.16

        switch visitor.duckVariant {
        case .mandarin:
            context.setFillColor(mandarinCrown)
            context.fillEllipse(in: CGRect(x: headCenter.x - headRadX * 0.5, y: -headRadY, width: headRadX * 1.5, height: headRadY * 2))

            let crest = CGMutablePath()
            crest.move(to: CGPoint(x: headCenter.x + headRadX * 0.2, y: 0))
            crest.addCurve(to: CGPoint(x: length * 0.04, y: headRadY * 0.75),
                           control1: CGPoint(x: headCenter.x, y: headRadY * 0.6),
                           control2: CGPoint(x: length * 0.12, y: headRadY * 0.85))
            crest.addCurve(to: CGPoint(x: length * 0.04, y: -headRadY * 0.75),
                           control1: CGPoint(x: length * -0.02, y: 0),
                           control2: CGPoint(x: length * -0.02, y: 0))
            crest.addCurve(to: CGPoint(x: headCenter.x + headRadX * 0.2, y: 0),
                           control1: CGPoint(x: length * 0.12, y: -headRadY * 0.85),
                           control2: CGPoint(x: headCenter.x, y: -headRadY * 0.6))
            crest.closeSubpath()
            context.setFillColor(mandarinCrest)
            context.addPath(crest)
            context.fillPath()

        case .whitePekin:
            context.setFillColor(duckWhiteBase)
            context.fillEllipse(in: CGRect(x: headCenter.x - headRadX * 0.5, y: -headRadY, width: headRadX * 1.5, height: headRadY * 2))
            context.setStrokeColor(duckWhiteShadow)
            context.setLineWidth(1.2)
            context.strokeEllipse(in: CGRect(x: headCenter.x - headRadX * 0.5, y: -headRadY, width: headRadX * 1.5, height: headRadY * 2))
        }

        // Broad Spoon Duck Bill
        let bill = CGMutablePath()
        let billStartX = headCenter.x + headRadX * 0.65
        let billLen = length * 0.25
        let billWid = length * 0.13

        bill.move(to: CGPoint(x: billStartX, y: billWid * 0.55))
        bill.addCurve(to: CGPoint(x: billStartX + billLen, y: 0),
                      control1: CGPoint(x: billStartX + billLen * 0.75, y: billWid * 0.65),
                      control2: CGPoint(x: billStartX + billLen * 0.95, y: billWid * 0.35))
        bill.addCurve(to: CGPoint(x: billStartX, y: -billWid * 0.55),
                      control1: CGPoint(x: billStartX + billLen * 0.95, y: -billWid * 0.35),
                      control2: CGPoint(x: billStartX + billLen * 0.75, y: -billWid * 0.65))
        bill.closeSubpath()

        let billColor = (visitor.duckVariant == .mandarin) ? mandarinBill : duckWhiteBill
        context.setFillColor(billColor)
        context.addPath(bill)
        context.fillPath()

        let billTipColor = (visitor.duckVariant == .mandarin) ? mandarinBillTip : duckWhiteBillHigh
        context.setStrokeColor(billTipColor)
        context.setLineWidth(1.2)
        let billLine = CGMutablePath()
        billLine.move(to: CGPoint(x: billStartX + 2, y: 0))
        billLine.addLine(to: CGPoint(x: billStartX + billLen - 2, y: 0))
        context.addPath(billLine)
        context.strokePath()

        // Expressive Sumi-Ink Eyes with Catchlight Glint
        let eyeX = headCenter.x + headRadX * 0.25
        let eyeY = headRadY * 0.65
        let eyeRad: CGFloat = 3.6

        context.setFillColor(duckInkEye)
        context.fillEllipse(in: CGRect(x: eyeX - eyeRad, y: eyeY - eyeRad, width: eyeRad * 2, height: eyeRad * 2))
        context.fillEllipse(in: CGRect(x: eyeX - eyeRad, y: -eyeY - eyeRad, width: eyeRad * 2, height: eyeRad * 2))

        context.setFillColor(duckEyeCatchlight)
        let glintRad: CGFloat = 1.3
        context.fillEllipse(in: CGRect(x: eyeX - glintRad + 1.0, y: eyeY - glintRad + 1.0, width: glintRad * 2, height: glintRad * 2))
        context.fillEllipse(in: CGRect(x: eyeX - glintRad + 1.0, y: -eyeY - glintRad + 1.0, width: glintRad * 2, height: glintRad * 2))

        context.restoreGState()
    }

    private static func drawDabblingDuck(
        _ visitor: PondVisitor,
        in context: CGContext,
        bob: CGFloat
    ) {
        let length: CGFloat = 92.0
        let halfWidth: CGFloat = 35.0

        // Concentric Splash & Ripple Rings
        context.saveGState()
        context.setStrokeColor(red: 0.82, green: 0.96, blue: 1.0, alpha: 0.70)
        context.setLineWidth(2.0)
        context.strokeEllipse(in: CGRect(x: length * 0.05, y: -halfWidth * 0.9, width: halfWidth * 1.8, height: halfWidth * 1.8))

        context.setStrokeColor(red: 0.88, green: 0.98, blue: 1.0, alpha: 0.40)
        context.setLineWidth(1.4)
        context.strokeEllipse(in: CGRect(x: -length * 0.10, y: -halfWidth * 1.3, width: halfWidth * 2.6, height: halfWidth * 2.6))

        // Subsurface micro bubbles
        context.setFillColor(red: 0.90, green: 0.98, blue: 1.0, alpha: 0.75)
        for (bx, by, br) in [(length * 0.25, 4.0, 1.8), (length * 0.32, -6.0, 2.2), (length * 0.18, -8.0, 1.4)] {
            context.fillEllipse(in: CGRect(x: bx - br, y: by - br, width: br * 2, height: br * 2))
        }

        // Paddling webbed feet splashing
        context.setFillColor(paddleOrange)
        for side: CGFloat in [-1.0, 1.0] {
            context.saveGState()
            context.translateBy(x: -length * 0.10, y: side * halfWidth * 0.75)
            context.rotate(by: side * 0.55)
            let f = CGMutablePath()
            f.move(to: .zero)
            f.addLine(to: CGPoint(x: -length * 0.22, y: side * length * 0.14))
            f.addLine(to: CGPoint(x: -length * 0.25, y: 0))
            f.addLine(to: CGPoint(x: -length * 0.22, y: -side * length * 0.08))
            f.closeSubpath()
            context.addPath(f)
            context.fillPath()
            context.restoreGState()
        }

        // Upturned duck rump & pointed tail feathers ("Duck Butt" Dabble)
        let rump = CGMutablePath()
        rump.move(to: CGPoint(x: length * 0.10, y: halfWidth * 0.65))
        rump.addCurve(to: CGPoint(x: -length * 0.42, y: 0),
                      control1: CGPoint(x: -length * 0.15, y: halfWidth * 0.85),
                      control2: CGPoint(x: -length * 0.38, y: halfWidth * 0.45))
        rump.addCurve(to: CGPoint(x: length * 0.10, y: -halfWidth * 0.65),
                      control1: CGPoint(x: -length * 0.38, y: -halfWidth * 0.45),
                      control2: CGPoint(x: -length * 0.15, y: -halfWidth * 0.85))
        rump.addCurve(to: CGPoint(x: length * 0.10, y: halfWidth * 0.65),
                      control1: CGPoint(x: length * 0.18, y: 0),
                      control2: CGPoint(x: length * 0.18, y: 0))
        rump.closeSubpath()

        let baseCol = (visitor.duckVariant == .mandarin) ? mandarinFlank : duckWhiteBase
        context.setFillColor(baseCol)
        context.addPath(rump)
        context.fillPath()

        let tailPoint = CGMutablePath()
        tailPoint.move(to: CGPoint(x: -length * 0.25, y: halfWidth * 0.25))
        tailPoint.addLine(to: CGPoint(x: -length * 0.52, y: 0))
        tailPoint.addLine(to: CGPoint(x: -length * 0.25, y: -halfWidth * 0.25))
        tailPoint.closeSubpath()
        let tailCol = (visitor.duckVariant == .mandarin) ? mandarinCrown : duckWhiteShadow
        context.setFillColor(tailCol)
        context.addPath(tailPoint)
        context.fillPath()

        context.restoreGState()
    }

    // MARK: - Water Surface Ripples

    /// Generates Ukiyo-e wave arc strokes, specular foam crests, and central dimple micro-bubbles.
    static func rippleStrokes(for ripple: WaterRipple, theme: PondTheme = .day) -> [PondStroke] {
        guard !ripple.isDead, ripple.alpha > 0.001 else { return [] }

        let center = CGPoint(x: CGFloat(ripple.center.x), y: CGFloat(ripple.center.y))
        let radius = CGFloat(ripple.radius)
        let alpha = CGFloat(ripple.alpha)

        let themePalette = theme.renderPalette
        let palette = (ripple.type == .foodDrop) ? PondThemePalette.foodRipple : themePalette.ripple
        let lightDir = themePalette.weather.lightDirection
        let lightAngle = atan2(CGFloat(lightDir.1), CGFloat(lightDir.0))

        switch ripple.type {
        case .eatingNibble:
            // Delicate koi nibble with directional Fresnel specular arc (strictly 1 stroke)
            let nibblePath = CGMutablePath()
            nibblePath.addEllipse(in: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
            if radius >= 8.0 {
                let rInner = radius * 0.55
                nibblePath.addEllipse(in: CGRect(x: center.x - rInner, y: center.y - rInner, width: rInner * 2, height: rInner * 2))
            }
            // Fresnel specular glint arc facing the light direction
            nibblePath.addArc(center: center, radius: radius * 1.02, startAngle: lightAngle - .pi / 3.5, endAngle: lightAngle + .pi / 3.5, clockwise: false)

            return [
                PondStroke(
                    path: nibblePath,
                    color: palette.specular.cgColor(alpha: alpha * 0.75),
                    width: 1.1
                )
            ]

        case .padBump:
            // Organic lily pad contact wake wave with soft green-cyan crest and Fresnel glint (strictly 1 stroke)
            let bumpPath = CGMutablePath()
            let rx = radius * 1.04
            let ry = radius * 0.96
            bumpPath.addEllipse(in: CGRect(x: center.x - rx, y: center.y - ry, width: rx * 2.0, height: ry * 2.0))
            if radius >= 12.0 {
                let rInner = radius * 0.58
                bumpPath.addEllipse(in: CGRect(x: center.x - rInner, y: center.y - rInner, width: rInner * 2.0, height: rInner * 2.0))
            }
            bumpPath.addArc(center: center, radius: rx * 1.01, startAngle: lightAngle - .pi / 4.0, endAngle: lightAngle + .pi / 4.0, clockwise: false)

            return [
                PondStroke(
                    path: bumpPath,
                    color: palette.specular.cgColor(alpha: alpha * 0.80),
                    width: 1.3
                )
            ]

        case .rainDrop:
            // High-contrast sparkling silver capillary rings & impact pearl flash
            let rx = radius * 1.03
            let ry = radius * 0.97
            let outerRect = CGRect(x: center.x - rx, y: center.y - ry, width: rx * 2.0, height: ry * 2.0)

            // Path 1: Diffuse Sky Specular Halo Bloom
            let haloPath = CGMutablePath()
            haloPath.addEllipse(in: outerRect)
            if radius <= 12.0 {
                // Flash glow around initial impact
                haloPath.addEllipse(in: CGRect(x: center.x - 6.0, y: center.y - 6.0, width: 12.0, height: 12.0))
            }

            // Path 2: Crisp Sparkling Silver Crest & Core Pearl Ping
            let crestPath = CGMutablePath()
            crestPath.addEllipse(in: outerRect)

            // Rebound inner capillary ring
            if radius >= 10.0 {
                let rInner = radius * 0.52
                crestPath.addEllipse(in: CGRect(x: center.x - rInner, y: center.y - rInner, width: rInner * 2.0, height: rInner * 2.0))
            }

            // Central impact ping flash
            if radius <= 14.0 {
                let pingR: CGFloat = max(2.0, (14.0 - radius) * 0.35 + 2.0)
                crestPath.addEllipse(in: CGRect(x: center.x - pingR, y: center.y - pingR, width: pingR * 2.0, height: pingR * 2.0))
            }

            let silverColor = CGColor(red: 0.96, green: 0.99, blue: 1.0, alpha: min(1.0, alpha * 0.95))
            let haloColor = CGColor(red: 0.80, green: 0.94, blue: 1.0, alpha: alpha * 0.38)
            let pearlFill = CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: min(1.0, alpha * 0.98))

            return [
                PondStroke(
                    path: haloPath,
                    color: haloColor,
                    width: 3.2,
                    fillColor: (radius <= 12.0) ? CGColor(red: 0.85, green: 0.96, blue: 1.0, alpha: alpha * 0.25) : nil
                ),
                PondStroke(
                    path: crestPath,
                    color: silverColor,
                    width: 1.5,
                    fillColor: (radius <= 14.0) ? pearlFill : nil
                )
            ]

        case .waterCall, .foodDrop:
            // Full Ukiyo-e Wave System & Subsurface Micro-Bubbles (strictly bounded to max 2 strokes per ripple)
            let wavePath = CGMutablePath()
            let specularPath = CGMutablePath()

            // --- PART 1: Inner Bubble & Translucent Meniscus Dimple (Initial touch <= 36.0 pt) ---
            if radius <= 36.0 {
                let dimpleR = max(5.0, radius * 0.60)
                let dimpleRect = CGRect(x: center.x - dimpleR * 1.04, y: center.y - dimpleR * 0.96, width: dimpleR * 2.08, height: dimpleR * 1.92)
                specularPath.addEllipse(in: dimpleRect)

                // Subsurface micro-bubbles
                let bubbles: [(dx: CGFloat, dy: CGFloat, r: CGFloat)] = [
                    (-3.5, 4.5, 3.8),
                    (5.0, -2.5, 2.6),
                    (-6.0, -4.0, 1.8)
                ]

                for b in bubbles {
                    let bp = CGPoint(x: center.x + b.dx * (radius / 18.0), y: center.y + b.dy * (radius / 18.0))
                    specularPath.addEllipse(in: CGRect(x: bp.x - b.r, y: bp.y - b.r, width: b.r * 2.0, height: b.r * 2.0))
                    specularPath.addEllipse(in: CGRect(x: bp.x - b.r * 0.45, y: bp.y + b.r * 0.25, width: b.r * 0.7, height: b.r * 0.7))
                }
            }

            // --- PART 2: Ukiyo-e Wave Arcs (Expanding outwards) ---
            let rings: [(fraction: CGFloat, aGain: CGFloat, minR: CGFloat)] = [
                (1.00, 0.88, 3.0),
                (0.64, 0.62, 10.0),
                (0.36, 0.38, 20.0)
            ]

            let arcs: [(start: CGFloat, end: CGFloat, isPrimary: Bool)] = [
                (.pi * 0.32, .pi * 0.88, true),  // Primary light-facing crest
                (.pi * 1.05, .pi * 1.45, false), // Side crest
                (.pi * 1.68, .pi * 1.96, false)  // Counter crest
            ]

            for ring in rings {
                let r = radius * ring.fraction
                guard r >= ring.minR else { continue }

                for arc in arcs {
                    let steps = 18
                    for s in 0..<steps {
                        let frac = CGFloat(s) / CGFloat(steps)
                        let a1 = arc.start + frac * (arc.end - arc.start)
                        let a2 = arc.start + CGFloat(s + 1) / CGFloat(steps) * (arc.end - arc.start)

                        let p1 = CGPoint(x: center.x + r * cos(a1) * 1.05, y: center.y + r * sin(a1) * 0.95)
                        let p2 = CGPoint(x: center.x + r * cos(a2) * 1.05, y: center.y + r * sin(a2) * 0.95)

                        wavePath.move(to: p1)
                        wavePath.addLine(to: p2)
                    }

                    // Primary crest: Specular highlight and Ukiyo-e foam bead
                    if arc.isPrimary && ring.fraction >= 0.60 && r >= 6.0 {
                        let specArc = CGMutablePath()
                        specArc.addArc(center: center, radius: r * 1.01, startAngle: .pi * 0.48, endAngle: .pi * 0.75, clockwise: false)
                        specularPath.addPath(specArc)

                        // Characteristic Ukiyo-e leading foam bead
                        let foamA: CGFloat = .pi * 0.86
                        let foamP = CGPoint(x: center.x + r * cos(foamA) * 1.05, y: center.y + r * sin(foamA) * 0.95)
                        let foamR: CGFloat = ring.fraction > 0.8 ? 2.4 : 1.7
                        specularPath.addEllipse(in: CGRect(x: foamP.x - foamR, y: foamP.y - foamR, width: foamR * 2, height: foamR * 2))
                    }
                }
            }

            var strokes: [PondStroke] = []
            if !wavePath.isEmpty {
                strokes.append(PondStroke(
                    path: wavePath,
                    color: palette.brush.cgColor(alpha: alpha * 0.70),
                    width: 1.4
                ))
            }

            if !specularPath.isEmpty {
                strokes.append(PondStroke(
                    path: specularPath,
                    color: palette.specular.cgColor(alpha: alpha * 0.90),
                    width: 1.2,
                    fillColor: palette.bubble.color.cgColor(alpha: palette.bubble.alpha * alpha * 0.50)
                ))
            }

            return strokes
        }
    }

    public static func drawRipples(_ ripples: [WaterRipple], in context: CGContext, theme: PondTheme = .day) {
        guard !ripples.isEmpty else { return }
        context.saveGState()
        context.setLineCap(.round)

        for ripple in ripples where !ripple.isDead {
            for stroke in rippleStrokes(for: ripple, theme: theme) {
                if let fill = stroke.fillColor {
                    context.setFillColor(fill)
                    context.addPath(stroke.path)
                    context.fillPath()
                }
                if stroke.width > 0 {
                    context.setStrokeColor(stroke.color)
                    context.setLineWidth(stroke.width)
                    context.addPath(stroke.path)
                    context.strokePath()
                }
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
