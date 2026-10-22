import CoreGraphics
import Foundation

/// Procedural coarse pixel-art generator for the pond frog (katak teratai).
///
/// Designed specifically for the pond's coarse logical pixel grid (270-line target)
/// to match the authentic Nagomi pixel-art aesthetic of the koi fish, flora, and visitors.
public enum PondFrogArtwork {

    public static func draw(_ frog: PondFrog, in context: CGContext, time: Double) {
        guard frog.isVisible else { return }

        context.saveGState()

        // Base enlargement factor: ~2.40x for an unmistakably readable hero character (~46pt length)
        // Perfectly proportioned on the ~150pt lily pad: prominent, bold, yet natural and harmonious.
        let baseScale: CGFloat = 2.40

        // 1. Drop Shadow (Projected onto the lily pad or water surface)
        let altitude = frog.altitude
        let shadowScale = max(0.35, 1.0 - altitude / 48.0) * baseScale
        let shadowAlpha = max(0.12, 0.44 - altitude * 0.008)

        context.saveGState()
        // Shadow stays at ground coordinate with slight light offset
        context.translateBy(x: frog.position.x + 4.5, y: frog.position.y - 4.5)
        context.scaleBy(x: shadowScale, y: shadowScale * 0.82)
        context.setFillColor(red: 0.04, green: 0.08, blue: 0.05, alpha: shadowAlpha)
        context.fillEllipse(in: CGRect(x: -10.0, y: -8.5, width: 20.0, height: 17.0))
        context.restoreGState()

        // 2. Elevated Frog Body (Shifted vertically by altitude)
        context.saveGState()
        context.translateBy(x: frog.position.x, y: frog.position.y + altitude)
        context.rotate(by: CGFloat(frog.heading))
        context.scaleBy(x: frog.scaleX * baseScale, y: frog.scaleY * baseScale)

        if frog.state == .jumpingOut || frog.state == .jumpingIn {
            drawLeapingFrog(frog, in: context)
        } else {
            drawPerchedFrog(frog, in: context)
        }

        context.restoreGState()
        context.restoreGState()
    }

    // MARK: - Perched Frog (Hinggap di Teratai)

