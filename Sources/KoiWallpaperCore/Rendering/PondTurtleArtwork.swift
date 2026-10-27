import AppKit
import CoreGraphics
import Foundation

/// Procedural coarse pixel-art generator for the swimming pond turtle (*Nihon Ishigame / Kame*).
///
/// Rendered directly in the pond's coarse rasterizer buffer (270-line grid with nearest-neighbor magnification),
/// matching the authentic Nagomi aesthetic, top-down perspective, and lighting of the koi fish and flora.
public enum PondTurtleArtwork {

    public enum PaletteVariant: String, Sendable, CaseIterable {
        /// Authentic Japanese Nagomi garden moss jade palette matching koi, lotus, and water caustics
        case nagomi
        /// Natural Japanese pond turtle golden amber stone palette
        case ishigame
    }

    public struct TurtlePalette {
        public let shellDark: CGColor
        public let shellMid: CGColor
        public let shellLight: CGColor
        public let scuteLine: CGColor
        public let skinDark: CGColor
        public let skinBase: CGColor
        public let skinHighlight: CGColor
        public let eyeDark: CGColor
        public let eyeCatchlight: CGColor
    }

    public static let nagomiPalette = TurtlePalette(
        shellDark: CGColor(red: 0.10, green: 0.22, blue: 0.12, alpha: 1.0),     // Deep sumi jade rim
        shellMid: CGColor(red: 0.22, green: 0.40, blue: 0.20, alpha: 1.0),      // Forest moss jade
        shellLight: CGColor(red: 0.38, green: 0.58, blue: 0.28, alpha: 1.0),    // Warm olive highlight
        scuteLine: CGColor(red: 0.06, green: 0.14, blue: 0.08, alpha: 0.90),    // Dark scute grooves
        skinDark: CGColor(red: 0.14, green: 0.24, blue: 0.12, alpha: 1.0),     // Skin contour
        skinBase: CGColor(red: 0.32, green: 0.48, blue: 0.24, alpha: 1.0),     // Mossy green skin
        skinHighlight: CGColor(red: 0.48, green: 0.68, blue: 0.36, alpha: 1.0),// Snout/flipper highlight
        eyeDark: CGColor(red: 0.04, green: 0.06, blue: 0.04, alpha: 1.0),      // Glossy black eye
        eyeCatchlight: CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.95)   // Catchlight glint
    )

    public static let ishigamePalette = TurtlePalette(
        shellDark: CGColor(red: 0.20, green: 0.15, blue: 0.08, alpha: 1.0),     // Dark bronze rim
        shellMid: CGColor(red: 0.42, green: 0.32, blue: 0.16, alpha: 1.0),      // Warm golden amber shell
        shellLight: CGColor(red: 0.60, green: 0.48, blue: 0.22, alpha: 1.0),    // Amber ridge highlight
        scuteLine: CGColor(red: 0.12, green: 0.09, blue: 0.05, alpha: 0.90),
        skinDark: CGColor(red: 0.16, green: 0.20, blue: 0.12, alpha: 1.0),
        skinBase: CGColor(red: 0.34, green: 0.42, blue: 0.24, alpha: 1.0),
        skinHighlight: CGColor(red: 0.50, green: 0.60, blue: 0.34, alpha: 1.0),
        eyeDark: CGColor(red: 0.04, green: 0.05, blue: 0.04, alpha: 1.0),
        eyeCatchlight: CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.95)
    )

    public static func palette(for variant: PaletteVariant) -> TurtlePalette {
        switch variant {
        case .nagomi: return nagomiPalette
        case .ishigame: return ishigamePalette
        }
    }

    // MARK: - Aquatic Depth Shadow

    /// Draws the aquatic drop shadow cast onto the pond bed, matching the koi fish shadow projection.
    public static func drawShadow(
        _ turtle: PondTurtle,
        in context: CGContext,
        shadowStyle: PondLighting.ShadowStyle
    ) {
        guard turtle.isVisible else { return }

        context.saveGState()
        let offset = PondLighting.shadowOffset(distance: 14.0)
        context.translateBy(x: turtle.position.x + offset.x, y: turtle.position.y + offset.y)
        context.rotate(by: CGFloat(turtle.heading))

        let length = turtle.length
        let width = length * 0.74
        let strokeCycle = sin(turtle.paddlePhase)
        let strokeCos = cos(turtle.paddlePhase)

        let flipperSweep = strokeCycle * 0.38 - 0.20
        let rearFlipperSweep = strokeCos * 0.22 + 0.15

        let c = shadowStyle.color
        // 1. Penumbra (soft aquatic boundary)
        context.setFillColor(red: c.0, green: c.1, blue: c.2, alpha: shadowStyle.penumbraAlpha)
        drawSilhouette(in: context, length: length * 1.10, width: width * 1.10, flipperSweep: flipperSweep, rearSweep: rearFlipperSweep)
        context.fillPath()

        // 2. Umbra core (solid shadow)
        context.setFillColor(red: c.0, green: c.1, blue: c.2, alpha: shadowStyle.coreAlpha)
        drawSilhouette(in: context, length: length, width: width, flipperSweep: flipperSweep, rearSweep: rearFlipperSweep)
        context.fillPath()

        context.restoreGState()
    }

    // MARK: - Top-Down Turtle Rendering

    /// Renders the swimming top-down turtle into the active context.
    public static func draw(
        _ turtle: PondTurtle,
        in context: CGContext,
        theme: PondTheme = .day,
        variant: PaletteVariant? = nil
    ) {
        guard turtle.isVisible else { return }

        context.saveGState()
        context.translateBy(x: turtle.position.x, y: turtle.position.y)
        context.rotate(by: CGFloat(turtle.heading))

        let pal = palette(for: variant ?? turtle.variant)
        let length = turtle.length
        let width = length * 0.74
        let strokeCycle = sin(turtle.paddlePhase)
        let strokeCos = cos(turtle.paddlePhase)

        let flipperSweep = strokeCycle * 0.38 - 0.20
        let rearFlipperSweep = strokeCos * 0.22 + 0.15

        // 1. Tiny Cute Tail
        let tailPath = CGMutablePath()
        tailPath.move(to: CGPoint(x: -length * 0.42, y: -length * 0.04))
        tailPath.addLine(to: CGPoint(x: -length * 0.62 + CGFloat(strokeCycle * 2.0), y: 0.0))
        tailPath.addLine(to: CGPoint(x: -length * 0.42, y: length * 0.04))
        tailPath.closeSubpath()
        context.setFillColor(pal.skinBase)
        context.addPath(tailPath)
        context.fillPath()
        context.setStrokeColor(pal.skinDark)
        context.setLineWidth(1.2)
        context.addPath(tailPath)
        context.strokePath()

        // 2. Rear Flippers (Kaki Dayung Belakang)
        for side in [-1.0, 1.0] {
            context.saveGState()
            let originX = -length * 0.30
            let originY = CGFloat(side) * width * 0.38
            context.translateBy(x: originX, y: originY)
            let baseAngle = (side > 0 ? 2.5 : -2.5) + rearFlipperSweep * side
            context.rotate(by: CGFloat(baseAngle))

            let footPath = CGMutablePath()
            let footLen = length * 0.32
            let footWid = length * 0.16
            footPath.addEllipse(in: CGRect(x: 0, y: -footWid * 0.5, width: footLen, height: footWid))

            context.setFillColor(pal.skinBase)
            context.addPath(footPath)
            context.fillPath()

            context.setStrokeColor(pal.skinDark)
            context.setLineWidth(1.0)
            context.addPath(footPath)
            context.strokePath()
            context.restoreGState()
        }

        // 3. Front Flippers (Kaki Dayung Depan - Main Swimming Paddles)
        for side in [-1.0, 1.0] {
            context.saveGState()
            let originX = length * 0.22
            let originY = CGFloat(side) * width * 0.38
            context.translateBy(x: originX, y: originY)
            let baseAngle = (side > 0 ? 1.05 : -1.05) + flipperSweep * side
            context.rotate(by: CGFloat(baseAngle))

            let paddlePath = CGMutablePath()
            let pLen = length * 0.44
            let pWid = length * 0.18
            paddlePath.move(to: .zero)
            paddlePath.addQuadCurve(to: CGPoint(x: pLen * 0.7, y: CGFloat(side) * pWid * 0.8),
                                    control: CGPoint(x: pLen * 0.3, y: CGFloat(side) * pWid * 1.1))
            paddlePath.addQuadCurve(to: CGPoint(x: pLen, y: 0),
                                    control: CGPoint(x: pLen * 0.95, y: CGFloat(side) * pWid * 0.4))
            paddlePath.addQuadCurve(to: CGPoint(x: pLen * 0.5, y: -CGFloat(side) * pWid * 0.4),
                                    control: CGPoint(x: pLen * 0.8, y: -CGFloat(side) * pWid * 0.3))
            paddlePath.closeSubpath()

            context.setFillColor(pal.skinBase)
            context.addPath(paddlePath)
            context.fillPath()

            // Leading edge highlight
            context.setStrokeColor(pal.skinHighlight)
            context.setLineWidth(1.2)
            context.move(to: .zero)
            context.addQuadCurve(to: CGPoint(x: pLen * 0.7, y: CGFloat(side) * pWid * 0.8),
                                 control: CGPoint(x: pLen * 0.3, y: CGFloat(side) * pWid * 1.1))
            context.strokePath()

            context.setStrokeColor(pal.skinDark)
            context.setLineWidth(1.0)
            context.addPath(paddlePath)
            context.strokePath()
            context.restoreGState()
        }

        // 4. Head and Rounded Snout (Kepala Kura-kura)
        context.saveGState()
        let headBob = CGFloat(strokeCycle * 1.5)
        let headOriginX = length * 0.38 + headBob
        let headPath = CGMutablePath()
        let headLen = length * 0.28
        let headWid = length * 0.20

        headPath.addEllipse(in: CGRect(x: headOriginX, y: -headWid * 0.5, width: headLen, height: headWid))
        context.setFillColor(pal.skinBase)
        context.addPath(headPath)
        context.fillPath()

        // Snout highlight
        context.setFillColor(pal.skinHighlight)
        context.fillEllipse(in: CGRect(x: headOriginX + headLen * 0.35, y: -headWid * 0.25, width: headLen * 0.45, height: headWid * 0.5))

        // Eyes (Two glossy beads with catchlight glints)
        for eyeSide in [-1.0, 1.0] {
            let eyeX = headOriginX + headLen * 0.55
            let eyeY = CGFloat(eyeSide) * headWid * 0.35
            let eyeR = length * 0.038

            context.setFillColor(pal.eyeDark)
            context.fillEllipse(in: CGRect(x: eyeX - eyeR, y: eyeY - eyeR, width: eyeR * 2, height: eyeR * 2))

            let clR = eyeR * 0.45
            context.setFillColor(pal.eyeCatchlight)
            context.fillEllipse(in: CGRect(x: eyeX - eyeR * 0.3, y: eyeY - eyeR * 0.3, width: clR * 2, height: clR * 2))
        }

        context.setStrokeColor(pal.skinDark)
        context.setLineWidth(1.0)
        context.addPath(headPath)
        context.strokePath()
        context.restoreGState()

        // 5. Carapace (Tempurung Kura-kura)
        let shellRect = CGRect(x: -length * 0.44, y: -width * 0.5, width: length * 0.88, height: width)

        // Marginal Rim (Pinggiran Luar Tempurung)
        context.setFillColor(pal.shellDark)
        context.fillEllipse(in: shellRect)

        // Inner Dome (Kubah Dalam)
        let innerRect = shellRect.insetBy(dx: length * 0.045, dy: width * 0.045)
        context.setFillColor(pal.shellMid)
        context.fillEllipse(in: innerRect)

        // Hexagonal Scutes (Lempeng Tempurung Khas Kura-kura)
        context.saveGState()
        context.setStrokeColor(pal.scuteLine)
        context.setLineWidth(1.4)

        let cx0 = -length * 0.22
        let cx1 = 0.0
        let cx2 = length * 0.22
        let scuteW = length * 0.18
        let scuteH = width * 0.26

        for cx in [cx0, cx1, cx2] {
            let hexPath = CGMutablePath()
            hexPath.move(to: CGPoint(x: cx - scuteW * 0.5, y: 0))
            hexPath.addLine(to: CGPoint(x: cx - scuteW * 0.25, y: scuteH * 0.5))
            hexPath.addLine(to: CGPoint(x: cx + scuteW * 0.25, y: scuteH * 0.5))
            hexPath.addLine(to: CGPoint(x: cx + scuteW * 0.5, y: 0))
            hexPath.addLine(to: CGPoint(x: cx + scuteW * 0.25, y: -scuteH * 0.5))
            hexPath.addLine(to: CGPoint(x: cx - scuteW * 0.25, y: -scuteH * 0.5))
            hexPath.closeSubpath()

            context.setFillColor(pal.shellLight.copy(alpha: 0.35)!)
            context.addPath(hexPath)
            context.fillPath()

            context.addPath(hexPath)
            context.strokePath()
        }

        // Costal scutes (Garis lempeng lateral)
        for side in [-1.0, 1.0] {
            for cx in [cx0, cx1, cx2] {
                let costalPath = CGMutablePath()
                costalPath.move(to: CGPoint(x: cx, y: CGFloat(side) * scuteH * 0.5))
                costalPath.addLine(to: CGPoint(x: cx * 1.1, y: CGFloat(side) * width * 0.44))
                context.addPath(costalPath)
                context.strokePath()
            }
        }
        context.restoreGState()

        // Dorsal Ridge Highlight (Kilau garis punggung)
        context.saveGState()
        let ridgePath = CGMutablePath()
        ridgePath.addEllipse(in: CGRect(x: -length * 0.26, y: -width * 0.06, width: length * 0.52, height: width * 0.12))
        context.setFillColor(pal.shellLight.copy(alpha: 0.28)!)
        context.addPath(ridgePath)
        context.fillPath()
        context.restoreGState()

        // Shell Outline
        context.setStrokeColor(pal.shellDark)
        context.setLineWidth(1.5)
        context.strokeEllipse(in: shellRect)

        context.restoreGState()
    }

    private static func drawSilhouette(
        in context: CGContext,
        length: CGFloat,
        width: CGFloat,
        flipperSweep: CGFloat,
        rearSweep: CGFloat
    ) {
        let shellRect = CGRect(x: -length * 0.44, y: -width * 0.5, width: length * 0.88, height: width)
        context.addEllipse(in: shellRect)

        let headLen = length * 0.28
        let headWid = length * 0.20
        context.addEllipse(in: CGRect(x: length * 0.38, y: -headWid * 0.5, width: headLen, height: headWid))

        let tailPath = CGMutablePath()
        tailPath.move(to: CGPoint(x: -length * 0.42, y: -length * 0.05))
        tailPath.addLine(to: CGPoint(x: -length * 0.62, y: 0.0))
        tailPath.addLine(to: CGPoint(x: -length * 0.42, y: length * 0.05))
        tailPath.closeSubpath()
        context.addPath(tailPath)

        for side in [-1.0, 1.0] {
            let originX = length * 0.22
            let originY = CGFloat(side) * width * 0.38
            let pLen = length * 0.44
            let pWid = length * 0.18
            let baseAngle = (side > 0 ? 1.05 : -1.05) + flipperSweep * side

            var t = CGAffineTransform(translationX: originX, y: originY)
            t = t.rotated(by: baseAngle)

            let p = CGMutablePath()
            p.move(to: .zero, transform: t)
            p.addQuadCurve(to: CGPoint(x: pLen * 0.7, y: CGFloat(side) * pWid * 0.8),
                           control: CGPoint(x: pLen * 0.3, y: CGFloat(side) * pWid * 1.1),
                           transform: t)
            p.addQuadCurve(to: CGPoint(x: pLen, y: 0),
                           control: CGPoint(x: pLen * 0.95, y: CGFloat(side) * pWid * 0.4),
                           transform: t)
            p.addQuadCurve(to: CGPoint(x: pLen * 0.5, y: -CGFloat(side) * pWid * 0.4),
                           control: CGPoint(x: pLen * 0.8, y: -CGFloat(side) * pWid * 0.3),
                           transform: t)
            p.closeSubpath()
            context.addPath(p)
        }

        for side in [-1.0, 1.0] {
            let originX = -length * 0.30
            let originY = CGFloat(side) * width * 0.38
            let footLen = length * 0.32
            let footWid = length * 0.16
            let baseAngle = (side > 0 ? 2.5 : -2.5) + rearSweep * side

            var t = CGAffineTransform(translationX: originX, y: originY)
            t = t.rotated(by: baseAngle)

            let p = CGMutablePath()
            p.addEllipse(in: CGRect(x: 0, y: -footWid * 0.5, width: footLen, height: footWid), transform: t)
            context.addPath(p)
        }
    }
}
