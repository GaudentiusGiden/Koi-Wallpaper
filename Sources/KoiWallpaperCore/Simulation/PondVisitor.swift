import Foundation

/// The type of visitors that can appear on the surface of the pond.
public enum PondVisitorType: String, Codable, CaseIterable, Sendable {
    case swan = "swan"
    case ball = "ball"

    public var displayName: String {
        switch self {
        case .swan: return "Angsa (Swan)"
        case .ball: return "Bola (Temari Ball)"
        }
    }
}

/// Represents an interactive surface visitor (such as an elegant swimming swan
/// or a floating Japanese Temari ball) that influences the motion and curiosity of koi fish.
public struct PondVisitor: Identifiable, Sendable {
    public let id: UUID
    public let type: PondVisitorType
    public var position: PondVector
    public var velocity: PondVector
    public var heading: Double
    public var speed: Double
    public var radius: Double
    public var interactionRadius: Double
    public var bobbingPhase: Double
    public var bobbingSpeed: Double
    public var wanderAngle: Double
    public var lifetime: Double?
    public var age: Double
    public var rng: SeededRandomNumberGenerator

    public var isExpired: Bool {
        if let maxAge = lifetime {
            return age >= maxAge
        }
        return false
    }

    public init(
        id: UUID = UUID(),
        type: PondVisitorType,
        position: PondVector,
        velocity: PondVector? = nil,
        heading: Double = 0.0,
        speed: Double? = nil,
        radius: Double? = nil,
        interactionRadius: Double? = nil,
        lifetime: Double? = nil,
        seed: UInt64? = nil
    ) {
        self.id = id
        self.type = type
        self.position = position
        self.heading = normalizeAngle(heading)
        self.lifetime = lifetime
        self.age = 0.0

        let initialSeed = seed ?? UInt64(truncatingIfNeeded: id.hashValue)
        var prng = SeededRandomNumberGenerator(seed: initialSeed)
        self.bobbingPhase = Double.random(in: 0...(2 * .pi), using: &prng)
        self.wanderAngle = Double.random(in: -Double.pi...Double.pi, using: &prng)
        self.rng = prng

        switch type {
        case .swan:
            let defaultSpeed = speed ?? 24.0
            self.speed = defaultSpeed
            self.velocity = velocity ?? PondVector.fromAngle(heading, length: defaultSpeed)
            self.radius = radius ?? 24.0
            self.interactionRadius = interactionRadius ?? 160.0
            self.bobbingSpeed = 2.2
        case .ball:
            let defaultSpeed = speed ?? 16.0
            let initialVel = velocity ?? PondVector(
                x: Double.random(in: -defaultSpeed...defaultSpeed, using: &self.rng),
                y: Double.random(in: -defaultSpeed...defaultSpeed, using: &self.rng)
            )
            self.velocity = initialVel
            self.speed = initialVel.length
            self.radius = radius ?? 14.0
            self.interactionRadius = interactionRadius ?? 120.0
            self.bobbingSpeed = 3.4
        }
    }

    /// Main physics update step for the visitor.
    public mutating func update(dt: Double, bounds: PondBounds) {
        age += dt
        bobbingPhase += bobbingSpeed * dt
        if bobbingPhase > 2.0 * .pi {
            bobbingPhase -= 2.0 * .pi
        }

        switch type {
        case .swan:
            // Smooth gliding motion with soft boundary avoidance
            wanderAngle += Double.random(in: -0.3...0.3, using: &rng) * dt * 1.4
            wanderAngle = normalizeAngle(wanderAngle)

            let forward = PondVector.fromAngle(heading, length: speed)
            let boundaryForce = bounds.boundaryAvoidanceForce(
                for: position,
                heading: heading,
                strength: 6.0,
                marginOverride: radius + 45.0
            )
            let steer = forward + boundaryForce * 1.5
            if steer.lengthSquared > 0.0001 {
                let desiredHeading = steer.angle
                let diff = normalizeAngle(desiredHeading - heading)
                let maxTurn = 1.4 * dt
                let turn = min(max(diff, -maxTurn), maxTurn)
                heading = normalizeAngle(heading + turn)
            }
            velocity = PondVector.fromAngle(heading, length: speed)
            position += velocity * dt
            position = bounds.clamped(position, inset: radius + 8.0)

        case .ball:
            // Drifts with slight water resistance and bounces off pond boundaries
            position += velocity * dt

            // Mild hydrodynamic damping
            let damping = 0.08 * dt
            velocity = velocity * max(0.1, 1.0 - damping)

            // If speed drops below minimum drift, provide gentle surface current
            if velocity.length < 4.0 {
                let currentAngle = sin(age * 0.2) * .pi
                velocity += PondVector.fromAngle(currentAngle, length: 5.0 * dt)
            }

            // Boundary collision bounce
            let minX = bounds.minX + radius + 4.0
            let maxX = bounds.maxX - radius - 4.0
            let minY = bounds.minY + radius + 4.0
            let maxY = bounds.maxY - radius - 4.0

            if position.x <= minX {
                position.x = minX
                velocity.x = abs(velocity.x)
            } else if position.x >= maxX {
                position.x = maxX
                velocity.x = -abs(velocity.x)
            }

            if position.y <= minY {
                position.y = minY
                velocity.y = abs(velocity.y)
            } else if position.y >= maxY {
                position.y = maxY
                velocity.y = -abs(velocity.y)
            }

            if velocity.lengthSquared > 0.001 {
                heading = velocity.angle
            }
        }
    }

    /// Imparts a physical impulse to the visitor (e.g. nudged by a koi's nose or water splash).
    public mutating func applyImpulse(_ impulse: PondVector) {
        velocity += impulse
        let maxSpeed = 75.0
        if velocity.length > maxSpeed {
            velocity = velocity.normalized() * maxSpeed
        }
        if velocity.lengthSquared > 0.001 {
            heading = velocity.angle
        }
    }
}