    private static func drawPerchedFrog(_ frog: PondFrog, in context: CGContext) {
        let palette = frogPalette(for: frog.variant)

        // 0. Dark Silhouette Base (Separates frog cleanly from the green lily pad!)
        context.setFillColor(red: palette.darkGreen.r * 0.7, green: palette.darkGreen.g * 0.7, blue: palette.darkGreen.b * 0.7, alpha: 0.95)
        // Body base outline
        context.fillEllipse(in: CGRect(x: -7.8, y: -6.8, width: 15.6, height: 13.6))
        // Thigh base outlines
        context.fill(CGRect(x: -8.2, y: 5.0, width: 8.5, height: 5.2))
        context.fill(CGRect(x: -8.2, y: -10.2, width: 8.5, height: 5.2))

        // 1. Hind Legs (Folded Z-shape tightly at sides - the iconic frog silhouette!)
        context.setFillColor(red: palette.darkGreen.r, green: palette.darkGreen.g, blue: palette.darkGreen.b, alpha: 1.0)
        // Left folded thigh & shin
        context.fill(CGRect(x: -7.6, y: 5.4, width: 7.4, height: 4.4))
        context.fill(CGRect(x: -4.6, y: 8.0, width: 6.0, height: 3.4))
        // Right folded thigh & shin
        context.fill(CGRect(x: -7.6, y: -9.8, width: 7.4, height: 4.4))
        context.fill(CGRect(x: -4.6, y: -11.4, width: 6.0, height: 3.4))

        // Vibrant thigh muscle base
        context.setFillColor(red: palette.body.r, green: palette.body.g, blue: palette.body.b, alpha: 1.0)
        context.fill(CGRect(x: -6.5, y: 5.8, width: 5.5, height: 3.2))
        context.fill(CGRect(x: -6.5, y: -9.0, width: 5.5, height: 3.2))

        // UNMISTAKABLE FROG HIGHLIGHT: Bright curved highlight on the tops of both bent knees!
        context.setFillColor(red: palette.highlight.r, green: palette.highlight.g, blue: palette.highlight.b, alpha: 1.0)
        context.fill(CGRect(x: -4.0, y: 8.6, width: 4.6, height: 1.6))
        context.fill(CGRect(x: -4.0, y: -10.2, width: 4.6, height: 1.6))

        // Splayed webbed feet with 3 long spread pixel toes resting on leaf
        // Left toes
        context.fill(CGRect(x: 1.2, y: 7.6, width: 2.4, height: 1.5))
        context.fill(CGRect(x: 3.0, y: 9.6, width: 2.4, height: 1.5))
        context.fill(CGRect(x: 0.6, y: 11.6, width: 2.4, height: 1.5))
        // Right toes
        context.fill(CGRect(x: 1.2, y: -9.1, width: 2.4, height: 1.5))
        context.fill(CGRect(x: 3.0, y: -11.1, width: 2.4, height: 1.5))
        context.fill(CGRect(x: 0.6, y: -13.1, width: 2.4, height: 1.5))

        // 2. Main Dorsal Body (Plump pear silhouette)
        context.setFillColor(red: palette.body.r, green: palette.body.g, blue: palette.body.b, alpha: 1.0)
        context.fillEllipse(in: CGRect(x: -7.2, y: -6.2, width: 14.4, height: 12.4))

        // Dark contour shading around lower back/flanks
        context.setFillColor(red: palette.darkGreen.r, green: palette.darkGreen.g, blue: palette.darkGreen.b, alpha: 0.88)
        context.fill(CGRect(x: -7.4, y: -4.6, width: 2.8, height: 9.2))

        // Variant-specific dorsal markings & bright spine highlights
        drawDorsalMarkings(frog, in: context, palette: palette)

        // 3. Front Arms (Planted forward supporting the frog's weight)
        context.setFillColor(red: palette.body.r, green: palette.body.g, blue: palette.body.b, alpha: 1.0)
        context.fill(CGRect(x: 1.6, y: 4.8, width: 3.8, height: 2.8))
        context.fill(CGRect(x: 1.6, y: -7.6, width: 3.8, height: 2.8))
        // Toe pads on leaf
        context.setFillColor(red: palette.highlight.r, green: palette.highlight.g, blue: palette.highlight.b, alpha: 1.0)
        context.fill(CGRect(x: 5.0, y: 5.8, width: 2.0, height: 2.0))
        context.fill(CGRect(x: 5.0, y: -7.8, width: 2.0, height: 2.0))

        // 4. Head & Snout with Wide Frog Jawline
        context.setFillColor(red: palette.body.r, green: palette.body.g, blue: palette.body.b, alpha: 1.0)
        context.fill(CGRect(x: 3.0, y: -4.8, width: 5.8, height: 9.6))
        context.fill(CGRect(x: 7.8, y: -3.0, width: 2.8, height: 6.0))

        // Characteristic Dark Eye Mask Stripe running from nostril through eye to shoulder
        context.setFillColor(red: palette.mask.r, green: palette.mask.g, blue: palette.mask.b, alpha: 0.95)
        context.fill(CGRect(x: 2.2, y: 3.8, width: 5.8, height: 1.8))
        context.fill(CGRect(x: 2.2, y: -5.6, width: 5.8, height: 1.8))

        // Wide mouth seam line
        context.fill(CGRect(x: 7.2, y: -2.6, width: 2.4, height: 0.9))
        context.fill(CGRect(x: 7.2, y: 1.7, width: 2.4, height: 0.9))

        // Nostril dots
        context.fill(CGRect(x: 9.2, y: 1.0, width: 1.1, height: 1.1))
        context.fill(CGRect(x: 9.2, y: -2.1, width: 1.1, height: 1.1))

        // 5. Pale Cream Underbelly & Throat Sac (High-contrast focal point)
        drawVocalSac(frog, in: context, palette: palette)

        // 6. Large Bulbous Frog Eyes (The definitive frog feature that pops!)
        drawFrogEyes(frog, in: context, palette: palette)

        // 7. Lotus Petal Hat (.lotusPetal accessory perched like a jaunty beret)
        if frog.variant == .lotusPetal {
            drawLotusPetalHat(in: context)
        }
    }

    // MARK: - Leaping Frog (Sedang Melompat di Udara)

