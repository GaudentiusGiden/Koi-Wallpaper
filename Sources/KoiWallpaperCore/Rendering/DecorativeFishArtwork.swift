import CoreGraphics
import Foundation

/// Pure visual schooling. Samples depend only on active pond time and viewport;
/// there is no mutable simulation, additional clock, or access to the koi RNG.
public enum DecorativeFishArtwork {
    public static let fishPerSchool = 8
    public static let schoolCount = 3

    private struct FishPalette {
        let body: CGColor
        let belly: CGColor
        let bellyHighlight: CGColor
        let bellySheen: CGColor
        let pattern: CGColor
        let fin: CGColor
        let finAccent: CGColor
    }

    private struct SchoolFishInstance {
        let x: CGFloat
        let y: CGFloat
        let turn: Double
        let length: CGFloat
        let halfWidth: CGFloat
        let palette: FishPalette
        let index: Int
    }

    public static func draw(in context: CGContext, size: CGSize, time: Double, theme: PondTheme = .day, customShadowStyle: PondLighting.ShadowStyle? = nil) {
        let short = min(size.width, size.height)
        let centers = [CGPoint(x: 0.29, y: 0.34), CGPoint(x: 0.75, y: 0.30), CGPoint(x: 0.65, y: 0.73)]

        for group in 0..<schoolCount {
            var rng = SeededRandomNumberGenerator(seed: UInt64(700 + group * 443))
            let phaseAngle = time * (0.10 + Double(group) * 0.014) + Double(group) * 2.1
            let center = CGPoint(x: centers[group].x * size.width + CGFloat(sin(phaseAngle)) * short * 0.065,
                                 y: centers[group].y * size.height + CGFloat(sin(phaseAngle * 0.8 + 1)) * short * 0.055)
            let heading = atan2(cos(phaseAngle * 0.8 + 1) * 0.055 * 0.8, cos(phaseAngle) * 0.065)

            var instances: [SchoolFishInstance] = []
            instances.reserveCapacity(fishPerSchool)
            for index in 0..<fishPerSchool {
                let offsetX = CGFloat(Double.random(in: -0.065...0.065, using: &rng)) * short
                let offsetY = CGFloat(Double.random(in: -0.045...0.045, using: &rng)) * short
                let length = CGFloat(Double.random(in: 0.015...0.025, using: &rng)) * short
                let turn = heading + sin(time * 0.9 + Double(index)) * 0.14
                let halfWidth = length * 0.18
                let pal = palette(for: group, index: index)
                let px = center.x + offsetX + CGFloat(sin(time * 0.7 + Double(index))) * short * 0.004
                let py = center.y + offsetY + CGFloat(cos(time * 0.6 + Double(index))) * short * 0.003
                instances.append(SchoolFishInstance(x: px, y: py, turn: turn, length: length, halfWidth: halfWidth, palette: pal, index: index))
            }

            // 1. Soft aquatic drop shadow grounded on pond bed (all fish shadows under all fish)
            for fish in instances {
                context.saveGState()
                context.translateBy(x: fish.x, y: fish.y)
                context.rotate(by: CGFloat(fish.turn))
                drawShadow(in: context, length: fish.length, halfWidth: fish.halfWidth, heading: CGFloat(fish.turn), theme: theme, customShadowStyle: customShadowStyle)
                context.restoreGState()
            }

            // 2. Fish anatomy, fins, motifs, and eyes
            for fish in instances {
                context.saveGState()
                context.translateBy(x: fish.x, y: fish.y)
                context.rotate(by: CGFloat(fish.turn))
                drawPectoralFins(in: context, length: fish.length, halfWidth: fish.halfWidth, palette: fish.palette, time: time, index: fish.index)
                drawTailFin(in: context, length: fish.length, halfWidth: fish.halfWidth, palette: fish.palette, time: time, index: fish.index)
                drawTorso(in: context, length: fish.length, halfWidth: fish.halfWidth, palette: fish.palette, index: fish.index)
                drawEyes(in: context, length: fish.length, halfWidth: fish.halfWidth)
                context.restoreGState()
            }
        }
    }

