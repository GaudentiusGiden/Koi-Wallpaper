import AppKit
import CoreGraphics
import Foundation

/// Pixel-art artwork generator for the Pond Turtle (*Pond Turtle / Kame*).
///
/// Directly renders authentic pixel-art sprites derived from the reference turtle pack,
/// aligned to the pond logical coarse pixel grid without smooth vector blurring.
public enum PondTurtleArtwork {

    public enum Pose: String, Sendable, CaseIterable {
        /// Top-down view (basking on river stone or paddling straight)
        case topDown
        /// Dynamic 3/4 swimming view (gliding through water, showing peach plastron underbelly)
        case swimming3D
    }

    public enum PaletteVariant: String, Sendable, CaseIterable {
        /// Authentic Japanese Nagomi garden palette matching Koi, lotus, and water caustics
        case nagomi
        /// Original bright lime & mint pixel palette from the reference pack
        case vibrant
    }

    // MARK: - Embedded Sprite Caches

    private static let b64SwimVibrant = "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"
    private static let b64TopVibrant = "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"
    private static let b64SwimNagomi = "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"
    private static let b64TopNagomi = "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"

    private static var cachedSwimVibrant: CGImage? = decodeBase64Png(b64SwimVibrant)
    private static var cachedTopVibrant: CGImage? = decodeBase64Png(b64TopVibrant)
    private static var cachedSwimNagomi: CGImage? = decodeBase64Png(b64SwimNagomi)
    private static var cachedTopNagomi: CGImage? = decodeBase64Png(b64TopNagomi)

    private static func decodeBase64Png(_ b64: String) -> CGImage? {
        guard let data = Data(base64Encoded: b64),
              let rep = NSBitmapImageRep(data: data) else { return nil }
        return rep.cgImage
    }

    public static func spriteImage(pose: Pose, variant: PaletteVariant) -> CGImage? {
        switch (pose, variant) {
        case (.swimming3D, .nagomi): return cachedSwimNagomi
        case (.swimming3D, .vibrant): return cachedSwimVibrant
        case (.topDown, .nagomi): return cachedTopNagomi
        case (.topDown, .vibrant): return cachedTopVibrant
        }
    }

    // MARK: - Pixel-Art Drawing

    /// Draws the turtle sprite at the specified position with pixel-perfect nearest neighbor interpolation.
    public static func drawPixelTurtle(
        pose: Pose,
        variant: PaletteVariant = .nagomi,
        at center: CGPoint,
        heading: Double = 0.0,
        scale: CGFloat = 1.6,
        in context: CGContext
    ) {
        guard let sprite = spriteImage(pose: pose, variant: variant) else { return }

        context.saveGState()
        context.translateBy(x: center.x, y: center.y)
        if heading != 0.0 {
            context.rotate(by: CGFloat(heading))
        }

        let w = CGFloat(sprite.width) * scale
        let h = CGFloat(sprite.height) * scale

        // Strict pixel art guarantees: no anti-aliasing, nearest neighbor magnification
        context.interpolationQuality = .none
        context.setShouldAntialias(false)

        context.draw(sprite, in: CGRect(x: -w * 0.5, y: -h * 0.5, width: w, height: h))
        context.restoreGState()
    }

    // MARK: - Pixel-Art River Rock (Basking Stone)

