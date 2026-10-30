import Foundation

/// Represents an individual small decorative schooling fish (medaka / minnow).
public struct DecorativeFishInstance: Sendable {
    public var position: PondVector
    public var velocity: PondVector
    public var heading: Double
    public var turn: Double
    public var lengthRatio: Double
    public var length: Double
    public var halfWidth: Double
    public var localDistance: Double
    public var localAngle: Double
    public var panicTimer: Double
    public var swimPhase: Double
    public let groupIndex: Int
    public let index: Int
    public var wanderPhase: Double
    public var isScout: Bool

    public init(
        position: PondVector,
        velocity: PondVector = .zero,
        heading: Double = 0.0,
        turn: Double = 0.0,
        lengthRatio: Double = 0.020,
        length: Double = 16.0,
        halfWidth: Double = 2.88,
        localDistance: Double = 20.0,
        localAngle: Double = 0.0,
        panicTimer: Double = 0.0,
        swimPhase: Double = 0.0,
        groupIndex: Int = 0,
        index: Int = 0,
        wanderPhase: Double = 0.0,
        isScout: Bool = false
    ) {
        self.position = position
        self.velocity = velocity
        self.heading = heading
        self.turn = turn
        self.lengthRatio = lengthRatio
        self.length = length
        self.halfWidth = halfWidth
        self.localDistance = localDistance
        self.localAngle = localAngle
        self.panicTimer = panicTimer
        self.swimPhase = swimPhase
        self.groupIndex = groupIndex
        self.index = index
        self.wanderPhase = wanderPhase
        self.isScout = isScout
    }
}

/// Represents the behavioral state of a decorative small fish school.
public enum SchoolingMode: String, Sendable {
    /// Loose cruising formation where fish swim in roughly the same direction with comfortable spacing.
    case cohesive
    /// Dispersed / foraging mode where fish scatter and spread out over a wide area, wandering independently.
    case dispersed
}

/// Represents an autonomous school of decorative small fish.
/// Maintains dynamic schooling modes (loose cohesive cruise vs dispersed foraging mencar),
/// active cruising across the pond, generous pairwise separation,
/// and reactive evasion from water splashes (ripples) and large koi fish.
public struct DecorativeSchool: Sendable {
    public static let fishPerSchool = 8
    public static let schoolCount = 3

    public let groupIndex: Int
    public var center: PondVector
    public var velocity: PondVector
    public var heading: Double
    public var cruisingSpeed: Double
    public var targetWaypoint: PondVector
    public var waypointTimer: Double
    public var boundingRadius: Double
    public var fish: [DecorativeFishInstance]
    public var rng: SeededRandomNumberGenerator

    public var mode: SchoolingMode
    public var modeTimer: Double
    public var dispersionFactor: Double

    // MARK: - Tiny Fish Steal (Nagomi Food Swarm)
    public static let tinyFishStealRadius: Double = 70.0
    public static let tinyFishStealChance: Double = 0.55
    public static let tinyFishBite: Double = 0.35

