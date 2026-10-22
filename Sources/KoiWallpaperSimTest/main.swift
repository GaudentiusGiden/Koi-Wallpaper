import Foundation
import KoiWallpaperCore

struct SimTestResult {
    let name: String
    let passed: Bool
    let details: String
}

var testResults: [SimTestResult] = []

func recordSimTest(_ name: String, passed: Bool, details: String) {
    testResults.append(SimTestResult(name: name, passed: passed, details: details))
    let status = passed ? "[PASS]" : "[FAIL]"
    print("\(status) \(name): \(details)")
}

// Suite Isolation: Ensure pure simulation tests do not write to UserDefaults.standard
FeedingRoutineManager.defaultStoreProvider = { InMemoryFeedingStore() }
DailyGreetingManager.defaultStoreProvider = { InMemoryGreetingStore() }

print("=======================================================")
print("Koi Wallpaper M1 Simulation Test Suite")
print("Target: Pure Simulation Core & Behavior Verification")
print("=======================================================\n")

// -------------------------------------------------------------
// TEST 0: Standalone Tapered Capsule Collision Geometry
// -------------------------------------------------------------
print("--- 0. Standalone Tapered Capsule Geometry & Regression Tests ---")

// Regression Test 0.1: Parallel Tapered Capsules (Asymmetric Overlap)
// C1: (0,0) -> (10,0) with radius 1.0 -> 5.0
// C2: (0,4) -> (10,4) with radius 1.0 -> 1.0
// Centerline distance is 4.0 everywhere.
// At x=0: r1=1, r2=1, sum=2 < dist 4.0 (clearance 2.0).
// At x=10: r1=5, r2=1, sum=6 > dist 4.0 (overlap +2.0 pt).
// Flaw in old algorithm: evaluated centerline closest point at s=0, t=0, reporting clearance 2.0.
// Fixed algorithm: evaluates capsule endpoints and tangent boundaries, correctly detecting overlap of 2.0 pt.
let t0Capsule1 = KoiBodyCapsule(start: PondVector(x: 0, y: 0), end: PondVector(x: 10, y: 0), startRadius: 1.0, endRadius: 5.0)
let t0Capsule2 = KoiBodyCapsule(start: PondVector(x: 0, y: 4), end: PondVector(x: 10, y: 4), startRadius: 1.0, endRadius: 1.0)
let (t0Overlap1, t0Norm1, _, _) = KoiSpineGeometry.testCapsulePairCollision(t0Capsule1, t0Capsule2)
let t0_1Passed = abs(t0Overlap1 - 2.0) < 0.01 && t0Norm1.y < 0.0 // normal from C2 to C1 points downward

recordSimTest(
    "T0.1 Parallel Tapered Capsule Overlap Regression",
    passed: t0_1Passed,
    details: "overlap=\(String(format: "%.2f", t0Overlap1))pt (expected 2.00pt; old centerline algorithm missed this with -2.0pt clearance)"
)

// Regression Test 0.2: Parallel Separated Tapered Capsules
// C1: (0,0) -> (10,0) with radius 1.0 -> 3.0
// C2: (0,6) -> (10,6) with radius 1.0 -> 1.0
// At x=10: r1=3, r2=1, sum=4, dist=6 -> clearance 2.0 (overlap -2.0 pt).
let t0CapsuleSeparated1 = KoiBodyCapsule(start: PondVector(x: 0, y: 0), end: PondVector(x: 10, y: 0), startRadius: 1.0, endRadius: 3.0)
let t0CapsuleSeparated2 = KoiBodyCapsule(start: PondVector(x: 0, y: 6), end: PondVector(x: 10, y: 6), startRadius: 1.0, endRadius: 1.0)
let (t0Overlap2, _, _, _) = KoiSpineGeometry.testCapsulePairCollision(t0CapsuleSeparated1, t0CapsuleSeparated2)
let t0_2Passed = abs(t0Overlap2 - (-2.0)) < 0.01

recordSimTest(
    "T0.2 Parallel Separated Tapered Capsule Clearance",
    passed: t0_2Passed,
    details: "overlap=\(String(format: "%.2f", t0Overlap2))pt (clearance=\(String(format: "%.2f", -t0Overlap2))pt, expected 2.00pt clearance)"
)

// Regression Test 0.3: Collinear Overlapping Capsules
// C1: (0,0) -> (10,0) with radius 2.0 -> 2.0
// C2: (8,0) -> (18,0) with radius 2.0 -> 2.0
// Segments overlap on x in [8, 10] with dist 0.0 -> overlap 4.0 pt.
let t0CapsuleCollinear1 = KoiBodyCapsule(start: PondVector(x: 0, y: 0), end: PondVector(x: 10, y: 0), startRadius: 2.0, endRadius: 2.0)
let t0CapsuleCollinear2 = KoiBodyCapsule(start: PondVector(x: 8, y: 0), end: PondVector(x: 18, y: 0), startRadius: 2.0, endRadius: 2.0)
let (t0Overlap3, _, _, _) = KoiSpineGeometry.testCapsulePairCollision(t0CapsuleCollinear1, t0CapsuleCollinear2)
let t0_3Passed = abs(t0Overlap3 - 4.0) < 0.01

recordSimTest(
    "T0.3 Collinear Overlapping Capsule Penetration",
    passed: t0_3Passed,
    details: "overlap=\(String(format: "%.2f", t0Overlap3))pt (expected 4.00pt)"
)

// Regression Test 0.4: Degenerate Point Capsule vs Segment
// C1: (5,2) -> (5,2) with radius 3.0 (single disk)
// C2: (0,5) -> (10,5) with radius 1.0 -> 1.0
// Centerline distance is 3.0. Sum of radii = 3 + 1 = 4 -> overlap = 1.0 pt.
let t0CapsulePoint = KoiBodyCapsule(start: PondVector(x: 5, y: 2), end: PondVector(x: 5, y: 2), startRadius: 3.0, endRadius: 3.0)
let t0CapsuleSegment = KoiBodyCapsule(start: PondVector(x: 0, y: 5), end: PondVector(x: 10, y: 5), startRadius: 1.0, endRadius: 1.0)
let (t0Overlap4, _, _, _) = KoiSpineGeometry.testCapsulePairCollision(t0CapsulePoint, t0CapsuleSegment)
let t0_4Passed = abs(t0Overlap4 - 1.0) < 0.01

recordSimTest(
    "T0.4 Degenerate Point Capsule vs Line Capsule",
    passed: t0_4Passed,
    details: "overlap=\(String(format: "%.2f", t0Overlap4))pt (expected 1.00pt)"
)

/// Independent geometric oracle:
/// Discretizes both fish into dense disk chains along their articulated spines
/// and measures minimum surface-to-surface clearance across all disk pairs.
/// Operates independently of the solver's capsule collision and resolution pipeline.
func evaluateIndependentClearance(fish1: KoiFish, fish2: KoiFish) -> (minClearance: Double, hasPenetration: Bool) {
    let samplesPerSegment = 4
    var disks1: [(center: PondVector, radius: Double)] = []
    for cap in fish1.bodyCapsules {
        for s in 0..<samplesPerSegment {
            let t = Double(s) / Double(samplesPerSegment)
            disks1.append((cap.point(at: t), cap.radius(at: t)))
        }
    }
    if let last = fish1.bodyCapsules.last {
        disks1.append((last.point(at: 1.0), last.radius(at: 1.0)))
    }

    var disks2: [(center: PondVector, radius: Double)] = []
    for cap in fish2.bodyCapsules {
        for s in 0..<samplesPerSegment {
            let t = Double(s) / Double(samplesPerSegment)
            disks2.append((cap.point(at: t), cap.radius(at: t)))
        }
    }
    if let last = fish2.bodyCapsules.last {
        disks2.append((last.point(at: 1.0), last.radius(at: 1.0)))
    }

    var minClearance = Double.infinity
    for d1 in disks1 {
        for d2 in disks2 {
            let centerDist = d1.center.distance(to: d2.center)
            let clearance = centerDist - (d1.radius + d2.radius)
            if clearance < minClearance {
                minClearance = clearance
            }
        }
    }
    return (minClearance, minClearance < 0.0)
}

