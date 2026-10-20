import CoreGraphics
import Foundation

/// Original, limited-palette koi artwork. Torso stations use the same spine and
/// widths as collision capsules; fins and tail remain articulated decorations.
public enum KoiArtwork {
    public static func draw(_ fish: KoiFish, in context: CGContext, drawShadowOnly: Bool = false) {
        context.saveGState()
        let length = CGFloat(fish.length)
        let halfWidth = CGFloat(fish.width / 2)
        let s = KoiFish.localSpinePoints(length: fish.length, flex: fish.spineCurvature, wigglePhase: fish.wigglePhase)
        let spine = [s.p0, s.p1, s.p2, s.p3, s.p4, s.p5, s.p6].map { CGPoint(x: $0.x, y: $0.y) }
        let shadowOffset = drawShadowOnly ? CGPoint(x: length * 0.085, y: -length * 0.105) : .zero
        context.translateBy(x: CGFloat(fish.position.x) + shadowOffset.x, y: CGFloat(fish.position.y) + shadowOffset.y)
        context.rotate(by: CGFloat(fish.heading))
        let body = torso(spine: spine, halfWidth: halfWidth)
        let tail = tail(spine: spine, halfWidth: halfWidth, length: length)
        if drawShadowOnly {
            context.setFillColor(red: 0.025, green: 0.17, blue: 0.14, alpha: 0.25)
            context.addPath(body)
            context.addPath(tail)
            context.fillPath()
            context.restoreGState()
            return
        }

        let cream = CGColor(red: 0.96, green: 0.94, blue: 0.80, alpha: 1)
        let ink = CGColor(red: 0.045, green: 0.12, blue: 0.105, alpha: 1)
        let red = CGColor(red: 0.74, green: 0.20, blue: 0.105, alpha: 1)
        let orange = CGColor(red: 0.91, green: 0.43, blue: 0.10, alpha: 1)
        let base: CGColor
        switch fish.variety.type {
        case .showa, .shiroUtsuri: base = ink
        case .ogon: base = CGColor(red: 0.91, green: 0.61, blue: 0.08, alpha: 1)
        case .asagi: base = CGColor(red: 0.38, green: 0.57, blue: 0.57, alpha: 1)
        default: base = cream
        }

        // Broad translucent fins with gentle swim stroke flutter and turn steering flare.
        context.setFillColor(base.copy(alpha: 0.66)!)
        let flutter = CGFloat(sin(fish.wigglePhase)) * 0.10
        let turnFinBias = CGFloat(fish.spineCurvature) * 0.10
        for side: CGFloat in [-1, 1] {
            let p = spine[2]
            let fin = CGMutablePath()
            let finSpan = side * (flutter + turnFinBias * side)
            fin.move(to: CGPoint(x: p.x + length * 0.04, y: p.y + side * halfWidth * 0.45))
            fin.addQuadCurve(to: CGPoint(x: p.x - length * 0.20, y: p.y + side * halfWidth * (1.55 + finSpan)),
                             control: CGPoint(x: p.x - length * 0.06, y: p.y + side * halfWidth * 1.8))
            fin.addQuadCurve(to: CGPoint(x: p.x - length * 0.23, y: p.y + side * halfWidth * 0.45),
                             control: CGPoint(x: p.x - length * 0.25, y: p.y + side * halfWidth * 0.9))
            fin.closeSubpath()
            context.addPath(fin)
            context.fillPath()
        }
        context.addPath(tail)
        context.fillPath()
        context.setFillColor(base)
        context.addPath(body)
        context.fillPath()

        context.saveGState()
        context.addPath(body)
        context.clip()
        // Deliberately irregular islands of color, rather than circular vector spots.
        func patch(_ x: CGFloat, _ y: CGFloat, _ width: CGFloat, _ height: CGFloat, _ color: CGColor, _ variant: Int) {
            let cy = spineY(at: x * length, spine: spine) + y * halfWidth
            let center = CGPoint(x: x * length, y: cy)
            let shapes: [[CGPoint]] = [
                [CGPoint(x: -0.50, y: -0.25), CGPoint(x: -0.30, y: -0.49), CGPoint(x: 0.06, y: -0.43), CGPoint(x: 0.29, y: -0.50), CGPoint(x: 0.48, y: -0.16), CGPoint(x: 0.40, y: 0.17), CGPoint(x: 0.16, y: 0.48), CGPoint(x: -0.13, y: 0.38), CGPoint(x: -0.42, y: 0.47)],
                [CGPoint(x: -0.47, y: -0.34), CGPoint(x: -0.07, y: -0.48), CGPoint(x: 0.31, y: -0.36), CGPoint(x: 0.45, y: -0.05), CGPoint(x: 0.35, y: 0.44), CGPoint(x: 0.02, y: 0.32), CGPoint(x: -0.22, y: 0.48), CGPoint(x: -0.48, y: 0.13)]
            ]
            let path = CGMutablePath()
            for (i, p) in shapes[variant % 2].enumerated() {
                let point = CGPoint(x: center.x + p.x * width * length, y: center.y + p.y * height * halfWidth)
                if i == 0 { path.move(to: point) } else { path.addLine(to: point) }
            }
            path.closeSubpath()
            context.setFillColor(color)
            context.addPath(path)
            context.fillPath()
        }
        switch fish.variety.type {
        case .kohaku, .sanke:
            patch(0.27, 0.06, 0.20, 1.35, red, 0)
            patch(0.02, -0.16, 0.21, 1.65, red, 1)
            patch(-0.25, 0.10, 0.16, 1.1, red, 0)
            if fish.variety.type == .sanke {
                patch(0.15, -0.52, 0.09, 0.7, ink, 1)
                patch(-0.08, 0.45, 0.10, 0.65, ink, 0)
                patch(-0.32, -0.18, 0.08, 0.50, ink, 1)
            }
        case .showa:
            patch(0.31, 0, 0.20, 1.6, cream, 1)
            patch(0.02, 0.4, 0.28, 1.5, cream, 0)
            patch(-0.28, -0.1, 0.20, 1.0, cream, 1)
            patch(0.23, -0.05, 0.14, 0.85, red, 0)
            patch(-0.08, 0.15, 0.20, 1.2, red, 1)
        case .shiroUtsuri:
            patch(0.28, 0.1, 0.24, 1.5, cream, 0)
            patch(-0.03, -0.25, 0.24, 1.6, cream, 1)
            patch(-0.29, 0.05, 0.16, 0.9, cream, 0)
        case .tancho:
            patch(0.31, 0, 0.16, 1.0, red, 1)
        case .kikusui:
            patch(0.12, 0.53, 0.47, 0.90, orange, 0)
            patch(-0.04, -0.50, 0.42, 0.82, orange, 1)
        case .asagi:
            patch(0.04, 0.78, 0.55, 0.60, red, 1)
            patch(-0.01, -0.82, 0.52, 0.60, red, 0)
            context.setStrokeColor(red: 0.13, green: 0.33, blue: 0.35, alpha: 0.6)
            context.setLineWidth(length * 0.018)
            for i in 0..<7 {
                let x = length * (0.24 - CGFloat(i) * 0.075)
                let y = spineY(at: x, spine: spine)
                context.move(to: CGPoint(x: x + length * 0.025, y: y - halfWidth * 0.5))
                context.addLine(to: CGPoint(x: x - length * 0.01, y: y))
                context.addLine(to: CGPoint(x: x + length * 0.025, y: y + halfWidth * 0.5))
            }
            context.strokePath()
        case .ogon:
            patch(0.07, 0.15, 0.50, 1.15, CGColor(red: 1, green: 0.78, blue: 0.21, alpha: 1), 1)
        }
        // Jade shade along the underside, warm dorsal highlight along the spine.
        let shade = CGMutablePath()
        shade.move(to: CGPoint(x: spine[0].x, y: -halfWidth * 0.4))
        for p in spine.prefix(6) { shade.addLine(to: CGPoint(x: p.x, y: p.y - halfWidth * 0.55)) }
        shade.addLine(to: CGPoint(x: -length, y: -length))
        shade.addLine(to: CGPoint(x: length, y: -length))
        shade.closeSubpath()
        context.setFillColor(red: 0.08, green: 0.29, blue: 0.23, alpha: 0.25)
        context.addPath(shade)
        context.fillPath()
        context.setStrokeColor(red: 1, green: 0.98, blue: 0.78, alpha: 0.22)
        context.setLineWidth(length * 0.028)
        context.move(to: CGPoint(x: spine[1].x, y: spine[1].y + halfWidth * 0.25))
        context.addQuadCurve(to: spine[4], control: CGPoint(x: spine[3].x, y: spine[3].y + halfWidth * 0.18))
        context.strokePath()
        context.restoreGState()

        // Small eyes and gill marks stay legible at the scene's logical resolution.
        let eyeSize = length * 0.035
        context.setFillColor(ink)
        for side: CGFloat in [-1, 1] {
            context.fill(CGRect(x: spine[1].x + length * 0.025, y: side * halfWidth * 0.59 - eyeSize / 2,
                                width: eyeSize, height: eyeSize))
        }
        context.restoreGState()
    }

