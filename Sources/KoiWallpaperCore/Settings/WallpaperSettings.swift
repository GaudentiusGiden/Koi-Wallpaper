import Foundation

/// Defines how the time of day phase is determined.
public enum TimeOfDayMode: String, Codable, CaseIterable, Sendable {
    /// Automatically tracks local system clock time.
    case auto = "auto"
    /// Synchronizes with macOS system appearance (light mode = day, dark mode = night).
    case systemTheme = "systemTheme"
    /// Fixed manual selection by the user.
    case manual = "manual"
}

/// The visual atmospheric phases of the koi pond.
public enum TimeOfDayPhase: String, Codable, CaseIterable, Sendable {
    case dawn = "dawn"
    case day = "day"
    case dusk = "dusk"
    case night = "night"

    public var displayName: String {
        switch self {
        case .dawn: return "Fajar (Dawn)"
        case .day: return "Siang (Day)"
        case .dusk: return "Senja (Dusk)"
        case .night: return "Malam (Night)"
        }
    }
}

/// Persistent user configuration for the koi wallpaper.
public struct WallpaperSettings: Codable, Equatable, Sendable {
    public var timeOfDayMode: TimeOfDayMode
    public var manualTimePhase: TimeOfDayPhase
    public var pauseOnBattery: Bool
    public var isManualPaused: Bool
    public var initialInteractionMode: InputInteractionMode
    public var showHUD: Bool

    public init(
        timeOfDayMode: TimeOfDayMode = .auto,
        manualTimePhase: TimeOfDayPhase = .day,
        pauseOnBattery: Bool = false,
        isManualPaused: Bool = false,
        initialInteractionMode: InputInteractionMode = .clickThrough,
        showHUD: Bool = false
    ) {
        self.timeOfDayMode = timeOfDayMode
        self.manualTimePhase = manualTimePhase
        self.pauseOnBattery = pauseOnBattery
        self.isManualPaused = isManualPaused
        self.initialInteractionMode = initialInteractionMode
        self.showHUD = showHUD
    }
}
