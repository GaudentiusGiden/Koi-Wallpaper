import Foundation

/// Defines the boundary rectangle and edge margins of the pond.
/// Provides soft repulsive steering forces near edges so koi turn naturally
/// before colliding with walls, along with hard clamping guarantees.
public struct PondBounds: Equatable, Sendable {
    public var width: Double
    public var height: Double
    public var margin: Double

    public init(width: Double = 1280.0, height: Double = 800.0, margin: Double = 70.0) {
        self.width = max(100.0, width)
        self.height = max(100.0, height)
        self.margin = max(10.0, margin)
    }

    public var center: PondVector {
        PondVector(x: width * 0.5, y: height * 0.5)
    }

    public func contains(_ point: PondVector, inset: Double = 0.0) -> Bool {
        point.x >= inset && point.x <= (width - inset) && point.y >= inset && point.y <= (height - inset)
    }

    public func clamped(_ point: PondVector, inset: Double = 0.0) -> PondVector {
        PondVector(
            x: min(max(inset, point.x), max(inset, width - inset)),
            y: min(max(inset, point.y), max(inset, height - inset))
        )
    }

    /// Computes a soft inward steering avoidance force if the position is within the edge margin.
    public func boundaryAvoidanceForce(
        for position: PondVector,
        heading: Double,
        strength: Double = 2.0,
        marginOverride: Double? = nil
    ) -> PondVector {
        var force = PondVector.zero
        let effectiveMargin = marginOverride ?? margin

        if position.x < effectiveMargin {
            let penetration = (effectiveMargin - position.x) / effectiveMargin
            force.x += penetration * strength
        } else if position.x > width - effectiveMargin {
            let penetration = (position.x - (width - effectiveMargin)) / effectiveMargin
            force.x -= penetration * strength
        }

        if position.y < effectiveMargin {
            let penetration = (effectiveMargin - position.y) / effectiveMargin
            force.y += penetration * strength
        } else if position.y > height - effectiveMargin {
            let penetration = (position.y - (height - effectiveMargin)) / effectiveMargin
            force.y -= penetration * strength
        }

        return force
    }
}
