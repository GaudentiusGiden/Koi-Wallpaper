import CoreGraphics
import Foundation

/// Procedural artwork generator for realistic, gracefully swimming koi fish.
/// Completely custom vector rendering without external images or assets.
public enum KoiArtwork {

    /// Draws a koi fish onto the provided CGContext.
    /// - Parameters:
    ///   - context: The CoreGraphics context to draw into.
    ///   - fish: The KoiFish model containing position, heading, variety, and spine articulation.
    ///   - drawShadowOnly: When true, draws only the silhouette drop-shadow on the pond bed.
    public static func draw(
        _ fish: KoiFish,
        in context: CGContext,
        drawShadowOnly: Bool = false
    ) {
        context.saveGState()

        // If shadow only, apply pond floor offset
        if drawShadowOnly {
            context.translateBy(x: CGFloat(fish.position.x + 10.0), y: CGFloat(fish.position.y - 12.0))
        } else {
            context.translateBy(x: CGFloat(fish.position.x), y: CGFloat(fish.position.y))
        }

        context.rotate(by: CGFloat(fish.heading))

        let length = CGFloat(fish.length)
        let halfWidth = CGFloat(fish.width * 0.5)
        let flex = CGFloat(fish.spineCurvature)

        // 1. Compute articulated spine points from mouth (front) to tail (back)
        // Uses the shared geometric definition from KoiFish to ensure the visual artwork
        // precisely matches the simulation collision capsules.
        let spine = KoiFish.localSpinePoints(length: fish.length, flex: fish.spineCurvature)
        let p0 = CGPoint(x: spine.p0.x, y: spine.p0.y)
        let p1 = CGPoint(x: spine.p1.x, y: spine.p1.y)
        let p2 = CGPoint(x: spine.p2.x, y: spine.p2.y)
        let p3 = CGPoint(x: spine.p3.x, y: spine.p3.y)
        let p4 = CGPoint(x: spine.p4.x, y: spine.p4.y)
        let p5 = CGPoint(x: spine.p5.x, y: spine.p5.y)
        let p6 = CGPoint(x: spine.p6.x, y: spine.p6.y)

        if drawShadowOnly {
            drawShadowSilhouette(
                in: context,
                length: length,
                halfWidth: halfWidth,
                p0: p0, p1: p1, p2: p2, p3: p3, p4: p4, p5: p5, p6: p6,
                flex: flex
            )
            context.restoreGState()
            return
        }

        // 2. Draw Fins (Pectoral & Pelvic) behind body
        drawPectoralFins(
            in: context,
            variety: fish.variety,
            shoulder: p2,
            length: length,
            halfWidth: halfWidth,
            wigglePhase: fish.wigglePhase
        )

        drawPelvicFins(
            in: context,
            variety: fish.variety,
            flank: p4,
            length: length
        )

        // 3. Draw Main Body
        let bodyPath = CGMutablePath()
        // Top contour (from mouth along left flank to tail wrist)
        bodyPath.move(to: p0)
        bodyPath.addCurve(to: CGPoint(x: p2.x, y: p2.y + halfWidth),
                          control1: CGPoint(x: p1.x + 4, y: halfWidth * 0.7),
                          control2: CGPoint(x: p2.x + 6, y: p2.y + halfWidth))
        bodyPath.addCurve(to: CGPoint(x: p4.x, y: p4.y + halfWidth * 0.48),
                          control1: CGPoint(x: p3.x, y: p3.y + halfWidth * 0.85),
                          control2: CGPoint(x: p4.x + 4, y: p4.y + halfWidth * 0.6))
        bodyPath.addLine(to: CGPoint(x: p5.x, y: p5.y + halfWidth * 0.18))

        // Bottom contour (from tail wrist along right flank back to mouth)
        bodyPath.addLine(to: CGPoint(x: p5.x, y: p5.y - halfWidth * 0.18))
        bodyPath.addCurve(to: CGPoint(x: p4.x, y: p4.y - halfWidth * 0.48),
                          control1: CGPoint(x: p5.x + 4, y: p5.y - halfWidth * 0.2),
                          control2: CGPoint(x: p4.x - 2, y: p4.y - halfWidth * 0.45))
        bodyPath.addCurve(to: CGPoint(x: p2.x, y: p2.y - halfWidth),
                          control1: CGPoint(x: p3.x, y: p3.y - halfWidth * 0.85),
                          control2: CGPoint(x: p2.x + 6, y: p2.y - halfWidth))
        bodyPath.addCurve(to: p0,
                          control1: CGPoint(x: p1.x + 4, y: -halfWidth * 0.7),
                          control2: CGPoint(x: p0.x, y: 0))
        bodyPath.closeSubpath()

        // Fill Base Body Color
        let base = fish.variety.bodyBaseColor
        context.setFillColor(red: base.red, green: base.green, blue: base.blue, alpha: base.alpha)
        context.addPath(bodyPath)
        context.fillPath()

        // 4. Draw Variety Patterns (Clipped to body)
        context.saveGState()
        context.addPath(bodyPath)
        context.clip()
        drawVarietyPatterns(
            in: context,
            variety: fish.variety,
            length: length,
            halfWidth: halfWidth,
            p0: p0, p1: p1, p2: p2, p3: p3, p4: p4, p5: p5
        )
        context.restoreGState()

        // 5. Draw Dorsal Fin Ridge along Spine
        drawDorsalFin(in: context, variety: fish.variety, p2: p2, p3: p3, p4: p4)

        // 6. Draw Caudal (Tail) Fin
        drawTailFin(
            in: context,
            variety: fish.variety,
            p5: p5,
            p6: p6,
            length: length,
            halfWidth: halfWidth,
            flex: flex
        )

        // 7. Draw Eyes & Highlights
        drawEyes(in: context, p1: p1, halfWidth: halfWidth)

        context.restoreGState()
    }

