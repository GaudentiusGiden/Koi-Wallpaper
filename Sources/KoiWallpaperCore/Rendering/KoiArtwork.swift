import CoreGraphics
import Foundation

/// Original, limited-palette koi artwork. Torso stations use the same spine and
/// widths as collision capsules; fins and tail remain articulated decorations.
public enum KoiArtwork {
    private static let cream = CGColor(red: 0.96, green: 0.94, blue: 0.80, alpha: 1)
    private static let ink = CGColor(red: 0.045, green: 0.12, blue: 0.105, alpha: 1)
    private static let red = CGColor(red: 0.74, green: 0.20, blue: 0.105, alpha: 1)
    private static let orange = CGColor(red: 0.91, green: 0.43, blue: 0.10, alpha: 1)
    private static let ogonBase = CGColor(red: 0.91, green: 0.61, blue: 0.08, alpha: 1)
    private static let ogonHighlight = CGColor(red: 1, green: 0.78, blue: 0.21, alpha: 1)
    private static let asagiBase = CGColor(red: 0.38, green: 0.57, blue: 0.57, alpha: 1)
    private static let asagiStroke = CGColor(red: 0.13, green: 0.33, blue: 0.35, alpha: 0.6)

    private static let creamFin = cream.copy(alpha: 0.66)!
    private static let inkFin = ink.copy(alpha: 0.66)!
    private static let ogonFin = ogonBase.copy(alpha: 0.66)!
    private static let asagiFin = asagiBase.copy(alpha: 0.66)!

    private static let patchShapes: [[CGPoint]] = [
        [CGPoint(x: -0.50, y: -0.25), CGPoint(x: -0.30, y: -0.49), CGPoint(x: 0.06, y: -0.43), CGPoint(x: 0.29, y: -0.50), CGPoint(x: 0.48, y: -0.16), CGPoint(x: 0.40, y: 0.17), CGPoint(x: 0.16, y: 0.48), CGPoint(x: -0.13, y: 0.38), CGPoint(x: -0.42, y: 0.47)],
        [CGPoint(x: -0.47, y: -0.34), CGPoint(x: -0.07, y: -0.48), CGPoint(x: 0.31, y: -0.36), CGPoint(x: 0.45, y: -0.05), CGPoint(x: 0.35, y: 0.44), CGPoint(x: 0.02, y: 0.32), CGPoint(x: -0.22, y: 0.48), CGPoint(x: -0.48, y: 0.13)]
    ]

    public static func draw(_ fish: KoiFish, in context: CGContext, drawShadowOnly: Bool = false, phase: TimeOfDayPhase) {
        draw(fish, in: context, drawShadowOnly: drawShadowOnly, theme: phase.theme)
    }

