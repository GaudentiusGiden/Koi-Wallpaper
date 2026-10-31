import CoreGraphics
import Foundation

struct PondRGBColor {
    let red: CGFloat
    let green: CGFloat
    let blue: CGFloat

    init(hex: UInt32) {
        red = CGFloat((hex >> 16) & 0xFF) / 255
        green = CGFloat((hex >> 8) & 0xFF) / 255
        blue = CGFloat(hex & 0xFF) / 255
    }

    var components: (CGFloat, CGFloat, CGFloat) { (red, green, blue) }

    var cgColor: CGColor {
        CGColor(red: red, green: green, blue: blue, alpha: 1)
    }

    func cgColor(alpha: CGFloat) -> CGColor {
        CGColor(red: red, green: green, blue: blue, alpha: alpha)
    }
}

struct PondRGBAColor {
    let color: PondRGBColor
    let alpha: CGFloat

    var cgColor: CGColor { color.cgColor(alpha: alpha) }
}

struct PondCausticPalette {
    let outer: PondRGBColor
    let inner: PondRGBColor
    let faint: PondRGBColor
    let alphaGain: CGFloat

    // 3-Layer multi-scale caustics properties (Nagomi 09-water-surface.wgsl)
    let largeOpacity: CGFloat
    let largeSpeed: CGFloat
    let secondaryOpacity: CGFloat
    let secondarySpeed: CGFloat
    let detailOpacity: CGFloat
    let detailSpeed: CGFloat

    init(
        outer: PondRGBColor,
        inner: PondRGBColor,
        faint: PondRGBColor,
        alphaGain: CGFloat,
        largeOpacity: CGFloat = 0.99,
        largeSpeed: CGFloat = 1.0,
        secondaryOpacity: CGFloat = 0.15,
        secondarySpeed: CGFloat = 1.0,
        detailOpacity: CGFloat = 0.85,
        detailSpeed: CGFloat = 1.0
    ) {
        self.outer = outer
        self.inner = inner
        self.faint = faint
        self.alphaGain = alphaGain
        self.largeOpacity = largeOpacity
        self.largeSpeed = largeSpeed
        self.secondaryOpacity = secondaryOpacity
        self.secondarySpeed = secondarySpeed
        self.detailOpacity = detailOpacity
        self.detailSpeed = detailSpeed
    }
}

/// Atmospheric grading, weather tint, sunlight/moonlight beam, contrast, and vignette
/// conforming directly to Nagomi Desktop `10-weather-pass.wgsl`.
public struct PondWeatherGrade: Sendable {
    public let tint: (CGFloat, CGFloat, CGFloat)
    public let brightness: CGFloat
    public let contrast: CGFloat
    public let saturation: CGFloat
    public let vignette: CGFloat
    public let cloudStrength: CGFloat
    public let lightColor: (CGFloat, CGFloat, CGFloat)
    public let lightStrength: CGFloat
    public let lightDirection: (CGFloat, CGFloat)
    public let rainStrength: CGFloat

    public init(
        tint: (CGFloat, CGFloat, CGFloat),
        brightness: CGFloat = 1.0,
        contrast: CGFloat = 1.0,
        saturation: CGFloat = 1.0,
        vignette: CGFloat = 0.0,
        cloudStrength: CGFloat = 0.0,
        lightColor: (CGFloat, CGFloat, CGFloat),
        lightStrength: CGFloat,
        lightDirection: (CGFloat, CGFloat),
        rainStrength: CGFloat = 0.0
    ) {
        self.tint = tint
        self.brightness = brightness
        self.contrast = contrast
        self.saturation = saturation
        self.vignette = vignette
        self.cloudStrength = cloudStrength
        self.lightColor = lightColor
        self.lightStrength = lightStrength
        self.lightDirection = lightDirection
        self.rainStrength = rainStrength
    }

