import Foundation
import CoreGraphics

/// State machine for the single pond frog resting on a water lily pad.
public enum PondFrogState: String, Sendable, CaseIterable {
    /// Resting on the lily pad, breathing, blinking, and occasionally croaking.
    case perched
    /// Brief crouch wind-up right before launching into a leap.
    case crouching
    /// Airborne leap from the lily pad out into the pond water.
    case jumpingOut
    /// Submerged / away under the leaves or swimming out of sight.
    case away
    /// Airborne leap returning from the water back onto the lily pad.
    case jumpingIn
    /// Brief squash-and-stretch settle upon landing back on the lily pad.
    case landing
}

/// Visual design variants for the pond frog.
public enum PondFrogVariant: String, Sendable, CaseIterable {
    /// Classic vibrant Japanese tree frog (Nihon Amagaeru) with dark eye mask & lime spine
    case classicGreen
    /// Sturdy mossy pond frog (Tono-gaeru) with camo spots & golden lateral ridges
    case mossySpotted
    /// Radiant golden chartreuse Zen frog (Kaeru) bringing harmony & high contrast
    case goldenZen
    /// Cute mascot frog with a delicate pink lotus petal hat on its head
    case lotusPetal

    public var displayName: String {
        switch self {
        case .classicGreen: return "Nihon Amagaeru (Katak Hijau Klasik)"
        case .mossySpotted: return "Tono-gaeru (Katak Kolam Lumut)"
        case .goldenZen: return "Kaeru Kencana (Katak Emas Zen)"
        case .lotusPetal: return "Hasu Kaeru (Katak Bertopi Teratai)"
        }
    }
}

/// Simulation model for the pond frog (katak teratai).
///
/// Perches on a prominent water lily pad, displaying lifelike idle micro-animations
/// (throat sac breathing, vocal croak puffing, eye blinking, subtle head twitches),
/// periodically leaping out into the pond water with a parabolic arc and splash ripple,
/// and returning several seconds later.
public struct PondFrog: Sendable {

    // MARK: - Style & Identity

    public var variant: PondFrogVariant = .lotusPetal

    // MARK: - State & Transform

    public var state: PondFrogState = .perched
    public var position: CGPoint = .zero
    public var altitude: CGFloat = 0.0
    public var heading: Double = 0.0 // Facing angle in radians

    // MARK: - Perch & Water Locations

    public var perchPosition: CGPoint = .zero
    public var waterPosition: CGPoint = .zero

    // MARK: - Timing & Progression

    public var stateTime: Double = 0.0
    public var stateDuration: Double = 14.0 // Target duration for current state

    // MARK: - Idle Micro-Animations (When Perched)

    /// Continuous rhythmic throat breathing oscillation phase (rad).
    public var throatPhase: Double = 0.0

    /// Progress of vocal sac croak puff [0, 1]. 0 = normal throat, 1 = maximum balloon puff.
    public var croakProgress: Double = 0.0
    public var croakTimer: Double = 6.0

    /// Eye blink flag & timer.
    public var isBlinking: Bool = false
    public var blinkTimer: Double = 3.5

    /// Subtle head angle twitch offset (radians).
    public var headAngleOffset: Double = 0.0
    public var headTwitchTimer: Double = 5.0

    /// Squash & stretch deformation scale for crouching and landing cushion.
    public var scaleX: CGFloat = 1.0
    public var scaleY: CGFloat = 1.0

    /// Whether the frog is currently visible in the scene.
    public var isVisible: Bool {
        state != .away
    }

    // MARK: - Initialization

    public init(bounds: PondBounds) {
        updateLocations(bounds: bounds)
        self.position = perchPosition
        self.heading = defaultPerchHeading(perch: perchPosition, water: waterPosition)
        self.state = .perched
        self.stateDuration = 12.0
    }

    public static func initial(bounds: PondBounds) -> PondFrog {
        PondFrog(bounds: bounds)
    }

    // MARK: - Perch Location Derivation

