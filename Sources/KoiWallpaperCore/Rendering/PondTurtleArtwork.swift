import AppKit
import CoreGraphics
import Foundation

/// Procedural coarse pixel-art generator for the swimming pond turtle (*Nihon Ishigame / Kame*).
///
/// Rendered directly in the pond's coarse rasterizer buffer (270-line grid with nearest-neighbor magnification),
/// matching the authentic Nagomi aesthetic, top-down perspective, smooth organic texture, and dynamic lighting
/// of the koi fish and flora.
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
        public let scuteTone1: CGColor
        public let scuteTone2: CGColor
        public let skinDark: CGColor
        public let skinBase: CGColor
        public let skinFin: CGColor
        public let skinHighlight: CGColor
        public let eyeDark: CGColor
        public let eyeCatchlight: CGColor
        public let eyeIris: CGColor
        public let neckStripe: CGColor

        public init(
            shellDark: CGColor,
            shellMid: CGColor,
            shellLight: CGColor,
            scuteLine: CGColor,
            scuteTone1: CGColor? = nil,
            scuteTone2: CGColor? = nil,
            skinDark: CGColor,
            skinBase: CGColor,
            skinFin: CGColor? = nil,
            skinHighlight: CGColor,
            eyeDark: CGColor,
            eyeCatchlight: CGColor,
            eyeIris: CGColor? = nil,
            neckStripe: CGColor? = nil
        ) {
            self.shellDark = shellDark
            self.shellMid = shellMid
            self.shellLight = shellLight
            self.scuteLine = scuteLine
            self.scuteTone1 = scuteTone1 ?? shellMid.copy(alpha: 0.90)!
            self.scuteTone2 = scuteTone2 ?? shellLight.copy(alpha: 0.85)!
            self.skinDark = skinDark
            self.skinBase = skinBase
            self.skinFin = skinFin ?? skinBase.copy(alpha: 0.68)!
            self.skinHighlight = skinHighlight
            self.eyeDark = eyeDark
            self.eyeCatchlight = eyeCatchlight
            self.eyeIris = eyeIris ?? CGColor(red: 0.82, green: 0.65, blue: 0.28, alpha: 1.0)
            self.neckStripe = neckStripe ?? CGColor(red: 0.78, green: 0.70, blue: 0.45, alpha: 0.60)
        }
    }

    public static let nagomiPalette = TurtlePalette(
        shellDark: CGColor(red: 0.24, green: 0.16, blue: 0.08, alpha: 1.0),      // Dark bronze rim #3D2814
        shellMid: CGColor(red: 0.56, green: 0.42, blue: 0.21, alpha: 1.0),       // Radiant warm golden amber #8F6B35
        shellLight: CGColor(red: 0.80, green: 0.68, blue: 0.38, alpha: 0.90),    // Sunlit amber dorsal ridge #CCAE61
        scuteLine: CGColor(red: 0.20, green: 0.13, blue: 0.07, alpha: 0.50),     // Translucent bronze scute seam
        scuteTone1: CGColor(red: 0.46, green: 0.34, blue: 0.16, alpha: 0.92),    // Warm copper scute facet
        scuteTone2: CGColor(red: 0.64, green: 0.49, blue: 0.24, alpha: 0.92),    // Golden ochre scute facet
        skinDark: CGColor(red: 0.20, green: 0.18, blue: 0.14, alpha: 1.0),      // Deep boundary tone
        skinBase: CGColor(red: 0.32, green: 0.30, blue: 0.25, alpha: 1.0),      // Warm slate-olive skin #524C40 (natural & earthy)
        skinFin: CGColor(red: 0.56, green: 0.44, blue: 0.24, alpha: 0.70),       // Translucent amber-olive webbed flipper
        skinHighlight: CGColor(red: 0.52, green: 0.48, blue: 0.38, alpha: 0.75), // Soft cream-gold snout sheen
        eyeDark: CGColor(red: 0.045, green: 0.12, blue: 0.105, alpha: 1.0),      // Pure Japanese sumi ink (KoiArtwork.ink)
        eyeCatchlight: CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.92),    // Delicate catchlight glint
        eyeIris: CGColor(red: 0.82, green: 0.65, blue: 0.28, alpha: 1.0),        // Amber iris ring
        neckStripe: CGColor(red: 0.78, green: 0.70, blue: 0.45, alpha: 0.60)     // Cream-gold lateral neck stripes
    )

    public static let ishigamePalette = TurtlePalette(
        shellDark: CGColor(red: 0.24, green: 0.16, blue: 0.08, alpha: 1.0),      // Dark bronze rim
        shellMid: CGColor(red: 0.56, green: 0.42, blue: 0.21, alpha: 1.0),       // Radiant warm golden amber (#8F6B35)
        shellLight: CGColor(red: 0.80, green: 0.68, blue: 0.38, alpha: 0.90),    // Bright amber ridge (#CCAE61)
        scuteLine: CGColor(red: 0.20, green: 0.13, blue: 0.07, alpha: 0.50),     // Subtle translucent seam
        scuteTone1: CGColor(red: 0.46, green: 0.34, blue: 0.16, alpha: 0.92),
        scuteTone2: CGColor(red: 0.64, green: 0.49, blue: 0.24, alpha: 0.92),
        skinDark: CGColor(red: 0.20, green: 0.18, blue: 0.14, alpha: 1.0),
        skinBase: CGColor(red: 0.32, green: 0.30, blue: 0.25, alpha: 1.0),
        skinFin: CGColor(red: 0.56, green: 0.44, blue: 0.24, alpha: 0.70),       // Translucent amber-olive fin
        skinHighlight: CGColor(red: 0.52, green: 0.48, blue: 0.38, alpha: 0.75),
        eyeDark: CGColor(red: 0.045, green: 0.12, blue: 0.105, alpha: 1.0),
        eyeCatchlight: CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.92),
        eyeIris: CGColor(red: 0.82, green: 0.65, blue: 0.28, alpha: 1.0),
        neckStripe: CGColor(red: 0.78, green: 0.70, blue: 0.45, alpha: 0.60)
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
        let offset = PondLighting.shadowOffset(distance: turtle.length * 0.22)
        context.translateBy(x: turtle.position.x + offset.x, y: turtle.position.y + offset.y)
        context.rotate(by: CGFloat(turtle.heading))

        let length = turtle.length
        let halfWidth = length * 0.38
        let strokeCycle = sin(turtle.paddlePhase)
        let strokeCos = cos(turtle.paddlePhase)

        let flipperSweep = strokeCycle * 0.38 - 0.18
        let rearSweep = strokeCos * 0.22 + 0.12

        let shell = makeCarapacePath(length: length, halfWidth: halfWidth)
        let headStart = length * 0.26 + CGFloat(strokeCycle * 1.6)
        let head = makeHeadPath(headStart: headStart, length: length)
        let tail = makeTailPath(length: length, strokeCycle: strokeCycle)

        let flipperL = makeWebbedPaddlePath(side: -1, length: length, halfWidth: halfWidth, flipperSweep: flipperSweep)
        let flipperR = makeWebbedPaddlePath(side: 1, length: length, halfWidth: halfWidth, flipperSweep: flipperSweep)
        let rearL = makeRearPaddlePath(side: -1, length: length, halfWidth: halfWidth, rearSweep: rearSweep)
        let rearR = makeRearPaddlePath(side: 1, length: length, halfWidth: halfWidth, rearSweep: rearSweep)

        // 1. Soft Penumbra (expanded silhouette)
        context.setFillColor(red: shadowStyle.color.0, green: shadowStyle.color.1, blue: shadowStyle.color.2, alpha: shadowStyle.penumbraAlpha)
        context.saveGState()
        context.scaleBy(x: 1.06, y: 1.06)
        context.addPath(shell)
        context.addPath(head)
        context.addPath(tail)
        context.addPath(flipperL)
        context.addPath(flipperR)
        context.addPath(rearL)
        context.addPath(rearR)
        context.fillPath()
        context.restoreGState()

        // 2. Umbra core silhouette
        context.setFillColor(red: shadowStyle.color.0, green: shadowStyle.color.1, blue: shadowStyle.color.2, alpha: shadowStyle.coreAlpha)
        context.addPath(shell)
        context.addPath(head)
        context.addPath(tail)
        context.addPath(flipperL)
        context.addPath(flipperR)
        context.addPath(rearL)
        context.addPath(rearR)
        context.fillPath()

        context.restoreGState()
    }

    // MARK: - Top-Down Smooth Turtle Rendering

    /// Renders the swimming top-down turtle into the active context with smooth koi-harmonized texture and lighting.
    public static func draw(
        _ turtle: PondTurtle,
        in context: CGContext,
        theme: PondTheme = .day,
        variant: PaletteVariant? = nil,
        customFishAmbientStyle: PondLighting.FishAmbientStyle? = nil
    ) {
        guard turtle.isVisible else { return }

        context.saveGState()
        context.translateBy(x: turtle.position.x, y: turtle.position.y)
        context.rotate(by: CGFloat(turtle.heading))

        let pal = palette(for: variant ?? turtle.variant)
        let length = turtle.length
        let halfWidth = length * 0.38
        let strokeCycle = sin(turtle.paddlePhase)
        let strokeCos = cos(turtle.paddlePhase)

        let flipperSweep = strokeCycle * 0.38 - 0.18
        let rearSweep = strokeCos * 0.22 + 0.12

        // 1. Water Surface Wake (Riak gelombang V memecah dari moncong saat berenang)
        context.saveGState()
        context.setStrokeColor(red: 0.78, green: 0.94, blue: 0.98, alpha: 0.48)
        context.setLineWidth(1.4)
        let bowWake = CGMutablePath()
        bowWake.move(to: CGPoint(x: length * 0.42, y: halfWidth * 0.80))
        bowWake.addCurve(to: CGPoint(x: -length * 0.52, y: halfWidth * 1.55),
                         control1: CGPoint(x: length * 0.10, y: halfWidth * 1.35),
                         control2: CGPoint(x: -length * 0.22, y: halfWidth * 1.55))
        bowWake.move(to: CGPoint(x: length * 0.42, y: -halfWidth * 0.80))
        bowWake.addCurve(to: CGPoint(x: -length * 0.52, y: -halfWidth * 1.55),
                         control1: CGPoint(x: length * 0.10, y: -halfWidth * 1.35),
                         control2: CGPoint(x: -length * 0.22, y: -halfWidth * 1.55))
        context.addPath(bowWake)
        context.strokePath()
        context.restoreGState()

        // 2. Translucent Webbed Paddles & Tail
        let flipperL = makeWebbedPaddlePath(side: -1, length: length, halfWidth: halfWidth, flipperSweep: flipperSweep)
        let flipperR = makeWebbedPaddlePath(side: 1, length: length, halfWidth: halfWidth, flipperSweep: flipperSweep)
        let rearL = makeRearPaddlePath(side: -1, length: length, halfWidth: halfWidth, rearSweep: rearSweep)
        let rearR = makeRearPaddlePath(side: 1, length: length, halfWidth: halfWidth, rearSweep: rearSweep)
        let tail = makeTailPath(length: length, strokeCycle: strokeCycle)

        context.setFillColor(pal.skinFin)
        context.addPath(flipperL)
        context.addPath(flipperR)
        context.addPath(rearL)
        context.addPath(rearR)
        context.fillPath()

        context.setFillColor(pal.skinBase)
        context.addPath(tail)
        context.fillPath()

        // 3. Head & Beaked Snout Anatomy
        let headStart = length * 0.26 + CGFloat(strokeCycle * 1.6)
        let head = makeHeadPath(headStart: headStart, length: length)
        context.setFillColor(pal.skinBase)
        context.addPath(head)
        context.fillPath()

        // Snout sheen highlight
        context.setFillColor(pal.skinHighlight)
        context.fillEllipse(in: CGRect(x: headStart + length * 0.22, y: -length * 0.05, width: length * 0.11, height: length * 0.10))

        // Lateral neck stripes (Ciri khas kura-kura kolam Jepang)
        context.setStrokeColor(pal.neckStripe)
        context.setLineWidth(1.2)
        context.move(to: CGPoint(x: headStart + 4, y: length * 0.05))
        context.addLine(to: CGPoint(x: headStart + length * 0.18, y: length * 0.06))
        context.move(to: CGPoint(x: headStart + 4, y: -length * 0.05))
        context.addLine(to: CGPoint(x: headStart + length * 0.18, y: -length * 0.06))
        context.strokePath()

        // Expressive Eyes: Amber Iris Ring + Sumi Pupil + Catchlight Glint
        let eyeX = headStart + length * 0.22
        let eyeY = length * 0.075
        let eyeRad = length * 0.032
        for s: CGFloat in [-1, 1] {
            context.setFillColor(pal.eyeIris)
            context.fillEllipse(in: CGRect(x: eyeX - eyeRad, y: s * eyeY - eyeRad, width: eyeRad * 2, height: eyeRad * 2))
            context.setFillColor(pal.eyeDark)
            context.fillEllipse(in: CGRect(x: eyeX - eyeRad * 0.65, y: s * eyeY - eyeRad * 0.65, width: eyeRad * 1.3, height: eyeRad * 1.3))
            context.setFillColor(pal.eyeCatchlight)
            context.fillEllipse(in: CGRect(x: eyeX + 0.3, y: s * eyeY + 0.3, width: eyeRad * 0.45, height: eyeRad * 0.45))
        }

        // 4. Carapace (Shell) - Contoured Silhouette with Anterior Notch & Flared Posterior Rim
        let shell = makeCarapacePath(length: length, halfWidth: halfWidth)
        context.setFillColor(pal.shellDark)
        context.addPath(shell)
        context.fillPath()

        // Inner warm golden amber dome
        context.saveGState()
        context.scaleBy(x: 0.92, y: 0.90)
        context.setFillColor(pal.shellMid)
        context.addPath(shell)
        context.fillPath()
        context.restoreGState()

        // Scutes, 3 Keels, & Ambient Lighting
        context.saveGState()
        context.addPath(shell)
        context.clip()

        // Hexagonal Scute Facets
        let scuteCenters: [CGPoint] = [
            CGPoint(x: -length * 0.24, y: 0),
            CGPoint(x: 0, y: 0),
            CGPoint(x: length * 0.20, y: 0),
            CGPoint(x: -length * 0.12, y: halfWidth * 0.48),
            CGPoint(x: -length * 0.12, y: -halfWidth * 0.48),
            CGPoint(x: length * 0.12, y: halfWidth * 0.48),
            CGPoint(x: length * 0.12, y: -halfWidth * 0.48),
        ]
        for (i, pt) in scuteCenters.enumerated() {
            let col = (i % 2 == 0) ? pal.scuteTone1 : pal.scuteTone2
            context.setFillColor(col)
            context.fillEllipse(in: CGRect(x: pt.x - length * 0.10, y: pt.y - halfWidth * 0.24, width: length * 0.20, height: halfWidth * 0.48))
        }

        // Subtle scute boundary seams
        context.setStrokeColor(pal.scuteLine)
        context.setLineWidth(length * 0.016)
        for pt in scuteCenters.prefix(3) {
            context.move(to: CGPoint(x: pt.x, y: -halfWidth * 0.65))
            context.addLine(to: CGPoint(x: pt.x, y: halfWidth * 0.65))
        }
        context.move(to: CGPoint(x: -length * 0.36, y: 0))
        context.addLine(to: CGPoint(x: length * 0.30, y: 0))
        context.strokePath()

        // 3 Tricarinate Keels (Center ridge + 2 Lateral ridges)
        context.setStrokeColor(pal.shellLight.copy(alpha: 0.70)!)
        context.setLineWidth(length * 0.024)
        // Central keel
        context.move(to: CGPoint(x: -length * 0.36, y: 0))
        context.addLine(to: CGPoint(x: length * 0.30, y: 0))
        // Lateral keels
        context.move(to: CGPoint(x: -length * 0.28, y: halfWidth * 0.40))
        context.addQuadCurve(to: CGPoint(x: length * 0.22, y: halfWidth * 0.35), control: CGPoint(x: 0, y: halfWidth * 0.45))
        context.move(to: CGPoint(x: -length * 0.28, y: -halfWidth * 0.40))
        context.addQuadCurve(to: CGPoint(x: length * 0.22, y: -halfWidth * 0.35), control: CGPoint(x: 0, y: -halfWidth * 0.45))
        context.strokePath()

        // Ambient flank shade (identik KoiArtwork)
        let fishAmbient = customFishAmbientStyle ?? PondLighting.fishAmbientStyle(for: theme)
        let shade = CGMutablePath()
        shade.move(to: CGPoint(x: -length * 0.42, y: -halfWidth * 0.35))
        shade.addQuadCurve(to: CGPoint(x: length * 0.42, y: -halfWidth * 0.35),
                           control: CGPoint(x: 0, y: -halfWidth * 0.95))
        shade.addLine(to: CGPoint(x: length * 0.42, y: -halfWidth))
        shade.addLine(to: CGPoint(x: -length * 0.42, y: -halfWidth))
        shade.closeSubpath()
        context.setFillColor(red: fishAmbient.shadeColor.0, green: fishAmbient.shadeColor.1,
                             blue: fishAmbient.shadeColor.2, alpha: fishAmbient.shadeAlpha * 0.85)
        context.addPath(shade)
        context.fillPath()

        // Warm sunlit dorsal ridge
        context.setFillColor(pal.shellLight.copy(alpha: 0.65)!)
        context.fillEllipse(in: CGRect(x: -length * 0.22, y: -halfWidth * 0.14, width: length * 0.44, height: halfWidth * 0.28))

        context.restoreGState()

        context.restoreGState()
    }

    // MARK: - Geometric Path Helpers

    private static func makeCarapacePath(length: CGFloat, halfWidth: CGFloat) -> CGPath {
        let shell = CGMutablePath()
        shell.move(to: CGPoint(x: length * 0.38, y: 0)) // Front neck notch
        shell.addCurve(to: CGPoint(x: length * 0.24, y: halfWidth * 0.76),
                       control1: CGPoint(x: length * 0.36, y: halfWidth * 0.35),
                       control2: CGPoint(x: length * 0.32, y: halfWidth * 0.65))
        shell.addCurve(to: CGPoint(x: -length * 0.12, y: halfWidth * 1.02),
                       control1: CGPoint(x: length * 0.12, y: halfWidth * 0.92),
                       control2: CGPoint(x: 0, y: halfWidth * 1.02))
        shell.addCurve(to: CGPoint(x: -length * 0.38, y: halfWidth * 0.72),
                       control1: CGPoint(x: -length * 0.26, y: halfWidth * 0.98),
                       control2: CGPoint(x: -length * 0.34, y: halfWidth * 0.88))
        shell.addCurve(to: CGPoint(x: -length * 0.48, y: 0), // Posterior tail notch
                       control1: CGPoint(x: -length * 0.44, y: halfWidth * 0.42),
                       control2: CGPoint(x: -length * 0.46, y: halfWidth * 0.15))
        shell.addCurve(to: CGPoint(x: -length * 0.38, y: -halfWidth * 0.72),
                       control1: CGPoint(x: -length * 0.46, y: -halfWidth * 0.15),
                       control2: CGPoint(x: -length * 0.44, y: -halfWidth * 0.42))
        shell.addCurve(to: CGPoint(x: -length * 0.12, y: -halfWidth * 1.02),
                       control1: CGPoint(x: -length * 0.34, y: -halfWidth * 0.88),
                       control2: CGPoint(x: -length * 0.26, y: -halfWidth * 0.98))
        shell.addCurve(to: CGPoint(x: length * 0.24, y: -halfWidth * 0.76),
                       control1: CGPoint(x: 0, y: -halfWidth * 1.02),
                       control2: CGPoint(x: length * 0.12, y: -halfWidth * 0.92))
        shell.addCurve(to: CGPoint(x: length * 0.38, y: 0),
                       control1: CGPoint(x: length * 0.32, y: -halfWidth * 0.65),
                       control2: CGPoint(x: length * 0.36, y: -halfWidth * 0.35))
        shell.closeSubpath()
        return shell
    }

    private static func makeHeadPath(headStart: CGFloat, length: CGFloat) -> CGPath {
        let head = CGMutablePath()
        head.move(to: CGPoint(x: headStart, y: length * 0.08))
        head.addCurve(to: CGPoint(x: headStart + length * 0.22, y: length * 0.11),
                      control1: CGPoint(x: headStart + length * 0.08, y: length * 0.09),
                      control2: CGPoint(x: headStart + length * 0.14, y: length * 0.11))
        head.addCurve(to: CGPoint(x: headStart + length * 0.34, y: 0),
                      control1: CGPoint(x: headStart + length * 0.29, y: length * 0.08),
                      control2: CGPoint(x: headStart + length * 0.33, y: length * 0.03))
        head.addCurve(to: CGPoint(x: headStart + length * 0.22, y: -length * 0.11),
                      control1: CGPoint(x: headStart + length * 0.33, y: -length * 0.03),
                      control2: CGPoint(x: headStart + length * 0.29, y: -length * 0.08))
        head.addCurve(to: CGPoint(x: headStart, y: -length * 0.08),
                      control1: CGPoint(x: headStart + length * 0.14, y: -length * 0.11),
                      control2: CGPoint(x: headStart + length * 0.08, y: -length * 0.09))
        head.closeSubpath()
        return head
    }

    private static func makeWebbedPaddlePath(side: CGFloat, length: CGFloat, halfWidth: CGFloat, flipperSweep: Double) -> CGPath {
        let pLen = length * 0.48
        let pWid = length * 0.22
        var t = CGAffineTransform(translationX: length * 0.18, y: side * halfWidth * 0.75)
        t = t.rotated(by: (side > 0 ? 1.02 : -1.02) + flipperSweep * side)
        let p = CGMutablePath()
        p.move(to: .zero, transform: t)
        p.addCurve(to: CGPoint(x: pLen * 0.70, y: side * pWid * 0.90),
                   control1: CGPoint(x: pLen * 0.25, y: side * pWid * 1.25),
                   control2: CGPoint(x: pLen * 0.50, y: side * pWid * 1.10), transform: t)
        p.addQuadCurve(to: CGPoint(x: pLen, y: side * pWid * 0.10),
                       control: CGPoint(x: pLen * 0.98, y: side * pWid * 0.55), transform: t)
        p.addCurve(to: CGPoint(x: pLen * 0.45, y: -side * pWid * 0.35),
                   control1: CGPoint(x: pLen * 0.85, y: -side * pWid * 0.15),
                   control2: CGPoint(x: pLen * 0.65, y: -side * pWid * 0.35), transform: t)
        p.closeSubpath()
        return p
    }

    private static func makeRearPaddlePath(side: CGFloat, length: CGFloat, halfWidth: CGFloat, rearSweep: Double) -> CGPath {
        let fLen = length * 0.36
        let fWid = length * 0.19
        var t = CGAffineTransform(translationX: -length * 0.28, y: side * halfWidth * 0.80)
        t = t.rotated(by: (side > 0 ? 2.40 : -2.40) + rearSweep * side)
        let p = CGMutablePath()
        p.addEllipse(in: CGRect(x: 0, y: -fWid * 0.5, width: fLen, height: fWid), transform: t)
        return p
    }

    private static func makeTailPath(length: CGFloat, strokeCycle: Double) -> CGPath {
        let tail = CGMutablePath()
        tail.move(to: CGPoint(x: -length * 0.42, y: -length * 0.05))
        tail.addQuadCurve(to: CGPoint(x: -length * 0.65 + CGFloat(strokeCycle * 2.5), y: 0),
                          control: CGPoint(x: -length * 0.52, y: CGFloat(strokeCycle * 1.2)))
        tail.addQuadCurve(to: CGPoint(x: -length * 0.42, y: length * 0.05),
                          control: CGPoint(x: -length * 0.52, y: CGFloat(-strokeCycle * 1.2)))
        tail.closeSubpath()
        return tail
    }
}