    private static func drawLeapingFrog(_ frog: PondFrog, in context: CGContext) {
        let palette = frogPalette(for: frog.variant)

        // 1. Extended Hind Legs (Fully stretched backwards in mid-air!)
        context.setFillColor(red: palette.darkGreen.r, green: palette.darkGreen.g, blue: palette.darkGreen.b, alpha: 1.0)
        // Thighs reaching back
        context.fill(CGRect(x: -13.0, y: 3.5, width: 7.8, height: 3.5))
        context.fill(CGRect(x: -13.0, y: -7.0, width: 7.8, height: 3.5))
        // Shins extending further back
        context.fill(CGRect(x: -20.0, y: 4.5, width: 7.8, height: 2.6))
        context.fill(CGRect(x: -20.0, y: -7.1, width: 7.8, height: 2.6))

        // Splayed webbed feet pointing rearward
        context.setFillColor(red: palette.highlight.r, green: palette.highlight.g, blue: palette.highlight.b, alpha: 1.0)
        // Left webbed toes
        context.fill(CGRect(x: -26.5, y: 3.5, width: 6.8, height: 1.7))
        context.fill(CGRect(x: -25.5, y: 5.7, width: 5.8, height: 1.7))
        context.fill(CGRect(x: -24.5, y: 7.9, width: 4.8, height: 1.7))
        // Right webbed toes
        context.fill(CGRect(x: -26.5, y: -5.2, width: 6.8, height: 1.7))
        context.fill(CGRect(x: -25.5, y: -7.4, width: 5.8, height: 1.7))
        context.fill(CGRect(x: -24.5, y: -9.6, width: 4.8, height: 1.7))

        // 2. Streamlined Torso
        context.setFillColor(red: palette.body.r, green: palette.body.g, blue: palette.body.b, alpha: 1.0)
        context.fillEllipse(in: CGRect(x: -7.0, y: -5.2, width: 15.2, height: 10.4))

        // Spinal highlight
        context.setFillColor(red: palette.highlight.r, green: palette.highlight.g, blue: palette.highlight.b, alpha: 0.95)
        context.fill(CGRect(x: -5.2, y: -0.8, width: 8.6, height: 1.6))

        // 3. Reaching Front Arms (Streamlined forward)
        context.setFillColor(red: palette.body.r, green: palette.body.g, blue: palette.body.b, alpha: 1.0)
        context.fill(CGRect(x: 4.6, y: 3.8, width: 6.6, height: 2.4))
        context.fill(CGRect(x: 4.6, y: -6.2, width: 6.6, height: 2.4))
        context.setFillColor(red: palette.highlight.r, green: palette.highlight.g, blue: palette.highlight.b, alpha: 1.0)
        context.fill(CGRect(x: 10.2, y: 4.6, width: 2.2, height: 2.0))
        context.fill(CGRect(x: 10.2, y: -6.6, width: 2.2, height: 2.0))

        // 4. Head & Snout
        context.setFillColor(red: palette.body.r, green: palette.body.g, blue: palette.body.b, alpha: 1.0)
        context.fill(CGRect(x: 4.2, y: -4.0, width: 5.8, height: 8.0))
        context.fill(CGRect(x: 8.6, y: -2.4, width: 3.0, height: 4.8))

        // Mask streak
        context.setFillColor(red: palette.mask.r, green: palette.mask.g, blue: palette.mask.b, alpha: 0.90)
        context.fill(CGRect(x: 3.6, y: 3.3, width: 5.4, height: 1.5))
        context.fill(CGRect(x: 3.6, y: -4.8, width: 5.4, height: 1.5))

        // Eyes (Alert and open forward)
        drawFrogEyes(frog, in: context, palette: palette)

        if frog.variant == .lotusPetal {
            drawLotusPetalHat(in: context)
        }
    }

    // MARK: - Dorsal Markings & Highlights