    public static func lerp(from a: PondWeatherGrade, to b: PondWeatherGrade, t: CGFloat) -> PondWeatherGrade {
        let p = max(0, min(1, t))
        func mix(_ x: CGFloat, _ y: CGFloat) -> CGFloat { x + (y - x) * p }
        return PondWeatherGrade(
            tint: (mix(a.tint.0, b.tint.0), mix(a.tint.1, b.tint.1), mix(a.tint.2, b.tint.2)),
            brightness: mix(a.brightness, b.brightness),
            contrast: mix(a.contrast, b.contrast),
            saturation: mix(a.saturation, b.saturation),
            vignette: mix(a.vignette, b.vignette),
            cloudStrength: mix(a.cloudStrength, b.cloudStrength),
            lightColor: (mix(a.lightColor.0, b.lightColor.0), mix(a.lightColor.1, b.lightColor.1), mix(a.lightColor.2, b.lightColor.2)),
            lightStrength: mix(a.lightStrength, b.lightStrength),
            lightDirection: (mix(a.lightDirection.0, b.lightDirection.0), mix(a.lightDirection.1, b.lightDirection.1)),
            rainStrength: mix(a.rainStrength, b.rainStrength)
        )
    }
}

struct PondRipplePalette {
    let brush: PondRGBColor
    let specular: PondRGBColor
    let bubble: PondRGBAColor
    let bubbleShadow: PondRGBAColor
}

/// Shared colors for the cached pond layers. Keeping theme values together makes
/// water, lighting, foliage, and reflections respond as one visual treatment.
struct PondThemePalette {
    let waterDepth: [PondRGBColor]
    let opening: PondRGBColor
    let deepWater: PondRGBColor
    let shelteredWater: PondRGBColor
    let waterLightGain: CGFloat
    let atmosphere: PondRGBAColor?
    let caustics: PondCausticPalette
    let shadow: PondLighting.ShadowStyle
    let fishAmbient: PondLighting.FishAmbientStyle
    let stems: PondRGBColor
    let duckweed: PondRGBColor
    let greens: [PondRGBColor]
    let leafBase: PondRGBColor
    let leafHighlight: PondRGBColor
    let leafGlaze: PondRGBAColor
    let leafVeins: PondRGBAColor
    let leafRim: PondRGBAColor
    let flowerPetal: PondRGBColor
    let flowerInnerPetal: PondRGBColor
    let flowerCenter: PondRGBColor
    let flowerCore: PondRGBColor
    let glimmer: PondRGBAColor
    let ripple: PondRipplePalette
    let weather: PondWeatherGrade

    static let foodRipple = PondRipplePalette(
        brush: PondRGBColor(hex: 0xF5A038),
        specular: PondRGBColor(hex: 0xFFF5D0),
        bubble: PondRGBAColor(color: PondRGBColor(hex: 0xFFA040), alpha: 0.50),
        bubbleShadow: PondRGBAColor(color: PondRGBColor(hex: 0x301808), alpha: 0.40)
    )

    private static let paletteCache: [PondTheme: PondThemePalette] = {
        Dictionary(uniqueKeysWithValues: PondTheme.allCases.map { ($0, makePalette($0)) })
    }()

    static func forTheme(_ theme: PondTheme) -> PondThemePalette {
        paletteCache[theme]!
    }

