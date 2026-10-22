import Foundation

/// The central simulation engine managing the pond world, the 8 koi fish,
/// floating food pellets, expanding water ripples, and user interaction.
///
/// Fully decoupled from AppKit and UI frameworks for pure testability.
public final class PondSimulation: @unchecked Sendable {
    public var bounds: PondBounds {
        didSet {
            clampAllEntitiesToBounds()
        }
    }

    public private(set) var fish: [KoiFish] = []
    public private(set) var pellets: [FoodPellet] = []
    public private(set) var ripples: [WaterRipple] = []
    public private(set) var clickTargets: [ClickTarget] = []

    public var isPaused: Bool = false
    public var mood: PondMood = .calm
    public var isRainActive: Bool = false
    public let feedingRoutineManager: FeedingRoutineManager
    public let dailyGreetingManager: DailyGreetingManager
    private var rainTimer: Double = 0.0
    public let maxRainRipples: Int = 16

    // Timing and frame-rate stability
    public let fixedDeltaTime: Double
    public let maxCatchUpDelta: Double
    private var timeAccumulator: Double = 0.0
    /// Active fixed-step time shared by visual layers; freezes on pause and resets with the pond.
    public private(set) var elapsedTime: Double = 0.0
    public var rng: SeededRandomNumberGenerator
    private var usesResponsiveFishSizes = false
    private static let silhouetteFractions = [0.12, 0.15, 0.13, 0.17, 0.14, 0.18, 0.16, 0.125]

    private func productionLength(at index: Int) -> Double {
        min(bounds.width, bounds.height) * Self.silhouetteFractions[index % 8] / 1.16
    }

    // Capacity limits
    public let maxPellets: Int = 48
    public let maxRipples: Int = 64
    public let maxFeedingFish: Int = 3

    public init(
        bounds: PondBounds = PondBounds(width: 1280.0, height: 800.0),
        fixedDeltaTime: Double = 1.0 / 60.0,
        maxCatchUpDelta: Double = 0.10,
        initialFish: [KoiFish]? = nil,
        initialPellets: [FoodPellet]? = nil,
        seed: UInt64? = nil,
        mood: PondMood = .calm,
        isRainActive: Bool = false,
        feedingRoutineManager: FeedingRoutineManager? = nil,
        dailyGreetingManager: DailyGreetingManager? = nil,
        feedingStore: FeedingStore? = nil,
        greetingStore: DailyGreetingStore? = nil
    ) {
        self.bounds = bounds
        self.fixedDeltaTime = fixedDeltaTime
        self.maxCatchUpDelta = maxCatchUpDelta
        self.rng = SeededRandomNumberGenerator(seed: seed ?? 0x1337_cafe_babe_dead)
        self.mood = mood
        self.isRainActive = isRainActive

        if let routineMgr = feedingRoutineManager {
            self.feedingRoutineManager = routineMgr
        } else if let store = feedingStore {
            self.feedingRoutineManager = FeedingRoutineManager(store: store)
        } else {
            self.feedingRoutineManager = FeedingRoutineManager()
        }

        if let greetMgr = dailyGreetingManager {
            self.dailyGreetingManager = greetMgr
        } else if let store = greetingStore {
            self.dailyGreetingManager = DailyGreetingManager(store: store)
        } else {
            self.dailyGreetingManager = DailyGreetingManager()
        }

        if let customFish = initialFish {
            self.fish = customFish
        } else {
            initializeEightKoi()
        }

        if let customPellets = initialPellets {
            self.pellets = customPellets
        }
    }

