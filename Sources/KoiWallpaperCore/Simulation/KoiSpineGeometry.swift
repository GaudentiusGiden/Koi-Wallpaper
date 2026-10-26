import Foundation

/// Represents a single tapered capsule along the articulated koi spine.
/// Defined as the 2D convex hull of two disks: Disk(start, startRadius) and Disk(end, endRadius).
public struct KoiBodyCapsule: Sendable, Equatable {
    public let start: PondVector
    public let end: PondVector
    public let startRadius: Double
    public let endRadius: Double

    public init(start: PondVector, end: PondVector, startRadius: Double, endRadius: Double) {
        self.start = start
        self.end = end
        self.startRadius = max(0.0, startRadius)
        self.endRadius = max(0.0, endRadius)
    }

    /// Centerline point at parameter t in [0, 1].
    public func point(at t: Double) -> PondVector {
        start + (end - start) * min(max(t, 0.0), 1.0)
    }

    /// Interpolated radius at normalized parameter t in [0, 1].
    public func radius(at t: Double) -> Double {
        let clampedT = min(max(t, 0.0), 1.0)
        return (1.0 - clampedT) * startRadius + clampedT * endRadius
    }

    public var maxRadius: Double {
        max(startRadius, endRadius)
    }
}

/// Detailed result of geometric body-to-body collision testing between two koi.
public struct FishBodyCollision: Sendable {
    public let hasOverlap: Bool
    public let maxOverlap: Double // > 0 indicates penetration depth; <= 0 indicates clearance
    public let normal: PondVector // Collision normal pointing from fish2 to fish1
    public let contactPoint1: PondVector
    public let contactPoint2: PondVector

    public init(
        hasOverlap: Bool,
        maxOverlap: Double,
        normal: PondVector,
        contactPoint1: PondVector,
        contactPoint2: PondVector
    ) {
        self.hasOverlap = hasOverlap
        self.maxOverlap = maxOverlap
        self.normal = normal
        self.contactPoint1 = contactPoint1
        self.contactPoint2 = contactPoint2
    }
}

/// Robust geometric algorithms for articulated koi body representation,
/// exact point-to-tapered-capsule signed distance, and multi-capsule collision checking.
public enum KoiSpineGeometry {

    /// Computes the exact signed distance and outward normal from a 2D point P to a tapered capsule.
    /// Returns:
    /// - `signedDistance`: > 0 if P is outside, < 0 if P is inside (penetration).
    /// - `closestPointOnSurface`: The closest point on the capsule outer boundary.
    /// - `outwardNormal`: Unit vector pointing from the capsule surface towards P.
    public static func pointToCapsuleDistance(
        point P: PondVector,
        capsule C: KoiBodyCapsule
    ) -> (signedDistance: Double, closestPointOnSurface: PondVector, outwardNormal: PondVector) {
        let u = C.end - C.start
        let L = u.length

        if L < 1e-6 {
            // Degenerate capsule: single disk at start
            let rad = max(C.startRadius, C.endRadius)
            let diff = P - C.start
            let dist = diff.length
            let normal = dist > 1e-6 ? diff / dist : PondVector(x: 1.0, y: 0.0)
            let surfacePt = C.start + normal * rad
            return (dist - rad, surfacePt, normal)
        }

        let uNorm = u / L
        let nNorm = PondVector(x: -uNorm.y, y: uNorm.x)

        let rel = P - C.start
        let x = rel.dot(with: uNorm)
        let y = rel.dot(with: nNorm)
        let absY = abs(y)
        let ySign = y >= 0.0 ? 1.0 : -1.0

        let rA = C.startRadius
        let rB = C.endRadius
        let dr = rB - rA

        // If one disk completely subsumes the other
        if abs(dr) >= L - 1e-6 {
            let center = dr > 0 ? C.end : C.start
            let rad = max(rA, rB)
            let diff = P - center
            let dist = diff.length
            let normal = dist > 1e-6 ? diff / dist : PondVector(x: 1.0, y: 0.0)
            let surfacePt = center + normal * rad
            return (dist - rad, surfacePt, normal)
        }

        let sinAlpha = dr / L
        let cosAlpha = sqrt(max(0.0, 1.0 - sinAlpha * sinAlpha))

        // Contact points on Disk A and Disk B in local coordinates
        let xA = -rA * sinAlpha
        let yA = rA * cosAlpha
        let xB = L - rB * sinAlpha
        let yB = rB * cosAlpha

        let tx = xB - xA
        let ty = yB - yA
        let tLen = sqrt(tx * tx + ty * ty)

        let dotTangent = (x - xA) * (tx / tLen) + (absY - yA) * (ty / tLen)

        if dotTangent <= 0.0 {
            // Closest feature is Disk A
            let dist = sqrt(x * x + y * y)
            let normal = dist > 1e-6 ? (P - C.start) / dist : (nNorm * ySign)
            let surfacePt = C.start + normal * rA
            return (dist - rA, surfacePt, normal)
        } else if dotTangent >= tLen {
            // Closest feature is Disk B
            let dx = x - L
            let dist = sqrt(dx * dx + y * y)
            let normal = dist > 1e-6 ? (P - C.end) / dist : (nNorm * ySign)
            let surfacePt = C.end + normal * rB
            return (dist - rB, surfacePt, normal)
        } else {
            // Closest feature is the tangent line
            let normalLocal = PondVector(x: -sinAlpha, y: cosAlpha * ySign)
            let normalWorld = uNorm * normalLocal.x + nNorm * normalLocal.y
            let signedDist = -x * sinAlpha + absY * cosAlpha - rA * cosAlpha
            let surfacePt = P - normalWorld * signedDist
            return (signedDist, surfacePt, normalWorld)
        }
    }

