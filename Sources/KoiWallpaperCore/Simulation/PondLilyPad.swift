import Foundation
import CoreGraphics

/// Represents a single water lily pad (daun teratai) in the pond ecosystem.
/// Stores physical position, radius, flowering state, and dynamic wobble physics
/// triggered by koi fish collisions or frog jumps.
public struct PondLilyPad: Identifiable, Sendable {
    public let id: Int // 0..<16
    public let clusterIndex: Int // 0..<6
    public let padIndex: Int // 0..<3 or 0..<2
    public var position: PondVector
    public var radius: Double
    public var angle: Double
    public var variant: Int
    public let hasFlower: Bool
    public var flowerPosition: PondVector

    // MARK: - Dynamic Wobble Physics
    public static let bumpWobbleSeconds: Double = 0.6

    /// Remaining time for the current wobble oscillation in seconds.
    public var wobbleTime: Double = 0.0
    /// Duration of the active wobble animation.
    public var wobbleDuration: Double = bumpWobbleSeconds
    /// Normalized strength of the wobble [0.0...1.0].
    public var wobbleStrength: Double = 0.0
    /// Physical displacement vector offset caused by the collision impulse.
    public var displacementOffset: PondVector = .zero

    public init(
        id: Int,
        clusterIndex: Int,
        padIndex: Int,
        position: PondVector,
        radius: Double,
        angle: Double,
        variant: Int,
        hasFlower: Bool,
        flowerPosition: PondVector? = nil,
        wobbleTime: Double = 0.0,
        wobbleDuration: Double = bumpWobbleSeconds,
        wobbleStrength: Double = 0.0,
        displacementOffset: PondVector = .zero
    ) {
        self.id = id
        self.clusterIndex = clusterIndex
        self.padIndex = padIndex
        self.position = position
        self.radius = radius
        self.angle = angle
        self.variant = variant
        self.hasFlower = hasFlower
        self.flowerPosition = flowerPosition ?? position
        self.wobbleTime = wobbleTime
        self.wobbleDuration = wobbleDuration
        self.wobbleStrength = wobbleStrength
        self.displacementOffset = displacementOffset
    }

    /// Current rotational wobble angle (radians) computed from active oscillation.
    public var currentWobbleAngle: Double {
        guard wobbleTime > 0.0, wobbleDuration > 0.0 else { return 0.0 }
        let progress = wobbleTime / wobbleDuration
        // High frequency damped oscillation (~28 rad/s)
        return sin((wobbleDuration - wobbleTime) * 28.0) * wobbleStrength * progress * 0.12
    }

    /// Triggers a wobble reaction when a koi or creature bumps into this lily pad.
    public mutating func triggerBump(from source: PondVector, strength: Double = 1.0, duration: Double = bumpWobbleSeconds) {
        self.wobbleDuration = max(0.05, duration)
        self.wobbleTime = duration
        self.wobbleStrength = min(1.0, max(0.1, strength))

        let diff = position - source
        let dist = diff.length
        let pushDir = dist > 0.001 ? (diff / dist) : PondVector(x: 1.0, y: 0.0)
        let pushMagnitude = min(5.0, 3.5 * self.wobbleStrength)
        self.displacementOffset = pushDir * pushMagnitude
    }

    /// Advances the wobble physics by discrete time step.
    public mutating func update(dt: Double) {
        if wobbleTime > 0.0 {
            wobbleTime = max(0.0, wobbleTime - dt)
            if wobbleTime <= 0.0 {
                wobbleStrength = 0.0
                displacementOffset = .zero
            } else {
                // Exponential decay of displacement offset
                let decay = exp(-6.0 * dt)
                displacementOffset = displacementOffset * decay
                wobbleStrength = max(0.0, wobbleStrength - dt / wobbleDuration)
            }
        }
    }

    // MARK: - Generation for Pond Bounds

    /// Generates the standard 16 water lily pads across the 6 shoreline clusters,
    /// matching the CoreGraphics layouts in `PondFloraArtwork`.
    public static func generatePads(for bounds: PondBounds) -> [PondLilyPad] {
        let w = bounds.width
        let h = bounds.height
        let short = min(w, h)
        let scale = short * 1.3

        let clusterAnchors: [(Double, Double)] = [
            (0.035, 0.81), (0.065, 0.08),
            (0.965, 0.94), (0.945, 0.20),
            (0.49, 1.015), (0.57, -0.035)
        ]

        let padOffsets: [[(Double, Double, Double)]] = [
            [(-0.025, 0.15, 0.092), (0.070, 0.005, 0.107), (-0.015, -0.145, 0.079)],
            [(-0.025, 0.11, 0.087), (0.055, -0.020, 0.095), (-0.025, -0.160, 0.067)],
            [(-0.035, 0.135, 0.090), (0.050, -0.025, 0.103), (-0.025, -0.160, 0.066)],
            [(-0.025, 0.14, 0.082), (0.060, -0.015, 0.108), (-0.030, -0.17, 0.075)],
            [(-0.045, 0.005, 0.078), (0.085, 0.040, 0.060)],
            [(-0.055, 0.005, 0.076), (0.070, -0.020, 0.055)]
        ]

        var result: [PondLilyPad] = []
        result.reserveCapacity(16)
        var globalId = 0

        for clusterIdx in 0..<clusterAnchors.count {
            let anchor = clusterAnchors[clusterIdx]
            let anchorX = anchor.0 * w
            let anchorY = anchor.1 * h
            let mirror: Double = (clusterIdx == 2 || clusterIdx == 3) ? -1.0 : 1.0
            let clusterPads = padOffsets[clusterIdx]

            for padIdx in 0..<clusterPads.count {
                let p = clusterPads[padIdx]
                let padCenterX = anchorX + mirror * p.0 * scale
                let padCenterY = anchorY + p.1 * scale
                let padRadius = p.2 * scale
                let hasFlower = (padIdx == 1 && clusterIdx < 4)
                let angle = Double(clusterIdx) * 1.3 + Double(padIdx) * 2.1
                let variant = clusterIdx + padIdx

                let padPos = PondVector(x: padCenterX, y: padCenterY)
                let pad = PondLilyPad(
                    id: globalId,
                    clusterIndex: clusterIdx,
                    padIndex: padIdx,
                    position: padPos,
                    radius: padRadius,
                    angle: angle,
                    variant: variant,
                    hasFlower: hasFlower,
                    flowerPosition: padPos
                )
                result.append(pad)
                globalId += 1
            }
        }
        return result
    }
}
