import AppKit
import Foundation
import OSLog

private let logger = Logger(subsystem: "com.koiwallpaper.KoiWallpaper", category: "TimeOfDay")

/// Governs the atmospheric time-of-day progression for the koi pond.
public final class TimeOfDayController {
    public var mode: TimeOfDayMode {
        didSet {
            if oldValue != mode {
                evaluateAndNotify()
            }
        }
    }

    public var manualPhase: TimeOfDayPhase {
        didSet {
            if oldValue != manualPhase && mode == .manual {
                evaluateAndNotify()
            }
        }
    }

    public private(set) var currentPhase: TimeOfDayPhase = .day {
        didSet {
            if oldValue != currentPhase {
                logger.info("Time of day phase transitioned: \(oldValue.rawValue) -> \(self.currentPhase.rawValue)")
                onPhaseChanged?(currentPhase)
            }
        }
    }

    public var onPhaseChanged: ((TimeOfDayPhase) -> Void)?

    private let dateProvider: () -> Date
    private let systemAppearanceProvider: () -> Bool
    private var timer: Timer?
    private var appearanceObserver: NSObjectProtocol?

    public init(
        mode: TimeOfDayMode = .auto,
        manualPhase: TimeOfDayPhase = .day,
        dateProvider: @escaping () -> Date = { Date() },
        systemAppearanceProvider: @escaping () -> Bool = {
            let appearance = NSApp.effectiveAppearance
            return appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        }
    ) {
        self.mode = mode
        self.manualPhase = manualPhase
        self.dateProvider = dateProvider
        self.systemAppearanceProvider = systemAppearanceProvider
        self.currentPhase = Self.calculatePhase(
            mode: mode,
            manualPhase: manualPhase,
            date: dateProvider(),
            isDarkMode: systemAppearanceProvider()
        )
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

    public func evaluateAndNotify() {
        let calculated = Self.calculatePhase(
            mode: mode,
            manualPhase: manualPhase,
            date: dateProvider(),
            isDarkMode: systemAppearanceProvider()
        )
        self.currentPhase = calculated
    }

    /// Pure function mapping mode, date, and dark mode state to TimeOfDayPhase.
    public static func calculatePhase(
        mode: TimeOfDayMode,
        manualPhase: TimeOfDayPhase,
        date: Date,
        isDarkMode: Bool
    ) -> TimeOfDayPhase {
        switch mode {
        case .manual:
            return manualPhase
        case .systemTheme:
            return isDarkMode ? .night : .day
        case .auto:
            let calendar = Calendar.current
            let hour = calendar.component(.hour, from: date)
            switch hour {
            case 5..<8:
                return .dawn
            case 8..<17:
                return .day
            case 17..<20:
                return .dusk
            default:
                return .night
            }
        }
    }
}