    // MARK: - Shadow Silhouette

    private static func drawShadowSilhouette(
        in context: CGContext,
        length: CGFloat,
        halfWidth: CGFloat,
        p0: CGPoint, p1: CGPoint, p2: CGPoint, p3: CGPoint, p4: CGPoint, p5: CGPoint, p6: CGPoint,
        flex: CGFloat
    ) {
        let shadowColor = CGColor(red: 0.02, green: 0.08, blue: 0.09, alpha: 0.32)
        context.setFillColor(shadowColor)

        let path = CGMutablePath()
        path.move(to: p0)
        path.addCurve(to: CGPoint(x: p2.x, y: p2.y + halfWidth),
                      control1: CGPoint(x: p1.x, y: halfWidth * 0.7),
                      control2: CGPoint(x: p2.x + 4, y: p2.y + halfWidth))
        path.addCurve(to: CGPoint(x: p5.x, y: p5.y + halfWidth * 0.2),
                      control1: CGPoint(x: p3.x, y: p3.y + halfWidth * 0.7),
                      control2: CGPoint(x: p4.x, y: p4.y + halfWidth * 0.4))
        // Tail fin in shadow
        path.addLine(to: CGPoint(x: p6.x, y: p6.y + halfWidth * 0.7))
        path.addLine(to: CGPoint(x: p6.x + 4, y: p6.y))
        path.addLine(to: CGPoint(x: p6.x, y: p6.y - halfWidth * 0.7))
        path.addLine(to: CGPoint(x: p5.x, y: p5.y - halfWidth * 0.2))

        path.addCurve(to: CGPoint(x: p2.x, y: p2.y - halfWidth),
                      control1: CGPoint(x: p4.x, y: p4.y - halfWidth * 0.4),
                      control2: CGPoint(x: p3.x, y: p3.y - halfWidth * 0.7))
        path.addCurve(to: p0,
                      control1: CGPoint(x: p1.x, y: -halfWidth * 0.7),
                      control2: CGPoint(x: p0.x, y: 0))
        path.closeSubpath()

        context.addPath(path)
        context.fillPath()
    }

    // MARK: - Fins