    /// Initializes exactly 8 koi fish, one of each variety, dispersed evenly.
    public func initializeEightKoi() {
        usesResponsiveFishSizes = true
        fish.removeAll()
        let varieties = KoiVariety.allEightVarieties

        let centerX = bounds.width * 0.5
        let centerY = bounds.height * 0.5
        let spawnRadiusX = bounds.width * 0.32
        let spawnRadiusY = bounds.height * 0.32

        for (index, variety) in varieties.prefix(8).enumerated() {
            let angle = (Double(index) / 8.0) * (2.0 * .pi)
            let posX = centerX + cos(angle) * spawnRadiusX + Double.random(in: -20...20, using: &rng)
            let posY = centerY + sin(angle) * spawnRadiusY + Double.random(in: -20...20, using: &rng)
            let fishHeading = angle + .pi * 0.5 + Double.random(in: -0.3...0.3, using: &rng)
            let fishLength = productionLength(at: index)
            let fishSeed = rng.next()

            var koi = KoiFish(
                variety: variety,
                position: PondVector(x: posX, y: posY),
                heading: fishHeading,
                length: fishLength,
                baseSpeed: 45.0 + Double(index % 3) * 6.0,
                seed: fishSeed,
                bodyWidthRatio: 0.34
            )
            // Organic variation across the 8 koi so they don't swim in lockstep:
            // Index 0 preserves exactly 6.0 for deterministic T9.1 compliance.
            // Other fish have slight natural cadence variations (5.3 - 6.3 rad/s).
            if index > 0 {
                let cadenceOffsets = [0.0, -0.6, 0.2, -0.4, 0.1, -0.7, 0.3, -0.2]
                koi.wiggleFrequency = 6.0 + cadenceOffsets[index % 8]
            }
            let maxAllowedInset = min(bounds.width * 0.45, bounds.height * 0.45)
            let inset = min(koi.physicalRadius, maxAllowedInset)
            koi.position = bounds.clamped(koi.position, inset: inset)
            fish.append(koi)
        }
        resolveFishSeparation()
    }

    public func reset() {
        pellets.removeAll()
        ripples.removeAll()
        clickTargets.removeAll()
        timeAccumulator = 0.0
        elapsedTime = 0.0
        initializeEightKoi()
    }

    public func resize(width: Double, height: Double) {
        guard width > 10.0 && height > 10.0 else { return }
        let oldBounds = bounds
        // Capture positions before bounds.didSet clamps the previous world.
        let positions = fish.map(\.position)
        let pelletPositions = pellets.map(\.position)
        bounds = PondBounds(width: width, height: height, margin: bounds.margin)

        let scaleX = width / oldBounds.width
        let scaleY = height / oldBounds.height

        for i in 0..<fish.count {
            fish[i].position = PondVector(x: positions[i].x * scaleX, y: positions[i].y * scaleY)
            if usesResponsiveFishSizes { fish[i].length = productionLength(at: i) }
        }
        for i in 0..<pellets.count {
            pellets[i].position = PondVector(x: pelletPositions[i].x * scaleX, y: pelletPositions[i].y * scaleY)
        }

        clampAllEntitiesToBounds()
        resolveFishSeparation()
    }

    public func clampAllEntitiesToBounds() {
        let maxAllowedInset = min(bounds.width * 0.45, bounds.height * 0.45)
        for i in 0..<fish.count {
            let inset = min(fish[i].physicalRadius, maxAllowedInset)
            fish[i].position = bounds.clamped(fish[i].position, inset: inset)
        }
        for i in 0..<pellets.count {
            pellets[i].position = bounds.clamped(pellets[i].position, inset: pellets[i].radius + 4.0)
        }
    }

    // MARK: - Input Handling