    /// Renders autonomous simulated decorative fish schools with active schooling and evasive kinematics.
    public static func draw(
        schools: [DecorativeSchool],
        in context: CGContext,
        size: CGSize,
        time: Double,
        theme: PondTheme = .day,
        customShadowStyle: PondLighting.ShadowStyle? = nil
    ) {
        guard !schools.isEmpty else {
            draw(in: context, size: size, time: time, theme: theme, customShadowStyle: customShadowStyle)
            return
        }

        for school in schools {
            let group = school.groupIndex
            var instances: [(fish: DecorativeFishInstance, palette: FishPalette)] = []
            instances.reserveCapacity(school.fish.count)

            for fish in school.fish {
                let pal = palette(for: group, index: fish.index)
                instances.append((fish: fish, palette: pal))
            }

            // 1. Soft aquatic drop shadow grounded on pond bed (all fish shadows under all fish)
            for item in instances {
                let fish = item.fish
                context.saveGState()
                context.translateBy(x: CGFloat(fish.position.x), y: CGFloat(fish.position.y))
                context.rotate(by: CGFloat(fish.turn))
                drawShadow(
                    in: context,
                    length: CGFloat(fish.length),
                    halfWidth: CGFloat(fish.halfWidth),
                    heading: CGFloat(fish.turn),
                    theme: theme,
                    customShadowStyle: customShadowStyle
                )
                context.restoreGState()
            }

            // 2. Fish anatomy, fins, motifs, and eyes
            for item in instances {
                let fish = item.fish
                context.saveGState()
                context.translateBy(x: CGFloat(fish.position.x), y: CGFloat(fish.position.y))
                context.rotate(by: CGFloat(fish.turn))
                drawPectoralFins(
                    in: context,
                    length: CGFloat(fish.length),
                    halfWidth: CGFloat(fish.halfWidth),
                    palette: item.palette,
                    time: time,
                    index: fish.index,
                    phase: fish.swimPhase
                )
                drawTailFin(
                    in: context,
                    length: CGFloat(fish.length),
                    halfWidth: CGFloat(fish.halfWidth),
                    palette: item.palette,
                    time: time,
                    index: fish.index,
                    phase: fish.swimPhase
                )
                drawTorso(
                    in: context,
                    length: CGFloat(fish.length),
                    halfWidth: CGFloat(fish.halfWidth),
                    palette: item.palette,
                    index: fish.index
                )
                drawEyes(
                    in: context,
                    length: CGFloat(fish.length),
                    halfWidth: CGFloat(fish.halfWidth)
                )
                context.restoreGState()
            }
        }
    }

    public static func draw(in context: CGContext, size: CGSize, time: Double, phase: TimeOfDayPhase) {
        draw(in: context, size: size, time: time, theme: phase.theme)
    }

    // MARK: - School Color Palettes

    private static let cachedPalettes: [[FishPalette]] = {
        (0..<schoolCount).map { group in
            (0..<fishPerSchool).map { index in
                buildPalette(for: group, index: index)
            }
        }
    }()

    private static func palette(for group: Int, index: Int) -> FishPalette {
        let g = max(0, min(group, cachedPalettes.count - 1))
        let list = cachedPalettes[g]
        return list[index % list.count]
    }