    private static func torso(spine: [CGPoint], halfWidth: CGFloat) -> CGPath {
        let widths: [CGFloat] = [0.14, 0.70, 1, 0.85, 0.48, 0.18]
        let path = CGMutablePath()
        for (i, p) in spine.prefix(6).enumerated() {
            let point = CGPoint(x: p.x, y: p.y + halfWidth * widths[i])
            if i == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        for i in (0..<6).reversed() { path.addLine(to: CGPoint(x: spine[i].x, y: spine[i].y - halfWidth * widths[i])) }
        path.closeSubpath()
        return path
    }

    private static func tail(spine: [CGPoint], halfWidth: CGFloat, length: CGFloat) -> CGPath {
        let p = spine[5], end = spine[6]
        let path = CGMutablePath()
        path.move(to: p)
        path.addQuadCurve(to: CGPoint(x: end.x, y: end.y + halfWidth * 0.82),
                          control: CGPoint(x: end.x + length * 0.10, y: end.y + halfWidth * 0.80))
        path.addLine(to: CGPoint(x: end.x + length * 0.09, y: end.y))
        path.addLine(to: CGPoint(x: end.x, y: end.y - halfWidth * 0.82))
        path.addQuadCurve(to: p, control: CGPoint(x: end.x + length * 0.10, y: end.y - halfWidth * 0.80))
        path.closeSubpath()
        return path
    }

    private static func spineY(at x: CGFloat, spine: [CGPoint]) -> CGFloat {
        for i in 0..<5 where x <= spine[i].x && x >= spine[i + 1].x {
            let t = (spine[i].x - x) / max(0.001, spine[i].x - spine[i + 1].x)
            return spine[i].y + (spine[i + 1].y - spine[i].y) * t
        }
        return x > spine[0].x ? spine[0].y : spine[5].y
    }
}
