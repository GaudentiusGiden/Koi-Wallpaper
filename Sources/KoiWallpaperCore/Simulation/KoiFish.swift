import Foundation

public enum KoiBehaviorState: String, Sendable {
    case wandering = "Wandering"
    case seekingFood = "Seeking Food"
    case investigatingClick = "Investigating Click"
    case investigatingVisitor = "Investigating Visitor"
    case followingInsect = "Following Insect"
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
    public internal(set) var length: Double
    public let bodyWidthRatio: Double
    public var width: Double { length * bodyWidthRatio }

    public var wigglePhase: Double
    public var wiggleFrequency: Double
    public var spineCurvature: Double // Range -1.0 to 1.0 (body flex)

    public var wanderAngle: Double
    public var rng: SeededRandomNumberGenerator
    public private(set) var state: KoiBehaviorState
    public private(set) var currentTarget: PondVector?
    public private(set) var targetDurationRemaining: Double
    public private(set) var targetVisitorId: UUID?
    public private(set) var targetInsectId: UUID?
    public var traits: FishTraits

    public init(
        id: UUID = UUID(),
        variety: KoiVariety,
        position: PondVector,
        heading: Double = 0.0,
        length: Double = 48.0,
        baseSpeed: Double = 50.0,
        maxSpeed: Double = 120.0,
        maxTurnRate: Double = 2.4,
        seed: UInt64? = nil,
        bodyWidthRatio: Double = 0.28,
        traits: FishTraits? = nil
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
        self.bodyWidthRatio = min(0.4, max(0.2, bodyWidthRatio))
        self.traits = traits ?? FishTraits.defaultTraits(for: variety)

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
        self.targetVisitorId = nil
        self.targetInsectId = nil
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
        // A fixed envelope covers the complete tail stroke. A radius based on the
        // current stroke could grow after the position clamp later in update().
        let tailY = length * 15.0 / 48.0 + width * 0.42
        return max(length * 0.72 + 6.0, hypot(length * 0.70, tailY) + 2.0)
    }

    /// Articulated spine control points in fish local space, shared identically between
    /// simulation collision geometry and visual CoreGraphics vector rendering.
    /// When `wigglePhase` is provided, a smooth, natural traveling wave creates fluid S-curve swimming.
    public static func localSpinePoints(
        length: Double,
        flex: Double,
        wigglePhase: Double? = nil
    ) -> (p0: PondVector, p1: PondVector, p2: PondVector, p3: PondVector, p4: PondVector, p5: PondVector, p6: PondVector) {
        let bend = flex * length / 48.0
        let scale = length / 48.0

        let w2: Double
        let w3: Double
        let w4: Double
        let w5: Double
        let w6: Double

        if let phase = wigglePhase {
            // Fluid backward-traveling undulatory wave:
            // Amplitudes and phase lags create a gentle, natural S-curve swimming stroke.
            w2 = sin(phase - 0.25) * 0.35 * scale
            w3 = sin(phase - 0.75) * 1.05 * scale
            w4 = sin(phase - 1.45) * 2.20 * scale
            w5 = sin(phase - 2.15) * 3.60 * scale
            w6 = sin(phase - 2.85) * 5.60 * scale
        } else {
            w2 = 0.0
            w3 = 0.0
            w4 = 0.0
            w5 = 0.0
            w6 = 0.0
        }

        return (
            p0: PondVector(x: length * 0.48, y: 0.0),
            p1: PondVector(x: length * 0.32, y: 0.0),
            p2: PondVector(x: length * 0.12, y: bend * 1.5 + w2),
            p3: PondVector(x: -length * 0.10, y: bend * 3.5 + w3),
            p4: PondVector(x: -length * 0.30, y: bend * 6.5 + w4),
            p5: PondVector(x: -length * 0.46, y: bend * 10.5 + w5),
            p6: PondVector(x: -length * 0.68, y: bend * 15.0 + w6)
        )
    }