    private static func drawDorsalMarkings(_ frog: PondFrog, in context: CGContext, palette: FrogPalette) {
        switch frog.variant {
        case .classicGreen, .lotusPetal:
            // High-contrast bright lime spinal ridge + 2 scapular V-angles
            context.setFillColor(red: palette.highlight.r, green: palette.highlight.g, blue: palette.highlight.b, alpha: 0.98)
            // Center spinal stripe
            context.fill(CGRect(x: -5.4, y: -1.0, width: 7.8, height: 2.0))
            // Shoulder chevron highlights
            context.fill(CGRect(x: 0.2, y: 2.0, width: 2.4, height: 1.4))
            context.fill(CGRect(x: 0.2, y: -3.4, width: 2.4, height: 1.4))

            // Dark camouflage spots
            context.setFillColor(red: palette.darkGreen.r, green: palette.darkGreen.g, blue: palette.darkGreen.b, alpha: 0.88)
            context.fill(CGRect(x: -3.6, y: 2.2, width: 2.6, height: 2.4))
            context.fill(CGRect(x: -3.6, y: -4.6, width: 2.6, height: 2.4))

        case .mossySpotted:
            // Tono-gaeru: Camouflage dark spots + dual golden lateral folds
            context.setFillColor(red: palette.darkGreen.r, green: palette.darkGreen.g, blue: palette.darkGreen.b, alpha: 0.92)
            context.fill(CGRect(x: -4.2, y: 2.0, width: 3.2, height: 2.8))
            context.fill(CGRect(x: -4.2, y: -4.8, width: 3.2, height: 2.8))
            context.fill(CGRect(x: -1.2, y: 3.0, width: 2.6, height: 2.4))
            context.fill(CGRect(x: -1.2, y: -5.4, width: 2.6, height: 2.4))

            // Dual golden dorsolateral ridges
            context.setFillColor(red: palette.highlight.r, green: palette.highlight.g, blue: palette.highlight.b, alpha: 0.96)
            context.fill(CGRect(x: -5.6, y: 3.8, width: 7.8, height: 1.6))
            context.fill(CGRect(x: -5.6, y: -5.4, width: 7.8, height: 1.6))

        case .goldenZen:
            // Kaeru Zen: Luminous gold spine + delicate pearl white dots
            context.setFillColor(red: palette.highlight.r, green: palette.highlight.g, blue: palette.highlight.b, alpha: 0.98)
            context.fill(CGRect(x: -5.6, y: -1.1, width: 8.4, height: 2.2))

            // Pearl dots
            context.setFillColor(red: 1.0, green: 1.0, blue: 0.92, alpha: 0.95)
            context.fill(CGRect(x: -4.0, y: 2.2, width: 1.8, height: 1.8))
            context.fill(CGRect(x: -4.0, y: -4.0, width: 1.8, height: 1.8))
            context.fill(CGRect(x: -1.0, y: 2.0, width: 1.8, height: 1.8))
            context.fill(CGRect(x: -1.0, y: -3.8, width: 1.8, height: 1.8))
        }
    }

    // MARK: - Vocal Sac (Breathing & Croak Puff)

    private static func drawVocalSac(_ frog: PondFrog, in context: CGContext, palette: FrogPalette) {
        let breathOffset = CGFloat(sin(frog.throatPhase)) * 1.5

        if frog.variant == .mossySpotted && frog.croakProgress > 0.02 {
            // Tono-gaeru has iconic PAIRED lateral vocal sacs blooming on left & right of jaw!
            let croakR = CGFloat(2.8 + 5.0 * frog.croakProgress)
            let sacX: CGFloat = 6.4
            let sacLeftY: CGFloat = 4.8 + croakR * 0.4
            let sacRightY: CGFloat = -4.8 - croakR * 0.4

            context.setFillColor(red: palette.sac.r, green: palette.sac.g, blue: palette.sac.b, alpha: 0.90)
            context.fillEllipse(in: CGRect(x: sacX - croakR, y: sacLeftY - croakR, width: croakR * 2.0, height: croakR * 2.0))
            context.fillEllipse(in: CGRect(x: sacX - croakR, y: sacRightY - croakR, width: croakR * 2.0, height: croakR * 2.0))

            // White glint dots
            context.setFillColor(red: 1.0, green: 1.0, blue: 0.95, alpha: 0.92)
            context.fill(CGRect(x: sacX + croakR * 0.2, y: sacLeftY - croakR * 0.3, width: 2.0, height: 2.0))
            context.fill(CGRect(x: sacX + croakR * 0.2, y: sacRightY - croakR * 0.3, width: 2.0, height: 2.0))
        } else if frog.croakProgress > 0.02 {
            // Single large spherical throat bubble ballooning forward from beneath chin
            let croakR = CGFloat(3.5 + 5.8 * frog.croakProgress)
            let sacX: CGFloat = 8.6 + croakR * 0.45
            let sacY: CGFloat = 0.0

            context.setFillColor(red: palette.sac.r, green: palette.sac.g, blue: palette.sac.b, alpha: 0.90)
            context.fillEllipse(in: CGRect(x: sacX - croakR, y: sacY - croakR, width: croakR * 2.0, height: croakR * 2.0))

            // Specular glint
            context.setFillColor(red: 1.0, green: 1.0, blue: 0.95, alpha: 0.94)
            context.fill(CGRect(x: sacX + croakR * 0.3, y: sacY - croakR * 0.4, width: 2.4, height: 2.4))
        } else {
            // High-contrast creamy white throat & belly band
            context.setFillColor(red: palette.throat.r, green: palette.throat.g, blue: palette.throat.b, alpha: 0.96)
            context.fill(CGRect(x: 6.8 + breathOffset * 0.5, y: -2.6, width: 2.6 + breathOffset, height: 5.2))
        }
    }

