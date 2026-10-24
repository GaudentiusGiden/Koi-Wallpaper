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
    public let isAutonomous: Bool
    public private(set) var hasEnteredPond: Bool
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
    private var cruiseHeading: Double
    private var autonomousStayDuration: Double
    private var departureTarget: PondVector?
    private var autonomousCourseOffset: Double
    private var autonomousCourseOffsetTarget: Double
    private var autonomousCourseChangeTimer: Double

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
        isAutonomous: Bool = false,
        seed: UInt64? = nil
    ) {
        self.id = id
        self.type = type
        self.isAutonomous = isAutonomous
        self.hasEnteredPond = true
        self.position = position
        self.heading = normalizeAngle(heading)
        self.cruiseHeading = normalizeAngle(heading)
        self.lifetime = lifetime
        self.age = 0.0
        self.departureTarget = nil
        self.autonomousCourseOffset = 0.0

        let initialSeed = seed ?? UInt64(truncatingIfNeeded: id.hashValue)
        var prng = SeededRandomNumberGenerator(seed: initialSeed)
        self.autonomousStayDuration = isAutonomous
            ? Double.random(in: 18.0...30.0, using: &prng)
            : 0.0
        self.autonomousCourseOffsetTarget = 0.0
        self.autonomousCourseChangeTimer = isAutonomous
            ? Double.random(in: 2.5...5.0, using: &prng)
            : 0.0
        self.bobbingPhase = Double.random(in: 0...(2 * .pi), using: &prng)
        self.wanderAngle = Double.random(in: -Double.pi...Double.pi, using: &prng)
        self.rng = prng

        switch type {
        case .swan:
            let defaultSpeed = speed ?? 24.0
            self.speed = defaultSpeed
            self.velocity = velocity ?? PondVector.fromAngle(heading, length: defaultSpeed)
            self.radius = radius ?? 53.0
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
            if isAutonomous {
                if departureTarget == nil && age >= autonomousStayDuration {
                    departureTarget = chooseDepartureTarget(in: bounds)
                }

                let desiredHeading: Double
                if let departureTarget {
                    desiredHeading = (departureTarget - position).angle
                } else {
                    // Change the long-term course in small eased steps for a natural wandering path.
                    autonomousCourseChangeTimer -= dt
                    if autonomousCourseChangeTimer <= 0.0 {
                        autonomousCourseOffsetTarget = Double.random(in: -0.85...0.85, using: &rng)
                        autonomousCourseChangeTimer = Double.random(in: 3.0...7.0, using: &rng)
                    }
                    let response = min(1.0, dt * 0.24)
                    autonomousCourseOffset += (autonomousCourseOffsetTarget - autonomousCourseOffset) * response
                    let ripple = sin(age * 0.22 + bobbingPhase) * 0.10
                    let courseHeading = normalizeAngle(cruiseHeading + autonomousCourseOffset + ripple)
                    let course = PondVector.fromAngle(courseHeading, length: speed)
                    let boundaryForce = bounds.boundaryAvoidanceForce(
                        for: position,
                        heading: heading,
                        strength: 7.0,
                        marginOverride: radius + 75.0
                    )
                    desiredHeading = (course + boundaryForce * 1.4).angle
                }

                // Limit the turn rate so the body follows the course without abrupt heading changes.
                let difference = normalizeAngle(desiredHeading - heading)
                let maxTurn = (departureTarget == nil ? 0.48 : 0.62) * dt
                heading = normalizeAngle(heading + min(max(difference, -maxTurn), maxTurn))

                let speedVariation = 0.88 + 0.12 * (0.5 + 0.5 * sin(age * 0.43 + bobbingPhase))
                velocity = PondVector.fromAngle(heading, length: speed * speedVariation)
                position += velocity * dt
                break
            }

            // Manually-created swans glide with soft boundary avoidance.
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

    /// Whether the visitor's visible footprint overlaps the pond rectangle.
    public func overlapsPond(_ bounds: PondBounds) -> Bool {
        let extent = type == .swan ? radius + 35.0 : radius
        return position.x + extent >= bounds.minX && position.x - extent <= bounds.maxX &&
            position.y + extent >= bounds.minY && position.y - extent <= bounds.maxY
    }

    /// Autonomous visitors are removed only after their full artwork has cleared the pond.
    public func hasCompletelyExited(_ bounds: PondBounds) -> Bool {
        isAutonomous && hasEnteredPond && !overlapsPond(bounds)
    }

    private mutating func chooseDepartureTarget(in bounds: PondBounds) -> PondVector {
        let distancesToEdges = [position.x, bounds.width - position.x, position.y, bounds.height - position.y]
        let nearestEdge = distancesToEdges.enumerated().min { $0.element < $1.element }?.offset ?? 0
        let margin = radius + 55.0

        switch nearestEdge {
        case 0:
            return PondVector(x: -margin, y: Double.random(in: bounds.height * 0.18...bounds.height * 0.82, using: &rng))
        case 1:
            return PondVector(x: bounds.width + margin, y: Double.random(in: bounds.height * 0.18...bounds.height * 0.82, using: &rng))
        case 2:
            return PondVector(x: Double.random(in: bounds.width * 0.18...bounds.width * 0.82, using: &rng), y: -margin)
        default:
            return PondVector(x: Double.random(in: bounds.width * 0.18...bounds.width * 0.82, using: &rng), y: bounds.height + margin)
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