    /// Computes the shortest distance between two 2D line segments P1-Q1 and P2-Q2.
    public static func segmentSegmentDistance(
        p1: PondVector, q1: PondVector,
        p2: PondVector, q2: PondVector
    ) -> (distance: Double, s: Double, t: Double, closest1: PondVector, closest2: PondVector) {
        let u = q1 - p1
        let v = q2 - p2
        let w0 = p1 - p2

        let a = u.lengthSquared
        let b = u.dot(with: v)
        let c = v.lengthSquared
        let d = u.dot(with: w0)
        let e = v.dot(with: w0)

        let eps = 1e-9
        var s: Double = 0.0
        var t: Double = 0.0

        if a < eps && c < eps {
            s = 0.0
            t = 0.0
        } else if a < eps {
            s = 0.0
            t = min(max(e / c, 0.0), 1.0)
        } else if c < eps {
            t = 0.0
            s = min(max(-d / a, 0.0), 1.0)
        } else {
            let denom = a * c - b * b
            if denom > eps {
                s = min(max((b * e - c * d) / denom, 0.0), 1.0)
            } else {
                s = 0.0
            }
            t = (b * s + e) / c
            if t < 0.0 {
                t = 0.0
                s = min(max(-d / a, 0.0), 1.0)
            } else if t > 1.0 {
                t = 1.0
                s = min(max((b - d) / a, 0.0), 1.0)
            }
        }

        let closest1 = p1 + u * s
        let closest2 = p2 + v * t
        let dist = closest1.distance(to: closest2)
        return (dist, s, t, closest1, closest2)
    }

