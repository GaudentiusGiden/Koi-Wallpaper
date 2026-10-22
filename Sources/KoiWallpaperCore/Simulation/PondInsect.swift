import Foundation

/// The species of pond insects animating the atmospheric pond scene.
public enum PondInsectType: String, Codable, CaseIterable, Sendable {
    case dragonfly = "dragonfly"
    case butterfly = "butterfly"
    case firefly = "firefly"

    public var displayName: String {
        switch self {
        case .dragonfly: return "Capung (Dragonfly)"
        case .butterfly: return "Kupu-kupu (Butterfly)"
        case .firefly: return "Kunang-kunang (Firefly)"
        }
    }
}

/// Represents an atmospheric pond insect (dragonfly, butterfly, or firefly)
/// with characteristic flight kinetics, altitude, and smooth transition fading.
public struct PondInsect: Identifiable, Sendable {
    public let id: UUID
    public let type: PondInsectType
    public var position: PondVector
    public var velocity: PondVector
    public var heading: Double
    public var speed: Double
    public var altitude: Double // 0.0 (near water surface) to 1.0 (high in air)
    public var opacity: Double // 0.0 to 1.0 (for smooth theme cross-fading)
    public var targetOpacity: Double
    public var phase: Double // wing flutter or glowing pulse phase
    public var wanderAngle: Double
    public var colorVariant: Int // 0 or 1 for visual variety
    public var rng: SeededRandomNumberGenerator

    // Dragonfly darting dynamics
    public var dartTimer: Double
    public var isDarting: Bool
    public var dartDurationRemaining: Double

    public var isFlyingLow: Bool {
        altitude <= 0.45
    }

    public init(
        id: UUID = UUID(),
        type: PondInsectType,
        position: PondVector,
        heading: Double = 0.0,
        speed: Double? = nil,
        altitude: Double? = nil,
        opacity: Double = 1.0,
        targetOpacity: Double = 1.0,
        colorVariant: Int = 0,
        seed: UInt64? = nil
    ) {
        self.id = id
        self.type = type
        self.position = position
        self.heading = normalizeAngle(heading)
        self.opacity = max(0.0, min(1.0, opacity))
        self.targetOpacity = max(0.0, min(1.0, targetOpacity))
        self.colorVariant = colorVariant

        let initialSeed = seed ?? UInt64(truncatingIfNeeded: id.hashValue)
        var prng = SeededRandomNumberGenerator(seed: initialSeed)
        self.phase = Double.random(in: 0...(2 * .pi), using: &prng)
        self.wanderAngle = heading
        self.isDarting = false
        self.dartDurationRemaining = 0.0
        self.rng = prng

        switch type {
        case .dragonfly:
            let defaultSpeed = speed ?? 12.0
            self.speed = defaultSpeed
            self.velocity = PondVector.fromAngle(heading, length: defaultSpeed)
            self.altitude = altitude ?? Double.random(in: 0.20...0.50, using: &self.rng)
            self.dartTimer = Double.random(in: 1.8...3.2, using: &self.rng)

        case .butterfly:
            let defaultSpeed = speed ?? 34.0
            self.speed = defaultSpeed
            self.velocity = PondVector.fromAngle(heading, length: defaultSpeed)
            self.altitude = altitude ?? Double.random(in: 0.30...0.65, using: &self.rng)
            self.dartTimer = 0.0

        case .firefly:
            let defaultSpeed = speed ?? 15.0
            self.speed = defaultSpeed
            self.velocity = PondVector.fromAngle(heading, length: defaultSpeed)
            self.altitude = altitude ?? Double.random(in: 0.15...0.45, using: &self.rng)
            self.dartTimer = 0.0
        }
    }

    /// Advances the insect physics and flight kinetics by a discrete time step.
    public mutating func update(dt: Double, bounds: PondBounds) {
        // Smoothly interpolate opacity towards targetOpacity
        if abs(opacity - targetOpacity) > 0.001 {
            let fadeRate = 1.8 // Fades over ~0.55s to 1.8s
            let step = fadeRate * dt
            if opacity < targetOpacity {
                opacity = min(targetOpacity, opacity + step)
            } else {
                opacity = max(targetOpacity, opacity - step)
            }
        } else {
            opacity = targetOpacity
        }

        switch type {
        case .dragonfly:
            updateDragonfly(dt: dt, bounds: bounds)
        case .butterfly:
            updateButterfly(dt: dt, bounds: bounds)
        case .firefly:
            updateFirefly(dt: dt, bounds: bounds)
        }

        // Hard bounds clamp with safe margin
        position = bounds.clamped(position, inset: 16.0)
    }

