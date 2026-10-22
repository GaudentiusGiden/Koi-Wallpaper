import CoreGraphics
import Foundation

/// Procedural pixel-art generator for pond insects:
/// dragonflies (capung), butterflies (kupu-kupu), and fireflies (kunang-kunang).
///
/// Designed specifically for the pond's coarse logical pixel grid (270-line target)
/// to match the authentic Nagomi pixel-art style of the koi, flora, and visitors.
public enum PondInsectArtwork {

    public static func drawInsects(_ insects: [PondInsect], in context: CGContext, time: Double) {
        guard !insects.isEmpty else { return }
        context.saveGState()

        for insect in insects where insect.opacity > 0.005 {
            draw(insect, in: context, time: time)
        }

        context.restoreGState()
    }

    public static func draw(_ insect: PondInsect, in context: CGContext, time: Double) {
        context.saveGState()
        context.translateBy(x: CGFloat(insect.position.x), y: CGFloat(insect.position.y))
        context.rotate(by: CGFloat(insect.heading))

        let op = CGFloat(insect.opacity)

        switch insect.type {
        case .dragonfly:
            drawPixelDragonfly(insect, in: context, opacity: op)
        case .butterfly:
            drawPixelButterfly(insect, in: context, opacity: op)
        case .firefly:
            drawPixelFirefly(insect, in: context, opacity: op)
        }

        context.restoreGState()
    }

    // MARK: - Pixel Dragonfly (Capung)