    private static func makePalette(_ theme: PondTheme) -> PondThemePalette {
        switch theme {
        case .day:
            return PondThemePalette(
                waterDepth: [rgb(0x76C6A5), rgb(0x56A886), rgb(0x3B8C6C), rgb(0x286F54), rgb(0x164C39)],
                opening: rgb(0x8EE0BE), deepWater: rgb(0x0E3B2C), shelteredWater: rgb(0x133827),
                waterLightGain: 1.0, atmosphere: nil,
                caustics: .init(outer: rgb(0x9BE5C4), inner: rgb(0xD8FFF0), faint: rgb(0x6CCB9F), alphaGain: 0.92,
                                largeOpacity: 0.99, largeSpeed: 1.0, secondaryOpacity: 0.15, secondarySpeed: 1.0, detailOpacity: 0.90, detailSpeed: 1.0),
                shadow: shadow(0x0A3628, core: 0.32, penumbra: 0.14, fish: 0.20),
                fishAmbient: fishAmbient(shade: 0x1A4C3A, shadeAlpha: 0.16, highlight: 0xFFF4D4, highlightAlpha: 0.18),
                stems: rgb(0x16442B), duckweed: rgb(0x84BE4E),
                greens: greens(0x225B33, 0x2E753E, 0x448F47, 0x2A6D3A),
                leafBase: rgb(0x18482A), leafHighlight: rgb(0x2F6F3F),
                leafGlaze: rgba(0x5E9E56, 0.38), leafVeins: rgba(0x0F331D, 0.88),
                leafRim: rgba(0x96D686, 0.35),
                flowerPetal: rgb(0xF26588), flowerInnerPetal: rgb(0xFFC0C8),
                flowerCenter: rgb(0xF7B63B), flowerCore: rgb(0x704020),
                glimmer: rgba(0xD4FFE9, 0.10),
                ripple: .init(brush: rgb(0x40D8C0), specular: rgb(0xF4FFFA), bubble: rgba(0x8EE0BE, 0.45), bubbleShadow: rgba(0x0A3628, 0.40)),
                weather: PondWeatherGrade(tint: (1.0, 1.0, 1.0), brightness: 1.0, contrast: 1.0, saturation: 1.0, vignette: 0.0, cloudStrength: 0.0, lightColor: (1.0, 0.94, 0.72), lightStrength: 0.0, lightDirection: (-0.58, 0.82), rainStrength: 0.0)
            )
        case .dawn:
            return PondThemePalette(
                waterDepth: [rgb(0xF5DDC7), rgb(0xACD3C4), rgb(0x5EA799), rgb(0x357870), rgb(0x1B4D4E)],
                opening: rgb(0xFFE5CE), deepWater: rgb(0x103E3F), shelteredWater: rgb(0x1A3B34),
                waterLightGain: 0.85, atmosphere: rgba(0xF5D3AA, 0.03),
                caustics: .init(outer: rgb(0xF7D8A8), inner: rgb(0xFFF2D6), faint: rgb(0xB8DAC8), alphaGain: 0.75,
                                largeOpacity: 0.4356, largeSpeed: 0.336, secondaryOpacity: 0.054, secondarySpeed: 0.252, detailOpacity: 0.288, detailSpeed: 0.42),
                shadow: shadow(0x123832, core: 0.28, penumbra: 0.12, fish: 0.18),
                fishAmbient: fishAmbient(shade: 0x2E5349, shadeAlpha: 0.16, highlight: 0xFFDEBC, highlightAlpha: 0.22),
                stems: rgb(0x204834), duckweed: rgb(0x9EB662),
                greens: greens(0x2E6340, 0x39734A, 0x518554, 0x357045),
                leafBase: rgb(0x1E5336), leafHighlight: rgb(0x3F7846),
                leafGlaze: rgba(0x9EB366, 0.35), leafVeins: rgba(0x18442E, 0.82),
                leafRim: rgba(0xE4C486, 0.38),
                flowerPetal: rgb(0xF57B8C), flowerInnerPetal: rgb(0xFFCCC2),
                flowerCenter: rgb(0xF6B445), flowerCore: rgb(0x6E4224),
                glimmer: rgba(0xFFE9D0, 0.08),
                ripple: .init(brush: rgb(0x52A699), specular: rgb(0xFFF0DE), bubble: rgba(0xFFD6B5, 0.45), bubbleShadow: rgba(0x123832, 0.40)),
                weather: PondWeatherGrade(tint: (1.0, 0.96, 0.92), brightness: 0.95, contrast: 1.02, saturation: 1.05, vignette: 0.12, cloudStrength: 0.10, lightColor: (1.0, 0.78, 0.65), lightStrength: 0.18, lightDirection: (-0.85, 0.53), rainStrength: 0.0)
            )
        case .goldenHour:
            return PondThemePalette(
                waterDepth: [rgb(0xF8D288), rgb(0xA5C9A4), rgb(0x569B88), rgb(0x2B6D6B), rgb(0x16444D)],
                opening: rgb(0xFFD97C), deepWater: rgb(0x0C373F), shelteredWater: rgb(0x203B2A),
                waterLightGain: 0.98, atmosphere: rgba(0xFFA834, 0.04),
                caustics: .init(outer: rgb(0xF6C66D), inner: rgb(0xFFE3A6), faint: rgb(0xC7A45A), alphaGain: 0.85,
                                largeOpacity: 0.9108, largeSpeed: 0.72, secondaryOpacity: 0.099, secondarySpeed: 0.50, detailOpacity: 0.468, detailSpeed: 0.86),
                shadow: shadow(0x153A37, core: 0.30, penumbra: 0.13, fish: 0.19),
                fishAmbient: fishAmbient(shade: 0x4D4326, shadeAlpha: 0.15, highlight: 0xFFE2A6, highlightAlpha: 0.24),
                stems: rgb(0x384828), duckweed: rgb(0xBCA342),
                greens: greens(0x3B5E36, 0x4E7038, 0x73813C, 0x466936),
                leafBase: rgb(0x2B5034), leafHighlight: rgb(0x65773A),
                leafGlaze: rgba(0xCAA345, 0.36), leafVeins: rgba(0x223E2A, 0.84),
                leafRim: rgba(0xF0D070, 0.46),
                flowerPetal: rgb(0xEF7560), flowerInnerPetal: rgb(0xFFCAA0),
                flowerCenter: rgb(0xF8BD44), flowerCore: rgb(0x724025),
                glimmer: rgba(0xFFE0A0, 0.09),
                ripple: .init(brush: rgb(0xE8B84B), specular: rgb(0xFFF5D6), bubble: rgba(0xFFE2A6, 0.50), bubbleShadow: rgba(0x153A37, 0.45)),
                weather: PondWeatherGrade(tint: (1.0, 0.94, 0.86), brightness: 1.0, contrast: 1.06, saturation: 1.10, vignette: 0.20, cloudStrength: 0.16, lightColor: (1.0, 0.42, 0.15), lightStrength: 0.22, lightDirection: (-0.70, 0.72), rainStrength: 0.0)
            )
        case .dusk:
            return PondThemePalette(
                waterDepth: [rgb(0xD88EAF), rgb(0x92789B), rgb(0x56607C), rgb(0x2E4564), rgb(0x182B49)],
                opening: rgb(0xF39DB8), deepWater: rgb(0x11213C), shelteredWater: rgb(0x24263D),
                waterLightGain: 0.65, atmosphere: rgba(0xB86E9F, 0.05),
                caustics: .init(outer: rgb(0xC995C2), inner: rgb(0xE8B8D4), faint: rgb(0x8D7CA8), alphaGain: 0.48,
                                largeOpacity: 0.7128, largeSpeed: 0.34, secondaryOpacity: 0.075, secondarySpeed: 0.24, detailOpacity: 0.702, detailSpeed: 0.44),
                shadow: shadow(0x171E3A, core: 0.25, penumbra: 0.11, fish: 0.16),
                fishAmbient: fishAmbient(shade: 0x3E3450, shadeAlpha: 0.17, highlight: 0xF2B8D5, highlightAlpha: 0.20),
                stems: rgb(0x26383E), duckweed: rgb(0x717D56),
                greens: greens(0x314D3E, 0x3E5844, 0x5C694D, 0x395140),
                leafBase: rgb(0x233A3E), leafHighlight: rgb(0x3A5449),
                leafGlaze: rgba(0x827699, 0.36), leafVeins: rgba(0x172B35, 0.86),
                leafRim: rgba(0xC793B3, 0.38),
                flowerPetal: rgb(0xD66F9C), flowerInnerPetal: rgb(0xE7B2CB),
                flowerCenter: rgb(0xE3A447), flowerCore: rgb(0x5F3248),
                glimmer: rgba(0xE6B6D6, 0.06),
                ripple: .init(brush: rgb(0x8A7CA8), specular: rgb(0xF3DCE8), bubble: rgba(0xD88EAF, 0.40), bubbleShadow: rgba(0x171E3A, 0.45)),
                weather: PondWeatherGrade(tint: (0.92, 0.88, 0.98), brightness: 0.88, contrast: 1.05, saturation: 1.02, vignette: 0.28, cloudStrength: 0.20, lightColor: (0.85, 0.52, 0.88), lightStrength: 0.16, lightDirection: (0.55, 0.83), rainStrength: 0.0)
            )
        case .night:
            return PondThemePalette(
                waterDepth: [rgb(0x26556D), rgb(0x1A4257), rgb(0x123243), rgb(0x0B2330), rgb(0x061620)],
                opening: rgb(0x3B7996), deepWater: rgb(0x04131C), shelteredWater: rgb(0x071A24),
                waterLightGain: 0.40, atmosphere: rgba(0x061D33, 0.08),
                caustics: .init(outer: rgb(0x3886A6), inner: rgb(0x69BCE0), faint: rgb(0x245E78), alphaGain: 0.34,
                                largeOpacity: 0.7128, largeSpeed: 0.34, secondaryOpacity: 0.075, secondarySpeed: 0.24, detailOpacity: 0.702, detailSpeed: 0.44),
                shadow: shadow(0x041119, core: 0.24, penumbra: 0.10, fish: 0.15),
                fishAmbient: fishAmbient(shade: 0x123648, shadeAlpha: 0.18, highlight: 0xA5E2F7, highlightAlpha: 0.16),
                stems: rgb(0x0D2524), duckweed: rgb(0x486237),
                greens: greens(0x1D3B33, 0x24463A, 0x33533D, 0x223F34),
                leafBase: rgb(0x122F2C), leafHighlight: rgb(0x1E4840),
                leafGlaze: rgba(0x2F645C, 0.30), leafVeins: rgba(0x071F22, 0.92),
                leafRim: rgba(0x5FA39D, 0.30),
                flowerPetal: rgb(0xA66896), flowerInnerPetal: rgb(0xCBA0C0),
                flowerCenter: rgb(0xD2A147), flowerCore: rgb(0x502F3C),
                glimmer: rgba(0x66BDE0, 0.04),
                ripple: .init(brush: rgb(0x2E6F94), specular: rgb(0xB8E6F8), bubble: rgba(0x3B7996, 0.35), bubbleShadow: rgba(0x041119, 0.50)),
                weather: PondWeatherGrade(tint: (0.82, 0.88, 1.0), brightness: 0.78, contrast: 1.08, saturation: 0.95, vignette: 0.42, cloudStrength: 0.30, lightColor: (0.46, 0.68, 1.0), lightStrength: 0.14, lightDirection: (0.68, 0.74), rainStrength: 0.0)
            )
        case .deepClear:
            return PondThemePalette(
                waterDepth: [rgb(0x7DF6EF), rgb(0x38D4C8), rgb(0x1DB2BC), rgb(0x137E97), rgb(0x094F6C)],
                opening: rgb(0x9DFFF2), deepWater: rgb(0x053F4A), shelteredWater: rgb(0x0A3F3F),
                waterLightGain: 1.10, atmosphere: nil,
                caustics: .init(outer: rgb(0x7EECE0), inner: rgb(0xD0FFF7), faint: rgb(0x4DC9C3), alphaGain: 1.05,
                                largeOpacity: 1.0, largeSpeed: 1.05, secondaryOpacity: 0.20, secondarySpeed: 1.0, detailOpacity: 0.95, detailSpeed: 1.10),
                shadow: shadow(0x053A44, core: 0.34, penumbra: 0.14, fish: 0.20),
                fishAmbient: fishAmbient(shade: 0x125557, shadeAlpha: 0.16, highlight: 0xD0FFF5, highlightAlpha: 0.20),
                stems: rgb(0x0D4E3E), duckweed: rgb(0x95C549),
                greens: greens(0x20603E, 0x297A4C, 0x429D56, 0x247046),
                leafBase: rgb(0x12553B), leafHighlight: rgb(0x2E7D4C),
                leafGlaze: rgba(0x5CAF64, 0.42), leafVeins: rgba(0x094231, 0.88),
                leafRim: rgba(0x84E0A0, 0.42),
                flowerPetal: rgb(0xF0688C), flowerInnerPetal: rgb(0xFFC2CE),
                flowerCenter: rgb(0xF7B63B), flowerCore: rgb(0x6E3E1F),
                glimmer: rgba(0xC2FFF3, 0.10),
                ripple: .init(brush: rgb(0x24C8C0), specular: rgb(0xD6FFFA), bubble: rgba(0x7DF6EF, 0.50), bubbleShadow: rgba(0x053A44, 0.45)),
                weather: PondWeatherGrade(tint: (0.96, 1.02, 1.0), brightness: 1.05, contrast: 1.02, saturation: 1.12, vignette: 0.0, cloudStrength: 0.02, lightColor: (0.92, 1.0, 0.98), lightStrength: 0.20, lightDirection: (-0.60, 0.80), rainStrength: 0.0)
            )
        case .rain:
            return PondThemePalette(
                waterDepth: [rgb(0x869FA1), rgb(0x658083), rgb(0x4A6568), rgb(0x314A4D), rgb(0x1E3336)],
                opening: rgb(0xA5BDBD), deepWater: rgb(0x182A2E), shelteredWater: rgb(0x223437),
                waterLightGain: 0.48, atmosphere: rgba(0x8CA8AC, 0.06),
                caustics: .init(outer: rgb(0x8EAEB0), inner: rgb(0xC4D8D8), faint: rgb(0x6D8C8E), alphaGain: 0.28,
                                largeOpacity: 0.35, largeSpeed: 0.50, secondaryOpacity: 0.06, secondarySpeed: 0.40, detailOpacity: 0.40, detailSpeed: 0.60),
                shadow: shadow(0x16292D, core: 0.24, penumbra: 0.11, fish: 0.15),
                fishAmbient: fishAmbient(shade: 0x374C51, shadeAlpha: 0.16, highlight: 0xD3E4E3, highlightAlpha: 0.16),
                stems: rgb(0x263B34), duckweed: rgb(0x7D8E58),
                greens: greens(0x324F3F, 0x3F5A47, 0x53684C, 0x385240),
                leafBase: rgb(0x284339), leafHighlight: rgb(0x42604B),
                leafGlaze: rgba(0x718B68, 0.32), leafVeins: rgba(0x1D3533, 0.85),
                leafRim: rgba(0xA0BA7F, 0.32),
                flowerPetal: rgb(0xCB788E), flowerInnerPetal: rgb(0xDFBAC1),
                flowerCenter: rgb(0xD0A65B), flowerCore: rgb(0x573C41),
                glimmer: rgba(0xC2D7D7, 0.06),
                ripple: .init(brush: rgb(0x6D8E92), specular: rgb(0xE0ECEC), bubble: rgba(0xA5BDBD, 0.40), bubbleShadow: rgba(0x16292D, 0.40)),
                weather: PondWeatherGrade(tint: (0.88, 0.92, 0.94), brightness: 0.85, contrast: 0.98, saturation: 0.88, vignette: 0.25, cloudStrength: 0.45, lightColor: (0.75, 0.85, 0.90), lightStrength: 0.10, lightDirection: (-0.40, 0.90), rainStrength: 1.0)
            )
        }
    }