    private static func buildPalette(for group: Int, index: Int) -> FishPalette {
        switch group {
        case 0:
            // Golden Amber / Medaka School: warm sunlight tones with scarlet & champagne accents
            let bodyTones: [(CGFloat, CGFloat, CGFloat)] = [
                (0.96, 0.63, 0.19), // 0: warm golden orange
                (0.98, 0.72, 0.24), // 1: sunny amber gold
                (0.91, 0.54, 0.16), // 2: rich honey copper
                (0.95, 0.67, 0.22), // 3: warm apricot
                (0.97, 0.76, 0.28), // 4: pale sunlight gold
                (0.93, 0.58, 0.18), // 5: deep amber
                (0.96, 0.65, 0.25), // 6: marigold
                (0.94, 0.70, 0.30)  // 7: champagne gold
            ]
            let tone = bodyTones[index % bodyTones.count]
            let patternTones: [CGColor] = [
                CGColor(red: 0.88, green: 0.35, blue: 0.14, alpha: 0.92), // 0: warm vermilion saddle
                CGColor(red: 1.00, green: 0.92, blue: 0.58, alpha: 0.95), // 1: golden streamer
                CGColor(red: 0.86, green: 0.28, blue: 0.14, alpha: 0.95), // 2: tancho crown
                CGColor(red: 0.08, green: 0.14, blue: 0.12, alpha: 0.85), // 3: sumi flecks
                CGColor(red: 0.99, green: 0.95, blue: 0.84, alpha: 0.92), // 4: pearl belly
                CGColor(red: 1.00, green: 0.90, blue: 0.50, alpha: 0.95), // 5: golden shimmer
                CGColor(red: 0.90, green: 0.38, blue: 0.16, alpha: 0.92), // 6: flame caudal dip
                CGColor(red: 1.00, green: 0.96, blue: 0.82, alpha: 0.90)  // 7: champagne pearl
            ]
            let belly = CGColor(red: 0.99, green: 0.94, blue: 0.82, alpha: 0.90)
            return FishPalette(
                body: CGColor(red: tone.0, green: tone.1, blue: tone.2, alpha: 0.94),
                belly: belly,
                bellyHighlight: belly.copy(alpha: 0.32)!,
                bellySheen: belly.copy(alpha: 0.65)!,
                pattern: patternTones[index % patternTones.count],
                fin: CGColor(red: tone.0, green: tone.1, blue: tone.2, alpha: 0.58),
                finAccent: CGColor(red: 1.00, green: 0.92, blue: 0.65, alpha: 0.85)
            )

        case 1:
            // Crimson Coral / Ruby Minnow School: rich rose-reds with peach & sumi accents
            let bodyTones: [(CGFloat, CGFloat, CGFloat)] = [
                (0.91, 0.34, 0.33), // 0: coral red
                (0.87, 0.26, 0.30), // 1: rose crimson
                (0.93, 0.42, 0.32), // 2: warm vermilion
                (0.84, 0.22, 0.28), // 3: deep scarlet ruby
                (0.94, 0.46, 0.40), // 4: salmon coral
                (0.90, 0.30, 0.26), // 5: cherry red
                (0.88, 0.28, 0.34), // 6: ruby rose
                (0.95, 0.48, 0.38)  // 7: soft flame coral
            ]
            let tone = bodyTones[index % bodyTones.count]
            let patternTones: [CGColor] = [
                CGColor(red: 0.72, green: 0.16, blue: 0.20, alpha: 0.92), // 0: deep ruby saddle
                CGColor(red: 1.00, green: 0.86, blue: 0.70, alpha: 0.95), // 1: peach-gold streamer
                CGColor(red: 0.98, green: 0.92, blue: 0.82, alpha: 0.95), // 2: cream tancho crown
                CGColor(red: 0.10, green: 0.10, blue: 0.12, alpha: 0.85), // 3: sumi flecks
                CGColor(red: 0.99, green: 0.94, blue: 0.88, alpha: 0.92), // 4: soft cream belly
                CGColor(red: 1.00, green: 0.82, blue: 0.65, alpha: 0.95), // 5: peach shimmer
                CGColor(red: 0.78, green: 0.18, blue: 0.22, alpha: 0.92), // 6: ruby caudal dip
                CGColor(red: 1.00, green: 0.94, blue: 0.90, alpha: 0.90)  // 7: rose-pearl sheen
            ]
            let belly = CGColor(red: 0.99, green: 0.92, blue: 0.86, alpha: 0.90)
            return FishPalette(
                body: CGColor(red: tone.0, green: tone.1, blue: tone.2, alpha: 0.92),
                belly: belly,
                bellyHighlight: belly.copy(alpha: 0.32)!,
                bellySheen: belly.copy(alpha: 0.65)!,
                pattern: patternTones[index % patternTones.count],
                fin: CGColor(red: tone.0, green: tone.1 * 1.1, blue: tone.2 * 1.1, alpha: 0.55),
                finAccent: CGColor(red: 1.00, green: 0.88, blue: 0.82, alpha: 0.85)
            )

        default:
            // Jade Turquoise / River Minnow School (Group 2): cool serene aquas with silver & teal accents
            let bodyTones: [(CGFloat, CGFloat, CGFloat)] = [
                (0.29, 0.70, 0.80), // 0: teal turquoise
                (0.36, 0.76, 0.83), // 1: pale cyan mint
                (0.24, 0.62, 0.74), // 2: deep jade aqua
                (0.32, 0.72, 0.81), // 3: seafoam turquoise
                (0.26, 0.67, 0.77), // 4: aquamarine
                (0.42, 0.80, 0.86), // 5: glacier blue
                (0.25, 0.63, 0.75), // 6: river cyan
                (0.38, 0.75, 0.79)  // 7: opal mint
            ]
            let tone = bodyTones[index % bodyTones.count]
            let patternTones: [CGColor] = [
                CGColor(red: 0.14, green: 0.54, blue: 0.64, alpha: 0.92), // 0: deep teal saddle
                CGColor(red: 0.85, green: 0.98, blue: 1.00, alpha: 0.95), // 1: ice-silver streamer
                CGColor(red: 0.88, green: 0.96, blue: 0.62, alpha: 0.95), // 2: chartreuse tancho
                CGColor(red: 0.08, green: 0.16, blue: 0.18, alpha: 0.85), // 3: slate sumi flecks
                CGColor(red: 0.90, green: 0.98, blue: 0.98, alpha: 0.92), // 4: opal belly
                CGColor(red: 0.70, green: 0.95, blue: 1.00, alpha: 0.95), // 5: aqua shimmer
                CGColor(red: 0.18, green: 0.58, blue: 0.70, alpha: 0.92), // 6: deep aqua dip
                CGColor(red: 0.88, green: 0.98, blue: 0.98, alpha: 0.90)  // 7: opal pearl sheen
            ]
            let belly = CGColor(red: 0.88, green: 0.96, blue: 0.96, alpha: 0.88)
            return FishPalette(
                body: CGColor(red: tone.0, green: tone.1, blue: tone.2, alpha: 0.90),
                belly: belly,
                bellyHighlight: belly.copy(alpha: 0.32)!,
                bellySheen: belly.copy(alpha: 0.65)!,
                pattern: patternTones[index % patternTones.count],
                fin: CGColor(red: tone.0, green: tone.1, blue: tone.2, alpha: 0.52),
                finAccent: CGColor(red: 0.82, green: 0.97, blue: 1.00, alpha: 0.85)
            )
        }
    }

