import Foundation

/// 48-slot time-of-day histogram (30-minute intervals) recording feeding habit schedules.
/// Handles midnight wraparound via circular distance; decays with a 7-day half-life.
public struct FeedingTimeHistogram: Codable, Equatable, Sendable {
    public static let schemaVersion: Int = 1
    public static let totalSlots: Int = 48
    public static let halfLifeSeconds: Double = 7.0 * 86400.0 // 7 days (604,800s)
    public static let sessionMergeWindow: TimeInterval = 90.0 // 90 seconds
    public static let confidenceThreshold: Double = 3.0 // At least 3 sessions of accumulated weight

    public var version: Int
    public var slots: [Double]
    public var lastDecayTimestamp: Date
    public var lastSessionTimestamp: Date?
    public var lastSessionSlot: Int?
    public var sessionCount: Int

    public init(
        version: Int = FeedingTimeHistogram.schemaVersion,
        slots: [Double]? = nil,
        lastDecayTimestamp: Date = Date(),
        lastSessionTimestamp: Date? = nil,
        lastSessionSlot: Int? = nil,
        sessionCount: Int = 0
    ) {
        self.version = version == Self.schemaVersion ? version : Self.schemaVersion
        if let s = slots, s.count == Self.totalSlots {
            var allValid = true
            for val in s {
                if !val.isFinite || val.isNaN || val < 0.0 {
                    allValid = false
                    break
                }
            }
            self.slots = allValid ? s : Array(repeating: 0.0, count: Self.totalSlots)
        } else {
            self.slots = Array(repeating: 0.0, count: Self.totalSlots)
        }
        self.lastDecayTimestamp = lastDecayTimestamp
        self.lastSessionTimestamp = lastSessionTimestamp
        if let slot = lastSessionSlot, slot >= 0 && slot < Self.totalSlots {
            self.lastSessionSlot = slot
        } else {
            self.lastSessionSlot = nil
        }
        self.sessionCount = max(0, sessionCount)
    }

    private enum CodingKeys: String, CodingKey {
        case version
        case slots
        case lastDecayTimestamp
        case lastSessionTimestamp
        case lastSessionSlot
        case sessionCount
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let v = try container.decode(Int.self, forKey: .version)
        guard v == Self.schemaVersion else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: container.codingPath + [CodingKeys.version],
                    debugDescription: "Unsupported FeedingTimeHistogram schema version: \(v), expected \(Self.schemaVersion)"
                )
            )
        }
        self.version = v

        let s = try container.decode([Double].self, forKey: .slots)
        guard s.count == Self.totalSlots else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: container.codingPath + [CodingKeys.slots],
                    debugDescription: "Invalid FeedingTimeHistogram slots count: \(s.count), expected \(Self.totalSlots)"
                )
            )
        }
        for (i, val) in s.enumerated() {
            guard val.isFinite && !val.isNaN && val >= 0.0 else {
                throw DecodingError.dataCorrupted(
                    DecodingError.Context(
                        codingPath: container.codingPath + [CodingKeys.slots],
                        debugDescription: "Invalid slot weight at index \(i): \(val)"
                    )
                )
            }
        }
        self.slots = s

        self.lastDecayTimestamp = try container.decode(Date.self, forKey: .lastDecayTimestamp)
        self.lastSessionTimestamp = try container.decodeIfPresent(Date.self, forKey: .lastSessionTimestamp)

        if let slotIdx = try container.decodeIfPresent(Int.self, forKey: .lastSessionSlot) {
            guard slotIdx >= 0 && slotIdx < Self.totalSlots else {
                throw DecodingError.dataCorrupted(
                    DecodingError.Context(
                        codingPath: container.codingPath + [CodingKeys.lastSessionSlot],
                        debugDescription: "lastSessionSlot out of bounds: \(slotIdx), totalSlots: \(Self.totalSlots)"
                    )
                )
            }
            self.lastSessionSlot = slotIdx
        } else {
            self.lastSessionSlot = nil
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
        try container.encode(slots, forKey: .slots)
        try container.encode(lastDecayTimestamp, forKey: .lastDecayTimestamp)
        try container.encodeIfPresent(lastSessionTimestamp, forKey: .lastSessionTimestamp)
        try container.encodeIfPresent(lastSessionSlot, forKey: .lastSessionSlot)
        try container.encode(sessionCount, forKey: .sessionCount)
    }

    /// Converts a local date into a 0..<48 time slot (30-minute buckets).
    public static func slot(for date: Date, calendar: Calendar = .current) -> Int {
        let hour = calendar.component(.hour, from: date)
        let minute = calendar.component(.minute, from: date)
        let slot = hour * 2 + (minute >= 30 ? 1 : 0)
        return min(totalSlots - 1, max(0, slot))
    }

    /// Calculates circular shortest distance between two 48-slot indices, correctly wrapping midnight.
    /// Slot 47 (23:30) and slot 0 (00:00) have circular distance 1.
    public static func circularDistance(slot1: Int, slot2: Int) -> Int {
        let diff = abs(slot1 - slot2)
        return min(diff, totalSlots - diff)
    }

    /// Lazily applies exponential decay with a 7-day half-life.
    public mutating func applyDecay(at date: Date = Date()) {
        let elapsed = date.timeIntervalSince(lastDecayTimestamp)
        guard elapsed > 0 else { return }
        let decayFactor = pow(0.5, elapsed / Self.halfLifeSeconds)
        for i in 0..<slots.count {
            slots[i] *= decayFactor
        }
        lastDecayTimestamp = date
    }

    /// Records a feeding event at the given local date.
    /// Merges events occurring within a 90-second window into the same session.
    @discardableResult
    public mutating func recordFeeding(
        at date: Date = Date(),
        calendar: Calendar = .current,
        weightIncrement: Double = 1.0
    ) -> Bool {
        applyDecay(at: date)
        let currentSlot = Self.slot(for: date, calendar: calendar)

        if let lastTime = lastSessionTimestamp,
           let lastSlot = lastSessionSlot,
           date.timeIntervalSince(lastTime) <= Self.sessionMergeWindow {
            if Self.circularDistance(slot1: currentSlot, slot2: lastSlot) <= 1 {
                // Merged into current session: diminishing return prevents click spamming
                slots[currentSlot] += weightIncrement * 0.05
                lastSessionTimestamp = date
                return false
            }
        }

        slots[currentSlot] += weightIncrement
        lastSessionTimestamp = date
        lastSessionSlot = currentSlot
        sessionCount += 1
        return true
    }

    public func weight(slot: Int) -> Double {
        guard slot >= 0 && slot < Self.totalSlots else { return 0.0 }
        return slots[slot]
    }

    public func hasConfidence(slot: Int) -> Bool {
        weight(slot: slot) >= Self.confidenceThreshold
    }

    /// Checks if a given time slot matches any confident habitual feeding slot within circular tolerance.
    public func isHabitualTime(slot: Int, toleranceSlots: Int = 1) -> Bool {
        for s in 0..<Self.totalSlots {
            if hasConfidence(slot: s) && Self.circularDistance(slot1: slot, slot2: s) <= toleranceSlots {
                return true
            }
        }
        return false
    }

    /// Returns the slot with the highest accumulated weight.
    public var preferredSlot: (slot: Int, weight: Double)? {
        guard let maxElement = slots.enumerated().max(by: { $0.element < $1.element }),
              maxElement.element > 0.0 else {
            return nil
        }
        return (maxElement.offset, maxElement.element)
    }
}
