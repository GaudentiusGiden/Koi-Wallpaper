import Foundation

/// Represents the continuous multi-directional surface water currents and wave field
/// of the pond, adopting the 3-wave system (`waveDirectionA`, `waveDirectionB`, `waveDirectionC`)
/// from Nagomi Desktop `09-water-surface.wgsl` and `water-simulation-spec.json`.
public struct PondWaterCurrent: Sendable {
    // 3 Primary Wave Directions from Nagomi WGSL
    public static let waveDirectionA = PondVector(x: 0.94, y: 0.34)
    public static let waveDirectionB = PondVector(x: -0.38, y: 0.92)
    public static let waveDirectionC = PondVector(x: 0.71, y: 0.71)

    // Wave frequencies (radians / normalized span)
    public static let waveFreqA: Double = 22.0
    public static let waveFreqB: Double = 31.0
    public static let waveFreqC: Double = 59.0

    // Wave speeds (phase advance rate per second)
    public static let waveSpeedA: Double = 0.92
    public static let waveSpeedB: Double = 0.51
    public static let waveSpeedC: Double = -6.38

    // Wave relative strengths
    public static let waveStrengthA: Double = 1.2
    public static let waveStrengthB: Double = 0.55
    public static let waveStrengthC: Double = 0.28

    // Base current distortion amplitude (Nagomi currentDistortion.amplitude = 0.015)
    public static let baseAmplitude: Double = 0.015

    /// Calculates the instantaneous continuous 2D surface water current velocity (in points/second)
    /// at a given pond position and simulation time.
    public static func currentVector(
        at position: PondVector,
        in bounds: PondBounds,
        time: Double
    ) -> PondVector {
        let aspect = max(0.2, bounds.width / max(1.0, bounds.height))
        let centeredX = (position.x / max(1.0, bounds.width) - 0.5) * aspect
        let centeredY = (position.y / max(1.0, bounds.height) - 0.5)

        let phaseA = (centeredX * waveDirectionA.x + centeredY * waveDirectionA.y) * waveFreqA - time * waveSpeedA
        let phaseB = (centeredX * waveDirectionB.x + centeredY * waveDirectionB.y) * waveFreqB - time * waveSpeedB
        let phaseC = (centeredX * waveDirectionC.x + centeredY * waveDirectionC.y) * waveFreqC - time * waveSpeedC

        // Sum of directional wave slopes
        let slopeX = waveDirectionA.x * sin(phaseA) * waveStrengthA
                   + waveDirectionB.x * sin(phaseB) * waveStrengthB
                   + waveDirectionC.x * sin(phaseC) * waveStrengthC
        let slopeY = waveDirectionA.y * sin(phaseA) * waveStrengthA
                   + waveDirectionB.y * sin(phaseB) * waveStrengthB
                   + waveDirectionC.y * sin(phaseC) * waveStrengthC

        // Soft physical water current velocity (~2.5 - 6.0 pt/s)
        let velocityScale = 220.0 * baseAmplitude
        return PondVector(x: slopeX * velocityScale / aspect, y: slopeY * velocityScale)
    }

    /// Calculates the dynamic optical refraction displacement on the pond floor
    /// at a given world position and time, simulating light ray deviation through surface waves.
    public static func refractionDisplacement(
        at position: PondVector,
        in bounds: PondBounds,
        time: Double
    ) -> PondVector {
        let current = currentVector(at: position, in: bounds, time: time)
        // Scaled optical shift for submerged shadows and bottom caustics (~1.5 - 3.5 pt)
        return PondVector(x: current.x * 0.65, y: current.y * 0.65)
    }

    /// Evaluates Fresnel reflectance using Schlick's approximation:
    /// R(theta) = F0 + (1 - F0) * (1 - cos(theta))^5
    public static func fresnelReflectance(cosTheta: Double, f0: Double = 0.02) -> Double {
        let clampedCos = max(0.0, min(1.0, cosTheta))
        let oneMinusCos = 1.0 - clampedCos
        let pow5 = oneMinusCos * oneMinusCos * oneMinusCos * oneMinusCos * oneMinusCos
        return f0 + (1.0 - f0) * pow5
    }

    /// Evaluates the wave crest specular highlight intensity for surface glints
    /// based on surface slope alignment with the directional light.
    public static func specularIntensity(
        at position: PondVector,
        in bounds: PondBounds,
        time: Double,
        lightDirection: (Double, Double)
    ) -> Double {
        let aspect = max(0.2, bounds.width / max(1.0, bounds.height))
        let centeredX = (position.x / max(1.0, bounds.width) - 0.5) * aspect
        let centeredY = (position.y / max(1.0, bounds.height) - 0.5)

        let phaseA = (centeredX * waveDirectionA.x + centeredY * waveDirectionA.y) * waveFreqA - time * waveSpeedA
        let phaseB = (centeredX * waveDirectionB.x + centeredY * waveDirectionB.y) * waveFreqB - time * waveSpeedB

        let waveCrest = max(0.0, cos(phaseA) * 0.60 + cos(phaseB) * 0.40)
        let c2 = waveCrest * waveCrest
        let glintSharpness = c2 * c2 * c2

        // Directional alignment with light vector
        let lightLen = hypot(lightDirection.0, lightDirection.1)
        guard lightLen > 0.001 else { return glintSharpness }
        let normLightX = lightDirection.0 / lightLen
        let normLightY = lightDirection.1 / lightLen

        let dotLight = (centeredX * normLightX + centeredY * normLightY)
        let fresnelAngle = max(0.1, min(1.0, 1.0 - abs(dotLight)))
        let fresnel = fresnelReflectance(cosTheta: fresnelAngle)

        return glintSharpness * (0.35 + 0.65 * fresnel)
    }
}
