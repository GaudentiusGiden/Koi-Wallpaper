import AppKit
import Foundation
import KoiWallpaperCore

private func renderSwanDesignPreview(to outputURL: URL) throws {
    let size = CGSize(width: 1432, height: 1080)
    let bounds = PondBounds(width: Double(size.width), height: Double(size.height))
    let simulation = PondSimulation(bounds: bounds, initialInsects: [], seed: 42)
    simulation.addVisitor(PondVisitor(
        type: .swan,
        position: bounds.center,
        heading: 0.18,
        seed: 42
    ))

    guard let context = CGContext(
        data: nil,
        width: Int(size.width),
        height: Int(size.height),
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else {
        throw NSError(domain: "KoiWallpaperPreview", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not create preview bitmap context."])
    }

    context.setShouldAntialias(true)
    PondRenderer().render(simulation: simulation, in: context, rect: CGRect(origin: .zero, size: size), theme: .day)

    guard let cgImage = context.makeImage(),
          let png = NSBitmapImageRep(cgImage: cgImage).representation(using: .png, properties: [:]) else {
        throw NSError(domain: "KoiWallpaperPreview", code: 2, userInfo: [NSLocalizedDescriptionKey: "Could not encode swan preview as PNG."])
    }

    try FileManager.default.createDirectory(at: outputURL.deletingLastPathComponent(), withIntermediateDirectories: true)
    try png.write(to: outputURL)
}

private func drawBadge(title: String, subtitle: String, at point: CGPoint, in context: CGContext) {
    let width: CGFloat = 280
    let height: CGFloat = 46
    let rect = CGRect(x: point.x, y: point.y, width: width, height: height)

    context.saveGState()
    context.setFillColor(red: 0.04, green: 0.12, blue: 0.10, alpha: 0.88)
    let path = NSBezierPath(roundedRect: rect, xRadius: 7, yRadius: 7)
    path.fill()
    context.setStrokeColor(red: 0.40, green: 0.90, blue: 0.65, alpha: 0.85)
    context.setLineWidth(1.2)
    context.stroke(rect)
    context.restoreGState()

    let tAttrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 12, weight: .bold),
        .foregroundColor: NSColor(red: 0.98, green: 0.90, blue: 0.50, alpha: 1.0)
    ]
    let sAttrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 10, weight: .regular),
        .foregroundColor: NSColor(red: 0.85, green: 0.92, blue: 0.88, alpha: 1.0)
    ]
    title.draw(at: NSPoint(x: point.x + 10, y: point.y + 24), withAttributes: tAttrs)
    subtitle.draw(at: NSPoint(x: point.x + 10, y: point.y + 8), withAttributes: sAttrs)
}

private func drawReferenceSummaryCard(in context: CGContext) {
    let rect = CGRect(x: 35, y: 35, width: 490, height: 185)
    context.saveGState()
    context.setFillColor(red: 0.04, green: 0.12, blue: 0.10, alpha: 0.94)
    let path = NSBezierPath(roundedRect: rect, xRadius: 10, yRadius: 10)
    path.fill()
    context.setStrokeColor(red: 0.45, green: 0.92, blue: 0.68, alpha: 0.90)
    context.setLineWidth(1.6)
    context.stroke(rect)
    context.restoreGState()

    let titleAttrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 13, weight: .bold),
        .foregroundColor: NSColor(red: 0.98, green: 0.90, blue: 0.50, alpha: 1.0)
    ]
    let bodyAttrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 11, weight: .regular),
        .foregroundColor: NSColor.white
    ]

    "Kura-kura Pixel Art Murni - Selaras Tema Koi Wallpaper".draw(at: NSPoint(x: 48, y: 192), withAttributes: titleAttrs)

    let compURL = URL(fileURLWithPath: "build/pixel_turtle_palette_comparison.png")
    if let compImg = NSImage(contentsOf: compURL) {
        let rRect = NSRect(x: 48, y: 46, width: 140, height: 135)
        compImg.draw(in: rRect)
        context.setStrokeColor(red: 0.35, green: 0.65, blue: 0.50, alpha: 0.6)
        context.setLineWidth(1.0)
        context.stroke(rRect)
    }

    let infoText = """
    Penyelarasan Pixel-Art Asli & Tema Kolam:
    • 100% Pixel Art Murni: Menggunakan raster pixel
      diskrit tanpa kurva vektor halus (anti-aliasing).
    • Palet Nagomi (Batu & Kanan): Warna moss jade
      & terracotta peach menyatu dengan koi & teratai.
    • Palet Vibrant (Tengah): Warna asli cerah sesuai
      pack referensi dengan raster pixel tajam.
    • Batu & Riak Air Pixel: Batu kali & gelombang air
      dibuat dengan blok pixel serasi.
    """
    infoText.draw(at: NSPoint(x: 200, y: 44), withAttributes: bodyAttrs)
}

