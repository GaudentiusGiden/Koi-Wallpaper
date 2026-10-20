import CoreGraphics
import Foundation

/// Procedural artwork generator for pond elements: deep water, underwater caustics,
/// lily pads, lotus flowers, food pellets, and surface ripples.
public enum PondArtwork {

    // MARK: - Water Background & Caustics

    public static func drawWater(in context: CGContext, rect: CGRect, phase: TimeOfDayPhase = .day) {
        context.saveGState()
        context.translateBy(x: rect.minX, y: rect.minY)
        let w = rect.width, h = rect.height
        let colors: [CGColor]
        switch phase {
        case .day:
            colors = [CGColor(red: 0.42, green: 0.72, blue: 0.57, alpha: 1), CGColor(red: 0.18, green: 0.43, blue: 0.32, alpha: 1), CGColor(red: 0.08, green: 0.26, blue: 0.21, alpha: 1)]
        case .dawn:
            colors = [CGColor(red: 0.47, green: 0.61, blue: 0.44, alpha: 1), CGColor(red: 0.20, green: 0.36, blue: 0.29, alpha: 1), CGColor(red: 0.06, green: 0.21, blue: 0.19, alpha: 1)]
        case .dusk:
            colors = [CGColor(red: 0.28, green: 0.29, blue: 0.35, alpha: 1), CGColor(red: 0.13, green: 0.16, blue: 0.23, alpha: 1), CGColor(red: 0.06, green: 0.09, blue: 0.16, alpha: 1)]
        case .night:
            colors = [CGColor(red: 0.07, green: 0.15, blue: 0.23, alpha: 1), CGColor(red: 0.025, green: 0.07, blue: 0.13, alpha: 1), CGColor(red: 0.01, green: 0.03, blue: 0.07, alpha: 1)]
        }
        let space = CGColorSpaceCreateDeviceRGB()
        context.setFillColor(colors[2])
        context.fill(CGRect(x: 0, y: 0, width: w, height: h))
        if let gradient = CGGradient(colorsSpace: space, colors: colors as CFArray, locations: [0, 0.50, 1]) {
            context.drawRadialGradient(gradient, startCenter: CGPoint(x: w * 0.36, y: h * 0.96), startRadius: 0,
                                       endCenter: CGPoint(x: w * 0.53, y: h * 0.42), endRadius: max(w, h) * 0.87,
                                       options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
        }
        // Overlapping, oblique pools of light give the water spatial depth.
        let gain: CGFloat = phase == .day ? 1 : (phase == .dawn ? 0.60 : 0.16)
        func light(_ x: CGFloat, _ y: CGFloat, _ rx: CGFloat, _ ry: CGFloat, _ angle: CGFloat, _ alpha: CGFloat) {
            context.saveGState()
            context.translateBy(x: x * w, y: y * h)
            context.rotate(by: angle)
            context.scaleBy(x: rx * w, y: ry * h)
            if let glow = CGGradient(colorsSpace: space, colors: [
                CGColor(red: 0.69, green: 1, blue: 0.83, alpha: alpha * gain),
                CGColor(red: 0.46, green: 0.91, blue: 0.69, alpha: alpha * 0.26 * gain),
                CGColor(red: 0.46, green: 0.91, blue: 0.69, alpha: 0)
            ] as CFArray, locations: [0, 0.48, 1]) {
                context.drawRadialGradient(glow, startCenter: .zero, startRadius: 0,
                                           endCenter: .zero, endRadius: 1, options: [])
            }
            context.restoreGState()
        }
        light(0.17, 0.40, 0.13, 0.74, -0.43, 0.78)
        light(0.43, 0.94, 0.34, 0.22, -0.18, 0.82)
        light(0.73, 0.78, 0.10, 0.55, -0.52, 0.30)
        light(0.96, 0.18, 0.19, 0.37, -0.48, 0.16)
        // A chain of feathered pools follows a curved light shaft. Its center
        // is also soft; a translucent stroked path would leave a hard ribbon edge.
        for index in 0..<24 {
            let t = CGFloat(index) / 23
            let u = 1 - t
            let x = u * u * u * (-0.10) + 3 * u * u * t * 0.10 + 3 * u * t * t * 0.25 + t * t * t * 0.48
            let y = u * u * u * (-0.10) + 3 * u * u * t * 0.40 + 3 * u * t * t * 0.58 + t * t * t * 1.12
            light(x, y, 0.045, 0.11, -0.43, 0.16)
        }

        // Original, seeded flecks sit below the smooth water surface. They are
        // generated only on cache rebuild and do not animate like screen noise.
        var random = SeededRandomNumberGenerator(seed: 405)
        let unit = min(w, h) / 270
        for index in 0..<3000 {
            let x = CGFloat(Double.random(in: 0...1, using: &random)) * w
            let y = CGFloat(Double.random(in: 0...1, using: &random)) * h
            let size = CGFloat(Double.random(in: 0.4...1.4, using: &random)) * unit
            if index % 3 == 0 { context.setFillColor(red: 0.61, green: 0.85, blue: 0.60, alpha: 0.065 * gain) }
            else { context.setFillColor(red: 0.04, green: 0.25, blue: 0.18, alpha: 0.065 * gain) }
            context.fill(CGRect(x: x, y: y, width: size, height: size))
        }
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
