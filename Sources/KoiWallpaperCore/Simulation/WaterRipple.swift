import Foundation

public enum RippleType: Sendable, Equatable {
    case waterCall   // Regular click (cyan splash)
    case foodDrop    // Option-click (orange food splash)
    case eatingNibble // Koi eating pellet (small white/cyan delicate ring)
    case rainDrop    // Atmospheric raindrop ripple (delicate silver-cyan ring)
}

/// Represents an expanding concentric water surface ripple.
public struct WaterRipple: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let center: PondVector
    public var radius: Double
    public let maxRadius: Double
    public var alpha: Double
    public let growthRate: Double
    public let fadeRate: Double
    public let type: RippleType

    public init(
        id: UUID = UUID(),
        center: PondVector,
        type: RippleType,
        initialRadius: Double = 4.0,
        maxRadius: Double? = nil,
        initialAlpha: Double = 1.0
    ) {
        self.id = id
        self.center = center
        self.type = type
        self.radius = initialRadius
        self.alpha = initialAlpha

        switch type {
        case .waterCall:
            self.maxRadius = maxRadius ?? 90.0
            self.growthRate = 45.0
            self.fadeRate = 0.55
        case .foodDrop:
            self.maxRadius = maxRadius ?? 60.0
            self.growthRate = 35.0
            self.fadeRate = 0.65
        case .eatingNibble:
            self.maxRadius = maxRadius ?? 25.0
            self.growthRate = 28.0
            self.fadeRate = 1.2
        case .rainDrop:
            self.maxRadius = maxRadius ?? 18.0
            self.growthRate = 22.0
            self.fadeRate = 1.6
        }
    }

    public var isDead: Bool {
        alpha <= 0.0 || radius >= maxRadius
    }

    public mutating func update(dt: Double) {
        radius += growthRate * dt
        alpha -= fadeRate * dt
        if alpha < 0.0 {
            alpha = 0.0
        }
    }
}
