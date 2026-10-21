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

    public static func shadowStyle(for theme: PondTheme) -> ShadowStyle {
        switch theme {
        case .day:
            return ShadowStyle(
                color: (0.015, 0.125, 0.095),
                coreAlpha: 0.36,
                penumbraAlpha: 0.16,
                smallFishAlpha: 0.24
            )
        case .dawn:
            return ShadowStyle(
                color: (0.035, 0.120, 0.075),
                coreAlpha: 0.30,
                penumbraAlpha: 0.13,
                smallFishAlpha: 0.20
            )
        case .goldenHour:
            return ShadowStyle(
                color: (0.020, 0.085, 0.095),
                coreAlpha: 0.34,
                penumbraAlpha: 0.15,
                smallFishAlpha: 0.22
            )
        case .dusk:
            return ShadowStyle(
                color: (0.025, 0.045, 0.095),
                coreAlpha: 0.26,
                penumbraAlpha: 0.11,
                smallFishAlpha: 0.17
            )
        case .night:
            return ShadowStyle(
                color: (0.008, 0.022, 0.060),
                coreAlpha: 0.22,
                penumbraAlpha: 0.09,
                smallFishAlpha: 0.14
            )
        case .deepClear:
            return ShadowStyle(
                color: (0.010, 0.110, 0.130),
                coreAlpha: 0.38,
                penumbraAlpha: 0.16,
                smallFishAlpha: 0.26
            )
        case .rain:
            return ShadowStyle(
                color: (0.020, 0.050, 0.075),
                coreAlpha: 0.24,
                penumbraAlpha: 0.14,
                smallFishAlpha: 0.16
            )
        }
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