// -------------------------------------------------------------
// TEST 1: Eight Koi Initialization & Distinct Varieties
// -------------------------------------------------------------
print("\n--- 1. Koi Population & Variety Initialization ---")
let bounds = PondBounds(width: 1000.0, height: 700.0)
let sim = PondSimulation(bounds: bounds, seed: 100)

let count8 = (sim.fish.count == 8)
let uniqueIDs = (Set(sim.fish.map(\.id)).count == 8)
let uniqueVarieties = (Set(sim.fish.map(\.variety.type)).count == 8)
let allInside = sim.fish.allSatisfy { bounds.contains($0.position) }
let allMoving = sim.fish.allSatisfy { $0.speed > 0.0 }
let allArticulated = sim.fish.allSatisfy { $0.length >= 40.0 && $0.width > 10.0 }

recordSimTest(
    "T1.1 Eight Koi Fish Population",
    passed: count8 && uniqueIDs,
    details: "fishCount=\(sim.fish.count), uniqueIDs=\(Set(sim.fish.map(\.id)).count)"
)

recordSimTest(
    "T1.2 Distinct Japanese Koi Varieties",
    passed: uniqueVarieties,
    details: "varieties=\(sim.fish.map(\.variety.name).joined(separator: ", "))"
)

recordSimTest(
    "T1.3 Initial Placement & Physical Confinement",
    passed: allInside && allMoving && allArticulated,
    details: "allInsideBounds=\(allInside), allMoving=\(allMoving), allArticulated=\(allArticulated)"
)

// -------------------------------------------------------------
// TEST 2: Boundary Confinement & Continuous Swimming
// -------------------------------------------------------------
print("\n--- 2. Boundary Confinement & Smooth Avoidance ---")
let smallBounds = PondBounds(width: 500.0, height: 400.0, margin: 50.0)
let swimSim = PondSimulation(bounds: smallBounds, seed: 200)
var stayedInside = true
var minObservedX = Double.infinity
var maxObservedX = -Double.infinity
var minObservedY = Double.infinity
var maxObservedY = -Double.infinity

// Simulate 600 frames (10 seconds continuous swimming)
for _ in 0..<600 {
    swimSim.advance(deltaTime: 1.0 / 60.0)
    for f in swimSim.fish {
        minObservedX = min(minObservedX, f.position.x)
        maxObservedX = max(maxObservedX, f.position.x)
        minObservedY = min(minObservedY, f.position.y)
        maxObservedY = max(maxObservedY, f.position.y)

        if !smallBounds.contains(f.position) {
            stayedInside = false
        }
    }
}

recordSimTest(
    "T2.1 Continuous Swimming Confinement (600 frames / 10s)",
    passed: stayedInside && minObservedX > 0 && maxObservedX < smallBounds.width && minObservedY > 0 && maxObservedY < smallBounds.height,
    details: "stayedInside=\(stayedInside), X-range=[\(String(format: "%.1f", minObservedX))...\(String(format: "%.1f", maxObservedX))], Y-range=[\(String(format: "%.1f", minObservedY))...\(String(format: "%.1f", maxObservedY))]"
)

// Test boundary steering force vector
let nearLeftForce = smallBounds.boundaryAvoidanceForce(for: PondVector(x: 15.0, y: 200.0), heading: .pi)
let nearRightForce = smallBounds.boundaryAvoidanceForce(for: PondVector(x: 485.0, y: 200.0), heading: 0.0)
let centerForce = smallBounds.boundaryAvoidanceForce(for: PondVector(x: 250.0, y: 200.0), heading: 0.0)

let softTurningValid = (nearLeftForce.x > 0.0) && (nearRightForce.x < 0.0) && (abs(centerForce.x) < 0.001 && abs(centerForce.y) < 0.001)

recordSimTest(
    "T2.2 Soft Boundary Avoidance Vector Field",
    passed: softTurningValid,
    details: "nearLeftForceX=\(String(format: "%.2f", nearLeftForce.x)), nearRightForceX=\(String(format: "%.2f", nearRightForce.x)), centerForce=\(centerForce)"
)

// -------------------------------------------------------------
// TEST 3: Multi-Step Articulated Body Non-Penetration & Separation
// -------------------------------------------------------------
print("\n--- 3. Multi-Step Articulated Body Non-Penetration Dynamics ---")
// Metric explanation:
// Koi bodies are modeled as 5 articulated tapered capsules along the spine (mouth to caudal peduncle),
// matching the core body mass contour from KoiArtwork.
// On every simulation step after solver resolution:
// 1. We test geometric segment-to-segment tapered capsule intersection across all fish pairs.
// 2. We verify clearance with an independent geometric oracle (dense articulated disk chain).
// 3. We verify all fish remain inside the physical pond boundary.
// A test passes if and only if zero geometric body penetration occurs (capsule overlap <= 0, oracle penetration == false)
// and pond bounds containment is maintained throughout the entire multi-step simulation trajectory.

// Scenario A: Head-on Collision Course (2 fish with different lengths swimming directly toward each other)
let headOnFishA = KoiFish(variety: KoiVariety.allEightVarieties[0], position: PondVector(x: 300.0, y: 300.0), heading: 0.0, length: 52.0, seed: 2001)
let headOnFishB = KoiFish(variety: KoiVariety.allEightVarieties[1], position: PondVector(x: 400.0, y: 300.0), heading: .pi, length: 44.0, seed: 2002)
let headOnSim = PondSimulation(bounds: bounds, initialFish: [headOnFishA, headOnFishB], seed: 2000)

var headOnAnyOverlap = false
var headOnWorstOverlap = -Double.infinity
var headOnMinOracleClearance = Double.infinity
var headOnStayedInBounds = true

for _ in 0..<120 { // 2.0 seconds at 60 FPS
    headOnSim.advance(deltaTime: 1.0 / 60.0)
    let col = KoiSpineGeometry.testBodyCollision(fish1: headOnSim.fish[0], fish2: headOnSim.fish[1], safetyMargin: 0.0)
    if col.hasOverlap {
        headOnAnyOverlap = true
    }
    headOnWorstOverlap = max(headOnWorstOverlap, col.maxOverlap)

    let (oracleClearance, oraclePen) = evaluateIndependentClearance(fish1: headOnSim.fish[0], fish2: headOnSim.fish[1])
    if oraclePen {
        headOnAnyOverlap = true
    }
    headOnMinOracleClearance = min(headOnMinOracleClearance, oracleClearance)

    for f in headOnSim.fish {
        if !bounds.contains(f.position, inset: 10.0) {
            headOnStayedInBounds = false
        }
    }
}
let headOnPassed = !headOnAnyOverlap && headOnStayedInBounds

// Scenario B: Crossing / T-Bone Trajectory (2 fish swimming at 90° intersecting course)
// Fish A travels East across X=350, Fish B travels North across Y=300
let crossFishA = KoiFish(variety: KoiVariety.allEightVarieties[2], position: PondVector(x: 280.0, y: 300.0), heading: 0.0, length: 48.0, seed: 3001)
let crossFishB = KoiFish(variety: KoiVariety.allEightVarieties[3], position: PondVector(x: 350.0, y: 220.0), heading: .pi * 0.5, length: 56.0, seed: 3002)
let crossSim = PondSimulation(bounds: bounds, initialFish: [crossFishA, crossFishB], seed: 3000)

var crossAnyOverlap = false
var crossWorstOverlap = -Double.infinity
var crossMinOracleClearance = Double.infinity
var crossStayedInBounds = true