    // MARK: - Anatomy & Markings

    private static func drawShadow(
        in context: CGContext,
        length: CGFloat,
        halfWidth: CGFloat,
        heading: CGFloat,
        theme: PondTheme = .day,
        customShadowStyle: PondLighting.ShadowStyle? = nil
    ) {
        let style = customShadowStyle ?? PondLighting.shadowStyle(for: theme)
        context.setFillColor(red: style.color.0, green: style.color.1, blue: style.color.2, alpha: style.smallFishAlpha)
        let worldOffset = PondLighting.shadowOffset(distance: length * 0.28)
        // The fish context is rotated; undo that rotation for the light vector.
        let shadowOffset = CGPoint(x: cos(heading) * worldOffset.x + sin(heading) * worldOffset.y,
                                   y: -sin(heading) * worldOffset.x + cos(heading) * worldOffset.y)
        context.fillEllipse(in: CGRect(
            x: -length * 0.42 + shadowOffset.x,
            y: -halfWidth * 0.90 + shadowOffset.y,
            width: length * 0.94,
            height: halfWidth * 1.85
        ))
    }

    private static func drawPectoralFins(
        in context: CGContext,
        length: CGFloat,
        halfWidth: CGFloat,
        palette: FishPalette,
        time: Double,
        index: Int,
        phase: Double? = nil
    ) {
        let p = phase ?? (time * 3.8 + Double(index) * 1.4)
        let finStroke = CGFloat(sin(p)) * length * 0.025
        for side: CGFloat in [-1.0, 1.0] {
            let fin = CGMutablePath()
            fin.move(to: CGPoint(x: length * 0.14, y: side * halfWidth * 0.70))
            fin.addLine(to: CGPoint(x: -length * 0.04, y: side * (halfWidth * 1.60 + finStroke * side)))
            fin.addLine(to: CGPoint(x: 0, y: side * halfWidth * 0.75))
            fin.closeSubpath()

            context.setFillColor(palette.fin)
            context.addPath(fin)
            context.fillPath()

            context.setStrokeColor(palette.finAccent)
            context.setLineWidth(max(0.5, length * 0.03))
            context.move(to: CGPoint(x: length * 0.14, y: side * halfWidth * 0.70))
            context.addLine(to: CGPoint(x: -length * 0.04, y: side * (halfWidth * 1.60 + finStroke * side)))
            context.strokePath()
        }
    }

