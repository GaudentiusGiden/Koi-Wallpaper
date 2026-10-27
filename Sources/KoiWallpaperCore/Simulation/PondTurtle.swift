import Foundation
import CoreGraphics

/// State machine for the pond turtle (*Kame* / Kura-kura Kolam).
public enum PondTurtleState: String, Sendable, CaseIterable {
    /// Resting comfortably on the river stone, sunbathing with sleepy zen eyes.
    case basking
    /// Brief reaction when clicked near or startled by ripples.
    case startled
    /// Sliding off the stone and diving into the pond water with a gentle splash ripple.
    case slidingIn
    /// Swimming gracefully across the pond alongside the koi fish with paddle strokes and ripples.
    case swimming
    /// Navigating smoothly back toward the river rock to climb out.
    case returning
    /// Climbing from the water surface back onto the basking stone.
    case climbingOut
    /// Submerged or resting out of view between visits.
    case away
}

/// Simulation model for the Pond Turtle (*Kame* / Kura-kura Kolam).
///
/// Autonomously alternates between basking on a shoreline river stone and swimming gracefully
/// among the koi fish. Startles and dives if clicked while basking.
public struct PondTurtle: Sendable {

    // MARK: - Style & Identity

    public var variant: PondTurtleArtwork.PaletteVariant = .nagomi

    // MARK: - State & Transform

    public var state: PondTurtleState = .basking
    public var position: CGPoint = .zero
    public var heading: Double = 0.18 // Facing angle in radians
    public var altitude: CGFloat = 0.0
    public var speed: Double = 0.0

    // MARK: - Rock & Water Anchor Locations

    public var rockPosition: CGPoint = .zero
    public var waterPosition: CGPoint = .zero

    // MARK: - Timing & Progression

    public var stateTime: Double = 0.0
    public var stateDuration: Double = 24.0

    // MARK: - Animation Phases

    /// Swimming paddle stroke phase (radians).
    public var paddlePhase: Double = 0.0

    /// Basking subtle breathing phase (radians).
    public var breathPhase: Double = 0.0

    /// Wandering angle for natural meandering swimming paths.
    public var wanderAngle: Double = 0.0

    /// Scale factor for pixel-art rendering.
    public var scale: CGFloat = 1.65

    /// Whether the turtle is currently visible in the scene.
    public var isVisible: Bool {
        state != .away
    }

    // MARK: - Initialization

    public init(bounds: PondBounds) {
        updateLocations(bounds: bounds)
        self.position = rockPosition
        self.state = .basking
        self.stateDuration = 24.0
    }

    public static func initial(bounds: PondBounds) -> PondTurtle {
        PondTurtle(bounds: bounds)
    }

    // MARK: - Location Updates

    /// Computes the exact river rock position near the top-left shoreline lily pads
    /// and the water entry spot based on current pond bounds.
    public mutating func updateLocations(bounds: PondBounds) {
        let w = bounds.width
        let h = bounds.height

        // Top-left cove near Anchor 0: (0.194 * w, 0.722 * h)
        // Perfectly positioned beside the lily pads with zero obstruction of open swimming lanes.
        self.rockPosition = CGPoint(x: 0.194 * w, y: 0.722 * h)

        // Water entry spot right beside the stone toward open pond water
        self.waterPosition = CGPoint(x: rockPosition.x + 55.0, y: rockPosition.y - 35.0)

        if state == .basking || state == .startled {
            self.position = rockPosition
            self.altitude = 4.0
        }
    }

    // MARK: - Simulation Tick

    public mutating func update(
        dt: Double,
        bounds: PondBounds,
        spawnRipple: (CGPoint, RippleType) -> Void
    ) {
        stateTime += dt

        switch state {
        case .basking:
            updateBasking(dt: dt)

        case .startled:
            updateStartled(dt: dt, spawnRipple: spawnRipple)

        case .slidingIn:
            updateSlidingIn(dt: dt, bounds: bounds, spawnRipple: spawnRipple)

        case .swimming:
            updateSwimming(dt: dt, bounds: bounds)

        case .returning:
            updateReturning(dt: dt, spawnRipple: spawnRipple)

        case .climbingOut:
            updateClimbingOut(dt: dt)

        case .away:
            updateAway(dt: dt)
        }
    }

    // MARK: - State Handlers

    private mutating func updateBasking(dt: Double) {
        position = rockPosition
        altitude = 4.0
        speed = 0.0
        heading = 0.18

        // Subtle breathing micro-animation
        breathPhase += dt * 2.2
        if breathPhase > .pi * 200 { breathPhase -= .pi * 200 }

        if stateTime >= stateDuration {
            // Natural transition to slide into the water for a swim
            transitionTo(state: .slidingIn, duration: 1.0)
        }
    }

    private mutating func updateStartled(dt: Double, spawnRipple: (CGPoint, RippleType) -> Void) {
        position = rockPosition
        altitude = 3.5

        if stateTime >= stateDuration {
            // Startle leads to an immediate splash dive into the water!
            spawnRipple(CGPoint(x: rockPosition.x + 20.0, y: rockPosition.y - 15.0), .waterCall)
            transitionTo(state: .slidingIn, duration: 0.75)
        }
    }

