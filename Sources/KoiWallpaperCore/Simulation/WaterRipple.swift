import Foundation

public enum RippleType: String, Sendable, Equatable, CaseIterable {
    case waterCall    // Regular click / touch (cyan splash)
    case foodDrop     // Option-click (orange food splash)
    case eatingNibble // Koi eating pellet or small fish steal nibble (small white/cyan delicate ring)
    case rainDrop     // Atmospheric raindrop ripple (delicate silver-cyan ring)
    case padBump      // Koi bumping into water lily pad (organic emerald-cyan wave)
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
            let maxR = maxRadius ?? 140.0
            self.maxRadius = maxR
            self.growthRate = max(0.0, (maxR - initialRadius) / 2.2)
            self.fadeRate = max(0.0, initialAlpha / 2.5)
        case .foodDrop:
            let maxR = maxRadius ?? 95.0
            self.maxRadius = maxR
            self.growthRate = max(0.0, (maxR - initialRadius) / 2.2)
            self.fadeRate = max(0.0, initialAlpha / 2.5)
        case .eatingNibble:
            self.maxRadius = maxRadius ?? 25.0
            self.growthRate = 28.0
            self.fadeRate = 1.2
        case .rainDrop:
            let maxR = maxRadius ?? 32.0
            self.maxRadius = maxR
            self.growthRate = max(0.0, (maxR - initialRadius) / 0.95)
            self.fadeRate = max(0.0, initialAlpha / 1.05)
        case .padBump:
            let maxR = maxRadius ?? 48.0
            self.maxRadius = maxR
            self.growthRate = max(0.0, (maxR - initialRadius) / 1.2)
            self.fadeRate = max(0.0, initialAlpha / 1.2)
        }
    }

    public var isDead: Bool {
        alpha <= 0.0 || (radius >= maxRadius && alpha <= 0.001)
    }

    public mutating func update(dt: Double) {
        radius += growthRate * dt
        if radius > maxRadius {
            radius = maxRadius
        }
        alpha -= fadeRate * dt
        if alpha < 0.0 {
            alpha = 0.0
        }
    }
}
