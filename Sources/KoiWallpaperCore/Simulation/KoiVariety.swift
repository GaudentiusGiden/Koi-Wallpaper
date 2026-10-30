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

    /// Convenience initializer from hex value (e.g. 0xF1EADB)
    public init(hex: UInt32, alpha: Double = 1.0) {
        self.red = Double((hex >> 16) & 0xFF) / 255.0
        self.green = Double((hex >> 8) & 0xFF) / 255.0
        self.blue = Double(hex & 0xFF) / 255.0
        self.alpha = min(max(alpha, 0.0), 1.0)
    }

    public static let white = SimulationColor(hex: 0xF1EADB)
    public static let black = SimulationColor(hex: 0x242622)
    public static let crimson = SimulationColor(hex: 0xDC4B2F)
    public static let orange = SimulationColor(hex: 0xDF5032)
    public static let gold = SimulationColor(hex: 0xE7AA31)
    public static let deepGold = SimulationColor(hex: 0xCF7626)
    public static let indigo = SimulationColor(hex: 0x385764)
    public static let platinum = SimulationColor(hex: 0xEAF2F8)
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

/// Mathematical pattern patch definition along the fish spine, adapted from authentic Japanese koi markings.
public struct KoiPatternPatch: Sendable, Equatable {
    /// Normalized position along spine: 0.0 near head/snout, 1.0 near tail peduncle
    public let position: Double
    /// Relative longitudinal length of patch (0.0 to 1.0)
    public let length: Double
    /// Relative transverse width of patch (0.0 to 1.0)
    public let width: Double
    /// Lateral offset from spine centerline: -1.0 (left) to 1.0 (right)
    public let offset: Double
    /// Whether this patch uses secondary marking color (e.g. black/sumi) instead of primary accent (hi)
    public let isSecondaryMarking: Bool

    public init(
        position: Double,
        length: Double,
        width: Double,
        offset: Double,
        isSecondaryMarking: Bool = false
    ) {
        self.position = position
        self.length = length
        self.width = width
        self.offset = offset
        self.isSecondaryMarking = isSecondaryMarking
    }
}

public struct KoiVariety: Equatable, Sendable {
    public let type: KoiVarietyType
    public let name: String
    public let bodyBaseColor: SimulationColor
    public let primaryPatternColor: SimulationColor
    public let secondaryPatternColor: SimulationColor?
    public let finColor: SimulationColor
    public let neonBodyBaseColor: SimulationColor
    public let neonPrimaryPatternColor: SimulationColor
    public let neonSecondaryPatternColor: SimulationColor?
    public let neonFinColor: SimulationColor
    public let patterns: [KoiPatternPatch]

    public init(
        type: KoiVarietyType,
        name: String,
        bodyBaseColor: SimulationColor,
        primaryPatternColor: SimulationColor,
        secondaryPatternColor: SimulationColor? = nil,
        finColor: SimulationColor,
        neonBodyBaseColor: SimulationColor? = nil,
        neonPrimaryPatternColor: SimulationColor? = nil,
        neonSecondaryPatternColor: SimulationColor? = nil,
        neonFinColor: SimulationColor? = nil,
        patterns: [KoiPatternPatch] = []
    ) {
        self.type = type
        self.name = name
        self.bodyBaseColor = bodyBaseColor
        self.primaryPatternColor = primaryPatternColor
        self.secondaryPatternColor = secondaryPatternColor
        self.finColor = finColor
        self.neonBodyBaseColor = neonBodyBaseColor ?? bodyBaseColor
        self.neonPrimaryPatternColor = neonPrimaryPatternColor ?? primaryPatternColor
        self.neonSecondaryPatternColor = neonSecondaryPatternColor ?? secondaryPatternColor
        self.neonFinColor = neonFinColor ?? finColor
        self.patterns = patterns
    }

    public func bodyBaseColor(for mode: KoiPaletteMode) -> SimulationColor {
        mode == .neon ? neonBodyBaseColor : bodyBaseColor
    }

    public func primaryPatternColor(for mode: KoiPaletteMode) -> SimulationColor {
        mode == .neon ? neonPrimaryPatternColor : primaryPatternColor
    }

    public func secondaryPatternColor(for mode: KoiPaletteMode) -> SimulationColor? {
        mode == .neon ? neonSecondaryPatternColor : secondaryPatternColor
    }

    public func finColor(for mode: KoiPaletteMode) -> SimulationColor {
        mode == .neon ? neonFinColor : finColor
    }