for _ in 0..<120 { // 2.0 seconds at 60 FPS
    crossSim.advance(deltaTime: 1.0 / 60.0)
    let col = KoiSpineGeometry.testBodyCollision(fish1: crossSim.fish[0], fish2: crossSim.fish[1], safetyMargin: 0.0)
    if col.hasOverlap {
        crossAnyOverlap = true
    }
    crossWorstOverlap = max(crossWorstOverlap, col.maxOverlap)

    let (oracleClearance, oraclePen) = evaluateIndependentClearance(fish1: crossSim.fish[0], fish2: crossSim.fish[1])
    if oraclePen {
        crossAnyOverlap = true
    }
    crossMinOracleClearance = min(crossMinOracleClearance, oracleClearance)

    for f in crossSim.fish {
        if !bounds.contains(f.position, inset: 10.0) {
            crossStayedInBounds = false
        }
    }
}
let crossPassed = !crossAnyOverlap && crossStayedInBounds

// Scenario C: Multi-Fish Convergent Water Click (3 fish of varying lengths converging on 1 splash)
let clickCenter = PondVector(x: 500.0, y: 320.0)
let cFish0 = KoiFish(variety: KoiVariety.allEightVarieties[4], position: clickCenter + PondVector(x: 90.0, y: 0.0), heading: .pi, length: 44.0, seed: 4001)
let cFish1 = KoiFish(variety: KoiVariety.allEightVarieties[5], position: clickCenter + PondVector(x: -45.0, y: 77.94), heading: -0.5236, length: 52.0, seed: 4002)
let cFish2 = KoiFish(variety: KoiVariety.allEightVarieties[6], position: clickCenter + PondVector(x: -45.0, y: -77.94), heading: 0.5236, length: 48.0, seed: 4003)
let clickSepSim = PondSimulation(bounds: bounds, initialFish: [cFish0, cFish1, cFish2], seed: 4000)

clickSepSim.handleWaterClick(at: clickCenter)

var clickAnyOverlap = false
var clickWorstOverlap = -Double.infinity
var clickMinOracleClearance = Double.infinity
var reachedProximity = false
var clickStayedInBounds = true

for _ in 0..<180 { // 3.0 seconds at 60 FPS
    clickSepSim.advance(deltaTime: 1.0 / 60.0)
    for i in 0..<clickSepSim.fish.count {
        for j in (i + 1)..<clickSepSim.fish.count {
            let col = KoiSpineGeometry.testBodyCollision(fish1: clickSepSim.fish[i], fish2: clickSepSim.fish[j], safetyMargin: 0.0)
            if col.hasOverlap {
                clickAnyOverlap = true
            }
            clickWorstOverlap = max(clickWorstOverlap, col.maxOverlap)

            let (oracleClearance, oraclePen) = evaluateIndependentClearance(fish1: clickSepSim.fish[i], fish2: clickSepSim.fish[j])
            if oraclePen {
                clickAnyOverlap = true
            }
            clickMinOracleClearance = min(clickMinOracleClearance, oracleClearance)
        }
        if !bounds.contains(clickSepSim.fish[i].position, inset: 10.0) {
            clickStayedInBounds = false
        }
    }
    if clickSepSim.fish[0].position.distance(to: clickCenter) <= 65.0 {
        reachedProximity = true
    }
}
let clickSepPassed = !clickAnyOverlap && reachedProximity && clickStayedInBounds

// Scenario D: Food Pellet Convergence (3 fish of varying lengths converging on food drop)
let foodDropPos = PondVector(x: 400.0, y: 300.0)
let fFishA = KoiFish(variety: KoiVariety.allEightVarieties[0], position: foodDropPos + PondVector(x: -70.0, y: 0.0), heading: 0.0, length: 46.0, seed: 5001)
let fFishB = KoiFish(variety: KoiVariety.allEightVarieties[1], position: foodDropPos + PondVector(x: 70.0, y: 0.0), heading: .pi, length: 54.0, seed: 5002)
let fFishC = KoiFish(variety: KoiVariety.allEightVarieties[7], position: foodDropPos + PondVector(x: 0.0, y: 70.0), heading: -.pi * 0.5, length: 50.0, seed: 5003)
let pelletA = FoodPellet(position: foodDropPos + PondVector(x: -5.0, y: -2.0), driftVelocity: .zero)
let pelletB = FoodPellet(position: foodDropPos + PondVector(x: 5.0, y: -2.0), driftVelocity: .zero)
let pelletC = FoodPellet(position: foodDropPos + PondVector(x: 0.0, y: 5.0), driftVelocity: .zero)
let foodSepSim = PondSimulation(bounds: bounds, initialFish: [fFishA, fFishB, fFishC], initialPellets: [pelletA, pelletB, pelletC], seed: 5000)

var foodAnyOverlap = false
var foodWorstOverlap = -Double.infinity
var foodMinOracleClearance = Double.infinity
var foodStayedInBounds = true

for _ in 0..<120 { // 2.0 seconds at 60 FPS
    foodSepSim.advance(deltaTime: 1.0 / 60.0)
    for i in 0..<foodSepSim.fish.count {
        for j in (i + 1)..<foodSepSim.fish.count {
            let col = KoiSpineGeometry.testBodyCollision(fish1: foodSepSim.fish[i], fish2: foodSepSim.fish[j], safetyMargin: 0.0)
            if col.hasOverlap {
                foodAnyOverlap = true
            }
            foodWorstOverlap = max(foodWorstOverlap, col.maxOverlap)

            let (oracleClearance, oraclePen) = evaluateIndependentClearance(fish1: foodSepSim.fish[i], fish2: foodSepSim.fish[j])
            if oraclePen {
                foodAnyOverlap = true
            }
            foodMinOracleClearance = min(foodMinOracleClearance, oracleClearance)
        }
        if !bounds.contains(foodSepSim.fish[i].position, inset: 10.0) {
            foodStayedInBounds = false
        }
    }
}
let foodSepPassed = !foodAnyOverlap && foodStayedInBounds

// Scenario E: Near-Wall Boundary Collision (1 fish pinned near left wall, 1 incoming fish colliding toward wall)
let wallFishA = KoiFish(variety: KoiVariety.allEightVarieties[3], position: PondVector(x: 55.0, y: 300.0), heading: .pi * 0.5, length: 50.0, seed: 6001)
let wallFishB = KoiFish(variety: KoiVariety.allEightVarieties[4], position: PondVector(x: 140.0, y: 300.0), heading: .pi, length: 52.0, seed: 6002)
let wallSim = PondSimulation(bounds: bounds, initialFish: [wallFishA, wallFishB], seed: 6000)

var wallAnyOverlap = false
var wallWorstOverlap = -Double.infinity
var wallMinOracleClearance = Double.infinity
var wallStayedInBounds = true

for _ in 0..<120 { // 2.0 seconds at 60 FPS
    wallSim.advance(deltaTime: 1.0 / 60.0)
    let col = KoiSpineGeometry.testBodyCollision(fish1: wallSim.fish[0], fish2: wallSim.fish[1], safetyMargin: 0.0)
    if col.hasOverlap {
        wallAnyOverlap = true
    }
    wallWorstOverlap = max(wallWorstOverlap, col.maxOverlap)

    let (oracleClearance, oraclePen) = evaluateIndependentClearance(fish1: wallSim.fish[0], fish2: wallSim.fish[1])
    if oraclePen {
        wallAnyOverlap = true
    }
    wallMinOracleClearance = min(wallMinOracleClearance, oracleClearance)

    for f in wallSim.fish {
        if !bounds.contains(f.position, inset: 10.0) {
            wallStayedInBounds = false
        }
    }
}
let wallPassed = !wallAnyOverlap && wallStayedInBounds

let t3AllPassed = headOnPassed && crossPassed && clickSepPassed && foodSepPassed && wallPassed

