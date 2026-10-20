import Foundation

/// Pure representation of an RGBA color for the simulation layer, independent of AppKit.
public struct SimulationColor: Equatable, Sendable {
    public var red: Double
    public var green: Double
    public var blue: Double
    public var alpha: Double

    public init(red: Double, green: Double, blue: Double, alpha: Double = 1.0) {
        self.red = min(max(red, 0.0), 1.0)
        self.green = min(max(green, 0.0), 1.0)
        self.blue = min(max(blue, 0.0), 1.0)
        self.alpha = min(max(alpha, 0.0), 1.0)
    }

    public static let white = SimulationColor(red: 0.98, green: 0.98, blue: 0.98)
    public static let black = SimulationColor(red: 0.10, green: 0.10, blue: 0.12)
    public static let crimson = SimulationColor(red: 0.88, green: 0.22, blue: 0.14)
    public static let orange = SimulationColor(red: 0.95, green: 0.48, blue: 0.12)
    public static let gold = SimulationColor(red: 0.96, green: 0.78, blue: 0.22)
    public static let deepGold = SimulationColor(red: 0.86, green: 0.65, blue: 0.14)
    public static let indigo = SimulationColor(red: 0.32, green: 0.42, blue: 0.52)
    public static let platinum = SimulationColor(red: 0.92, green: 0.94, blue: 0.96)
}

/// The 8 distinct classic Japanese koi varieties modeled in M1.
public enum KoiVarietyType: String, CaseIterable, Sendable {
    case kohaku = "Kohaku"
    case sanke = "Taisho Sanke"
    case showa = "Showa Sanshoku"
    case ogon = "Yamabuki Ogon"
    case asagi = "Asagi"
    case shiroUtsuri = "Shiro Utsuri"
    case tancho = "Tancho"
    case kikusui = "Kikusui"
}

public struct KoiVariety: Equatable, Sendable {
    public let type: KoiVarietyType
    public let name: String
    public let bodyBaseColor: SimulationColor
    public let primaryPatternColor: SimulationColor
    public let secondaryPatternColor: SimulationColor?
    public let finColor: SimulationColor

    public init(
        type: KoiVarietyType,
        name: String,
        bodyBaseColor: SimulationColor,
        primaryPatternColor: SimulationColor,
        secondaryPatternColor: SimulationColor? = nil,
        finColor: SimulationColor
    ) {
        self.type = type
        self.name = name
        self.bodyBaseColor = bodyBaseColor
        self.primaryPatternColor = primaryPatternColor
        self.secondaryPatternColor = secondaryPatternColor
        self.finColor = finColor
    }

    public static let allEightVarieties: [KoiVariety] = [
        // 1. Kohaku: Classic pristine white body with vibrant crimson markings
        KoiVariety(
            type: .kohaku,
            name: "Kohaku",
            bodyBaseColor: .white,
            primaryPatternColor: .crimson,
            secondaryPatternColor: nil,
            finColor: SimulationColor(red: 0.95, green: 0.95, blue: 0.95, alpha: 0.8)
        ),
        // 2. Taisho Sanke: White body with crimson patches and black sumi accents
        KoiVariety(
            type: .sanke,
            name: "Taisho Sanke",
            bodyBaseColor: .white,
            primaryPatternColor: .crimson,
            secondaryPatternColor: .black,
            finColor: SimulationColor(red: 0.95, green: 0.95, blue: 0.95, alpha: 0.8)
        ),
        // 3. Showa Sanshoku: Midnight black base with bold red and white patterns
        KoiVariety(
            type: .showa,
            name: "Showa Sanshoku",
            bodyBaseColor: .black,
            primaryPatternColor: .crimson,
            secondaryPatternColor: .white,
            finColor: SimulationColor(red: 0.25, green: 0.25, blue: 0.28, alpha: 0.85)
        ),
        // 4. Yamabuki Ogon: Metallic deep golden yellow
        KoiVariety(
            type: .ogon,
            name: "Yamabuki Ogon",
            bodyBaseColor: .gold,
            primaryPatternColor: .deepGold,
            secondaryPatternColor: nil,
            finColor: SimulationColor(red: 0.96, green: 0.82, blue: 0.35, alpha: 0.85)
        ),
        // 5. Asagi: Indigo blue-grey back with vermilion red flanks and fins
        KoiVariety(
            type: .asagi,
            name: "Asagi",
            bodyBaseColor: .indigo,
            primaryPatternColor: .crimson,
            secondaryPatternColor: SimulationColor(red: 0.20, green: 0.26, blue: 0.34),
            finColor: SimulationColor(red: 0.88, green: 0.28, blue: 0.20, alpha: 0.85)
        ),
        // 6. Shiro Utsuri: Rich black body with crisp white step patches
        KoiVariety(
            type: .shiroUtsuri,
            name: "Shiro Utsuri",
            bodyBaseColor: .black,
            primaryPatternColor: .white,
            secondaryPatternColor: nil,
            finColor: SimulationColor(red: 0.30, green: 0.30, blue: 0.35, alpha: 0.8)
        ),
        // 7. Tancho: Pure snow-white body with a single circular scarlet sun on forehead
        KoiVariety(
            type: .tancho,
            name: "Tancho",
            bodyBaseColor: .white,
            primaryPatternColor: .crimson,
            secondaryPatternColor: nil,
            finColor: SimulationColor(red: 0.96, green: 0.96, blue: 0.96, alpha: 0.8)
        ),
        // 8. Kikusui: Silvery platinum white with glowing metallic orange flank waves
        KoiVariety(
            type: .kikusui,
            name: "Kikusui",
            bodyBaseColor: .platinum,
            primaryPatternColor: .orange,
            secondaryPatternColor: nil,
            finColor: SimulationColor(red: 0.95, green: 0.90, blue: 0.85, alpha: 0.85)
        )
    ]
}