    private mutating func updateSlidingIn(
        dt: Double,
        bounds: PondBounds,
        spawnRipple: (CGPoint, RippleType) -> Void
    ) {
        let p = min(1.0, CGFloat(stateTime / stateDuration))
        let smoothP = p * p * (3.0 - 2.0 * p)

        // Slide down from rock onto water surface
        position.x = rockPosition.x + (waterPosition.x - rockPosition.x) * smoothP
        position.y = rockPosition.y + (waterPosition.y - rockPosition.y) * smoothP
        altitude = max(0.0, 4.0 * (1.0 - p))

        heading = atan2(Double(waterPosition.y - rockPosition.y), Double(waterPosition.x - rockPosition.x))
        paddlePhase += dt * 6.0

        if stateTime >= stateDuration {
            altitude = 0.0
            position = waterPosition
            spawnRipple(waterPosition, .waterCall)
            wanderAngle = heading
            transitionTo(state: .swimming, duration: Double.random(in: 28.0...45.0))
        }
    }

    private mutating func updateSwimming(dt: Double, bounds: PondBounds) {
        altitude = 0.0
        speed = 22.0 // Relaxed, gentle swimming speed

        // Natural wandering steering
        wanderAngle += Double.random(in: -0.35...0.35) * dt * 3.0
        wanderAngle = wanderAngle.truncatingRemainder(dividingBy: .pi * 2)

        // Soft wall avoidance
        let margin = 90.0
        var steerX = 0.0
        var steerY = 0.0

        if Double(position.x) < margin { steerX += 1.0 }
        if Double(position.x) > bounds.width - margin { steerX -= 1.0 }
        if Double(position.y) < margin { steerY += 1.0 }
        if Double(position.y) > bounds.height - margin { steerY -= 1.0 }

        if steerX != 0.0 || steerY != 0.0 {
            let avoidAngle = atan2(steerY, steerX)
            wanderAngle = wanderAngle * 0.92 + avoidAngle * 0.08
        }

        heading = wanderAngle

        // Advance position
        position.x += CGFloat(cos(heading) * speed * dt)
        position.y += CGFloat(sin(heading) * speed * dt)

        // Clamp inside bounds
        position.x = max(40.0, min(CGFloat(bounds.width - 40.0), position.x))
        position.y = max(40.0, min(CGFloat(bounds.height - 40.0), position.y))

        // Paddle stroke progression
        paddlePhase += dt * 4.8
        if paddlePhase > .pi * 200 { paddlePhase -= .pi * 200 }

        if stateTime >= stateDuration {
            // Finished swimming cycle -> return to rock
            transitionTo(state: .returning, duration: 12.0)
        }
    }

    private mutating func updateReturning(dt: Double, spawnRipple: (CGPoint, RippleType) -> Void) {
        altitude = 0.0
        speed = 26.0

        let dx = Double(waterPosition.x - position.x)
        let dy = Double(waterPosition.y - position.y)
        let dist = hypot(dx, dy)

        heading = atan2(dy, dx)
        paddlePhase += dt * 5.2

        if dist < 18.0 {
            // Arrived at entry spot -> climb out
            position = waterPosition
            spawnRipple(waterPosition, .eatingNibble)
            transitionTo(state: .climbingOut, duration: 1.4)
        } else {
            position.x += CGFloat(cos(heading) * speed * dt)
            position.y += CGFloat(sin(heading) * speed * dt)
        }

        if stateTime >= stateDuration {
            // Safety timeout: snap to rock if stuck
            transitionTo(state: .climbingOut, duration: 1.0)
        }
    }

    private mutating func updateClimbingOut(dt: Double) {
        let p = min(1.0, CGFloat(stateTime / stateDuration))
        let smoothP = p * p * (3.0 - 2.0 * p)

        // Climb up from water onto rock
        position.x = waterPosition.x + (rockPosition.x - waterPosition.x) * smoothP
        position.y = waterPosition.y + (rockPosition.y - waterPosition.y) * smoothP
        altitude = 4.0 * smoothP

        heading = 0.18
        paddlePhase += dt * 3.0

        if stateTime >= stateDuration {
            position = rockPosition
            altitude = 4.0
            heading = 0.18
            transitionTo(state: .basking, duration: Double.random(in: 22.0...38.0))
        }
    }

    private mutating func updateAway(dt: Double) {
        position = rockPosition
        altitude = 0.0
        speed = 0.0

        if stateTime >= stateDuration {
            // Emerge back onto the basking rock
            transitionTo(state: .basking, duration: Double.random(in: 20.0...35.0))
        }
    }

    private mutating func transitionTo(state newState: PondTurtleState, duration: Double) {
        self.state = newState
        self.stateTime = 0.0
        self.stateDuration = duration
    }

    // MARK: - Interactive Trigger

    /// Startles the turtle if it is currently basking on the rock.
    public mutating func triggerStartleIfBasking() {
        if state == .basking {
            transitionTo(state: .startled, duration: 0.22)
        }
    }
}
