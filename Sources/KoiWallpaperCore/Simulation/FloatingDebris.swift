import Foundation

/// Types of organic and atmospheric debris drifting on the surface of the pond.
public enum FloatingDebrisType: String, Codable, CaseIterable, Sendable {
    case sakuraPetal = "sakuraPetal"     // Pink cherry blossom petal (Spring)
    case waterLilyPetal = "waterLilyPetal" // White/blush lotus petal (Summer)
    case momijiLeaf = "momijiLeaf"       // Japanese maple leaf (Autumn)
    case snowShard = "snowShard"         // Translucent ice/snowflake (Winter)

    public var displayName: String {
        switch self {
        case .sakuraPetal: return "Kelopak Sakura"
        case .waterLilyPetal: return "Kelopak Teratai"
        case .momijiLeaf: return "Daun Momiji"
        case .snowShard: return "Serpihan Salju"
        }
    }
}

/// Represents an organic particle or leaf floating on the surface of the pond,
/// drifting gently with water currents and physically responding to ripples.
public struct FloatingDebris: Identifiable, Sendable {
    public let id: UUID
    public let type: FloatingDebrisType
    public var position: PondVector
    public var velocity: PondVector
    public var angle: Double
    public var spin: Double
    public var scale: Double
    public var variant: Int // Subtle visual color/shape variation
    public var age: Double
    public let lifespan: Double
    public var opacity: Double
    public var bobbingPhase: Double
    public var bobbingSpeed: Double

    public var isExpired: Bool {
        age >= lifespan || (age > 0.1 && opacity <= 0.001)
    }

    public init(
        id: UUID = UUID(),
        type: FloatingDebrisType,
        position: PondVector,
        velocity: PondVector? = nil,
        angle: Double = 0.0,
        spin: Double = 0.0,
        scale: Double = 1.0,
        variant: Int = 0,
        lifespan: Double = 50.0,
        seed: UInt64? = nil
    ) {
        self.id = id
        self.type = type
        self.position = position
        self.angle = angle
        self.spin = spin
        self.scale = max(0.6, min(1.8, scale))
        self.variant = variant
        self.age = 0.0
        self.lifespan = max(0.1, lifespan)
        self.opacity = (lifespan < 2.0) ? 1.0 : 0.0 // short test lifespans start visible immediately

        var prng = SeededRandomNumberGenerator(seed: seed ?? UInt64(truncatingIfNeeded: id.hashValue))
        let defaultVel = velocity ?? PondVector(
            x: Double.random(in: -3.0...3.0, using: &prng),
            y: Double.random(in: -3.0...3.0, using: &prng)
        )
        self.velocity = defaultVel
        self.bobbingPhase = Double.random(in: 0...(2 * .pi), using: &prng)
        self.bobbingSpeed = Double.random(in: 1.0...2.2, using: &prng)
    }

    public mutating func update(dt: Double, bounds: PondBounds) {
        age += dt
        bobbingPhase += bobbingSpeed * dt

        // Fade in smoothly over the first 2 seconds; stay opaque; fade out smoothly in last 4 seconds
        let fadeInDuration = 2.0
        let fadeOutDuration = 4.0
        if age < fadeInDuration {
            opacity = min(1.0, age / fadeInDuration)
        } else if age > (lifespan - fadeOutDuration) {
            let remaining = max(0.0, lifespan - age)
            opacity = min(1.0, remaining / fadeOutDuration)
        } else {
            opacity = 1.0
        }

        // Natural gentle drift
        position = position + velocity * dt
        angle += spin * dt

        // Water drag dampening
        let drag = exp(-0.85 * dt)
        velocity = velocity * drag
        spin *= exp(-1.2 * dt)

        // Subtle ambient water drift (sinusoidal micro-currents)
        let ambientDriftX = sin(bobbingPhase * 0.4) * 1.5 * dt
        let ambientDriftY = cos(bobbingPhase * 0.35) * 1.2 * dt
        position = PondVector(x: position.x + ambientDriftX, y: position.y + ambientDriftY)
    }

    /// Receives a physical impulse when an expanding water ripple passes near this debris.
    public mutating func receiveRippleImpulse(
        rippleCenter: PondVector,
        rippleRadius: Double,
        maxRadius: Double,
        strength: Double = 1.0
    ) {
        let toDebris = position - rippleCenter
        let dist = toDebris.length
        guard dist > 0.001 else { return }

        // The impulse zone is where the expanding ripple crest currently is (tolerance ±16pt)
        let crestDistance = abs(dist - rippleRadius)
        guard crestDistance <= 16.0 else { return }

        // Radial outward unit vector
        let radial = toDebris / dist
        // Impulse attenuates as ripple grows larger and towards crest boundary
        let proximityFactor = max(0.0, 1.0 - (crestDistance / 16.0))
        let radiusFactor = max(0.2, 1.0 - (rippleRadius / max(1.0, maxRadius)))
        let impulseMagnitude = 32.0 * strength * proximityFactor * radiusFactor

        // Push outwards
        velocity = velocity + (radial * impulseMagnitude)
        // Add random rotational wobble
        let wobbleDirection: Double = (id.hashValue % 2 == 0) ? 1.0 : -1.0
        spin += wobbleDirection * (impulseMagnitude * 0.04)
    }
}