    /// Computes the exact perch location on the prominent lily pad at the bottom-left corner
    /// (Cluster 1, Pad 1) and the matching landing water position based on current pond bounds.
    public mutating func updateLocations(bounds: PondBounds) {
        let w = bounds.width
        let h = bounds.height
        let short = min(w, h)
        let scale = short * 1.3

        // Anchor 1 of flora is at the bottom-left corner: (0.065, 0.08)
        let anchorX = 0.065 * w
        let anchorY = 0.08 * h

        // Pad 1 of Cluster 1: offset (0.055, -0.020), radius 0.095 * scale
        let padCenterX = anchorX + 0.055 * scale
        let padCenterY = anchorY - 0.020 * scale
        let padRadius = 0.095 * scale

        // Perch on the green leaf surface of the bottom-left lily pad,
        // offset northeast of the lotus flower toward open pond water:
        let perchOffsetX = padRadius * 0.52 * cos(0.72)
        let perchOffsetY = padRadius * 0.52 * sin(0.72)

        self.perchPosition = CGPoint(x: padCenterX + perchOffsetX, y: padCenterY + perchOffsetY)

        // Water landing spot: ~120 pt northeast into open swimming water
        let jumpDistance = max(95.0, min(150.0, short * 0.20))
        self.waterPosition = CGPoint(
            x: perchPosition.x + jumpDistance * cos(0.68),
            y: perchPosition.y + jumpDistance * sin(0.68)
        )

        // If currently perched or landing, snap position to perch
        if state == .perched || state == .landing {
            self.position = perchPosition
            self.heading = defaultPerchHeading(perch: perchPosition, water: waterPosition) + headAngleOffset
        }
    }

    private func defaultPerchHeading(perch: CGPoint, water: CGPoint) -> Double {
        atan2(Double(water.y - perch.y), Double(water.x - perch.x))
    }

    // MARK: - Simulation Tick

    public mutating func update(dt: Double, bounds: PondBounds, spawnRipple: (CGPoint, RippleType) -> Void) {
        stateTime += dt

        switch state {
        case .perched:
            updatePerched(dt: dt)

        case .crouching:
            updateCrouching(dt: dt)

        case .jumpingOut:
            updateJumpingOut(dt: dt, spawnRipple: spawnRipple)

        case .away:
            updateAway(dt: dt)

        case .jumpingIn:
            updateJumpingIn(dt: dt, spawnRipple: spawnRipple)

        case .landing:
            updateLanding(dt: dt)
        }
    }

    // MARK: - State Handlers

    private mutating func updatePerched(dt: Double) {
        position = perchPosition
        altitude = 0.0
        scaleX = 1.0
        scaleY = 1.0

        // 1. Throat breathing pulse (~1.8 Hz)
        throatPhase += dt * 11.3 // ~1.8 Hz in radians
        if throatPhase > .pi * 200 { throatPhase -= .pi * 200 }

        // 2. Vocal croak puff cycle
        croakTimer -= dt
        if croakTimer <= 0 {
            // Croak puff lasts ~0.65s (sinusoidal balloon)
            let puffDuration = 0.65
            let puffTime = -croakTimer
            if puffTime < puffDuration {
                croakProgress = sin(puffTime / puffDuration * .pi)
            } else {
                croakProgress = 0.0
                croakTimer = Double.random(in: 5.5...9.0)
            }
        } else {
            croakProgress = 0.0
        }

        // 3. Eye blinking
        blinkTimer -= dt
        if blinkTimer <= 0 {
            let blinkDuration = 0.16
            let blinkTime = -blinkTimer
            if blinkTime < blinkDuration {
                isBlinking = true
            } else {
                isBlinking = false
                blinkTimer = Double.random(in: 3.2...5.8)
            }
        } else {
            isBlinking = false
        }

        // 4. Subtle head look-around twitch
        headTwitchTimer -= dt
        if headTwitchTimer <= 0 {
            headAngleOffset = Double.random(in: -0.22...0.22)
            headTwitchTimer = Double.random(in: 4.0...7.5)
        }

        let baseHeading = defaultPerchHeading(perch: perchPosition, water: waterPosition)
        heading = baseHeading + headAngleOffset

        // Check if perched period expired -> transition to crouch & leap
        if stateTime >= stateDuration {
            transitionTo(state: .crouching, duration: 0.22)
        }
    }

