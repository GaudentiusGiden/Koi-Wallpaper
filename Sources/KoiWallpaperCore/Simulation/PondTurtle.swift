import Foundation
import CoreGraphics

/// States for the swimming pond turtle (*Nihon Ishigame / Kame*).
public enum PondTurtleState: String, Sendable, CaseIterable {
    /// Cruising peacefully across the open pond water with relaxed flipper strokes.
    case swimming
    /// Quick swimming burst and startle reaction when clicked near.
    case startled
}

/// Simulation model for the Pond Turtle (*Kame* / Kura-kura Kolam).
///
/// An autonomous aquatic resident of the pond swimming gracefully alongside the koi fish.
/// Features rhythmic flipper paddle kinetics, natural wandering with margin avoidance,
/// and interactive speed-burst reactions when clicked.
public struct PondTurtle: Sendable {

    // MARK: - Style & Identity

    public var variant: PondTurtleArtwork.PaletteVariant = .nagomi

    // MARK: - State & Transform

    public var state: PondTurtleState = .swimming
    public var position: CGPoint = .zero
    public var heading: Double = 0.35 // Facing angle in radians
    public var speed: Double = 20.0   // Current swimming speed (pt/s)
    public var length: CGFloat = 84.0 // Turtle length in pt (~84pt, proportional alongside koi & duck)

    // MARK: - Animation & Kinetics

    /// Swimming flipper paddle stroke phase (radians).
    public var paddlePhase: Double = 0.0

    /// Target wandering angle for natural meandering paths.
    public var wanderAngle: Double = 0.35

    /// Time spent in the current state.
    public var stateTime: Double = 0.0

    /// Timer for spawning periodic subtle swim ripples.
    public var rippleTimer: Double = 0.0
    public var nextRippleInterval: Double = 5.0

    /// Whether the turtle is active and visible in the pond.
    public var isVisible: Bool = true

    // MARK: - Initialization

    public init(bounds: PondBounds) {
        // Start in open pond water between center and shoreline
        self.position = CGPoint(x: bounds.width * 0.32, y: bounds.height * 0.48)
        self.heading = 0.35
        self.wanderAngle = 0.35
        self.speed = 20.0
        self.state = .swimming
    }

    public static func initial(bounds: PondBounds) -> PondTurtle {
        PondTurtle(bounds: bounds)
    }

    // MARK: - Bounds Adaptation

    public mutating func updateLocations(bounds: PondBounds) {
        clampToBounds(bounds: bounds)
    }

    public mutating func clampToBounds(bounds: PondBounds) {
        let margin: CGFloat = 40.0
        position.x = max(margin, min(CGFloat(bounds.width) - margin, position.x))
        position.y = max(margin, min(CGFloat(bounds.height) - margin, position.y))
    }

    // MARK: - Simulation Tick

    public mutating func update(
        dt: Double,
        bounds: PondBounds,
        spawnRipple: (CGPoint, RippleType) -> Void
    ) {
        stateTime += dt
        rippleTimer += dt

        switch state {
        case .swimming:
            updateSwimming(dt: dt, bounds: bounds, spawnRipple: spawnRipple)
        case .startled:
            updateStartled(dt: dt, bounds: bounds, spawnRipple: spawnRipple)
        }
    }

    // MARK: - State Handlers

    private mutating func updateSwimming(
        dt: Double,
        bounds: PondBounds,
        spawnRipple: (CGPoint, RippleType) -> Void
    ) {
        speed = 20.0

        // 1. Natural wandering & soft shoreline margin repulsion
        let margin: Double = 65.0
        var steerX = 0.0
        var steerY = 0.0

        if Double(position.x) < margin { steerX += 1.0 }
        if Double(position.x) > bounds.width - margin { steerX -= 1.0 }
        if Double(position.y) < margin { steerY += 1.0 }
        if Double(position.y) > bounds.height - margin { steerY -= 1.0 }

        if steerX != 0.0 || steerY != 0.0 {
            let avoidAngle = atan2(steerY, steerX)
            let diff = angleDifference(target: avoidAngle, current: wanderAngle)
            wanderAngle += diff * min(1.0, dt * 2.5)
        } else {
            // Gentle random course wandering
            wanderAngle += Double.random(in: -0.35...0.35) * dt * 2.0
        }

        // Smooth heading interpolation toward wanderAngle
        let turnDiff = angleDifference(target: wanderAngle, current: heading)
        heading += turnDiff * min(1.0, dt * 3.2)

        // Advance position forward
        position.x += CGFloat(cos(heading) * speed * dt)
        position.y += CGFloat(sin(heading) * speed * dt)
        clampToBounds(bounds: bounds)

        // Paddle stroke progression (faster swimming = faster flipper stroke)
        paddlePhase += dt * (speed * 0.18 + 1.2)
        if paddlePhase > .pi * 200 { paddlePhase -= .pi * 200 }

        // Periodic subtle swim ripple
        if rippleTimer >= nextRippleInterval {
            rippleTimer = 0.0
            nextRippleInterval = Double.random(in: 4.5...7.5)
            spawnRipple(position, .eatingNibble)
        }
    }

    private mutating func updateStartled(
        dt: Double,
        bounds: PondBounds,
        spawnRipple: (CGPoint, RippleType) -> Void
    ) {
        speed = 46.0

        // Steer away from edges during panic burst
        let margin: Double = 50.0
        var steerX = 0.0
        var steerY = 0.0

        if Double(position.x) < margin { steerX += 1.0 }
        if Double(position.x) > bounds.width - margin { steerX -= 1.0 }
        if Double(position.y) < margin { steerY += 1.0 }
        if Double(position.y) > bounds.height - margin { steerY -= 1.0 }

        if steerX != 0.0 || steerY != 0.0 {
            let avoidAngle = atan2(steerY, steerX)
            let diff = angleDifference(target: avoidAngle, current: heading)
            heading += diff * min(1.0, dt * 4.0)
        }

        position.x += CGFloat(cos(heading) * speed * dt)
        position.y += CGFloat(sin(heading) * speed * dt)
        clampToBounds(bounds: bounds)

        paddlePhase += dt * 8.2
        if paddlePhase > .pi * 200 { paddlePhase -= .pi * 200 }

        // After 2.2 seconds of panic burst, settle back to calm swimming
        if stateTime >= 2.2 {
            state = .swimming
            stateTime = 0.0
            speed = 20.0
            wanderAngle = heading
        }
    }

    private func angleDifference(target: Double, current: Double) -> Double {
        var diff = (target - current).truncatingRemainder(dividingBy: .pi * 2)
        if diff < -.pi { diff += .pi * 2 }
        if diff > .pi { diff -= .pi * 2 }
        return diff
    }

    // MARK: - Interactive Trigger

    /// Startles the swimming turtle, causing an energetic speed burst away from the click.
    public mutating func triggerStartle(awayFrom point: CGPoint) {
        let dx = Double(position.x - point.x)
        let dy = Double(position.y - point.y)
        heading = atan2(dy, dx) + Double.random(in: -0.2...0.2)
        wanderAngle = heading
        speed = 46.0
        state = .startled
        stateTime = 0.0
    }
}
