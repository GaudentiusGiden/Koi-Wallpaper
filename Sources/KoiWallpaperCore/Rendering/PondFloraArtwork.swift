import CoreGraphics
import Foundation

/// Six original shoreline vignettes. Cached separately so ambient sway only moves
/// small textures; the open swimming area is never filled with a repeating border.
enum PondFloraArtwork {
    static let anchors: [CGPoint] = [
        CGPoint(x: 0.035, y: 0.81), CGPoint(x: 0.065, y: 0.08),
        CGPoint(x: 0.965, y: 0.94), CGPoint(x: 0.945, y: 0.20),
        CGPoint(x: 0.49, y: 1.015), CGPoint(x: 0.57, y: -0.035)
    ]
    static func localBounds(shortSide: CGFloat) -> CGRect {
        CGRect(x: -shortSide * 0.30, y: -shortSide * 0.34, width: shortSide * 0.60, height: shortSide * 0.68)
    }
    static func drawCluster(_ index: Int, in context: CGContext, shortSide: CGFloat, theme: PondTheme = .day) {
        context.saveGState()
        context.scaleBy(x: shortSide * 1.3, y: shortSide * 1.3)
        let mirror: CGFloat = index == 2 || index == 3 ? -1 : 1
        context.scaleBy(x: mirror, y: 1)
        var rng = SeededRandomNumberGenerator(seed: UInt64(6100 + index * 317))
        let palette = theme.renderPalette
        func random(_ range: ClosedRange<Double>) -> CGFloat { CGFloat(Double.random(in: range, using: &rng)) }

        // Submerged stems and floating duckweed, with denser roots along the shore.
        let count = index < 4 ? 100 : 38
        for i in 0..<count {
            let y = random(-0.24...0.24)
            let x = random(-0.065...0.095) + sin(y * 27 + CGFloat(index)) * 0.023
            let length = random(0.012...0.035)
            context.setStrokeColor(red: palette.stems.red, green: palette.stems.green,
                                   blue: palette.stems.blue, alpha: 0.45)
            context.setLineWidth(0.002)
            context.move(to: CGPoint(x: x - 0.014, y: y - length))
            context.addQuadCurve(to: CGPoint(x: x + 0.010, y: y + length), control: CGPoint(x: x - 0.02, y: y))
            context.strokePath()
            let radius = random(0.0035...0.0085)
            let shadowStyle = PondLighting.shadowStyle(for: theme)
            context.setFillColor(red: shadowStyle.color.0, green: shadowStyle.color.1, blue: shadowStyle.color.2, alpha: shadowStyle.smallFishAlpha)
            let shadow = PondLighting.shadowOffset(distance: 0.024)
            context.fillEllipse(in: CGRect(x: x + shadow.x * mirror, y: y + shadow.y,
                                          width: radius * 3.0, height: radius * 2.4))
            let col = palette.greens[i % palette.greens.count]
            context.setFillColor(red: col.red, green: col.green, blue: col.blue, alpha: 1)
            context.fillEllipse(in: CGRect(x: x, y: y, width: radius * 2.1, height: radius * 1.5))
            context.fillEllipse(in: CGRect(x: x - radius, y: y + radius * 0.8, width: radius * 1.4, height: radius * 1.8))
            if i % 3 == 0 {
                context.setFillColor(red: palette.duckweed.red, green: palette.duckweed.green,
                                     blue: palette.duckweed.blue, alpha: 1)
                context.fill(CGRect(x: x, y: y + radius, width: radius * 0.65, height: radius * 0.65))
            }
        }
        // 3 + 3 + 3 + 3 + 2 + 2 = 16 pads; the four corner clusters carry flowers.
        let pads: [(CGFloat, CGFloat, CGFloat)]
        switch index {
        case 0: pads = [(-0.025, 0.15, 0.092), (0.070, 0.005, 0.107), (-0.015, -0.145, 0.079)]
        case 1: pads = [(-0.025, 0.11, 0.087), (0.055, -0.020, 0.095), (-0.025, -0.160, 0.067)]
        case 2: pads = [(-0.035, 0.135, 0.090), (0.050, -0.025, 0.103), (-0.025, -0.160, 0.066)]
        case 3: pads = [(-0.025, 0.14, 0.082), (0.060, -0.015, 0.108), (-0.030, -0.17, 0.075)]
        case 4: pads = [(-0.045, 0.005, 0.078), (0.085, 0.040, 0.060)]
        default: pads = [(-0.055, 0.005, 0.076), (0.070, -0.020, 0.055)]
        }
        for (i, p) in pads.enumerated() {
            drawPad(in: context, center: CGPoint(x: p.0, y: p.1), radius: p.2,
                    angle: CGFloat(index) * 1.3 + CGFloat(i) * 2.1, variant: index + i,
                    flower: i == 1 && index < 4, mirror: mirror, theme: theme)
        }
        context.restoreGState()
    }

    static func drawCluster(_ index: Int, in context: CGContext, shortSide: CGFloat, phase: TimeOfDayPhase) {
        drawCluster(index, in: context, shortSide: shortSide, theme: phase.theme)
    }