    public static let allEightVarieties: [KoiVariety] = [
        // 1. Kohaku: Classic pristine white porcelain body with vibrant crimson step markings
        KoiVariety(
            type: .kohaku,
            name: "Kohaku",
            bodyBaseColor: SimulationColor(hex: 0xF1EADB),
            primaryPatternColor: SimulationColor(hex: 0xDC4B2F),
            secondaryPatternColor: nil,
            finColor: SimulationColor(hex: 0xE6DDCA, alpha: 0.75),
            neonBodyBaseColor: SimulationColor(hex: 0xFFF3E8),
            neonPrimaryPatternColor: SimulationColor(hex: 0xFF3B5C),
            neonSecondaryPatternColor: nil,
            neonFinColor: SimulationColor(hex: 0xFFD6DE, alpha: 0.8),
            patterns: [
                KoiPatternPatch(position: 0.17, length: 0.090, width: 0.74, offset: 0.04),
                KoiPatternPatch(position: 0.48, length: 0.115, width: 0.69, offset: -0.12),
                KoiPatternPatch(position: 0.76, length: 0.085, width: 0.62, offset: 0.16)
            ]
        ),
        // 2. Taisho Sanke: White body with crimson patches and black sumi accents
        KoiVariety(
            type: .sanke,
            name: "Taisho Sanke",
            bodyBaseColor: SimulationColor(hex: 0xF2EBDC),
            primaryPatternColor: SimulationColor(hex: 0xDF5032),
            secondaryPatternColor: SimulationColor(hex: 0x20211F),
            finColor: SimulationColor(hex: 0xE7DECE, alpha: 0.75),
            neonBodyBaseColor: SimulationColor(hex: 0xFF6A2B),
            neonPrimaryPatternColor: SimulationColor(hex: 0xFFF0D4),
            neonSecondaryPatternColor: SimulationColor(hex: 0x2C0F1B),
            neonFinColor: SimulationColor(hex: 0xFF9A3D, alpha: 0.8),
            patterns: [
                KoiPatternPatch(position: 0.19, length: 0.095, width: 0.70, offset: 0.04, isSecondaryMarking: false),
                KoiPatternPatch(position: 0.58, length: 0.105, width: 0.66, offset: -0.14, isSecondaryMarking: false),
                KoiPatternPatch(position: 0.38, length: 0.045, width: 0.30, offset: 0.38, isSecondaryMarking: true),
                KoiPatternPatch(position: 0.79, length: 0.040, width: 0.28, offset: -0.36, isSecondaryMarking: true)
            ]
        ),
        // 3. Showa Sanshoku: Midnight black base with bold red and white patterns
        KoiVariety(
            type: .showa,
            name: "Showa Sanshoku",
            bodyBaseColor: SimulationColor(hex: 0x242622),
            primaryPatternColor: SimulationColor(hex: 0xD9482E),
            secondaryPatternColor: SimulationColor(hex: 0xEEE6D5),
            finColor: SimulationColor(hex: 0xC9BFAA, alpha: 0.75),
            neonBodyBaseColor: SimulationColor(hex: 0x2A1052),
            neonPrimaryPatternColor: SimulationColor(hex: 0xFF7AD6),
            neonSecondaryPatternColor: SimulationColor(hex: 0xA86BFF),
            neonFinColor: SimulationColor(hex: 0xD6A4FF, alpha: 0.8),
            patterns: [
                KoiPatternPatch(position: 0.15, length: 0.082, width: 0.63, offset: -0.05, isSecondaryMarking: false),
                KoiPatternPatch(position: 0.53, length: 0.092, width: 0.58, offset: 0.17, isSecondaryMarking: false),
                KoiPatternPatch(position: 0.32, length: 0.090, width: 0.72, offset: 0.10, isSecondaryMarking: true),
                KoiPatternPatch(position: 0.73, length: 0.105, width: 0.67, offset: -0.14, isSecondaryMarking: true)
            ]
        ),
        // 4. Yamabuki Ogon: Metallic deep golden yellow
        KoiVariety(
            type: .ogon,
            name: "Yamabuki Ogon",
            bodyBaseColor: SimulationColor(hex: 0xE7AA31),
            primaryPatternColor: SimulationColor(hex: 0xCF7626),
            secondaryPatternColor: nil,
            finColor: SimulationColor(hex: 0xD9922A, alpha: 0.8),
            neonBodyBaseColor: SimulationColor(hex: 0xFFCF3A),
            neonPrimaryPatternColor: SimulationColor(hex: 0xFF8A1F),
            neonSecondaryPatternColor: nil,
            neonFinColor: SimulationColor(hex: 0xFFB22A, alpha: 0.8),
            patterns: []
        ),
        // 5. Asagi: Slate indigo blue-grey back with vermilion red flanks and fins
        KoiVariety(
            type: .asagi,
            name: "Asagi",
            bodyBaseColor: SimulationColor(hex: 0x385764),
            primaryPatternColor: SimulationColor(hex: 0xDC4B2F),
            secondaryPatternColor: SimulationColor(hex: 0x223B47),
            finColor: SimulationColor(hex: 0xE65842, alpha: 0.85),
            neonBodyBaseColor: SimulationColor(hex: 0x2F6FF2),
            neonPrimaryPatternColor: SimulationColor(hex: 0xFFD23A),
            neonSecondaryPatternColor: SimulationColor(hex: 0x0D1F5E),
            neonFinColor: SimulationColor(hex: 0xFFC93A, alpha: 0.85),
            patterns: [
                KoiPatternPatch(position: 0.45, length: 0.22, width: 0.45, offset: 0.78, isSecondaryMarking: false),
                KoiPatternPatch(position: 0.45, length: 0.22, width: 0.45, offset: -0.78, isSecondaryMarking: false)
            ]
        ),
        // 6. Shiro Utsuri: Rich black body with crisp white step patches
        KoiVariety(
            type: .shiroUtsuri,
            name: "Shiro Utsuri",
            bodyBaseColor: SimulationColor(hex: 0x252825),
            primaryPatternColor: SimulationColor(hex: 0xEAE5DA),
            secondaryPatternColor: nil,
            finColor: SimulationColor(hex: 0xD7D2C7, alpha: 0.75),
            neonBodyBaseColor: SimulationColor(hex: 0x1C3B6E),
            neonPrimaryPatternColor: SimulationColor(hex: 0x5FD4FF),
            neonSecondaryPatternColor: nil,
            neonFinColor: SimulationColor(hex: 0xCBE8FF, alpha: 0.8),
            patterns: [
                KoiPatternPatch(position: 0.24, length: 0.100, width: 0.70, offset: 0.08, isSecondaryMarking: false),
                KoiPatternPatch(position: 0.52, length: 0.110, width: 0.65, offset: -0.16, isSecondaryMarking: false),
                KoiPatternPatch(position: 0.78, length: 0.080, width: 0.56, offset: 0.18, isSecondaryMarking: false)
            ]
        ),
        // 7. Tancho: Pure snow-white body with a single circular scarlet sun on forehead
        KoiVariety(
            type: .tancho,
            name: "Tancho",
            bodyBaseColor: SimulationColor(hex: 0xF2EBDC),
            primaryPatternColor: SimulationColor(hex: 0xDA4430),
            secondaryPatternColor: nil,
            finColor: SimulationColor(hex: 0xE7DECE, alpha: 0.75),
            neonBodyBaseColor: SimulationColor(hex: 0xFFF3E8),
            neonPrimaryPatternColor: SimulationColor(hex: 0xFF3B5C),
            neonSecondaryPatternColor: nil,
            neonFinColor: SimulationColor(hex: 0xFFD6DE, alpha: 0.8),
            patterns: [
                KoiPatternPatch(position: 0.16, length: 0.070, width: 0.52, offset: 0.0, isSecondaryMarking: false)
            ]
        ),
        // 8. Kikusui: Silvery platinum white with glowing metallic orange flank waves
        KoiVariety(
            type: .kikusui,
            name: "Kikusui",
            bodyBaseColor: SimulationColor(hex: 0xEAF2F8),
            primaryPatternColor: SimulationColor(hex: 0xE67E22),
            secondaryPatternColor: nil,
            finColor: SimulationColor(hex: 0xE0E6ED, alpha: 0.8),
            neonBodyBaseColor: SimulationColor(hex: 0xEAF6FF),
            neonPrimaryPatternColor: SimulationColor(hex: 0xFF6A2B),
            neonSecondaryPatternColor: nil,
            neonFinColor: SimulationColor(hex: 0xCBE8FF, alpha: 0.8),
            patterns: [
                KoiPatternPatch(position: 0.38, length: 0.20, width: 0.55, offset: 0.65, isSecondaryMarking: false),
                KoiPatternPatch(position: 0.42, length: 0.18, width: 0.52, offset: -0.65, isSecondaryMarking: false)
            ]
        )
    ]
}
