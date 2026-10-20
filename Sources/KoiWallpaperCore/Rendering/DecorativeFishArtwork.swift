import CoreGraphics
import Foundation

/// Pure visual schooling. Samples depend only on active pond time and viewport;
/// there is no mutable simulation, additional clock, or access to the koi RNG.
enum DecorativeFishArtwork {
    static let fishPerSchool = 8
    static let schoolCount = 3
    static func draw(in context: CGContext, size: CGSize, time: Double) {
        let short = min(size.width, size.height)
        let centers = [CGPoint(x: 0.29, y: 0.34), CGPoint(x: 0.75, y: 0.30), CGPoint(x: 0.65, y: 0.73)]
        let colors = [CGColor(red: 0.96, green: 0.63, blue: 0.19, alpha: 0.92),
                      CGColor(red: 0.91, green: 0.34, blue: 0.33, alpha: 0.88),
                      CGColor(red: 0.29, green: 0.70, blue: 0.80, alpha: 0.86)]
        for group in 0..<schoolCount {
            var rng = SeededRandomNumberGenerator(seed: UInt64(700 + group * 443))
            let phase = time * (0.10 + Double(group) * 0.014) + Double(group) * 2.1
            let center = CGPoint(x: centers[group].x * size.width + CGFloat(sin(phase)) * short * 0.065,
                                 y: centers[group].y * size.height + CGFloat(sin(phase * 0.8 + 1)) * short * 0.055)
            let heading = atan2(cos(phase * 0.8 + 1) * 0.055 * 0.8, cos(phase) * 0.065)
            for index in 0..<fishPerSchool {
                let offsetX = CGFloat(Double.random(in: -0.065...0.065, using: &rng)) * short
                let offsetY = CGFloat(Double.random(in: -0.045...0.045, using: &rng)) * short
                let length = CGFloat(Double.random(in: 0.015...0.025, using: &rng)) * short
                let turn = heading + sin(time * 0.9 + Double(index)) * 0.14
                context.saveGState()
                context.translateBy(x: center.x + offsetX + CGFloat(sin(time * 0.7 + Double(index))) * short * 0.004,
                                    y: center.y + offsetY + CGFloat(cos(time * 0.6 + Double(index))) * short * 0.003)
                context.rotate(by: CGFloat(turn))
                context.setFillColor(red: 0.035, green: 0.21, blue: 0.16, alpha: 0.23)
                context.fillEllipse(in: CGRect(x: -length * 0.4, y: -length * 0.35, width: length, height: length * 0.35))
                let path = CGMutablePath()
                path.move(to: CGPoint(x: length * 0.5, y: 0))
                path.addLine(to: CGPoint(x: length * 0.10, y: length * 0.19))
                path.addLine(to: CGPoint(x: -length * 0.28, y: length * 0.10))
                let flutter = CGFloat(sin(time * 4 + Double(index) * 1.7)) * length * 0.10
                path.addLine(to: CGPoint(x: -length * 0.60, y: length * 0.18 + flutter))
                path.addLine(to: CGPoint(x: -length * 0.47, y: flutter))
                path.addLine(to: CGPoint(x: -length * 0.60, y: -length * 0.18 + flutter))
                path.addLine(to: CGPoint(x: -length * 0.28, y: -length * 0.10))
                path.addLine(to: CGPoint(x: length * 0.10, y: -length * 0.19))
                path.closeSubpath()
                context.setFillColor(colors[group])
                context.addPath(path)
                context.fillPath()
                context.setFillColor(red: 1, green: 0.91, blue: 0.65, alpha: 0.9)
                context.fill(CGRect(x: -length * 0.15, y: 0, width: length * 0.25, height: length * 0.14))
                context.restoreGState()
            }
        }
    }
}
