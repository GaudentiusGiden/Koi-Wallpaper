import Foundation

/// 12 x 8 spatial grid recording feeding location habits in normalized pond coordinates.
/// Survives pond resize proportionally; decays with a 7-day half-life.
public struct FeedingMemoryGrid: Codable, Equatable, Sendable {
    public static let schemaVersion: Int = 1
    public static let columns: Int = 12
    public static let rows: Int = 8
    public static let totalCells: Int = 12 * 8 // 96
    public static let halfLifeSeconds: Double = 7.0 * 86400.0 // 7 days (604,800s)
    public static let sessionMergeWindow: TimeInterval = 90.0 // 90 seconds
    public static let confidenceThreshold: Double = 3.0 // At least 3 sessions of accumulated weight

    public var version: Int
    public var weights: [Double]
    public var lastDecayTimestamp: Date
    public var lastSessionTimestamp: Date?
    public var lastSessionCellIndex: Int?
    public var sessionCount: Int

    public init(
        version: Int = FeedingMemoryGrid.schemaVersion,
        weights: [Double]? = nil,
        lastDecayTimestamp: Date = Date(),
        lastSessionTimestamp: Date? = nil,
        lastSessionCellIndex: Int? = nil,
        sessionCount: Int = 0
    ) {
        self.version = version == Self.schemaVersion ? version : Self.schemaVersion
        if let w = weights, w.count == Self.totalCells {
            var allValid = true
            for val in w {
                if !val.isFinite || val.isNaN || val < 0.0 {
                    allValid = false
                    break
                }
            }
            self.weights = allValid ? w : Array(repeating: 0.0, count: Self.totalCells)
        } else {
            self.weights = Array(repeating: 0.0, count: Self.totalCells)
        }
        self.lastDecayTimestamp = lastDecayTimestamp
        self.lastSessionTimestamp = lastSessionTimestamp
        if let idx = lastSessionCellIndex, idx >= 0 && idx < Self.totalCells {
            self.lastSessionCellIndex = idx
        } else {
            self.lastSessionCellIndex = nil
        }
        self.sessionCount = max(0, sessionCount)
    }