    /// Tests collision between two tapered capsules over all boundary features and sample points.
    /// Returns the maximum overlap (positive if intersecting) and contact normal pointing from C2 to C1.
    public static func testCapsulePairCollision(
        _ c1: KoiBodyCapsule,
        _ c2: KoiBodyCapsule,
        safetyMargin: Double = 0.0
    ) -> (overlap: Double, normal: PondVector, pt1: PondVector, pt2: PondVector) {
        var worstOverlap = -Double.infinity
        var worstNormal = PondVector(x: 1.0, y: 0.0)
        var worstPt1 = c1.start
        var worstPt2 = c2.start

        // Fast-path bounding check for the capsule pair
        let mid1 = (c1.start + c1.end) * 0.5
        let halfLen1 = (c1.start - c1.end).length * 0.5 + c1.maxRadius + safetyMargin
        let mid2 = (c2.start + c2.end) * 0.5
        let halfLen2 = (c2.start - c2.end).length * 0.5 + c2.maxRadius
        let diff = mid1 - mid2
        let maxReach = halfLen1 + halfLen2
        if diff.lengthSquared > maxReach * maxReach {
            return (-Double.infinity, worstNormal, worstPt1, worstPt2)
        }

        // 1. Test Disk endpoints and intermediate samples of C1 against C2 without heap allocations
        for step in 0...4 {
            let s = Double(step) * 0.25
            let pt1 = c1.point(at: s)
            let rad1 = c1.radius(at: s)
            let (distToC2, pt2OnC2, normFromC2) = pointToCapsuleDistance(point: pt1, capsule: c2)
            let overlap = (rad1 + safetyMargin) - distToC2
            if overlap > worstOverlap {
                worstOverlap = overlap
                worstNormal = normFromC2
                worstPt1 = pt1
                worstPt2 = pt2OnC2
            }
        }

        // 2. Test Disk endpoints and intermediate samples of C2 against C1 without heap allocations
        for step in 0...4 {
            let t = Double(step) * 0.25
            let pt2 = c2.point(at: t)
            let rad2 = c2.radius(at: t)
            let (distToC1, pt1OnC1, normFromC1) = pointToCapsuleDistance(point: pt2, capsule: c1)
            let overlap = (rad2 + safetyMargin) - distToC1
            if overlap > worstOverlap {
                worstOverlap = overlap
                worstNormal = -normFromC1 // Normal must point from C2 to C1
                worstPt1 = pt1OnC1
                worstPt2 = pt2
            }
        }

        // 3. Centerline closest points check
        let (centerDist, sCenter, tCenter, cPt1, cPt2) = segmentSegmentDistance(
            p1: c1.start, q1: c1.end,
            p2: c2.start, q2: c2.end
        )
        let r1 = c1.radius(at: sCenter)
        let r2 = c2.radius(at: tCenter)
        let centerOverlap = (r1 + r2 + safetyMargin) - centerDist
        if centerOverlap > worstOverlap {
            worstOverlap = centerOverlap
            worstNormal = centerDist > 1e-4 ? (cPt1 - cPt2) / centerDist : worstNormal
            worstPt1 = cPt1
            worstPt2 = cPt2
        }

        return (worstOverlap, worstNormal, worstPt1, worstPt2)
    }

    /// Evaluates multi-capsule collision between pre-computed capsules.
    public static func testBodyCollision(
        capsules1: [KoiBodyCapsule],
        capsules2: [KoiBodyCapsule],
        fish1Position: PondVector,
        fish2Position: PondVector,
        safetyMargin: Double = 0.0
    ) -> FishBodyCollision {
        var worstOverlap = -Double.infinity
        var worstNormal = PondVector(x: 1.0, y: 0.0)
        var worstPt1 = fish1Position
        var worstPt2 = fish2Position

        for cap1 in capsules1 {
            for cap2 in capsules2 {
                let (overlap, normal, pt1, pt2) = testCapsulePairCollision(
                    cap1, cap2,
                    safetyMargin: safetyMargin
                )
                if overlap > worstOverlap {
                    worstOverlap = overlap
                    worstNormal = normal
                    worstPt1 = pt1
                    worstPt2 = pt2
                }
            }
        }

        return FishBodyCollision(
            hasOverlap: worstOverlap > 0.0,
            maxOverlap: worstOverlap,
            normal: worstNormal,
            contactPoint1: worstPt1,
            contactPoint2: worstPt2
        )
    }

    /// Evaluates multi-capsule collision between two koi fish.
    /// Tests all 5x5 capsule pairs using the exact point-to-capsule surface distance algorithm.
    public static func testBodyCollision(
        fish1: KoiFish,
        fish2: KoiFish,
        safetyMargin: Double = 0.0
    ) -> FishBodyCollision {
        testBodyCollision(
            capsules1: fish1.bodyCapsules,
            capsules2: fish2.bodyCapsules,
            fish1Position: fish1.position,
            fish2Position: fish2.position,
            safetyMargin: safetyMargin
        )
    }

    /// Checks if any part of the articulated capsule proxy of fish1 penetrates that of fish2.
    public static func checkBodyIntersection(fish1: KoiFish, fish2: KoiFish) -> Bool {
        testBodyCollision(fish1: fish1, fish2: fish2, safetyMargin: 0.0).hasOverlap
    }
}