private func renderTurtlePondPreview(to outputURL: URL) throws {
    let size = CGSize(width: 1440, height: 900)
    let bounds = PondBounds(width: Double(size.width), height: Double(size.height))
    let simulation = PondSimulation(bounds: bounds, seed: 101)
    simulation.setSeason(.spring)

    // Advance simulation 120 steps so koi are actively dispersed and swimming
    for _ in 0..<120 {
        simulation.stepSimulation(dt: 1.0 / 60.0)
    }

    guard let context = CGContext(
        data: nil,
        width: Int(size.width),
        height: Int(size.height),
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else {
        throw NSError(domain: "KoiWallpaperPreview", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not create preview bitmap context."])
    }

    let nsContext = NSGraphicsContext(cgContext: context, flipped: false)
    NSGraphicsContext.current = nsContext

    context.setShouldAntialias(true)
    PondRenderer().render(simulation: simulation, in: context, rect: CGRect(origin: .zero, size: size), theme: .day)

    let shadowStyle = PondLighting.shadowStyle(for: .day)

    // Turtle 1: Swimming in Open Water (Nagomi Moss Jade)
    var turtle1 = PondTurtle(bounds: PondBounds(width: Double(size.width), height: Double(size.height)))
    turtle1.position = CGPoint(x: 480, y: 520)
    turtle1.heading = 0.35
    turtle1.paddlePhase = 1.8
    turtle1.variant = .nagomi

    PondTurtleArtwork.drawShadow(turtle1, in: context, shadowStyle: shadowStyle)
    PondTurtleArtwork.draw(turtle1, in: context, theme: .day)

    drawBadge(title: "Kura-kura Kolam (Nagomi Moss Jade)",
              subtitle: "Berenang bebas tampak atas dengan lempeng giok lumut & dayungan alami",
              at: CGPoint(x: turtle1.position.x - 120, y: turtle1.position.y - 120), in: context)

    // Turtle 2: Swimming in Open Water (Golden Amber Ishigame)
    var turtle2 = PondTurtle(bounds: PondBounds(width: Double(size.width), height: Double(size.height)))
    turtle2.position = CGPoint(x: 940, y: 380)
    turtle2.heading = -0.45
    turtle2.paddlePhase = 4.2
    turtle2.variant = .ishigame

    PondTurtleArtwork.drawShadow(turtle2, in: context, shadowStyle: shadowStyle)
    PondTurtleArtwork.draw(turtle2, in: context, theme: .day)

    drawBadge(title: "Kura-kura Kolam (Golden Amber Ishigame)",
              subtitle: "Warna batu ambar keemasan khas kura-kura kolam Jepang alami",
              at: CGPoint(x: turtle2.position.x - 130, y: turtle2.position.y - 120), in: context)

    // Inset Reference Card (Bottom Left)
    drawReferenceSummaryCard(in: context)

    guard let cgImage = context.makeImage(),
          let png = NSBitmapImageRep(cgImage: cgImage).representation(using: .png, properties: [:]) else {
        throw NSError(domain: "KoiWallpaperPreview", code: 2, userInfo: [NSLocalizedDescriptionKey: "Could not encode turtle pond preview as PNG."])
    }

    try FileManager.default.createDirectory(at: outputURL.deletingLastPathComponent(), withIntermediateDirectories: true)
    try png.write(to: outputURL)
}

private func renderSeasonsDesignPreview(to outputURL: URL) throws {
    let size = CGSize(width: 1432, height: 1080)
    let bounds = PondBounds(width: Double(size.width), height: Double(size.height))
    let simulation = PondSimulation(bounds: bounds, initialInsects: [], seed: 42)
    simulation.setSeason(.spring)

    // Spawn an assortment of sakura petals and momiji leaves across the pond
    let samplePositions: [(PondVector, FloatingDebrisType, Double, Int)] = [
        (PondVector(x: 350.0, y: 380.0), .sakuraPetal, 0.4, 0),
        (PondVector(x: 420.0, y: 340.0), .sakuraPetal, 1.2, 1),
        (PondVector(x: 500.0, y: 460.0), .sakuraPetal, 2.1, 0),
        (PondVector(x: 620.0, y: 320.0), .sakuraPetal, 0.8, 1),
        (PondVector(x: 800.0, y: 420.0), .momijiLeaf, 0.5, 0),
        (PondVector(x: 880.0, y: 510.0), .momijiLeaf, 1.9, 1),
        (PondVector(x: 960.0, y: 360.0), .momijiLeaf, 2.7, 0),
        (PondVector(x: 720.0, y: 650.0), .waterLilyPetal, 0.3, 0),
        (PondVector(x: 610.0, y: 720.0), .waterLilyPetal, 1.4, 0)
    ]

    for (pos, type, angle, variant) in samplePositions {
        var debris = FloatingDebris(
            type: type,
            position: pos,
            angle: angle,
            scale: 1.15,
            variant: variant,
            lifespan: 60.0,
            seed: 100
        )
        debris.opacity = 0.95
        simulation.spawnSeasonalDebris(at: pos, type: type)
    }

    guard let context = CGContext(
        data: nil,
        width: Int(size.width),
        height: Int(size.height),
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else {
        throw NSError(domain: "KoiWallpaperPreview", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not create preview bitmap context."])
    }

    context.setShouldAntialias(true)
    PondRenderer().render(simulation: simulation, in: context, rect: CGRect(origin: .zero, size: size), theme: .day)

    guard let cgImage = context.makeImage(),
          let png = NSBitmapImageRep(cgImage: cgImage).representation(using: .png, properties: [:]) else {
        throw NSError(domain: "KoiWallpaperPreview", code: 2, userInfo: [NSLocalizedDescriptionKey: "Could not encode seasons preview as PNG."])
    }

    try FileManager.default.createDirectory(at: outputURL.deletingLastPathComponent(), withIntermediateDirectories: true)
    try png.write(to: outputURL)
}

private func renderReadmePreview(to outputURL: URL) throws {
    let size = CGSize(width: 1280, height: 720)
    let bounds = PondBounds(width: Double(size.width), height: Double(size.height))
    let simulation = PondSimulation(bounds: bounds, seed: 108)
    simulation.setSeason(.spring)

    // Advance simulation 160 steps so koi are naturally dispersed and articulated
    for _ in 0..<160 {
        simulation.stepSimulation(dt: 1.0 / 60.0)
    }

    // Add swan visitor
    simulation.addVisitor(PondVisitor(
        type: .swan,
        position: PondVector(x: Double(size.width) * 0.76, y: Double(size.height) * 0.36),
        heading: -2.25,
        seed: 77
    ))

    // Add floating sakura petals
    simulation.spawnSeasonalDebris(at: PondVector(x: Double(size.width) * 0.32, y: Double(size.height) * 0.28), type: .sakuraPetal)
    simulation.spawnSeasonalDebris(at: PondVector(x: Double(size.width) * 0.58, y: Double(size.height) * 0.44), type: .sakuraPetal)
    simulation.spawnSeasonalDebris(at: PondVector(x: Double(size.width) * 0.18, y: Double(size.height) * 0.68), type: .waterLilyPetal)
    simulation.spawnSeasonalDebris(at: PondVector(x: Double(size.width) * 0.84, y: Double(size.height) * 0.76), type: .sakuraPetal)

    // Position turtle swimming naturally
    simulation.turtle.state = .swimming
    simulation.turtle.position = CGPoint(x: size.width * 0.22, y: size.height * 0.42)
    simulation.turtle.heading = 0.52
    simulation.turtle.paddlePhase = 2.4
    simulation.turtle.variant = .nagomi

    guard let context = CGContext(
        data: nil,
        width: Int(size.width),
        height: Int(size.height),
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else {
        throw NSError(domain: "KoiWallpaperPreview", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not create preview bitmap context."])
    }

    context.setShouldAntialias(true)
    PondRenderer().render(simulation: simulation, in: context, rect: CGRect(origin: .zero, size: size), theme: .day)

    guard let cgImage = context.makeImage(),
          let png = NSBitmapImageRep(cgImage: cgImage).representation(using: .png, properties: [:]) else {
        throw NSError(domain: "KoiWallpaperPreview", code: 2, userInfo: [NSLocalizedDescriptionKey: "Could not encode readme preview as PNG."])
    }

    try FileManager.default.createDirectory(at: outputURL.deletingLastPathComponent(), withIntermediateDirectories: true)
    try png.write(to: outputURL)
}

final class PreviewAppDelegate: NSObject, NSApplicationDelegate {
    private var window: NSWindow?
    private var previewView: KoiPondPreviewView?
    private var reviewRecording: Process?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let defaultWidth: CGFloat = 1024
        let defaultHeight: CGFloat = 640

        let window = NSWindow(
            contentRect: NSRect(x: 100, y: 100, width: defaultWidth, height: defaultHeight),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Koi Pond Preview"
        window.isRestorable = false
        window.minSize = NSSize(width: 480, height: 320)
        window.setContentSize(NSSize(width: defaultWidth, height: defaultHeight))
        window.center()

        let review = CommandLine.arguments.contains("--review-style")
        let reviewSimulation = review ? PondSimulation(bounds: PondBounds(width: Double(defaultWidth), height: Double(defaultHeight)), seed: 42) : nil
        let preview = KoiPondPreviewView(frame: window.contentLayoutRect, simulation: reviewSimulation)
        if CommandLine.arguments.contains("--preview-swan") {
            preview.simulation.setAutomaticSwanEnabled(true)
            print("[KoiWallpaperPreview] Automatic Swan preview enabled.")
        }
        window.contentView = preview

        window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(preview)
        NSApplication.shared.activate(ignoringOtherApps: true)

        self.window = window
        self.previewView = preview

        print("[KoiWallpaperPreview] Preview window launched: frame=\(window.frame), contentBounds=\(preview.bounds). Controls: Click=Splash, Opt+Click=Feed, Space=Pause, R=Reset, H=HUD.")

        if review {
            runStyleReview(window: window, preview: preview)
            return
        }

        if CommandLine.arguments.contains("--validate-collision") {
            let simBounds = PondBounds(width: Double(defaultWidth), height: Double(defaultHeight))
            let fishA = KoiFish(
                variety: KoiVariety.allEightVarieties[0], // Kohaku
                position: PondVector(x: 460.0, y: 320.0),
                heading: 0.0,
                length: 54.0,
                baseSpeed: 60.0,
                seed: 7001
            )
            let fishB = KoiFish(
                variety: KoiVariety.allEightVarieties[2], // Showa Sanshoku
                position: PondVector(x: 560.0, y: 320.0),
                heading: .pi,
                length: 48.0,
                baseSpeed: 60.0,
                seed: 7002
            )
            let collisionSim = PondSimulation(bounds: simBounds, initialFish: [fishA, fishB], seed: 7000)
            let collisionPreview = KoiPondPreviewView(frame: window.contentLayoutRect, simulation: collisionSim)
            window.contentView = collisionPreview
            self.previewView = collisionPreview
            runCollisionVisualValidation(window: window, preview: collisionPreview)
            return
        }

        if CommandLine.arguments.contains("--validate-visual") {
            runAutomatedVisualValidation(window: window, preview: preview)
        }
    }

    /// Reproducible native review: stable seed, HUD-free screenshots and a 25s
    /// WindowServer recording. Normal preview behavior is unaffected by this flag.
    private func runStyleReview(window: NSWindow, preview: KoiPondPreviewView) {
        preview.showHUD = false
        preview.needsDisplay = true
        // Keep the requested capture rectangle occupied by this window while the
        // review runs, including when Stage Manager changes the active application.
        window.level = .floating
        let destination = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("build/visual-review")
        try? FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
        let id = window.windowNumber
        func foreground() {
            window.makeKeyAndOrderFront(nil)
            window.orderFrontRegardless()
            NSApplication.shared.activate(ignoringOtherApps: true)
        }
        func capture(_ name: String) {
            foreground()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
                process.arguments = ["-x", "-o", "-l\(id)", destination.appendingPathComponent(name + ".png").path]
                try? process.run()
            }
        }
        let startFrames = preview.totalRenderedFrames
        let startTime = CACurrentMediaTime()
        DispatchQueue.main.asyncAfter(deadline: .now() + 14) {
            let cadence = Double(preview.totalRenderedFrames - startFrames) / (CACurrentMediaTime() - startTime)
            print(String(format: "[Style Review] Native scene submissions: %.1f Hz (AppKit updates, not display VSYNC)", cadence))
        }
        foreground()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            let recording = Process()
            recording.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
            let movie = destination.appendingPathComponent("native-preview.mov")
            try? FileManager.default.removeItem(at: movie)
            // -l selects a window for stills, but is ignored by video capture.
            let top = NSScreen.screens.first?.frame.maxY ?? window.frame.maxY
            let f = window.frame
            let region = "\(Int(f.minX)),\(Int(top - f.maxY)),\(Int(f.width)),\(Int(f.height))"
            recording.arguments = ["-v", "-V25", "-R\(region)", movie.path]
            do { try recording.run(); self?.reviewRecording = recording }
            catch { print("[Style Review] Recording unavailable: \(error)") }
            capture("native-preview-start")
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 6) { preview.simulation.handleWaterClick(at: preview.simulation.bounds.center) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) { preview.simulation.handleFoodDrop(at: preview.simulation.bounds.center) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 15) {
            preview.simulation.isPaused = true
            capture("native-preview-paused")
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 17) { preview.simulation.isPaused = false }
        DispatchQueue.main.asyncAfter(deadline: .now() + 23) { capture("native-preview-final") }
        DispatchQueue.main.asyncAfter(deadline: .now() + 28) { [weak self] in
            if let recording = self?.reviewRecording {
                if recording.isRunning { recording.terminate() }
                else { print("[Style Review] Recording exit status: \(recording.terminationStatus)") }
            }
            print("[Style Review] Artifacts: \(destination.path)")
            NSApplication.shared.terminate(nil)
        }
    }

    private func runCollisionVisualValidation(window: NSWindow, preview: KoiPondPreviewView) {
        print("[KoiWallpaperPreview] Starting automated head-on collision visual validation with dynamic minimum-clearance detection...")
        let wid = window.windowNumber
        let startTime = CACurrentMediaTime()

        func ensureActive() {
            window.makeKeyAndOrderFront(nil)
            window.orderFrontRegardless()
            NSApplication.shared.activate(ignoringOtherApps: true)
        }

        func capture(name: String, targetSec: Double) {
            ensureActive()
            let actualElapsed = CACurrentMediaTime() - startTime
            let path = "/tmp/\(name)"
            let p = Process()
            p.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
            p.arguments = ["-l\(wid)", "-o", path]
            try? p.run()
            p.waitUntilExit()

            let reportsDir = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("reports/screenshots")
            if FileManager.default.fileExists(atPath: reportsDir.path) {
                let targetURL = reportsDir.appendingPathComponent(name)
                try? FileManager.default.removeItem(at: targetURL)
                try? FileManager.default.copyItem(at: URL(fileURLWithPath: path), to: targetURL)
            }

            print(String(format: "[Visual Validation] Captured /tmp/%@ & reports/screenshots/%@ at t=%.2fs (target: %.2fs)", name, name, actualElapsed, targetSec))
        }

        // 1. Approaching (0.20s)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.20) {
            if preview.simulation.fish.count >= 2 {
                let f1 = preview.simulation.fish[0]
                let f2 = preview.simulation.fish[1]
                let dist = f1.position.distance(to: f2.position)
                print(String(format: "[Collision Tracking] Approaching at t=%.2fs: FishA=(%.1f, %.1f), FishB=(%.1f, %.1f), centerDist=%.2fpt", 0.20, f1.position.x, f1.position.y, f2.position.x, f2.position.y, dist))
            }
            capture(name: "m1_collision_approaching.png", targetSec: 0.20)
        }

        // 2. Real-time dynamic closest encounter detection
        var hasCapturedClosest = false
        var previousClearance = Double.infinity
        var minClearanceObserved = Double.infinity
        var monitorTimer: Timer?

        monitorTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { timer in
            guard preview.simulation.fish.count >= 2 else { return }
            let f1 = preview.simulation.fish[0]
            let f2 = preview.simulation.fish[1]
            let col = KoiSpineGeometry.testBodyCollision(fish1: f1, fish2: f2, safetyMargin: 0.0)
            let clearance = -col.maxOverlap
            let centerDist = f1.position.distance(to: f2.position)
            let elapsed = CACurrentMediaTime() - startTime

            if clearance < minClearanceObserved {
                minClearanceObserved = clearance
            }

            // Detect closest encounter:
            // When fish are in close proximity (centerDist <= 80.0pt),
            // trigger capture when clearance hits local minimum (inflection: starts increasing by >0.05pt)
            if !hasCapturedClosest && elapsed >= 0.45 {
                let isInflection = (clearance > previousClearance + 0.05) && (minClearanceObserved <= 35.0)
                if isInflection {
                    hasCapturedClosest = true
                    print(String(format: "[Collision Tracking] Closest encounter DETECTED at t=%.3fs! FishA=(%.1f, %.1f), FishB=(%.1f, %.1f), centerDist=%.2fpt, clearance=%.2fpt (capsuleOverlap=%.2fpt)", elapsed, f1.position.x, f1.position.y, f2.position.x, f2.position.y, centerDist, clearance, col.maxOverlap))
                    capture(name: "m1_collision_closest.png", targetSec: elapsed)

                    // 3. Deflected and Separating (+0.75s after closest encounter)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.75) {
                        let curF1 = preview.simulation.fish[0]
                        let curF2 = preview.simulation.fish[1]
                        let curDist = curF1.position.distance(to: curF2.position)
                        let deflectedElapsed = CACurrentMediaTime() - startTime
                        print(String(format: "[Collision Tracking] Deflected & Separating at t=%.3fs: FishA=(%.1f, %.1f), FishB=(%.1f, %.1f), centerDist=%.2fpt", deflectedElapsed, curF1.position.x, curF1.position.y, curF2.position.x, curF2.position.y, curDist))
                        capture(name: "m1_collision_deflected.png", targetSec: deflectedElapsed)
                    }

                    // 4. Complete and exit (+1.10s after closest encounter)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.10) {
                        timer.invalidate()
                        let totalTime = CACurrentMediaTime() - startTime
                        print(String(format: "[Visual Validation] Collision visual validation completed in %.2fs.", totalTime))
                        NSApplication.shared.terminate(nil)
                    }
                }
            }
            previousClearance = clearance
        }

        // Safety fallback timer at 3.5s
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
            if !hasCapturedClosest {
                print("[Collision Tracking] Fallback timeout triggered at t=3.5s")
                capture(name: "m1_collision_closest.png", targetSec: 3.5)
                capture(name: "m1_collision_deflected.png", targetSec: 3.5)
                monitorTimer?.invalidate()
                NSApplication.shared.terminate(nil)
            }
        }
    }

    private func runAutomatedVisualValidation(window: NSWindow, preview: KoiPondPreviewView) {
        print("[KoiWallpaperPreview] Starting automated visual validation sequence via GUI events...")
        let wid = window.windowNumber
        let startTime = CACurrentMediaTime()

        func ensureActive() {
            window.makeKeyAndOrderFront(nil)
            window.orderFrontRegardless()
            NSApplication.shared.activate(ignoringOtherApps: true)
        }

        // Keep window active and in front to avoid macOS Stage Manager / Exposé tucking it away
        let activeTimer = Timer.scheduledTimer(withTimeInterval: 0.20, repeats: true) { [weak window] _ in
            guard let window = window else { return }
            window.makeKeyAndOrderFront(nil)
            window.orderFrontRegardless()
            NSApplication.shared.activate(ignoringOtherApps: true)
        }

        func capture(name: String, targetSec: Double) {
            ensureActive()
            let actualElapsed = CACurrentMediaTime() - startTime
            let path = "/tmp/\(name)"
            let p = Process()
            p.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
            p.arguments = ["-l\(wid)", "-o", path]
            try? p.run()
            p.waitUntilExit()

            let reportsDir = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("reports/screenshots")
            if FileManager.default.fileExists(atPath: reportsDir.path) {
                let targetURL = reportsDir.appendingPathComponent(name)
                try? FileManager.default.removeItem(at: targetURL)
                try? FileManager.default.copyItem(at: URL(fileURLWithPath: path), to: targetURL)
            }

            print(String(format: "[Visual Validation] Captured /tmp/%@ & reports/screenshots/%@ at t=%.2fs (scheduled: %.1fs)", name, name, actualElapsed, targetSec))
        }

        func sendGuiMouseDown(at pointInView: NSPoint, option: Bool) {
            ensureActive()
            let windowPoint = preview.convert(pointInView, to: nil)
            let flags: NSEvent.ModifierFlags = option ? [.option] : []
            if let event = NSEvent.mouseEvent(
                with: .leftMouseDown,
                location: windowPoint,
                modifierFlags: flags,
                timestamp: ProcessInfo.processInfo.systemUptime,
                windowNumber: window.windowNumber,
                context: nil,
                eventNumber: 100,
                clickCount: 1,
                pressure: 1.0
            ) {
                print(String(format: "[GUI Dispatch] Dispatching %@ to window at viewPoint=(%.1f, %.1f)", option ? "Option+MouseDown" : "MouseDown", pointInView.x, pointInView.y))
                window.sendEvent(event)
            }
        }

        func sendGuiKeyDown(character: String, keyCode: UInt16) {
            ensureActive()
            if let event = NSEvent.keyEvent(
                with: .keyDown,
                location: .zero,
                modifierFlags: [],
                timestamp: ProcessInfo.processInfo.systemUptime,
                windowNumber: window.windowNumber,
                context: nil,
                characters: character,
                charactersIgnoringModifiers: character,
                isARepeat: false,
                keyCode: keyCode
            ) {
                print("[GUI Dispatch] Dispatching KeyDown '\(character)' (keyCode=\(keyCode)) to window")
                window.sendEvent(event)
            }
        }

        // 1. Initial Running t0 (0.8s)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            capture(name: "m1_seq1_running_t0.png", targetSec: 0.8)
        }

        // 2. Initial Running t1 (1.6s) - proves continuous swimming over 0.8s
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            capture(name: "m1_seq1_running_t1.png", targetSec: 1.6)
        }

        // 3. Drop food pellets via GUI Option+Click at view center (2.0s) & Capture dropped state (2.4s)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            let center = NSPoint(x: preview.bounds.midX, y: preview.bounds.midY)
            sendGuiMouseDown(at: center, option: true)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.4) {
            capture(name: "m1_seq2_food_dropped.png", targetSec: 2.4)
        }

        // 4. Koi Approaching Food (3.2s) - pellets visible, fish steering toward pellets
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.2) {
            capture(name: "m1_seq3_food_approaching.png", targetSec: 3.2)
        }

        // 5. Koi Eating Pellets with physical spacing (4.0s) - remaining pellets visible and matching HUD
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
            capture(name: "m1_seq4_food_eating.png", targetSec: 4.0)
        }

        // 6. Food dispersal t0 (5.0s) - pellets 0, fish beginning outward turn
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
            capture(name: "m1_seq5_food_dispersing_t0.png", targetSec: 5.0)
        }

        // 7. Food dispersal t1 (5.8s) - fish clearly moved outward over 0.8s back to wandering
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.8) {
            capture(name: "m1_seq5_food_dispersing_t1.png", targetSec: 5.8)
        }

        // 8. Regular Water Splash via GUI Click (6.4s) & Capture splash state (7.0s)
        DispatchQueue.main.asyncAfter(deadline: .now() + 6.4) {
            let splashPoint = NSPoint(x: preview.bounds.midX + 120, y: preview.bounds.midY - 60)
            sendGuiMouseDown(at: splashPoint, option: false)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 7.0) {
            capture(name: "m1_seq6_splash.png", targetSec: 7.0)
        }

        // 9. Pause Simulation via GUI KeyDown ' ' (7.8s) & Capture pause t0 (8.4s)
        DispatchQueue.main.asyncAfter(deadline: .now() + 7.8) {
            sendGuiKeyDown(character: " ", keyCode: 49)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 8.4) {
            capture(name: "m1_seq7_paused_t0.png", targetSec: 8.4)
        }

        // 10. Pause Frozen t1 (9.2s) - proves animation and physics are frozen over 0.8s
        DispatchQueue.main.asyncAfter(deadline: .now() + 9.2) {
            capture(name: "m1_seq7_paused_t1.png", targetSec: 9.2)
        }

        // 11. Resume Simulation via GUI KeyDown ' ' (9.8s) & Capture resumed t0 (10.4s)
        DispatchQueue.main.asyncAfter(deadline: .now() + 9.8) {
            sendGuiKeyDown(character: " ", keyCode: 49)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 10.4) {
            capture(name: "m1_seq8_resumed_t0.png", targetSec: 10.4)
        }

        // 12. Resumed t1 (11.2s) - proves smooth motion continuation over 0.8s
        DispatchQueue.main.asyncAfter(deadline: .now() + 11.2) {
            capture(name: "m1_seq8_resumed_t1.png", targetSec: 11.2)
        }

        // 13. Resize Window to 720x460 (11.8s) & Capture resized state (12.6s)
        DispatchQueue.main.asyncAfter(deadline: .now() + 11.8) {
            window.setContentSize(NSSize(width: 720, height: 460))
            preview.frame = window.contentLayoutRect
            preview.setFrameSize(window.contentLayoutRect.size)
            preview.needsDisplay = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 12.6) {
            capture(name: "m1_seq9_resized.png", targetSec: 12.6)
        }

        // 14. Reset Simulation via GUI KeyDown 'r' (13.2s) & Capture reset state (13.8s)
        DispatchQueue.main.asyncAfter(deadline: .now() + 13.2) {
            sendGuiKeyDown(character: "r", keyCode: 15)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 13.8) {
            capture(name: "m1_seq10_reset.png", targetSec: 13.8)
        }

        // 15. Complete and Exit (14.5s)
        DispatchQueue.main.asyncAfter(deadline: .now() + 14.5) {
            activeTimer.invalidate()
            let totalTime = CACurrentMediaTime() - startTime
            print(String(format: "[Visual Validation] All visual states captured successfully in %.2fs.", totalTime))
            NSApplication.shared.terminate(nil)
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }

    func applicationWillTerminate(_ notification: Notification) {
        if reviewRecording?.isRunning == true { reviewRecording?.terminate() }
    }
}