    private static func drawPixelDragonfly(_ insect: PondInsect, in context: CGContext, opacity: CGFloat) {
        let isEmerald = (insect.colorVariant == 1)
        // Primary jewel tone
        let primaryColor = isEmerald
            ? (r: CGFloat(0.08), g: CGFloat(0.74), b: CGFloat(0.52)) // Emerald teal
            : (r: CGFloat(0.12), g: CGFloat(0.60), b: CGFloat(0.92)) // Azure blue
        let darkColor = isEmerald
            ? (r: CGFloat(0.04), g: CGFloat(0.38), b: CGFloat(0.28))
            : (r: CGFloat(0.06), g: CGFloat(0.30), b: CGFloat(0.52))
        let highlightColor = isEmerald
            ? (r: CGFloat(0.45), g: CGFloat(0.94), b: CGFloat(0.78))
            : (r: CGFloat(0.52), g: CGFloat(0.85), b: CGFloat(1.00))

        // 1. Slender Segmented Abdomen (Tail stretching backwards along -X)
        // Enlarged to ~28pt length for clear pixel legibility
        let tailLength: CGFloat = 26.0
        let segments = 6
        let segStep = tailLength / CGFloat(segments)

        for i in 0..<segments {
            let segX = -3.5 - CGFloat(i) * segStep
            let segW = max(1.8, 3.4 - CGFloat(i) * 0.26)
            let col = (i % 2 == 0) ? primaryColor : darkColor
            context.setFillColor(red: col.r, green: col.g, blue: col.b, alpha: opacity * 0.95)
            context.fill(CGRect(x: segX - segStep, y: -segW * 0.5, width: segStep * 1.05, height: segW))

            // Subtle top highlight pixel line on each segment
            context.setFillColor(red: highlightColor.r, green: highlightColor.g, blue: highlightColor.b, alpha: opacity * 0.65)
            context.fill(CGRect(x: segX - segStep, y: segW * 0.5 - 0.9, width: segStep * 1.05, height: 0.9))
        }

        // Tail tip clasper spurs
        context.setFillColor(red: darkColor.r, green: darkColor.g, blue: darkColor.b, alpha: opacity * 0.90)
        context.fill(CGRect(x: -3.5 - tailLength - 2.0, y: 1.0, width: 2.0, height: 1.0))
        context.fill(CGRect(x: -3.5 - tailLength - 2.0, y: -2.0, width: 2.0, height: 1.0))

        // 2. Thorax (Mid-body block)
        context.setFillColor(red: darkColor.r, green: darkColor.g, blue: darkColor.b, alpha: opacity * 0.98)
        context.fill(CGRect(x: -3.5, y: -3.5, width: 7.0, height: 7.0))
        context.setFillColor(red: primaryColor.r, green: primaryColor.g, blue: primaryColor.b, alpha: opacity * 0.98)
        context.fill(CGRect(x: -2.0, y: -2.5, width: 4.5, height: 5.0))
        context.setFillColor(red: highlightColor.r, green: highlightColor.g, blue: highlightColor.b, alpha: opacity * 0.85)
        context.fill(CGRect(x: -1.0, y: -1.0, width: 2.5, height: 2.0))

        // 3. Head & Bulbous Compound Eyes
        context.setFillColor(red: darkColor.r * 0.8, green: darkColor.g * 0.8, blue: darkColor.b * 0.8, alpha: opacity * 0.98)
        context.fill(CGRect(x: 3.5, y: -2.8, width: 4.0, height: 5.6))

        // Large compound eyes on sides (chunky pixels)
        let eyeDark = (r: CGFloat(0.08), g: CGFloat(0.09), b: CGFloat(0.10))
        context.setFillColor(red: eyeDark.r, green: eyeDark.g, blue: eyeDark.b, alpha: opacity * 0.98)
        context.fill(CGRect(x: 4.2, y: 2.8, width: 3.8, height: 3.4))
        context.fill(CGRect(x: 4.2, y: -6.2, width: 3.8, height: 3.4))

        // White eye glint pixels
        context.setFillColor(red: 1.0, green: 1.0, blue: 1.0, alpha: opacity * 0.90)
        context.fill(CGRect(x: 6.2, y: 4.5, width: 1.4, height: 1.4))
        context.fill(CGRect(x: 6.2, y: -4.5, width: 1.4, height: 1.4))

        // 4. Four Large Chunky Pixel Wings with Rapid Shimmer
        let flutter = CGFloat(sin(insect.phase)) * 0.16
        let wingSpanFore: CGFloat = 21.0
        let wingSpanHind: CGFloat = 17.5

        func drawPixelWing(startX: CGFloat, angle: CGFloat, span: CGFloat, width: CGFloat) {
            context.saveGState()
            context.translateBy(x: startX, y: 0)
            context.rotate(by: angle)

            // Wing membrane (translucent pixel sheen)
            let wingRect = CGRect(x: -width * 0.35, y: 0, width: width, height: span)
            context.setFillColor(red: 0.88, green: 0.96, blue: 1.0, alpha: opacity * 0.52)
            context.fill(wingRect)

            // Wing dark leading edge & border
            context.setFillColor(red: primaryColor.r, green: primaryColor.g, blue: primaryColor.b, alpha: opacity * 0.88)
            context.fill(CGRect(x: -width * 0.35, y: 0, width: 1.2, height: span))
            context.fill(CGRect(x: width * 0.65 - 1.0, y: span * 0.25, width: 1.0, height: span * 0.70))
            context.fill(CGRect(x: -width * 0.35, y: span - 1.2, width: width, height: 1.2))

            // Cross veins (pixel bars)
            context.setFillColor(red: darkColor.r, green: darkColor.g, blue: darkColor.b, alpha: opacity * 0.65)
            context.fill(CGRect(x: -width * 0.35, y: span * 0.40, width: width * 0.8, height: 0.8))
            context.fill(CGRect(x: -width * 0.35, y: span * 0.70, width: width * 0.8, height: 0.8))

            // Pterostigma (distinct dark pixel mark near wing tip)
            context.setFillColor(red: darkColor.r * 0.7, green: darkColor.g * 0.7, blue: darkColor.b * 0.7, alpha: opacity * 0.95)
            context.fill(CGRect(x: -width * 0.35, y: span * 0.78, width: 2.2, height: 3.2))

            context.restoreGState()
        }

        // Left & Right Forewings
        drawPixelWing(startX: 1.0, angle: .pi * 0.48 + flutter, span: wingSpanFore, width: 5.2)
        drawPixelWing(startX: 1.0, angle: -.pi * 0.48 - flutter, span: wingSpanFore, width: 5.2)

        // Left & Right Hindwings
        drawPixelWing(startX: -2.5, angle: .pi * 0.62 + flutter * 0.8, span: wingSpanHind, width: 5.8)
        drawPixelWing(startX: -2.5, angle: -.pi * 0.62 - flutter * 0.8, span: wingSpanHind, width: 5.8)
    }