    public init(groupIndex: Int, bounds: PondBounds, seed: UInt64? = nil) {
        self.groupIndex = groupIndex
        let initialSeed = seed ?? UInt64(700 + groupIndex * 443)
        var prng = SeededRandomNumberGenerator(seed: initialSeed)

        let initialNormalizedCenters: [(Double, Double)] = [
            (0.29, 0.34),
            (0.75, 0.30),
            (0.65, 0.73)
        ]
        let norm = initialNormalizedCenters[groupIndex % initialNormalizedCenters.count]
        let initialCenter = PondVector(x: norm.0 * bounds.width, y: norm.1 * bounds.height)

        self.center = initialCenter
        self.heading = Double.random(in: -Double.pi...Double.pi, using: &prng)
        let baseCruisingSpeed = 32.0 + Double(groupIndex) * 4.0
        self.cruisingSpeed = baseCruisingSpeed
        self.velocity = PondVector.fromAngle(self.heading, length: baseCruisingSpeed)
        self.targetWaypoint = initialCenter
        self.waypointTimer = Double.random(in: 4.0...9.0, using: &prng)
        self.rng = prng

        // Stagger initial modes across schools so they don't look synchronized:
        // Group 1 starts dispersed ("mencar") right away across its sector,
        // while Groups 0 & 2 start in loose cohesive mode.
        switch groupIndex % 3 {
        case 1:
            self.mode = .dispersed
            self.modeTimer = Double.random(in: 12.0...20.0, using: &prng)
            self.dispersionFactor = 2.6
            self.boundingRadius = 110.0
        default:
            self.mode = .cohesive
            self.modeTimer = Double.random(in: 8.0...16.0, using: &prng)
            self.dispersionFactor = 1.35
            self.boundingRadius = 75.0
        }

        var instances: [DecorativeFishInstance] = []
        instances.reserveCapacity(Self.fishPerSchool)

        let short = min(bounds.width, bounds.height)

        // Distinct, well-spaced natural schooling formation slots
        // Staggered wedge pattern ensuring zero initial overlap
        let formationOffsets: [(Double, Double)] = [
            (24.0, 0.0),    // Scout leader
            (8.0, -18.0),   // Left wing
            (8.0, 18.0),    // Right wing
            (-10.0, -10.0), // Inner mid-left
            (-10.0, 10.0),  // Inner mid-right
            (-26.0, -24.0), // Flank outer left
            (-26.0, 24.0),  // Flank outer right
            (-32.0, 0.0)    // Rear guard
        ]

        for index in 0..<Self.fishPerSchool {
            let lengthRatio = Double.random(in: 0.016...0.024, using: &self.rng)
            let length = lengthRatio * short
            let halfWidth = length * 0.18
            let slot = formationOffsets[index % formationOffsets.count]
            let localDist = hypot(slot.0, slot.1)
            let localAngle = atan2(slot.1, slot.0)
            let initialSpread = self.dispersionFactor
            let rotOffset = PondVector(
                x: (slot.0 * initialSpread) * cos(self.heading) - (slot.1 * initialSpread) * sin(self.heading),
                y: (slot.0 * initialSpread) * sin(self.heading) + (slot.1 * initialSpread) * cos(self.heading)
            )
            let fishPos = initialCenter + rotOffset
            let initialSwimPhase = Double.random(in: 0...(2 * .pi), using: &self.rng)
            let initialWanderPhase = Double.random(in: 0...(2 * .pi), using: &self.rng)
            let isScout = (index == 0 || index == 5)

            let inst = DecorativeFishInstance(
                position: fishPos,
                velocity: self.velocity,
                heading: self.heading,
                turn: self.heading,
                lengthRatio: lengthRatio,
                length: length,
                halfWidth: halfWidth,
                localDistance: localDist,
                localAngle: localAngle,
                panicTimer: 0.0,
                swimPhase: initialSwimPhase,
                groupIndex: groupIndex,
                index: index,
                wanderPhase: initialWanderPhase,
                isScout: isScout
            )
            instances.append(inst)
        }
        self.fish = instances
        self.pickNewWaypoint(bounds: bounds)
    }

    private mutating func pickNewWaypoint(bounds: PondBounds) {
        let margin = 70.0
        let minX = bounds.minX + margin
        let maxX = bounds.maxX - margin
        let minY = bounds.minY + margin
        let maxY = bounds.maxY - margin

        guard maxX > minX && maxY > minY else {
            targetWaypoint = center
            waypointTimer = 5.0
            return
        }

        // Each school has a distinct home patrolling territory to prevent grouping together:
        // Group 0: West / North-West sector
        // Group 1: East / North-East sector
        // Group 2: South / Center-South sector
        let spanX = maxX - minX
        let spanY = maxY - minY

        let sectorMinX: Double
        let sectorMaxX: Double
        let sectorMinY: Double
        let sectorMaxY: Double

        switch groupIndex % 3 {
        case 0:
            sectorMinX = minX
            sectorMaxX = minX + spanX * 0.52
            sectorMinY = minY
            sectorMaxY = minY + spanY * 0.65
        case 1:
            sectorMinX = minX + spanX * 0.48
            sectorMaxX = maxX
            sectorMinY = minY
            sectorMaxY = minY + spanY * 0.65
        default:
            sectorMinX = minX + spanX * 0.15
            sectorMaxX = minX + spanX * 0.85
            sectorMinY = minY + spanY * 0.40
            sectorMaxY = maxY
        }

        let wx = Double.random(in: sectorMinX...sectorMaxX, using: &rng)
        let wy = Double.random(in: sectorMinY...sectorMaxY, using: &rng)
        targetWaypoint = PondVector(x: wx, y: wy)
        waypointTimer = Double.random(in: 6.0...12.0, using: &rng)
    }