    private mutating func updateCrouching(dt: Double) {
        position = perchPosition
        altitude = 0.0
        croakProgress = 0.0
        isBlinking = false

        // Wind-up posture compression (squash down before spring)
        let t = min(1.0, CGFloat(stateTime / stateDuration))
        scaleX = 1.0 + 0.18 * t
        scaleY = 1.0 - 0.20 * t

        let jumpHeading = defaultPerchHeading(perch: perchPosition, water: waterPosition)
        heading = jumpHeading

        if stateTime >= stateDuration {
            transitionTo(state: .jumpingOut, duration: 0.72)
        }
    }

    private mutating func updateJumpingOut(dt: Double, spawnRipple: (CGPoint, RippleType) -> Void) {
        let p = min(1.0, CGFloat(stateTime / stateDuration))
        // Smooth step horizontal interpolation for natural leap momentum
        let smoothP = p * p * (3.0 - 2.0 * p)

        position.x = perchPosition.x + (waterPosition.x - perchPosition.x) * smoothP
        position.y = perchPosition.y + (waterPosition.y - perchPosition.y) * smoothP

        // Parabolic vertical jump arc (apex ~26 pt above water)
        let maxApex: CGFloat = 26.0
        altitude = 4.0 * maxApex * p * (1.0 - p)

        // Dynamic elongated leap pose
        scaleX = 1.15
        scaleY = 0.88

        let jumpHeading = defaultPerchHeading(perch: perchPosition, water: waterPosition)
        heading = jumpHeading

        if stateTime >= stateDuration {
            // Water impact! Spawn splash ripple
            altitude = 0.0
            spawnRipple(waterPosition, .waterCall)

            // Disappear into submerged / away state
            transitionTo(state: .away, duration: Double.random(in: 5.5...9.5))
        }
    }

    private mutating func updateAway(dt: Double) {
        position = waterPosition
        altitude = 0.0

        if stateTime >= stateDuration {
            // Ready to return! Launch return leap from water onto lily pad
            transitionTo(state: .jumpingIn, duration: 0.74)
        }
    }

    private mutating func updateJumpingIn(dt: Double, spawnRipple: (CGPoint, RippleType) -> Void) {
        let p = min(1.0, CGFloat(stateTime / stateDuration))
        let smoothP = p * p * (3.0 - 2.0 * p)

        position.x = waterPosition.x + (perchPosition.x - waterPosition.x) * smoothP
        position.y = waterPosition.y + (perchPosition.y - waterPosition.y) * smoothP

        // Parabolic arc for returning leap
        let maxApex: CGFloat = 28.0
        altitude = 4.0 * maxApex * p * (1.0 - p)

        scaleX = 1.14
        scaleY = 0.88

        // Face toward lily pad
        let returnHeading = atan2(Double(perchPosition.y - waterPosition.y), Double(perchPosition.x - waterPosition.x))
        heading = returnHeading

        if stateTime >= stateDuration {
            // Touch down on lily pad!
            altitude = 0.0
            position = perchPosition

            // Gentle landing ripple on the water beside the lily pad
            spawnRipple(CGPoint(x: perchPosition.x + 8.0, y: perchPosition.y - 6.0), .eatingNibble)

            transitionTo(state: .landing, duration: 0.24)
        }
    }

    private mutating func updateLanding(dt: Double) {
        position = perchPosition
        altitude = 0.0

        // Squash-and-stretch landing cushion
        let p = min(1.0, CGFloat(stateTime / stateDuration))
        let cushion = sin(p * .pi)
        scaleX = 1.0 + 0.22 * cushion
        scaleY = 1.0 - 0.18 * cushion

        let baseHeading = defaultPerchHeading(perch: perchPosition, water: waterPosition)
        heading = baseHeading

        if stateTime >= stateDuration {
            // Settle back to perched state with fresh duration
            transitionTo(state: .perched, duration: Double.random(in: 11.0...17.0))
        }
    }

    private mutating func transitionTo(state newState: PondFrogState, duration: Double) {
        self.state = newState
        self.stateTime = 0.0
        self.stateDuration = duration
    }

    // MARK: - Interactive Trigger

    /// If the user clicks near the perched frog, it startles and initiates an immediate leap!
    public mutating func triggerJumpIfPerched() {
        if state == .perched {
            transitionTo(state: .crouching, duration: 0.14)
        }
    }
}
