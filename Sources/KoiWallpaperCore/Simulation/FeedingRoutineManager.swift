import Foundation
import OSLog

private let logger = Logger(subsystem: "com.koiwallpaper.KoiWallpaper", category: "FeedingRoutine")

/// Storage abstraction for separated, versioned feeding memory grid and time histogram.
public protocol FeedingStore: Sendable {
    func loadGrid() -> FeedingMemoryGrid?
    func saveGrid(_ grid: FeedingMemoryGrid)
    func loadHistogram() -> FeedingTimeHistogram?
    func saveHistogram(_ histogram: FeedingTimeHistogram)
    func reset()
}

/// Persistent store using macOS standard UserDefaults with separate keys and versioning.
public final class UserDefaultsFeedingStore: FeedingStore, @unchecked Sendable {
    private let userDefaults: UserDefaults
    private let gridKey: String
    private let histogramKey: String

    public init(
        userDefaults: UserDefaults = .standard,
        gridKey: String = "com.koiwallpaper.memory.grid.v1",
        histogramKey: String = "com.koiwallpaper.memory.time.v1"
    ) {
        self.userDefaults = userDefaults
        self.gridKey = gridKey
        self.histogramKey = histogramKey
    }

    public func loadGrid() -> FeedingMemoryGrid? {
        guard let data = userDefaults.data(forKey: gridKey) else { return nil }
        do {
            let decoder = JSONDecoder()
            decoder.nonConformingFloatDecodingStrategy = .convertFromString(
                positiveInfinity: "+Infinity",
                negativeInfinity: "-Infinity",
                nan: "NaN"
            )
            return try decoder.decode(FeedingMemoryGrid.self, from: data)
        } catch {
            logger.warning("Corrupted FeedingMemoryGrid data encountered; falling back to clean default: \(error.localizedDescription)")
            return nil
        }
    }

    public func saveGrid(_ grid: FeedingMemoryGrid) {
        do {
            let encoder = JSONEncoder()
            encoder.nonConformingFloatEncodingStrategy = .convertToString(
                positiveInfinity: "+Infinity",
                negativeInfinity: "-Infinity",
                nan: "NaN"
            )
            let data = try encoder.encode(grid)
            userDefaults.set(data, forKey: gridKey)
        } catch {
            logger.error("Failed to encode FeedingMemoryGrid: \(error.localizedDescription)")
        }
    }

    public func loadHistogram() -> FeedingTimeHistogram? {
        guard let data = userDefaults.data(forKey: histogramKey) else { return nil }
        do {
            let decoder = JSONDecoder()
            decoder.nonConformingFloatDecodingStrategy = .convertFromString(
                positiveInfinity: "+Infinity",
                negativeInfinity: "-Infinity",
                nan: "NaN"
            )
            return try decoder.decode(FeedingTimeHistogram.self, from: data)
        } catch {
            logger.warning("Corrupted FeedingTimeHistogram data encountered; falling back to clean default: \(error.localizedDescription)")
            return nil
        }
    }

    public func saveHistogram(_ histogram: FeedingTimeHistogram) {
        do {
            let encoder = JSONEncoder()
            encoder.nonConformingFloatEncodingStrategy = .convertToString(
                positiveInfinity: "+Infinity",
                negativeInfinity: "-Infinity",
                nan: "NaN"
            )
            let data = try encoder.encode(histogram)
            userDefaults.set(data, forKey: histogramKey)
        } catch {
            logger.error("Failed to encode FeedingTimeHistogram: \(error.localizedDescription)")
        }
    }

    public func reset() {
        userDefaults.removeObject(forKey: gridKey)
        userDefaults.removeObject(forKey: histogramKey)
    }
}

/// In-memory store for isolated deterministic testing and preview execution.
public final class InMemoryFeedingStore: FeedingStore, @unchecked Sendable {
    private let lock = NSLock()
    private var gridData: Data?
    private var histogramData: Data?

    public init(gridData: Data? = nil, histogramData: Data? = nil) {
        self.gridData = gridData
        self.histogramData = histogramData
    }

    public func loadGrid() -> FeedingMemoryGrid? {
        lock.lock()
        defer { lock.unlock() }
        guard let data = gridData else { return nil }
        do {
            let decoder = JSONDecoder()
            decoder.nonConformingFloatDecodingStrategy = .convertFromString(
                positiveInfinity: "+Infinity",
                negativeInfinity: "-Infinity",
                nan: "NaN"
            )
            return try decoder.decode(FeedingMemoryGrid.self, from: data)
        } catch {
            logger.warning("InMemoryFeedingStore: corrupted grid data; returning nil.")
            return nil
        }
    }

    public func saveGrid(_ grid: FeedingMemoryGrid) {
        lock.lock()
        defer { lock.unlock() }
        let encoder = JSONEncoder()
        encoder.nonConformingFloatEncodingStrategy = .convertToString(
            positiveInfinity: "+Infinity",
            negativeInfinity: "-Infinity",
            nan: "NaN"
        )
        gridData = try? encoder.encode(grid)
    }