    /// Regular click: spawns a water splash ripple and temporary attraction targets
    /// distributed along the ripple perimeter so koi investigate without converging on a single point.
    public func handleWaterClick(at point: PondVector) {
        guard !isPaused else { return }

        // Spawn ripple (cyan)
        if ripples.count < maxRipples {
            ripples.append(WaterRipple(center: point, type: .waterCall))
        }

        // Create temporary target
        let target = ClickTarget(position: point, duration: 4.5)
        clickTargets.append(target)

        // Select the up to 3 closest curious fish
        let sortedIndices = Array(fish.indices.sorted { idx1, idx2 in
            let d1 = fish[idx1].position.distanceSquared(to: point) / (0.5 + fish[idx1].traits.curiosity)
            let d2 = fish[idx2].position.distanceSquared(to: point) / (0.5 + fish[idx2].traits.curiosity)
            return d1 < d2
        }.prefix(3))

        guard !sortedIndices.isEmpty else { return }

        // Inspection perimeter radius (~42pt matches visual ripple wave scale)
        let inspectionRadius: Double = 42.0
        let count = sortedIndices.count

        // Distribute inspection target points around the click perimeter
        var assignedAngles: [Double] = []
        for (i, fishIdx) in sortedIndices.enumerated() {
            let diff = fish[fishIdx].position - point
            var angle = (diff.length > 0.001) ? diff.angle : (Double(i) * (2.0 * .pi / Double(count)))

            // Ensure minimum angular separation from already assigned angles (~0.95 rad / ~54 deg)
            for prevAngle in assignedAngles {
                var diffAngle = abs(angle - prevAngle)
                if diffAngle > .pi { diffAngle = 2.0 * .pi - diffAngle }
                if diffAngle < 0.95 {
                    angle += (angle >= prevAngle ? 1.0 : -1.0)
                }
            }
            assignedAngles.append(angle)

            let targetOffset = PondVector.fromAngle(angle, length: inspectionRadius)
            let inspectionTarget = bounds.clamped(point + targetOffset, inset: fish[fishIdx].physicalRadius)
            fish[fishIdx].setTarget(inspectionTarget, state: .investigatingClick, duration: 4.5)
        }
    }

    /// Option-click: spawns food pellets and an orange food splash ripple.
    public func handleFoodDrop(at point: PondVector, pelletCount: Int = 4, scatterRadius: Double = 16.0) {
        guard !isPaused else { return }

        // Spawn food splash ripple
        if ripples.count < maxRipples {
            ripples.append(WaterRipple(center: point, type: .foodDrop))
        }

        // Add pellets up to maximum limit
        let countToAdd = min(pelletCount, maxPellets - pellets.count)
        guard countToAdd > 0 else { return }

        for _ in 0..<countToAdd {
            let offset = (scatterRadius > 0.0)
                ? PondVector(
                    x: Double.random(in: -scatterRadius...scatterRadius, using: &rng),
                    y: Double.random(in: -scatterRadius...scatterRadius, using: &rng)
                )
                : .zero
            let pelletPos = bounds.clamped(point + offset, inset: 10.0)
            let drift = PondVector(
                x: Double.random(in: -1...1, using: &rng),
                y: Double.random(in: -1...1, using: &rng)
            )
            let bob = Double.random(in: 0...(2 * .pi), using: &rng)
            let pellet = FoodPellet(position: pelletPos, driftVelocity: drift, bobbingPhase: bob)
            pellets.append(pellet)
        }

        // Alert closest fish to food presence (strictly capped at maxFeedingFish)
        let eligibleFish = fish.indices
            .filter { fish[$0].state == .wandering }
            .sorted { idx1, idx2 in
                let d1 = fish[idx1].position.distanceSquared(to: point) / (0.5 + fish[idx1].traits.feedingEagerness)
                let d2 = fish[idx2].position.distanceSquared(to: point) / (0.5 + fish[idx2].traits.feedingEagerness)
                return d1 < d2
            }

        let responseCount = min(maxFeedingFish, max(1, countToAdd))
        for idx in eligibleFish.prefix(responseCount) {
            fish[idx].setTarget(point, state: .seekingFood, duration: 5.0)
        }

        // Record feeding event in long-term memory
        feedingRoutineManager.recordFeeding(at: point, bounds: bounds, at: Date())
    }

    /// Directly adds a single pellet at exact coordinates without scatter.
    public func addPellet(at point: PondVector) {
        guard !isPaused, pellets.count < maxPellets else { return }
        let clamped = bounds.clamped(point, inset: 10.0)
        pellets.append(FoodPellet(position: clamped))
        feedingRoutineManager.recordFeeding(at: clamped, bounds: bounds, at: Date())
    }

    /// Directly sets an attraction or steering target for a specific fish by index.
    public func setFishTarget(at index: Int, target: PondVector, state: KoiBehaviorState, duration: Double) {
        guard index >= 0 && index < fish.count else { return }
        fish[index].setTarget(target, state: state, duration: duration)
    }

