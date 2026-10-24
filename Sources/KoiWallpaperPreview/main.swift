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

if let renderIndex = CommandLine.arguments.firstIndex(of: "--render-swan-design") {
    let outputPath = CommandLine.arguments.dropFirst(renderIndex + 1).first ?? "build/swan-design-preview.png"
    do {
        let outputURL = URL(fileURLWithPath: outputPath, relativeTo: URL(fileURLWithPath: FileManager.default.currentDirectoryPath))
        try renderSwanDesignPreview(to: outputURL)
        print("[KoiWallpaperPreview] Swan design rendered with the app renderer: \(outputURL.path)")
    } catch {
        fatalError("Could not render swan design preview: \(error)")
    }
} else {
    let app = NSApplication.shared
    let delegate = PreviewAppDelegate()
    app.setActivationPolicy(.regular)
    app.delegate = delegate
    app.run()
}