    private static func drawPectoralFins(
        in context: CGContext,
        variety: KoiVariety,
        shoulder: CGPoint,
        length: CGFloat,
        halfWidth: CGFloat,
        wigglePhase: Double
    ) {
        let finLen = length * 0.32
        let flutter = CGFloat(sin(wigglePhase) * 0.08)
        let finCol = variety.finColor

        context.saveGState()
        context.setFillColor(red: finCol.red, green: finCol.green, blue: finCol.blue, alpha: finCol.alpha)

        // Left Fin: sweeps back gracefully along left flank
        let leftFin = CGMutablePath()
        let leftBase = CGPoint(x: shoulder.x + 3, y: shoulder.y + halfWidth * 0.5)
        let leftTip = CGPoint(x: shoulder.x - finLen * 0.85, y: shoulder.y + halfWidth * (1.18 + flutter))
        let leftMid = CGPoint(x: shoulder.x - finLen * 0.35, y: shoulder.y + halfWidth * (1.28 + flutter))
        let leftTrailing = CGPoint(x: shoulder.x - finLen * 0.70, y: shoulder.y + halfWidth * 0.40)

        leftFin.move(to: leftBase)
        leftFin.addCurve(to: leftTip, control1: leftMid, control2: leftTip)
        leftFin.addCurve(to: leftTrailing, control1: CGPoint(x: leftTip.x + 4, y: leftTrailing.y + 2), control2: leftTrailing)
        leftFin.closeSubpath()
        context.addPath(leftFin)
        context.fillPath()

        // Right Fin: sweeps back gracefully along right flank
        let rightFin = CGMutablePath()
        let rightBase = CGPoint(x: shoulder.x + 3, y: shoulder.y - halfWidth * 0.5)
        let rightTip = CGPoint(x: shoulder.x - finLen * 0.85, y: shoulder.y - halfWidth * (1.18 + flutter))
        let rightMid = CGPoint(x: shoulder.x - finLen * 0.35, y: shoulder.y - halfWidth * (1.28 + flutter))
        let rightTrailing = CGPoint(x: shoulder.x - finLen * 0.70, y: shoulder.y - halfWidth * 0.40)

        rightFin.move(to: rightBase)
        rightFin.addCurve(to: rightTip, control1: rightMid, control2: rightTip)
        rightFin.addCurve(to: rightTrailing, control1: CGPoint(x: rightTip.x + 4, y: rightTrailing.y - 2), control2: rightTrailing)
        rightFin.closeSubpath()
        context.addPath(rightFin)
        context.fillPath()

        context.restoreGState()
    }

    private static func drawPelvicFins(
        in context: CGContext,
        variety: KoiVariety,
        flank: CGPoint,
        length: CGFloat
    ) {
        let finCol = variety.finColor
        context.saveGState()
        context.setFillColor(red: finCol.red, green: finCol.green, blue: finCol.blue, alpha: finCol.alpha * 0.8)

        let finW = length * 0.18
        let finH = length * 0.10

        // Small left & right pelvic fins
        context.fillEllipse(in: CGRect(x: flank.x - finW * 0.5, y: flank.y + 4, width: finW, height: finH))
        context.fillEllipse(in: CGRect(x: flank.x - finW * 0.5, y: flank.y - 4 - finH, width: finW, height: finH))

        context.restoreGState()
    }

    private static func drawTailFin(
        in context: CGContext,
        variety: KoiVariety,
        p5: CGPoint,
        p6: CGPoint,
        length: CGFloat,
        halfWidth: CGFloat,
        flex: CGFloat
    ) {
        let finCol = variety.finColor
        context.saveGState()
        context.setFillColor(red: finCol.red, green: finCol.green, blue: finCol.blue, alpha: finCol.alpha)

        let tailFan = CGMutablePath()
        tailFan.move(to: p5)
        // Top fan lobe
        tailFan.addCurve(to: CGPoint(x: p6.x, y: p6.y + halfWidth * 0.8),
                         control1: CGPoint(x: p5.x - length * 0.08, y: p5.y + halfWidth * 0.5),
                         control2: CGPoint(x: p6.x + length * 0.06, y: p6.y + halfWidth * 0.9))
        // Center cleft
        tailFan.addCurve(to: CGPoint(x: p6.x + length * 0.06, y: p6.y),
                         control1: CGPoint(x: p6.x - 2, y: p6.y + halfWidth * 0.3),
                         control2: CGPoint(x: p6.x + 4, y: p6.y + 2))
        // Bottom fan lobe
        tailFan.addCurve(to: CGPoint(x: p6.x, y: p6.y - halfWidth * 0.8),
                         control1: CGPoint(x: p6.x + 4, y: p6.y - 2),
                         control2: CGPoint(x: p6.x - 2, y: p6.y - halfWidth * 0.3))
        tailFan.addCurve(to: p5,
                         control1: CGPoint(x: p6.x + length * 0.06, y: p6.y - halfWidth * 0.9),
                         control2: CGPoint(x: p5.x - length * 0.08, y: p5.y - halfWidth * 0.5))
        tailFan.closeSubpath()

        context.addPath(tailFan)
        context.fillPath()

        // Subtle fin ray striations
        context.setStrokeColor(red: finCol.red * 0.85, green: finCol.green * 0.85, blue: finCol.blue * 0.85, alpha: 0.6)
        context.setLineWidth(0.8)
        context.move(to: p5)
        context.addLine(to: CGPoint(x: p6.x + 1, y: p6.y + halfWidth * 0.5))
        context.move(to: p5)
        context.addLine(to: CGPoint(x: p6.x + 4, y: p6.y))
        context.move(to: p5)
        context.addLine(to: CGPoint(x: p6.x + 1, y: p6.y - halfWidth * 0.5))
        context.strokePath()

        context.restoreGState()
    }