    // MARK: - Species Kinetics

    /// Dragonfly: hovers with micro-flutter and periodically darts sharply.
    private mutating func updateDragonfly(dt: Double, bounds: PondBounds) {
        phase += 36.0 * dt // High-frequency wing shimmer
        if phase > 2.0 * .pi { phase -= 2.0 * .pi }

        // Altitude gentle oscillation with low dips
        altitude = 0.32 + 0.18 * sin(phase * 0.45 + Double(colorVariant))

        if isDarting {
            dartDurationRemaining -= dt
            if dartDurationRemaining <= 0.0 {
                isDarting = false
                speed = 12.0
                dartTimer = Double.random(in: 1.8...3.5, using: &rng)
            }
        } else {
            dartTimer -= dt
            if dartTimer <= 0.0 {
                // Dart sudden burst!
                isDarting = true
                dartDurationRemaining = Double.random(in: 0.24...0.38, using: &rng)
                speed = Double.random(in: 140.0...200.0, using: &rng)

                // Pick sharp turn angle (+/- 35 to 90 deg)
                let turnDelta = Double.random(in: 0.6...1.6, using: &rng) * (Double.random(in: 0...1, using: &rng) > 0.5 ? 1.0 : -1.0)
                heading = normalizeAngle(heading + turnDelta)
            }
        }

        // Boundary steering
        let margin = 45.0
        let avoidance = bounds.boundaryAvoidanceForce(for: position, heading: heading, strength: 4.0, marginOverride: margin)
        if avoidance.lengthSquared > 0.01 {
            let desired = avoidance.angle
            let diff = normalizeAngle(desired - heading)
            heading = normalizeAngle(heading + diff * min(1.0, 5.0 * dt))
        }

        velocity = PondVector.fromAngle(heading, length: speed)
        position += velocity * dt
    }

    /// Butterfly: gentle fluttering flight with soft sinusoidal curves.
    private mutating func updateButterfly(dt: Double, bounds: PondBounds) {
        phase += 8.5 * dt // Gentle wing flapping (~4.2 Hz)
        if phase > 2.0 * .pi { phase -= 2.0 * .pi }

        // Altitude sways smoothly
        altitude = 0.42 + 0.28 * sin(phase * 0.5 + Double(colorVariant) * 1.5)

        // Fluttery heading steering: organic wander + sinusoidal wing flutter
        wanderAngle += Double.random(in: -0.3...0.3, using: &rng) * dt * 1.8
        wanderAngle = normalizeAngle(wanderAngle)

        let flutterWave = sin(phase * 2.2) * 0.22
        var desiredHeading = normalizeAngle(wanderAngle + flutterWave)

        // Soft boundary avoidance
        let margin = 50.0
        let avoidance = bounds.boundaryAvoidanceForce(for: position, heading: heading, strength: 3.5, marginOverride: margin)
        if avoidance.lengthSquared > 0.01 {
            desiredHeading = avoidance.angle
        }

        let diff = normalizeAngle(desiredHeading - heading)
        heading = normalizeAngle(heading + diff * min(1.0, 4.0 * dt))

        speed = 30.0 + 8.0 * sin(phase * 1.5)
        velocity = PondVector.fromAngle(heading, length: speed)
        position += velocity * dt
    }

    /// Firefly: slow, lazy drifting motion with soft glowing pulse.
    private mutating func updateFirefly(dt: Double, bounds: PondBounds) {
        // Glowing pulse frequency (gentle breathing cycle)
        let pulseRate = 1.9 + Double(colorVariant) * 0.45
        phase += pulseRate * dt
        if phase > 2.0 * .pi { phase -= 2.0 * .pi }

        // Low-to-mid hovering altitude
        altitude = 0.22 + 0.16 * sin(phase * 0.7 + Double(colorVariant))

        // Gentle wandering drift
        wanderAngle += Double.random(in: -0.25...0.25, using: &rng) * dt * 1.0
        wanderAngle = normalizeAngle(wanderAngle)

        var desiredHeading = wanderAngle
        let margin = 40.0
        let avoidance = bounds.boundaryAvoidanceForce(for: position, heading: heading, strength: 2.5, marginOverride: margin)
        if avoidance.lengthSquared > 0.01 {
            desiredHeading = avoidance.angle
        }

        let diff = normalizeAngle(desiredHeading - heading)
        heading = normalizeAngle(heading + diff * min(1.0, 2.5 * dt))

        speed = 13.0 + 4.0 * sin(phase * 0.8)
        velocity = PondVector.fromAngle(heading, length: speed)
        position += velocity * dt
    }
}