    /// Draws a natural river boulder constructed out of stepped pixel-art blocks with moss details.
    public static func drawPixelRiverRock(
        at center: CGPoint,
        scale: CGFloat = 2.0,
        in context: CGContext,
        theme: PondTheme = .day
    ) {
        context.saveGState()
        context.translateBy(x: center.x, y: center.y)
        context.interpolationQuality = .none
        context.setShouldAntialias(false)

        let u = scale * 1.6 // Pixel block unit

        // 1. Underwater Drop Shadow (Stepped pixel oval)
        context.setFillColor(red: 0.02, green: 0.06, blue: 0.05, alpha: 0.42)
        context.fill(CGRect(x: -26 * u, y: -20 * u, width: 52 * u, height: 38 * u))
        context.fill(CGRect(x: -30 * u, y: -16 * u, width: 60 * u, height: 30 * u))
        context.fill(CGRect(x: -20 * u, y: -23 * u, width: 40 * u, height: 44 * u))

        // 2. Base Dark Outline Perimeter (Stepped river stone silhouette)
        context.setFillColor(red: 0.12, green: 0.16, blue: 0.15, alpha: 1.0)
        context.fill(CGRect(x: -24 * u, y: -18 * u, width: 48 * u, height: 36 * u))
        context.fill(CGRect(x: -28 * u, y: -14 * u, width: 56 * u, height: 28 * u))
        context.fill(CGRect(x: -18 * u, y: -21 * u, width: 36 * u, height: 42 * u))

        // 3. Deep Slate Granite Body
        context.setFillColor(red: 0.22, green: 0.27, blue: 0.26, alpha: 1.0)
        context.fill(CGRect(x: -22 * u, y: -16 * u, width: 44 * u, height: 32 * u))
        context.fill(CGRect(x: -26 * u, y: -12 * u, width: 52 * u, height: 24 * u))
        context.fill(CGRect(x: -16 * u, y: -19 * u, width: 32 * u, height: 38 * u))

        // 4. Midtone Slate Facet (Warm grey dry stone)
        context.setFillColor(red: 0.32, green: 0.38, blue: 0.36, alpha: 1.0)
        context.fill(CGRect(x: -18 * u, y: -12 * u, width: 36 * u, height: 24 * u))
        context.fill(CGRect(x: -22 * u, y: -8 * u, width: 44 * u, height: 16 * u))
        context.fill(CGRect(x: -12 * u, y: -15 * u, width: 24 * u, height: 30 * u))

        // 5. Sunlit Crest Highlight (Upper facet catching pond sunlight)
        context.setFillColor(red: 0.44, green: 0.50, blue: 0.48, alpha: 1.0)
        context.fill(CGRect(x: -12 * u, y: -4 * u, width: 24 * u, height: 14 * u))
        context.fill(CGRect(x: -16 * u, y: -1 * u, width: 32 * u, height: 8 * u))
        context.fill(CGRect(x: -8 * u, y: -7 * u, width: 16 * u, height: 20 * u))

        // Subtle specular edge glint
        context.setFillColor(red: 0.56, green: 0.62, blue: 0.60, alpha: 0.85)
        context.fill(CGRect(x: -10 * u, y: 1 * u, width: 18 * u, height: 4 * u))
        context.fill(CGRect(x: -4 * u, y: 5 * u, width: 8 * u, height: 3 * u))

        // 6. Clinging Moss Pixels (Natural Japanese garden moss draping the stone edges)
        context.setFillColor(red: 0.16, green: 0.38, blue: 0.18, alpha: 0.95) // Dark moss base
        context.fill(CGRect(x: -24 * u, y: -10 * u, width: 6 * u, height: 10 * u))
        context.fill(CGRect(x: -20 * u, y: -16 * u, width: 8 * u, height: 7 * u))
        context.fill(CGRect(x: -14 * u, y: -19 * u, width: 8 * u, height: 5 * u))
        context.fill(CGRect(x: 12 * u, y: -15 * u, width: 8 * u, height: 7 * u))
        context.fill(CGRect(x: 18 * u, y: -9 * u, width: 6 * u, height: 8 * u))

        // Vibrant moss pixels
        context.setFillColor(red: 0.28, green: 0.56, blue: 0.24, alpha: 0.95)
        context.fill(CGRect(x: -22 * u, y: -8 * u, width: 4 * u, height: 6 * u))
        context.fill(CGRect(x: -18 * u, y: -14 * u, width: 5 * u, height: 4 * u))
        context.fill(CGRect(x: 14 * u, y: -13 * u, width: 5 * u, height: 4 * u))
        context.fill(CGRect(x: 18 * u, y: -7 * u, width: 4 * u, height: 4 * u))

        // Fresh lime moss tips
        context.setFillColor(red: 0.45, green: 0.74, blue: 0.32, alpha: 0.90)
        context.fill(CGRect(x: -20 * u, y: -6 * u, width: 2 * u, height: 3 * u))
        context.fill(CGRect(x: -16 * u, y: -12 * u, width: 3 * u, height: 2 * u))
        context.fill(CGRect(x: 16 * u, y: -11 * u, width: 2 * u, height: 2 * u))

        context.restoreGState()
    }

    // MARK: - Pixel-Art Water Ripples

