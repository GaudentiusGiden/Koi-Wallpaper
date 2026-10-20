import Foundation

public enum KoiBehaviorState: String, Sendable {
    case wandering = "Wandering"
    case seekingFood = "Seeking Food"
    case investigatingClick = "Investigating Click"
}

/// Represents an individual koi fish with natural swimming physics,
/// autonomous steering (wandering, boundary avoidance, separation),
/// and sinusoidal spine articulation.
public struct KoiFish: Identifiable, Sendable {
    public let id: UUID
    public let variety: KoiVariety
    public var position: PondVector
    public var velocity: PondVector
    public var heading: Double // Radians: -pi to pi
    public var speed: Double
    public let baseSpeed: Double
    public let maxSpeed: Double
    public let maxTurnRate: Double // Radians per second
    public let length: Double
    public var width: Double { length * 0.28 }

    public var wigglePhase: Double
    public var wiggleFrequency: Double
    public var spineCurvature: Double // Range -1.0 to 1.0 (body flex)

    public var wanderAngle: Double
    public var rng: SeededRandomNumberGenerator
    public private(set) var state: KoiBehaviorState
    public private(set) var currentTarget: PondVector?
    public private(set) var targetDurationRemaining: Double

    public init(
        id: UUID = UUID(),
        variety: KoiVariety,
        position: PondVector,
        heading: Double = 0.0,
        length: Double = 48.0,
        baseSpeed: Double = 50.0,
        maxSpeed: Double = 120.0,
        maxTurnRate: Double = 2.4,
        seed: UInt64? = nil
    ) {
        self.id = id
        self.variety = variety
        self.position = position
        self.heading = normalizeAngle(heading)
        self.baseSpeed = baseSpeed
        self.maxSpeed = maxSpeed
        self.maxTurnRate = maxTurnRate
        self.speed = baseSpeed
        self.velocity = PondVector.fromAngle(heading, length: baseSpeed)
        self.length = length

        let initialSeed = seed ?? UInt64(truncatingIfNeeded: id.hashValue)
        var prng = SeededRandomNumberGenerator(seed: initialSeed)
        self.wigglePhase = Double.random(in: 0...(2 * .pi), using: &prng)
        self.wiggleFrequency = 6.0
        self.spineCurvature = 0.0
        self.wanderAngle = Double.random(in: -Double.pi...Double.pi, using: &prng)
        self.rng = prng

        self.state = .wandering
        self.currentTarget = nil
        self.targetDurationRemaining = 0.0
    }

    /// The coordinate of the koi's mouth (front of head).
    public var mouthPosition: PondVector {
        let mouthOffset = length * 0.46
        return position + PondVector.fromAngle(heading, length: mouthOffset)
    }

    public var mouthRadius: Double {
        length * 0.16
    }

    /// Maximum physical radius from the fish position to the furthest extent of artwork
    /// (mouth 0.48L, tail tip 0.72L, pectoral fins 0.15L, plus swimming articulation).
    public var physicalRadius: Double {
        length * 0.72 + 6.0
    }

    /// Articulated spine control points in fish local space, shared identically between
    /// simulation collision geometry and visual CoreGraphics vector rendering.
    public static func localSpinePoints(
        length: Double,
        flex: Double
    ) -> (p0: PondVector, p1: PondVector, p2: PondVector, p3: PondVector, p4: PondVector, p5: PondVector, p6: PondVector) {
        (
            p0: PondVector(x: length * 0.48, y: 0.0),
            p1: PondVector(x: length * 0.32, y: 0.0),
            p2: PondVector(x: length * 0.12, y: flex * 1.5),
            p3: PondVector(x: -length * 0.10, y: flex * 3.5),
            p4: PondVector(x: -length * 0.30, y: flex * 6.5),
            p5: PondVector(x: -length * 0.46, y: flex * 10.5),
            p6: PondVector(x: -length * 0.68, y: flex * 15.0)
        )
    }

