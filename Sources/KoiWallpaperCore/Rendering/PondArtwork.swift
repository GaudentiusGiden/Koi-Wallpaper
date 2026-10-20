import CoreGraphics
import Foundation

/// Procedural artwork generator for pond elements: deep water, underwater caustics,
/// lily pads, lotus flowers, food pellets, and surface ripples.
public enum PondArtwork {

    // MARK: - Water Background & Caustics

    public static func drawWater(in context: CGContext, rect: CGRect, phase: TimeOfDayPhase = .day) {
        context.saveGState()

        // 1. Base Gradient: Atmospheric pond water tuned per phase
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let gradientColors: CFArray

        switch phase {
        case .dawn:
            gradientColors = [
                CGColor(red: 0.07, green: 0.16, blue: 0.18, alpha: 1.0),
                CGColor(red: 0.03, green: 0.09, blue: 0.12, alpha: 1.0)
            ] as CFArray
        case .day:
            gradientColors = [
                CGColor(red: 0.04, green: 0.14, blue: 0.16, alpha: 1.0),
                CGColor(red: 0.02, green: 0.08, blue: 0.10, alpha: 1.0)
            ] as CFArray
        case .dusk:
            gradientColors = [
                CGColor(red: 0.12, green: 0.09, blue: 0.18, alpha: 1.0),
                CGColor(red: 0.05, green: 0.04, blue: 0.10, alpha: 1.0)
            ] as CFArray
        case .night:
            gradientColors = [
                CGColor(red: 0.02, green: 0.05, blue: 0.12, alpha: 1.0),
                CGColor(red: 0.01, green: 0.02, blue: 0.05, alpha: 1.0)
            ] as CFArray
        }

        let locations: [CGFloat] = [0.0, 1.0]

        if let gradient = CGGradient(colorsSpace: colorSpace, colors: gradientColors, locations: locations) {
            let center = CGPoint(x: rect.midX, y: rect.midY)
            let radius = max(rect.width, rect.height) * 0.75
            context.drawRadialGradient(
                gradient,
                startCenter: center,
                startRadius: 0,
                endCenter: center,
                endRadius: radius,
                options: [.drawsAfterEndLocation]
            )
        } else {
            context.setFillColor(red: 0.03, green: 0.10, blue: 0.12, alpha: 1.0)
            context.fill(rect)
        }

        // 2. Soft Underwater Caustics & Shimmer Bands tuned per phase
        drawCaustics(in: context, rect: rect, phase: phase)

        context.restoreGState()
    }

    private static func drawCaustics(in context: CGContext, rect: CGRect, phase: TimeOfDayPhase = .day) {
        context.saveGState()

        let causticColor: CGColor
        switch phase {
        case .dawn:
            causticColor = CGColor(red: 0.45, green: 0.40, blue: 0.32, alpha: 0.16)
        case .day:
            causticColor = CGColor(red: 0.12, green: 0.40, blue: 0.38, alpha: 0.14)
        case .dusk:
            causticColor = CGColor(red: 0.50, green: 0.30, blue: 0.38, alpha: 0.15)
        case .night:
            causticColor = CGColor(red: 0.22, green: 0.35, blue: 0.52, alpha: 0.12)
        }

        context.setStrokeColor(causticColor)
        context.setLineWidth(24.0)
        context.setLineCap(.round)

        let w = rect.width
        let h = rect.height

        // Flowing curved caustic bands
        let path1 = CGMutablePath()
        path1.move(to: CGPoint(x: w * 0.15, y: h * 0.2))
        path1.addCurve(to: CGPoint(x: w * 0.85, y: h * 0.4),
                       control1: CGPoint(x: w * 0.4, y: h * 0.1),
                       control2: CGPoint(x: w * 0.6, y: h * 0.5))
        context.addPath(path1)
        context.strokePath()

        let path2 = CGMutablePath()
        path2.move(to: CGPoint(x: w * 0.1, y: h * 0.75))
        path2.addCurve(to: CGPoint(x: w * 0.9, y: h * 0.65),
                       control1: CGPoint(x: w * 0.35, y: h * 0.85),
                       control2: CGPoint(x: w * 0.65, y: h * 0.55))
        context.addPath(path2)
        context.strokePath()

        context.restoreGState()
    }