    private static func drawTailFin(
        in context: CGContext,
        length: CGFloat,
        halfWidth: CGFloat,
        palette: FishPalette,
        time: Double,
        index: Int,
        phase: Double? = nil
    ) {
        let p = phase ?? (time * 4.2 + Double(index) * 1.7)
        let flutter = CGFloat(sin(p)) * length * 0.10
        let tail = CGMutablePath()
        tail.move(to: CGPoint(x: -length * 0.26, y: halfWidth * 0.35))
        tail.addQuadCurve(to: CGPoint(x: -length * 0.62, y: halfWidth * 1.05 + flutter),
                          control: CGPoint(x: -length * 0.44, y: halfWidth * 0.85 + flutter * 0.5))
        tail.addLine(to: CGPoint(x: -length * 0.47, y: flutter))
        tail.addLine(to: CGPoint(x: -length * 0.62, y: -halfWidth * 1.05 + flutter))
        tail.addQuadCurve(to: CGPoint(x: -length * 0.26, y: -halfWidth * 0.35),
                          control: CGPoint(x: -length * 0.44, y: -halfWidth * 0.85 + flutter * 0.5))
        tail.closeSubpath()

        context.setFillColor(palette.fin)
        context.addPath(tail)
        context.fillPath()

        // Delicate fin rays / margin accents
        context.setStrokeColor(palette.finAccent)
        context.setLineWidth(max(0.5, length * 0.035))
        context.move(to: CGPoint(x: -length * 0.30, y: 0))
        context.addLine(to: CGPoint(x: -length * 0.60, y: halfWidth * 0.90 + flutter))
        context.move(to: CGPoint(x: -length * 0.30, y: 0))
        context.addLine(to: CGPoint(x: -length * 0.60, y: -halfWidth * 0.90 + flutter))
        context.strokePath()
    }

    private static func drawTorso(
        in context: CGContext,
        length: CGFloat,
        halfWidth: CGFloat,
        palette: FishPalette,
        index: Int
    ) {
        let body = CGMutablePath()
        body.move(to: CGPoint(x: length * 0.50, y: 0))
        body.addQuadCurve(to: CGPoint(x: length * 0.12, y: halfWidth),
                          control: CGPoint(x: length * 0.36, y: halfWidth * 0.85))
        body.addQuadCurve(to: CGPoint(x: -length * 0.28, y: halfWidth * 0.38),
                          control: CGPoint(x: -length * 0.10, y: halfWidth * 0.85))
        body.addLine(to: CGPoint(x: -length * 0.28, y: -halfWidth * 0.38))
        body.addQuadCurve(to: CGPoint(x: length * 0.12, y: -halfWidth),
                          control: CGPoint(x: -length * 0.10, y: -halfWidth * 0.85))
        body.addQuadCurve(to: CGPoint(x: length * 0.50, y: 0),
                          control: CGPoint(x: length * 0.36, y: -halfWidth * 0.85))
        body.closeSubpath()

        // Base torso fill
        context.setFillColor(palette.body)
        context.addPath(body)
        context.fillPath()

        // Clip markings and depth layers to the body outline
        context.saveGState()
        context.addPath(body)
        context.clip()

        // 1. Soft underside depth shade (ambient aquatic shadow)
        context.setFillColor(red: 0.04, green: 0.18, blue: 0.15, alpha: 0.22)
        context.fill(CGRect(x: -length * 0.40, y: -halfWidth * 1.10, width: length * 0.95, height: halfWidth * 0.75))

        // 2. Subtle dorsal midline highlight catching overhead pond light
        context.setStrokeColor(palette.bellyHighlight)
        context.setLineWidth(max(0.6, length * 0.04))
        context.move(to: CGPoint(x: length * 0.32, y: halfWidth * 0.10))
        context.addLine(to: CGPoint(x: -length * 0.20, y: halfWidth * 0.05))
        context.strokePath()

        // 3. Distinct organic motif per fish
        drawMotif(in: context, length: length, halfWidth: halfWidth, palette: palette, motif: index % 8)

        context.restoreGState()
    }