    public static func draw(
        _ fish: KoiFish,
        in context: CGContext,
        drawShadowOnly: Bool = false,
        theme: PondTheme = .day,
        customShadowStyle: PondLighting.ShadowStyle? = nil,
        customFishAmbientStyle: PondLighting.FishAmbientStyle? = nil
    ) {
        context.saveGState()
        let length = CGFloat(fish.length)
        let halfWidth = CGFloat(fish.width / 2)
        let s = KoiFish.localSpinePoints(length: fish.length, flex: fish.spineCurvature, wigglePhase: fish.wigglePhase)
        let spine = [s.p0, s.p1, s.p2, s.p3, s.p4, s.p5, s.p6].map { CGPoint(x: $0.x, y: $0.y) }
        let shadowOffset = drawShadowOnly ? PondLighting.shadowOffset(distance: length * 0.28) : .zero
        context.translateBy(x: CGFloat(fish.position.x) + shadowOffset.x, y: CGFloat(fish.position.y) + shadowOffset.y)
        context.rotate(by: CGFloat(fish.heading))
        let body = torso(spine: spine, halfWidth: halfWidth)
        let tail = tail(spine: spine, halfWidth: halfWidth, length: length)
        let flutter = CGFloat(sin(fish.wigglePhase)) * 0.10
        let turnFinBias = CGFloat(fish.spineCurvature) * 0.10
        if drawShadowOnly {
            let style = customShadowStyle ?? PondLighting.shadowStyle(for: theme)
            // 1. Slightly expanded stepped penumbra (soft edge into pond bed)
            let penumbraWidth = halfWidth * 1.14
            let penumbraLength = length * 1.05
            let penumbraBody = Self.torso(spine: spine, halfWidth: penumbraWidth)
            let penumbraTail = Self.tail(spine: spine, halfWidth: penumbraWidth, length: penumbraLength)
            context.setFillColor(red: style.color.0, green: style.color.1, blue: style.color.2, alpha: style.penumbraAlpha)
            context.addPath(penumbraBody)
            context.addPath(penumbraTail)
            for side: CGFloat in [-1, 1] {
                context.addPath(pectoralFin(at: spine[2], length: penumbraLength, halfWidth: penumbraWidth,
                                            side: side, flutter: flutter, turnBias: turnFinBias))
            }
            context.fillPath()

            // 2. Core umbra silhouette
            context.setFillColor(red: style.color.0, green: style.color.1, blue: style.color.2, alpha: style.coreAlpha)
            context.addPath(body)
            context.addPath(tail)
            // A single filled silhouette keeps translucent fins from producing
            // darker overlap patches in the projected shadow.
            for side: CGFloat in [-1, 1] {
                context.addPath(pectoralFin(at: spine[2], length: length, halfWidth: halfWidth,
                                            side: side, flutter: flutter, turnBias: turnFinBias))
            }
            context.fillPath()
            context.restoreGState()
            return
        }

        let base: CGColor
        let finColor: CGColor
        switch fish.variety.type {
        case .showa, .shiroUtsuri:
            base = Self.ink
            finColor = Self.inkFin
        case .ogon:
            base = Self.ogonBase
            finColor = Self.ogonFin
        case .asagi:
            base = Self.asagiBase
            finColor = Self.asagiFin
        default:
            base = Self.cream
            finColor = Self.creamFin
        }

        // Broad translucent fins with gentle swim stroke flutter and turn steering flare.
        context.setFillColor(finColor)
        for side: CGFloat in [-1, 1] {
            context.addPath(pectoralFin(at: spine[2], length: length, halfWidth: halfWidth,
                                        side: side, flutter: flutter, turnBias: turnFinBias))
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
            let shape = Self.patchShapes[variant % 2]
            let path = CGMutablePath()
            for (i, p) in shape.enumerated() {
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
            patch(0.27, 0.06, 0.20, 1.35, Self.red, 0)
            patch(0.02, -0.16, 0.21, 1.65, Self.red, 1)
            patch(-0.25, 0.10, 0.16, 1.1, Self.red, 0)
            if fish.variety.type == .sanke {
                patch(0.15, -0.52, 0.09, 0.7, Self.ink, 1)
                patch(-0.08, 0.45, 0.10, 0.65, Self.ink, 0)
                patch(-0.32, -0.18, 0.08, 0.50, Self.ink, 1)
            }
        case .showa:
            patch(0.31, 0, 0.20, 1.6, Self.cream, 1)
            patch(0.02, 0.4, 0.28, 1.5, Self.cream, 0)
            patch(-0.28, -0.1, 0.20, 1.0, Self.cream, 1)
            patch(0.23, -0.05, 0.14, 0.85, Self.red, 0)
            patch(-0.08, 0.15, 0.20, 1.2, Self.red, 1)
        case .shiroUtsuri:
            patch(0.28, 0.1, 0.24, 1.5, Self.cream, 0)
            patch(-0.03, -0.25, 0.24, 1.6, Self.cream, 1)
            patch(-0.29, 0.05, 0.16, 0.9, Self.cream, 0)
        case .tancho:
            patch(0.31, 0, 0.16, 1.0, Self.red, 1)
        case .kikusui:
            patch(0.12, 0.53, 0.47, 0.90, Self.orange, 0)
            patch(-0.04, -0.50, 0.42, 0.82, Self.orange, 1)
        case .asagi:
            patch(0.04, 0.78, 0.55, 0.60, Self.red, 1)
            patch(-0.01, -0.82, 0.52, 0.60, Self.red, 0)
            context.setStrokeColor(Self.asagiStroke)
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
            patch(0.07, 0.15, 0.50, 1.15, Self.ogonHighlight, 1)
        }
        // Theme-colored reflections stay on the existing light and shade areas,
        // so the koi variety's base color and markings remain recognizable.
        let fishAmbient = customFishAmbientStyle ?? PondLighting.fishAmbientStyle(for: theme)
        let shade = CGMutablePath()
        shade.move(to: CGPoint(x: spine[0].x, y: -halfWidth * 0.4))
        for p in spine.prefix(6) { shade.addLine(to: CGPoint(x: p.x, y: p.y - halfWidth * 0.55)) }
        shade.addLine(to: CGPoint(x: -length, y: -length))
        shade.addLine(to: CGPoint(x: length, y: -length))
        shade.closeSubpath()
        context.setFillColor(red: fishAmbient.shadeColor.0, green: fishAmbient.shadeColor.1,
                             blue: fishAmbient.shadeColor.2, alpha: fishAmbient.shadeAlpha)
        context.addPath(shade)
        context.fillPath()
        context.setStrokeColor(red: fishAmbient.highlightColor.0, green: fishAmbient.highlightColor.1,
                               blue: fishAmbient.highlightColor.2, alpha: fishAmbient.highlightAlpha)
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

    private static func pectoralFin(at point: CGPoint, length: CGFloat, halfWidth: CGFloat,
                                    side: CGFloat, flutter: CGFloat, turnBias: CGFloat) -> CGPath {
        let span = side * (flutter + turnBias * side)
        let leading = CGPoint(x: point.x + length * 0.04, y: point.y + side * halfWidth * 0.45)
        let tip = CGPoint(x: point.x - length * 0.20, y: point.y + side * halfWidth * (1.55 + span))
        let trailing = CGPoint(x: point.x - length * 0.23, y: point.y + side * halfWidth * 0.45)
        let forwardControl = CGPoint(x: point.x - length * 0.06, y: point.y + side * halfWidth * 1.8)
        let backControl = CGPoint(x: point.x - length * 0.25, y: point.y + side * halfWidth * 0.9)
        let path = CGMutablePath()
        // Both sides use the torso's winding so their overlapping shadows add
        // to the silhouette instead of cutting a hole in it.
        path.move(to: leading)
        if side > 0 {
            path.addQuadCurve(to: tip, control: forwardControl)
            path.addQuadCurve(to: trailing, control: backControl)
        } else {
            path.addLine(to: trailing)
            path.addQuadCurve(to: tip, control: backControl)
            path.addQuadCurve(to: leading, control: forwardControl)
        }
        path.closeSubpath()
        return path
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