    private static func drawDorsalFin(
        in context: CGContext,
        variety: KoiVariety,
        p2: CGPoint,
        p3: CGPoint,
        p4: CGPoint
    ) {
        context.saveGState()
        let finCol = variety.finColor
        context.setStrokeColor(red: finCol.red * 0.9, green: finCol.green * 0.9, blue: finCol.blue * 0.9, alpha: 0.8)
        context.setLineWidth(1.6)
        context.move(to: CGPoint(x: p2.x - 2, y: p2.y))
        context.addCurve(to: CGPoint(x: p4.x, y: p4.y),
                         control1: CGPoint(x: p3.x + 2, y: p3.y + 0.5),
                         control2: CGPoint(x: p3.x - 4, y: p3.y + 0.5))
        context.strokePath()
        context.restoreGState()
    }

    // MARK: - Variety Patterns

    private static func drawVarietyPatterns(
        in context: CGContext,
        variety: KoiVariety,
        length: CGFloat,
        halfWidth: CGFloat,
        p0: CGPoint, p1: CGPoint, p2: CGPoint, p3: CGPoint, p4: CGPoint, p5: CGPoint
    ) {
        let pColor = variety.primaryPatternColor
        context.setFillColor(red: pColor.red, green: pColor.green, blue: pColor.blue, alpha: pColor.alpha)

        switch variety.type {
        case .kohaku:
            // Beautiful 3-step crimson (hi) plates along back
            context.fillEllipse(in: CGRect(x: p1.x - 4, y: p1.y - halfWidth * 0.6, width: length * 0.26, height: halfWidth * 1.2))
            context.fillEllipse(in: CGRect(x: p3.x - 4, y: p3.y - halfWidth * 0.7, width: length * 0.28, height: halfWidth * 1.35))
            context.fillEllipse(in: CGRect(x: p4.x - 3, y: p4.y - halfWidth * 0.45, width: length * 0.20, height: halfWidth * 0.9))

        case .sanke:
            // Crimson hi plates + black sumi patches
            context.fillEllipse(in: CGRect(x: p1.x - 2, y: p1.y - halfWidth * 0.5, width: length * 0.24, height: halfWidth * 1.1))
            context.fillEllipse(in: CGRect(x: p3.x - 3, y: p3.y - halfWidth * 0.65, width: length * 0.26, height: halfWidth * 1.25))
            context.fillEllipse(in: CGRect(x: p4.x - 2, y: p4.y - halfWidth * 0.4, width: length * 0.18, height: halfWidth * 0.8))

            // Sumi spots (black)
            context.setFillColor(red: 0.1, green: 0.1, blue: 0.12, alpha: 0.95)
            context.fillEllipse(in: CGRect(x: p2.x - 2, y: p2.y + halfWidth * 0.2, width: length * 0.08, height: length * 0.07))
            context.fillEllipse(in: CGRect(x: p3.x - 4, y: p3.y - halfWidth * 0.5, width: length * 0.09, height: length * 0.08))
            context.fillEllipse(in: CGRect(x: p4.x + 2, y: p4.y + halfWidth * 0.15, width: length * 0.07, height: length * 0.06))

        case .showa:
            // Bold red and white wrapping lightning marks across black body
            context.fillEllipse(in: CGRect(x: p1.x - 4, y: p1.y - halfWidth * 0.5, width: length * 0.22, height: halfWidth * 1.1))
            context.fillEllipse(in: CGRect(x: p3.x - 2, y: p3.y - halfWidth * 0.6, width: length * 0.25, height: halfWidth * 1.2))

            // White accents
            context.setFillColor(red: 0.96, green: 0.96, blue: 0.96, alpha: 0.95)
            context.fillEllipse(in: CGRect(x: p0.x - length * 0.1, y: p0.y - halfWidth * 0.3, width: length * 0.12, height: halfWidth * 0.6))
            context.fillEllipse(in: CGRect(x: p2.x - 4, y: p2.y + halfWidth * 0.3, width: length * 0.14, height: halfWidth * 0.6))
            context.fillEllipse(in: CGRect(x: p4.x, y: p4.y - halfWidth * 0.35, width: length * 0.14, height: halfWidth * 0.6))

        case .ogon:
            // Solid metallic shimmer highlights
            context.setFillColor(red: 1.0, green: 0.90, blue: 0.45, alpha: 0.35)
            context.fillEllipse(in: CGRect(x: p2.x - length * 0.1, y: p2.y - halfWidth * 0.35, width: length * 0.35, height: halfWidth * 0.7))

        case .asagi:
            // Reticulated scale mesh along indigo back + vermilion belly
            context.setFillColor(red: 0.88, green: 0.22, blue: 0.14, alpha: 0.9)
            // Left flank vermilion
            context.fillEllipse(in: CGRect(x: p2.x - length * 0.2, y: p2.y + halfWidth * 0.4, width: length * 0.4, height: halfWidth * 0.7))
            // Right flank vermilion
            context.fillEllipse(in: CGRect(x: p2.x - length * 0.2, y: p2.y - halfWidth * 1.1, width: length * 0.4, height: halfWidth * 0.7))

        case .shiroUtsuri:
            // Crisp white patches on glossy black
            context.setFillColor(red: 0.96, green: 0.96, blue: 0.96, alpha: 0.95)
            context.fillEllipse(in: CGRect(x: p1.x - 2, y: p1.y - halfWidth * 0.6, width: length * 0.22, height: halfWidth * 1.1))
            context.fillEllipse(in: CGRect(x: p3.x - 4, y: p3.y + halfWidth * 0.1, width: length * 0.24, height: halfWidth * 0.9))
            context.fillEllipse(in: CGRect(x: p4.x - 2, y: p4.y - halfWidth * 0.5, width: length * 0.18, height: halfWidth * 0.8))

        case .tancho:
            // Pure white body with a single bold scarlet sun on forehead
            context.setFillColor(red: 0.88, green: 0.18, blue: 0.12, alpha: 0.98)
            let sunCenter = CGPoint(x: p1.x + 2, y: p1.y)
            let sunRadius = halfWidth * 0.62
            context.fillEllipse(in: CGRect(
                x: sunCenter.x - sunRadius,
                y: sunCenter.y - sunRadius,
                width: sunRadius * 2,
                height: sunRadius * 2
            ))

        case .kikusui:
            // Metallic orange wavy flank lines on platinum white
            context.fillEllipse(in: CGRect(x: p2.x - length * 0.15, y: p2.y + halfWidth * 0.25, width: length * 0.35, height: halfWidth * 0.55))
            context.fillEllipse(in: CGRect(x: p2.x - length * 0.15, y: p2.y - halfWidth * 0.80, width: length * 0.35, height: halfWidth * 0.55))
        }
    }