    private static func drawMotif(
        in context: CGContext,
        length: CGFloat,
        halfWidth: CGFloat,
        palette: FishPalette,
        motif: Int
    ) {
        switch motif {
        case 0:
            // Kohaku / Twin Saddle Patches
            context.setFillColor(palette.pattern)
            context.fillEllipse(in: CGRect(
                x: length * 0.04, y: -halfWidth * 0.45,
                width: length * 0.22, height: halfWidth * 1.25
            ))
            context.fillEllipse(in: CGRect(
                x: -length * 0.22, y: -halfWidth * 0.55,
                width: length * 0.16, height: halfWidth * 0.95
            ))

        case 1:
            // Medaka Lateral Streamer
            context.setStrokeColor(palette.pattern)
            context.setLineWidth(max(0.8, length * 0.075))
            context.move(to: CGPoint(x: length * 0.25, y: halfWidth * 0.18))
            context.addQuadCurve(to: CGPoint(x: -length * 0.22, y: 0),
                                 control: CGPoint(x: 0, y: halfWidth * 0.12))
            context.strokePath()

        case 2:
            // Tancho Crown
            context.setFillColor(palette.pattern)
            context.fillEllipse(in: CGRect(
                x: length * 0.25, y: -halfWidth * 0.45,
                width: length * 0.15, height: halfWidth * 0.90
            ))

        case 3:
            // Bekko / Sumi Flecks
            context.setFillColor(palette.pattern)
            context.fillEllipse(in: CGRect(
                x: length * 0.16, y: halfWidth * 0.15,
                width: length * 0.08, height: halfWidth * 0.45
            ))
            context.fillEllipse(in: CGRect(
                x: -length * 0.04, y: -halfWidth * 0.55,
                width: length * 0.09, height: halfWidth * 0.50
            ))
            context.fillEllipse(in: CGRect(
                x: -length * 0.20, y: halfWidth * 0.05,
                width: length * 0.07, height: halfWidth * 0.40
            ))

        case 4:
            // Countershaded Two-Tone Belly
            context.setFillColor(palette.belly)
            let bellyPath = CGMutablePath()
            bellyPath.move(to: CGPoint(x: length * 0.38, y: 0))
            bellyPath.addQuadCurve(to: CGPoint(x: -length * 0.25, y: 0),
                                   control: CGPoint(x: 0, y: -halfWidth * 0.35))
            bellyPath.addLine(to: CGPoint(x: -length * 0.25, y: -halfWidth * 1.10))
            bellyPath.addLine(to: CGPoint(x: length * 0.38, y: -halfWidth * 1.10))
            bellyPath.closeSubpath()
            context.addPath(bellyPath)
            context.fillPath()

        case 5:
            // Twin Shimmer Scales
            context.setFillColor(palette.pattern)
            context.fillEllipse(in: CGRect(
                x: length * 0.04, y: halfWidth * 0.05,
                width: length * 0.11, height: halfWidth * 0.55
            ))
            context.fillEllipse(in: CGRect(
                x: -length * 0.12, y: -halfWidth * 0.45,
                width: length * 0.10, height: halfWidth * 0.50
            ))

        case 6:
            // Caudal Dip / Flame Tail
            context.setFillColor(palette.pattern)
            context.fill(CGRect(
                x: -length * 0.26, y: -halfWidth,
                width: length * 0.15, height: halfWidth * 2.0
            ))

        default:
            // Pearl Minimalist with Soft Dorsal Sheen
            context.setFillColor(palette.bellySheen)
            context.fillEllipse(in: CGRect(
                x: -length * 0.10, y: -halfWidth * 0.55,
                width: length * 0.34, height: halfWidth * 1.10
            ))
        }
    }

    private static func drawEyes(in context: CGContext, length: CGFloat, halfWidth: CGFloat) {
        let eyeX = length * 0.28
        let eyeOffset = halfWidth * 0.75
        let eyeSize = max(0.35, min(0.60, length * 0.022))

        // Soft aquatic ink tint: darkens the lateral head naturally without harsh black clumping
        context.setFillColor(red: 0.06, green: 0.15, blue: 0.13, alpha: 0.65)
        for side: CGFloat in [-1.0, 1.0] {
            context.fill(CGRect(
                x: eyeX - eyeSize * 0.5,
                y: side * eyeOffset - eyeSize * 0.5,
                width: eyeSize,
                height: eyeSize
            ))
        }
    }
}
