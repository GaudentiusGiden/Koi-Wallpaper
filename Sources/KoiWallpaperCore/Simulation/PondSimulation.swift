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
    public private(set) var visitors: [PondVisitor] = []
    public private(set) var insects: [PondInsect] = []
    public private(set) var decorativeSchools: [DecorativeSchool] = []
    public private(set) var floatingDebris: [FloatingDebris] = []
    public private(set) var lilyPads: [PondLilyPad] = []
    public var frog: PondFrog
    public var turtle: PondTurtle

    public var isPaused: Bool = false
    public var mood: PondMood = .calm
    public var isRainActive: Bool = false
    public var isFloatingDebrisEnabled: Bool = true
    public var koiPaletteMode: KoiPaletteMode = .classic
    public var season: PondSeason = .spring
    public var seasonMode: SeasonMode = .autoCalendar
    public private(set) var currentTheme: PondTheme = .day
    public let feedingRoutineManager: FeedingRoutineManager
    public let dailyGreetingManager: DailyGreetingManager
    private var rainTimer: Double = 0.0
    public let maxRainRipples: Int = 16
    private var debrisSpawnTimer: Double = 0.0
    private var nextDebrisSpawnInterval: Double = 3.5

    // Cached habitual feeding evaluation (interval 10s instead of 60 Hz)
    private var timeSinceHabitCheck: Double = 10.0
    private var cachedHabitualTime: Bool = false
    private var cachedHabitTarget: PondVector? = nil

    // Insect dynamics & periodic koi curiosity targeting
    private var insectTargetTimer: Double = 0.0
    private var nextInsectTargetInterval: Double = 14.0

    // Production wallpaper swans enter from an edge, cross the pond, then return after a pause.
    public private(set) var isAutomaticSwanEnabled = false
    public var isVisitorRotationEnabled = false
    private var nextAutonomousType: PondVisitorType = .duck
    private var automaticSwanArrivalCountdown: Double?

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
    public let maxVisitors: Int = 6
    public let maxInsects: Int = 4
    public let maxFloatingDebris: Int = 24

    public init(
        bounds: PondBounds = PondBounds(width: 1280.0, height: 800.0),
        fixedDeltaTime: Double = 1.0 / 60.0,
        maxCatchUpDelta: Double = 0.10,
        initialFish: [KoiFish]? = nil,
        initialPellets: [FoodPellet]? = nil,
        initialInsects: [PondInsect]? = nil,
        initialDebris: [FloatingDebris]? = nil,
        seed: UInt64? = nil,
        mood: PondMood = .calm,
        isRainActive: Bool = false,
        theme: PondTheme = .day,
        season: PondSeason? = nil,
        seasonMode: SeasonMode = .autoCalendar,
        isFloatingDebrisEnabled: Bool = true,
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
        self.currentTheme = theme
        self.seasonMode = seasonMode
        self.season = season ?? (seasonMode == .autoCalendar ? PondSeason.currentCalendarSeason() : .spring)
        self.isFloatingDebrisEnabled = isFloatingDebrisEnabled
        self.nextInsectTargetInterval = Double.random(in: 12.0...20.0, using: &self.rng)
        self.nextDebrisSpawnInterval = 4.0

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

        self.frog = PondFrog.initial(bounds: bounds)
        self.turtle = PondTurtle.initial(bounds: bounds)

        if let customFish = initialFish {
            self.fish = customFish
        } else {
            initializeEightKoi()
        }

        if let customPellets = initialPellets {
            self.pellets = customPellets
        }

        if let customInsects = initialInsects {
            self.insects = customInsects
        } else {
            initializeInsects(for: theme)
        }
        if let customDebris = initialDebris {
            self.floatingDebris = customDebris
        }
        self.lilyPads = PondLilyPad.generatePads(for: bounds)
        initializeDecorativeSchools()
    }

    /// Initializes the 3 schools of decorative small schooling fish.
    public func initializeDecorativeSchools() {
        decorativeSchools.removeAll()
        for group in 0..<DecorativeSchool.schoolCount {
            let seed = UInt64(700 + group * 443)
            decorativeSchools.append(DecorativeSchool(groupIndex: group, bounds: bounds, seed: seed))
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
        visitors.removeAll()
        floatingDebris.removeAll()
        debrisSpawnTimer = 0.0
        timeAccumulator = 0.0
        elapsedTime = 0.0
        insectTargetTimer = 0.0
        nextInsectTargetInterval = Double.random(in: 12.0...20.0, using: &rng)
        automaticSwanArrivalCountdown = isAutomaticSwanEnabled
            ? Double.random(in: 3.0...6.0, using: &rng)
            : nil
        initializeInsects(for: currentTheme)
        initializeEightKoi()
        self.lilyPads = PondLilyPad.generatePads(for: bounds)
        initializeDecorativeSchools()
    }

    public func resize(width: Double, height: Double) {
        guard width > 10.0 && height > 10.0 else { return }
        let oldBounds = bounds
        // Capture positions before bounds.didSet clamps the previous world.
        let positions = fish.map(\.position)
        let pelletPositions = pellets.map(\.position)
        let visitorPositions = visitors.map(\.position)
        let insectPositions = insects.map(\.position)
        let debrisPositions = floatingDebris.map(\.position)
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
        for i in 0..<visitors.count {
            visitors[i].position = PondVector(x: visitorPositions[i].x * scaleX, y: visitorPositions[i].y * scaleY)
        }
        for i in 0..<insects.count {
            insects[i].position = PondVector(x: insectPositions[i].x * scaleX, y: insectPositions[i].y * scaleY)
        }
        for i in 0..<floatingDebris.count {
            floatingDebris[i].position = PondVector(x: debrisPositions[i].x * scaleX, y: debrisPositions[i].y * scaleY)
        }
        for i in 0..<decorativeSchools.count {
            decorativeSchools[i].resize(oldBounds: oldBounds, newBounds: bounds)
        }
        self.lilyPads = PondLilyPad.generatePads(for: bounds)
        frog.updateLocations(bounds: bounds)
        turtle.position = CGPoint(x: turtle.position.x * scaleX, y: turtle.position.y * scaleY)
        turtle.clampToBounds(bounds: bounds)

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
        for i in 0..<visitors.count {
            guard !visitors[i].isAutonomous else { continue }
            visitors[i].position = bounds.clamped(visitors[i].position, inset: visitors[i].radius + 4.0)
        }
        for i in 0..<insects.count {
            insects[i].position = bounds.clamped(insects[i].position, inset: 16.0)
        }
        for i in 0..<floatingDebris.count {
            floatingDebris[i].position = bounds.clamped(floatingDebris[i].position, inset: 10.0)
        }
        turtle.clampToBounds(bounds: bounds)
    }

    // MARK: - Input Handling

    /// Regular click: spawns a water splash ripple and temporary attraction targets
    /// distributed along the ripple perimeter so koi investigate without converging on a single point.
    public func handleWaterClick(at point: PondVector) {
        guard !isPaused else { return }

        // Startle perched frog if click is nearby
        let frogDist = hypot(point.x - Double(frog.position.x), point.y - Double(frog.position.y))
        if frogDist < 48.0 {
            frog.triggerJumpIfPerched()
        }

        // Startle swimming turtle if click is nearby (speed burst panic)
        let turtleDist = hypot(point.x - Double(turtle.position.x), point.y - Double(turtle.position.y))
        if turtleDist < 72.0 {
            turtle.triggerStartle(awayFrom: CGPoint(x: point.x, y: point.y))
        }

        // Startle swimming duck if click is nearby (splash burst panic)
        for i in 0..<visitors.count {
            if visitors[i].type == .duck {
                let duckDist = hypot(point.x - visitors[i].position.x, point.y - visitors[i].position.y)
                if duckDist < 68.0 {
                    visitors[i].triggerStartle(awayFrom: point)
                    if ripples.count < maxRipples {
                        ripples.append(WaterRipple(center: visitors[i].position, type: .waterCall))
                    }
                }
            }
        }

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
            .filter { fish[$0].state == .wandering || fish[$0].state == .followingInsect }
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
    public func setFishTarget(at index: Int, target: PondVector, state: KoiBehaviorState, duration: Double, visitorId: UUID? = nil, insectId: UUID? = nil) {
        guard index >= 0 && index < fish.count else { return }
        fish[index].setTarget(target, state: state, duration: duration, visitorId: visitorId, insectId: insectId)
    }

    // MARK: - Visitor Management

    /// Enables or disables the recurring swan used by the live desktop wallpaper.
    public func setAutomaticSwanEnabled(_ enabled: Bool) {
        guard enabled != isAutomaticSwanEnabled else { return }
        isAutomaticSwanEnabled = enabled

        if enabled {
            let birdAlreadyPresent = visitors.contains { $0.type == .swan || $0.type == .duck }
            automaticSwanArrivalCountdown = nil
            if !birdAlreadyPresent {
                createAutomaticSwan()
            }
        } else {
            let autonomousIds = visitors.filter(\.isAutonomous).map(\.id)
            for id in autonomousIds {
                removeVisitor(id: id)
            }
            automaticSwanArrivalCountdown = nil
        }
    }

    private func updateAutomaticSwan(dt: Double) {
        guard isAutomaticSwanEnabled else { return }

        // A manually created swan or duck also prevents a second bird from overlapping it.
        if visitors.contains(where: { $0.type == .swan || $0.type == .duck }) {
            automaticSwanArrivalCountdown = nil
            return
        }

        if automaticSwanArrivalCountdown == nil {
            automaticSwanArrivalCountdown = Double.random(in: 5.0...9.0, using: &rng)
        }

        automaticSwanArrivalCountdown! -= dt
        guard automaticSwanArrivalCountdown! <= 0 else { return }

        createAutomaticSwan()
    }

    private func createAutomaticSwan() {
        let visitorType: PondVisitorType
        let duckVar: DuckPaletteVariant

        if isVisitorRotationEnabled {
            visitorType = nextAutonomousType
            duckVar = Bool.random(using: &rng) ? .mandarin : .whitePekin
            nextAutonomousType = (nextAutonomousType == .swan) ? .duck : .swan
        } else {
            visitorType = .swan
            duckVar = .mandarin
        }

        let radius = (visitorType == .swan) ? 53.0 : 42.0
        let insetX = min(radius + 52.0, bounds.width * 0.30)
        let insetY = min(radius + 52.0, bounds.height * 0.30)
        let position = PondVector(
            x: Double.random(in: insetX...(bounds.width - insetX), using: &rng),
            y: Double.random(in: insetY...(bounds.height - insetY), using: &rng)
        )
        let heading = Double.random(in: -Double.pi...Double.pi, using: &rng)
        let speed = (visitorType == .swan)
            ? Double.random(in: 34.0...44.0, using: &rng)
            : Double.random(in: 32.0...42.0, using: &rng)
        let seed = rng.next()
        let visitor = PondVisitor(
            type: visitorType,
            duckVariant: duckVar,
            position: position,
            heading: heading,
            speed: speed,
            isAutonomous: true,
            seed: seed
        )
        addVisitor(visitor)
        automaticSwanArrivalCountdown = nil
    }

    /// Adds an existing visitor to the pond, subject to the capacity cap.
    public func addVisitor(_ visitor: PondVisitor) {
        guard visitors.count < maxVisitors else { return }
        visitors.append(visitor)
    }

    /// Spawns a surface visitor (such as an elegant swan, nagomi duck, or floating temari ball) in the pond.
    @discardableResult
    public func spawnVisitor(
        type: PondVisitorType,
        duckVariant: DuckPaletteVariant = .mandarin,
        at point: PondVector? = nil,
        lifetime: Double? = nil
    ) -> PondVisitor {
        if visitors.count >= maxVisitors {
            // Remove the oldest visitor if cap reached, clearing fish targets for it
            let oldest = visitors.removeFirst()
            for i in 0..<fish.count {
                if fish[i].targetVisitorId == oldest.id {
                    fish[i].clearTarget()
                }
            }
        }

        let spawnPos: PondVector
        if let explicitPoint = point {
            spawnPos = bounds.clamped(explicitPoint, inset: 30.0)
        } else {
            // Spawn at an organic, aesthetic location
            let margin = 70.0
            let sx = Double.random(in: (bounds.minX + margin)...(bounds.maxX - margin), using: &rng)
            let sy = Double.random(in: (bounds.minY + margin)...(bounds.maxY - margin), using: &rng)
            spawnPos = PondVector(x: sx, y: sy)
        }

        let heading = Double.random(in: -Double.pi...Double.pi, using: &rng)
        let seed = rng.next()
        let visitor = PondVisitor(
            type: type,
            duckVariant: duckVariant,
            position: spawnPos,
            heading: heading,
            lifetime: lifetime,
            seed: seed
        )
        visitors.append(visitor)

        // Spawn a welcoming water ripple
        if ripples.count < maxRipples {
            ripples.append(WaterRipple(center: spawnPos, type: .waterCall))
        }

        return visitor
    }

    /// Removes a visitor by its identifier and guarantees no fish remains stuck on a missing target.
    public func removeVisitor(id: UUID) {
        visitors.removeAll { $0.id == id }
        for i in 0..<fish.count {
            if fish[i].targetVisitorId == id || (visitors.isEmpty && fish[i].state == .investigatingVisitor) {
                fish[i].clearTarget()
            }
        }
    }

    /// Clears all visitors from the pond, immediately resetting any investigating fish back to wandering.
    public func clearVisitors() {
        visitors.removeAll()
        for i in 0..<fish.count {
            if fish[i].state == .investigatingVisitor || fish[i].targetVisitorId != nil {
                fish[i].clearTarget()
            }
        }
        automaticSwanArrivalCountdown = isAutomaticSwanEnabled
            ? Double.random(in: 5.0...9.0, using: &rng)
            : nil
    }

    // MARK: - Insect Simulation & Theme Transition

    /// Initializes pond insects for a given theme:
    /// 2 dragonflies + 2 butterflies on non-night themes (day, dawn, dusk, goldenHour, deepClear, rain),
    /// and 4 fireflies on night theme.
    public func initializeInsects(for theme: PondTheme) {
        clearInsects()
        insects = createInsects(for: theme, opacity: 1.0, targetOpacity: 1.0)
    }

    /// Clears all insects and any koi target following an insect.
    public func clearInsects() {
        insects.removeAll()
        for i in 0..<fish.count {
            if fish[i].state == .followingInsect {
                fish[i].clearTarget()
            }
        }
    }

    /// Helper to generate a themed insect group.
    public func createInsects(for theme: PondTheme, opacity: Double, targetOpacity: Double) -> [PondInsect] {
        var group: [PondInsect] = []
        let margin = 55.0
        let minX = bounds.minX + margin
        let maxX = bounds.maxX - margin
        let minY = bounds.minY + margin
        let maxY = bounds.maxY - margin
        let spanX = max(40.0, maxX - minX)
        let spanY = max(40.0, maxY - minY)

        if theme.isNight {
            // 4 Fireflies distributed across the pond
            let offsets: [(Double, Double)] = [(0.25, 0.35), (0.75, 0.30), (0.35, 0.72), (0.72, 0.68)]
            for (i, offset) in offsets.enumerated() {
                let posX = minX + spanX * offset.0 + Double.random(in: -25...25, using: &rng)
                let posY = minY + spanY * offset.1 + Double.random(in: -25...25, using: &rng)
                let heading = Double.random(in: -Double.pi...Double.pi, using: &rng)
                let seed = rng.next()
                let firefly = PondInsect(
                    type: .firefly,
                    position: bounds.clamped(PondVector(x: posX, y: posY), inset: 20.0),
                    heading: heading,
                    opacity: opacity,
                    targetOpacity: targetOpacity,
                    colorVariant: i % 2,
                    seed: seed
                )
                group.append(firefly)
            }
        } else {
            // 2 Dragonflies and 2 Butterflies distributed across the pond
            let offsets: [(Double, Double)] = [(0.28, 0.30), (0.72, 0.68), (0.68, 0.32), (0.32, 0.70)]
            for i in 0..<4 {
                let posX = minX + spanX * offsets[i].0 + Double.random(in: -25...25, using: &rng)
                let posY = minY + spanY * offsets[i].1 + Double.random(in: -25...25, using: &rng)
                let heading = Double.random(in: -Double.pi...Double.pi, using: &rng)
                let seed = rng.next()
                let type: PondInsectType = (i < 2) ? .dragonfly : .butterfly
                let insect = PondInsect(
                    type: type,
                    position: bounds.clamped(PondVector(x: posX, y: posY), inset: 20.0),
                    heading: heading,
                    opacity: opacity,
                    targetOpacity: targetOpacity,
                    colorVariant: i % 2,
                    seed: seed
                )
                group.append(insect)
            }
        }
        return group
    }

    /// Sets the active theme, smoothly fading between night and non-night insect populations when animated.
    public func setTheme(_ newTheme: PondTheme, animated: Bool = true) {
        if !animated {
            currentTheme = newTheme
            for i in 0..<fish.count {
                if fish[i].state == .followingInsect {
                    fish[i].clearTarget()
                }
            }
            initializeInsects(for: newTheme)
            return
        }

        if newTheme.isNight == currentTheme.isNight {
            currentTheme = newTheme
            return
        }

        currentTheme = newTheme
        // Cross-species theme transition: fade out existing group, fade in new group
        for i in 0..<insects.count {
            insects[i].targetOpacity = 0.0
        }
        for i in 0..<fish.count {
            if fish[i].state == .followingInsect {
                fish[i].clearTarget()
            }
        }

        let targetType: PondInsectType = newTheme.isNight ? .firefly : .dragonfly
        let hasNewSpecies = insects.contains { $0.type == targetType }
        if !hasNewSpecies {
            let newGroup = createInsects(for: newTheme, opacity: 0.0, targetOpacity: 1.0)
            insects.append(contentsOf: newGroup)
        } else {
            for i in 0..<insects.count {
                let matches = newTheme.isNight ? (insects[i].type == .firefly) : (insects[i].type != .firefly)
                if matches {
                    insects[i].targetOpacity = 1.0
                }
            }
        }
    }

    /// Updates insect opacity during theme transitions driven by an external progress (0.0 to 1.0).
    public func updateThemeTransition(from fromTheme: PondTheme, to toTheme: PondTheme, progress: Double) {
        let p = max(0.0, min(1.0, progress))

        if fromTheme == toTheme && currentTheme == toTheme && p >= 1.0 {
            return
        }

        if fromTheme.isNight == toTheme.isNight {
            currentTheme = toTheme
            let targetType: PondInsectType = toTheme.isNight ? .firefly : .dragonfly
            let hasCorrectSpecies = insects.contains { $0.type == targetType }
            if !hasCorrectSpecies || insects.count != 4 {
                initializeInsects(for: toTheme)
            } else {
                for i in 0..<insects.count {
                    insects[i].opacity = 1.0
                    insects[i].targetOpacity = 1.0
                }
            }
            return
        }

        currentTheme = (p >= 0.5) ? toTheme : fromTheme
        let fromIsNight = fromTheme.isNight
        let toIsNight = toTheme.isNight

        let hasFromGroup = insects.contains { fromIsNight ? ($0.type == .firefly) : ($0.type != .firefly) }
        let hasToGroup = insects.contains { toIsNight ? ($0.type == .firefly) : ($0.type != .firefly) }

        if !hasFromGroup {
            let group = createInsects(for: fromTheme, opacity: 1.0 - p, targetOpacity: 0.0)
            insects.append(contentsOf: group)
        }
        if !hasToGroup {
            let group = createInsects(for: toTheme, opacity: p, targetOpacity: 1.0)
            insects.append(contentsOf: group)
        }

        for i in 0..<insects.count {
            let isToGroup = toIsNight ? (insects[i].type == .firefly) : (insects[i].type != .firefly)
            if isToGroup {
                insects[i].opacity = p
                insects[i].targetOpacity = 1.0
            } else {
                insects[i].opacity = 1.0 - p
                insects[i].targetOpacity = 0.0
            }
        }

        if p >= 1.0 {
            currentTheme = toTheme
            insects.removeAll { insect in
                let isOld = toIsNight ? (insect.type != .firefly) : (insect.type == .firefly)
                return isOld || insect.opacity <= 0.001
            }
            for i in 0..<insects.count {
                insects[i].opacity = 1.0
                insects[i].targetOpacity = 1.0
            }
        }
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

    /// Advances the simulation by simulatedSeconds for a discrete snapshot, even when paused.
    public func advanceSnapshot(simulatedSeconds: Double = 10.0) {
        let dt = fixedDeltaTime
        var remaining = max(0.0, simulatedSeconds)
        let maxSteps = max(1200, Int(ceil(remaining / dt)) + 10)
        var steps = 0
        while remaining >= dt && steps < maxSteps {
            stepSimulation(dt: dt)
            remaining -= dt
            steps += 1
        }
        if remaining > 0 && steps < maxSteps {
            stepSimulation(dt: remaining)
        }
    }

    /// Executes a single discrete physics update step.
    public func stepSimulation(dt: Double) {
        elapsedTime += dt
        // 1. Update Pellets
        for i in 0..<pellets.count {
            pellets[i].update(dt: dt, bounds: bounds)
        }

        // 1b. Update Lily Pads and Koi Surface Contact (depth < 0.25)
        for i in 0..<lilyPads.count {
            lilyPads[i].update(dt: dt)
        }

        for k in fish where k.depth < 0.25 {
            for pIdx in 0..<lilyPads.count {
                let dist = k.position.distance(to: lilyPads[pIdx].position)
                let mouthDist = k.mouthPosition.distance(to: lilyPads[pIdx].position)
                let collisionThreshold = lilyPads[pIdx].radius + k.physicalRadius * 0.5
                if dist <= collisionThreshold || mouthDist <= (lilyPads[pIdx].radius + 8.0) {
                    if lilyPads[pIdx].contactCooldown <= 0.08 {
                        lilyPads[pIdx].triggerContact(duration: PondLilyPad.contactCooldownSeconds)
                        if ripples.count < maxRipples {
                            ripples.append(WaterRipple(center: lilyPads[pIdx].position, type: .padBump))
                        }
                        // 40% chance startles frog if perched on this pad to nearest neighbor pad within 70pt
                        let effectiveHopRange = max(PondFrog.hopRange, PondFrog.hopRange * (min(bounds.width, bounds.height) / 270.0))
                        frog.handlePadBump(bumpedPadId: lilyPads[pIdx].id, allPads: lilyPads, maxRange: effectiveHopRange, rng: &rng)
                    }
                }
            }
        }

        // 2. Update Koi Fish & Check Food Consumption
        let currentFish = fish
        let activePellets = pellets.filter { !$0.isConsumed && !$0.isExpired }

        // Recruit closest wandering fish if active feeders < limit
        let activeFeeders = fish.indices.filter { fish[$0].state == .seekingFood }
        let neededFeeders = min(maxFeedingFish, activePellets.count) - activeFeeders.count
        if neededFeeders > 0 && !activePellets.isEmpty {
            let closestWanderers = fish.indices
                .filter { fish[$0].state == .wandering || fish[$0].state == .followingInsect }
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

        // 6. Update Visitors & Fish Interaction Dynamics
        for i in 0..<visitors.count {
            visitors[i].update(dt: dt, bounds: bounds)
        }

        // Visitors (Ducks & Swans) feed on nearby food pellets
        if !pellets.isEmpty {
            for i in 0..<visitors.count {
                guard visitors[i].type == .duck || visitors[i].type == .swan else { continue }
                if visitors[i].type == .duck && (visitors[i].isStartled || visitors[i].isDabbling) { continue }

                var closestIdx: Int? = nil
                var minD = visitors[i].interactionRadius
                for pIdx in 0..<pellets.count {
                    let d = pellets[pIdx].position.distance(to: visitors[i].position)
                    if d < minD {
                        minD = d
                        closestIdx = pIdx
                    }
                }

                if let pIdx = closestIdx {
                    let targetPellet = pellets[pIdx]
                    visitors[i].targetPelletId = targetPellet.id
                    let diff = targetPellet.position - visitors[i].position
                    let targetAngle = diff.angle
                    let diffAngle = normalizeAngle(targetAngle - visitors[i].heading)
                    let maxTurn = (visitors[i].type == .duck ? 2.4 : 1.2) * dt
                    visitors[i].heading = normalizeAngle(visitors[i].heading + min(max(diffAngle, -maxTurn), maxTurn))
                    visitors[i].velocity = PondVector.fromAngle(visitors[i].heading, length: visitors[i].speed)

                    let eatDist = (visitors[i].type == .duck) ? 18.0 : 26.0
                    if minD < eatDist {
                        pellets.remove(at: pIdx)
                        if ripples.count < maxRipples {
                            ripples.append(WaterRipple(center: targetPellet.position, type: .eatingNibble))
                        }
                        if visitors[i].type == .duck {
                            visitors[i].triggerDabble(duration: Double.random(in: 2.0...3.2, using: &rng))
                        }
                        visitors[i].targetPelletId = nil
                    }
                } else {
                    visitors[i].targetPelletId = nil
                }
            }
        }

        // Purge expired or fully departed visitors and clear any koi targets for them.
        let departedVisitors = visitors.filter { $0.isExpired || $0.hasCompletelyExited(bounds) }
        if !departedVisitors.isEmpty {
            let departedIds = Set(departedVisitors.map(\.id))
            visitors.removeAll { $0.isExpired || $0.hasCompletelyExited(bounds) }
            for i in 0..<fish.count {
                if let vid = fish[i].targetVisitorId, departedIds.contains(vid) {
                    fish[i].clearTarget()
                }
            }
        }

        updateAutomaticSwan(dt: dt)

        // Update fish targeting visitors & enforce zero stuck fish guarantee
        for i in 0..<fish.count {
            if fish[i].state == .investigatingVisitor {
                if let vid = fish[i].targetVisitorId, let activeVisitor = visitors.first(where: { $0.id == vid }) {
                    // Update target point to current visitor position (or escort offset)
                    let escortOffset: PondVector
                    if activeVisitor.type == .swan || activeVisitor.type == .duck {
                        let angle = activeVisitor.heading + .pi * 0.75
                        escortOffset = PondVector.fromAngle(angle, length: activeVisitor.radius + 18.0)
                    } else {
                        escortOffset = .zero
                    }
                    let target = bounds.clamped(activeVisitor.position + escortOffset, inset: fish[i].physicalRadius)
                    fish[i].setTarget(target, state: .investigatingVisitor, duration: 5.5, visitorId: vid)
                } else {
                    // Visitor has been removed or ID missing: immediately return to wandering!
                    fish[i].clearTarget()
                }
            }
        }

        // Attract wandering fish to nearby visitors if no food is present
        if !visitors.isEmpty && pellets.isEmpty {
            for visitor in visitors {
                guard bounds.contains(visitor.position) else { continue }
                for i in 0..<fish.count {
                    guard fish[i].state == .wandering && fish[i].currentTarget == nil else { continue }
                    let dist = fish[i].position.distance(to: visitor.position)
                    if dist < visitor.interactionRadius {
                        let curiosityThreshold = (mood == .playful) ? 0.35 : 0.55
                        if fish[i].traits.curiosity >= curiosityThreshold {
                            let escortOffset: PondVector
                            if visitor.type == .swan || visitor.type == .duck {
                                let angle = visitor.heading + .pi * 0.75
                                escortOffset = PondVector.fromAngle(angle, length: visitor.radius + 18.0)
                            } else {
                                escortOffset = .zero
                            }
                            let target = bounds.clamped(visitor.position + escortOffset, inset: fish[i].physicalRadius)
                            fish[i].setTarget(target, state: .investigatingVisitor, duration: 5.5, visitorId: visitor.id)
                        }
                    }
                }
            }
        }

        // Ball nudge physics: when fish mouth touches the ball, impart gentle impulse and ripple
        for vIdx in 0..<visitors.count where visitors[vIdx].type == .ball {
            for fIdx in 0..<fish.count {
                let mouthPos = fish[fIdx].mouthPosition
                let dist = mouthPos.distance(to: visitors[vIdx].position)
                if dist < (fish[fIdx].mouthRadius + visitors[vIdx].radius + 4.0) {
                    let impulse = PondVector.fromAngle(fish[fIdx].heading, length: 28.0)
                    visitors[vIdx].applyImpulse(impulse)
                    if ripples.count < maxRipples {
                        ripples.append(WaterRipple(center: visitors[vIdx].position, type: .waterCall))
                    }
                    if fish[fIdx].state == .investigatingVisitor {
                        fish[fIdx].clearTarget()
                    }
                }
            }
        }

        // Atmospheric rain drops: strictly capped to maxRainRipples
        if isRainActive {
            rainTimer += dt
            if rainTimer >= 0.08 {
                rainTimer = 0.0
                let activeRainRipples = ripples.reduce(0) { $0 + ($1.type == .rainDrop ? 1 : 0) }
                if activeRainRipples < maxRainRipples && ripples.count < maxRipples {
                    let rx = Double.random(in: bounds.minX...bounds.maxX, using: &rng)
                    let ry = Double.random(in: bounds.minY...bounds.maxY, using: &rng)
                    ripples.append(WaterRipple(center: PondVector(x: rx, y: ry), type: .rainDrop))
                }
            }
        }

        // Habitual feeding location bias: periodically re-evaluated every 10 seconds of simulation time
        timeSinceHabitCheck += dt
        if timeSinceHabitCheck >= 10.0 {
            timeSinceHabitCheck = 0.0
            cachedHabitualTime = feedingRoutineManager.isHabitualTime()
            cachedHabitTarget = cachedHabitualTime ? feedingRoutineManager.habitualWorldTarget(for: bounds) : nil
        }

        if pellets.isEmpty && cachedHabitualTime {
            if let habitTarget = cachedHabitTarget {
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

        // 6. Update Insects & Koi Curiosity Interaction
        let lotusFlowers = lilyPads.filter { $0.hasFlower }.map { $0.flowerPosition }
        for i in 0..<insects.count {
            insects[i].update(dt: dt, bounds: bounds, flowerPositions: lotusFlowers)
        }
        // Purge fully faded out insects
        insects.removeAll { $0.targetOpacity == 0.0 && $0.opacity <= 0.001 }

        // Update fish following insects: track moving target and ensure zero stuck fish guarantee
        for i in 0..<fish.count {
            if fish[i].state == .followingInsect {
                if let targetInsectId = fish[i].targetInsectId,
                   let activeInsect = insects.first(where: { $0.id == targetInsectId && $0.opacity > 0.05 }) {
                    let target = bounds.clamped(activeInsect.position, inset: fish[i].physicalRadius)
                    fish[i].updateMovingTarget(target)
                } else {
                    // Insect missing or faded out: return to wandering immediately!
                    fish[i].clearTarget()
                }
            }
        }

        // Attract a curious wandering fish to follow a low-flying insect (approx every 12-20s)
        // Food and click targets remain strictly prioritized!
        if pellets.isEmpty && clickTargets.isEmpty && !fish.contains(where: { $0.state == .followingInsect }) {
            insectTargetTimer += dt
            if insectTargetTimer >= nextInsectTargetInterval {
                insectTargetTimer = 0.0
                nextInsectTargetInterval = Double.random(in: 12.0...20.0, using: &rng)

                let activeInsects = insects.filter { $0.opacity >= 0.5 }
                if !activeInsects.isEmpty {
                    let lowFlying = activeInsects.filter(\.isFlyingLow)
                    let chosenInsect = lowFlying.randomElement(using: &rng) ?? activeInsects.min(by: { $0.altitude < $1.altitude })!

                    let eligibleFish = fish.indices.filter { fish[$0].state == .wandering && fish[$0].currentTarget == nil }
                    if !eligibleFish.isEmpty {
                        let chosenFishIdx = eligibleFish.max(by: { idx1, idx2 in
                            let d1 = fish[idx1].position.distance(to: chosenInsect.position)
                            let d2 = fish[idx2].position.distance(to: chosenInsect.position)
                            let s1 = fish[idx1].traits.curiosity / (1.0 + d1 / 250.0)
                            let s2 = fish[idx2].traits.curiosity / (1.0 + d2 / 250.0)
                            return s1 < s2
                        })!

                        let target = bounds.clamped(chosenInsect.position, inset: fish[chosenFishIdx].physicalRadius)
                        fish[chosenFishIdx].setTarget(target, state: .followingInsect, duration: 5.5, insectId: chosenInsect.id)
                    }
                }
            }
        }

        // 7. Update Pond Frog
        frog.update(dt: dt, bounds: bounds) { [weak self] point, rippleType in
            guard let self = self else { return }
            if self.ripples.count < self.maxRipples {
                let p = PondVector(x: Double(point.x), y: Double(point.y))
                self.ripples.append(WaterRipple(
                    center: p,
                    type: rippleType,
                    initialRadius: 4.0,
                    maxRadius: (rippleType == .waterCall ? 44.0 : 22.0)
                ))
            }
        }

        // 7b. Update Pond Turtle (Kame)
        turtle.update(dt: dt, bounds: bounds) { [weak self] point, rippleType in
            guard let self = self else { return }
            if self.ripples.count < self.maxRipples {
                let p = PondVector(x: Double(point.x), y: Double(point.y))
                self.ripples.append(WaterRipple(
                    center: p,
                    type: rippleType,
                    initialRadius: 4.0,
                    maxRadius: (rippleType == .waterCall ? 48.0 : 24.0)
                ))
            }
        }

        // 8. Update click targets
        for i in 0..<clickTargets.count {
            clickTargets[i].update(dt: dt)
        }
        clickTargets.removeAll { $0.isExpired }

        // 9. Update Decorative Schooling Small Fish
        // Compute inter-school repulsion so the 3 schools maintain separate paths
        var schoolRepulsions = [PondVector](repeating: .zero, count: decorativeSchools.count)
        let minSchoolClearance = 210.0
        for i in 0..<decorativeSchools.count {
            for j in (i + 1)..<decorativeSchools.count {
                let diff = decorativeSchools[i].center - decorativeSchools[j].center
                let distSq = diff.lengthSquared
                if distSq < minSchoolClearance * minSchoolClearance && distSq > 0.001 {
                    let dist = sqrt(distSq)
                    let pushMag = ((minSchoolClearance - dist) / minSchoolClearance) * 55.0
                    let pushDir = diff / dist
                    schoolRepulsions[i] += pushDir * pushMag
                    schoolRepulsions[j] -= pushDir * pushMag
                }
            }
        }

        for i in 0..<decorativeSchools.count {
            decorativeSchools[i].update(
                dt: dt,
                bounds: bounds,
                koiFish: fish,
                ripples: ripples,
                externalRepulsion: schoolRepulsions[i]
            )
        }

        // Tiny fish steal floating food pellets (tinyFishSteal)
        if !pellets.isEmpty {
            for i in 0..<decorativeSchools.count {
                decorativeSchools[i].performTinyFishSteal(dt: dt, pellets: &pellets) { [weak self] pos, rType in
                    guard let self = self else { return }
                    if self.ripples.count < self.maxRipples {
                        self.ripples.append(WaterRipple(center: pos, type: rType))
                    }
                }
            }
        }

        // Soft inter-school pairwise fish separation (prevents cross-school bunching)
        let crossSchoolComfort = 30.0
        for sA in 0..<decorativeSchools.count {
            for sB in (sA + 1)..<decorativeSchools.count {
                for fA in 0..<decorativeSchools[sA].fish.count {
                    for fB in 0..<decorativeSchools[sB].fish.count {
                        let diff = decorativeSchools[sA].fish[fA].position - decorativeSchools[sB].fish[fB].position
                        let distSq = diff.lengthSquared
                        if distSq < crossSchoolComfort * crossSchoolComfort && distSq > 0.001 {
                            let dist = sqrt(distSq)
                            let push = (diff / dist) * (((crossSchoolComfort - dist) / crossSchoolComfort) * 16.0 * dt)
                            decorativeSchools[sA].fish[fA].velocity += push
                            decorativeSchools[sB].fish[fB].velocity -= push
                        }
                    }
                }
            }
        }

        // 10. Update Seasonal Floating Debris & Ripple Physical Impulses
        if isFloatingDebrisEnabled {
            debrisSpawnTimer += dt
            if debrisSpawnTimer >= nextDebrisSpawnInterval {
                debrisSpawnTimer = 0.0
                nextDebrisSpawnInterval = Double.random(in: 3.5...6.5, using: &rng)
                if floatingDebris.count < maxFloatingDebris {
                    spawnSeasonalDebris()
                }
            }
        }

        // Apply physical outward ripple impulses to floating debris (Nagomi duckweed ripple response)
        if !ripples.isEmpty && !floatingDebris.isEmpty {
            for r in ripples {
                for dIdx in 0..<floatingDebris.count {
                    floatingDebris[dIdx].applyRippleImpulse(
                        rippleCenter: r.center,
                        rippleRadius: r.radius,
                        maxRadius: r.maxRadius,
                        strength: r.alpha,
                        rippleType: r.type
                    )
                }
            }
        }

        // Update debris kinematics and drag with continuous water current
        for i in 0..<floatingDebris.count {
            let current = PondWaterCurrent.currentVector(at: floatingDebris[i].position, in: bounds, time: elapsedTime)
            floatingDebris[i].update(dt: dt, bounds: bounds, current: current, time: elapsedTime)
        }

        // Remove expired debris or debris that drifted beyond margin
        let debrisMargin = 50.0
        floatingDebris.removeAll { debris in
            debris.isExpired || !bounds.contains(debris.position, inset: -debrisMargin)
        }
    }

    // MARK: - Seasonal Debris Management

    public func setSeason(_ newSeason: PondSeason) {
        self.season = newSeason
        self.seasonMode = .manual
    }

    public func setSeasonMode(_ mode: SeasonMode) {
        self.seasonMode = mode
        if mode == .autoCalendar {
            self.season = PondSeason.currentCalendarSeason()
        }
    }

    public func setFloatingDebrisEnabled(_ enabled: Bool) {
        self.isFloatingDebrisEnabled = enabled
        if !enabled {
            floatingDebris.removeAll()
        }
    }

    public func spawnSeasonalDebris(at customPosition: PondVector? = nil, type: FloatingDebrisType? = nil) {
        guard floatingDebris.count < maxFloatingDebris else { return }
        let debrisType = type ?? season.primaryDebrisType

        let pos: PondVector
        if let custom = customPosition {
            pos = bounds.clamped(custom, inset: 10.0)
        } else {
            // Spawn around edges or open water
            let edge = Int.random(in: 0...3, using: &rng)
            let x: Double
            let y: Double
            switch edge {
            case 0: // Top edge
                x = Double.random(in: bounds.minX...bounds.maxX, using: &rng)
                y = bounds.minY + Double.random(in: 10.0...40.0, using: &rng)
            case 1: // Right edge
                x = bounds.maxX - Double.random(in: 10.0...40.0, using: &rng)
                y = Double.random(in: bounds.minY...bounds.maxY, using: &rng)
            case 2: // Bottom edge
                x = Double.random(in: bounds.minX...bounds.maxX, using: &rng)
                y = bounds.maxY - Double.random(in: 10.0...40.0, using: &rng)
            default: // Left edge
                x = bounds.minX + Double.random(in: 10.0...40.0, using: &rng)
                y = Double.random(in: bounds.minY...bounds.maxY, using: &rng)
            }
            pos = PondVector(x: x, y: y)
        }

        let variant = Int.random(in: 0...1, using: &rng)
        let scale = Double.random(in: 0.85...1.15, using: &rng)
        let angle = Double.random(in: 0...(2 * .pi), using: &rng)
        let spin = Double.random(in: -0.3...0.3, using: &rng)
        let driftSpeed = Double.random(in: 2.0...6.0, using: &rng)
        let driftAngle = Double.random(in: 0...(2 * .pi), using: &rng)
        let vel = PondVector.fromAngle(driftAngle, length: driftSpeed)
        let lifespan = Double.random(in: 35.0...60.0, using: &rng)

        let debris = FloatingDebris(
            type: debrisType,
            position: pos,
            velocity: vel,
            angle: angle,
            spin: spin,
            scale: scale,
            variant: variant,
            lifespan: lifespan,
            seed: rng.next()
        )
        floatingDebris.append(debris)
    }

    public func clearFloatingDebris() {
        floatingDebris.removeAll()
    }

    public func populateSeasonalCluster(count: Int = 8, clearExisting: Bool = true) {
        guard isFloatingDebrisEnabled else { return }
        if clearExisting {
            floatingDebris.removeAll()
        }
        let targetCount = min(count, maxFloatingDebris)
        let debrisType = season.primaryDebrisType

        // Spread across open pond water (avoiding extreme edges)
        let marginX = min(120.0, bounds.width * 0.15)
        let marginY = min(120.0, bounds.height * 0.15)
        let minX = bounds.minX + marginX
        let maxX = max(minX + 10.0, bounds.maxX - marginX)
        let minY = bounds.minY + marginY
        let maxY = max(minY + 10.0, bounds.maxY - marginY)

        for _ in 0..<targetCount {
            let x = Double.random(in: minX...maxX, using: &rng)
            let y = Double.random(in: minY...maxY, using: &rng)
            let pos = PondVector(x: x, y: y)

            let variant = Int.random(in: 0...1, using: &rng)
            let scale = Double.random(in: 0.95...1.30, using: &rng)
            let angle = Double.random(in: 0...(2 * .pi), using: &rng)
            let spin = Double.random(in: -0.25...0.25, using: &rng)
            let driftSpeed = Double.random(in: 2.0...5.0, using: &rng)
            let driftAngle = Double.random(in: 0...(2 * .pi), using: &rng)
            let vel = PondVector.fromAngle(driftAngle, length: driftSpeed)
            let lifespan = Double.random(in: 45.0...80.0, using: &rng)

            var debris = FloatingDebris(
                type: debrisType,
                position: pos,
                velocity: vel,
                angle: angle,
                spin: spin,
                scale: scale,
                variant: variant,
                lifespan: lifespan,
                seed: rng.next()
            )
            // Pre-warm age and make fully visible immediately
            debris.age = Double.random(in: 2.5...12.0, using: &rng)
            debris.opacity = 1.0
            floatingDebris.append(debris)
        }
    }

    /// Enforces a physical non-penetration position relaxation constraint between fish bodies
    /// based on their exact articulated spine capsules. If the solid silhouettes of two fish
    /// intersect, they are separated along their capsule collision normal, respecting pond boundaries.
    public func resolveFishSeparation(safetyMargin: Double = 0.5) {
        guard fish.count > 1 else { return }

        // Perform 3 relaxation passes per sub-step for multi-body stability
        for _ in 0..<3 {
            var allCapsules: [[KoiBodyCapsule]] = []
            allCapsules.reserveCapacity(fish.count)
            for f in fish {
                allCapsules.append(f.bodyCapsules)
            }

            for i in 0..<fish.count {
                for j in (i + 1)..<fish.count {
                    // 1. Broadphase: check if centers are within combined physical radii
                    let diff = fish[i].position - fish[j].position
                    let maxReach = fish[i].physicalRadius + fish[j].physicalRadius + safetyMargin
                    if diff.lengthSquared > maxReach * maxReach {
                        continue
                    }

                    // 2. Narrowphase: test articulated spine capsules using precomputed capsules
                    let collision = KoiSpineGeometry.testBodyCollision(
                        capsules1: allCapsules[i],
                        capsules2: allCapsules[j],
                        fish1Position: fish[i].position,
                        fish2Position: fish[j].position,
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