if let renderIndex = CommandLine.arguments.firstIndex(of: "--render-readme-preview") {
    let outputPath = CommandLine.arguments.dropFirst(renderIndex + 1).first ?? "docs/assets/preview.png"
    do {
        let outputURL = URL(fileURLWithPath: outputPath, relativeTo: URL(fileURLWithPath: FileManager.default.currentDirectoryPath))
        try renderReadmePreview(to: outputURL)
        print("[KoiWallpaperPreview] README showcase preview rendered: \(outputURL.path)")
    } catch {
        fatalError("Could not render readme preview: \(error)")
    }
} else if let renderIndex = CommandLine.arguments.firstIndex(of: "--render-swan-design") {
    let outputPath = CommandLine.arguments.dropFirst(renderIndex + 1).first ?? "build/swan-design-preview.png"
    do {
        let outputURL = URL(fileURLWithPath: outputPath, relativeTo: URL(fileURLWithPath: FileManager.default.currentDirectoryPath))
        try renderSwanDesignPreview(to: outputURL)
        print("[KoiWallpaperPreview] Swan design rendered with the app renderer: \(outputURL.path)")
    } catch {
        fatalError("Could not render swan design preview: \(error)")
    }
} else if let renderIndex = CommandLine.arguments.firstIndex(of: "--render-seasons-design") {
    let outputPath = CommandLine.arguments.dropFirst(renderIndex + 1).first ?? "build/seasons-design-preview.png"
    do {
        let outputURL = URL(fileURLWithPath: outputPath, relativeTo: URL(fileURLWithPath: FileManager.default.currentDirectoryPath))
        try renderSeasonsDesignPreview(to: outputURL)
        print("[KoiWallpaperPreview] Seasons design rendered with the app renderer: \(outputURL.path)")
    } catch {
        fatalError("Could not render seasons design preview: \(error)")
    }
} else if let renderIndex = CommandLine.arguments.firstIndex(of: "--render-turtle-pond") {
    let outputPath = CommandLine.arguments.dropFirst(renderIndex + 1).first ?? "build/turtle-pond-integration-preview.png"
    do {
        let outputURL = URL(fileURLWithPath: outputPath, relativeTo: URL(fileURLWithPath: FileManager.default.currentDirectoryPath))
        try renderTurtlePondPreview(to: outputURL)
        print("[KoiWallpaperPreview] Turtle pond design rendered with the app renderer: \(outputURL.path)")
    } catch {
        fatalError("Could not render turtle pond preview: \(error)")
    }
} else {
    let app = NSApplication.shared
    let delegate = PreviewAppDelegate()
    app.setActivationPolicy(.regular)
    app.delegate = delegate
    app.run()
}
