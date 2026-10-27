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
            eyeCatchlight: CGColor
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
        }
    }

    public static let nagomiPalette = TurtlePalette(
        shellDark: CGColor(red: 0.16, green: 0.30, blue: 0.15, alpha: 1.0),      // Deep sumi jade edge
        shellMid: CGColor(red: 0.31, green: 0.53, blue: 0.25, alpha: 1.0),       // Radiant forest moss jade (#4E8740)
        shellLight: CGColor(red: 0.47, green: 0.74, blue: 0.35, alpha: 0.85),    // Soft sunlit dorsal ridge (#78BC58)
        scuteLine: CGColor(red: 0.14, green: 0.24, blue: 0.12, alpha: 0.45),     // Subtle translucent scute seam
        scuteTone1: CGColor(red: 0.25, green: 0.45, blue: 0.21, alpha: 0.92),    // Soft deep facet
        scuteTone2: CGColor(red: 0.37, green: 0.59, blue: 0.29, alpha: 0.92),    // Soft light facet
        skinDark: CGColor(red: 0.14, green: 0.25, blue: 0.11, alpha: 1.0),      // Soft boundary tone
        skinBase: CGColor(red: 0.38, green: 0.64, blue: 0.26, alpha: 1.0),      // Fresh vibrant spring moss green (#61A342)
        skinFin: CGColor(red: 0.42, green: 0.68, blue: 0.30, alpha: 0.68),       // Translucent webbed flipper matching koi fins
        skinHighlight: CGColor(red: 0.58, green: 0.84, blue: 0.42, alpha: 0.75), // Soft snout sheen
        eyeDark: CGColor(red: 0.045, green: 0.12, blue: 0.105, alpha: 1.0),      // Pure Japanese sumi ink (KoiArtwork.ink)
        eyeCatchlight: CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.90)    // Delicate catchlight glint
    )

    public static let ishigamePalette = TurtlePalette(
        shellDark: CGColor(red: 0.22, green: 0.15, blue: 0.08, alpha: 1.0),      // Dark bronze rim
        shellMid: CGColor(red: 0.53, green: 0.40, blue: 0.19, alpha: 1.0),       // Radiant warm golden amber (#876530)
        shellLight: CGColor(red: 0.75, green: 0.63, blue: 0.32, alpha: 0.85),    // Bright amber ridge (#BFA052)
        scuteLine: CGColor(red: 0.18, green: 0.12, blue: 0.06, alpha: 0.45),     // Subtle translucent seam
        scuteTone1: CGColor(red: 0.44, green: 0.33, blue: 0.16, alpha: 0.92),
        scuteTone2: CGColor(red: 0.62, green: 0.48, blue: 0.24, alpha: 0.92),
        skinDark: CGColor(red: 0.22, green: 0.28, blue: 0.14, alpha: 1.0),
        skinBase: CGColor(red: 0.42, green: 0.54, blue: 0.28, alpha: 1.0),
        skinFin: CGColor(red: 0.46, green: 0.58, blue: 0.32, alpha: 0.68),       // Translucent amber-olive fin
        skinHighlight: CGColor(red: 0.62, green: 0.74, blue: 0.42, alpha: 0.75),
        eyeDark: CGColor(red: 0.045, green: 0.12, blue: 0.105, alpha: 1.0),
        eyeCatchlight: CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.90)
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
        let halfWidth = length * 0.37
        let strokeCycle = sin(turtle.paddlePhase)
        let strokeCos = cos(turtle.paddlePhase)

        let flipperSweep = strokeCycle * 0.36 - 0.18
        let rearSweep = strokeCos * 0.20 + 0.12

        let shellRect = CGRect(x: -length * 0.44, y: -halfWidth, width: length * 0.88, height: halfWidth * 2)
        let headLen = length * 0.30
        let headWid = length * 0.22
        let headOriginX = length * 0.36 + CGFloat(strokeCycle * 1.8)
        let headRect = CGRect(x: headOriginX, y: -headWid * 0.5, width: headLen, height: headWid)

        let tailPath = CGMutablePath()
        tailPath.move(to: CGPoint(x: -length * 0.40, y: -length * 0.04))
        tailPath.addQuadCurve(to: CGPoint(x: -length * 0.62 + CGFloat(strokeCycle * 2.2), y: 0),
                              control: CGPoint(x: -length * 0.51, y: CGFloat(strokeCycle * 1.0)))
        tailPath.addQuadCurve(to: CGPoint(x: -length * 0.40, y: length * 0.04),
                              control: CGPoint(x: -length * 0.51, y: CGFloat(-strokeCycle * 1.0)))
        tailPath.closeSubpath()

        func flipperPath(side: CGFloat) -> CGPath {
            let pLen = length * 0.45
            let pWid = length * 0.19
            var t = CGAffineTransform(translationX: length * 0.20, y: side * halfWidth * 0.72)
            t = t.rotated(by: (side > 0 ? 1.05 : -1.05) + flipperSweep * side)
            let p = CGMutablePath()
            p.move(to: .zero, transform: t)
            p.addQuadCurve(to: CGPoint(x: pLen * 0.72, y: side * pWid * 0.80),
                           control: CGPoint(x: pLen * 0.30, y: side * pWid * 1.15), transform: t)
            p.addQuadCurve(to: CGPoint(x: pLen, y: 0),
                           control: CGPoint(x: pLen * 0.96, y: side * pWid * 0.40), transform: t)
            p.addQuadCurve(to: CGPoint(x: pLen * 0.48, y: -side * pWid * 0.35),
                           control: CGPoint(x: pLen * 0.78, y: -side * pWid * 0.28), transform: t)
            p.closeSubpath()
            return p
        }

        func rearPath(side: CGFloat) -> CGPath {
            let fLen = length * 0.33
            let fWid = length * 0.16
            var t = CGAffineTransform(translationX: -length * 0.28, y: side * halfWidth * 0.76)
            t = t.rotated(by: (side > 0 ? 2.45 : -2.45) + rearSweep * side)
            let p = CGMutablePath()
            p.addEllipse(in: CGRect(x: 0, y: -fWid * 0.5, width: fLen, height: fWid), transform: t)
            return p
        }

        // 1. Soft Penumbra (expanded silhouette)
        let pShell = CGPath(ellipseIn: shellRect.insetBy(dx: -length * 0.05, dy: -halfWidth * 0.05), transform: nil)
        context.setFillColor(red: shadowStyle.color.0, green: shadowStyle.color.1, blue: shadowStyle.color.2, alpha: shadowStyle.penumbraAlpha)
        context.addPath(pShell)
        context.addEllipse(in: headRect.insetBy(dx: -headLen * 0.05, dy: -headWid * 0.05))
        context.addPath(tailPath)
        context.addPath(flipperPath(side: -1))
        context.addPath(flipperPath(side: 1))
        context.addPath(rearPath(side: -1))
        context.addPath(rearPath(side: 1))
        context.fillPath()

        // 2. Umbra core silhouette
        context.setFillColor(red: shadowStyle.color.0, green: shadowStyle.color.1, blue: shadowStyle.color.2, alpha: shadowStyle.coreAlpha)
        context.addEllipse(in: shellRect)
        context.addEllipse(in: headRect)
        context.addPath(tailPath)
        context.addPath(flipperPath(side: -1))
        context.addPath(flipperPath(side: 1))
        context.addPath(rearPath(side: -1))
        context.addPath(rearPath(side: 1))
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
        let halfWidth = length * 0.37
        let strokeCycle = sin(turtle.paddlePhase)
        let strokeCos = cos(turtle.paddlePhase)

        let flipperSweep = strokeCycle * 0.36 - 0.18
        let rearSweep = strokeCos * 0.20 + 0.12

        let shellRect = CGRect(x: -length * 0.44, y: -halfWidth, width: length * 0.88, height: halfWidth * 2)
        let headLen = length * 0.30
        let headWid = length * 0.22
        let headOriginX = length * 0.36 + CGFloat(strokeCycle * 1.8)
        let headRect = CGRect(x: headOriginX, y: -headWid * 0.5, width: headLen, height: headWid)

        let tailPath = CGMutablePath()
        tailPath.move(to: CGPoint(x: -length * 0.40, y: -length * 0.04))
        tailPath.addQuadCurve(to: CGPoint(x: -length * 0.62 + CGFloat(strokeCycle * 2.2), y: 0),
                              control: CGPoint(x: -length * 0.51, y: CGFloat(strokeCycle * 1.0)))
        tailPath.addQuadCurve(to: CGPoint(x: -length * 0.40, y: length * 0.04),
                              control: CGPoint(x: -length * 0.51, y: CGFloat(-strokeCycle * 1.0)))
        tailPath.closeSubpath()

        func flipperPath(side: CGFloat) -> CGPath {
            let pLen = length * 0.45
            let pWid = length * 0.19
            var t = CGAffineTransform(translationX: length * 0.20, y: side * halfWidth * 0.72)
            t = t.rotated(by: (side > 0 ? 1.05 : -1.05) + flipperSweep * side)
            let p = CGMutablePath()
            p.move(to: .zero, transform: t)
            p.addQuadCurve(to: CGPoint(x: pLen * 0.72, y: side * pWid * 0.80),
                           control: CGPoint(x: pLen * 0.30, y: side * pWid * 1.15), transform: t)
            p.addQuadCurve(to: CGPoint(x: pLen, y: 0),
                           control: CGPoint(x: pLen * 0.96, y: side * pWid * 0.40), transform: t)
            p.addQuadCurve(to: CGPoint(x: pLen * 0.48, y: -side * pWid * 0.35),
                           control: CGPoint(x: pLen * 0.78, y: -side * pWid * 0.28), transform: t)
            p.closeSubpath()
            return p
        }

        func rearPath(side: CGFloat) -> CGPath {
            let fLen = length * 0.33
            let fWid = length * 0.16
            var t = CGAffineTransform(translationX: -length * 0.28, y: side * halfWidth * 0.76)
            t = t.rotated(by: (side > 0 ? 2.45 : -2.45) + rearSweep * side)
            let p = CGMutablePath()
            p.addEllipse(in: CGRect(x: 0, y: -fWid * 0.5, width: fLen, height: fWid), transform: t)
            return p
        }

        // 1. Translucent webbed paddles & tail (no harsh strokes!)
        context.setFillColor(pal.skinFin)
        context.addPath(flipperPath(side: -1))
        context.addPath(flipperPath(side: 1))
        context.addPath(rearPath(side: -1))
        context.addPath(rearPath(side: 1))
        context.fillPath()

        context.setFillColor(pal.skinBase)
        context.addPath(tailPath)
        context.fillPath()

        // 2. Head & Ink eyes (smooth organic dome without dark outer strokes)
        context.setFillColor(pal.skinBase)
        context.fillEllipse(in: headRect)

        context.setFillColor(pal.skinHighlight)
        context.fillEllipse(in: CGRect(x: headOriginX + headLen * 0.35, y: -headWid * 0.22, width: headLen * 0.45, height: headWid * 0.44))

        let eyeSize = length * 0.036
        context.setFillColor(pal.eyeDark)
        for side: CGFloat in [-1, 1] {
            let eyeX = headOriginX + headLen * 0.58
            let eyeY = side * headWid * 0.32 - eyeSize / 2
            context.fillEllipse(in: CGRect(x: eyeX, y: eyeY, width: eyeSize, height: eyeSize))
            context.setFillColor(pal.eyeCatchlight)
            context.fillEllipse(in: CGRect(x: eyeX + eyeSize * 0.20, y: eyeY + eyeSize * 0.20, width: eyeSize * 0.40, height: eyeSize * 0.40))
            context.setFillColor(pal.eyeDark)
        }

        // 3. Carapace (Shell) - Organic Dome without harsh cartoon strokes!
        context.setFillColor(pal.shellDark)
        context.fillEllipse(in: shellRect)

        let domeRect = shellRect.insetBy(dx: length * 0.045, dy: halfWidth * 0.055)
        context.setFillColor(pal.shellMid)
        context.fillEllipse(in: domeRect)

        // Clipped scutes & dynamic ambient lighting
        context.saveGState()
        context.addEllipse(in: domeRect)
        context.clip()

        // Soft organic scute facets
        let scuteCenters: [CGPoint] = [
            CGPoint(x: -length * 0.22, y: 0),
            CGPoint(x: 0, y: 0),
            CGPoint(x: length * 0.22, y: 0),
            CGPoint(x: -length * 0.12, y: halfWidth * 0.46),
            CGPoint(x: -length * 0.12, y: -halfWidth * 0.46),
            CGPoint(x: length * 0.12, y: halfWidth * 0.46),
            CGPoint(x: length * 0.12, y: -halfWidth * 0.46),
        ]
        let scuteW = length * 0.18
        let scuteH = halfWidth * 0.48

        for (i, c) in scuteCenters.enumerated() {
            let facetRect = CGRect(x: c.x - scuteW * 0.5, y: c.y - scuteH * 0.5, width: scuteW, height: scuteH)
            let color = (i % 2 == 0) ? pal.scuteTone1 : pal.scuteTone2
            context.setFillColor(color)
            context.fillEllipse(in: facetRect)
        }

        // Subtle soft scute seams (delicate alpha, not harsh black lines)
        context.setStrokeColor(pal.scuteLine)
        context.setLineWidth(length * 0.016)
        for c in scuteCenters.prefix(3) {
            context.move(to: CGPoint(x: c.x, y: -halfWidth * 0.65))
            context.addLine(to: CGPoint(x: c.x, y: halfWidth * 0.65))
        }
        context.move(to: CGPoint(x: -length * 0.35, y: 0))
        context.addLine(to: CGPoint(x: length * 0.35, y: 0))
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

        // Soft dorsal spine highlight
        context.setStrokeColor(red: fishAmbient.highlightColor.0, green: fishAmbient.highlightColor.1,
                               blue: fishAmbient.highlightColor.2, alpha: fishAmbient.highlightAlpha * 0.90)
        context.setLineWidth(length * 0.032)
        context.move(to: CGPoint(x: -length * 0.28, y: halfWidth * 0.08))
        context.addQuadCurve(to: CGPoint(x: length * 0.28, y: halfWidth * 0.08),
                             control: CGPoint(x: 0, y: halfWidth * 0.16))
        context.strokePath()

        // Warm sunlit ridge
        context.setFillColor(pal.shellLight)
        context.fillEllipse(in: CGRect(x: -length * 0.24, y: -halfWidth * 0.12, width: length * 0.48, height: halfWidth * 0.24))

        context.restoreGState()

        context.restoreGState()
    }
}