    /// Atmospheric overlay representing ambient lighting (e.g. night darkness, dusk glow, dawn warmth).
    public static func drawAtmosphere(in context: CGContext, rect: CGRect, phase: TimeOfDayPhase) {
        guard phase != .day else { return }
        context.saveGState()

        switch phase {
        case .dawn:
            context.setFillColor(red: 0.90, green: 0.65, blue: 0.40, alpha: 0.05)
            context.fill(rect)
        case .day:
            break
        case .dusk:
            context.setFillColor(red: 0.85, green: 0.45, blue: 0.25, alpha: 0.08)
            context.fill(rect)
        case .night:
            context.setFillColor(red: 0.05, green: 0.12, blue: 0.28, alpha: 0.14)
            context.fill(rect)
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

    // MARK: - Lily Pads & Flowers (Pond Flora)

    public static func drawLilyPads(in context: CGContext, bounds: PondBounds) {
        context.saveGState()

        let w = CGFloat(bounds.width)
        let h = CGFloat(bounds.height)

        // Cluster 1: Top-Left Corner
        drawSingleLilyPad(
            in: context,
            center: CGPoint(x: w * 0.08, y: h * 0.85),
            radius: 46.0,
            notchAngle: 0.4,
            hasFlower: true
        )
        drawSingleLilyPad(
            in: context,
            center: CGPoint(x: w * 0.14, y: h * 0.88),
            radius: 34.0,
            notchAngle: -0.8,
            hasFlower: false
        )
        drawSingleLilyPad(
            in: context,
            center: CGPoint(x: w * 0.06, y: h * 0.74),
            radius: 38.0,
            notchAngle: 1.8,
            hasFlower: false
        )

        // Cluster 2: Bottom-Right Corner
        drawSingleLilyPad(
            in: context,
            center: CGPoint(x: w * 0.90, y: h * 0.14),
            radius: 52.0,
            notchAngle: -2.2,
            hasFlower: true
        )
        drawSingleLilyPad(
            in: context,
            center: CGPoint(x: w * 0.84, y: h * 0.10),
            radius: 36.0,
            notchAngle: 1.1,
            hasFlower: false
        )
        drawSingleLilyPad(
            in: context,
            center: CGPoint(x: w * 0.93, y: h * 0.24),
            radius: 40.0,
            notchAngle: -0.5,
            hasFlower: false
        )

        // Cluster 3: Single pad near mid-bottom edge
        drawSingleLilyPad(
            in: context,
            center: CGPoint(x: w * 0.48, y: h * 0.06),
            radius: 42.0,
            notchAngle: 2.5,
            hasFlower: false
        )

        context.restoreGState()
    }

    private static func drawSingleLilyPad(
        in context: CGContext,
        center: CGPoint,
        radius: CGFloat,
        notchAngle: CGFloat,
        hasFlower: Bool
    ) {
        context.saveGState()

        // 1. Soft Drop Shadow onto Pond Floor
        let shadowPath = CGMutablePath()
        let shadowCenter = CGPoint(x: center.x + 8.0, y: center.y - 12.0)
        shadowPath.addArc(
            center: shadowCenter,
            radius: radius,
            startAngle: notchAngle + 0.25,
            endAngle: notchAngle - 0.25 + 2.0 * .pi,
            clockwise: false
        )
        shadowPath.addLine(to: shadowCenter)
        shadowPath.closeSubpath()

        context.setFillColor(red: 0.01, green: 0.05, blue: 0.06, alpha: 0.38)
        context.addPath(shadowPath)
        context.fillPath()

        // 2. Lily Pad Leaf Body (Deep Forest / Jade Green)
        let leafPath = CGMutablePath()
        leafPath.addArc(
            center: center,
            radius: radius,
            startAngle: notchAngle + 0.22,
            endAngle: notchAngle - 0.22 + 2.0 * .pi,
            clockwise: false
        )
        leafPath.addLine(to: center)
        leafPath.closeSubpath()

        context.setFillColor(red: 0.12, green: 0.36, blue: 0.22, alpha: 0.95)
        context.addPath(leafPath)
        context.fillPath()

        // 3. Subtle Leaf Vein Ribs
        context.setStrokeColor(red: 0.18, green: 0.48, blue: 0.30, alpha: 0.6)
        context.setLineWidth(1.0)
        for i in 0..<7 {
            let veinAngle = notchAngle + 0.45 + CGFloat(i) * ((2.0 * .pi - 0.9) / 6.0)
            context.move(to: center)
            let veinEnd = CGPoint(
                x: center.x + cos(veinAngle) * (radius * 0.88),
                y: center.y + sin(veinAngle) * (radius * 0.88)
            )
            context.addLine(to: veinEnd)
        }
        context.strokePath()

        // 4. Edge highlight ring
        context.setStrokeColor(red: 0.22, green: 0.54, blue: 0.34, alpha: 0.5)
        context.setLineWidth(1.2)
        context.addPath(leafPath)
        context.strokePath()

        // 5. Water Lily Flower (Lotus)
        if hasFlower {
            drawLotusFlower(in: context, center: CGPoint(x: center.x + radius * 0.2, y: center.y + radius * 0.15))
        }

        context.restoreGState()
    }

    private static func drawLotusFlower(in context: CGContext, center: CGPoint) {
        context.saveGState()

        let petalCount = 8
        let petalLen: CGFloat = 13.0
        let petalWidth: CGFloat = 5.5

        // Petals (Blush white/pink gradient)
        context.setFillColor(red: 0.98, green: 0.94, blue: 0.96, alpha: 0.95)
        context.setStrokeColor(red: 0.92, green: 0.72, blue: 0.80, alpha: 0.7)
        context.setLineWidth(0.8)

        for i in 0..<petalCount {
            let angle = (CGFloat(i) / CGFloat(petalCount)) * 2.0 * .pi
            context.saveGState()
            context.translateBy(x: center.x, y: center.y)
            context.rotate(by: angle)

            let petalPath = CGMutablePath()
            petalPath.move(to: .zero)
            petalPath.addCurve(to: CGPoint(x: petalLen, y: 0),
                               control1: CGPoint(x: petalLen * 0.4, y: petalWidth),
                               control2: CGPoint(x: petalLen * 0.8, y: petalWidth * 0.6))
            petalPath.addCurve(to: .zero,
                               control1: CGPoint(x: petalLen * 0.8, y: -petalWidth * 0.6),
                               control2: CGPoint(x: petalLen * 0.4, y: -petalWidth))
            petalPath.closeSubpath()

            context.addPath(petalPath)
            context.fillPath()
            context.addPath(petalPath)
            context.strokePath()

            context.restoreGState()
        }

        // Flower Center (Golden Stamen)
        context.setFillColor(red: 0.96, green: 0.82, blue: 0.24, alpha: 1.0)
        let centerR: CGFloat = 4.0
        context.fillEllipse(in: CGRect(x: center.x - centerR, y: center.y - centerR, width: centerR * 2, height: centerR * 2))

        context.restoreGState()
    }
}
