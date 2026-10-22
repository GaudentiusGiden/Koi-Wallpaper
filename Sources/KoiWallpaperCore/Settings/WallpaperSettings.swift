import Foundation

/// Defines how the time of day phase or visual theme is determined.
public enum TimeOfDayMode: String, Codable, CaseIterable, Sendable {
    /// Automatically tracks local system clock time across the five REA phases.
    case auto = "auto"
    /// Synchronizes with macOS system appearance (light mode = day, dark mode = night).
    case systemTheme = "systemTheme"
    /// Fixed manual selection by the user (supports all 5 time phases plus Deep Clear and Rain presets).
    case manual = "manual"
}

/// The visual atmospheric time-of-day phases of the koi pond according to the REA breakdown.
public enum TimeOfDayPhase: String, Codable, CaseIterable, Sendable {
    case dawn = "dawn"
    case day = "day"
    case goldenHour = "goldenHour"
    case dusk = "dusk"
    case night = "night"

    public var theme: PondTheme {
        switch self {
        case .dawn: return .dawn
        case .day: return .day
        case .goldenHour: return .goldenHour
        case .dusk: return .dusk
        case .night: return .night
        }
    }

    public var displayName: String {
        switch self {
        case .dawn: return "Fajar (Dawn)"
        case .day: return "Siang (Day)"
        case .goldenHour: return "Golden Hour"
        case .dusk: return "Senja (Dusk)"
        case .night: return "Malam (Night)"
        }
    }
}

/// Visual pond themes including the five time-of-day phases and two manual presets (Deep Clear & Rain).
public enum PondTheme: String, Codable, CaseIterable, Sendable {
    case dawn = "dawn"
    case day = "day"
    case goldenHour = "goldenHour"
    case dusk = "dusk"
    case night = "night"
    case deepClear = "deepClear"
    case rain = "rain"

    public var isTimePhase: Bool {
        switch self {
        case .dawn, .day, .goldenHour, .dusk, .night:
            return true
        case .deepClear, .rain:
            return false
        }
    }

    public var asTimePhase: TimeOfDayPhase? {
        TimeOfDayPhase(rawValue: rawValue)
    }

    public var displayName: String {
        switch self {
        case .dawn: return "Fajar (Dawn)"
        case .day: return "Siang (Day)"
        case .goldenHour: return "Golden Hour"
        case .dusk: return "Senja (Dusk)"
        case .night: return "Malam (Night)"
        case .deepClear: return "Deep Clear"
        case .rain: return "Hujan (Rain Preset)"
        }
    }
}

/// Global behavioral mood of the pond and koi fish.
public enum PondMood: String, Codable, CaseIterable, Sendable {
    case calm = "calm"
    case playful = "playful"

    public var displayName: String {
        switch self {
        case .calm: return "Tenang (Calm)"
        case .playful: return "Lincah (Playful)"
        }
    }
}

/// Persistent user configuration for the koi wallpaper.
public struct WallpaperSettings: Codable, Equatable, Sendable {
    public var timeOfDayMode: TimeOfDayMode
    public var manualTimePhase: TimeOfDayPhase {
        didSet {
            if manualTheme.asTimePhase != manualTimePhase {
                manualTheme = manualTimePhase.theme
            }
        }
    }
    public var manualTheme: PondTheme {
        didSet {
            if let phase = manualTheme.asTimePhase, phase != manualTimePhase {
                manualTimePhase = phase
            }
        }
    }
    public var pauseOnBattery: Bool
    public var isManualPaused: Bool
    public var initialInteractionMode: InputInteractionMode
    public var showHUD: Bool
    public var pondMood: PondMood
    public var isRainActive: Bool

    public init(
        timeOfDayMode: TimeOfDayMode = .auto,
        manualTimePhase: TimeOfDayPhase = .day,
        manualTheme: PondTheme? = nil,
        pauseOnBattery: Bool = false,
        isManualPaused: Bool = false,
        initialInteractionMode: InputInteractionMode = .clickThrough,
        showHUD: Bool = false,
        pondMood: PondMood = .calm,
        isRainActive: Bool = false
    ) {
        self.timeOfDayMode = timeOfDayMode
        let resolvedTheme = manualTheme ?? manualTimePhase.theme
        self.manualTheme = resolvedTheme
        self.manualTimePhase = resolvedTheme.asTimePhase ?? manualTimePhase
        self.pauseOnBattery = pauseOnBattery
        self.isManualPaused = isManualPaused
        self.initialInteractionMode = initialInteractionMode
        self.showHUD = showHUD
        self.pondMood = pondMood
        self.isRainActive = isRainActive
    }

    private enum CodingKeys: String, CodingKey {
        case timeOfDayMode
        case manualTimePhase
        case manualTheme
        case pauseOnBattery
        case isManualPaused
        case initialInteractionMode
        case showHUD
        case pondMood
        case isRainActive
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        timeOfDayMode = try container.decodeIfPresent(TimeOfDayMode.self, forKey: .timeOfDayMode) ?? .auto
        let decodedPhase = try container.decodeIfPresent(TimeOfDayPhase.self, forKey: .manualTimePhase) ?? .day
        manualTimePhase = decodedPhase
        let decodedTheme = try container.decodeIfPresent(PondTheme.self, forKey: .manualTheme)
        manualTheme = decodedTheme ?? decodedPhase.theme
        pauseOnBattery = try container.decodeIfPresent(Bool.self, forKey: .pauseOnBattery) ?? false
        isManualPaused = try container.decodeIfPresent(Bool.self, forKey: .isManualPaused) ?? false
        initialInteractionMode = try container.decodeIfPresent(InputInteractionMode.self, forKey: .initialInteractionMode) ?? .clickThrough
        showHUD = try container.decodeIfPresent(Bool.self, forKey: .showHUD) ?? false
        pondMood = try container.decodeIfPresent(PondMood.self, forKey: .pondMood) ?? .calm
        isRainActive = try container.decodeIfPresent(Bool.self, forKey: .isRainActive) ?? false
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(timeOfDayMode, forKey: .timeOfDayMode)
        try container.encode(manualTimePhase, forKey: .manualTimePhase)
        try container.encode(manualTheme, forKey: .manualTheme)
        try container.encode(pauseOnBattery, forKey: .pauseOnBattery)
        try container.encode(isManualPaused, forKey: .isManualPaused)
        try container.encode(initialInteractionMode, forKey: .initialInteractionMode)
        try container.encode(showHUD, forKey: .showHUD)
        try container.encode(pondMood, forKey: .pondMood)
        try container.encode(isRainActive, forKey: .isRainActive)
    }
}