    // MARK: - Pixel Butterfly (Kupu-kupu)

    private static func drawPixelButterfly(_ insect: PondInsect, in context: CGContext, opacity: CGFloat) {
        let isYellow = (insect.colorVariant == 1)
        // Flapping vertical compression ratio
        let wingSpread = max(0.24, CGFloat(abs(cos(insect.phase))))

        // Vibrant pixel palettes
        let wingPrimary = isYellow
            ? (r: CGFloat(0.98), g: CGFloat(0.88), b: CGFloat(0.18)) // Radiant sulfur yellow
            : (r: CGFloat(0.96), g: CGFloat(0.42), b: CGFloat(0.08)) // Vivid monarch orange
        let wingSecondary = isYellow
            ? (r: CGFloat(0.90), g: CGFloat(0.72), b: CGFloat(0.08)) // Golden shade
            : (r: CGFloat(0.82), g: CGFloat(0.26), b: CGFloat(0.04)) // Deep terracotta
        let borderDark = (r: CGFloat(0.12), g: CGFloat(0.10), b: CGFloat(0.09))
        let accentDot = isYellow
            ? (r: CGFloat(0.35), g: CGFloat(0.88), b: CGFloat(0.92)) // Pastel blue rim dots
            : (r: CGFloat(1.00), g: CGFloat(1.00), b: CGFloat(0.95)) // White rim dots

        func drawWingPair(sideMultiplier: CGFloat) {
            context.saveGState()
            context.scaleBy(x: 1.0, y: sideMultiplier * wingSpread)

            // 1. Forewing (Large stepped pixel wing block)
            // Span ~21 pt, chord ~14 pt
            context.setFillColor(red: wingPrimary.r, green: wingPrimary.g, blue: wingPrimary.b, alpha: opacity * 0.96)
            let forePath = CGMutablePath()
            forePath.move(to: CGPoint(x: 0, y: 0))
            forePath.addLine(to: CGPoint(x: 6.0, y: 10.0))
            forePath.addLine(to: CGPoint(x: 7.5, y: 20.0))
            forePath.addLine(to: CGPoint(x: 4.0, y: 21.5))
            forePath.addLine(to: CGPoint(x: -3.0, y: 18.0))
            forePath.addLine(to: CGPoint(x: -5.0, y: 12.0))
            forePath.addLine(to: CGPoint(x: -2.0, y: 0))
            forePath.closeSubpath()
            context.addPath(forePath)
            context.fillPath()

            // Inner warm shade streak
            context.setFillColor(red: wingSecondary.r, green: wingSecondary.g, blue: wingSecondary.b, alpha: opacity * 0.90)
            context.fill(CGRect(x: 0.5, y: 3.5, width: 3.5, height: 10.0))
            context.fill(CGRect(x: -2.0, y: 4.0, width: 2.2, height: 7.5))

            // Bold black pixel border
            context.setFillColor(red: borderDark.r, green: borderDark.g, blue: borderDark.b, alpha: opacity * 0.95)
            // Leading edge
            context.fill(CGRect(x: 5.5, y: 11.0, width: 2.5, height: 9.5))
            // Outer apex & trailing margin
            context.fill(CGRect(x: -4.5, y: 18.5, width: 10.0, height: 3.0))
            context.fill(CGRect(x: -5.5, y: 12.0, width: 2.2, height: 7.0))

            // Internal vein lines
            context.fill(CGRect(x: 1.5, y: 2.0, width: 1.2, height: 12.0))
            context.fill(CGRect(x: -1.0, y: 2.0, width: 1.2, height: 10.0))

            // Bright pixel accent dots on outer rim
            context.setFillColor(red: accentDot.r, green: accentDot.g, blue: accentDot.b, alpha: opacity * 0.95)
            context.fill(CGRect(x: 5.0, y: 19.5, width: 1.8, height: 1.8))
            context.fill(CGRect(x: 1.0, y: 19.5, width: 1.8, height: 1.8))
            context.fill(CGRect(x: -3.0, y: 17.0, width: 1.8, height: 1.8))

            // 2. Hindwing (Rounded scalloped pixel block)
            // Span ~14 pt
            context.setFillColor(red: wingPrimary.r * 0.94, green: wingPrimary.g * 0.94, blue: wingPrimary.b * 0.94, alpha: opacity * 0.96)
            let hindPath = CGMutablePath()
            hindPath.move(to: CGPoint(x: -2.0, y: 0))
            hindPath.addLine(to: CGPoint(x: -4.0, y: 8.0))
            hindPath.addLine(to: CGPoint(x: -10.0, y: 13.5))
            hindPath.addLine(to: CGPoint(x: -14.0, y: 10.0))
            hindPath.addLine(to: CGPoint(x: -13.0, y: 3.0))
            hindPath.addLine(to: CGPoint(x: -5.0, y: 0))
            hindPath.closeSubpath()
            context.addPath(hindPath)
            context.fillPath()

            // Hindwing outer dark border
            context.setFillColor(red: borderDark.r, green: borderDark.g, blue: borderDark.b, alpha: opacity * 0.95)
            context.fill(CGRect(x: -13.5, y: 8.0, width: 5.0, height: 4.5))
            context.fill(CGRect(x: -14.5, y: 3.5, width: 2.5, height: 6.0))

            // Hindwing accent dot
            context.setFillColor(red: accentDot.r, green: accentDot.g, blue: accentDot.b, alpha: opacity * 0.95)
            context.fill(CGRect(x: -11.5, y: 10.5, width: 1.8, height: 1.8))

            context.restoreGState()
        }

        drawWingPair(sideMultiplier: 1.0)
        drawWingPair(sideMultiplier: -1.0)

        // 3. Central Body (Thorax & Abdomen)
        // Length ~18pt, width ~3.5pt
        context.setFillColor(red: 0.14, green: 0.12, blue: 0.10, alpha: opacity * 0.98)
        context.fill(CGRect(x: -8.0, y: -1.8, width: 13.0, height: 3.6))

        // Head
        context.fill(CGRect(x: 5.0, y: -1.6, width: 3.2, height: 3.2))

        // Antennae (Pixel whiskers spreading forward)
        context.setFillColor(red: 0.16, green: 0.14, blue: 0.12, alpha: opacity * 0.90)
        context.fill(CGRect(x: 7.5, y: 1.2, width: 2.5, height: 1.0))
        context.fill(CGRect(x: 9.5, y: 2.2, width: 2.2, height: 1.0))
        context.fill(CGRect(x: 11.2, y: 3.2, width: 1.6, height: 1.6)) // Antenna club

        context.fill(CGRect(x: 7.5, y: -2.2, width: 2.5, height: 1.0))
        context.fill(CGRect(x: 9.5, y: -3.2, width: 2.2, height: 1.0))
        context.fill(CGRect(x: 11.2, y: -4.8, width: 1.6, height: 1.6)) // Antenna club
    }

