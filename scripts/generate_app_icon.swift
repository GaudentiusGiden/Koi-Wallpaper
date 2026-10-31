#!/usr/bin/env swift
import AppKit
import CoreGraphics
import Foundation

let fileManager = FileManager.default
let scriptURL = URL(fileURLWithPath: CommandLine.arguments[0]).standardizedFileURL
let projectDir = scriptURL.deletingLastPathComponent().deletingLastPathComponent()
let buildDir = projectDir.appendingPathComponent("build")
let iconsetDir = buildDir.appendingPathComponent("AppIcon.iconset")
let icnsOutputURL = buildDir.appendingPathComponent("AppIcon.icns")

try? fileManager.removeItem(at: iconsetDir)
try fileManager.createDirectory(at: iconsetDir, withIntermediateDirectories: true)

let colorSpace = CGColorSpaceCreateDeviceRGB()

func rgba(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1.0) -> CGColor {
    CGColor(red: r / 255.0, green: g / 255.0, blue: b / 255.0, alpha: a)
}

func interpolateSpline(_ pts: [CGPoint], subdivisions: Int = 8) -> [CGPoint] {
    guard pts.count >= 2 else { return pts }
    var result: [CGPoint] = []
    for i in 0..<(pts.count - 1) {
        let p0 = pts[max(0, i - 1)]
        let p1 = pts[i]
        let p2 = pts[i + 1]
        let p3 = pts[min(pts.count - 1, i + 2)]
        for step in 0..<subdivisions {
            let t = CGFloat(step) / CGFloat(subdivisions)
            let t2 = t * t
            let t3 = t2 * t
            let x = 0.5 * ((2.0 * p1.x) + (-p0.x + p2.x) * t + (2.0 * p0.x - 5.0 * p1.x + 4.0 * p2.x - p3.x) * t2 + (-p0.x + 3.0 * p1.x - 3.0 * p2.x + p3.x) * t3)
            let y = 0.5 * ((2.0 * p1.y) + (-p0.y + p2.y) * t + (2.0 * p0.y - 5.0 * p1.y + 4.0 * p2.y - p3.y) * t2 + (-p0.y + 3.0 * p1.y - 3.0 * p2.y + p3.y) * t3)
            result.append(CGPoint(x: x, y: y))
        }
    }
    if let last = pts.last {
        result.append(last)
    }
    return result
}

func koiProfileWidth(t: CGFloat, maxHalfWidth: CGFloat) -> CGFloat {
    if t < 0.24 {
        let u = t / 0.24
        return maxHalfWidth * sqrt(max(0.0, 1.0 - (1.0 - u) * (1.0 - u)))
    } else {
        let u = (t - 0.24) / 0.76
        let taper = pow(1.0 - u, 1.35) * 0.82 + (1.0 - u) * 0.18
        return maxHalfWidth * max(0.18, taper)
    }
}