recordSimTest(
    "T3.1 Multi-Step Articulated Body Non-Penetration Dynamics",
    passed: t3AllPassed,
    details: "Zero penetration verified across 5 seeded multi-step scenarios: " +
        "HeadOn(capsuleOverlap=\(String(format: "%.2f", headOnWorstOverlap))pt, oracleClearance=\(String(format: "%.2f", headOnMinOracleClearance))pt), " +
        "Cross(capsuleOverlap=\(String(format: "%.2f", crossWorstOverlap))pt, oracleClearance=\(String(format: "%.2f", crossMinOracleClearance))pt), " +
        "ClickConv(capsuleOverlap=\(String(format: "%.2f", clickWorstOverlap))pt, oracleClearance=\(String(format: "%.2f", clickMinOracleClearance))pt), " +
        "FoodConv(capsuleOverlap=\(String(format: "%.2f", foodWorstOverlap))pt, oracleClearance=\(String(format: "%.2f", foodMinOracleClearance))pt), " +
        "NearWall(capsuleOverlap=\(String(format: "%.2f", wallWorstOverlap))pt, oracleClearance=\(String(format: "%.2f", wallMinOracleClearance))pt). " +
        "Boundary containment=true on all steps."
)

// -------------------------------------------------------------
// TEST 4: Regular Click Target & Return to Wandering
// -------------------------------------------------------------
print("\n--- 4. Water Click Temporary Target & Return to Wander ---")
let clickSim = PondSimulation(bounds: bounds, seed: 400)
let clickPos = PondVector(x: 500.0, y: 350.0)
clickSim.handleWaterClick(at: clickPos)

let rippleCreated = (clickSim.ripples.count == 1 && clickSim.ripples[0].type == .waterCall)
let targetCreated = (clickSim.clickTargets.count == 1)
let attractedFishCount = clickSim.fish.filter { $0.state == .investigatingClick }.count
let attractedOk = (attractedFishCount > 0)

// Fast-forward past target duration (5.0 seconds = 300 frames)
for _ in 0..<360 {
    clickSim.advance(deltaTime: 1.0 / 60.0)
}

let targetExpired = (clickSim.clickTargets.isEmpty)
let fishReturnedToWandering = clickSim.fish.allSatisfy { $0.state == .wandering }

recordSimTest(
    "T4.1 Water Click Attraction & Graceful Wander Return",
    passed: rippleCreated && targetCreated && attractedOk && targetExpired && fishReturnedToWandering,
    details: "rippleCreated=\(rippleCreated), targetCreated=\(targetCreated), attractedCount=\(attractedFishCount), targetExpired=\(targetExpired), allReturnedToWander=\(fishReturnedToWandering)"
)

// -------------------------------------------------------------
// TEST 5: Option+Click Food Pellet Placement
// -------------------------------------------------------------
print("\n--- 5. Option+Click Food Drop & Pellet Distribution ---")
let foodSim = PondSimulation(bounds: bounds, seed: 500)
let foodPos = PondVector(x: 420.0, y: 280.0)
foodSim.handleFoodDrop(at: foodPos, pelletCount: 5)

let pelletsSpawned = (foodSim.pellets.count == 5)
let foodRippleSpawned = (foodSim.ripples.count == 1 && foodSim.ripples[0].type == .foodDrop)
let allPelletsUnconsumed = foodSim.pellets.allSatisfy { !$0.isConsumed && $0.consumerFishId == nil }
let pelletsClusteredNearClick = foodSim.pellets.allSatisfy { $0.position.distance(to: foodPos) < 30.0 }

recordSimTest(
    "T5.1 Option+Click Food Drop Accuracy & State",
    passed: pelletsSpawned && foodRippleSpawned && allPelletsUnconsumed && pelletsClusteredNearClick,
    details: "pelletsCount=\(foodSim.pellets.count), rippleType=\(foodSim.ripples.first?.type == .foodDrop ? "foodDrop" : "none"), clusteredNearClick=\(pelletsClusteredNearClick)"
)

// -------------------------------------------------------------
// TEST 6: Strict Single Consumption Guarantee
// -------------------------------------------------------------
print("\n--- 6. Food Consumption Semantics ---")
let consumeSim = PondSimulation(bounds: bounds, seed: 600)
let hungryFish = consumeSim.fish[0]
let mouthPoint = hungryFish.mouthPosition

// Drop a single pellet directly at fish's mouth without scatter
consumeSim.handleFoodDrop(at: mouthPoint, pelletCount: 1, scatterRadius: 0.0)
let initialPelletCount = consumeSim.pellets.count
let targetPelletId = consumeSim.pellets[0].id

// Step 1: Fish should consume the pellet
consumeSim.stepSimulation(dt: 1.0 / 60.0)

let pelletPurged = (consumeSim.pellets.count == 0)
let eatingRippleSpawned = consumeSim.ripples.contains { $0.type == .eatingNibble }

// Test atomic single consumption programmatically
var atomicPellet = FoodPellet(id: targetPelletId, position: mouthPoint)
let firstEat = atomicPellet.consume(by: hungryFish.id)
let secondEat = atomicPellet.consume(by: consumeSim.fish[1].id)

let singleConsumptionStrict = (firstEat == true) && (secondEat == false) && (atomicPellet.consumerFishId == hungryFish.id)

recordSimTest(
    "T6.1 Strict Single-Consumption Guarantee",
    passed: (initialPelletCount == 1) && pelletPurged && eatingRippleSpawned && singleConsumptionStrict,
    details: "firstEat=\(firstEat), secondEatAttempt=\(secondEat) (rejected), consumerFish=\(hungryFish.variety.name), nibbleRippleSpawned=\(eatingRippleSpawned)"
)

// -------------------------------------------------------------
// TEST 7: Capacity Caps on Pellets and Ripples
// -------------------------------------------------------------
print("\n--- 7. Capacity Caps on Interactive Objects ---")
let capSim = PondSimulation(bounds: bounds, seed: 700)

// Attempt to drop 120 pellets (cap is 48)
for _ in 0..<25 {
    capSim.handleFoodDrop(at: PondVector(x: 400.0, y: 300.0), pelletCount: 6)
}
let pelletCapRespected = (capSim.pellets.count == capSim.maxPellets)

// Attempt to spawn 100 ripples (cap is 64)
for _ in 0..<100 {
    capSim.handleWaterClick(at: PondVector(x: 400.0, y: 300.0))
}
let rippleCapRespected = (capSim.ripples.count == capSim.maxRipples)

recordSimTest(
    "T7.1 Interactive Object Capacity Limits",
    passed: pelletCapRespected && rippleCapRespected,
    details: "pellets=\(capSim.pellets.count)/\(capSim.maxPellets), ripples=\(capSim.ripples.count)/\(capSim.maxRipples). Inputs when full do not exceed limits."
)

// -------------------------------------------------------------
// TEST 8: Unconsumed Pellet Expiration
// -------------------------------------------------------------
print("\n--- 8. Unconsumed Pellet Expiration ---")
var isolatedPellet = FoodPellet(position: PondVector(x: 20.0, y: 20.0), age: 24.8, lifetime: 25.0)
let beforeExpiry = !isolatedPellet.isExpired
isolatedPellet.update(dt: 0.5, bounds: bounds)
let afterExpiry = isolatedPellet.isExpired

recordSimTest(
    "T8.1 Unconsumed Food Expiration (25s Lifetime)",
    passed: beforeExpiry && afterExpiry,
    details: "before(age=24.8s): expired=\(!beforeExpiry), after(age=25.3s): expired=\(afterExpiry). Stale pellets gracefully expire."
)

// -------------------------------------------------------------
// TEST 9: Frame-Rate Independence & Timing Stability
// -------------------------------------------------------------
print("\n--- 9. Frame-Rate Independence & Deterministic Timing ---")
let testBounds = PondBounds(width: 800.0, height: 600.0)

// Sim 1: 60 FPS (dt = 1/60) for 60 iterations
let sim60 = PondSimulation(bounds: testBounds, seed: 900)
let initialPhase60 = sim60.fish[0].wigglePhase
for _ in 0..<60 {
    sim60.advance(deltaTime: 1.0 / 60.0)
}

// Sim 2: 30 FPS (dt = 1/30) for 30 iterations
let sim30 = PondSimulation(bounds: testBounds, seed: 900)
let initialPhase30 = sim30.fish[0].wigglePhase
for _ in 0..<30 {
    sim30.advance(deltaTime: 1.0 / 30.0)
}