    // MARK: - Eyes & Head Details

    private static func drawEyes(in context: CGContext, p1: CGPoint, halfWidth: CGFloat) {
        context.saveGState()
        let eyeRadius: CGFloat = 1.6

        // Left Eye
        let leftEye = CGPoint(x: p1.x + 3, y: p1.y + halfWidth * 0.72)
        context.setFillColor(red: 0.08, green: 0.08, blue: 0.10, alpha: 1.0)
        context.fillEllipse(in: CGRect(x: leftEye.x - eyeRadius, y: leftEye.y - eyeRadius, width: eyeRadius * 2, height: eyeRadius * 2))

        // Left Specular Highlight
        context.setFillColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.9)
        context.fillEllipse(in: CGRect(x: leftEye.x - 0.5, y: leftEye.y + 0.4, width: 0.8, height: 0.8))

        // Right Eye
        let rightEye = CGPoint(x: p1.x + 3, y: p1.y - halfWidth * 0.72)
        context.setFillColor(red: 0.08, green: 0.08, blue: 0.10, alpha: 1.0)
        context.fillEllipse(in: CGRect(x: rightEye.x - eyeRadius, y: rightEye.y - eyeRadius, width: eyeRadius * 2, height: eyeRadius * 2))

        // Right Specular Highlight
        context.setFillColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.9)
        context.fillEllipse(in: CGRect(x: rightEye.x - 0.5, y: rightEye.y - 0.4, width: 0.8, height: 0.8))

        context.restoreGState()
    }
}