    // MARK: - Time Stepping & Physics Update

    /// Advances simulation by deltaTime, using a fixed timestep accumulator and catch-up limiting.
    public func advance(deltaTime: Double) {
        guard !isPaused else { return }

        // Clamp delta to prevent huge jumps or physics tunneling after suspension/sleep
        let clampedDelta = min(max(0.0, deltaTime), maxCatchUpDelta)
        timeAccumulator += clampedDelta

        while timeAccumulator >= fixedDeltaTime {
            stepSimulation(dt: fixedDeltaTime)
            timeAccumulator -= fixedDeltaTime
        }
    }

    /// Executes a single discrete physics update step.
    public func stepSimulation(dt: Double) {
        elapsedTime += dt
        // 1. Update Pellets
        for i in 0..<pellets.count {
            pellets[i].update(dt: dt, bounds: bounds)
        }

        // 2. Update Koi Fish & Check Food Consumption
        let currentFish = fish
        let activePellets = pellets.filter { !$0.isConsumed && !$0.isExpired }

        // Recruit closest wandering fish if active feeders < limit
        let activeFeeders = fish.indices.filter { fish[$0].state == .seekingFood }
        let neededFeeders = min(maxFeedingFish, activePellets.count) - activeFeeders.count
        if neededFeeders > 0 && !activePellets.isEmpty {
            let closestWanderers = fish.indices
                .filter { fish[$0].state == .wandering }
                .sorted { idx1, idx2 in
                    let d1 = activePellets.map { fish[idx1].position.distanceSquared(to: $0.position) }.min() ?? Double.infinity
                    let d2 = activePellets.map { fish[idx2].position.distanceSquared(to: $0.position) }.min() ?? Double.infinity
                    return d1 < d2
                }
            for idx in closestWanderers.prefix(neededFeeders) {
                let targetPos = activePellets.first?.position ?? fish[idx].position
                fish[idx].setTarget(targetPos, state: .seekingFood, duration: 5.0)
            }
        }

        // Assign each feeding fish to a distinct nearby pellet to prevent clustering
        var assignedPelletIds = Set<UUID>()
        for i in 0..<fish.count {
            var targetForThisFish: PondVector? = nil
            if fish[i].state == .seekingFood && !activePellets.isEmpty {
                var bestPellet: FoodPellet? = nil
                var bestScore = Double.infinity
                for p in activePellets {
                    let dist = fish[i].position.distance(to: p.position)
                    let score = assignedPelletIds.contains(p.id) ? (dist + 300.0) : dist
                    if score < bestScore {
                        bestScore = score
                        bestPellet = p
                    }
                }
                if let chosen = bestPellet {
                    assignedPelletIds.insert(chosen.id)
                    targetForThisFish = chosen.position
                }
            }

            // Update fish steering and motion
            fish[i].update(
                dt: dt,
                bounds: bounds,
                allFish: currentFish,
                nearestFood: targetForThisFish,
                mood: mood
            )

            // Check food consumption at fish mouth
            let mouthPos = fish[i].mouthPosition
            let mouthReach = fish[i].mouthRadius + 6.0

            for pIdx in 0..<pellets.count {
                guard !pellets[pIdx].isConsumed else { continue }
                if mouthPos.distance(to: pellets[pIdx].position) <= (mouthReach + pellets[pIdx].radius) {
                    if pellets[pIdx].consume(by: fish[i].id) {
                        // Spawn delicate eating nibble ripple
                        if ripples.count < maxRipples {
                            ripples.append(WaterRipple(center: pellets[pIdx].position, type: .eatingNibble))
                        }
                        // Clear food target once eaten
                        if fish[i].state == .seekingFood {
                            fish[i].clearTarget()
                        }
                        break // Consume at most one pellet per mouth per sub-step
                    }
                }
            }
        }

        // 3. Enforce position-level non-penetration relaxation between fish bodies
        // based on exact articulated spine capsules
        resolveFishSeparation()

        // 4. Purge consumed and expired food pellets
        pellets.removeAll { $0.isConsumed || $0.isExpired }

        // If no pellets remain, all fish in seekingFood state immediately return to wandering
        if pellets.isEmpty {
            for i in 0..<fish.count {
                if fish[i].state == .seekingFood {
                    fish[i].clearTarget()
                }
            }
        }

        // 5. Update and purge ripples
        for i in 0..<ripples.count {
            ripples[i].update(dt: dt)
        }
        ripples.removeAll { $0.isDead }

        // Atmospheric rain drops: strictly capped to maxRainRipples
        if isRainActive {
            rainTimer += dt
            if rainTimer >= 0.22 {
                rainTimer = 0.0
                let activeRainRipples = ripples.reduce(0) { $0 + ($1.type == .rainDrop ? 1 : 0) }
                if activeRainRipples < maxRainRipples && ripples.count < maxRipples {
                    let rx = Double.random(in: bounds.minX...bounds.maxX, using: &rng)
                    let ry = Double.random(in: bounds.minY...bounds.maxY, using: &rng)
                    ripples.append(WaterRipple(center: PondVector(x: rx, y: ry), type: .rainDrop))
                }
            }
        }

        // Habitual feeding location bias: if no food is present and currently a confident feeding time
        if pellets.isEmpty && feedingRoutineManager.isHabitualTime() {
            if let habitTarget = feedingRoutineManager.habitualWorldTarget(for: bounds) {
                for i in 0..<fish.count {
                    if fish[i].state == .wandering && fish[i].currentTarget == nil && fish[i].traits.feedingEagerness > 0.65 {
                        let chance = Double.random(in: 0...1, using: &rng)
                        // Gently bias fish toward habit area occasionally
                        if chance < (dt * 0.07) {
                            let jitter = PondVector(
                                x: Double.random(in: -35...35, using: &rng),
                                y: Double.random(in: -35...35, using: &rng)
                            )
                            let target = bounds.clamped(habitTarget + jitter, inset: fish[i].physicalRadius)
                            fish[i].setTarget(target, state: .wandering, duration: 4.0)
                        }
                    }
                }
            }
        }

        // 6. Update click targets
        for i in 0..<clickTargets.count {
            clickTargets[i].update(dt: dt)
        }
        clickTargets.removeAll { $0.isExpired }
    }

