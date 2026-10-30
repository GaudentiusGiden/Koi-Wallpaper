import Foundation

/// Represents a single food pellet floating in the pond.
/// Guarantees strict single-consumption semantics.
public struct FoodPellet: Identifiable, Equatable, Sendable {
    public let id: UUID
    public var position: PondVector
    public var driftVelocity: PondVector
    public var age: Double
    public let lifetime: Double
    public private(set) var isConsumed: Bool
    public private(set) var consumerFishId: UUID?
    public let radius: Double
    public var bobbingPhase: Double
    /// Remaining bites for this pellet (1.0 to 3.0). Small fish nibble away portions (0.35 each).
    public var bitesRemaining: Double

    public init(
        id: UUID = UUID(),
        position: PondVector,
        driftVelocity: PondVector = .zero,
        age: Double = 0.0,
        lifetime: Double = 25.0,
        radius: Double = 3.5,
        bobbingPhase: Double = 0.0,
        bitesRemaining: Double = 2.0
    ) {
        self.id = id
        self.position = position
        self.driftVelocity = driftVelocity
        self.age = age
        self.lifetime = lifetime
        self.isConsumed = false
        self.consumerFishId = nil
        self.radius = radius
        self.bobbingPhase = bobbingPhase
        self.bitesRemaining = bitesRemaining
    }

    public var isExpired: Bool {
        age >= lifetime
    }

    /// Advances the pellet physics, drifting gently on the water surface.
    public mutating func update(dt: Double, bounds: PondBounds) {
        guard !isConsumed else { return }
        age += dt
        position += driftVelocity * dt
        // Keep within pond margins
        position = bounds.clamped(position, inset: radius + 2.0)
        bobbingPhase += dt * 1.5
    }

    /// Atomically marks the pellet as consumed by a specific koi.
    /// Returns true if consumption was successful, false if already consumed.
    public mutating func consume(by fishId: UUID) -> Bool {
        guard !isConsumed else { return false }
        isConsumed = true
        consumerFishId = fishId
        bitesRemaining = 0.0
        return true
    }

    /// Subtracts a portion when tiny decorative fish nibble at the pellet (Nagomi tinyFishSteal).
    /// Returns true if the pellet was completely consumed by the bite.
    @discardableResult
    public mutating func takeBite(amount: Double = 0.35) -> Bool {
        guard !isConsumed else { return false }
        bitesRemaining -= amount
        if bitesRemaining <= 0.05 {
            bitesRemaining = 0.0
            isConsumed = true
            return true
        }
        return false
    }
}