    private static func drawPad(in context: CGContext, center: CGPoint, radius: CGFloat,
                                angle: CGFloat, variant: Int, flower: Bool, mirror: CGFloat, theme: PondTheme = .day) {
        let palette = theme.renderPalette
        context.saveGState()
        context.translateBy(x: center.x, y: center.y)
        context.rotate(by: angle)
        context.scaleBy(x: 1, y: 0.92)
        let leaf = CGMutablePath()
        leaf.move(to: .zero)
        for i in 0...40 {
            let theta = 0.19 + CGFloat(i) / 40 * (.pi * 2 - 0.42)
            let r = radius * (1 + sin(CGFloat(i) * 2.4 + CGFloat(variant)) * 0.018)
            leaf.addLine(to: CGPoint(x: cos(theta) * r, y: sin(theta) * r))
        }
        leaf.closeSubpath()
        context.saveGState()
        // Undo the local leaf rotation/mirroring for a consistent world light direction.
        let offset = PondLighting.shadowOffset(distance: radius * 0.44)
        let dx = offset.x * mirror
        let dy = offset.y
        context.translateBy(x: cos(angle) * dx + sin(angle) * dy,
                            y: (-sin(angle) * dx + cos(angle) * dy) / 0.92)
        let shadowStyle = PondLighting.shadowStyle(for: theme)
        // 1. Soft penumbra stepped softening rim
        context.saveGState()
        context.scaleBy(x: 1.08, y: 1.08)
        context.setFillColor(red: shadowStyle.color.0, green: shadowStyle.color.1, blue: shadowStyle.color.2, alpha: shadowStyle.penumbraAlpha)
        context.addPath(leaf)
        context.fillPath()
        context.restoreGState()

        // 2. Core umbra
        context.setFillColor(red: shadowStyle.color.0, green: shadowStyle.color.1, blue: shadowStyle.color.2, alpha: shadowStyle.coreAlpha)
        context.addPath(leaf)
        context.fillPath()
        context.restoreGState()

        let shade = CGFloat(variant % 3) * 0.015
        context.setFillColor(red: palette.leafBase.red + shade,
                             green: palette.leafBase.green + shade,
                             blue: palette.leafBase.blue + shade, alpha: 1)
        context.addPath(leaf)
        context.fillPath()
        context.saveGState()
        context.addPath(leaf)
        context.clip()
        context.setFillColor(red: palette.leafHighlight.red + shade,
                             green: palette.leafHighlight.green + shade,
                             blue: palette.leafHighlight.blue + shade, alpha: 1)
        context.fillEllipse(in: CGRect(x: -radius * 1.03, y: -radius * 0.65, width: radius * 1.65, height: radius * 1.7))
        context.setFillColor(red: palette.leafGlaze.color.red,
                             green: palette.leafGlaze.color.green,
                             blue: palette.leafGlaze.color.blue, alpha: palette.leafGlaze.alpha)
        context.fillEllipse(in: CGRect(x: -radius * 0.85, y: radius * 0.10, width: radius * 0.7, height: radius * 0.5))
        context.restoreGState()
        context.setStrokeColor(red: palette.leafVeins.color.red,
                               green: palette.leafVeins.color.green,
                               blue: palette.leafVeins.color.blue, alpha: palette.leafVeins.alpha)
        context.setLineWidth(radius * 0.035)
        for i in 0..<7 {
            let theta = 0.45 + CGFloat(i) * (2 * .pi - 0.9) / 6
            let end = CGPoint(x: cos(theta) * radius * 0.90, y: sin(theta) * radius * 0.90)
            context.move(to: .zero)
            context.addLine(to: end)
            if i % 2 == 0 {
                context.move(to: CGPoint(x: end.x * 0.55, y: end.y * 0.55))
                context.addLine(to: CGPoint(x: cos(theta + 0.20) * radius * 0.78, y: sin(theta + 0.20) * radius * 0.78))
            }
        }
        context.strokePath()
        // Short, broken rim highlights use the shared theme palette.
        context.setStrokeColor(red: palette.leafRim.color.red,
                               green: palette.leafRim.color.green,
                               blue: palette.leafRim.color.blue, alpha: palette.leafRim.alpha)
        context.setLineWidth(radius * 0.022)
        context.addArc(center: .zero, radius: radius * 0.985, startAngle: 1.2, endAngle: 2.7, clockwise: false)
        context.strokePath()
        if flower { drawFlower(in: context, radius: radius * 0.32, theme: theme) }
        context.restoreGState()
    }

    private static func drawFlower(in context: CGContext, radius: CGFloat, theme: PondTheme = .day) {
        let palette = theme.renderPalette
        for tier in 0..<2 {
            let petal = CGMutablePath()
            for i in 0..<16 {
                let theta = CGFloat(i) * .pi / 8 + CGFloat(tier) * 0.32
                let r = radius * (i % 2 == 0 ? (tier == 0 ? 1 : 0.68) : 0.26)
                let p = CGPoint(x: cos(theta) * r, y: sin(theta) * r)
                if i == 0 { petal.move(to: p) } else { petal.addLine(to: p) }
            }
            petal.closeSubpath()
            let petalColor = tier == 0 ? palette.flowerPetal : palette.flowerInnerPetal
            context.setFillColor(red: petalColor.red, green: petalColor.green, blue: petalColor.blue, alpha: 1)
            context.addPath(petal)
            context.fillPath()
        }
        context.setFillColor(red: palette.flowerCenter.red, green: palette.flowerCenter.green,
                             blue: palette.flowerCenter.blue, alpha: 1)
        context.fill(CGRect(x: -radius * 0.20, y: -radius * 0.20, width: radius * 0.40, height: radius * 0.40))
        context.setFillColor(red: palette.flowerCore.red, green: palette.flowerCore.green,
                             blue: palette.flowerCore.blue, alpha: 1)
        context.fill(CGRect(x: -radius * 0.09, y: -radius * 0.09, width: radius * 0.18, height: radius * 0.18))
    }
}