    private enum CodingKeys: String, CodingKey {
        case version
        case weights
        case lastDecayTimestamp
        case lastSessionTimestamp
        case lastSessionCellIndex
        case sessionCount
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let v = try container.decode(Int.self, forKey: .version)
        guard v == Self.schemaVersion else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: container.codingPath + [CodingKeys.version],
                    debugDescription: "Unsupported FeedingMemoryGrid schema version: \(v), expected \(Self.schemaVersion)"
                )
            )
        }
        self.version = v

        let w = try container.decode([Double].self, forKey: .weights)
        guard w.count == Self.totalCells else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: container.codingPath + [CodingKeys.weights],
                    debugDescription: "Invalid FeedingMemoryGrid weights count: \(w.count), expected \(Self.totalCells)"
                )
            )
        }
        for (i, val) in w.enumerated() {
            guard val.isFinite && !val.isNaN && val >= 0.0 else {
                throw DecodingError.dataCorrupted(
                    DecodingError.Context(
                        codingPath: container.codingPath + [CodingKeys.weights],
                        debugDescription: "Invalid weight at index \(i): \(val)"
                    )
                )
            }
        }
        self.weights = w

        self.lastDecayTimestamp = try container.decode(Date.self, forKey: .lastDecayTimestamp)
        self.lastSessionTimestamp = try container.decodeIfPresent(Date.self, forKey: .lastSessionTimestamp)

        if let idx = try container.decodeIfPresent(Int.self, forKey: .lastSessionCellIndex) {
            guard idx >= 0 && idx < Self.totalCells else {
                throw DecodingError.dataCorrupted(
                    DecodingError.Context(
                        codingPath: container.codingPath + [CodingKeys.lastSessionCellIndex],
                        debugDescription: "lastSessionCellIndex out of bounds: \(idx), totalCells: \(Self.totalCells)"
                    )
                )
            }
            self.lastSessionCellIndex = idx
        } else {
            self.lastSessionCellIndex = nil
        }

        let sc = try container.decode(Int.self, forKey: .sessionCount)
        guard sc >= 0 else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: container.codingPath + [CodingKeys.sessionCount],
                    debugDescription: "sessionCount cannot be negative: \(sc)"
                )
            )
        }
        self.sessionCount = sc
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(version, forKey: .version)
        try container.encode(weights, forKey: .weights)
        try container.encode(lastDecayTimestamp, forKey: .lastDecayTimestamp)
        try container.encodeIfPresent(lastSessionTimestamp, forKey: .lastSessionTimestamp)
        try container.encodeIfPresent(lastSessionCellIndex, forKey: .lastSessionCellIndex)
        try container.encode(sessionCount, forKey: .sessionCount)
    }

    public static func cellIndex(col: Int, row: Int) -> Int {
        min(totalCells - 1, max(0, row * columns + col))
    }

    public static func cellCoordinates(index: Int) -> (col: Int, row: Int) {
        let clamped = min(totalCells - 1, max(0, index))
        return (clamped % columns, clamped / columns)
    }

    /// Converts normalized pond coordinates (u: 0..1, v: 0..1) to grid cell (col, row).
    public static func cellForNormalized(u: Double, v: Double) -> (col: Int, row: Int) {
        let clampedU = min(0.999999, max(0.0, u))
        let clampedV = min(0.999999, max(0.0, v))
        let col = min(columns - 1, max(0, Int(clampedU * Double(columns))))
        let row = min(rows - 1, max(0, Int(clampedV * Double(rows))))
        return (col, row)
    }

    /// Returns normalized center coordinates (0..1, 0..1) of a grid cell.
    public static func normalizedCenter(col: Int, row: Int) -> PondVector {
        let u = (Double(min(columns - 1, max(0, col))) + 0.5) / Double(columns)
        let v = (Double(min(rows - 1, max(0, row))) + 0.5) / Double(rows)
        return PondVector(x: u, y: v)
    }

    /// Converts normalized grid location to world coordinates for the given pond bounds.
    /// Strictly proportional to pond dimensions regardless of aspect ratio or resolution.
    public static func worldCenter(col: Int, row: Int, bounds: PondBounds) -> PondVector {
        let norm = normalizedCenter(col: col, row: row)
        return PondVector(x: norm.x * bounds.width, y: norm.y * bounds.height)
    }

    /// Lazily applies exponential decay with a 7-day half-life.
    public mutating func applyDecay(at date: Date = Date()) {
        let elapsed = date.timeIntervalSince(lastDecayTimestamp)
        guard elapsed > 0 else { return }
        let decayFactor = pow(0.5, elapsed / Self.halfLifeSeconds)
        for i in 0..<weights.count {
            weights[i] *= decayFactor
        }
        lastDecayTimestamp = date
    }

    /// Records a feeding event at normalized coordinates (u, v).
    /// Merges nearby events within a 90-second window into the same session.
    /// Returns true if a new distinct session was initiated.
    @discardableResult
    public mutating func recordFeeding(
        normalizedPoint: PondVector,
        at date: Date = Date(),
        weightIncrement: Double = 1.0
    ) -> Bool {
        applyDecay(at: date)

        let (col, row) = Self.cellForNormalized(u: normalizedPoint.x, v: normalizedPoint.y)
        let idx = Self.cellIndex(col: col, row: row)

        // Session merging: if within 90 seconds and nearby cell
        if let lastTime = lastSessionTimestamp,
           let lastIdx = lastSessionCellIndex,
           date.timeIntervalSince(lastTime) <= Self.sessionMergeWindow {
            let (lastCol, lastRow) = Self.cellCoordinates(index: lastIdx)
            let isNearby = abs(col - lastCol) <= 1 && abs(row - lastRow) <= 1
            if isNearby {
                // Merged into current session: diminishing return prevents spam reinforcement
                let diminishingFactor = 0.05
                weights[idx] += weightIncrement * diminishingFactor
                lastSessionTimestamp = date
                return false
            }
        }

        // New distinct session
        weights[idx] += weightIncrement
        lastSessionTimestamp = date
        lastSessionCellIndex = idx
        sessionCount += 1
        return true
    }

    /// Returns the accumulated, decayed weight of the cell.
    public func weight(col: Int, row: Int) -> Double {
        let idx = Self.cellIndex(col: col, row: row)
        return weights[idx]
    }

    /// Returns true if the cell has reached confident habit status (accumulated weight >= 3.0 sessions).
    public func hasConfidence(col: Int, row: Int) -> Bool {
        weight(col: col, row: row) >= Self.confidenceThreshold
    }

    /// Returns the highest-weighted cell if any feeding has occurred.
    public var preferredCell: (col: Int, row: Int, weight: Double)? {
        guard let maxElement = weights.enumerated().max(by: { $0.element < $1.element }),
              maxElement.element > 0.0 else {
            return nil
        }
        let (col, row) = Self.cellCoordinates(index: maxElement.offset)
        return (col, row, maxElement.element)
    }
}
