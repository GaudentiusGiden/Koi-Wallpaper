import CoreGraphics
import Foundation

/// The 4 distinct seasonal cycles influencing pond atmosphere, flora, and floating surface debris.
public enum PondSeason: String, Codable, CaseIterable, Sendable {
    case spring = "spring"
    case summer = "summer"
    case autumn = "autumn"
    case winter = "winter"

    public var displayName: String {
        switch self {
        case .spring: return "Musim Semi (Spring / Haru)"
        case .summer: return "Musim Panas (Summer / Natsu)"
        case .autumn: return "Musim Gugur (Autumn / Aki)"
        case .winter: return "Musim Dingin (Winter / Fuyu)"
        }
    }

    /// Descriptive banner message shown when season changes.
    public var bannerMessage: String {
        switch self {
        case .spring:
            return "Musim Semi (Haru) — Bunga Sakura & Kelopak Melayang"
        case .summer:
            return "Musim Panas (Natsu) — Teratai Mekar & Air Jernih"
        case .autumn:
            return "Musim Gugur (Aki) — Daun Momiji Merah-Keemasan Hanyut"
        case .winter:
            return "Musim Dingin (Fuyu) — Serpihan Es & Salju Tipis"
        }
    }

    /// Subtle atmospheric tint color applied across the pond scene to evoke the season.
    public var atmosphericTintColor: CGColor {
        switch self {
        case .spring:
            // Soft blushing sakura pink
            return CGColor(red: 0.98, green: 0.70, blue: 0.82, alpha: 0.038)
        case .summer:
            // Clear, vibrant emerald water sunlight
            return CGColor(red: 0.20, green: 0.75, blue: 0.55, alpha: 0.022)
        case .autumn:
            // Warm golden amber / momiji russet
            return CGColor(red: 0.88, green: 0.45, blue: 0.12, alpha: 0.060)
        case .winter:
            // Crisp cool frosty cyan/ice blue
            return CGColor(red: 0.45, green: 0.72, blue: 0.95, alpha: 0.070)
        }
    }

    /// Primary floating debris associated with this season.
    public var primaryDebrisType: FloatingDebrisType {
        switch self {
        case .spring: return .sakuraPetal
        case .summer: return .waterLilyPetal
        case .autumn: return .momijiLeaf
        case .winter: return .snowShard
        }
    }

    /// Evaluates current season according to Gregorian calendar month (Northern temperate baseline).
    public static func currentCalendarSeason(date: Date = Date(), calendar: Calendar = .current) -> PondSeason {
        let month = calendar.component(.month, from: date)
        switch month {
        case 3, 4, 5:
            return .spring
        case 6, 7, 8:
            return .summer
        case 9, 10, 11:
            return .autumn
        default: // 12, 1, 2
            return .winter
        }
    }
}

/// Mode to determine how the pond season is selected.
public enum SeasonMode: String, Codable, CaseIterable, Sendable {
    case autoCalendar = "autoCalendar"
    case manual = "manual"

    public var displayName: String {
        switch self {
        case .autoCalendar: return "Otomatis Sesuai Kalender (Auto)"
        case .manual: return "Manual"
        }
    }
}
