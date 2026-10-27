import CoreGraphics
import Foundation

/// Renders seasonal organic debris floating on the pond surface (sakura petals, momiji leaves, snow shards).
public enum FloatingDebrisArtwork {

    public static func draw(
        _ debrisList: [FloatingDebris],
        in context: CGContext,
        shadowStyle: PondLighting.ShadowStyle? = nil,
        drawShadowOnly: Bool = false
    ) {
        guard !debrisList.isEmpty else { return }

        context.saveGState()

        for debris in debrisList {
            guard debris.opacity > 0.001 else { continue }

            let pos = CGPoint(x: CGFloat(debris.position.x), y: CGFloat(debris.position.y))
            let s = CGFloat(debris.scale)
            let bob = CGFloat(sin(debris.bobbingPhase) * 0.7)
            let alpha = CGFloat(debris.opacity)

            context.saveGState()

            if drawShadowOnly {
                // Draw soft drop shadow on pond floor
                let offset = PondLighting.shadowOffset(distance: 9.0)
                context.translateBy(x: pos.x + offset.x, y: pos.y + offset.y)
                context.rotate(by: CGFloat(debris.angle))
                context.scaleBy(x: s, y: s)
                context.setAlpha(alpha * 0.28)
                context.setFillColor(red: 0.01, green: 0.04, blue: 0.06, alpha: 1.0)
                drawDebrisSilhouette(type: debris.type, in: context)
            } else {
                // Draw floating debris body on water surface
                context.translateBy(x: pos.x, y: pos.y + bob)
                context.rotate(by: CGFloat(debris.angle))
                context.scaleBy(x: s, y: s)
                context.setAlpha(alpha)

                switch debris.type {
                case .sakuraPetal:
                    drawSakuraPetal(in: context, variant: debris.variant)
                case .momijiLeaf:
                    drawMomijiLeaf(in: context, variant: debris.variant)
                case .waterLilyPetal:
                    drawWaterLilyPetal(in: context, variant: debris.variant)
                case .snowShard:
                    drawSnowShard(in: context, variant: debris.variant)
                }
            }

            context.restoreGState()
        }

        context.restoreGState()
    }

    // MARK: - Specific Artwork Renderers

