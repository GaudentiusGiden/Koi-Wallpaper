import Foundation
import OSLog

private let logger = Logger(subsystem: "com.koiwallpaper.KoiWallpaper", category: "Settings")

/// Storage abstraction for persistence of WallpaperSettings.
public protocol SettingsStore: AnyObject {
    func loadSettings() -> WallpaperSettings?
    func saveSettings(_ settings: WallpaperSettings)
    func resetSettings()
}

/// Persistent store using macOS standard UserDefaults.
public final class UserDefaultsSettingsStore: SettingsStore {
    private let userDefaults: UserDefaults
    private let key: String

    public init(userDefaults: UserDefaults = .standard, key: String = "com.koiwallpaper.settings") {
        self.userDefaults = userDefaults
        self.key = key
    }

    public func loadSettings() -> WallpaperSettings? {
        guard let data = userDefaults.data(forKey: key) else {
            return nil
        }
        do {
            let decoder = JSONDecoder()
            return try decoder.decode(WallpaperSettings.self, from: data)
        } catch {
            logger.error("Failed to decode WallpaperSettings: \(error.localizedDescription)")
            return nil
        }
    }

    public func saveSettings(_ settings: WallpaperSettings) {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(settings)
            userDefaults.set(data, forKey: key)
        } catch {
            logger.error("Failed to encode WallpaperSettings: \(error.localizedDescription)")
        }
    }

    public func resetSettings() {
        userDefaults.removeObject(forKey: key)
    }
}

/// Persistent store using a shared JSON file in Application Support for cross-process sync (Desktop App <-> Screen Saver).
public final class SharedFileSettingsStore: SettingsStore {
    public let fileURL: URL
    private let fallbackStore: SettingsStore?

    public static var defaultSettingsDirectory: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support")
        return appSupport.appendingPathComponent("KoiWallpaper")
    }

    public static var defaultSettingsURL: URL {
        defaultSettingsDirectory.appendingPathComponent("settings.json")
    }

    public init(
        fileURL: URL = SharedFileSettingsStore.defaultSettingsURL,
        fallbackStore: SettingsStore? = UserDefaultsSettingsStore()
    ) {
        self.fileURL = fileURL
        self.fallbackStore = fallbackStore
    }

    public func loadSettings() -> WallpaperSettings? {
        if FileManager.default.fileExists(atPath: fileURL.path) {
            do {
                let data = try Data(contentsOf: fileURL)
                let decoder = JSONDecoder()
                return try decoder.decode(WallpaperSettings.self, from: data)
            } catch {
                logger.error("Failed to decode settings from \(self.fileURL.path): \(error.localizedDescription)")
            }
        }
        return fallbackStore?.loadSettings()
    }

    public func saveSettings(_ settings: WallpaperSettings) {
        fallbackStore?.saveSettings(settings)

        do {
            let directory = fileURL.deletingLastPathComponent()
            if !FileManager.default.fileExists(atPath: directory.path) {
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            }
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(settings)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            logger.error("Failed to write settings to \(self.fileURL.path): \(error.localizedDescription)")
        }
    }

    public func resetSettings() {
        fallbackStore?.resetSettings()
        try? FileManager.default.removeItem(at: fileURL)
    }
}

/// In-memory store for deterministic unit tests and preview environments.
public final class InMemorySettingsStore: SettingsStore {
    private var storedSettings: WallpaperSettings?

    public init(initialSettings: WallpaperSettings? = nil) {
        self.storedSettings = initialSettings
    }

    public func loadSettings() -> WallpaperSettings? {
        return storedSettings
    }

    public func saveSettings(_ settings: WallpaperSettings) {
        self.storedSettings = settings
    }

    public func resetSettings() {
        self.storedSettings = nil
    }
}

/// Coordinates configuration state and persists mutations across app launches.
public final class SettingsManager {
    public let store: SettingsStore

    public private(set) var settings: WallpaperSettings {
        didSet {
            store.saveSettings(settings)
            onSettingsChanged?(settings)
        }
    }

    public var onSettingsChanged: ((WallpaperSettings) -> Void)?

    public init(store: SettingsStore = SharedFileSettingsStore()) {
        self.store = store
        self.settings = store.loadSettings() ?? WallpaperSettings()
    }

    public func updateSettings(_ transform: (inout WallpaperSettings) -> Void) {
        var current = settings
        transform(&current)
        self.settings = current
    }

    public func resetToDefaults() {
        store.resetSettings()
        self.settings = WallpaperSettings()
    }
}
