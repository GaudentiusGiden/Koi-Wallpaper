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
                waterDepth: [rgb(0x7EF2CB), rgb(0x55DAB2), rgb(0x36B596), rgb(0x24856F), rgb(0x15594C)],
                opening: rgb(0xA0F8D7), deepWater: rgb(0x0A4038), shelteredWater: rgb(0x0D3D2A),
                waterLightGain: 1.02, atmosphere: nil,
                caustics: .init(outer: rgb(0xA6F6D5), inner: rgb(0xD2FFE8), faint: rgb(0x78DDB7), alphaGain: 1.0),
                shadow: shadow(0x063C2E, core: 0.32, penumbra: 0.13, fish: 0.19),
                fishAmbient: fishAmbient(shade: 0x155843, shadeAlpha: 0.18, highlight: 0xFFF0C5, highlightAlpha: 0.18),
                stems: rgb(0x17482D), duckweed: rgb(0x8DBE55),
                greens: greens(0x28653A, 0x347C43, 0x4A914B, 0x307343),
                leafBase: rgb(0x185437), leafHighlight: rgb(0x347C4B),
                leafGlaze: rgba(0x65A85A, 0.42), leafVeins: rgba(0x123F2C, 0.88),
                leafRim: rgba(0xA8E18D, 0.38),
                flowerPetal: rgb(0xF66F91), flowerInnerPetal: rgb(0xFFC5D0),
                flowerCenter: rgb(0xF7B83E), flowerCore: rgb(0x704122),
                glimmer: rgba(0xD7FFE8, 0.10)
            )
        case .dawn:
            return PondThemePalette(
                waterDepth: [rgb(0xEBD0B4), rgb(0xA4D5C4), rgb(0x5BAF9F), rgb(0x347C73), rgb(0x194F50)],
                opening: rgb(0xFFE0BA), deepWater: rgb(0x0C403D), shelteredWater: rgb(0x183D32),
                waterLightGain: 0.78, atmosphere: rgba(0xF6D1A5, 0.025),
                caustics: .init(outer: rgb(0xF6D8A6), inner: rgb(0xFFF0D2), faint: rgb(0xB3D8C3), alphaGain: 0.72),
                shadow: shadow(0x123A34, core: 0.29, penumbra: 0.12, fish: 0.18),
                fishAmbient: fishAmbient(shade: 0x31564B, shadeAlpha: 0.16, highlight: 0xFFD7AD, highlightAlpha: 0.22),
                stems: rgb(0x214B36), duckweed: rgb(0xA4B86B),
                greens: greens(0x326845, 0x3D7950, 0x56895A, 0x39764B),
                leafBase: rgb(0x22583A), leafHighlight: rgb(0x477E4B),
                leafGlaze: rgba(0xA4B66B, 0.35), leafVeins: rgba(0x1C4932, 0.82),
                leafRim: rgba(0xE8C88C, 0.40),
                flowerPetal: rgb(0xF68191), flowerInnerPetal: rgb(0xFFD0C5),
                flowerCenter: rgb(0xF7B64B), flowerCore: rgb(0x704427),
                glimmer: rgba(0xFFE9CC, 0.08)
            )
        case .goldenHour:
            return PondThemePalette(
                waterDepth: [rgb(0xEFCB8E), rgb(0x91CBB7), rgb(0x4A9D91), rgb(0x286F6E), rgb(0x16464F)],
                opening: rgb(0xFFD279), deepWater: rgb(0x0B3940), shelteredWater: rgb(0x253F2B),
                waterLightGain: 0.95, atmosphere: rgba(0xFFB94D, 0.035),
                caustics: .init(outer: rgb(0xF4C56D), inner: rgb(0xFFE2A1), faint: rgb(0xC9A75C), alphaGain: 0.82),
                shadow: shadow(0x143D3A, core: 0.31, penumbra: 0.14, fish: 0.19),
                fishAmbient: fishAmbient(shade: 0x554829, shadeAlpha: 0.15, highlight: 0xFFE0A0, highlightAlpha: 0.24),
                stems: rgb(0x3D4E2C), duckweed: rgb(0xC2A847),
                greens: greens(0x41663B, 0x577A3E, 0x7D8B43, 0x4F733C),
                leafBase: rgb(0x31583A), leafHighlight: rgb(0x6F8141),
                leafGlaze: rgba(0xD2A94A, 0.35), leafVeins: rgba(0x28452F, 0.84),
                leafRim: rgba(0xF4D478, 0.48),
                flowerPetal: rgb(0xF17E69), flowerInnerPetal: rgb(0xFFD0A8),
                flowerCenter: rgb(0xF9C04A), flowerCore: rgb(0x754328),
                glimmer: rgba(0xFFE2A5, 0.09)
            )
        case .dusk:
            return PondThemePalette(
                waterDepth: [rgb(0xC886AA), rgb(0x80698D), rgb(0x4D5878), rgb(0x2A4162), rgb(0x172B49)],
                opening: rgb(0xF3A0A0), deepWater: rgb(0x101F3A), shelteredWater: rgb(0x28283F),
                waterLightGain: 0.62, atmosphere: rgba(0xB975A1, 0.045),
                caustics: .init(outer: rgb(0xC797C0), inner: rgb(0xE6B5D1), faint: rgb(0x8D7DA8), alphaGain: 0.46),
                shadow: shadow(0x171F3C, core: 0.25, penumbra: 0.11, fish: 0.16),
                fishAmbient: fishAmbient(shade: 0x403653, shadeAlpha: 0.17, highlight: 0xF0B9D4, highlightAlpha: 0.19),
                stems: rgb(0x293C43), duckweed: rgb(0x75825B),
                greens: greens(0x355443, 0x45614A, 0x647254, 0x405947),
                leafBase: rgb(0x263F43), leafHighlight: rgb(0x405C50),
                leafGlaze: rgba(0x887CA0, 0.38), leafVeins: rgba(0x1B303B, 0.86),
                leafRim: rgba(0xCB98B8, 0.38),
                flowerPetal: rgb(0xD976A2), flowerInnerPetal: rgb(0xEAB8D0),
                flowerCenter: rgb(0xE6A84C), flowerCore: rgb(0x61354B),
                glimmer: rgba(0xE7B9D8, 0.055)
            )
        case .night:
            return PondThemePalette(
                waterDepth: [rgb(0x3F7FA3), rgb(0x245779), rgb(0x163D60), rgb(0x0D2A49), rgb(0x071A32)],
                opening: rgb(0x5CA7C8), deepWater: rgb(0x071D37), shelteredWater: rgb(0x0A2633),
                waterLightGain: 0.38, atmosphere: rgba(0x0A2443, 0.08),
                caustics: .init(outer: rgb(0x4A8EB5), inner: rgb(0x7DC1DF), faint: rgb(0x315F85), alphaGain: 0.30),
                shadow: shadow(0x07172A, core: 0.22, penumbra: 0.09, fish: 0.14),
                fishAmbient: fishAmbient(shade: 0x214A6C, shadeAlpha: 0.19, highlight: 0xB6E3F5, highlightAlpha: 0.17),
                stems: rgb(0x102B29), duckweed: rgb(0x526C3F),
                greens: greens(0x24443B, 0x2B5141, 0x3C6148, 0x294A3D),
                leafBase: rgb(0x153532), leafHighlight: rgb(0x235149),
                leafGlaze: rgba(0x397269, 0.31), leafVeins: rgba(0x0A2629, 0.92),
                leafRim: rgba(0x71B7B0, 0.34),
                flowerPetal: rgb(0xAD709C), flowerInnerPetal: rgb(0xD1A9C7),
                flowerCenter: rgb(0xD9A74C), flowerCore: rgb(0x593544),
                glimmer: rgba(0x77C8E8, 0.035)
            )
        case .deepClear:
            return PondThemePalette(
                waterDepth: [rgb(0x8AF4E8), rgb(0x4BD9D2), rgb(0x27B1B8), rgb(0x167F96), rgb(0x0B506B)],
                opening: rgb(0xA7FFF0), deepWater: rgb(0x06404A), shelteredWater: rgb(0x0C4140),
                waterLightGain: 1.12, atmosphere: nil,
                caustics: .init(outer: rgb(0x85F0E3), inner: rgb(0xD3FFF7), faint: rgb(0x55CDC7), alphaGain: 1.08),
                shadow: shadow(0x063C45, core: 0.34, penumbra: 0.14, fish: 0.20),
                fishAmbient: fishAmbient(shade: 0x14585A, shadeAlpha: 0.16, highlight: 0xD1FFF5, highlightAlpha: 0.20),
                stems: rgb(0x0E5140), duckweed: rgb(0x9DCB4E),
                greens: greens(0x236642, 0x2D8050, 0x48A35B, 0x28764A),
                leafBase: rgb(0x145B3F), leafHighlight: rgb(0x328551),
                leafGlaze: rgba(0x61B66A, 0.43), leafVeins: rgba(0x0A4735, 0.88),
                leafRim: rgba(0x8AE5A6, 0.43),
                flowerPetal: rgb(0xF36F91), flowerInnerPetal: rgb(0xFFC6D2),
                flowerCenter: rgb(0xF7B83E), flowerCore: rgb(0x704122),
                glimmer: rgba(0xC6FFF4, 0.10)
            )
        case .rain:
            return PondThemePalette(
                waterDepth: [rgb(0xA3BABB), rgb(0x789698), rgb(0x536E74), rgb(0x354D56), rgb(0x20353E)],
                opening: rgb(0xC3D1CE), deepWater: rgb(0x20383D), shelteredWater: rgb(0x2E3D39),
                waterLightGain: 0.43, atmosphere: rgba(0xA0B6B9, 0.055),
                caustics: .init(outer: rgb(0xA8C1C2), inner: rgb(0xD4E0DE), faint: rgb(0x81999B), alphaGain: 0.28),
                shadow: shadow(0x1A3036, core: 0.24, penumbra: 0.12, fish: 0.15),
                fishAmbient: fishAmbient(shade: 0x40555B, shadeAlpha: 0.17, highlight: 0xD6E5E4, highlightAlpha: 0.17),
                stems: rgb(0x30463E), duckweed: rgb(0x8B9C64),
                greens: greens(0x3A5948, 0x4A6753, 0x62775A, 0x415D4B),
                leafBase: rgb(0x304F43), leafHighlight: rgb(0x4D6E58),
                leafGlaze: rgba(0x829A79, 0.34), leafVeins: rgba(0x243F3D, 0.84),
                leafRim: rgba(0xB3CBC0, 0.34),
                flowerPetal: rgb(0xD8859B), flowerInnerPetal: rgb(0xEBC6CD),
                flowerCenter: rgb(0xD8AE62), flowerCore: rgb(0x60464A),
                glimmer: rgba(0xD4E1E0, 0.06)
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
}