func phaseMatchesExpectedAdvance(_ phaseAfter: Double, phaseBefore: Double, radians: Double) -> Bool {
    let expectedPhase = (phaseBefore + radians).truncatingRemainder(dividingBy: 2.0 * .pi)
    return abs(phaseAfter - expectedPhase) < 0.0001
}

// Wandering fish stay at base speed, so the swim phase should advance by
// wiggleFrequency * 1 second regardless of how render-frame deltas are grouped.
let phaseAdvance60 = phaseMatchesExpectedAdvance(sim60.fish[0].wigglePhase, phaseBefore: initialPhase60, radians: 6.0)
let phaseAdvance30 = phaseMatchesExpectedAdvance(sim30.fish[0].wigglePhase, phaseBefore: initialPhase30, radians: 6.0)
let timingStable = (sim60.fish.count == 8 && sim30.fish.count == 8 && phaseAdvance60 && phaseAdvance30)

recordSimTest(
    "T9.1 Frame-Rate Independence Across 60 FPS vs 30 FPS",
    passed: timingStable,
    details: "60 FPS and 30 FPS schedules both advance the 6 rad/s swim phase by 6 radians over 1 second (60 fixed steps); randomized wandering paths are not compared."
)

// -------------------------------------------------------------
// TEST 10: Pause & Catch-Up Delta Limiting
// -------------------------------------------------------------
print("\n--- 10. Pause & Lag Catch-Up Clamping ---")
let pauseSim = PondSimulation(bounds: testBounds, seed: 1000)
let posBeforePause = pauseSim.fish[0].position

pauseSim.isPaused = true
pauseSim.advance(deltaTime: 5.0)
let posDuringPause = pauseSim.fish[0].position
let pauseFrozen = (posDuringPause.x == posBeforePause.x && posDuringPause.y == posBeforePause.y)

pauseSim.isPaused = false
// Advance with large 15.0 second lag spike
pauseSim.advance(deltaTime: 15.0)
let posAfterLag = pauseSim.fish[0].position
let lagDistance = posAfterLag.distance(to: posDuringPause)

// Clamped to at most maxCatchUpDelta (0.10s) -> distance should be at most ~15 points, not 15s * 50 = 750 points!
let catchUpClamped = (lagDistance < 25.0)

recordSimTest(
    "T10.1 Simulation Pause & Lag Catch-Up Clamping",
    passed: pauseFrozen && catchUpClamped,
    details: "frozenDuringPause=\(pauseFrozen), lagDistanceAfter15sLag=\(String(format: "%.1f", lagDistance)) points (clamped to maxCatchUp 0.10s, prevents teleportation)"
)

// -------------------------------------------------------------
// TEST 11: Responsive Production Geometry
// -------------------------------------------------------------
print("\n--- 11. Responsive Koi Geometry ---")
let geometryWorld = PondSimulation(bounds: PondBounds(width: 1024, height: 640), seed: 1100)
let originalIDs = geometryWorld.fish.map(\.id)
let originalLengths = geometryWorld.fish.map(\.length)
let originalCenters = geometryWorld.fish.map(\.position)
let sizedForViewport = geometryWorld.fish.allSatisfy {
    let silhouette = $0.length * 1.16 / 640
    return silhouette >= 0.119 && silhouette <= 0.181 && abs($0.width / $0.length - 0.34) < 0.00001
}
geometryWorld.resize(width: 1536, height: 960)
let scaledGeometry = geometryWorld.fish.enumerated().allSatisfy { index, fish in
    abs(fish.length / originalLengths[index] - 1.5) < 0.00001 &&
    fish.position.distance(to: originalCenters[index] * 1.5) < 0.01
}
let custom = KoiFish(variety: KoiVariety.allEightVarieties[0], position: PondVector(x: 500, y: 320), length: 52, seed: 1101)
let customWorld = PondSimulation(bounds: PondBounds(width: 1024, height: 640), initialFish: [custom], seed: 1102)
customWorld.resize(width: 480, height: 320)
let explicitGeometryPreserved = customWorld.fish[0].length == 52 && abs(customWorld.fish[0].width / 52 - 0.28) < 0.00001
recordSimTest("T11.1 Responsive Geometry, Identity and Custom Fixture Compatibility",
              passed: sizedForViewport && scaledGeometry && geometryWorld.fish.map(\.id) == originalIDs && explicitGeometryPreserved,
              details: "productionProportions=\(sizedForViewport), proportionalResize=\(scaledGeometry), customDimensionsPreserved=\(explicitGeometryPreserved)")

let stressBounds = PondBounds(width: 1024, height: 640)
let production = PondSimulation(bounds: stressBounds, seed: 1200).fish
var profileStressPassed = true
var stressDetails: [String] = []
for scenario in 0..<5 {
    let center = stressBounds.center
    var fixtures: [KoiFish] = []
    let count = scenario == 2 || scenario == 3 ? 3 : 2
    for i in 0..<count {
        var fish = production[(i * 3 + scenario) % 8]
        switch scenario {
        case 0:
            fish.position = center + PondVector(x: i == 0 ? -130 : 130, y: 0)
            fish.heading = i == 0 ? 0 : .pi
        case 1:
            fish.position = center + (i == 0 ? PondVector(x: -180, y: 0) : PondVector(x: 0, y: -180))
            fish.heading = i == 0 ? 0 : .pi / 2
        case 2, 3:
            let angle = Double(i) * 2 * Double.pi / 3
            fish.position = center + PondVector.fromAngle(angle, length: 150)
            fish.heading = angle + .pi
        default:
            fish.position = PondVector(x: 95 + Double(i) * 75, y: 260)
            fish.heading = i == 0 ? 0 : .pi
        }
        fixtures.append(fish)
    }
    let world = PondSimulation(bounds: stressBounds, initialFish: fixtures, seed: UInt64(1300 + scenario))
    world.clampAllEntitiesToBounds()
    world.resolveFishSeparation()
    if scenario == 2 { world.handleWaterClick(at: center) }
    if scenario == 3 { world.handleFoodDrop(at: center) }
    var minClearance = Double.infinity
    var stayedInside = true
    var clear = true
    for frame in 0..<600 {
        if scenario == 4 && frame == 240 { world.resize(width: 720, height: 480) }
        world.advance(deltaTime: 1.0 / 60)
        for fish in world.fish {
            if !world.bounds.contains(fish.position, inset: min(fish.physicalRadius, min(world.bounds.width, world.bounds.height) * 0.45) - 0.01) { stayedInside = false }
        }
        for i in world.fish.indices {
            for j in (i + 1)..<world.fish.count {
                let result = evaluateIndependentClearance(fish1: world.fish[i], fish2: world.fish[j])
                minClearance = min(minClearance, result.minClearance)
                if result.hasPenetration || world.fish[i].bodyCollision(with: world.fish[j]).maxOverlap > 0.01 { clear = false }
            }
        }
    }
    profileStressPassed = profileStressPassed && stayedInside && clear
    stressDetails.append(String(format: "scenario%d(clear=%@, bounds=%@, clearance=%.2fpt)", scenario, String(clear), String(stayedInside), minClearance))
}
recordSimTest("T11.2 Production-Size Collision and Resize Stress (Independent Oracle)",
              passed: profileStressPassed, details: stressDetails.joined(separator: "; "))

// -------------------------------------------------------------
// TEST 12: Surface Visitors & Fish Dynamics (Milestone M5)
// -------------------------------------------------------------
print("\n--- 12. Surface Visitors & Fish Motion Dynamics (Milestone M5) ---")

// T12.1 Surface Visitors (Swan & Ball) Kinematics & Confinement
let visitorSim = PondSimulation(bounds: PondBounds(width: 800, height: 600), seed: 5001)
let swan1 = visitorSim.spawnVisitor(type: PondVisitorType.swan, at: PondVector(x: 200, y: 300))
let ball1 = visitorSim.spawnVisitor(type: PondVisitorType.ball, at: PondVector(x: 600, y: 300))