    public func loadHistogram() -> FeedingTimeHistogram? {
        lock.lock()
        defer { lock.unlock() }
        guard let data = histogramData else { return nil }
        do {
            let decoder = JSONDecoder()
            decoder.nonConformingFloatDecodingStrategy = .convertFromString(
                positiveInfinity: "+Infinity",
                negativeInfinity: "-Infinity",
                nan: "NaN"
            )
            return try decoder.decode(FeedingTimeHistogram.self, from: data)
        } catch {
            logger.warning("InMemoryFeedingStore: corrupted histogram data; returning nil.")
            return nil
        }
    }

    public func saveHistogram(_ histogram: FeedingTimeHistogram) {
        lock.lock()
        defer { lock.unlock() }
        let encoder = JSONEncoder()
        encoder.nonConformingFloatEncodingStrategy = .convertToString(
            positiveInfinity: "+Infinity",
            negativeInfinity: "-Infinity",
            nan: "NaN"
        )
        histogramData = try? encoder.encode(histogram)
    }

    public func reset() {
        lock.lock()
        defer { lock.unlock() }
        gridData = nil
        histogramData = nil
    }
}

/// Coordinates spatial feeding memory (12x8 grid) and temporal habits (48-slot histogram).
/// Decoupled, thread-safe, and resilient against corrupted storage payloads.
public final class FeedingRoutineManager: @unchecked Sendable {
    public static var defaultStoreProvider: @Sendable () -> FeedingStore = {
        UserDefaultsFeedingStore()
    }

    private let lock = NSLock()
    public let store: FeedingStore

    public private(set) var grid: FeedingMemoryGrid
    public private(set) var histogram: FeedingTimeHistogram

    public init(store: FeedingStore? = nil) {
        let actualStore = store ?? Self.defaultStoreProvider()
        self.store = actualStore
        // Graceful corrupted data resilience:
        // If data is corrupt or missing, load returns nil and falls back to clean instance without crash.
        self.grid = actualStore.loadGrid() ?? FeedingMemoryGrid()
        self.histogram = actualStore.loadHistogram() ?? FeedingTimeHistogram()
    }

    /// Records a feeding event at pond world coordinates.
    /// World coordinates are automatically normalized so location memory scales proportionally on resize.
    @discardableResult
    public func recordFeeding(
        at worldPoint: PondVector,
        bounds: PondBounds,
        at date: Date = Date(),
        calendar: Calendar = .current
    ) -> (newLocationSession: Bool, newTimeSession: Bool) {
        lock.lock()
        defer { lock.unlock() }

        guard bounds.width > 0 && bounds.height > 0 else { return (false, false) }
        let normU = min(1.0, max(0.0, worldPoint.x / bounds.width))
        let normV = min(1.0, max(0.0, worldPoint.y / bounds.height))
        let normPoint = PondVector(x: normU, y: normV)

        let isNewLoc = grid.recordFeeding(normalizedPoint: normPoint, at: date)
        let isNewTime = histogram.recordFeeding(at: date, calendar: calendar)

        store.saveGrid(grid)
        store.saveHistogram(histogram)

        return (isNewLoc, isNewTime)
    }

    /// Checks whether the given date matches an established feeding time habit.
    public func isHabitualTime(at date: Date = Date(), calendar: Calendar = .current) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        var hist = histogram
        hist.applyDecay(at: date)
        let currentSlot = FeedingTimeHistogram.slot(for: date, calendar: calendar)
        return hist.isHabitualTime(slot: currentSlot)
    }

    /// Returns the world coordinate of the preferred feeding location if a confident habit exists.
    /// Automatically computed proportionally for the current pond bounds.
    public func habitualWorldTarget(for bounds: PondBounds, at date: Date = Date()) -> PondVector? {
        lock.lock()
        defer { lock.unlock() }

        var g = grid
        g.applyDecay(at: date)

        guard let pref = g.preferredCell, pref.weight >= FeedingMemoryGrid.confidenceThreshold else {
            return nil
        }
        return FeedingMemoryGrid.worldCenter(col: pref.col, row: pref.row, bounds: bounds)
    }

    /// Returns confidence score (0.0 to 1.0+) for the current preferred habit.
    public func overallConfidence(at date: Date = Date()) -> Double {
        lock.lock()
        defer { lock.unlock() }
        var g = grid
        g.applyDecay(at: date)
        let locWeight = g.preferredCell?.weight ?? 0.0
        return min(1.0, locWeight / FeedingMemoryGrid.confidenceThreshold)
    }

    public func reset() {
        lock.lock()
        defer { lock.unlock() }
        grid = FeedingMemoryGrid()
        histogram = FeedingTimeHistogram()
        store.reset()
    }
}
