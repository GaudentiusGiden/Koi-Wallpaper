import Foundation

/// Fast, reproducible, 64-bit pseudo-random number generator using the SplitMix64 algorithm.
/// Implements Swift's standard `RandomNumberGenerator` protocol for deterministic simulation.
public struct SeededRandomNumberGenerator: RandomNumberGenerator, Sendable {
    public private(set) var state: UInt64

    public init(seed: UInt64) {
        self.state = (seed == 0) ? 0x853c49e6748fea9b : seed
    }

    public mutating func next() -> UInt64 {
        state &+= 0x9e3779b97f4a7c15
        var z = state
        z = (z ^ (z >> 30)) &* 0xbf58476d1ce4e5b9
        z = (z ^ (z >> 27)) &* 0x94d049bb133111eb
        return z ^ (z >> 31)
    }
}