var visitorsStayedInBounds = true
for _ in 0..<300 { // 5 seconds at 60Hz
    visitorSim.stepSimulation(dt: 1.0 / 60.0)
    for v in visitorSim.visitors {
        if !visitorSim.bounds.contains(v.position, inset: v.radius) {
            visitorsStayedInBounds = false
        }
    }
}
let t12_1Passed = (visitorSim.visitors.count == 2) && visitorsStayedInBounds && (swan1.speed > 0.0) && (ball1.radius > 0.0)
recordSimTest(
    "T12.1 Surface Visitors (Swan & Ball) Kinematics & Confinement",
    passed: t12_1Passed,
    details: "count=\(visitorSim.visitors.count), stayedInBounds=\(visitorsStayedInBounds), swanSpeed=\(String(format: "%.1f", swan1.speed))pt/s, ballRadius=\(String(format: "%.1f", ball1.radius))pt"
)

// T12.2 Fish Curiosity & Attraction to Visitors
let attractBounds = PondBounds(width: 800, height: 600)
var curiousFish = KoiFish(
    variety: KoiVariety.allEightVarieties[0],
    position: PondVector(x: 350, y: 300),
    heading: 0.0,
    length: 50.0,
    baseSpeed: 50.0,
    seed: 5002
)
curiousFish.traits = FishTraits(curiosity: 0.85, boldness: 0.6, agility: 1.0, feedingEagerness: 0.5)
let attractSim = PondSimulation(bounds: attractBounds, initialFish: [curiousFish], seed: 5003)
let targetSwan = attractSim.spawnVisitor(type: PondVisitorType.swan, at: PondVector(x: 420, y: 300))

var fishTargetedVisitor = false
var fishApproached = false
for _ in 0..<60 { // Up to 1 second
    attractSim.stepSimulation(dt: 1.0 / 60.0)
    let f = attractSim.fish[0]
    if f.state == KoiBehaviorState.investigatingVisitor && f.targetVisitorId == targetSwan.id {
        fishTargetedVisitor = true
    }
    if f.position.distance(to: targetSwan.position) < 80.0 {
        fishApproached = true
    }
}
let t12_2Passed = fishTargetedVisitor && fishApproached
recordSimTest(
    "T12.2 Fish Curiosity & Attraction to Visitors",
    passed: t12_2Passed,
    details: "targetedVisitor=\(fishTargetedVisitor), approached=\(fishApproached), state=\(attractSim.fish[0].state.rawValue)"
)

// T12.3 Safe Visitor Removal & Zero Stuck Fish Guarantee
let removalBounds = PondBounds(width: 800, height: 600)
var followingFish = KoiFish(
    variety: KoiVariety.allEightVarieties[1],
    position: PondVector(x: 300, y: 300),
    heading: 0.0,
    length: 50.0,
    baseSpeed: 50.0,
    seed: 5004
)
followingFish.traits = FishTraits(curiosity: 0.90, boldness: 0.6, agility: 1.0, feedingEagerness: 0.5)
let removalSim = PondSimulation(bounds: removalBounds, initialFish: [followingFish], seed: 5005)
let swanToRemove = removalSim.spawnVisitor(type: PondVisitorType.swan, at: PondVector(x: 360, y: 300))

// Step until fish investigates the visitor
for _ in 0..<30 {
    removalSim.stepSimulation(dt: 1.0 / 60.0)
    if removalSim.fish[0].state == KoiBehaviorState.investigatingVisitor { break }
}
let wasInvestigating = (removalSim.fish[0].state == KoiBehaviorState.investigatingVisitor)

// Explicitly remove the visitor
removalSim.removeVisitor(id: swanToRemove.id)

// Verify fish target is immediately cleared
let targetImmediatelyCleared = (removalSim.fish[0].currentTarget == nil &&
                                removalSim.fish[0].targetVisitorId == nil &&
                                removalSim.fish[0].state == KoiBehaviorState.wandering)

// Advance 120 steps and verify fish swims smoothly without being stuck
var continuedSwimming = true
let posBefore = removalSim.fish[0].position
for _ in 0..<120 {
    removalSim.stepSimulation(dt: 1.0 / 60.0)
}
let posAfter = removalSim.fish[0].position
let displacement = posBefore.distance(to: posAfter)
continuedSwimming = (displacement > 20.0) && (removalSim.fish[0].state == KoiBehaviorState.wandering)

let t12_3Passed = wasInvestigating && targetImmediatelyCleared && continuedSwimming
recordSimTest(
    "T12.3 Safe Visitor Removal & Zero Stuck Fish Guarantee",
    passed: t12_3Passed,
    details: "wasInvestigating=\(wasInvestigating), immediatelyCleared=\(targetImmediatelyCleared), continuedSwimming=\(continuedSwimming), displacement=\(String(format: "%.1f", displacement))pt"
)

// T12.4 Ball Nudge Physical Impulse & Ripple Reaction
let nudgeBounds = PondBounds(width: 800, height: 600)
var nudgingFish = KoiFish(
    variety: KoiVariety.allEightVarieties[3],
    position: PondVector(x: 280, y: 300),
    heading: 0.0, // Head pointing right toward (300, 300)
    length: 50.0,
    baseSpeed: 60.0,
    seed: 5006
)
let nudgeSim = PondSimulation(bounds: nudgeBounds, initialFish: [nudgingFish], seed: 5007)
let ballToNudge = nudgeSim.spawnVisitor(type: PondVisitorType.ball, at: PondVector(x: 310, y: 300))
let initialBallVel = ballToNudge.velocity

var ballNudged = false
var rippleSpawned = false
for _ in 0..<60 {
    nudgeSim.stepSimulation(dt: 1.0 / 60.0)
    if let currentBall = nudgeSim.visitors.first(where: { $0.id == ballToNudge.id }) {
        if currentBall.velocity.distance(to: initialBallVel) > 5.0 {
            ballNudged = true
        }
    }
    if nudgeSim.ripples.contains(where: { $0.type == RippleType.waterCall }) {
        rippleSpawned = true
    }
    if ballNudged && rippleSpawned { break }
}
let t12_4Passed = ballNudged && rippleSpawned
recordSimTest(
    "T12.4 Ball Nudge Physical Impulse & Ripple Reaction",
    passed: t12_4Passed,
    details: "ballNudged=\(ballNudged), rippleSpawned=\(rippleSpawned)"
)

// -------------------------------------------------------------
// TEST 13: Pond Insects & Koi Curiosity Reaction
// -------------------------------------------------------------
print("\n--- 13. Pond Insects & Koi Curiosity Dynamics ---")

// T13.1 Theme Insect Population & Species Selection
let themesToTest: [PondTheme] = [.day, .dawn, .goldenHour, .dusk, .deepClear, .rain, .night]
var allThemesCompliant = true
var themeDetails: [String] = []

for th in themesToTest {
    let testSim = PondSimulation(theme: th)
    let inCount = testSim.insects.count
    let dfCount = testSim.insects.filter { $0.type == .dragonfly }.count
    let bfCount = testSim.insects.filter { $0.type == .butterfly }.count
    let ffCount = testSim.insects.filter { $0.type == .firefly }.count

    if th.isNight {
        let isCorrect = (inCount == 4 && ffCount == 4 && dfCount == 0 && bfCount == 0)
        if !isCorrect { allThemesCompliant = false }
        themeDetails.append("\(th.rawValue): ff=\(ffCount)/4")
    } else {
        let isCorrect = (inCount == 4 && dfCount == 2 && bfCount == 2 && ffCount == 0)
        if !isCorrect { allThemesCompliant = false }
        themeDetails.append("\(th.rawValue): df=\(dfCount),bf=\(bfCount)")
    }
}

recordSimTest(
    "T13.1 Theme Insect Population & Species Selection",
    passed: allThemesCompliant,
    details: themeDetails.joined(separator: ", ")
)

// T13.2 Theme Transition Insect Cross-Fading
let transSim = PondSimulation(theme: .day)
// Transition Day -> Night
transSim.updateThemeTransition(from: .day, to: .night, progress: 0.0)
let p0_dayOp = transSim.insects.filter { $0.type != .firefly }.map(\.opacity).first ?? 0
let p0_nightOp = transSim.insects.filter { $0.type == .firefly }.map(\.opacity).first ?? 0

