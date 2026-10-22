import Foundation

/// Innate temperament and physical responsiveness characteristics of an individual koi fish.
public struct FishTraits: Codable, Equatable, Sendable {
    /// Propensity to investigate water splash clicks and explore ripples (0.0 to 1.0).
    public var curiosity: Double
    /// Boldness/confidence when approaching objects or unfamiliar spots (0.0 to 1.0).
    public var boldness: Double
    /// Turning agility and responsiveness multiplier (0.8 to 1.3).
    public var agility: Double
    /// Propensity to seek food pellets and respond to feeding routines (0.0 to 1.0).
    public var feedingEagerness: Double

    public init(
        curiosity: Double = 0.5,
        boldness: Double = 0.5,
        agility: Double = 1.0,
        feedingEagerness: Double = 0.5
    ) {
        self.curiosity = min(1.0, max(0.0, curiosity))
        self.boldness = min(1.0, max(0.0, boldness))
        self.agility = min(1.5, max(0.7, agility))
        self.feedingEagerness = min(1.0, max(0.0, feedingEagerness))
    }

    /// Characteristic baseline traits for each of the 8 Japanese koi varieties.
    public static func defaultTraits(for variety: KoiVariety) -> FishTraits {
        switch variety.name {
        case "Kohaku":
            return FishTraits(curiosity: 0.85, boldness: 0.80, agility: 1.15, feedingEagerness: 0.90)
        case "Taisho Sanke":
            return FishTraits(curiosity: 0.70, boldness: 0.65, agility: 1.05, feedingEagerness: 0.75)
        case "Showa Sanshoku":
            return FishTraits(curiosity: 0.60, boldness: 0.75, agility: 1.00, feedingEagerness: 0.80)
        case "Yamabuki Ogon":
            return FishTraits(curiosity: 0.90, boldness: 0.90, agility: 1.20, feedingEagerness: 0.95)
        case "Asagi":
            return FishTraits(curiosity: 0.45, boldness: 0.40, agility: 0.90, feedingEagerness: 0.55)
        case "Shiro Utsuri":
            return FishTraits(curiosity: 0.55, boldness: 0.60, agility: 0.95, feedingEagerness: 0.65)
        case "Tancho":
            return FishTraits(curiosity: 0.50, boldness: 0.70, agility: 1.00, feedingEagerness: 0.60)
        case "Kikusui":
            return FishTraits(curiosity: 0.75, boldness: 0.55, agility: 1.10, feedingEagerness: 0.70)
        default:
            return FishTraits(curiosity: 0.60, boldness: 0.60, agility: 1.00, feedingEagerness: 0.70)
        }
    }
}