    /// Articulated tapered body capsules in pond world coordinates covering the solid torso
    /// from mouth (p0) to caudal peduncle (p5). Used for exact collision detection and separation.
    public var bodyCapsules: [KoiBodyCapsule] {
        let hw = width * 0.5
        let spine = KoiFish.localSpinePoints(length: length, flex: spineCurvature, wigglePhase: wigglePhase)

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

    /// Sets a temporary attraction target (e.g. water ripple, food pellet, surface visitor, or insect).
    public mutating func setTarget(_ target: PondVector, state: KoiBehaviorState, duration: Double, visitorId: UUID? = nil, insectId: UUID? = nil) {
        self.currentTarget = target
        self.state = state
        self.targetDurationRemaining = duration
        self.targetVisitorId = visitorId
        self.targetInsectId = insectId
    }

    /// Smoothly updates a dynamic target position (e.g. flying insect or swimming swan) without resetting duration.
    public mutating func updateMovingTarget(_ target: PondVector) {
        self.currentTarget = target
    }

    public mutating func clearTarget() {
        self.currentTarget = nil
        self.state = .wandering
        self.targetDurationRemaining = 0.0
        self.targetVisitorId = nil
        self.targetInsectId = nil
    }

    /// Main physics and steering step for the koi fish.
    public mutating func update(
        dt: Double,
        bounds: PondBounds,
        allFish: [KoiFish],
        nearestFood: PondVector?,
        mood: PondMood = .calm
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
            let arrivalDist: Double
            switch state {
            case .investigatingVisitor:
                arrivalDist = mouthRadius + 14.0
            case .followingInsect:
                arrivalDist = mouthRadius + 10.0
            default:
                arrivalDist = mouthRadius + 6.0
            }
            if targetDurationRemaining <= 0.0 || dist < arrivalDist {
                clearTarget()
            }
        }

        // 2. Compute Steering Forces
        var steeringForce = PondVector.zero

        // A. Wander Force: Calm, smooth wandering with gentle drift
        wanderAngle += Double.random(in: -0.4...0.4, using: &rng) * dt * 1.6
        wanderAngle = normalizeAngle(wanderAngle)
        let wanderCircleCenter = position + PondVector.fromAngle(heading, length: 70.0)
        let wanderDisplacement = PondVector.fromAngle(heading + wanderAngle, length: 32.0)
        let wanderForce = (wanderCircleCenter + wanderDisplacement - position).normalized() * 0.75
        steeringForce += wanderForce

        // B. Target Seeking Force (if active)
        var targetPull = PondVector.zero
        if let target = currentTarget {
            let toTarget = (target - position)
            let dist = toTarget.length
            if dist > 0.001 {
                let arrivalRamp = min(1.0, max(0.25, dist / 80.0))
                let baseSeek: Double
                switch state {
                case .seekingFood: baseSeek = 2.4
                case .investigatingClick: baseSeek = 1.8
                case .investigatingVisitor: baseSeek = 1.9
                case .followingInsect: baseSeek = 1.8
                case .wandering: baseSeek = 1.5
                }
                targetPull = toTarget.normalized() * (baseSeek * arrivalRamp)
            }
        }

        // C. Separation Force (maintain space between koi; hard physical barrier when close)
        let socialRadius = length * 1.5
        let physicalBarrier = length * 0.90
        var separationForce = PondVector.zero
        var forwardObstacleCloseness = 0.0
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

            // Smooth evaluation of neighbor in front of this fish in its swim path
            if dist < physicalBarrier * 1.35 {
                let toOtherNorm = (other.position - position) / dist
                let dot = forwardVector.dot(with: toOtherNorm)
                if dot > 0.35 {
                    let distFactor = 1.0 - (dist / (physicalBarrier * 1.35))
                    let alignmentFactor = (dot - 0.35) / 0.65
                    let closeness = distFactor * alignmentFactor
                    forwardObstacleCloseness = max(forwardObstacleCloseness, closeness)
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

        // 3. Smooth Heading & Shortest Turn Interpolation
        let desiredHeading: Double
        if steeringForce.lengthSquared > 0.0001 {
            desiredHeading = steeringForce.angle
        } else {
            desiredHeading = heading
        }

        let angleDiff = normalizeAngle(desiredHeading - heading)
        let avoidanceUrgency = min(1.0, (separationForce.length / 2.5) + (boundaryForce.length / 2.5))
        let stateUrgency: Double
        switch state {
        case .seekingFood: stateUrgency = 1.0
        case .investigatingClick: stateUrgency = 0.5
        case .investigatingVisitor: stateUrgency = 0.6
        case .followingInsect: stateUrgency = 0.55
        case .wandering: stateUrgency = 0.0
        }
        let urgency = max(avoidanceUrgency, stateUrgency)
        let calmTurnRate = max(0.9, maxTurnRate * 0.50)
        let baseTurnRate = calmTurnRate + (maxTurnRate - calmTurnRate) * urgency
        let moodTurnFactor = (mood == .playful ? 1.15 : 1.0)
        let effectiveTurnRate = baseTurnRate * traits.agility * moodTurnFactor

        let maxTurnThisStep = effectiveTurnRate * dt
        let absDiff = abs(angleDiff)
        let easeFactor = min(1.0, max(0.12, absDiff / 0.28))
        let turnStepMag = min(absDiff, maxTurnThisStep * easeFactor)
        let turnStep = (angleDiff >= 0.0 ? 1.0 : -1.0) * turnStepMag
        heading = normalizeAngle(heading + turnStep)

        // 4. Smooth Speed Control
        var targetSpeed: Double
        let moodSpeedMultiplier = (mood == .playful ? 1.25 : 1.0)
        switch state {
        case .wandering:
            targetSpeed = baseSpeed * moodSpeedMultiplier
        case .seekingFood:
            let eagernessBonus = 0.90 + traits.boldness * 0.20
            targetSpeed = maxSpeed * moodSpeedMultiplier * eagernessBonus
        case .investigatingClick:
            targetSpeed = baseSpeed * 1.35 * moodSpeedMultiplier
        case .investigatingVisitor:
            targetSpeed = baseSpeed * 1.25 * moodSpeedMultiplier
        case .followingInsect:
            targetSpeed = baseSpeed * 1.30 * moodSpeedMultiplier
        }

        // Smoothly yield and decelerate if another fish is directly ahead in our path
        if forwardObstacleCloseness > 0.001 {
            let slowdownFactor = 1.0 - (forwardObstacleCloseness * 0.60)
            targetSpeed = min(targetSpeed, baseSpeed * slowdownFactor)
        }

        let speedChangeRate = (targetSpeed > speed) ? 50.0 : 35.0
        let speedDiff = targetSpeed - speed
        let maxSpeedStep = speedChangeRate * dt
        speed += min(max(speedDiff, -maxSpeedStep), maxSpeedStep)

        // 5. Update Position and Hard Clamp
        velocity = PondVector.fromAngle(heading, length: speed)
        position += velocity * dt

        // Keep strictly inside bounds based on full fish artwork extent (mouth, tail, and fins)
        let maxAllowedInset = min(bounds.width * 0.45, bounds.height * 0.45)
        let inset = min(physicalRadius, maxAllowedInset)
        position = bounds.clamped(position, inset: inset)

        // 6. Sinusoidal Swimming Wiggle & Smooth Spine Curvature
        let wiggleMoodFactor = (mood == .playful ? 1.20 : 1.0)
        let wiggleRate = (speed / baseSpeed) * wiggleFrequency * wiggleMoodFactor
        wigglePhase += wiggleRate * dt
        if wigglePhase > 2.0 * .pi {
            wigglePhase -= 2.0 * .pi
        }

        // Smooth turn curvature (body flexion) during turns
        let targetCurvature = min(max((turnStep / (maxTurnThisStep + 0.0001)) * 0.45, -0.65), 0.65)
        let curvatureRelaxRate = 5.5
        spineCurvature += (targetCurvature - spineCurvature) * min(1.0, curvatureRelaxRate * dt)
        spineCurvature = min(max(spineCurvature, -1.0), 1.0)
    }
}
