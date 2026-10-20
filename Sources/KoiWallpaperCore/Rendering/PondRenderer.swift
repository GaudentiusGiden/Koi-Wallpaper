import CoreGraphics
import Foundation

/// Coordinates the complete layered visual rendering of the pond simulation onto a CGContext.
public final class PondRenderer {

    public init() {}

    /// Renders all pond simulation layers in accurate visual depth order.
    /// - Parameters:
    ///   - simulation: The current PondSimulation state.
    ///   - context: The CoreGraphics context to draw into.
    ///   - rect: The viewport bounds.
    ///   - phase: The current TimeOfDayPhase affecting lighting and caustics.
    public func render(
        simulation: PondSimulation,
        in context: CGContext,
        rect: CGRect,
        phase: TimeOfDayPhase = .day
    ) {
        // Layer 1: Water Bed, Ambient Depth Gradient, and Underwater Caustics
        PondArtwork.drawWater(in: context, rect: rect, phase: phase)

        // Layer 2: Fish Drop Shadows onto Pond Bed (Depth illusion)
        for fish in simulation.fish {
            KoiArtwork.draw(fish, in: context, drawShadowOnly: true)
        }

        // Layer 3: Koi Fish Bodies, Fins, Distinct Patterns, and Eyes
        for fish in simulation.fish {
            KoiArtwork.draw(fish, in: context, drawShadowOnly: false)
        }

        // Layer 4: Floating Food Pellets
        PondArtwork.drawPellets(simulation.pellets, in: context)

        // Layer 5: Expanding Water Surface Ripples
        PondArtwork.drawRipples(simulation.ripples, in: context)

        // Layer 6: Floating Lily Pads and Lotus Flowers
        PondArtwork.drawLilyPads(in: context, bounds: simulation.bounds)

        // Layer 7: Time of Day Atmospheric Lighting
        PondArtwork.drawAtmosphere(in: context, rect: rect, phase: phase)
    }
}