    private static func drawSakuraPetal(in context: CGContext, variant: Int) {
        // Classic notched sakura petal: 14pt tall, 9pt wide
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 0, y: 7)) // Stem base
        path.addCurve(to: CGPoint(x: -4.5, y: -4), control1: CGPoint(x: -3.5, y: 4), control2: CGPoint(x: -5.0, y: 0))
        path.addCurve(to: CGPoint(x: -1.2, y: -7), control1: CGPoint(x: -4.0, y: -6.5), control2: CGPoint(x: -2.5, y: -7.0))
        path.addLine(to: CGPoint(x: 0, y: -5.2)) // Center notch
        path.addLine(to: CGPoint(x: 1.2, y: -7))
        path.addCurve(to: CGPoint(x: 4.5, y: -4), control1: CGPoint(x: 2.5, y: -7.0), control2: CGPoint(x: 4.0, y: -6.5))
        path.addCurve(to: CGPoint(x: 0, y: 7), control1: CGPoint(x: 5.0, y: 0), control2: CGPoint(x: 3.5, y: 4))
        path.closeSubpath()

        // Base petal fill (delicate pink)
        if variant == 0 {
            context.setFillColor(red: 0.99, green: 0.74, blue: 0.82, alpha: 0.96)
        } else {
            context.setFillColor(red: 0.98, green: 0.68, blue: 0.78, alpha: 0.96)
        }
        context.addPath(path)
        context.fillPath()

        // Inner blushing gradient / vein highlight
        let innerPath = CGMutablePath()
        innerPath.move(to: CGPoint(x: 0, y: 6))
        innerPath.addCurve(to: CGPoint(x: 0, y: -2), control1: CGPoint(x: -1.5, y: 3), control2: CGPoint(x: -0.5, y: 0))
        innerPath.addLine(to: CGPoint(x: 0, y: 6))
        innerPath.closeSubpath()

        context.setFillColor(red: 0.92, green: 0.45, blue: 0.60, alpha: 0.75)
        context.addPath(innerPath)
        context.fillPath()

        // Subtle petal edge outline
        context.setStrokeColor(red: 0.90, green: 0.52, blue: 0.65, alpha: 0.55)
        context.setLineWidth(0.6)
        context.addPath(path)
        context.strokePath()
    }

    private static func drawMomijiLeaf(in context: CGContext, variant: Int) {
        // Japanese maple leaf with 5 lobes radiating outward: 22pt span
        let baseColor: (CGFloat, CGFloat, CGFloat)
        let veinColor: (CGFloat, CGFloat, CGFloat)

        if variant == 0 {
            // Scarlet crimson momiji
            baseColor = (0.84, 0.20, 0.16)
            veinColor = (0.52, 0.09, 0.08)
        } else {
            // Golden amber momiji
            baseColor = (0.90, 0.54, 0.15)
            veinColor = (0.62, 0.30, 0.06)
        }

        let leaf = CGMutablePath()
        leaf.move(to: CGPoint(x: 0, y: 9)) // Petiole base

        // Left lower lobe
        leaf.addLine(to: CGPoint(x: -6, y: 4))
        leaf.addLine(to: CGPoint(x: -9, y: 5))
        leaf.addLine(to: CGPoint(x: -6, y: 1))

        // Left upper lobe
        leaf.addLine(to: CGPoint(x: -8, y: -4))
        leaf.addLine(to: CGPoint(x: -10, y: -5))
        leaf.addLine(to: CGPoint(x: -4, y: -4))

        // Central top lobe
        leaf.addLine(to: CGPoint(x: -2, y: -9))
        leaf.addLine(to: CGPoint(x: 0, y: -12))
        leaf.addLine(to: CGPoint(x: 2, y: -9))

        // Right upper lobe
        leaf.addLine(to: CGPoint(x: 4, y: -4))
        leaf.addLine(to: CGPoint(x: 10, y: -5))
        leaf.addLine(to: CGPoint(x: 8, y: -4))

        // Right lower lobe
        leaf.addLine(to: CGPoint(x: 6, y: 1))
        leaf.addLine(to: CGPoint(x: 9, y: 5))
        leaf.addLine(to: CGPoint(x: 6, y: 4))

        leaf.closeSubpath()

        // Fill leaf blade
        context.setFillColor(red: baseColor.0, green: baseColor.1, blue: baseColor.2, alpha: 0.95)
        context.addPath(leaf)
        context.fillPath()

        // Veins
        context.setStrokeColor(red: veinColor.0, green: veinColor.1, blue: veinColor.2, alpha: 0.85)
        context.setLineWidth(0.8)
        context.move(to: CGPoint(x: 0, y: 9))
        context.addLine(to: CGPoint(x: 0, y: -9))
        context.move(to: CGPoint(x: 0, y: 3))
        context.addLine(to: CGPoint(x: -7, y: -4))
        context.move(to: CGPoint(x: 0, y: 3))
        context.addLine(to: CGPoint(x: 7, y: -4))
        context.strokePath()

        // Rim highlight
        context.setStrokeColor(red: baseColor.0 * 1.15, green: baseColor.1 * 1.15, blue: baseColor.2 * 1.15, alpha: 0.45)
        context.setLineWidth(0.5)
        context.addPath(leaf)
        context.strokePath()
    }

    private static func drawWaterLilyPetal(in context: CGContext, variant: Int) {
        // Delicate curved water lily petal: 16pt tall, 7pt wide
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 0, y: 8))
        path.addCurve(to: CGPoint(x: -3.5, y: -3), control1: CGPoint(x: -3.0, y: 4), control2: CGPoint(x: -4.0, y: 0))
        path.addCurve(to: CGPoint(x: 0, y: -8), control1: CGPoint(x: -3.0, y: -6), control2: CGPoint(x: -1.0, y: -7.5))
        path.addCurve(to: CGPoint(x: 3.5, y: -3), control1: CGPoint(x: 1.0, y: -7.5), control2: CGPoint(x: 3.0, y: -6))
        path.addCurve(to: CGPoint(x: 0, y: 8), control1: CGPoint(x: 4.0, y: 0), control2: CGPoint(x: 3.0, y: 4))
        path.closeSubpath()

        // White cream body
        context.setFillColor(red: 0.96, green: 0.97, blue: 0.95, alpha: 0.94)
        context.addPath(path)
        context.fillPath()

        // Blush pink tip
        context.setFillColor(red: 0.94, green: 0.62, blue: 0.74, alpha: 0.65)
        let tipPath = CGMutablePath()
        tipPath.move(to: CGPoint(x: -2.0, y: -4))
        tipPath.addLine(to: CGPoint(x: 0, y: -8))
        tipPath.addLine(to: CGPoint(x: 2.0, y: -4))
        tipPath.closeSubpath()
        context.addPath(tipPath)
        context.fillPath()

        context.setStrokeColor(red: 0.85, green: 0.88, blue: 0.85, alpha: 0.6)
        context.setLineWidth(0.5)
        context.addPath(path)
        context.strokePath()
    }

    private static func drawSnowShard(in context: CGContext, variant: Int) {
        // Hexagonal ice shard / snowflake
        context.setStrokeColor(red: 0.92, green: 0.97, blue: 1.0, alpha: 0.92)
        context.setLineWidth(0.9)

        let r: CGFloat = 6.5
        for i in 0..<3 {
            let theta = CGFloat(i) * (.pi / 3.0)
            let dx = cos(theta) * r
            let dy = sin(theta) * r
            context.move(to: CGPoint(x: -dx, y: -dy))
            context.addLine(to: CGPoint(x: dx, y: dy))
        }
        context.strokePath()

        // Inner glowing ice core
        context.setFillColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.95)
        context.fillEllipse(in: CGRect(x: -1.8, y: -1.8, width: 3.6, height: 3.6))
    }

    private static func drawDebrisSilhouette(type: FloatingDebrisType, in context: CGContext) {
        switch type {
        case .sakuraPetal, .waterLilyPetal:
            context.fillEllipse(in: CGRect(x: -4.0, y: -6.0, width: 8.0, height: 12.0))
        case .momijiLeaf:
            context.fillEllipse(in: CGRect(x: -7.0, y: -7.0, width: 14.0, height: 14.0))
        case .snowShard:
            context.fillEllipse(in: CGRect(x: -3.0, y: -3.0, width: 6.0, height: 6.0))
        }
    }
}
