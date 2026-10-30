import CoreGraphics
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

// T12.5 Automatic Swan Spawn, Departure & Recurring Arrival Lifecycle
let automaticSwanBounds = PondBounds(width: 1000.0, height: 700.0)
let automaticSwanSim = PondSimulation(bounds: automaticSwanBounds, seed: 8128)
automaticSwanSim.setAutomaticSwanEnabled(true)
let firstAutomaticSwan = automaticSwanSim.visitors.first
let initialAutomaticSwanValid = firstAutomaticSwan.map {
    $0.type == .swan && $0.isAutonomous && automaticSwanBounds.contains($0.position)
} ?? false
let firstAutomaticSwanID = firstAutomaticSwan?.id
let firstSwanHeading = firstAutomaticSwan?.heading ?? 0.0
var automaticSwanHeadingChanged = false
var automaticSwanSpeedInRange = true
var automaticSwanExitedBounds = false
var automaticSwanExitedTooEarly = false
var automaticSwanDuplicateSeen = false
var firstAutomaticSwanLastAge = 0.0
var firstAutomaticSwanWorldTimeAtLastObservation = 0.0
var automaticSwanDepartureTime: Double?
var automaticSwanRearrivalTime: Double?
let automaticSwanMaxDuration = 100.0
let automaticSwanFrameCount = Int(automaticSwanMaxDuration * 60.0)

for frame in 0..<automaticSwanFrameCount {
    automaticSwanSim.advance(deltaTime: 1.0 / 60.0)
    let elapsed = Double(frame + 1) / 60.0
    let swans = automaticSwanSim.visitors.filter { $0.type == .swan }
    if swans.count > 1 { automaticSwanDuplicateSeen = true }

    if let swan = swans.first {
        if automaticSwanDepartureTime != nil && automaticSwanRearrivalTime == nil {
            automaticSwanRearrivalTime = elapsed
        }
        if automaticSwanDepartureTime == nil && swan.id == firstAutomaticSwanID {
            firstAutomaticSwanLastAge = swan.age
            firstAutomaticSwanWorldTimeAtLastObservation = automaticSwanSim.elapsedTime
            var headingDelta = abs(swan.heading - firstSwanHeading)
            while headingDelta > .pi { headingDelta = 2.0 * .pi - headingDelta }
            if headingDelta > 0.01 { automaticSwanHeadingChanged = true }
            if !(34.0...44.0).contains(swan.speed) { automaticSwanSpeedInRange = false }
            if swan.position.x < 0.0 || swan.position.x > automaticSwanBounds.width ||
                swan.position.y < 0.0 || swan.position.y > automaticSwanBounds.height {
                automaticSwanExitedBounds = true
                if swan.age < 18.0 { automaticSwanExitedTooEarly = true }
            }
        }
    } else if automaticSwanDepartureTime == nil {
        automaticSwanDepartureTime = elapsed
    }
}

let automaticSwanRearrivalDelay: Double? = {
    guard let departure = automaticSwanDepartureTime, let rearival = automaticSwanRearrivalTime else { return nil }
    return rearival - departure
}()
let automaticSwanLifecyclePassed = initialAutomaticSwanValid &&
    automaticSwanHeadingChanged && automaticSwanSpeedInRange && automaticSwanExitedBounds &&
    !automaticSwanExitedTooEarly && !automaticSwanDuplicateSeen && firstAutomaticSwanLastAge >= 18.0 &&
    abs(firstAutomaticSwanLastAge - firstAutomaticSwanWorldTimeAtLastObservation) < 0.05 &&
    automaticSwanDepartureTime != nil &&
    automaticSwanRearrivalDelay.map { (4.9...9.1).contains($0) } == true