transSim.updateThemeTransition(from: .day, to: .night, progress: 0.5)
let p50_count = transSim.insects.count
let p50_dayOp = transSim.insects.filter { $0.type != .firefly }.map(\.opacity).first ?? 0
let p50_nightOp = transSim.insects.filter { $0.type == .firefly }.map(\.opacity).first ?? 0

transSim.updateThemeTransition(from: .day, to: .night, progress: 1.0)
let p100_count = transSim.insects.count
let p100_allFireflies = transSim.insects.allSatisfy { $0.type == .firefly && $0.opacity == 1.0 }

// Transition Night -> Dawn (Non-Night)
transSim.updateThemeTransition(from: .night, to: .dawn, progress: 0.5)
let back50_count = transSim.insects.count
transSim.updateThemeTransition(from: .night, to: .dawn, progress: 1.0)
let dawn_count = transSim.insects.count
let dawn_nonNight = transSim.insects.filter { $0.type == .dragonfly }.count == 2 &&
                    transSim.insects.filter { $0.type == .butterfly }.count == 2

// Transition Day -> Dusk (Non-Night to Non-Night preserve same 4)
let beforeDuskIds = transSim.insects.map(\.id)
transSim.updateThemeTransition(from: .dawn, to: .dusk, progress: 0.5)
transSim.updateThemeTransition(from: .dawn, to: .dusk, progress: 1.0)
let dusk_count = transSim.insects.count
let duskPreserved = (transSim.insects.map(\.id) == beforeDuskIds)

let t13_2Passed = (p0_dayOp == 1.0 && p0_nightOp == 0.0) &&
                  (p50_count == 8 && abs(p50_dayOp - 0.5) < 0.01 && abs(p50_nightOp - 0.5) < 0.01) &&
                  (p100_count == 4 && p100_allFireflies) &&
                  (back50_count == 8 && dawn_count == 4 && dawn_nonNight) &&
                  (dusk_count == 4 && duskPreserved)

recordSimTest(
    "T13.2 Theme Transition Insect Cross-Fading",
    passed: t13_2Passed,
    details: "p0=(day:\(p0_dayOp),night:\(p0_nightOp)), p50=(count:\(p50_count),day:\(p50_dayOp),night:\(p50_nightOp)), p100=(count:\(p100_count),fireflies:\(p100_allFireflies)), duskPreserved=\(duskPreserved)"
)

// T13.3 Insect Kinematics, Bounds Confinement & Pause Freeze
let kinSim = PondSimulation(bounds: PondBounds(width: 800.0, height: 600.0), theme: .day)
var allInBounds = true
var sawDarting = false

for _ in 0..<600 {
    kinSim.stepSimulation(dt: 1.0 / 60.0)
    for insect in kinSim.insects {
        if !kinSim.bounds.contains(insect.position) {
            allInBounds = false
        }
        if insect.isDarting { sawDarting = true }
    }
}

// Pause freeze test
kinSim.isPaused = true
let frozenPositions = kinSim.insects.map(\.position)
let frozenPhases = kinSim.insects.map(\.phase)
for _ in 0..<60 {
    kinSim.advance(deltaTime: 1.0 / 60.0)
}
let afterPausePositions = kinSim.insects.map(\.position)
let afterPausePhases = kinSim.insects.map(\.phase)
let freezeSuccess = (frozenPositions == afterPausePositions) && (frozenPhases == afterPausePhases)

let t13_3Passed = allInBounds && sawDarting && freezeSuccess
recordSimTest(
    "T13.3 Insect Kinematics, Confinement & Pause Freeze",
    passed: t13_3Passed,
    details: "allInBounds=\(allInBounds), sawDarting=\(sawDarting), freezeSuccess=\(freezeSuccess)"
)

// T13.4 Koi Following Moving Insect Target, Duration Timeout & Zero Stuck Guarantee
let followSim = PondSimulation(bounds: PondBounds(width: 800.0, height: 600.0), theme: .day)
let targetInsect = followSim.insects[0]
followSim.setFishTarget(at: 0, target: targetInsect.position, state: .followingInsect, duration: 5.5, insectId: targetInsect.id)

var trackedMovement = false
let initialFishPos = followSim.fish[0].position

for _ in 0..<120 {
    followSim.stepSimulation(dt: 1.0 / 60.0)
    if followSim.fish[0].state == .followingInsect {
        if let currentTarget = followSim.fish[0].currentTarget {
            let activeInsect = followSim.insects.first(where: { $0.id == targetInsect.id })!
            if currentTarget.distance(to: activeInsect.position) < 0.01 {
                trackedMovement = true
            }
        }
    }
}

let movedDuringFollow = followSim.fish[0].position.distance(to: initialFishPos) > 10.0

// Advance remaining steps until 5.5s timeout expires (330 steps total at 60Hz)
for _ in 0..<250 {
    followSim.stepSimulation(dt: 1.0 / 60.0)
}
let returnedToWanderAfterTimeout = (followSim.fish[0].state == .wandering && followSim.fish[0].currentTarget == nil)

// Zero stuck fish guarantee on insect clear
followSim.setFishTarget(at: 1, target: followSim.insects[1].position, state: .followingInsect, duration: 5.5, insectId: followSim.insects[1].id)
let wasFollowingBeforeClear = (followSim.fish[1].state == .followingInsect)
followSim.clearInsects()
followSim.stepSimulation(dt: 1.0 / 60.0)
let immediatelyClearedStuckFish = (followSim.fish[1].state == .wandering && followSim.fish[1].currentTarget == nil)

let t13_4Passed = trackedMovement && movedDuringFollow && returnedToWanderAfterTimeout && wasFollowingBeforeClear && immediatelyClearedStuckFish
recordSimTest(
    "T13.4 Koi Following Moving Target, Timeout & Zero Stuck Guarantee",
    passed: t13_4Passed,
    details: "trackedMovement=\(trackedMovement), moved=\(movedDuringFollow), returnedAfterTimeout=\(returnedToWanderAfterTimeout), immediatelyCleared=\(immediatelyClearedStuckFish)"
)

// T13.5 Food and Click Priority Over Insect Following
let prioSim = PondSimulation(bounds: PondBounds(width: 800.0, height: 600.0), theme: .day)
// Assign fish 0 to insect
let insectToFollow = prioSim.insects[0]
prioSim.setFishTarget(at: 0, target: insectToFollow.position, state: .followingInsect, duration: 5.5, insectId: insectToFollow.id)

// Drop food near fish 0: fish 0 should immediately switch to .seekingFood
prioSim.handleFoodDrop(at: prioSim.fish[0].position)
let foodOverrodeInsect = (prioSim.fish[0].state == .seekingFood)

// Assign fish 1 to insect
prioSim.setFishTarget(at: 1, target: prioSim.insects[1].position, state: .followingInsect, duration: 5.5, insectId: prioSim.insects[1].id)
// Click water near fish 1: should switch to .investigatingClick
prioSim.handleWaterClick(at: prioSim.fish[1].position + PondVector(x: 20.0, y: 0.0))
let clickOverrodeInsect = (prioSim.fish[1].state == .investigatingClick)

let t13_5Passed = foodOverrodeInsect && clickOverrodeInsect
recordSimTest(
    "T13.5 Food & Click Priority Over Insect Following",
    passed: t13_5Passed,
    details: "foodOverrode=\(foodOverrodeInsect), clickOverrode=\(clickOverrodeInsect)"
)

// -------------------------------------------------------------
// TEST 14: Pond Frog Simulation & Lifecycle Dynamics
// -------------------------------------------------------------
print("\n--- 14. Pond Frog (Katak Teratai) Lifecycle Dynamics ---")