func renderZenArcAppIcon(pixelSize: Int) -> Data {
    let s = CGFloat(pixelSize)
    guard let ctx = CGContext(
        data: nil,
        width: pixelSize,
        height: pixelSize,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else {
        fatalError("Failed to create CGContext for size \(pixelSize)")
    }

    // Flip to top-left coordinate system
    ctx.translateBy(x: 0, y: s)
    ctx.scaleBy(x: 1, y: -1)

    // Follow macOS Sonoma/Big Sur icon grid (824/1024 squircle with soft drop shadow)
    let margin = s * 0.092
    let squircleRect = CGRect(x: margin, y: margin, width: s - margin * 2, height: s - margin * 2)
    let cornerRadius = squircleRect.width * 0.225
    let squirclePath = CGPath(roundedRect: squircleRect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)

    // Outer ambient shadow
    ctx.saveGState()
    ctx.setShadow(
        offset: CGSize(width: 0, height: s * 0.022),
        blur: s * 0.048,
        color: rgba(0, 0, 0, 0.45)
    )
    ctx.setFillColor(rgba(10, 28, 34))
    ctx.addPath(squirclePath)
    ctx.fillPath()
    ctx.restoreGState()

    // Clip inside squircle
    ctx.saveGState()
    ctx.addPath(squirclePath)
    ctx.clip()

    // Deep abyssal teal-jade pond background gradient
    let gradColors = [rgba(16, 48, 56), rgba(7, 22, 28)] as CFArray
    if let grad = CGGradient(colorsSpace: colorSpace, colors: gradColors, locations: [0.0, 1.0]) {
        ctx.drawLinearGradient(
            grad,
            start: CGPoint(x: squircleRect.minX, y: squircleRect.minY),
            end: CGPoint(x: squircleRect.maxX, y: squircleRect.maxY),
            options: []
        )
    }

    let boxW = squircleRect.width
    let cx = squircleRect.midX + boxW * 0.02
    let cy = squircleRect.midY + boxW * 0.02

    // Subtle glowing pond aura
    let auraColors = [rgba(48, 145, 150, 0.26), rgba(10, 30, 36, 0.0)] as CFArray
    if let aura = CGGradient(colorsSpace: colorSpace, colors: auraColors, locations: [0.0, 1.0]) {
        ctx.drawRadialGradient(
            aura,
            startCenter: CGPoint(x: cx, y: cy),
            startRadius: 0,
            endCenter: CGPoint(x: cx, y: cy),
            endRadius: boxW * 0.45,
            options: []
        )
    }

    let arcR = boxW * 0.245

    // Minimalist Enso water ripple arcs completing the circle
    ctx.saveGState()
    ctx.setStrokeColor(rgba(165, 228, 222, 0.34))
    ctx.setLineWidth(boxW * 0.018)
    ctx.setLineCap(.round)
    ctx.addArc(center: CGPoint(x: cx, y: cy), radius: arcR, startAngle: 0.08, endAngle: 1.95, clockwise: false)
    ctx.strokePath()

    ctx.setStrokeColor(rgba(165, 228, 222, 0.16))
    ctx.setLineWidth(boxW * 0.011)
    ctx.addArc(center: CGPoint(x: cx, y: cy), radius: arcR * 1.24, startAngle: 0.22, endAngle: 1.65, clockwise: false)
    ctx.strokePath()
    ctx.restoreGState()

    // Zen Arc Koi geometry
    let angles: [CGFloat] = [-0.42, -0.95, -1.52, -2.10, -2.65, -3.15]
    let controlSpine = angles.map { a in
        CGPoint(x: cx + cos(a) * arcR, y: cy + sin(a) * arcR)
    }
    let spine = interpolateSpline(controlSpine, subdivisions: 8)
    let n = spine.count
    let maxHalfWidth = boxW * 0.095
    var tangents: [CGPoint] = []
    var normals: [CGPoint] = []

    for i in 0..<n {
        let prev = spine[max(0, i - 1)]
        let next = spine[min(n - 1, i + 1)]
        let dx = next.x - prev.x
        let dy = next.y - prev.y
        let len = max(0.0001, hypot(dx, dy))
        let tx = dx / len
        let ty = dy / len
        tangents.append(CGPoint(x: tx, y: ty))
        normals.append(CGPoint(x: -ty, y: tx))
    }

    var leftPts: [CGPoint] = []
    var rightPts: [CGPoint] = []
    for i in 0..<n {
        let t = CGFloat(i) / CGFloat(n - 1)
        let w = koiProfileWidth(t: t, maxHalfWidth: maxHalfWidth)
        let p = spine[i]
        let nm = normals[i]
        leftPts.append(CGPoint(x: p.x + nm.x * w, y: p.y + nm.y * w))
        rightPts.append(CGPoint(x: p.x - nm.x * w, y: p.y - nm.y * w))
    }

    let torso = CGMutablePath()
    let noseTip = CGPoint(
        x: spine[0].x - tangents[0].x * maxHalfWidth * 0.22,
        y: spine[0].y - tangents[0].y * maxHalfWidth * 0.22
    )
    torso.move(to: noseTip)
    for pt in leftPts {
        torso.addLine(to: pt)
    }
    for pt in rightPts.reversed() {
        torso.addLine(to: pt)
    }
    torso.closeSubpath()

    // Pectoral fins
    let finStartIdx = max(1, Int(Double(n - 1) * 0.21))
    let finEndIdx = min(n - 1, Int(Double(n - 1) * 0.39))
    let finMidIdx = (finStartIdx + finEndIdx) / 2
    let finTan = tangents[finMidIdx]
    let finNorm = normals[finMidIdx]
    let finSpan = maxHalfWidth * 1.18
    let finSweep = maxHalfWidth * 1.35

    let leftFin = CGMutablePath()
    let lStart = leftPts[finStartIdx]
    let lEnd = leftPts[finEndIdx]
    let lTip = CGPoint(
        x: lStart.x + finNorm.x * finSpan + finTan.x * finSweep * 0.72,
        y: lStart.y + finNorm.y * finSpan + finTan.y * finSweep * 0.72
    )
    leftFin.move(to: lStart)
    leftFin.addQuadCurve(
        to: lTip,
        control: CGPoint(
            x: lStart.x + finNorm.x * finSpan * 1.05 + finTan.x * finSweep * 0.08,
            y: lStart.y + finNorm.y * finSpan * 1.05 + finTan.y * finSweep * 0.08
        )
    )
    leftFin.addQuadCurve(
        to: lEnd,
        control: CGPoint(
            x: lEnd.x + finNorm.x * finSpan * 0.45 + finTan.x * finSweep * 0.25,
            y: lEnd.y + finNorm.y * finSpan * 0.45 + finTan.y * finSweep * 0.25
        )
    )
    leftFin.closeSubpath()

    let rightFin = CGMutablePath()
    let rStart = rightPts[finStartIdx]
    let rEnd = rightPts[finEndIdx]
    let rTip = CGPoint(
        x: rStart.x - finNorm.x * (finSpan * 0.92) + finTan.x * finSweep * 0.72,
        y: rStart.y - finNorm.y * (finSpan * 0.92) + finTan.y * finSweep * 0.72
    )
    rightFin.move(to: rStart)
    rightFin.addQuadCurve(
        to: rTip,
        control: CGPoint(
            x: rStart.x - finNorm.x * finSpan * 0.96 + finTan.x * finSweep * 0.08,
            y: rStart.y - finNorm.y * finSpan * 0.96 + finTan.y * finSweep * 0.08
        )
    )
    rightFin.addQuadCurve(
        to: rEnd,
        control: CGPoint(
            x: rEnd.x - finNorm.x * finSpan * 0.42 + finTan.x * finSweep * 0.25,
            y: rEnd.y - finNorm.y * finSpan * 0.42 + finTan.y * finSweep * 0.25
        )
    )
    rightFin.closeSubpath()

    // Caudal tail
    let tailBase = spine[n - 1]
    let tailTan = tangents[n - 1]
    let tailNorm = normals[n - 1]
    let tailLen = maxHalfWidth * 2.05
    let tailSpread = maxHalfWidth * 1.55

    let lobeL = CGPoint(
        x: tailBase.x + tailTan.x * tailLen + tailNorm.x * tailSpread,
        y: tailBase.y + tailTan.y * tailLen + tailNorm.y * tailSpread
    )
    let notch = CGPoint(
        x: tailBase.x + tailTan.x * (tailLen * 0.56) + tailNorm.x * (tailSpread * 0.06),
        y: tailBase.y + tailTan.y * (tailLen * 0.56) + tailNorm.y * (tailSpread * 0.06)
    )
    let lobeR = CGPoint(
        x: tailBase.x + tailTan.x * (tailLen * 0.92) - tailNorm.x * (tailSpread * 0.85),
        y: tailBase.y + tailTan.y * (tailLen * 0.92) - tailNorm.y * (tailSpread * 0.85)
    )

    let tail = CGMutablePath()
    tail.move(to: leftPts[n - 1])
    tail.addQuadCurve(
        to: lobeL,
        control: CGPoint(
            x: tailBase.x + tailTan.x * tailLen * 0.45 + tailNorm.x * tailSpread * 0.98,
            y: tailBase.y + tailTan.y * tailLen * 0.45 + tailNorm.y * tailSpread * 0.98
        )
    )
    tail.addQuadCurve(
        to: notch,
        control: CGPoint(
            x: tailBase.x + tailTan.x * tailLen * 0.82 + tailNorm.x * tailSpread * 0.28,
            y: tailBase.y + tailTan.y * tailLen * 0.82 + tailNorm.y * tailSpread * 0.28
        )
    )
    tail.addQuadCurve(
        to: lobeR,
        control: CGPoint(
            x: tailBase.x + tailTan.x * tailLen * 0.78 - tailNorm.x * tailSpread * 0.25,
            y: tailBase.y + tailTan.y * tailLen * 0.78 - tailNorm.y * tailSpread * 0.25
        )
    )
    tail.addQuadCurve(
        to: rightPts[n - 1],
        control: CGPoint(
            x: tailBase.x + tailTan.x * tailLen * 0.42 - tailNorm.x * tailSpread * 0.82,
            y: tailBase.y + tailTan.y * tailLen * 0.42 - tailNorm.y * tailSpread * 0.82
        )
    )
    tail.closeSubpath()

    // Soft shadow beneath koi
    ctx.saveGState()
    ctx.translateBy(x: boxW * 0.014, y: boxW * 0.026)
    ctx.setFillColor(rgba(2, 8, 12, 0.44))
    ctx.addPath(torso)
    ctx.fillPath()
    ctx.addPath(tail)
    ctx.fillPath()
    ctx.restoreGState()

    // Fins & tail in translucent warm ivory
    ctx.setFillColor(rgba(248, 244, 236, 0.78))
    ctx.addPath(leftFin)
    ctx.fillPath()
    ctx.addPath(rightFin)
    ctx.fillPath()
    ctx.addPath(tail)
    ctx.fillPath()

    // Main koi torso in warm porcelain white
    ctx.setFillColor(rgba(250, 247, 240, 1.0))
    ctx.addPath(torso)
    ctx.fillPath()

    // Clip to torso for Kohaku/Tancho vermilion markings
    let headSpotCenter = spine[Int(Double(n - 1) * 0.12)]
    let shoulderCenter = spine[Int(Double(n - 1) * 0.34)]
    ctx.saveGState()
    ctx.addPath(torso)
    ctx.clip()
    ctx.setFillColor(rgba(232, 62, 42, 1.0))
    let spotR = boxW * 0.046
    ctx.fillEllipse(in: CGRect(x: headSpotCenter.x - spotR, y: headSpotCenter.y - spotR, width: spotR * 2, height: spotR * 2))
    let patchR = boxW * 0.068
    ctx.fillEllipse(in: CGRect(x: shoulderCenter.x - patchR, y: shoulderCenter.y - patchR, width: patchR * 2, height: patchR * 2))
    ctx.restoreGState()

    // Crisp water pearl droplet in front of nose
    let dropCenter = CGPoint(x: cx + cos(-0.12) * arcR, y: cy + sin(-0.12) * arcR)
    ctx.setFillColor(rgba(175, 235, 230, 0.88))
    ctx.fillEllipse(in: CGRect(x: dropCenter.x - boxW * 0.022, y: dropCenter.y - boxW * 0.022, width: boxW * 0.044, height: boxW * 0.044))

    // Inner squircle highlight rim
    ctx.setStrokeColor(rgba(255, 255, 255, 0.18))
    ctx.setLineWidth(max(1.0, s * 0.003))
    ctx.addPath(squirclePath)
    ctx.strokePath()
    ctx.restoreGState()

    guard let cgImage = ctx.makeImage() else {
        fatalError("Failed to make CGImage for size \(pixelSize)")
    }
    let rep = NSBitmapImageRep(cgImage: cgImage)
    guard let pngData = rep.representation(using: .png, properties: [:]) else {
        fatalError("Failed to encode PNG for size \(pixelSize)")
    }
    return pngData
}

let iconSpecs: [(name: String, pixels: Int)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024)
]

for spec in iconSpecs {
    let pngData = renderZenArcAppIcon(pixelSize: spec.pixels)
    let fileURL = iconsetDir.appendingPathComponent(spec.name)
    try pngData.write(to: fileURL)
}

let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
process.arguments = ["-c", "icns", iconsetDir.path, "-o", icnsOutputURL.path]
try process.run()
process.waitUntilExit()

guard process.terminationStatus == 0 else {
    fatalError("iconutil failed with status \(process.terminationStatus)")
}

try? fileManager.removeItem(at: iconsetDir)
print("==> Generated \(icnsOutputURL.path)")