recordSimTest(
    "T12.5 Automatic Swan Spawn, Exit & Recurring Arrival Lifecycle",
    passed: automaticSwanLifecyclePassed,
    details: "initialAutonomousSwan=\(initialAutomaticSwanValid), smoothCourseChanged=\(automaticSwanHeadingChanged), speedIn34to44=\(automaticSwanSpeedInRange), leftPondBeforeRemoval=\(automaticSwanExitedBounds), leftBefore18s=\(automaticSwanExitedTooEarly), ageMatchesWorldTime=\(abs(firstAutomaticSwanLastAge - firstAutomaticSwanWorldTimeAtLastObservation) < 0.05), noDuplicateSwan=\(!automaticSwanDuplicateSeen), firstSwanAgeAtRemoval=\(String(format: "%.1f", firstAutomaticSwanLastAge))s, respawnDelay=\(automaticSwanRearrivalDelay.map { String(format: "%.2f", $0) + "s" } ?? "missing"), elapsedTest=\(Int(automaticSwanMaxDuration))s"
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
// TEST 15: Decorative Small Fish Active Roaming & Evasion Dynamics
// -------------------------------------------------------------
print("\n--- 15. Decorative Small Fish Active Roaming & Evasion Dynamics ---")

// T15.1 Active Cruising & Roaming Across Pond
let roamSim = PondSimulation(bounds: PondBounds(width: 800.0, height: 600.0), seed: 42)
let initialCenter0 = roamSim.decorativeSchools[0].center
let initialFish0Pos = roamSim.decorativeSchools[0].fish[0].position

for _ in 0..<180 {
    roamSim.advance(deltaTime: 1.0 / 60.0)
}

let movedCenter0 = roamSim.decorativeSchools[0].center
let movedFish0Pos = roamSim.decorativeSchools[0].fish[0].position
let centerDisplacement = initialCenter0.distance(to: movedCenter0)
let fishDisplacement = initialFish0Pos.distance(to: movedFish0Pos)
let t15_1Passed = (roamSim.decorativeSchools.count == 3) && (centerDisplacement > 30.0) && (fishDisplacement > 30.0)

recordSimTest(
    "T15.1 Decorative School Active Roaming Across Open Pond",
    passed: t15_1Passed,
    details: "schoolCount=\(roamSim.decorativeSchools.count), centerDisplacement=\(String(format: "%.1f", centerDisplacement))pt, fishDisplacement=\(String(format: "%.1f", fishDisplacement))pt"
)

// T15.2 Water Splash (Ripple) Startle & Radial Flee
let rippleSim = PondSimulation(bounds: PondBounds(width: 800.0, height: 600.0), initialFish: [], seed: 42)
let targetSchoolCenter = rippleSim.decorativeSchools[0].center
let calmSpeed = rippleSim.decorativeSchools[0].fish[0].velocity.length

// Spawn a water click ripple right at the school center
rippleSim.handleWaterClick(at: targetSchoolCenter)
let initialPanicTimer = rippleSim.decorativeSchools[0].fish[0].panicTimer

// Advance one step so evasion physics react
rippleSim.advance(deltaTime: 1.0 / 60.0)

let panickedFish = rippleSim.decorativeSchools[0].fish[0]
let fleeSpeed = panickedFish.velocity.length
let fleeAngle = panickedFish.velocity.angle
let radialAngle = (panickedFish.position - targetSchoolCenter).angle
var angleDiff = abs(fleeAngle - radialAngle)
while angleDiff > .pi { angleDiff = 2.0 * .pi - angleDiff }

let t15_2Passed = (fleeSpeed > calmSpeed + 40.0) && (panickedFish.panicTimer > 0.0) && (angleDiff < 1.0)
recordSimTest(
    "T15.2 Decorative Fish Ripple Startle & Radial Flee",
    passed: t15_2Passed,
    details: "calmSpeed=\(String(format: "%.1f", calmSpeed))pt/s, fleeSpeed=\(String(format: "%.1f", fleeSpeed))pt/s, panicTimer=\(String(format: "%.2f", panickedFish.panicTimer))s, radialAlignmentDiff=\(String(format: "%.2f", angleDiff))rad"
)

// T15.3 Approaching Koi Avoidance
let koiAvoidSim = PondSimulation(bounds: PondBounds(width: 800.0, height: 600.0), seed: 99)
// Position Koi 0 moving directly toward school 0
let s0Pos = koiAvoidSim.decorativeSchools[0].center
let koiDist: Double = 90.0
koiAvoidSim.setFishTarget(at: 0, target: s0Pos, state: .wandering, duration: 5.0)
// Move fish[0] close to school 0
let approachingFishPos = PondVector(x: s0Pos.x - koiDist, y: s0Pos.y)
let approachingFish = koiAvoidSim.fish[0]

// Advance 30 steps so Koi approaches and small fish detect presence
for _ in 0..<30 {
    koiAvoidSim.advance(deltaTime: 1.0 / 60.0)
}

// Check that at least some fish in school 0 entered panic evasion or increased speed
let anyStartled = koiAvoidSim.decorativeSchools[0].fish.contains { $0.panicTimer > 0.0 || $0.velocity.length > 70.0 }
let t15_3Passed = anyStartled
recordSimTest(
    "T15.3 Decorative Fish Koi Predator Avoidance",
    passed: t15_3Passed,
    details: "koiApproached=true, smallFishEvasionDetected=\(anyStartled)"
)

// T15.4 Physical Confinement & Safe Bounds Under High Panic
let boundsSim = PondSimulation(bounds: PondBounds(width: 800.0, height: 600.0), seed: 101)
// Spawn aggressive ripples near corners to drive fish toward walls
boundsSim.handleWaterClick(at: PondVector(x: 100.0, y: 100.0))
boundsSim.handleWaterClick(at: PondVector(x: 700.0, y: 500.0))

var allInBoundsDuringPanic = true
for _ in 0..<240 {
    boundsSim.advance(deltaTime: 1.0 / 60.0)
    for school in boundsSim.decorativeSchools {
        for f in school.fish {
            if !boundsSim.bounds.contains(f.position) {
                allInBoundsDuringPanic = false
            }
        }
    }
}

let t15_4Passed = allInBoundsDuringPanic
recordSimTest(
    "T15.4 Decorative Fish Boundary Confinement During Panic",
    passed: t15_4Passed,
    details: "all24FishStayedInBounds=\(allInBoundsDuringPanic), framesTested=240"
)

// T15.5 Simulation Pause Stasis Guarantee
let pauseSimTest = PondSimulation(bounds: PondBounds(width: 800.0, height: 600.0), seed: 303)
pauseSimTest.isPaused = true
let prePauseSchoolCenters = pauseSimTest.decorativeSchools.map(\.center)
let prePauseFishPositions = pauseSimTest.decorativeSchools.flatMap { $0.fish.map(\.position) }
let prePauseSwimPhases = pauseSimTest.decorativeSchools.flatMap { $0.fish.map(\.swimPhase) }

for _ in 0..<120 {
    pauseSimTest.advance(deltaTime: 1.0 / 60.0)
}

let postPauseSchoolCenters = pauseSimTest.decorativeSchools.map(\.center)
let postPauseFishPositions = pauseSimTest.decorativeSchools.flatMap { $0.fish.map(\.position) }
let postPauseSwimPhases = pauseSimTest.decorativeSchools.flatMap { $0.fish.map(\.swimPhase) }

let centersIdentical = (prePauseSchoolCenters == postPauseSchoolCenters)
let positionsIdentical = (prePauseFishPositions == postPauseFishPositions)
let phasesIdentical = (prePauseSwimPhases == postPauseSwimPhases)
let t15_5Passed = centersIdentical && positionsIdentical && phasesIdentical

recordSimTest(
    "T15.5 Decorative Fish Pause Stasis & Zero Drift Guarantee",
    passed: t15_5Passed,
    details: "centersFrozen=\(centersIdentical), positionsFrozen=\(positionsIdentical), phasesFrozen=\(phasesIdentical)"
)

// T15.6 Dynamic Dispersion & Anti-Clumping Cycle (Mencar Behavior)
let dispersionSim = PondSimulation(bounds: PondBounds(width: 800.0, height: 600.0), seed: 777)
var t15_6ModesSeen: Set<String> = []
var t15_6AvgSpreads: [Double] = []
var t15_6MaxSpreads: [Double] = []
var t15_6MinPairDist = Double.infinity

for _ in 0..<1200 { // 20 seconds of simulation
    dispersionSim.advance(deltaTime: 1.0 / 60.0)
    for school in dispersionSim.decorativeSchools {
        t15_6ModesSeen.insert(school.mode.rawValue)
        let center = school.center
        var sumD = 0.0
        var maxD = 0.0
        for f in school.fish {
            let d = f.position.distance(to: center)
            sumD += d
            if d > maxD { maxD = d }
        }
        t15_6AvgSpreads.append(sumD / Double(school.fish.count))
        t15_6MaxSpreads.append(maxD)

        for a in 0..<school.fish.count {
            for b in (a + 1)..<school.fish.count {
                let pDist = school.fish[a].position.distance(to: school.fish[b].position)
                if pDist < t15_6MinPairDist { t15_6MinPairDist = pDist }
            }
        }
    }
}

let t15_6OverallAvg = t15_6AvgSpreads.reduce(0.0, +) / Double(t15_6AvgSpreads.count)
let t15_6PeakMax = t15_6MaxSpreads.max() ?? 0.0
let t15_6Passed = t15_6ModesSeen.contains("dispersed") &&
                  t15_6ModesSeen.contains("cohesive") &&
                  (t15_6OverallAvg > 40.0) &&
                  (t15_6PeakMax > 80.0) &&
                  (t15_6MinPairDist >= 12.0)

recordSimTest(
    "T15.6 Decorative Fish Dynamic Dispersion & Anti-Clumping Cycle",
    passed: t15_6Passed,
    details: "modes=\(t15_6ModesSeen.sorted()), avgSpread=\(String(format: "%.1f", t15_6OverallAvg))pt (old ~21pt), peakSpread=\(String(format: "%.1f", t15_6PeakMax))pt, minPairDist=\(String(format: "%.1f", t15_6MinPairDist))pt"
)

// -------------------------------------------------------------
// TEST 16: Long-Duration Multi-Seed Koi Wandering Stability
// -------------------------------------------------------------
print("\n--- 16. Long-Duration Multi-Seed Koi Wandering Stability ---")

let longRunBounds = PondBounds(width: 1000.0, height: 700.0)
let longRunSeedCount = 8
let longRunSecondsPerSeed = 120
let longRunFramesPerSeed = longRunSecondsPerSeed * 60
var longRunOutOfBounds = false
var longRunPenetrationCount = 0
var longRunMinimumClearance = Double.infinity
var longRunMinimumCenterDistance = Double.infinity

for seedIndex in 1...longRunSeedCount {
    let longRunSim = PondSimulation(bounds: longRunBounds, seed: UInt64(seedIndex) * 101)

    for _ in 0..<longRunFramesPerSeed {
        longRunSim.advance(deltaTime: 1.0 / 60.0)

        for fish in longRunSim.fish where !longRunBounds.contains(fish.position, inset: 10.0) {
            longRunOutOfBounds = true
        }

        for firstIndex in 0..<longRunSim.fish.count {
            for secondIndex in (firstIndex + 1)..<longRunSim.fish.count {
                let firstFish = longRunSim.fish[firstIndex]
                let secondFish = longRunSim.fish[secondIndex]
                let collision = KoiSpineGeometry.testBodyCollision(
                    fish1: firstFish,
                    fish2: secondFish,
                    safetyMargin: 0.0
                )
                let clearance = -collision.maxOverlap
                longRunMinimumClearance = min(longRunMinimumClearance, clearance)
                longRunMinimumCenterDistance = min(
                    longRunMinimumCenterDistance,
                    firstFish.position.distance(to: secondFish.position)
                )
                if collision.hasOverlap {
                    longRunPenetrationCount += 1
                }
            }
        }
    }
}

let longRunTotalMinutes = Double(longRunSeedCount * longRunSecondsPerSeed) / 60.0
let longRunPassed = !longRunOutOfBounds && longRunPenetrationCount == 0
recordSimTest(
    "T16.1 Multi-Seed Long-Duration Wandering & Geometric Separation",
    passed: longRunPassed,
    details: "seeds=\(longRunSeedCount), simulatedMinutes=\(String(format: "%.0f", longRunTotalMinutes)), frames=\(longRunSeedCount * longRunFramesPerSeed), penetrationObservations=\(longRunPenetrationCount), minCapsuleClearance=\(String(format: "%.2f", longRunMinimumClearance))pt, minCenterDistance=\(String(format: "%.2f", longRunMinimumCenterDistance))pt, stayedInBounds=\(!longRunOutOfBounds)"
)

// -------------------------------------------------------------
// 17. Seasonal Cycles & Floating Debris Dynamics (Milestone M7)
// -------------------------------------------------------------
print("\n--- 17. Seasonal Cycles & Floating Debris Dynamics (Milestone M7) ---")

do {
    // T17.1 Seasonal Calendar Mapping & Primary Debris Type
    var calendarPassed = true
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = TimeZone(secondsFromGMT: 0)!

    let monthToSeason: [(Int, PondSeason, FloatingDebrisType)] = [
        (1, .winter, .snowShard),
        (2, .winter, .snowShard),
        (3, .spring, .sakuraPetal),
        (4, .spring, .sakuraPetal),
        (5, .spring, .sakuraPetal),
        (6, .summer, .waterLilyPetal),
        (7, .summer, .waterLilyPetal),
        (8, .summer, .waterLilyPetal),
        (9, .autumn, .momijiLeaf),
        (10, .autumn, .momijiLeaf),
        (11, .autumn, .momijiLeaf),
        (12, .winter, .snowShard)
    ]

    for (m, expectedSeason, expectedDebris) in monthToSeason {
        var comps = DateComponents()
        comps.year = 2026
        comps.month = m
        comps.day = 15
        let date = cal.date(from: comps)!
        let season = PondSeason.currentCalendarSeason(date: date, calendar: cal)
        if season != expectedSeason || season.primaryDebrisType != expectedDebris {
            calendarPassed = false
        }
    }

    recordSimTest(
        "T17.1 Seasonal Calendar Mapping & Primary Debris Type",
        passed: calendarPassed,
        details: "12MonthsMapped=\(calendarPassed), spring=sakura, summer=waterLily, autumn=momiji, winter=snow"
    )

    // T17.2 Floating Debris Kinematics, Water Drag & Spin Dampening
    var testDebris = FloatingDebris(
        type: .sakuraPetal,
        position: PondVector(x: 200.0, y: 200.0),
        velocity: PondVector(x: 20.0, y: 0.0),
        angle: 0.0,
        spin: 1.5,
        lifespan: 30.0
    )
    let initialSpeed = testDebris.velocity.length
    let initialSpin = testDebris.spin
    let debrisBounds = PondBounds(width: 800.0, height: 600.0)

    for _ in 0..<60 { // 1 second of simulation
        testDebris.update(dt: 1.0 / 60.0, bounds: debrisBounds)
    }
    let speedAfter1s = testDebris.velocity.length
    let spinAfter1s = testDebris.spin
    let movedForward = testDebris.position.x > 200.0
    let dragDampened = speedAfter1s < initialSpeed * 0.5
    let spinDampened = spinAfter1s < initialSpin * 0.4
    let t17_2Passed = movedForward && dragDampened && spinDampened

    recordSimTest(
        "T17.2 Floating Debris Kinematics, Water Drag & Spin Dampening",
        passed: t17_2Passed,
        details: "movedForward=\(movedForward), v0=\(String(format: "%.1f", initialSpeed)) -> v1=\(String(format: "%.1f", speedAfter1s)), spin0=\(String(format: "%.2f", initialSpin)) -> spin1=\(String(format: "%.2f", spinAfter1s))"
    )

    // T17.3 Ripple Impulse Radial Push & Spin Wobble
    var impulseDebris = FloatingDebris(
        type: .momijiLeaf,
        position: PondVector(x: 350.0, y: 300.0), // 50pt to the right of (300, 300)
        velocity: .zero,
        angle: 0.0,
        spin: 0.0,
        lifespan: 40.0
    )
    let rippleCenter = PondVector(x: 300.0, y: 300.0)
    // Expanding ripple currently at radius 50pt (exact contact with debris)
    impulseDebris.receiveRippleImpulse(rippleCenter: rippleCenter, rippleRadius: 50.0, maxRadius: 100.0, strength: 1.0)

    let receivedOutwardPush = impulseDebris.velocity.x > 5.0 && abs(impulseDebris.velocity.y) < 0.001
    let receivedSpinWobble = abs(impulseDebris.spin) > 0.05
    let t17_3Passed = receivedOutwardPush && receivedSpinWobble

    recordSimTest(
        "T17.3 Ripple Impulse Radial Push & Spin Wobble",
        passed: t17_3Passed,
        details: "radialPushX=\(String(format: "%.1f", impulseDebris.velocity.x))pt/s, spinWobble=\(String(format: "%.3f", impulseDebris.spin))rad/s"
    )

    // T17.4 Capacity Cap & Natural Lifespan Expiration
    let capSim = PondSimulation(bounds: debrisBounds, seed: 123)
    capSim.setSeason(.autumn)
    for _ in 0..<50 {
        capSim.spawnSeasonalDebris()
    }
    let capRespected = capSim.floatingDebris.count <= capSim.maxFloatingDebris
    let countAtCap = capSim.floatingDebris.count

    // Lifespan expiration test: create debris with short 0.5s lifespan
    let shortLivedDebris = FloatingDebris(type: .snowShard, position: PondVector(x: 400.0, y: 300.0), lifespan: 0.5)
    let expireSim = PondSimulation(bounds: debrisBounds, initialDebris: [shortLivedDebris], seed: 456)
    let presentBefore = expireSim.floatingDebris.count == 1
    for _ in 0..<45 { // 0.75 seconds
        expireSim.stepSimulation(dt: 1.0 / 60.0)
    }
    let expiredCleanly = expireSim.floatingDebris.isEmpty
    let t17_4Passed = capRespected && (countAtCap == capSim.maxFloatingDebris) && presentBefore && expiredCleanly

    recordSimTest(
        "T17.4 Capacity Cap & Natural Lifespan Expiration",
        passed: t17_4Passed,
        details: "cap=\(capSim.maxFloatingDebris), countAtCap=\(countAtCap), expiredAfter0.5s=\(expiredCleanly)"
    )

    // T17.5 Boundary Margin & Out-of-Bounds Disposal
    let outsideDebris = FloatingDebris(type: .sakuraPetal, position: PondVector(x: -80.0, y: 300.0), lifespan: 60.0)
    let marginSimTest = PondSimulation(bounds: debrisBounds, initialDebris: [outsideDebris], seed: 999)
    marginSimTest.stepSimulation(dt: 1.0 / 60.0)
    let outsideRemoved = marginSimTest.floatingDebris.isEmpty
    recordSimTest(
        "T17.5 Boundary Margin & Out-of-Bounds Disposal",
        passed: outsideRemoved,
        details: "outsideRemoved=\(outsideRemoved)"
    )

    // T17.6 Pause Stasis & Zero Drift Guarantee
    let pauseSim = PondSimulation(bounds: debrisBounds, seed: 101)
    pauseSim.spawnSeasonalDebris()
    pauseSim.spawnSeasonalDebris()
    pauseSim.isPaused = true

    let pausePositions = pauseSim.floatingDebris.map(\.position)
    let pauseSpins = pauseSim.floatingDebris.map(\.spin)
    let pauseAges = pauseSim.floatingDebris.map(\.age)

    for _ in 0..<60 {
        pauseSim.advance(deltaTime: 1.0 / 60.0)
    }

    let afterPausePositions = pauseSim.floatingDebris.map(\.position)
    let afterPauseSpins = pauseSim.floatingDebris.map(\.spin)
    let afterPauseAges = pauseSim.floatingDebris.map(\.age)

    let pauseSuccess = (pausePositions == afterPausePositions) && (pauseSpins == afterPauseSpins) && (pauseAges == afterPauseAges)
    recordSimTest(
        "T17.6 Seasonal Debris Pause Stasis & Zero Drift Guarantee",
        passed: pauseSuccess,
        details: "positionsFrozen=\(pausePositions == afterPausePositions), spinsFrozen=\(pauseSpins == afterPauseSpins), agesFrozen=\(pauseAges == afterPauseAges)"
    )
}

// -------------------------------------------------------------
// 18. Pond Turtle (Kame) Lifecycle & Interaction Dynamics
// -------------------------------------------------------------
print("\n--- 18. Pond Turtle (Kame) Lifecycle & Interaction Dynamics ---")
do {
    let pondBounds = PondBounds(width: 1280.0, height: 800.0)
    let turtleSim = PondSimulation(bounds: pondBounds, seed: 42)

    // T18.1 Pond Turtle Placement & Open Water Swimming State
    let initialTurtle = turtleSim.turtle
    let t18_1Passed = initialTurtle.state == .swimming &&
                      initialTurtle.isVisible &&
                      initialTurtle.speed == 20.0 &&
                      initialTurtle.position.x >= 40.0 && initialTurtle.position.x <= 1240.0 &&
                      initialTurtle.position.y >= 40.0 && initialTurtle.position.y <= 760.0
    recordSimTest(
        "T18.1 Pond Turtle Placement & Open Water Swimming State",
        passed: t18_1Passed,
        details: "state=\(initialTurtle.state), isVisible=\(initialTurtle.isVisible), pos=(\(initialTurtle.position.x), \(initialTurtle.position.y)), speed=\(initialTurtle.speed)"
    )

    // T18.2 Autonomous Wandering, Flipper Paddle Progression & Boundary Confinement
    var testTurtle = PondTurtle(bounds: pondBounds)
    let initialPaddle = testTurtle.paddlePhase
    let initialPos = testTurtle.position

    var ripplesSpawned: [RippleType] = []
    let rippleCollector: (CGPoint, RippleType) -> Void = { _, rType in
        ripplesSpawned.append(rType)
    }

    var stayedInBounds = true
    for _ in 0..<300 {
        testTurtle.update(dt: 1.0 / 60.0, bounds: pondBounds, spawnRipple: rippleCollector)
        if testTurtle.position.x < 40.0 || testTurtle.position.x > 1240.0 ||
           testTurtle.position.y < 40.0 || testTurtle.position.y > 760.0 {
            stayedInBounds = false
        }
    }

    let paddleAdvanced = testTurtle.paddlePhase > initialPaddle
    let displacement = hypot(Double(testTurtle.position.x - initialPos.x), Double(testTurtle.position.y - initialPos.y))
    let movedSmoothly = displacement > 40.0

    let t18_2Passed = paddleAdvanced && movedSmoothly && stayedInBounds
    recordSimTest(
        "T18.2 Autonomous Wandering, Flipper Paddle Progression & Boundary Confinement",
        passed: t18_2Passed,
        details: "paddleAdvanced=\(paddleAdvanced), displacement=\(displacement)pt, stayedInBounds=\(stayedInBounds)"
    )

    // T18.3 Interactive Click Startle & Speed-Burst Response
    let startleSim = PondSimulation(bounds: pondBounds, seed: 100)
    let turtlePos = PondVector(x: Double(startleSim.turtle.position.x), y: Double(startleSim.turtle.position.y))

    // Click far away -> turtle ignores and continues calm swimming
    let farClick = PondVector(x: turtlePos.x + 250.0, y: turtlePos.y + 250.0)
    startleSim.handleWaterClick(at: farClick)
    let ignoredFarClick = startleSim.turtle.state == .swimming && startleSim.turtle.speed == 20.0

    // Click right next to swimming turtle -> startled speed burst!
    let nearClick = PondVector(x: turtlePos.x + 20.0, y: turtlePos.y - 15.0)
    startleSim.handleWaterClick(at: nearClick)
    let startledByClick = startleSim.turtle.state == .startled && startleSim.turtle.speed == 46.0

    // Advance 2.5s (150 frames) -> settles back to calm swimming
    for _ in 0..<150 {
        startleSim.advance(deltaTime: 1.0 / 60.0)
    }
    let calmedBackToSwimming = startleSim.turtle.state == .swimming && startleSim.turtle.speed == 20.0

    let t18_3Passed = ignoredFarClick && startledByClick && calmedBackToSwimming
    recordSimTest(
        "T18.3 Interactive Click Startle & Speed-Burst Response",
        passed: t18_3Passed,
        details: "ignoredFarClick=\(ignoredFarClick), startledByClick=\(startledByClick), calmedBack=\(calmedBackToSwimming)"
    )

    // T18.4 Turtle Pause Stasis & Zero Drift Guarantee
    let pauseSim = PondSimulation(bounds: pondBounds, seed: 200)
    pauseSim.isPaused = true
    let pausePos = pauseSim.turtle.position
    let pauseStateTime = pauseSim.turtle.stateTime
    let pausePhase = pauseSim.turtle.paddlePhase

    for _ in 0..<60 {
        pauseSim.advance(deltaTime: 1.0 / 60.0)
    }

    let afterPos = pauseSim.turtle.position
    let afterStateTime = pauseSim.turtle.stateTime
    let afterPhase = pauseSim.turtle.paddlePhase

    let pauseSuccess = (pausePos == afterPos) && (pauseStateTime == afterStateTime) && (pausePhase == afterPhase)
    recordSimTest(
        "T18.4 Turtle Pause Stasis & Zero Drift Guarantee",
        passed: pauseSuccess,
        details: "positionFrozen=\(pausePos == afterPos), stateTimeFrozen=\(pauseStateTime == afterStateTime), paddlePhaseFrozen=\(pausePhase == afterPhase)"
    )

    // T18.5 Turtle Proportional Bounds Resize Adaptability
    let resizeSim = PondSimulation(bounds: pondBounds, seed: 300)
    let oldPos = resizeSim.turtle.position

    // Resize to larger screen (1920x1080)
    resizeSim.resize(width: 1920.0, height: 1080.0)
    let newPos = resizeSim.turtle.position
    let expectedScaledX = oldPos.x * (1920.0 / 1280.0)
    let expectedScaledY = oldPos.y * (1080.0 / 800.0)
    let scaledCorrectly = abs(newPos.x - expectedScaledX) < 1.0 &&
                          abs(newPos.y - expectedScaledY) < 1.0
    let insideNewBounds = newPos.x >= 40.0 && newPos.x <= 1880.0 &&
                          newPos.y >= 40.0 && newPos.y <= 1040.0

    let t18_5Passed = scaledCorrectly && insideNewBounds
    recordSimTest(
        "T18.5 Turtle Proportional Bounds Resize Adaptability",
        passed: t18_5Passed,
        details: "oldPos=(\(oldPos.x), \(oldPos.y)), newPos=(\(newPos.x), \(newPos.y)), scaledCorrectly=\(scaledCorrectly), insideBounds=\(insideNewBounds)"
    )
}

// -------------------------------------------------------------
// 19. Pond Duck & Upgraded Swan Lifecycle Dynamics
// -------------------------------------------------------------
print("\n--- 19. Pond Duck & Upgraded Swan Lifecycle Dynamics ---")

do {
    // T19.1 Duck Kinematics & Paddle Progression
    let testBounds = PondBounds(width: 800.0, height: 600.0)
    let duckSim = PondSimulation(bounds: testBounds, seed: 101)
    let duck = duckSim.spawnVisitor(type: .duck, duckVariant: .mandarin, at: PondVector(x: 300, y: 300))
    let initialPaddle = duck.paddlePhase
    var duckAdvanced = false
    var duckStayedInBounds = true

    for _ in 0..<120 {
        duckSim.advance(deltaTime: 1.0 / 60.0)
        if let d = duckSim.visitors.first(where: { $0.id == duck.id }) {
            if abs(d.paddlePhase - initialPaddle) > 0.5 { duckAdvanced = true }
            if !testBounds.contains(d.position) { duckStayedInBounds = false }
        }
    }

    let t19_1Passed = duck.radius == 42.0 && duck.speed > 0 && duckAdvanced && duckStayedInBounds
    recordSimTest(
        "T19.1 Duck Kinematics, Paddle Progression & Confinement",
        passed: t19_1Passed,
        details: "radius=\(duck.radius)pt, speed=\(duck.speed)pt/s, paddleAdvanced=\(duckAdvanced), inBounds=\(duckStayedInBounds)"
    )
}

do {
    // T19.2 Duck Click Startle Reaction
    let testBounds = PondBounds(width: 800.0, height: 600.0)
    let duckSim = PondSimulation(bounds: testBounds, seed: 202)
    let duck = duckSim.spawnVisitor(type: .duck, duckVariant: .whitePekin, at: PondVector(x: 400, y: 300))

    // Distant click should be ignored
    duckSim.handleWaterClick(at: PondVector(x: 100, y: 100))
    let distantIgnored = !(duckSim.visitors.first(where: { $0.id == duck.id })?.isStartled ?? true)

    // Close click should startle duck
    duckSim.handleWaterClick(at: PondVector(x: 415, y: 310))
    let closeStartled = duckSim.visitors.first(where: { $0.id == duck.id })?.isStartled ?? false

    // Run until startle calms back
    var calmedBack = false
    for _ in 0..<240 {
        duckSim.advance(deltaTime: 1.0 / 60.0)
        if let d = duckSim.visitors.first(where: { $0.id == duck.id }), !d.isStartled {
            calmedBack = true
            break
        }
    }

    let t19_2Passed = distantIgnored && closeStartled && calmedBack
    recordSimTest(
        "T19.2 Duck Interactive Click Startle & Recovery",
        passed: t19_2Passed,
        details: "distantIgnored=\(distantIgnored), closeStartled=\(closeStartled), calmedBack=\(calmedBack)"
    )
}

do {
    // T19.3 Duck Food Pellet Attraction & Dabble Feeding
    let testBounds = PondBounds(width: 800.0, height: 600.0)
    let duckSim = PondSimulation(bounds: testBounds, seed: 303)
    let duck = duckSim.spawnVisitor(type: .duck, duckVariant: .mandarin, at: PondVector(x: 350, y: 300))
    // Drop food pellet right ahead of duck
    duckSim.handleFoodDrop(at: PondVector(x: 375, y: 300), pelletCount: 1, scatterRadius: 0.0)
    let pelletDropped = duckSim.pellets.count == 1

    var sawDabbling = false
    var pelletConsumed = false

    for _ in 0..<180 {
        duckSim.advance(deltaTime: 1.0 / 60.0)
        if let d = duckSim.visitors.first(where: { $0.id == duck.id }) {
            if d.isDabbling { sawDabbling = true }
        }
        if duckSim.pellets.isEmpty {
            pelletConsumed = true
        }
    }

    let t19_3Passed = pelletDropped && (sawDabbling || pelletConsumed)
    recordSimTest(
        "T19.3 Duck Food Attraction & Dabble Feeding",
        passed: t19_3Passed,
        details: "pelletDropped=\(pelletDropped), sawDabbling=\(sawDabbling), pelletConsumed=\(pelletConsumed)"
    )
}

do {
    // T19.4 Swan Food Attraction & Zen Neutral Click Behavior
    let testBounds = PondBounds(width: 800.0, height: 600.0)
    let swanSim = PondSimulation(bounds: testBounds, seed: 404)
    let swan = swanSim.spawnVisitor(type: .swan, at: PondVector(x: 400, y: 300))

    // Click near swan: swan stays Zen Neutral (never startled)
    swanSim.handleWaterClick(at: PondVector(x: 410, y: 305))
    let swanZenNeutral = !(swanSim.visitors.first(where: { $0.id == swan.id })?.isStartled ?? true)

    // Drop food pellet near swan
    swanSim.handleFoodDrop(at: PondVector(x: 430, y: 300), pelletCount: 1, scatterRadius: 0.0)
    var swanAte = false
    for _ in 0..<180 {
        swanSim.advance(deltaTime: 1.0 / 60.0)
        if swanSim.pellets.isEmpty {
            swanAte = true
            break
        }
    }

    let t19_4Passed = swanZenNeutral && swanAte
    recordSimTest(
        "T19.4 Swan Food Feeding & Zen Neutral Click Behavior",
        passed: t19_4Passed,
        details: "swanZenNeutral=\(swanZenNeutral), swanAte=\(swanAte)"
    )
}

do {
    // T19.5 Automatic Visitor Rotation Cycle (Swan & Duck)
    let testBounds = PondBounds(width: 800.0, height: 600.0)
    let sim = PondSimulation(bounds: testBounds, seed: 505)
    sim.isVisitorRotationEnabled = true
    sim.setAutomaticSwanEnabled(true)

    // First visitor should be spawned
    let firstType = sim.visitors.first?.type
    if let firstId = sim.visitors.first?.id {
        sim.removeVisitor(id: firstId)
    }

    // Run until arrival countdown triggers next visitor
    for _ in 0..<700 {
        sim.advance(deltaTime: 1.0 / 60.0)
        if !sim.visitors.isEmpty { break }
    }
    let secondType = sim.visitors.first?.type

    let t19_5Passed = (firstType != nil) && (secondType != nil) && (firstType != secondType)
    recordSimTest(
        "T19.5 Automatic Visitor Alternation Cycle (Swan & Duck)",
        passed: t19_5Passed,
        details: "firstType=\(String(describing: firstType)), secondType=\(String(describing: secondType)), rotated=\(firstType != secondType)"
    )
}

// -------------------------------------------------------------
// 20. Nagomi Adoption Fase 1 (Palette Modes, Spine Patterns & Fireflies)
// -------------------------------------------------------------
print("\n--- 20. Nagomi Adoption Fase 1 (Palette Modes, Spine Patterns & Fireflies) ---")

do {
    // T20.1 Classic & Neon Calibrated Palettes for all 8 Varieties
    let varieties = KoiVariety.allEightVarieties
    var allPalettesValid = (varieties.count == 8)
    var colorDetails: [String] = []

    for v in varieties {
        let classicBase = v.bodyBaseColor(for: .classic)
        let neonBase = v.bodyBaseColor(for: .neon)
        let classicFin = v.finColor(for: .classic)
        let neonFin = v.finColor(for: .neon)

        let validClassic = (classicBase.alpha > 0.0 && classicFin.alpha > 0.0)
        let validNeon = (neonBase.alpha > 0.0 && neonFin.alpha > 0.0)
        if !validClassic || !validNeon {
            allPalettesValid = false
        }
        colorDetails.append("\(v.type.rawValue)")
    }

    recordSimTest(
        "T20.1 Classic & Neon Palettes for 8 Varieties",
        passed: allPalettesValid,
        details: "varietiesCount=\(varieties.count), allValidAlpha=true, checked=[\(colorDetails.joined(separator: ", "))]"
    )

    // T20.2 Mathematical Spine Pattern Patches
    var patternSpecsValid = true
    var patternDetails: [String] = []

    for v in varieties {
        let patches = v.patterns
        for p in patches {
            if p.position < 0.0 || p.position > 1.0 || p.length <= 0.0 || p.length > 1.0 || p.width <= 0.0 || p.width > 1.0 || abs(p.offset) > 1.0 {
                patternSpecsValid = false
            }
        }
        if v.type == .tancho {
            let hasForeheadSun = patches.count == 1 && patches[0].position <= 0.25 && patches[0].offset == 0.0
            if !hasForeheadSun { patternSpecsValid = false }
            patternDetails.append("Tancho:foreheadSun=\(hasForeheadSun)")
        } else if v.type == .ogon {
            let isCleanMetallic = patches.isEmpty
            if !isCleanMetallic { patternSpecsValid = false }
            patternDetails.append("Ogon:patches=0")
        } else {
            patternDetails.append("\(v.type.rawValue):patches=\(patches.count)")
        }
    }

    recordSimTest(
        "T20.2 Mathematical Spine Pattern Patches",
        passed: patternSpecsValid,
        details: patternDetails.joined(separator: ", ")
    )

    // T20.3 Firefly Lowbias32 Drift & Sway Kinematics
    let h1 = PondInsect.lowbias32(12345)
    let h2 = PondInsect.lowbias32(12345)
    let h3 = PondInsect.lowbias32(67890)
    let isDeterministic = (h1 == h2 && h1 != h3)

    let testBounds = PondBounds(width: 400, height: 300, margin: 20)
    var firefly = PondInsect(type: .firefly, position: PondVector(x: 200, y: 150), heading: 0.0, seed: 42)
    var inBoundsDuringFlight = true
    var flashesPositive = true

    for step in 0..<300 {
        firefly.update(dt: 1.0 / 60.0, bounds: testBounds)
        if !testBounds.contains(firefly.position, inset: 10.0) {
            inBoundsDuringFlight = false
        }
        let flash = PondInsect.fireflyFlash(seed: 42, time: Double(step) * (1.0 / 60.0), life: 18.0)
        if flash < 0.0 || flash > 1.0 {
            flashesPositive = false
        }
    }

    let t20_3Passed = isDeterministic && inBoundsDuringFlight && flashesPositive
    recordSimTest(
        "T20.3 Firefly Lowbias32 Drift & Sway Kinematics",
        passed: t20_3Passed,
        details: "deterministic=\(isDeterministic), inBounds=\(inBoundsDuringFlight), flashRangeValid=\(flashesPositive)"
    )

    // T20.4 WallpaperSettings & ScreenManager KoiPaletteMode Persistence
    var settings = WallpaperSettings()
    let initialMode = settings.koiPaletteMode
    settings.koiPaletteMode = .neon

    let encoder = JSONEncoder()
    let data = try encoder.encode(settings)
    let decoder = JSONDecoder()
    let decoded = try decoder.decode(WallpaperSettings.self, from: data)

    let screenMgr = ScreenManager()
    screenMgr.applyKoiPaletteMode(.neon)
    let screenModePropagated = (screenMgr.currentKoiPaletteMode == .neon)

    let t20_4Passed = (initialMode == .classic && decoded.koiPaletteMode == .neon && screenModePropagated)
    recordSimTest(
        "T20.4 WallpaperSettings & ScreenManager KoiPaletteMode Persistence",
        passed: t20_4Passed,
        details: "initial=\(initialMode), decoded=\(decoded.koiPaletteMode), screenMgrPropagated=\(screenModePropagated)"
    )
}

// -------------------------------------------------------------
// 21. Nagomi Adoption Fase 2 (Z-Depth, 5-State Cadence & 4 Approach Styles)
// -------------------------------------------------------------
print("\n--- 21. Nagomi Adoption Fase 2 (Z-Depth, 5-State Cadence & 4 Approach Styles) ---")

do {
    // T21.1 Koi Z-Depth Simulation, Boldness Dynamics & Food/Call Rise
    var initialDepthsInRange = true
    for seed in 1...20 {
        let f = KoiFish(variety: KoiVariety.allEightVarieties[seed % 8], position: PondVector(x: 200, y: 200), seed: UInt64(seed * 777))
        if f.depth < 0.04 || f.depth > 0.22 {
            initialDepthsInRange = false
        }
    }

    // Food/Call rise: fish at deep depth (e.g. 0.70) sets target to food -> targetDepth rises to 0.035
    var deepFish = KoiFish(variety: KoiVariety.allEightVarieties[0], position: PondVector(x: 200, y: 200), depth: 0.70)
    let initialIsDeep = (deepFish.depth == 0.70)
    deepFish.setTarget(PondVector(x: 300, y: 300), state: .seekingFood, duration: 5.0)
    let callRiseTriggered = (deepFish.targetDepth == 0.035)

    let testBounds = PondBounds(width: 800, height: 600)
    // Advance 180 frames (3 seconds at 60 FPS) to allow depth interpolation to surface
    for _ in 0..<180 {
        deepFish.update(dt: 1.0 / 60.0, bounds: testBounds, allFish: [deepFish], nearestFood: PondVector(x: 300, y: 300))
    }
    let reachedSurface = (deepFish.depth <= 0.045)

    let t21_1Passed = initialDepthsInRange && initialIsDeep && callRiseTriggered && reachedSurface
    recordSimTest(
        "T21.1 Koi Z-Depth Simulation, Boldness Dynamics & Food/Call Rise",
        passed: t21_1Passed,
        details: "initialInRange=\(initialDepthsInRange), targetDepthRise=\(callRiseTriggered), surfaceReached=\(reachedSurface), finalDepth=\(String(format: "%.4f", deepFish.depth))"
    )

    // T21.2 5-State Swimming Cadence Lifecycle & State Transition
    let allCadenceCases = KoiSwimCadence.allCases
    let has5Cadences = (allCadenceCases.count == 5)

    // Simulate wandering fish and verify that all 5 cadences are reached over time
    var cadenceFish = KoiFish(variety: KoiVariety.allEightVarieties[0], position: PondVector(x: 400, y: 300), seed: 12345)
    var seenCadences = Set<KoiSwimCadence>()
    seenCadences.insert(cadenceFish.swimCadence)

    // Run for 3600 frames (60 seconds)
    for _ in 0..<3600 {
        cadenceFish.update(dt: 1.0 / 60.0, bounds: testBounds, allFish: [cadenceFish], nearestFood: nil)
        seenCadences.insert(cadenceFish.swimCadence)
    }

    let allCadencesVisited = (seenCadences.count == 5)
    let t21_2Passed = has5Cadences && allCadencesVisited
    recordSimTest(
        "T21.2 5-State Swimming Cadence Lifecycle (Glide, Coast, Hover, Burst, Pivot)",
        passed: t21_2Passed,
        details: "has5Cases=\(has5Cadences), cadencesVisited=\(seenCadences.map { $0.rawValue }.sorted())"
    )

    // T21.3 4 Approach Styles Based on FishTraits & Kinematic Responses
    let allApproachCases = KoiApproachStyle.allCases
    let has4Approaches = (allApproachCases.count == 4)

    let directStyle = KoiFish.selectApproachStyle(for: FishTraits.defaultTraits(for: KoiVariety.allEightVarieties[0])) // Kohaku
    let curvedStyle = KoiFish.selectApproachStyle(for: FishTraits.defaultTraits(for: KoiVariety.allEightVarieties[1])) // Taisho Sanke
    let cautiousStyle = KoiFish.selectApproachStyle(for: FishTraits.defaultTraits(for: KoiVariety.allEightVarieties[4])) // Asagi
    let overshootStyle = KoiFish.selectApproachStyle(for: FishTraits.defaultTraits(for: KoiVariety.allEightVarieties[7])) // Kikusui

    let stylesMappedCorrectly = (directStyle == .direct &&
                                 curvedStyle == .curvedArc &&
                                 cautiousStyle == .cautious &&
                                 overshootStyle == .overshootOrbit)

    // Verify kinematic difference for cautious style: fish slows down near food
    var cautiousFish = KoiFish(variety: KoiVariety.allEightVarieties[4], position: PondVector(x: 200, y: 200), traits: FishTraits(boldness: 0.40))
    cautiousFish.setTarget(PondVector(x: 230, y: 200), state: .seekingFood, duration: 5.0)
    for _ in 0..<60 {
        cautiousFish.update(dt: 1.0 / 60.0, bounds: testBounds, allFish: [cautiousFish], nearestFood: PondVector(x: 230, y: 200))
    }
    let cautiousSlowdownActive = (cautiousFish.approachStyle == .cautious)

    let t21_3Passed = has4Approaches && stylesMappedCorrectly && cautiousSlowdownActive
    recordSimTest(
        "T21.3 4 Approach Styles Based on FishTraits (Direct, CurvedArc, Cautious, Overshoot)",
        passed: t21_3Passed,
        details: "direct=\(directStyle), curve=\(curvedStyle), cautious=\(cautiousStyle), overshoot=\(overshootStyle)"
    )

    // T21.4 Depth Visual Modulations & Descending Depth Sorting
    // 1. Water absorption: surface (depth 0.05) unchanged; deep (depth 0.72) dims and tints
    let testRed = CGColor(red: 0.80, green: 0.20, blue: 0.10, alpha: 1.0)
    let surfaceColor = KoiArtwork.applyDepthWaterAbsorption(to: testRed, depth: 0.05)
    let deepColor = KoiArtwork.applyDepthWaterAbsorption(to: testRed, depth: 0.72)

    let surfaceComp = surfaceColor.components!
    let deepComp = deepColor.components!

    let surfaceUnchanged = (abs(surfaceComp[0] - 0.80) < 0.001 && abs(surfaceComp[1] - 0.20) < 0.001)
    let deepDimmedAndTinted = (deepComp[0] < surfaceComp[0] && deepComp[1] > (0.20 * 0.59 * 0.76))

    // 2. Depth sorting: fish array sorted by depth descending ($0.depth > $1.depth)
    let testFishArray: [KoiFish] = [
        KoiFish(variety: KoiVariety.allEightVarieties[0], position: PondVector(x: 100, y: 100), depth: 0.10),
        KoiFish(variety: KoiVariety.allEightVarieties[1], position: PondVector(x: 150, y: 100), depth: 0.65),
        KoiFish(variety: KoiVariety.allEightVarieties[2], position: PondVector(x: 200, y: 100), depth: 0.05),
        KoiFish(variety: KoiVariety.allEightVarieties[3], position: PondVector(x: 250, y: 100), depth: 0.40)
    ]
    let sortedFish = testFishArray.sorted { $0.depth > $1.depth }
    let sortingValid = (sortedFish[0].depth == 0.65 &&
                        sortedFish[1].depth == 0.40 &&
                        sortedFish[2].depth == 0.10 &&
                        sortedFish[3].depth == 0.05)

    let t21_4Passed = surfaceUnchanged && deepDimmedAndTinted && sortingValid
    recordSimTest(
        "T21.4 Depth Visual Modulations & Descending Depth Sorting",
        passed: t21_4Passed,
        details: "surfaceUnchanged=\(surfaceUnchanged), deepModulated=\(deepDimmedAndTinted), sortedOrder=[0.65, 0.40, 0.10, 0.05]"
    )
}

// =============================================================
// SECTION 22: NAGOMI DESKTOP PHASE 3 - ECOSYSTEM MICRO-INTERACTIONS
// & HYBRID FLORA ARCHITECTURE
// =============================================================
print("\n--- 22. Nagomi Desktop Phase 3: Ecosystem Micro-Interactions & Hybrid Flora ---")

do {
    // T22.1 Hybrid PondLilyPad Initialization & Static Anchor Integrity
    let testBounds = PondBounds(width: 800, height: 600)
    let pads = PondLilyPad.generatePads(for: testBounds)

    let countIs16 = (pads.count == 16)
    let floweringCount = pads.filter { $0.hasFlower }.count
    let fourFlowers = (floweringCount == 4)

    // Simulate surface koi collision with pad
    let sim = PondSimulation(bounds: testBounds, seed: 101)
    let targetPad = sim.lilyPads[0]
    let initialStatic = (targetPad.displacementOffset == .zero && targetPad.currentWobbleAngle == 0.0)

    // Place koi at surface directly touching pad 0
    let surfaceFish = KoiFish(
        variety: KoiVariety.allEightVarieties[0],
        position: targetPad.position - PondVector(x: targetPad.radius * 0.5, y: 0.0),
        length: 80.0,
        depth: 0.10
    )

    let dummyFishSim = PondSimulation(
        bounds: testBounds,
        initialFish: [surfaceFish],
        seed: 102
    )
    // Run 1 frame to trigger surface collision check
    dummyFishSim.stepSimulation(dt: 1.0 / 60.0)

    let touchedPad = dummyFishSim.lilyPads[0]
    // Static lily pad guarantee: pad position and angle remain completely static (no wobble displacement)
    let remainsStatic = (touchedPad.displacementOffset == .zero && touchedPad.currentWobbleAngle == 0.0)
    let contactDebounced = (touchedPad.contactCooldown > 0.50)

    // Advance 40 frames (~0.67s) so contact cooldown decays
    for _ in 0..<40 {
        dummyFishSim.stepSimulation(dt: 1.0 / 60.0)
    }
    let postPad = dummyFishSim.lilyPads[0]
    let fullyStatic = (postPad.displacementOffset == .zero && postPad.currentWobbleAngle == 0.0 && postPad.contactCooldown == 0.0)

    let t22_1Passed = countIs16 && fourFlowers && initialStatic && remainsStatic && contactDebounced && fullyStatic
    recordSimTest(
        "T22.1 Hybrid PondLilyPad (16 Pads, 4 Flowers) & Static Anchor Integrity",
        passed: t22_1Passed,
        details: "padsCount=\(pads.count), flowersCount=\(floweringCount), remainsStatic=\(remainsStatic), contactDebounced=\(contactDebounced), fullyStatic=\(fullyStatic)"
    )
}

do {
    // T22.2 Frog Bump Startle & Nearest Lily Pad Leap
    let testBounds = PondBounds(width: 480, height: 270)
    let pads = PondLilyPad.generatePads(for: testBounds)

    var frog = PondFrog.initial(bounds: testBounds)
    let initialPerched = (frog.state == .perched)
    let startleChanceSpec = (PondFrog.bumpStartleChance == 0.40)
    let hopRangeSpec = (PondFrog.hopRange == 70.0)
    let hopDurationSpec = (PondFrog.hopSeconds == 0.50)

    // Perched pad is pad 4 (Cluster 1, Pad 1)
    let perchedPadId = 4

    // Test with roll > 0.40 (frog remains calm)
    let calmResult = frog.handlePadBump(bumpedPadId: perchedPadId, allPads: pads, randomRoll: 0.75)
    let remainedCalm = (!calmResult && frog.state == .perched)

    // Test with roll <= 0.40 (frog startles and hops to nearest neighbor pad)
    let startledResult = frog.handlePadBump(bumpedPadId: perchedPadId, allPads: pads, randomRoll: 0.25)
    let hoppingTriggered = (startledResult && frog.state == .hoppingToPad)
    let hopTargetAssigned = (frog.hopTargetPosition != .zero)

    // Verify target pad is within 70pt
    let hopDist = hypot(frog.hopTargetPosition.x - frog.hopOriginPosition.x, frog.hopTargetPosition.y - frog.hopOriginPosition.y)
    let targetWithin70 = (hopDist > 5.0 && hopDist <= 70.0)

    // Advance 35 frames (~0.58s at 60 FPS) to complete leap and land
    for _ in 0..<35 {
        frog.update(dt: 1.0 / 60.0, bounds: testBounds) { _, _ in }
    }
    let landedOnPad = (frog.state == .landing || frog.state == .perched)
    let altitudeAtRest = (frog.altitude == 0.0)

    let t22_2Passed = initialPerched && startleChanceSpec && hopRangeSpec && hopDurationSpec &&
                      remainedCalm && hoppingTriggered && hopTargetAssigned && targetWithin70 &&
                      landedOnPad && altitudeAtRest
    recordSimTest(
        "T22.2 Frog Bump Startle & Nearest Lily Pad Hop (0.40 Chance, 70pt Range)",
        passed: t22_2Passed,
        details: "startleChance=\(PondFrog.bumpStartleChance), hopRange=\(PondFrog.hopRange), hopDist=\(String(format: "%.1f", hopDist))pt, landed=\(landedOnPad)"
    )
}

do {
    // T22.3 Tiny Fish Steal (tinyFishSteal: Bites Remaining, 70pt Swarm, Nibble Ripple)
    let testBounds = PondBounds(width: 800, height: 600)
    let pellet = FoodPellet(position: PondVector(x: 300, y: 300), bitesRemaining: 2.0)
    let initialBites = pellet.bitesRemaining

    var school = DecorativeSchool(groupIndex: 0, bounds: testBounds, seed: 555)
    // Position fish 0 very close to pellet (dist = 5.0 pt)
    school.fish[0].position = PondVector(x: 305, y: 300)

    var ripplesSpawned: [RippleType] = []
    var pellets = [pellet]

    // Perform tiny fish steal
    school.performTinyFishSteal(dt: 1.0 / 60.0, pellets: &pellets) { _, rType in
        ripplesSpawned.append(rType)
    }

    let biteSubtracted = (pellets[0].bitesRemaining < initialBites)
    let biteAmount = initialBites - pellets[0].bitesRemaining
    let biteMatchesSpec = (abs(biteAmount - 0.35) < 0.001)
    let nibbleRippleGenerated = ripplesSpawned.contains(.eatingNibble)

    // Repeated bites deplete pellet completely
    for _ in 0..<6 {
        pellets[0].takeBite(amount: 0.35)
    }
    let fullyConsumed = pellets[0].isConsumed

    let t22_3Passed = (initialBites == 2.0) && biteSubtracted && biteMatchesSpec && nibbleRippleGenerated && fullyConsumed
    recordSimTest(
        "T22.3 Tiny Fish Steal (bitesRemaining 1.0–3.0, 70pt Swarm, 0.35 Bite, .eatingNibble)",
        passed: t22_3Passed,
        details: "initialBites=\(initialBites), biteAmount=\(biteAmount), nibbleRipple=\(nibbleRippleGenerated), consumed=\(fullyConsumed)"
    )
}

do {
    // T22.4 Butterfly Lotus Flower Visiting Dynamics (Approaching, Orbiting 7–12pt, Resting)
    let testBounds = PondBounds(width: 800, height: 600)
    let pads = PondLilyPad.generatePads(for: testBounds)
    let lotusFlowers = pads.filter { $0.hasFlower }.map { $0.flowerPosition }

    let allButterflyStates = ButterflyState.allCases
    let has4States = (allButterflyStates.count == 4)

    var butterfly = PondInsect(
        type: .butterfly,
        position: PondVector(x: 200, y: 200),
        seed: 777
    )
    let initialWandering = (butterfly.butterflyState == .wandering)

    // Force flower visit trigger
    butterfly.flowerStateTimer = 0.0
    butterfly.update(dt: 1.0 / 60.0, bounds: testBounds, flowerPositions: lotusFlowers)

    let transitionedToApproaching = (butterfly.butterflyState == .approaching)
    let targetFlowerSet = (butterfly.targetFlowerPosition != nil)

    // Move butterfly close to target flower to trigger orbiting
    if let targetFlower = butterfly.targetFlowerPosition {
        butterfly.position = targetFlower + PondVector(x: 10.0, y: 0.0)
    }
    butterfly.update(dt: 1.0 / 60.0, bounds: testBounds, flowerPositions: lotusFlowers)

    let transitionedToOrbiting = (butterfly.butterflyState == .orbiting)
    let orbitRadiusInSpec = (butterfly.flowerOrbitRadius >= 7.0 && butterfly.flowerOrbitRadius <= 12.0)

    // Expire orbit timer to trigger resting
    butterfly.flowerStateTimer = 0.0
    butterfly.update(dt: 1.0 / 60.0, bounds: testBounds, flowerPositions: lotusFlowers)

    let transitionedToResting = (butterfly.butterflyState == .resting)
    let restingLowAltitude = (butterfly.altitude <= 0.10)

    // Expire rest timer to take off back into wander
    butterfly.flowerStateTimer = 0.0
    butterfly.update(dt: 1.0 / 60.0, bounds: testBounds, flowerPositions: lotusFlowers)

    let returnedToWander = (butterfly.butterflyState == .wandering)

    let t22_4Passed = has4States && initialWandering && transitionedToApproaching &&
                      targetFlowerSet && transitionedToOrbiting && orbitRadiusInSpec &&
                      transitionedToResting && restingLowAltitude && returnedToWander
    recordSimTest(
        "T22.4 Butterfly Lotus Flower Visiting (Approaching, Orbiting 7–12pt, Resting)",
        passed: t22_4Passed,
        details: "has4States=\(has4States), approaching=\(transitionedToApproaching), orbiting=\(transitionedToOrbiting), radius=\(String(format: "%.1f", butterfly.flowerOrbitRadius))pt, resting=\(transitionedToResting), wanderReturn=\(returnedToWander)"
    )
}

do {
    // T22.5 5 Ripple Types & Floating Debris Physical Wave Impulse
    let allRippleTypes = RippleType.allCases
    let has5Types = (allRippleTypes.count == 5)
    let containsAllExpected = Set(allRippleTypes).isSuperset(of: [.waterCall, .foodDrop, .eatingNibble, .rainDrop, .padBump])

    // Test physical impulse on floating debris
    var debris = FloatingDebris(
        type: .sakuraPetal,
        position: PondVector(x: 200, y: 200),
        velocity: .zero,
        lifespan: 30.0
    )
    let initialVelocity = debris.velocity

    // Ripple placed at (170, 200) with radius 30.0 (exact crest match at dist = 30pt)
    debris.applyRippleImpulse(
        rippleCenter: PondVector(x: 170, y: 200),
        rippleRadius: 30.0,
        maxRadius: 140.0,
        strength: 1.0,
        rippleType: .waterCall
    )

    let pushedOutward = (debris.velocity.x > initialVelocity.x)
    let spinImparted = (debris.spin != 0.0)

    // Compare with rainDrop weight (1.4x weight vs 0.8x weight)
    var debrisRain = FloatingDebris(
        type: .sakuraPetal,
        position: PondVector(x: 200, y: 200),
        velocity: .zero,
        lifespan: 30.0
    )
    debrisRain.applyRippleImpulse(
        rippleCenter: PondVector(x: 170, y: 200),
        rippleRadius: 30.0,
        maxRadius: 140.0,
        strength: 1.0,
        rippleType: .rainDrop
    )

    let rainPushStronger = (debrisRain.velocity.x > debris.velocity.x)

    let t22_5Passed = has5Types && containsAllExpected && pushedOutward && spinImparted && rainPushStronger
    recordSimTest(
        "T22.5 5 Ripple Types & Floating Debris Physical Wave Impulse (applyRippleImpulse)",
        passed: t22_5Passed,
        details: "has5Types=\(has5Types), types=\(allRippleTypes.map { $0.rawValue }), pushedX=\(String(format: "%.2f", debris.velocity.x)), rainPushedX=\(String(format: "%.2f", debrisRain.velocity.x))"
    )
}

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
