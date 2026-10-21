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

        // Structured depth gradient, light washes, and floor nuances crafted
        // specifically for each theme identity to prevent muddy waters.
        let depthColors: [CGColor]
        let lightColor: (CGFloat, CGFloat, CGFloat)
        let deepTealColor: (CGFloat, CGFloat, CGFloat)
        let oliveColor: (CGFloat, CGFloat, CGFloat)
        let gain: CGFloat
        switch theme {
        case .day:
            depthColors = [
                CGColor(red: 0.52, green: 0.95, blue: 0.77, alpha: 1),
                CGColor(red: 0.35, green: 0.67, blue: 0.53, alpha: 1),
                CGColor(red: 0.22, green: 0.52, blue: 0.40, alpha: 1),
                CGColor(red: 0.12, green: 0.38, blue: 0.28, alpha: 1),
                CGColor(red: 0.06, green: 0.22, blue: 0.16, alpha: 1)
            ]
            lightColor = (0.46, 1.00, 0.78)
            deepTealColor = (0.030, 0.16, 0.13)
            oliveColor = (0.050, 0.16, 0.09)
            gain = 1.0

        case .dawn:
            depthColors = [
                CGColor(red: 0.88, green: 0.82, blue: 0.68, alpha: 1),
                CGColor(red: 0.48, green: 0.68, blue: 0.54, alpha: 1),
                CGColor(red: 0.28, green: 0.52, blue: 0.42, alpha: 1),
                CGColor(red: 0.14, green: 0.35, blue: 0.29, alpha: 1),
                CGColor(red: 0.06, green: 0.20, blue: 0.17, alpha: 1)
            ]
            lightColor = (0.96, 0.84, 0.64)
            deepTealColor = (0.030, 0.16, 0.14)
            oliveColor = (0.060, 0.18, 0.10)
            gain = 0.75

        case .goldenHour:
            depthColors = [
                CGColor(red: 0.95, green: 0.78, blue: 0.48, alpha: 1),
                CGColor(red: 0.52, green: 0.65, blue: 0.44, alpha: 1),
                CGColor(red: 0.22, green: 0.48, blue: 0.45, alpha: 1),
                CGColor(red: 0.10, green: 0.32, blue: 0.34, alpha: 1),
                CGColor(red: 0.04, green: 0.18, blue: 0.22, alpha: 1)
            ]
            lightColor = (1.00, 0.80, 0.42)
            deepTealColor = (0.025, 0.14, 0.17)
            oliveColor = (0.070, 0.14, 0.08)
            gain = 0.92

        case .dusk:
            depthColors = [
                CGColor(red: 0.68, green: 0.46, blue: 0.60, alpha: 1),
                CGColor(red: 0.38, green: 0.32, blue: 0.48, alpha: 1),
                CGColor(red: 0.20, green: 0.24, blue: 0.38, alpha: 1),
                CGColor(red: 0.10, green: 0.14, blue: 0.26, alpha: 1),
                CGColor(red: 0.04, green: 0.07, blue: 0.16, alpha: 1)
            ]
            lightColor = (0.94, 0.58, 0.56)
            deepTealColor = (0.025, 0.055, 0.14)
            oliveColor = (0.045, 0.065, 0.11)
            gain = 0.45

        case .night:
            depthColors = [
                CGColor(red: 0.18, green: 0.36, blue: 0.52, alpha: 1),
                CGColor(red: 0.10, green: 0.22, blue: 0.36, alpha: 1),
                CGColor(red: 0.05, green: 0.13, blue: 0.24, alpha: 1),
                CGColor(red: 0.022, green: 0.07, blue: 0.15, alpha: 1),
                CGColor(red: 0.008, green: 0.03, blue: 0.08, alpha: 1)
            ]
            lightColor = (0.48, 0.76, 0.96)
            deepTealColor = (0.008, 0.032, 0.085)
            oliveColor = (0.012, 0.038, 0.065)
            gain = 0.30

        case .deepClear:
            depthColors = [
                CGColor(red: 0.45, green: 0.98, blue: 0.92, alpha: 1),
                CGColor(red: 0.25, green: 0.76, blue: 0.74, alpha: 1),
                CGColor(red: 0.12, green: 0.56, blue: 0.58, alpha: 1),
                CGColor(red: 0.06, green: 0.38, blue: 0.44, alpha: 1),
                CGColor(red: 0.03, green: 0.22, blue: 0.28, alpha: 1)
            ]
            lightColor = (0.60, 1.00, 0.96)
            deepTealColor = (0.020, 0.18, 0.22)
            oliveColor = (0.035, 0.18, 0.14)
            gain = 1.15

        case .rain:
            depthColors = [
                CGColor(red: 0.55, green: 0.68, blue: 0.70, alpha: 1),
                CGColor(red: 0.34, green: 0.48, blue: 0.50, alpha: 1),
                CGColor(red: 0.20, green: 0.36, blue: 0.38, alpha: 1),
                CGColor(red: 0.11, green: 0.24, blue: 0.27, alpha: 1),
                CGColor(red: 0.05, green: 0.14, blue: 0.17, alpha: 1)
            ]
            lightColor = (0.78, 0.86, 0.88)
            deepTealColor = (0.030, 0.11, 0.14)
            oliveColor = (0.040, 0.10, 0.10)
            gain = 0.58
        }

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
        wash(0.50, 0.95, 0.44, 0.20, -0.08, color: lightColor, alpha: 0.85 * gain)
        wash(0.76, 0.93, 0.30, 0.18, -0.22, color: lightColor, alpha: 0.70 * gain)

        wash(0.14, 0.55, 0.22, 0.38, -0.52, color: lightColor, alpha: 0.75 * gain)
        wash(0.28, 0.76, 0.16, 0.22, -0.60, color: lightColor, alpha: 0.24 * gain)

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
        for _ in 0..<2800 {
            let x = CGFloat(Double.random(in: 0...1, using: &random)) * w
            let y = CGFloat(Double.random(in: 0...1, using: &random)) * h
            let size = CGFloat(Double.random(in: 0.35...0.95, using: &random)) * unit
            let exposure = PondLighting.causticExposure(at: CGPoint(x: x / w, y: y / h))
            let isMineral = Double.random(in: 0...1, using: &random) < Double(exposure * 0.24)
            if isMineral {
                context.setFillColor(red: lightColor.0, green: lightColor.1, blue: lightColor.2, alpha: 0.075 * gain)
            } else {
                context.setFillColor(red: deepTealColor.0, green: deepTealColor.1, blue: deepTealColor.2,
                                     alpha: 0.070 + exposure * 0.035)
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
        guard theme != .day && theme != .deepClear else { return }
        context.saveGState()

        switch theme {
        case .dawn:
            context.setFillColor(red: 0.95, green: 0.80, blue: 0.55, alpha: 0.03)
            context.fill(rect)
        case .day, .deepClear:
            break
        case .goldenHour:
            context.setFillColor(red: 0.98, green: 0.72, blue: 0.35, alpha: 0.05)
            context.fill(rect)
        case .dusk:
            context.setFillColor(red: 0.80, green: 0.40, blue: 0.50, alpha: 0.06)
            context.fill(rect)
        case .night:
            context.setFillColor(red: 0.04, green: 0.10, blue: 0.25, alpha: 0.10)
            context.fill(rect)
        case .rain:
            context.setFillColor(red: 0.60, green: 0.72, blue: 0.78, alpha: 0.07)
            context.fill(rect)
        }

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
