import Foundation

/// Represents a temporary point of interest created by user interaction (e.g. water splash click).
/// Fish are attracted towards this target, and smoothly return to wandering when it expires.
public struct ClickTarget: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let position: PondVector
    public let duration: Double
    public var remainingDuration: Double

    public init(id: UUID = UUID(), position: PondVector, duration: Double = 5.0) {
        self.id = id
        self.position = position
        self.duration = duration
        self.remainingDuration = duration
    }

    public var isExpired: Bool {
        remainingDuration <= 0.0
    }

    public mutating func update(dt: Double) {
        remainingDuration -= dt
    }
}
