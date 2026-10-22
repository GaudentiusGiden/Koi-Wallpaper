import Foundation
import OSLog

private let logger = Logger(subsystem: "com.koiwallpaper.KoiWallpaper", category: "DailyGreeting")

/// Storage abstraction for persisting daily greeting date records.
public protocol DailyGreetingStore: Sendable {
    func loadLastGreetingDayKey() -> String?
    func saveLastGreetingDayKey(_ key: String?)
}

public final class UserDefaultsGreetingStore: DailyGreetingStore, @unchecked Sendable {
    private let userDefaults: UserDefaults
    private let key: String

    public init(userDefaults: UserDefaults = .standard, key: String = "com.koiwallpaper.greeting.lastDayKey") {
        self.userDefaults = userDefaults
        self.key = key
    }

    public func loadLastGreetingDayKey() -> String? {
        userDefaults.string(forKey: key)
    }

    public func saveLastGreetingDayKey(_ key: String?) {
        if let k = key {
            userDefaults.set(k, forKey: self.key)
        } else {
            userDefaults.removeObject(forKey: self.key)
        }
    }
}

public final class InMemoryGreetingStore: DailyGreetingStore, @unchecked Sendable {
    private let lock = NSLock()
    private var storedKey: String?

    public init(initialKey: String? = nil) {
        self.storedKey = initialKey
    }

    public func loadLastGreetingDayKey() -> String? {
        lock.lock()
        defer { lock.unlock() }
        return storedKey
    }

    public func saveLastGreetingDayKey(_ key: String?) {
        lock.lock()
        defer { lock.unlock() }
        storedKey = key
    }
}

/// Coordinates once-per-day koi pond greetings with a 04:00 AM daily cutoff boundary.
/// Does not repeat when windows appear or are unhidden multiple times on the same day.
public final class DailyGreetingManager: @unchecked Sendable {
    public static let dayBoundaryHour: Int = 4 // 04:00 AM

    public static var defaultStoreProvider: @Sendable () -> DailyGreetingStore = {
        UserDefaultsGreetingStore()
    }

    private let lock = NSLock()
    public let store: DailyGreetingStore
    public private(set) var lastGreetingDayKey: String?

    public init(store: DailyGreetingStore? = nil) {
        let actualStore = store ?? Self.defaultStoreProvider()
        self.store = actualStore
        self.lastGreetingDayKey = actualStore.loadLastGreetingDayKey()
    }

    /// Computes the effective calendar day string (e.g. "2026-10-21") relative to the 04:00 boundary.
    /// Times before 04:00 AM belong to the preceding local calendar day.
    /// Uses local calendar day boundaries rather than subtracting an absolute duration,
    /// ensuring correct behavior across DST spring-forward and fall-back transitions.
    public static func dayKey(for date: Date, calendar: Calendar = .current) -> String {
        let hour = calendar.component(.hour, from: date)
        let effectiveDate: Date
        if hour < dayBoundaryHour {
            // Hour is before 04:00 AM (00:00 - 03:59), belonging to previous local calendar day.
            effectiveDate = calendar.date(byAdding: .day, value: -1, to: date) ?? date
        } else {
            // Hour is 04:00 AM or later, starting the current effective calendar day.
            effectiveDate = date
        }
        let comp = calendar.dateComponents([.year, .month, .day], from: effectiveDate)
        return String(format: "%04d-%02d-%02d", comp.year ?? 2026, comp.month ?? 1, comp.day ?? 1)
    }

    /// Checks if a greeting is due for the given date.
    /// If due, records it so subsequent calls on the same 04:00-bounded day return false.
    public func checkAndTriggerGreeting(at date: Date = Date(), calendar: Calendar = .current) -> (shouldGreet: Bool, message: String?) {
        lock.lock()
        defer { lock.unlock() }

        let currentDayKey = Self.dayKey(for: date, calendar: calendar)
        if currentDayKey == lastGreetingDayKey {
            return (false, nil)
        }

        lastGreetingDayKey = currentDayKey
        store.saveLastGreetingDayKey(currentDayKey)

        let msg = Self.greetingMessage(for: date, calendar: calendar)
        return (true, msg)
    }

    /// Inspects whether a greeting is due without marking it as shown.
    public func isGreetingDue(at date: Date = Date(), calendar: Calendar = .current) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        let currentDayKey = Self.dayKey(for: date, calendar: calendar)
        return currentDayKey != lastGreetingDayKey
    }

    /// Contextual message tailored to local hour.
    public static func greetingMessage(for date: Date, calendar: Calendar = .current) -> String {
        let hour = calendar.component(.hour, from: date)
        switch hour {
        case 4..<11:
            return "Selamat pagi! Kolam koi menyambut hari baru bersamamu."
        case 11..<15:
            return "Selamat siang! Nikmati ketenangan kolam di sela harimu."
        case 15..<18:
            return "Selamat sore! Cahaya hangat menyinari ikan-ikan koi."
        default:
            return "Selamat malam! Kolam beristirahat dalam ketenangan."
        }
    }

    public func reset() {
        lock.lock()
        defer { lock.unlock() }
        lastGreetingDayKey = nil
        store.saveLastGreetingDayKey(nil)
    }
}