// T14.1 Initial Perched State & Lily Pad Alignment
let frogSim = PondSimulation(bounds: PondBounds(width: 800.0, height: 600.0), theme: .day)
let initialFrog = frogSim.frog
let initialPerched = (initialFrog.state == .perched)
let initialVisible = initialFrog.isVisible
let initialAtPerch = (initialFrog.position == initialFrog.perchPosition)
let perchInBounds = frogSim.bounds.contains(PondVector(x: Double(initialFrog.perchPosition.x), y: Double(initialFrog.perchPosition.y)))

let t14_1Passed = initialPerched && initialVisible && initialAtPerch && perchInBounds
recordSimTest(
    "T14.1 Pond Frog Initial Perched State & Pad Placement",
    passed: t14_1Passed,
    details: "state=\(initialFrog.state), isVisible=\(initialVisible), perchPos=(\(String(format: "%.1f", initialFrog.perchPosition.x)), \(String(format: "%.1f", initialFrog.perchPosition.y))), inBounds=\(perchInBounds)"
)

// T14.2 Idle Micro-Animations (Throat breathing, croak, blink, head twitch)
var sawBreathing = false
var sawBlink = false
var sawCroak = false
var sawHeadTwitch = false
let initialThroat = frogSim.frog.throatPhase
let initialHeadOffset = frogSim.frog.headAngleOffset

// Step for 8 seconds (idle perched period)
for _ in 0..<480 {
    frogSim.stepSimulation(dt: 1.0 / 60.0)
    if frogSim.frog.state == .perched {
        if abs(frogSim.frog.throatPhase - initialThroat) > 1.0 { sawBreathing = true }
        if frogSim.frog.isBlinking { sawBlink = true }
        if frogSim.frog.croakProgress > 0.05 { sawCroak = true }
        if abs(frogSim.frog.headAngleOffset - initialHeadOffset) > 0.01 { sawHeadTwitch = true }
    }
}

let t14_2Passed = sawBreathing && (sawBlink || sawCroak || sawHeadTwitch)
recordSimTest(
    "T14.2 Pond Frog Idle Micro-Animations (Breathing, Blink, Croak)",
    passed: t14_2Passed,
    details: "sawBreathing=\(sawBreathing), sawBlink=\(sawBlink), sawCroak=\(sawCroak), sawHeadTwitch=\(sawHeadTwitch)"
)

// T14.3 Leap Out Arc, Parabolic Altitude & Water Landing Splash Ripple
let jumpSim = PondSimulation(bounds: PondBounds(width: 800.0, height: 600.0), theme: .day)
jumpSim.frog.triggerJumpIfPerched() // Start leap
let beganCrouch = (jumpSim.frog.state == .crouching)

// Advance past crouch into jumpingOut
jumpSim.stepSimulation(dt: 0.20)
let inAirborneLeap = (jumpSim.frog.state == .jumpingOut)
var maxAltitudeRecorded: CGFloat = 0.0

let rippleCountBeforeSplash = jumpSim.ripples.count
while jumpSim.frog.state == .jumpingOut {
    maxAltitudeRecorded = max(maxAltitudeRecorded, jumpSim.frog.altitude)
    jumpSim.stepSimulation(dt: 1.0 / 60.0)
}

let reachedApex = maxAltitudeRecorded >= 20.0
let submergedAway = (jumpSim.frog.state == .away && !jumpSim.frog.isVisible)
let splashRippleSpawned = (jumpSim.ripples.count > rippleCountBeforeSplash)

let t14_3Passed = beganCrouch && inAirborneLeap && reachedApex && submergedAway && splashRippleSpawned
recordSimTest(
    "T14.3 Frog Parabolic Leap Out & Water Splash Ripple",
    passed: t14_3Passed,
    details: "beganCrouch=\(beganCrouch), inLeap=\(inAirborneLeap), apexAltitude=\(String(format: "%.1f", maxAltitudeRecorded))pt, submergedAway=\(submergedAway), splashRipple=\(splashRippleSpawned)"
)

// T14.4 Submerged Away Timing, Return Leap & Pad Touchdown
var sawReturnLeap = false
var returnApex: CGFloat = 0.0

// Advance through away state until return leap triggers
for _ in 0..<700 {
    jumpSim.stepSimulation(dt: 1.0 / 60.0)
    if jumpSim.frog.state == .jumpingIn {
        sawReturnLeap = true
        returnApex = max(returnApex, jumpSim.frog.altitude)
    }
    if jumpSim.frog.state == .landing || jumpSim.frog.state == .perched {
        break
    }
}

// Complete landing cushion into perched
for _ in 0..<30 {
    jumpSim.stepSimulation(dt: 1.0 / 60.0)
}

let returnedToPerch = (jumpSim.frog.state == .perched && jumpSim.frog.isVisible)
let landedNearPerch = hypot(jumpSim.frog.position.x - jumpSim.frog.perchPosition.x, jumpSim.frog.position.y - jumpSim.frog.perchPosition.y) < 0.1

let t14_4Passed = sawReturnLeap && (returnApex >= 20.0) && returnedToPerch && landedNearPerch
recordSimTest(
    "T14.4 Frog Away Timing, Return Leap & Lily Pad Touchdown",
    passed: t14_4Passed,
    details: "sawReturnLeap=\(sawReturnLeap), returnApex=\(String(format: "%.1f", returnApex))pt, returnedToPerch=\(returnedToPerch), landedAtPerch=\(landedNearPerch)"
)

// T14.5 Interactive Water Click Startle
let frogClickSim = PondSimulation(bounds: PondBounds(width: 800.0, height: 600.0), theme: .day)
// Click far away -> frog remains perched
frogClickSim.handleWaterClick(at: PondVector(x: 700.0, y: 500.0))
let ignoredFarClick = (frogClickSim.frog.state == .perched)

// Click right near frog -> startles into crouch & jump!
let nearFrogPoint = PondVector(x: Double(frogClickSim.frog.position.x) + 15.0, y: Double(frogClickSim.frog.position.y) - 10.0)
frogClickSim.handleWaterClick(at: nearFrogPoint)
let startledByClick = (frogClickSim.frog.state == .crouching)

let t14_5Passed = ignoredFarClick && startledByClick
recordSimTest(
    "T14.5 Interactive Click Near Frog Startles Leap",
    passed: t14_5Passed,
    details: "ignoredFarClick=\(ignoredFarClick), startledByClick=\(startledByClick)"
)

// T14.6 Bounds Resize Proportionality & Simulation Pause Freeze
let resizeSim = PondSimulation(bounds: PondBounds(width: 800.0, height: 600.0), theme: .day)
let originalPerch = resizeSim.frog.perchPosition
resizeSim.resize(width: 1200.0, height: 900.0)
let resizedPerch = resizeSim.frog.perchPosition
let perchMovedProportionally = (resizedPerch.x > originalPerch.x && resizedPerch.y > originalPerch.y)

// Pause freeze test
resizeSim.isPaused = true
let frogPosFrozen = resizeSim.frog.position
let frogThroatFrozen = resizeSim.frog.throatPhase
for _ in 0..<60 {
    resizeSim.advance(deltaTime: 1.0 / 60.0)
}
let pauseMaintained = (resizeSim.frog.position == frogPosFrozen && resizeSim.frog.throatPhase == frogThroatFrozen)

let t14_6Passed = perchMovedProportionally && pauseMaintained
recordSimTest(
    "T14.6 Frog Bounds Resize Adaptability & Pause Freeze",
    passed: t14_6Passed,
    details: "proportionalResize=\(perchMovedProportionally), pauseMaintained=\(pauseMaintained)"
)

// -------------------------------------------------------------
// SUMMARY & RESULTS
// -------------------------------------------------------------
print("\n=======================================================")
let passCount = testResults.filter { $0.passed }.count
let failCount = testResults.filter { !$0.passed }.count
print("M1 Simulation Test Results: \(passCount) Passed, \(failCount) Failed")
print("=======================================================")

if failCount > 0 {
    print("FATAL: Simulation test suite failed with \(failCount) errors.")
    exit(1)
} else {
    print("SUCCESS: All \(passCount) simulation tests passed.")
    exit(0)
}