    /// Draws stepped pixel-art ripple rings expanding around the turtle.
    public static func drawPixelRipples(
        at center: CGPoint,
        radius: CGFloat = 32.0,
        in context: CGContext
    ) {
        context.saveGState()
        context.translateBy(x: center.x, y: center.y)
        context.interpolationQuality = .none
        context.setShouldAntialias(false)

        let u: CGFloat = 2.0
        // Stepped pixel octagon / diamond rings
        for ring in [radius * 0.7, radius * 1.1] {
            let r = ring
            let alpha: CGFloat = ring == radius * 0.7 ? 0.48 : 0.28
            context.setFillColor(red: 0.85, green: 0.98, blue: 0.92, alpha: alpha)

            // Top & Bottom pixel bars
            context.fill(CGRect(x: -r * 0.5, y: r, width: r, height: u))
            context.fill(CGRect(x: -r * 0.5, y: -r - u, width: r, height: u))

            // Left & Right pixel bars
            context.fill(CGRect(x: -r - u, y: -r * 0.5, width: u, height: r))
            context.fill(CGRect(x: r, y: -r * 0.5, width: u, height: r))

            // 4 Corner diagonals
            context.fill(CGRect(x: r * 0.5, y: r * 0.5, width: r * 0.35, height: u))
            context.fill(CGRect(x: -r * 0.85, y: r * 0.5, width: r * 0.35, height: u))
            context.fill(CGRect(x: r * 0.5, y: -r * 0.5 - u, width: r * 0.35, height: u))
            context.fill(CGRect(x: -r * 0.85, y: -r * 0.5 - u, width: r * 0.35, height: u))
        }

        context.restoreGState()
    }

    // MARK: - Stepped Pixel Drop Shadow

    /// Draws a stepped pixel shadow cast onto the pond floor or rock surface.
    public static func drawPixelShadow(
        pose: Pose,
        at center: CGPoint,
        scale: CGFloat = 1.6,
        heading: Double = 0.0,
        in context: CGContext,
        shadowStyle: PondLighting.ShadowStyle
    ) {
        context.saveGState()
        let offset = PondLighting.shadowOffset(distance: 18.0)
        context.translateBy(x: center.x + offset.x, y: center.y + offset.y)
        if heading != 0.0 {
            context.rotate(by: CGFloat(heading))
        }
        context.interpolationQuality = .none
        context.setShouldAntialias(false)

        let c = shadowStyle.color
        let u = scale * 1.5

        // Stepped pixel shadow silhouette
        context.setFillColor(red: c.0, green: c.1, blue: c.2, alpha: shadowStyle.penumbraAlpha)
        context.fill(CGRect(x: -16 * u, y: -18 * u, width: 32 * u, height: 36 * u))
        context.fill(CGRect(x: -20 * u, y: -14 * u, width: 40 * u, height: 28 * u))
        context.fill(CGRect(x: -12 * u, y: -22 * u, width: 24 * u, height: 44 * u))

        context.setFillColor(red: c.0, green: c.1, blue: c.2, alpha: shadowStyle.coreAlpha)
        context.fill(CGRect(x: -12 * u, y: -14 * u, width: 24 * u, height: 28 * u))
        context.fill(CGRect(x: -15 * u, y: -10 * u, width: 30 * u, height: 20 * u))

        context.restoreGState()
    }

    // MARK: - High-Level Composite Drawing

    /// Draws the swimming depth shadow for the turtle if it is actively in the pond water.
    public static func drawShadow(
        _ turtle: PondTurtle,
        in context: CGContext,
        shadowStyle: PondLighting.ShadowStyle
    ) {
        guard turtle.state == .swimming || turtle.state == .slidingIn || turtle.state == .returning else { return }
        drawPixelShadow(
            pose: .swimming3D,
            at: turtle.position,
            scale: turtle.scale,
            heading: turtle.heading,
            in: context,
            shadowStyle: shadowStyle
        )
    }

    /// Renders the river rock and the pond turtle (*Kame*) according to its simulation state.
    public static func draw(
        _ turtle: PondTurtle,
        in context: CGContext,
        theme: PondTheme = .day,
        variant: PaletteVariant? = nil
    ) {
        let activeVariant = variant ?? turtle.variant

        // 1. River rock is always present at its shoreline cove
        drawPixelRiverRock(at: turtle.rockPosition, scale: 2.0, in: context, theme: theme)

        guard turtle.isVisible else { return }

        // 2. Turtle on rock or swimming
        switch turtle.state {
        case .basking, .startled:
            drawPixelTurtle(
                pose: .topDown,
                variant: activeVariant,
                at: turtle.position,
                heading: turtle.heading,
                scale: turtle.scale,
                in: context
            )
        case .swimming, .slidingIn, .returning, .climbingOut:
            drawPixelRipples(at: turtle.position, radius: 30.0, in: context)
            drawPixelTurtle(
                pose: .swimming3D,
                variant: activeVariant,
                at: turtle.position,
                heading: turtle.heading,
                scale: turtle.scale,
                in: context
            )
        case .away:
            break
        }
    }
}