    /// Advances the school physics by a discrete time step.
    /// Evaluates hierarchical threat broadphase against koi and ripples,
    /// performs active roaming wander, and updates schooling cohesion & evasion.
    public mutating func update(
        dt: Double,
        bounds: PondBounds,
        koiFish: [KoiFish],
        ripples: [WaterRipple],
        externalRepulsion: PondVector = .zero
    ) {
        guard dt > 0.0 else { return }

        let short = min(bounds.width, bounds.height)

        // 0. Update Schooling Mode (Loose Cohesion vs Mencar Dispersal Cycle)
        modeTimer -= dt
        if modeTimer <= 0.0 {
            switch mode {
            case .cohesive:
                mode = .dispersed
                modeTimer = Double.random(in: 14.0...24.0, using: &rng)
            case .dispersed:
                mode = .cohesive
                modeTimer = Double.random(in: 9.0...16.0, using: &rng)
            }
        }

        let targetDispersion: Double = (mode == .dispersed) ? 3.0 : 1.35
        let dispersionSpeed = (mode == .dispersed) ? 0.7 : 0.45
        dispersionFactor += (targetDispersion - dispersionFactor) * min(1.0, dt * dispersionSpeed)
        boundingRadius = 45.0 + dispersionFactor * 24.0

        // 1. Update Roaming Waypoint
        waypointTimer -= dt
        if waypointTimer <= 0.0 || center.distanceSquared(to: targetWaypoint) < 30.0 * 30.0 {
            pickNewWaypoint(bounds: bounds)
        }

        // 2. Steer School Centroid towards Waypoint
        let toTarget = targetWaypoint - center
        let distToTarget = toTarget.length
        let desiredVelocity: PondVector
        if distToTarget > 0.001 {
            desiredVelocity = (toTarget / distToTarget) * cruisingSpeed
        } else {
            desiredVelocity = velocity
        }

        // Boundary Repulsion on School Centroid
        var boundarySteering = PondVector.zero
        let edgeMargin = 70.0
        if center.x < bounds.minX + edgeMargin {
            let depth = (bounds.minX + edgeMargin) - center.x
            boundarySteering.x += depth * 1.5
        } else if center.x > bounds.maxX - edgeMargin {
            let depth = center.x - (bounds.maxX - edgeMargin)
            boundarySteering.x -= depth * 1.5
        }
        if center.y < bounds.minY + edgeMargin {
            let depth = (bounds.minY + edgeMargin) - center.y
            boundarySteering.y += depth * 1.5
        } else if center.y > bounds.maxY - edgeMargin {
            let depth = center.y - (bounds.maxY - edgeMargin)
            boundarySteering.y -= depth * 1.5
        }

        let steerT = min(1.0, dt * 1.6)
        velocity = (velocity + (boundarySteering + externalRepulsion) * dt).lerp(to: desiredVelocity, t: steerT)
        center += velocity * dt
        center = bounds.clamped(center, inset: 40.0)

        if velocity.lengthSquared > 1.0 {
            heading = Self.lerpAngle(from: heading, to: velocity.angle, t: min(1.0, dt * 2.8))
        }

        // 3. Hierarchical Threat Broadphase
        // Test ripples within reach of school centroid
        var activeThreatRipples: [WaterRipple] = []
        for r in ripples {
            guard !r.isDead && r.alpha > 0.05 else { continue }
            let maxReach = r.radius + boundingRadius + 80.0
            if center.distanceSquared(to: r.center) < (maxReach * maxReach) {
                activeThreatRipples.append(r)
            }
        }

        // Test Koi within reach of school centroid
        var nearbyKoi: [KoiFish] = []
        for k in koiFish {
            let maxReach = k.physicalRadius + boundingRadius + 110.0
            if center.distanceSquared(to: k.position) < (maxReach * maxReach) {
                nearbyKoi.append(k)
            }
        }

        // 4. Update Individual Fish
        for i in 0..<fish.count {
            fish[i].length = fish[i].lengthRatio * short
            fish[i].halfWidth = fish[i].length * 0.18
            fish[i].wanderPhase += dt * (1.1 + Double(i) * 0.22)

            var fleeForce = PondVector.zero
            var isFleeingThisFrame = false

            // A. Ripple Evasion (Water splash startle)
            for r in activeThreatRipples {
                let diff = fish[i].position - r.center
                let distSq = diff.lengthSquared
                let alertRadius = r.radius + 65.0
                if distSq < alertRadius * alertRadius && distSq > 0.001 {
                    let dist = sqrt(distSq)
                    let intensity = max(0.0, 1.0 - (dist / alertRadius))
                    let radialDir = diff / dist
                    // Slight angular scatter (+/- 15 deg based on fish index)
                    let scatterAngle = Double(i - 4) * 0.08
                    let scatterDir = PondVector(
                        x: radialDir.x * cos(scatterAngle) - radialDir.y * sin(scatterAngle),
                        y: radialDir.x * sin(scatterAngle) + radialDir.y * cos(scatterAngle)
                    )
                    let fleeMagnitude = 135.0 + intensity * 65.0
                    fleeForce += scatterDir * (fleeMagnitude * intensity)
                    fish[i].panicTimer = max(fish[i].panicTimer, 1.2 * intensity + 0.3)
                    isFleeingThisFrame = true
                }
            }

            // B. Koi Evasion (Large fish approaching)
            for k in nearbyKoi {
                // Threat originates from both koi mouth and koi body center
                let diffMouth = fish[i].position - k.mouthPosition
                let distMouthSq = diffMouth.lengthSquared
                let dangerRadiusMouth = k.mouthRadius + 95.0

                if distMouthSq < dangerRadiusMouth * dangerRadiusMouth && distMouthSq > 0.001 {
                    let dist = sqrt(distMouthSq)
                    let intensity = max(0.0, 1.0 - (dist / dangerRadiusMouth))
                    let radialDir = diffMouth / dist

                    // Perpendicular flank evasion away from koi heading
                    let koiHeadingVec = PondVector.fromAngle(k.heading, length: 1.0)
                    let lateralNormal = PondVector(x: -koiHeadingVec.y, y: koiHeadingVec.x)
                    let sideSign: Double = (diffMouth.dot(with: lateralNormal) >= 0.0) ? 1.0 : -1.0
                    let combinedEscape = (radialDir * 0.75 + lateralNormal * (sideSign * 0.55)).normalized()

                    let fleeMagnitude = 145.0 + intensity * 75.0
                    fleeForce += combinedEscape * (fleeMagnitude * intensity)
                    fish[i].panicTimer = max(fish[i].panicTimer, 1.5 * intensity + 0.4)
                    isFleeingThisFrame = true
                } else {
                    // Check koi body center
                    let diffBody = fish[i].position - k.position
                    let distBodySq = diffBody.lengthSquared
                    let dangerRadiusBody = k.physicalRadius * 0.75 + 50.0
                    if distBodySq < dangerRadiusBody * dangerRadiusBody && distBodySq > 0.001 {
                        let dist = sqrt(distBodySq)
                        let intensity = max(0.0, 1.0 - (dist / dangerRadiusBody))
                        let radialDir = diffBody / dist
                        let fleeMagnitude = 110.0 + intensity * 50.0
                        fleeForce += radialDir * (fleeMagnitude * intensity)
                        fish[i].panicTimer = max(fish[i].panicTimer, 1.1 * intensity + 0.2)
                        isFleeingThisFrame = true
                    }
                }
            }

            // C. Cohesion, Cruising & Dispersal
            let isPanicking = fish[i].panicTimer > 0.0 || isFleeingThisFrame
            let isDispersed = (mode == .dispersed)

            // Dynamic spread based on dispersionFactor and scout status
            let scoutMult = fish[i].isScout ? 1.45 : 1.0
            let spreadDist = max(20.0, fish[i].localDistance * dispersionFactor * scoutMult)

            // Organic meandering angles and radial offset
            let wanderAngleAmp = isDispersed ? 0.85 : 0.28
            let wanderDistAmp = isDispersed ? 26.0 : 8.0
            let wanderAngle = sin(fish[i].wanderPhase) * wanderAngleAmp
            let wanderDist = cos(fish[i].wanderPhase * 0.77 + Double(i)) * wanderDistAmp

            let currentSlotAngle = heading + fish[i].localAngle + wanderAngle
            let currentDist = max(18.0, spreadDist + wanderDist)
            let idealPosition = center + PondVector.fromAngle(currentSlotAngle, length: currentDist)
            let toSlot = idealPosition - fish[i].position
            let distToSlot = toSlot.length

            if isFleeingThisFrame && fleeForce.lengthSquared > 1.0 {
                // Immediate C-start startle escape reflex
                fish[i].swimPhase += dt * (11.0 + Double(i) * 1.2)
                let fleeDir = fleeForce.normalized()
                let targetFleeVelocity = fleeDir * min(190.0, max(120.0, fleeForce.length))
                fish[i].velocity = fish[i].velocity.lerp(to: targetFleeVelocity, t: min(1.0, dt * 45.0))
            } else if fish[i].panicTimer > 0.0 {
                // Sustained burst running away
                fish[i].swimPhase += dt * (9.0 + Double(i) * 1.0)
                fish[i].panicTimer = max(0.0, fish[i].panicTimer - dt)
                let cruiseVelocity = velocity + (toSlot * 1.1)
                fish[i].velocity = fish[i].velocity.lerp(to: cruiseVelocity, t: min(1.0, dt * 2.2))
            } else if isDispersed {
                // Dispersed / Foraging "Mencar" mode:
                // Small fish swim with high individual autonomy, exploring different headings,
                // veering off, drifting, and only feeling a gentle tether if wandering too far.
                fish[i].swimPhase += dt * (3.3 + Double(i % 3) * 0.40)

                let personalSpeed = cruisingSpeed * (0.80 + Double(i % 4) * 0.10)
                let individualHeading = heading + wanderAngle * 1.5 + Double(i - 4) * 0.12
                let foragingVec = PondVector.fromAngle(individualHeading, length: personalSpeed)

                // Soft tether toward dispersed slot if fish drifts too far away
                let tetherForce: PondVector
                if distToSlot > 35.0 {
                    let tetherMag = min(cruisingSpeed * 0.70, (distToSlot - 35.0) * 0.75)
                    tetherForce = (toSlot / distToSlot) * tetherMag
                } else {
                    tetherForce = toSlot * 0.20
                }

                let targetVelocity = foragingVec + tetherForce
                fish[i].velocity = fish[i].velocity.lerp(to: targetVelocity, t: min(1.0, dt * 2.5))
            } else {
                // Peaceful cohesive cruise:
                // Loose, relaxed natural schooling with breathing space and gentle individual sway.
                fish[i].swimPhase += dt * (3.8 + Double(i) * 0.35)
                let personalSpeed = cruisingSpeed * (0.92 + Double(i % 3) * 0.08)
                let schoolForward = PondVector.fromAngle(heading + wanderAngle * 0.5, length: personalSpeed)
                let targetVelocity = schoolForward * 0.45 + velocity * 0.35 + (toSlot * 1.8)
                fish[i].velocity = fish[i].velocity.lerp(to: targetVelocity, t: min(1.0, dt * 3.0))
            }

            // Boundary repulsion on individual fish
            let fishMargin = 25.0
            if fish[i].position.x < bounds.minX + fishMargin {
                fish[i].velocity.x += (bounds.minX + fishMargin - fish[i].position.x) * 4.0
            } else if fish[i].position.x > bounds.maxX - fishMargin {
                fish[i].velocity.x -= (fish[i].position.x - (bounds.maxX - fishMargin)) * 4.0
            }
            if fish[i].position.y < bounds.minY + fishMargin {
                fish[i].velocity.y += (bounds.minY + fishMargin - fish[i].position.y) * 4.0
            } else if fish[i].position.y > bounds.maxY - fishMargin {
                fish[i].velocity.y -= (fish[i].position.y - (bounds.maxY - fishMargin)) * 4.0
            }

            // Position & Heading Integration
            fish[i].position += fish[i].velocity * dt
            fish[i].position = bounds.clamped(fish[i].position, inset: 12.0)

            if fish[i].velocity.lengthSquared > 1.5 {
                let targetAngle = fish[i].velocity.angle
                let turnRate = isPanicking ? 8.5 : 4.0
                fish[i].heading = Self.lerpAngle(from: fish[i].heading, to: targetAngle, t: min(1.0, dt * turnRate))
            }

            let wiggleAmplitude = isPanicking ? 0.22 : 0.12
            fish[i].turn = fish[i].heading + sin(fish[i].swimPhase) * wiggleAmplitude
        }

        // 5. Intra-School Pairwise Fish Separation & Anti-Bunching
        // 2 iterations of relaxation guarantees small fish never bunch up, keeping generous personal space
        let minClearance = 16.0
        let comfortDistance = (mode == .dispersed) ? 50.0 : 32.0

        for a in 0..<fish.count {
            for b in (a + 1)..<fish.count {
                let diff = fish[a].position - fish[b].position
                let distSq = diff.lengthSquared
                guard distSq > 0.001 else { continue }
                let dist = sqrt(distSq)

                if dist < comfortDistance && dist >= minClearance {
                    // Soft organic separation steering (nudges fish to disperse comfortably)
                    let intensity = (comfortDistance - dist) / comfortDistance
                    let softPush = (diff / dist) * (intensity * 20.0 * dt)
                    fish[a].velocity += softPush
                    fish[b].velocity -= softPush
                }
            }
        }

        for _ in 0..<2 {
            for a in 0..<fish.count {
                for b in (a + 1)..<fish.count {
                    let diff = fish[a].position - fish[b].position
                    let distSq = diff.lengthSquared
                    guard distSq > 0.001 else { continue }
                    let dist = sqrt(distSq)

                    if dist < minClearance {
                        let push = (diff / dist) * ((minClearance - dist) * 0.5)
                        fish[a].position += push
                        fish[b].position -= push
                        fish[a].velocity += push * 1.2
                        fish[b].velocity -= push * 1.2
                    }
                }
            }
        }
    }

