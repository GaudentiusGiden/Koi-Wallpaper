import AppKit
import Foundation
import OSLog

private let logger = Logger(subsystem: "com.koiwallpaper.KoiWallpaper", category: "TimeOfDay")

/// Governs the atmospheric time-of-day progression and theme selection for the koi pond.
public final class TimeOfDayController {
    private var isBatchUpdating: Bool = false

    public var mode: TimeOfDayMode {
        didSet {
            if oldValue != mode && !isBatchUpdating {
                evaluateAndNotify()
            }
        }
    }

    public var manualTheme: PondTheme {
        didSet {
            if oldValue != manualTheme && mode == .manual && !isBatchUpdating {
                evaluateAndNotify()
            }
        }
    }

    public var manualPhase: TimeOfDayPhase {
        get { manualTheme.asTimePhase ?? .day }
        set { manualTheme = newValue.theme }
    }

    public private(set) var currentPhase: TimeOfDayPhase = .day {
        didSet {
            if oldValue != currentPhase {
                logger.info("Time of day phase transitioned: \(oldValue.rawValue) -> \(self.currentPhase.rawValue)")
                onPhaseChanged?(currentPhase)
            }
        }
    }

    public private(set) var currentTheme: PondTheme = .day {
        didSet {
            if oldValue != currentTheme {
                logger.info("Pond theme transitioned: \(oldValue.rawValue) -> \(self.currentTheme.rawValue)")
                onThemeChanged?(currentTheme)
            }
        }
    }

    public var onPhaseChanged: ((TimeOfDayPhase) -> Void)?
    public var onThemeChanged: ((PondTheme) -> Void)?

    private let dateProvider: () -> Date
    private let systemAppearanceProvider: () -> Bool
    private var timer: Timer?
    private var appearanceObserver: NSObjectProtocol?

    public init(
        mode: TimeOfDayMode = .auto,
        manualPhase: TimeOfDayPhase = .day,
        manualTheme: PondTheme? = nil,
        dateProvider: @escaping () -> Date = { Date() },
        systemAppearanceProvider: @escaping () -> Bool = {
            let app = NSApplication.shared
            let appearance = app.effectiveAppearance
            return appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        }
    ) {
        self.mode = mode
        let resolvedTheme = manualTheme ?? manualPhase.theme
        self.manualTheme = resolvedTheme
        self.dateProvider = dateProvider
        self.systemAppearanceProvider = systemAppearanceProvider
        let (calcPhase, calcTheme) = Self.calculatePhaseAndTheme(
            mode: mode,
            manualTheme: resolvedTheme,
            date: dateProvider(),
            isDarkMode: systemAppearanceProvider()
        )
        self.currentPhase = calcPhase
        self.currentTheme = calcTheme
    }

    deinit {
        stopMonitoring()
    }

    public func startMonitoring() {
        stopMonitoring()

        // Periodic check every 60 seconds for clock progression
        let timer = Timer(timeInterval: 60.0, repeats: true) { [weak self] _ in
            self?.evaluateAndNotify()
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer

        // Observe system appearance changes
        appearanceObserver = DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name("AppleInterfaceThemeChangedNotification"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.evaluateAndNotify()
        }
    }

    public func stopMonitoring() {
        timer?.invalidate()
        timer = nil
        if let obs = appearanceObserver {
            DistributedNotificationCenter.default().removeObserver(obs)
            appearanceObserver = nil
        }
    }

    public func setMode(_ newMode: TimeOfDayMode) {
        self.mode = newMode
    }

    public func setManualPhase(_ newPhase: TimeOfDayPhase) {
        self.manualPhase = newPhase
    }

    public func setManualTheme(_ newTheme: PondTheme) {
        self.manualTheme = newTheme
    }

    /// Atomically updates mode to .manual and sets manualTheme, evaluating and notifying at most once.
    public func selectManualTheme(_ newTheme: PondTheme) {
        let modeChanged = (mode != .manual)
        let themeChanged = (manualTheme != newTheme)
        guard modeChanged || themeChanged else { return }

        isBatchUpdating = true
        manualTheme = newTheme
        mode = .manual
        isBatchUpdating = false
        evaluateAndNotify()
    }

    /// Atomically updates both mode and manualTheme without intermediate evaluations.
    public func batchUpdate(mode newMode: TimeOfDayMode, manualTheme newManualTheme: PondTheme) {
        let modeChanged = (mode != newMode)
        let themeChanged = (manualTheme != newManualTheme)
        guard modeChanged || themeChanged else {
            evaluateAndNotify()
            return
        }

        isBatchUpdating = true
        manualTheme = newManualTheme
        mode = newMode
        isBatchUpdating = false
        evaluateAndNotify()
    }

    public func evaluateAndNotify() {
        let (calculatedPhase, calculatedTheme) = Self.calculatePhaseAndTheme(
            mode: mode,
            manualTheme: manualTheme,
            date: dateProvider(),
            isDarkMode: systemAppearanceProvider()
        )
        self.currentPhase = calculatedPhase
        self.currentTheme = calculatedTheme
    }

    /// Pure function mapping mode, date, and dark mode state to TimeOfDayPhase.
    public static func calculatePhase(
        mode: TimeOfDayMode,
        manualPhase: TimeOfDayPhase,
        date: Date,
        isDarkMode: Bool
    ) -> TimeOfDayPhase {
        calculatePhaseAndTheme(
            mode: mode,
            manualTheme: manualPhase.theme,
            date: date,
            isDarkMode: isDarkMode
        ).phase
    }

    /// Pure function calculating both TimeOfDayPhase and the active PondTheme according to REA rules.
    public static func calculatePhaseAndTheme(
        mode: TimeOfDayMode,
        manualTheme: PondTheme,
        date: Date,
        isDarkMode: Bool
    ) -> (phase: TimeOfDayPhase, theme: PondTheme) {
        switch mode {
        case .manual:
            let phase = manualTheme.asTimePhase ?? .day
            return (phase: phase, theme: manualTheme)
        case .systemTheme:
            let phase: TimeOfDayPhase = isDarkMode ? .night : .day
            return (phase: phase, theme: phase.theme)
        case .auto:
            let calendar = Calendar.current
            let hour = calendar.component(.hour, from: date)
            let minute = calendar.component(.minute, from: date)
            let minutesSinceMidnight = hour * 60 + minute

            // REA local time breakdown:
            // Dawn: 05:30 (330 min) ..< 07:30 (450 min)
            // Day: 07:30 (450 min) ..< 16:30 (990 min)
            // Golden Hour: 16:30 (990 min) ..< 18:00 (1080 min)
            // Dusk: 18:00 (1080 min) ..< 19:30 (1170 min)
            // Night: 19:30 (1170 min) ..< 05:30 (330 min)
            let phase: TimeOfDayPhase
            switch minutesSinceMidnight {
            case 330..<450:
                phase = .dawn
            case 450..<990:
                phase = .day
            case 990..<1080:
                phase = .goldenHour
            case 1080..<1170:
                phase = .dusk
            default:
                phase = .night
            }
            return (phase: phase, theme: phase.theme)
        }
    }
}