    /// Articulated tapered body capsules in pond world coordinates covering the solid torso
    /// from mouth (p0) to caudal peduncle (p5). Used for exact collision detection and separation.
    public var bodyCapsules: [KoiBodyCapsule] {
        let hw = width * 0.5
        let spine = KoiFish.localSpinePoints(length: length, flex: spineCurvature)

        let cosH = cos(heading)
        let sinH = sin(heading)

        @inline(__always)
        func toWorld(_ local: PondVector) -> PondVector {
            PondVector(
                x: position.x + (local.x * cosH - local.y * sinH),
                y: position.y + (local.x * sinH + local.y * cosH)
            )
        }

        let wp0 = toWorld(spine.p0)
        let wp1 = toWorld(spine.p1)
        let wp2 = toWorld(spine.p2)
        let wp3 = toWorld(spine.p3)
        let wp4 = toWorld(spine.p4)
        let wp5 = toWorld(spine.p5)

        let r0 = hw * 0.20 // Snout tip
        let r1 = hw * 0.70 // Head / Eyes
        let r2 = hw * 1.00 // Shoulder (maximum width)
        let r3 = hw * 0.85 // Mid-body
        let r4 = hw * 0.48 // Lower flank
        let r5 = hw * 0.18 // Tail wrist (caudal peduncle)

        return [
            KoiBodyCapsule(start: wp0, end: wp1, startRadius: r0, endRadius: r1),
            KoiBodyCapsule(start: wp1, end: wp2, startRadius: r1, endRadius: r2),
            KoiBodyCapsule(start: wp2, end: wp3, startRadius: r2, endRadius: r3),
            KoiBodyCapsule(start: wp3, end: wp4, startRadius: r3, endRadius: r4),
            KoiBodyCapsule(start: wp4, end: wp5, startRadius: r4, endRadius: r5)
        ]
    }

    /// Returns true if this koi's solid body silhouette penetrates another koi's body.
    public func intersectsBody(of other: KoiFish) -> Bool {
        KoiSpineGeometry.checkBodyIntersection(fish1: self, fish2: other)
    }

    /// Evaluates detailed geometric body collision against another koi.
    public func bodyCollision(with other: KoiFish, safetyMargin: Double = 0.0) -> FishBodyCollision {
        KoiSpineGeometry.testBodyCollision(fish1: self, fish2: other, safetyMargin: safetyMargin)
    }

    /// Sets a temporary attraction target (e.g. water ripple or food pellet).
    public mutating func setTarget(_ target: PondVector, state: KoiBehaviorState, duration: Double) {
        self.currentTarget = target
        self.state = state
        self.targetDurationRemaining = duration
    }

    public mutating func clearTarget() {
        self.currentTarget = nil
        self.state = .wandering
        self.targetDurationRemaining = 0.0
    }

