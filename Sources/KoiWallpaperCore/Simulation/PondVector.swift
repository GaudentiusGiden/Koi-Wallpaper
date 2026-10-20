import Foundation

/// A 2D vector used for all simulation physics and coordinate calculations.
/// Independent of AppKit to ensure pure simulation testability.
public struct PondVector: Equatable, Sendable, CustomStringConvertible {
    public var x: Double
    public var y: Double

    public static let zero = PondVector(x: 0, y: 0)

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }

    public var description: String {
        String(format: "(%.1f, %.1f)", x, y)
    }

    public var lengthSquared: Double {
        x * x + y * y
    }

    public var length: Double {
        sqrt(lengthSquared)
    }

    public func normalized() -> PondVector {
        let len = length
        guard len > 0.000001 else { return .zero }
        return PondVector(x: x / len, y: y / len)
    }

    public func distance(to other: PondVector) -> Double {
        (self - other).length
    }

    public func distanceSquared(to other: PondVector) -> Double {
        (self - other).lengthSquared
    }

    /// Angle in radians relative to positive X-axis (-pi to pi).
    public var angle: Double {
        atan2(y, x)
    }

    /// Constructs a vector with given angle and magnitude.
    public static func fromAngle(_ angle: Double, length: Double = 1.0) -> PondVector {
        PondVector(x: cos(angle) * length, y: sin(angle) * length)
    }

    public func dot(with other: PondVector) -> Double {
        x * other.x + y * other.y
    }

    public func lerp(to other: PondVector, t: Double) -> PondVector {
        let clampedT = min(max(t, 0.0), 1.0)
        return self + (other - self) * clampedT
    }

    // MARK: - Operators

    public static func + (lhs: PondVector, rhs: PondVector) -> PondVector {
        PondVector(x: lhs.x + rhs.x, y: lhs.y + rhs.y)
    }

    public static func - (lhs: PondVector, rhs: PondVector) -> PondVector {
        PondVector(x: lhs.x - rhs.x, y: lhs.y - rhs.y)
    }

    public static func * (lhs: PondVector, rhs: Double) -> PondVector {
        PondVector(x: lhs.x * rhs, y: lhs.y * rhs)
    }

    public static func * (lhs: Double, rhs: PondVector) -> PondVector {
        PondVector(x: lhs * rhs.x, y: lhs * rhs.y)
    }

    public static func / (lhs: PondVector, rhs: Double) -> PondVector {
        guard abs(rhs) > 0.000001 else { return .zero }
        return PondVector(x: lhs.x / rhs, y: lhs.y / rhs)
    }

    public static func += (lhs: inout PondVector, rhs: PondVector) {
        lhs = lhs + rhs
    }

    public static func -= (lhs: inout PondVector, rhs: PondVector) {
        lhs = lhs - rhs
    }

    public static prefix func - (v: PondVector) -> PondVector {
        PondVector(x: -v.x, y: -v.y)
    }
}

/// Normalizes an angle into the [-pi, pi] interval.
public func normalizeAngle(_ angle: Double) -> Double {
    var a = angle.truncatingRemainder(dividingBy: 2.0 * .pi)
    if a > .pi { a -= 2.0 * .pi }
    if a < -.pi { a += 2.0 * .pi }
    return a
}