    /// Checks if floating food pellets are within steal radius (70pt).
    /// With 55% chance, small fish swarm the pellet, reducing bitesRemaining by 0.35
    /// and spawning delicate .eatingNibble ripples (Nagomi tinyFishSteal).
    public mutating func performTinyFishSteal(
        dt: Double,
        pellets: inout [FoodPellet],
        spawnRipple: (PondVector, RippleType) -> Void
    ) {
        guard !pellets.isEmpty else { return }

        for pIdx in 0..<pellets.count {
            guard !pellets[pIdx].isConsumed else { continue }
            let pelletPos = pellets[pIdx].position

            var swarmingFishIndices: [Int] = []
            for i in 0..<fish.count {
                guard fish[i].panicTimer <= 0.0 else { continue }
                let dist = fish[i].position.distance(to: pelletPos)
                if dist <= Self.tinyFishStealRadius {
                    swarmingFishIndices.append(i)
                }
            }

            guard !swarmingFishIndices.isEmpty else { continue }

            let roll = Double.random(in: 0.0...1.0, using: &rng)
            guard roll <= Self.tinyFishStealChance else { continue }

            for i in swarmingFishIndices {
                let toPellet = pelletPos - fish[i].position
                let dist = toPellet.length

                if dist <= 12.0 {
                    let wasConsumed = pellets[pIdx].takeBite(amount: Self.tinyFishBite)
                    spawnRipple(pelletPos, .eatingNibble)

                    fish[i].swimPhase += 3.0
                    fish[i].velocity = PondVector.fromAngle(Double.random(in: -Double.pi...Double.pi, using: &rng), length: 45.0)

                    if wasConsumed {
                        break
                    }
                } else if dist > 0.001 {
                    let rushSpeed = 62.0 + Double(i % 3) * 8.0
                    let rushVel = (toPellet / dist) * rushSpeed
                    fish[i].velocity = fish[i].velocity.lerp(to: rushVel, t: min(1.0, dt * 5.5))
                    fish[i].swimPhase += dt * 6.5
                }
            }
        }
    }

    /// Resizes and scales the school coordinates when pond dimensions change.
    public mutating func resize(oldBounds: PondBounds, newBounds: PondBounds) {
        guard oldBounds.width > 0.0 && oldBounds.height > 0.0 else { return }
        let scaleX = newBounds.width / oldBounds.width
        let scaleY = newBounds.height / oldBounds.height

        center = PondVector(x: center.x * scaleX, y: center.y * scaleY)
        targetWaypoint = PondVector(x: targetWaypoint.x * scaleX, y: targetWaypoint.y * scaleY)

        for i in 0..<fish.count {
            fish[i].position = PondVector(x: fish[i].position.x * scaleX, y: fish[i].position.y * scaleY)
        }
    }

    /// Resets the school back to default organic positions.
    public mutating func reset(bounds: PondBounds, seed: UInt64? = nil) {
        self = DecorativeSchool(groupIndex: groupIndex, bounds: bounds, seed: seed)
    }

    @inlinable
    public static func lerpAngle(from: Double, to: Double, t: Double) -> Double {
        var diff = to - from
        while diff < -.pi { diff += 2.0 * .pi }
        while diff > .pi { diff -= 2.0 * .pi }
        return from + diff * min(1.0, max(0.0, t))
    }
}
