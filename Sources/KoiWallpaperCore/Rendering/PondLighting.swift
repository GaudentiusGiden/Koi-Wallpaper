import CoreGraphics
import Foundation

/// Shared world-space lighting for the pond floor and objects above it.
public enum PondLighting {
    // Light enters from the upper left; artwork coordinates have Y pointing up.
    public static func shadowOffset(distance: CGFloat) -> CGPoint {
        CGPoint(x: distance * 0.60, y: -distance * 0.80)
    }

    public struct ShadowStyle {
        public let color: (CGFloat, CGFloat, CGFloat)
        public let coreAlpha: CGFloat
        public let penumbraAlpha: CGFloat
        public let smallFishAlpha: CGFloat

        public init(color: (CGFloat, CGFloat, CGFloat), coreAlpha: CGFloat, penumbraAlpha: CGFloat, smallFishAlpha: CGFloat) {
            self.color = color
            self.coreAlpha = coreAlpha
            self.penumbraAlpha = penumbraAlpha
            self.smallFishAlpha = smallFishAlpha
        }

        public static func lerp(from a: ShadowStyle, to b: ShadowStyle, t: CGFloat) -> ShadowStyle {
            let clamped = max(0, min(1, t))
            let cr = a.color.0 + (b.color.0 - a.color.0) * clamped
            let cg = a.color.1 + (b.color.1 - a.color.1) * clamped
            let cb = a.color.2 + (b.color.2 - a.color.2) * clamped
            let core = a.coreAlpha + (b.coreAlpha - a.coreAlpha) * clamped
            let pen = a.penumbraAlpha + (b.penumbraAlpha - a.penumbraAlpha) * clamped
            let fish = a.smallFishAlpha + (b.smallFishAlpha - a.smallFishAlpha) * clamped
            return ShadowStyle(color: (cr, cg, cb), coreAlpha: core, penumbraAlpha: pen, smallFishAlpha: fish)
        }
    }

    /// Theme-colored reflected light on koi. Base colors and variety markings
    /// remain intact while the underside shade and dorsal highlight blend with
    /// the surrounding water.
    public struct FishAmbientStyle {
        public let shadeColor: (CGFloat, CGFloat, CGFloat)
        public let shadeAlpha: CGFloat
        public let highlightColor: (CGFloat, CGFloat, CGFloat)
        public let highlightAlpha: CGFloat

        public init(
            shadeColor: (CGFloat, CGFloat, CGFloat),
            shadeAlpha: CGFloat,
            highlightColor: (CGFloat, CGFloat, CGFloat),
            highlightAlpha: CGFloat
        ) {
            self.shadeColor = shadeColor
            self.shadeAlpha = shadeAlpha
            self.highlightColor = highlightColor
            self.highlightAlpha = highlightAlpha
        }

        public static func lerp(from a: FishAmbientStyle, to b: FishAmbientStyle, t: CGFloat) -> FishAmbientStyle {
            let clamped = max(0, min(1, t))
            func mix(_ x: CGFloat, _ y: CGFloat) -> CGFloat { x + (y - x) * clamped }
            return FishAmbientStyle(
                shadeColor: (mix(a.shadeColor.0, b.shadeColor.0), mix(a.shadeColor.1, b.shadeColor.1), mix(a.shadeColor.2, b.shadeColor.2)),
                shadeAlpha: mix(a.shadeAlpha, b.shadeAlpha),
                highlightColor: (mix(a.highlightColor.0, b.highlightColor.0), mix(a.highlightColor.1, b.highlightColor.1), mix(a.highlightColor.2, b.highlightColor.2)),
                highlightAlpha: mix(a.highlightAlpha, b.highlightAlpha)
            )
        }
    }

    public static func shadowStyle(for theme: PondTheme) -> ShadowStyle {
        theme.renderPalette.shadow
    }

    public static func fishAmbientStyle(for theme: PondTheme) -> FishAmbientStyle {
        theme.renderPalette.fishAmbient
    }

    static func shadowStyle(for phase: TimeOfDayPhase) -> ShadowStyle {
        shadowStyle(for: phase.theme)
    }

    /// Baked caustic visibility: strongest near the upper opening and left light
    /// shaft, quieter in the deep central swimming area. Coordinates are 0...1.
    static func causticExposure(at point: CGPoint) -> CGFloat {
        let top = exp(-1.5 * (pow((point.x - 0.48) / 0.34, 2) + pow((point.y - 0.96) / 0.26, 2)))
        let shaft = exp(-pow((point.x - (0.025 + point.y * 0.37)) / 0.12, 2))
        let right = exp(-pow((point.x - 0.94) / 0.18, 2))
        let depthAtten = 0.08 + point.y * 0.08
        return min(1, depthAtten + top * 0.90 + shaft * 0.64 + right * 0.22)
    }
}