    /// Enforces a physical non-penetration position relaxation constraint between fish bodies
    /// based on their exact articulated spine capsules. If the solid silhouettes of two fish
    /// intersect, they are separated along their capsule collision normal, respecting pond boundaries.
    public func resolveFishSeparation(safetyMargin: Double = 0.5) {
        guard fish.count > 1 else { return }

        // Perform 2 relaxation passes per sub-step for multi-body stability
        for _ in 0..<2 {
            for i in 0..<fish.count {
                for j in (i + 1)..<fish.count {
                    // 1. Broadphase: check if centers are within combined physical radii
                    let diff = fish[i].position - fish[j].position
                    let maxReach = fish[i].physicalRadius + fish[j].physicalRadius + safetyMargin
                    if diff.lengthSquared > maxReach * maxReach {
                        continue
                    }

                    // 2. Narrowphase: test articulated spine capsules
                    let collision = KoiSpineGeometry.testBodyCollision(
                        fish1: fish[i],
                        fish2: fish[j],
                        safetyMargin: safetyMargin
                    )

                    if collision.hasOverlap {
                        let push = collision.normal * (collision.maxOverlap * 0.5)

                        let insetI = min(fish[i].physicalRadius, min(bounds.width * 0.45, bounds.height * 0.45))
                        let insetJ = min(fish[j].physicalRadius, min(bounds.width * 0.45, bounds.height * 0.45))

                        let oldPosI = fish[i].position
                        fish[i].position = bounds.clamped(oldPosI + push, inset: insetI)
                        let actualMovementI = fish[i].position - oldPosI
                        let remainingPushI = push - actualMovementI

                        let oldPosJ = fish[j].position
                        let totalPushJ = push + remainingPushI
                        fish[j].position = bounds.clamped(oldPosJ - totalPushJ, inset: insetJ)
                    }
                }
            }
        }
    }
}