    // MARK: - Eyes (Bulbous, Prominent, Unmistakable Frog Eyes)

    private static func drawFrogEyes(_ frog: PondFrog, in context: CGContext, palette: FrogPalette) {
        let eyeLeftY: CGFloat = 4.4
        let eyeRightY: CGFloat = -4.4
        let eyeX: CGFloat = 4.6

        if frog.isBlinking {
            // Closed eyelid horizontal slit
            context.setFillColor(red: palette.mask.r, green: palette.mask.g, blue: palette.mask.b, alpha: 0.95)
            context.fill(CGRect(x: eyeX - 1.8, y: eyeLeftY - 0.9, width: 4.8, height: 1.6))
            context.fill(CGRect(x: eyeX - 1.8, y: eyeRightY - 0.9, width: 4.8, height: 1.6))
            context.setFillColor(red: palette.body.r, green: palette.body.g, blue: palette.body.b, alpha: 1.0)
            context.fill(CGRect(x: eyeX - 1.4, y: eyeLeftY + 0.7, width: 4.0, height: 1.4))
            context.fill(CGRect(x: eyeX - 1.4, y: eyeRightY - 2.1, width: 4.0, height: 1.4))
        } else {
            // Big bulbous dome-like frog eyes that protrude prominently from the skull
            // 1. Dark outer eye cup
            context.setFillColor(red: palette.mask.r, green: palette.mask.g, blue: palette.mask.b, alpha: 1.0)
            context.fillEllipse(in: CGRect(x: eyeX - 2.5, y: eyeLeftY - 2.5, width: 5.4, height: 5.4))
            context.fillEllipse(in: CGRect(x: eyeX - 2.5, y: eyeRightY - 2.9, width: 5.4, height: 5.4))

            // 2. Vivid glowing golden amber iris
            context.setFillColor(red: palette.eyeIris.r, green: palette.eyeIris.g, blue: palette.eyeIris.b, alpha: 1.0)
            context.fillEllipse(in: CGRect(x: eyeX - 1.6, y: eyeLeftY - 1.6, width: 3.8, height: 3.8))
            context.fillEllipse(in: CGRect(x: eyeX - 1.6, y: eyeRightY - 2.2, width: 3.8, height: 3.8))

            // 3. Deep black horizontal slit pupil (the signature amphibian eye!)
            context.setFillColor(red: 0.04, green: 0.04, blue: 0.04, alpha: 1.0)
            context.fill(CGRect(x: eyeX - 1.8, y: eyeLeftY - 0.6, width: 4.0, height: 1.2))
            context.fill(CGRect(x: eyeX - 1.8, y: eyeRightY - 0.6, width: 4.0, height: 1.2))

            // 4. Two bright white specular glint pixels (makes the eyes look moist and alive!)
            context.setFillColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.98)
            // Primary highlight
            context.fill(CGRect(x: eyeX + 0.4, y: eyeLeftY + 0.5, width: 1.5, height: 1.5))
            context.fill(CGRect(x: eyeX + 0.4, y: eyeRightY - 0.3, width: 1.5, height: 1.5))
            // Secondary subtle rim glint
            context.setFillColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.70)
            context.fill(CGRect(x: eyeX - 1.2, y: eyeLeftY - 1.2, width: 1.0, height: 1.0))
            context.fill(CGRect(x: eyeX - 1.2, y: eyeRightY - 1.8, width: 1.0, height: 1.0))
        }
    }

    // MARK: - Lotus Petal Hat (.lotusPetal accessory)

    private static func drawLotusPetalHat(in context: CGContext) {
        // Delicate pink water lily petal resting gracefully on the crown of the head like a beret,
        // placed slightly back so the two golden eyes remain completely unobstructed!
        let hatX: CGFloat = 2.2
        let hatY: CGFloat = 0.0

        // Petal deep rose-magenta rim & base
        context.setFillColor(red: 0.88, green: 0.22, blue: 0.46, alpha: 0.98)
        context.fill(CGRect(x: hatX - 3.2, y: hatY - 3.6, width: 6.4, height: 7.2))

        // Petal vibrant sakura pink body
        context.setFillColor(red: 0.98, green: 0.48, blue: 0.68, alpha: 0.98)
        context.fill(CGRect(x: hatX - 2.5, y: hatY - 2.8, width: 5.4, height: 5.8))

        // Petal soft inner petal fold & highlight
        context.setFillColor(red: 1.00, green: 0.82, blue: 0.92, alpha: 0.98)
        context.fill(CGRect(x: hatX - 1.4, y: hatY - 1.6, width: 3.2, height: 3.4))

        // Petal curled tip pointing toward nape
        context.setFillColor(red: 0.82, green: 0.16, blue: 0.40, alpha: 0.98)
        context.fill(CGRect(x: hatX - 3.8, y: hatY - 1.2, width: 2.0, height: 2.4))
        // Delicate white highlight glint on tip
        context.setFillColor(red: 1.00, green: 0.92, blue: 0.96, alpha: 0.95)
        context.fill(CGRect(x: hatX + 1.8, y: hatY - 0.6, width: 1.4, height: 1.4))
    }

    // MARK: - Palettes

    private struct FrogPalette {
        let body: (r: CGFloat, g: CGFloat, b: CGFloat)
        let darkGreen: (r: CGFloat, g: CGFloat, b: CGFloat)
        let highlight: (r: CGFloat, g: CGFloat, b: CGFloat)
        let throat: (r: CGFloat, g: CGFloat, b: CGFloat)
        let sac: (r: CGFloat, g: CGFloat, b: CGFloat)
        let eyeIris: (r: CGFloat, g: CGFloat, b: CGFloat)
        let mask: (r: CGFloat, g: CGFloat, b: CGFloat)
    }

    private static func frogPalette(for variant: PondFrogVariant) -> FrogPalette {
        switch variant {
        case .classicGreen, .lotusPetal:
            // High-contrast vibrant Japanese tree frog (Nihon Amagaeru)
            // Vivid lime green that clearly separates from the dark olive lily pad leaf!
            return FrogPalette(
                body: (0.36, 0.78, 0.22),      // Radiant tree frog green
                darkGreen: (0.10, 0.28, 0.08), // Dark forest contour
                highlight: (0.68, 0.96, 0.35), // Glowing lime-yellow highlights
                throat: (0.94, 0.98, 0.82),    // Creamy white belly/throat
                sac: (0.84, 0.96, 0.68),      // Pale chartreuse vocal sac
                eyeIris: (1.00, 0.84, 0.16),   // Luminous golden amber
                mask: (0.06, 0.08, 0.05)       // Deep charcoal mask
            )

        case .mossySpotted:
            return FrogPalette(
                body: (0.28, 0.58, 0.20),
                darkGreen: (0.08, 0.24, 0.06),
                highlight: (0.92, 0.85, 0.22), // Golden ridges
                throat: (0.88, 0.92, 0.75),
                sac: (0.80, 0.90, 0.64),
                eyeIris: (0.96, 0.72, 0.14),
                mask: (0.06, 0.08, 0.05)
            )

        case .goldenZen:
            return FrogPalette(
                body: (0.86, 0.80, 0.18),      // Golden chartreuse
                darkGreen: (0.50, 0.46, 0.08), // Olive gold shadow
                highlight: (1.00, 0.98, 0.48), // Luminous gold
                throat: (0.96, 0.96, 0.82),
                sac: (1.00, 0.92, 0.42),      // Amber gold sac
                eyeIris: (0.98, 0.58, 0.12),   // Copper amber
                mask: (0.20, 0.15, 0.05)
            )
        }
    }
}