    // MARK: - Pixel Firefly (Kunang-kunang)

    private static func drawPixelFirefly(_ insect: PondInsect, in context: CGContext, opacity: CGFloat) {
        // Glowing pulse intensity (smooth breathing cycle)
        let pulse = CGFloat(pow(sin(insect.phase) * 0.5 + 0.5, 2.0))

        let lanternX: CGFloat = -7.5
        let lanternY: CGFloat = 0.0

        // 1. Soft Stepped Pixel Glow Halo (Authentic pixel-art concentric glow disks)
        // High-performance: zero gradient allocation, instantaneous rasterization on coarse grid!
        let outerR: CGFloat = 22.0 + 8.0 * pulse
        let midR: CGFloat = 13.5 + 4.5 * pulse
        let innerR: CGFloat = 7.0 + 2.5 * pulse

        // Outer ambient glow disk
        context.setFillColor(red: 0.40, green: 0.82, blue: 0.12, alpha: (0.13 * pulse + 0.02) * opacity)
        context.fillEllipse(in: CGRect(x: lanternX - outerR, y: lanternY - outerR, width: outerR * 2.0, height: outerR * 2.0))

        // Mid vibrant glow disk
        context.setFillColor(red: 0.58, green: 0.92, blue: 0.16, alpha: (0.26 * pulse + 0.06) * opacity)
        context.fillEllipse(in: CGRect(x: lanternX - midR, y: lanternY - midR, width: midR * 2.0, height: midR * 2.0))

        // Inner bright halo disk
        context.setFillColor(red: 0.78, green: 1.00, blue: 0.25, alpha: (0.45 * pulse + 0.14) * opacity)
        context.fillEllipse(in: CGRect(x: lanternX - innerR, y: lanternY - innerR, width: innerR * 2.0, height: innerR * 2.0))

        // 2. Beetle Body (Bold chunky silhouette: length ~17pt, width ~8.5pt)
        // Elytra (dark charcoal wing covers)
        context.setFillColor(red: 0.15, green: 0.13, blue: 0.12, alpha: opacity * 0.96)
        context.fill(CGRect(x: -7.0, y: -4.2, width: 10.5, height: 8.4))

        // Elytra center split line
        context.setFillColor(red: 0.28, green: 0.24, blue: 0.22, alpha: opacity * 0.90)
        context.fill(CGRect(x: -6.5, y: -0.6, width: 9.5, height: 1.2))

        // Pronotum (Vivid warm orange-red neck shield)
        context.setFillColor(red: 0.90, green: 0.38, blue: 0.12, alpha: opacity * 0.98)
        context.fill(CGRect(x: 3.5, y: -3.6, width: 4.2, height: 7.2))

        // Head (Charcoal black)
        context.setFillColor(red: 0.08, green: 0.07, blue: 0.06, alpha: opacity * 0.98)
        context.fill(CGRect(x: 7.7, y: -2.2, width: 3.0, height: 4.4))

        // Antennae
        context.setFillColor(red: 0.18, green: 0.16, blue: 0.14, alpha: opacity * 0.85)
        context.fill(CGRect(x: 9.5, y: 1.8, width: 3.5, height: 1.0))
        context.fill(CGRect(x: 9.5, y: -2.8, width: 3.5, height: 1.0))

        // 3. Luminous Abdominal Lantern Core (Bright glowing pixel block at tail)
        let coreR: CGFloat = 3.2 + 0.8 * pulse
        context.setFillColor(red: 0.96, green: 1.00, blue: 0.45, alpha: (0.88 + 0.12 * pulse) * opacity)
        context.fillEllipse(in: CGRect(x: lanternX - coreR, y: lanternY - coreR, width: coreR * 2.0, height: coreR * 2.0))
        // Center white hot pixel
        context.setFillColor(red: 1.00, green: 1.00, blue: 0.85, alpha: (0.95 * pulse + 0.05) * opacity)
        context.fill(CGRect(x: lanternX - 1.2, y: lanternY - 1.2, width: 2.4, height: 2.4))
    }
}
