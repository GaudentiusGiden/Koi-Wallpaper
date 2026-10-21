import CoreGraphics
import Foundation

/// Shared world-space lighting for the pond floor and objects above it.
enum PondLighting {
    // Light enters from the upper left; artwork coordinates have Y pointing up.
    static func shadowOffset(distance: CGFloat) -> CGPoint {
        CGPoint(x: distance * 0.60, y: -distance * 0.80)
    }

    struct ShadowStyle {
        let color: (CGFloat, CGFloat, CGFloat)
        let coreAlpha: CGFloat
        let penumbraAlpha: CGFloat
        let smallFishAlpha: CGFloat
    }

    static func shadowStyle(for phase: TimeOfDayPhase) -> ShadowStyle {
        switch phase {
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
        case .dusk:
            return ShadowStyle(
                color: (0.025, 0.055, 0.090),
                coreAlpha: 0.25,
                penumbraAlpha: 0.11,
                smallFishAlpha: 0.16
            )
        case .night:
            return ShadowStyle(
                color: (0.008, 0.022, 0.055),
                coreAlpha: 0.18,
                penumbraAlpha: 0.08,
                smallFishAlpha: 0.12
            )
        }
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