    /// Main physics and steering step for the koi fish.
    public mutating func update(
        dt: Double,
        bounds: PondBounds,
        allFish: [KoiFish],
        nearestFood: PondVector?
    ) {
        // 1. Target Evaluation
        if state == .seekingFood {
            if let food = nearestFood {
                // Update target coordinate to the assigned food pellet
                self.currentTarget = food
                self.targetDurationRemaining = 4.0
            } else {
                // No food remaining, immediately return to wandering
                clearTarget()
            }
        }

        if let target = currentTarget {
            targetDurationRemaining -= dt
            let dist = position.distance(to: target)
            if targetDurationRemaining <= 0.0 || dist < (mouthRadius + 6.0) {
                clearTarget()
            }
        }

        // 2. Compute Steering Forces
        var steeringForce = PondVector.zero

        // A. Wander Force
        wanderAngle += Double.random(in: -1.2...1.2, using: &rng) * dt * 3.0
        wanderAngle = normalizeAngle(wanderAngle)
        let wanderCircleCenter = position + PondVector.fromAngle(heading, length: 70.0)
        let wanderDisplacement = PondVector.fromAngle(heading + wanderAngle, length: 35.0)
        let wanderForce = (wanderCircleCenter + wanderDisplacement - position).normalized() * 0.8
        steeringForce += wanderForce

        // B. Target Seeking Force (if active)
        var targetPull = PondVector.zero
        if let target = currentTarget {
            let toTarget = (target - position)
            let dist = toTarget.length
            if dist > 0.001 {
                let arrivalRamp = min(1.0, max(0.25, dist / 80.0))
                let baseSeek = (state == .seekingFood) ? 2.4 : 1.8
                targetPull = toTarget.normalized() * (baseSeek * arrivalRamp)
            }
        }

        // C. Separation Force (maintain space between koi; hard physical barrier when close)
        let socialRadius = length * 1.5
        let physicalBarrier = length * 0.90
        var separationForce = PondVector.zero
        var obstacleAhead = false
        var closestNeighborDist = Double.infinity
        let forwardVector = PondVector.fromAngle(heading, length: 1.0)

        for other in allFish where other.id != self.id {
            let diff = position - other.position
            let dist = diff.length
            guard dist > 0.001 else { continue }
            closestNeighborDist = min(closestNeighborDist, dist)

            if dist < physicalBarrier {
                // Predictive physical repulsion steering: hyperbolic curve strongly deflects heading away from neighbors
                let ratio = dist / physicalBarrier
                let emergencyWeight = 6.0 * (1.0 - ratio) / max(0.12, ratio)
                separationForce += diff.normalized() * emergencyWeight
            } else if dist < socialRadius {
                // Gentle social flocking spacing
                let norm = (socialRadius - dist) / socialRadius
                let weight = norm * norm * 3.5
                separationForce += diff.normalized() * weight
            }

            // Check if neighbor is directly in front of this fish in its swim path
            if dist < physicalBarrier * 1.25 {
                let toOtherNorm = (other.position - position) / dist
                if forwardVector.dot(with: toOtherNorm) > 0.50 {
                    obstacleAhead = true
                }
            }
        }

        // If neighbor is uncomfortably close, soften target pull to prioritize personal space
        if closestNeighborDist < physicalBarrier {
            targetPull = targetPull * 0.35
        }
        steeringForce += targetPull
        steeringForce += separationForce

        // D. Boundary Avoidance Force (soft margin from pond edges based on physical size)
        let effectiveMargin = max(bounds.margin, physicalRadius + 20.0)
        let boundaryForce = bounds.boundaryAvoidanceForce(
            for: position,
            heading: heading,
            strength: 5.0,
            marginOverride: effectiveMargin
        )
        steeringForce += boundaryForce

        // 3. Smooth Heading & Turning
        let desiredHeading: Double
        if steeringForce.lengthSquared > 0.0001 {
            desiredHeading = steeringForce.angle
        } else {
            desiredHeading = heading
        }

        let angleDiff = normalizeAngle(desiredHeading - heading)
        let maxTurnThisStep = maxTurnRate * dt
        let turnStep = min(max(angleDiff, -maxTurnThisStep), maxTurnThisStep)
        heading = normalizeAngle(heading + turnStep)

        // 4. Smooth Speed Control
        var targetSpeed: Double
        switch state {
        case .wandering:
            targetSpeed = baseSpeed
        case .seekingFood:
            targetSpeed = maxSpeed
        case .investigatingClick:
            targetSpeed = baseSpeed * 1.4
        }

        // If another fish is directly ahead in our path, yield and decelerate to avoid collision
        if obstacleAhead {
            targetSpeed = min(targetSpeed, baseSpeed * 0.35)
        }

        let speedChangeRate = (targetSpeed > speed) ? 60.0 : 40.0
        let speedDiff = targetSpeed - speed
        speed += min(max(speedDiff, -speedChangeRate * dt), speedChangeRate * dt)

        // 5. Update Position and Hard Clamp
        velocity = PondVector.fromAngle(heading, length: speed)
        position += velocity * dt

        // Keep strictly inside bounds based on full fish artwork extent (mouth, tail, and fins)
        let maxAllowedInset = min(bounds.width * 0.45, bounds.height * 0.45)
        let inset = min(physicalRadius, maxAllowedInset)
        position = bounds.clamped(position, inset: inset)

        // 6. Sinusoidal Swimming Wiggle & Spine Curvature
        let wiggleRate = (speed / baseSpeed) * wiggleFrequency
        wigglePhase += wiggleRate * dt
        if wigglePhase > 2.0 * .pi {
            wigglePhase -= 2.0 * .pi
        }

        // Turn curvature bias gives realistic body flexion during turns
        let turnBias = (turnStep / (maxTurnThisStep + 0.0001)) * 0.35
        let naturalWiggle = sin(wigglePhase) * 0.45
        spineCurvature = min(max(turnBias + naturalWiggle, -1.0), 1.0)
    }
}