    private static func rgb(_ hex: UInt32) -> PondRGBColor {
        PondRGBColor(hex: hex)
    }

    private static func rgba(_ hex: UInt32, _ alpha: CGFloat) -> PondRGBAColor {
        PondRGBAColor(color: rgb(hex), alpha: alpha)
    }

    private static func greens(_ first: UInt32, _ second: UInt32, _ third: UInt32, _ fourth: UInt32) -> [PondRGBColor] {
        [rgb(first), rgb(second), rgb(third), rgb(fourth)]
    }

    private static func shadow(_ color: UInt32, core: CGFloat, penumbra: CGFloat, fish: CGFloat) -> PondLighting.ShadowStyle {
        PondLighting.ShadowStyle(color: rgb(color).components, coreAlpha: core,
                                 penumbraAlpha: penumbra, smallFishAlpha: fish)
    }

    private static func fishAmbient(
        shade: UInt32,
        shadeAlpha: CGFloat,
        highlight: UInt32,
        highlightAlpha: CGFloat
    ) -> PondLighting.FishAmbientStyle {
        PondLighting.FishAmbientStyle(
            shadeColor: rgb(shade).components,
            shadeAlpha: shadeAlpha,
            highlightColor: rgb(highlight).components,
            highlightAlpha: highlightAlpha
        )
    }
}

extension PondTheme {
    var renderPalette: PondThemePalette { PondThemePalette.forTheme(self) }
    public var weatherGrade: PondWeatherGrade { PondThemePalette.forTheme(self).weather }
}
