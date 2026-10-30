import Foundation

/// Visual plumage variants for the Japanese pond duck.
public enum DuckPaletteVariant: String, Codable, CaseIterable, Sendable {
    /// Male Mandarin Duck (Oshidori) with chestnut breast, emerald-violet crest, and orange sails.
    case mandarin = "mandarin"
    /// Chubby White Call Duck / Pekin with warm ivory plumage and vivid orange spatula bill.
    case whitePekin = "whitePekin"
}

/// The type of visitors that can appear on the surface of the pond.
public enum PondVisitorType: String, Codable, CaseIterable, Sendable {
    case swan = "swan"
    case ball = "ball"
    case duck = "duck"

    public var displayName: String {
        switch self {
        case .swan: return "Angsa (Regal Swan)"
        case .ball: return "Bola (Temari Ball)"
        case .duck: return "Bebek (Nagomi Duck)"
        }
    }
}

/// Represents an interactive surface visitor (such as an elegant swimming swan,
/// a Japanese duck, or a floating Japanese Temari ball) that influences the motion and curiosity of koi fish.
public struct PondVisitor: Identifiable, Sendable {
    public let id: UUID
    public let type: PondVisitorType
    public var duckVariant: DuckPaletteVariant
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
    public var paddlePhase: Double
    public var paddleSpeed: Double
    public var neckNodPhase: Double
    public var isDabbling: Bool
    public var dabbleTimer: Double
    public var isStartled: Bool
    public var startleTimer: Double
    public var targetPelletId: UUID?
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
        duckVariant: DuckPaletteVariant = .mandarin,
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
        self.duckVariant = duckVariant
        self.isAutonomous = isAutonomous
        self.hasEnteredPond = true
        self.position = position
        self.heading = normalizeAngle(heading)
        self.cruiseHeading = normalizeAngle(heading)
        self.lifetime = lifetime
        self.age = 0.0
        self.departureTarget = nil
        self.autonomousCourseOffset = 0.0
        self.paddlePhase = 0.0
        self.neckNodPhase = 0.0
        self.isDabbling = false
        self.dabbleTimer = 0.0
        self.isStartled = false
        self.startleTimer = 0.0
        self.targetPelletId = nil

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
            self.bobbingSpeed = 2.0
            self.paddleSpeed = 2.4
        case .duck:
            let defaultSpeed = speed ?? 28.0
            self.speed = defaultSpeed
            self.velocity = velocity ?? PondVector.fromAngle(heading, length: defaultSpeed)
            self.radius = radius ?? 42.0
            self.interactionRadius = interactionRadius ?? 160.0
            self.bobbingSpeed = 2.6
            self.paddleSpeed = 4.0
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
            self.paddleSpeed = 0.0
        }
    }

    /// Main physics update step for the visitor.
    public mutating func update(dt: Double, bounds: PondBounds) {
        age += dt
        bobbingPhase += bobbingSpeed * dt
        if bobbingPhase > 2.0 * .pi {
            bobbingPhase -= 2.0 * .pi
        }

        let effectivePaddleSpeed = isStartled ? paddleSpeed * 2.2 : (isDabbling ? paddleSpeed * 1.5 : paddleSpeed)
        paddlePhase += effectivePaddleSpeed * dt
        if paddlePhase > 2.0 * .pi {
            paddlePhase -= 2.0 * .pi
        }

        neckNodPhase += 1.8 * dt
        if neckNodPhase > 2.0 * .pi {
            neckNodPhase -= 2.0 * .pi
        }

        if startleTimer > 0.0 {
            startleTimer = max(0.0, startleTimer - dt)
            if startleTimer == 0.0 {
                isStartled = false
            }
        }

        if dabbleTimer > 0.0 {
            dabbleTimer = max(0.0, dabbleTimer - dt)
            if dabbleTimer == 0.0 {
                isDabbling = false
            }
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

                // Keep the swan inside the pond throughout its roaming phase.
                if departureTarget == nil {
                    let inset = min(radius + 8.0, min(bounds.width, bounds.height) * 0.45)
                    var reflectedAtEdge = false

                    if position.x < inset {
                        position.x = inset
                        heading = normalizeAngle(.pi - heading)
                        reflectedAtEdge = true
                    } else if position.x > bounds.width - inset {
                        position.x = bounds.width - inset
                        heading = normalizeAngle(.pi - heading)
                        reflectedAtEdge = true
                    }

                    if position.y < inset {
                        position.y = inset
                        heading = normalizeAngle(-heading)
                        reflectedAtEdge = true
                    } else if position.y > bounds.height - inset {
                        position.y = bounds.height - inset
                        heading = normalizeAngle(-heading)
                        reflectedAtEdge = true
                    }

                    if reflectedAtEdge {
                        velocity = PondVector.fromAngle(heading, length: velocity.length)
                    }
                }
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

        case .duck:
            if isDabbling {
                // When dabbling to feed, damp velocity rapidly and remain largely stationary
                velocity = velocity * max(0.0, 1.0 - 4.5 * dt)
                position += velocity * dt
                position = bounds.clamped(position, inset: radius + 8.0)
                break
            }

            let effectiveSpeed = isStartled ? speed * 1.85 : speed

            if isAutonomous {
                if departureTarget == nil && age >= autonomousStayDuration {
                    departureTarget = chooseDepartureTarget(in: bounds)
                }

                let desiredHeading: Double
                if let departureTarget {
                    desiredHeading = (departureTarget - position).angle
                } else {
                    autonomousCourseChangeTimer -= dt
                    if autonomousCourseChangeTimer <= 0.0 {
                        autonomousCourseOffsetTarget = Double.random(in: -1.1...1.1, using: &rng)
                        autonomousCourseChangeTimer = Double.random(in: 2.2...5.5, using: &rng)
                    }
                    let response = min(1.0, dt * (isStartled ? 0.60 : 0.35))
                    autonomousCourseOffset += (autonomousCourseOffsetTarget - autonomousCourseOffset) * response
                    let ripple = sin(age * 0.35 + bobbingPhase) * 0.12
                    let courseHeading = normalizeAngle(cruiseHeading + autonomousCourseOffset + ripple)
                    let course = PondVector.fromAngle(courseHeading, length: effectiveSpeed)
                    let boundaryForce = bounds.boundaryAvoidanceForce(
                        for: position,
                        heading: heading,
                        strength: 7.5,
                        marginOverride: radius + 55.0
                    )
                    desiredHeading = (course + boundaryForce * 1.5).angle
                }

                let difference = normalizeAngle(desiredHeading - heading)
                let maxTurn = (departureTarget == nil ? (isStartled ? 1.6 : 0.75) : 0.95) * dt
                heading = normalizeAngle(heading + min(max(difference, -maxTurn), maxTurn))

                let speedVariation = isStartled ? 1.0 : (0.85 + 0.15 * (0.5 + 0.5 * sin(age * 0.6 + bobbingPhase)))
                velocity = PondVector.fromAngle(heading, length: effectiveSpeed * speedVariation)
                position += velocity * dt

                if departureTarget == nil {
                    let inset = min(radius + 8.0, min(bounds.width, bounds.height) * 0.45)
                    var reflectedAtEdge = false

                    if position.x < inset {
                        position.x = inset
                        heading = normalizeAngle(.pi - heading)
                        reflectedAtEdge = true
                    } else if position.x > bounds.width - inset {
                        position.x = bounds.width - inset
                        heading = normalizeAngle(.pi - heading)
                        reflectedAtEdge = true
                    }

                    if position.y < inset {
                        position.y = inset
                        heading = normalizeAngle(-heading)
                        reflectedAtEdge = true
                    } else if position.y > bounds.height - inset {
                        position.y = bounds.height - inset
                        heading = normalizeAngle(-heading)
                        reflectedAtEdge = true
                    }

                    if reflectedAtEdge {
                        velocity = PondVector.fromAngle(heading, length: velocity.length)
                    }
                }
                break
            }

            // Manually spawned duck roaming
            wanderAngle += Double.random(in: -0.4...0.4, using: &rng) * dt * 1.8
            wanderAngle = normalizeAngle(wanderAngle)

            let forward = PondVector.fromAngle(heading, length: effectiveSpeed)
            let boundaryForce = bounds.boundaryAvoidanceForce(
                for: position,
                heading: heading,
                strength: 6.5,
                marginOverride: radius + 35.0
            )
            let steer = forward + boundaryForce * 1.5
            if steer.lengthSquared > 0.0001 {
                let desiredHeading = steer.angle
                let diff = normalizeAngle(desiredHeading - heading)
                let maxTurn = (isStartled ? 2.8 : 1.8) * dt
                let turn = min(max(diff, -maxTurn), maxTurn)
                heading = normalizeAngle(heading + turn)
            }
            velocity = PondVector.fromAngle(heading, length: effectiveSpeed)
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

    /// Triggers a sudden startle panic reaction away from a disturbance point (for ducks).
    public mutating func triggerStartle(awayFrom: PondVector) {
        guard type == .duck else { return } // Swans remain Zen Neutral
        isStartled = true
        startleTimer = 2.6
        isDabbling = false
        dabbleTimer = 0.0
        targetPelletId = nil
        let diff = position - awayFrom
        let awayAngle = diff.lengthSquared > 0.001 ? diff.angle : heading + .pi
        heading = normalizeAngle(awayAngle)
        velocity = PondVector.fromAngle(heading, length: speed * 1.85)
    }

    /// Triggers a dabbling / duck-diving feeding action in place (for ducks).
    public mutating func triggerDabble(duration: Double = 2.4) {
        guard type == .duck else { return }
        isDabbling = true
        dabbleTimer = duration
        velocity = velocity * 0.12
    }

    /// Whether the visitor's visible footprint overlaps the pond rectangle.
    public func overlapsPond(_ bounds: PondBounds) -> Bool {
        let extent: Double
        switch type {
        case .swan: extent = radius + 35.0
        case .duck: extent = radius + 20.0
        case .ball: extent = radius
        }
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
