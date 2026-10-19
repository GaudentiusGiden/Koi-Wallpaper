import AppKit
import Foundation

let isInteractiveTestRequested = CommandLine.arguments.contains("--interactive-click-test")
let isHelpRequested = CommandLine.arguments.contains("--help") || CommandLine.arguments.contains("-h")

if isHelpRequested {
    print("""
    Usage: swift scripts/test_live_app.swift [options]

    Options:
      --interactive-click-test    Run live Finder click-through test.
                                  WARNING: This will activate Finder, clear Finder selection,
                                  and synthesize mouse clicks on desktop icons.
                                  Only run with explicit user consent.
      -h, --help                  Show this help message.

    Default Behavior (Safe Mode):
      Inspects the live application process, queries Window Server for window
      layer hierarchy and Finder desktop window precedence, and checks desktop
      icons in read-only mode without modifying Finder state or synthesizing clicks.
    """)
    exit(0)
}

print("=======================================================")
print("Testing Live KoiWallpaper.app Integration")
print("Mode: \(isInteractiveTestRequested ? "INTERACTIVE (Live clicks enabled)" : "SAFE (Read-only inspection)")")
print("=======================================================\n")

let appPath = "build/KoiWallpaper.app/Contents/MacOS/KoiWallpaper"
guard FileManager.default.fileExists(atPath: appPath) else {
    print("Error: App binary not found at \(appPath)")
    print("Please run ./scripts/build_app.sh first.")
    exit(1)
}

// 1. Launch KoiWallpaper.app in the background
let appProcess = Process()
appProcess.executableURL = URL(fileURLWithPath: appPath)
let outputPipe = Pipe()
appProcess.standardOutput = outputPipe
appProcess.standardError = outputPipe

print("Launching \(appPath)...")
do {
    try appProcess.run()
} catch {
    print("Error: Failed to launch application: \(error)")
    exit(1)
}

Thread.sleep(forTimeInterval: 1.5)

guard appProcess.isRunning else {
    print("Error: App failed to remain running.")
    exit(1)
}
print("App is running with PID: \(appProcess.processIdentifier)")

// 2. Query Window Server for KoiWallpaper and Finder window properties
let windowList = CGWindowListCopyWindowInfo([.optionAll], kCGNullWindowID) as? [[String: Any]] ?? []
var foundWallpaperWindow: [String: Any]?
var foundFinderWindow: [String: Any]?

for w in windowList {
    let owner = w[kCGWindowOwnerName as String] as? String ?? ""
    let pid = w[kCGWindowOwnerPID as String] as? pid_t ?? 0
    let layer = w[kCGWindowLayer as String] as? Int ?? 0

    if pid == appProcess.processIdentifier || owner == "KoiWallpaper" {
        foundWallpaperWindow = w
    }
    if owner == "Finder" && layer == Int(CGWindowLevelForKey(.desktopIconWindow)) {
        foundFinderWindow = w
    }
}

guard let wallpaperWin = foundWallpaperWindow else {
    print("FAIL: Could not locate KoiWallpaper window in Window Server list!")
    appProcess.terminate()
    exit(1)
}

let wallpaperLayer = wallpaperWin[kCGWindowLayer as String] as? Int ?? 0
let wallpaperBounds = wallpaperWin[kCGWindowBounds as String] as? [String: Any] ?? [:]
let expectedDesktopLayer = Int(CGWindowLevelForKey(.desktopWindow))

print("\n--- Window Server Inspection ---")
print("KoiWallpaper Window ID: \(wallpaperWin[kCGWindowNumber as String] ?? 0)")
print("KoiWallpaper Layer: \(wallpaperLayer) (expected: \(expectedDesktopLayer))")
print("KoiWallpaper Bounds: \(wallpaperBounds)")

let layerCheckPassed = (wallpaperLayer == expectedDesktopLayer)

var finderPrecedenceStatus: String = "NOT DETECTED"
var finderPrecedencePassed: Bool = false

if let finderWin = foundFinderWindow {
    let finderLayer = finderWin[kCGWindowLayer as String] as? Int ?? 0
    print("Finder Desktop Window Layer: \(finderLayer)")
    finderPrecedencePassed = (wallpaperLayer < finderLayer)
    finderPrecedenceStatus = finderPrecedencePassed
        ? "PASS (Wallpaper layer \(wallpaperLayer) < Finder layer \(finderLayer))"
        : "FAIL (Wallpaper layer \(wallpaperLayer) >= Finder layer \(finderLayer))"
    print("Layer hierarchy check: \(finderPrecedenceStatus)")
} else {
    finderPrecedenceStatus = "NOT DETECTED (Finder desktop icon window was not found in Window Server list)"
    print("Finder Desktop Window: NOT FOUND in Window Server list.")
    print("Note: Layer precedence cannot be verified without an active Finder desktop window.")
}

// 3. Desktop Item Inspection
print("\n--- Desktop Icon Inspection ---")
let getDesktopItemScript = """
tell application "System Events"
    if (exists process "Finder") then
        tell process "Finder"
            if (exists scroll area 1) then
                tell group 1 of scroll area 1
                    set cnt to count of UI elements
                    if cnt > 0 then
                        set elem to UI element 1
                        return (get name of elem) & "," & (item 1 of (get position of elem)) & "," & (item 2 of (get position of elem)) & "," & (item 1 of (get size of elem)) & "," & (item 2 of (get size of elem))
                    else
                        return "NONE:0"
                    end if
                end tell
            else
                return "NONE:NO_SCROLL_AREA"
            end if
        end tell
    else
        return "NONE:NO_FINDER"
    end if
end tell
"""

let itemProcess = Process()
let itemPipe = Pipe()
itemProcess.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
itemProcess.arguments = ["-e", getDesktopItemScript]
itemProcess.standardOutput = itemPipe
try? itemProcess.run()
itemProcess.waitUntilExit()

let itemData = itemPipe.fileHandleForReading.readDataToEndOfFile()
let itemStr = String(data: itemData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

var clickThroughPassed = false
var clickThroughStatus = "NOT RUN"

if !isInteractiveTestRequested {
    // SAFE MODE: Do not modify Finder state or send clicks
    print("[SAFE MODE] Skipping synthesized mouse click and Finder selection modification.")
    print("To test live Finder click-through (requires explicit user consent), run with:")
    print("    swift scripts/test_live_app.swift --interactive-click-test")
    print("Side effects of --interactive-click-test:")
    print("  - Activates Finder")
    print("  - Modifies desktop icon selection")
    print("  - Dispatches CGEvent mouse clicks to desktop coordinates")

    if !itemStr.starts(with: "NONE") && !itemStr.isEmpty {
        let parts = itemStr.split(separator: ",")
        if parts.count >= 5 {
            print("Desktop icon detected: \"\(parts[0])\" at position (\(parts[1]), \(parts[2]))")
        }
    } else {
        print("Desktop status: No desktop icons detected via System Events (\(itemStr)).")
    }
    clickThroughStatus = "SKIPPED (Safe mode default - requires explicit approval via --interactive-click-test)"
} else {
    // INTERACTIVE MODE: Explicitly enabled by user
    print("\n--- Live Finder Click-Through Test (Interactive) ---")
    if itemStr.starts(with: "NONE") || itemStr.isEmpty {
        print("FAIL: Prerequisite not met — No desktop icons found on Desktop (\(itemStr)).")
        print("Click-through cannot be tested without a desktop icon target.")
        clickThroughPassed = false
        clickThroughStatus = "FAIL (Prerequisite not met: no desktop icons available)"
    } else {
        let parts = itemStr.split(separator: ",")
        if parts.count >= 5 {
            let targetName = String(parts[0])
            let x = Double(parts[1]) ?? 0
            let y = Double(parts[2]) ?? 0
            let w = Double(parts[3]) ?? 64
            let h = Double(parts[4]) ?? 64

            let clickX = x + w / 2.0
            let clickY = y + h / 2.0
            print("Target desktop icon: \"\(targetName)\" at (\(x), \(y)), bounds: \(w)x\(h)")
            print("Simulating click at center coordinates (\(clickX), \(clickY))...")

            // Activate Finder and clear selection
            let deselectProc = Process()
            deselectProc.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
            deselectProc.arguments = ["-e", "tell application \"Finder\" to activate\ntell application \"Finder\" to set selection to {}"]
            try? deselectProc.run()
            deselectProc.waitUntilExit()

            Thread.sleep(forTimeInterval: 0.3)

            // Synthesize click
            let loc = CGPoint(x: clickX, y: clickY)
            let down = CGEvent(mouseEventSource: nil, mouseType: .leftMouseDown, mouseCursorPosition: loc, mouseButton: .left)
            let up = CGEvent(mouseEventSource: nil, mouseType: .leftMouseUp, mouseCursorPosition: loc, mouseButton: .left)
            down?.post(tap: .cghidEventTap)
            Thread.sleep(forTimeInterval: 0.05)
            up?.post(tap: .cghidEventTap)
            Thread.sleep(forTimeInterval: 0.3)

            // Verify Finder selection matches the targeted icon
            let checkProc = Process()
            let checkPipe = Pipe()
            checkProc.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
            checkProc.arguments = ["-e", "tell application \"Finder\" to get name of item 1 of (get selection as list)"]
            checkProc.standardOutput = checkPipe
            try? checkProc.run()
            checkProc.waitUntilExit()

            let checkData = checkPipe.fileHandleForReading.readDataToEndOfFile()
            let checkStr = String(data: checkData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            print("Finder selection after click: \"\(checkStr)\"")

            // Restore / clean up selection
            let cleanProc = Process()
            cleanProc.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
            cleanProc.arguments = ["-e", "tell application \"Finder\" to set selection to {}"]
            try? cleanProc.run()
            cleanProc.waitUntilExit()

            if checkStr == targetName {
                clickThroughPassed = true
                clickThroughStatus = "PASS (Selected \"\(checkStr)\" exactly matches target \"\(targetName)\")"
            } else {
                clickThroughPassed = false
                clickThroughStatus = "FAIL (Selected \"\(checkStr)\" does not match target \"\(targetName)\")"
            }
        } else {
            clickThroughPassed = false
            clickThroughStatus = "FAIL (Malformed icon geometry: \(itemStr))"
        }
    }
}

// 4. Terminate KoiWallpaper cleanly
print("\n--- Terminating KoiWallpaper ---")
appProcess.terminate()
appProcess.waitUntilExit()
print("App terminated with exit code: \(appProcess.terminationStatus)")

print("\n=======================================================")
print("Live Integration Summary:")
print("1. Binary build and execution: PASS")
print("2. Window Server layer (-2147483623): \(layerCheckPassed ? "PASS" : "FAIL")")
print("3. Finder layer precedence: \(finderPrecedenceStatus)")
print("4. Desktop click-through: \(clickThroughStatus)")
print("=======================================================")

if isInteractiveTestRequested {
    if !layerCheckPassed || !finderPrecedencePassed || !clickThroughPassed {
        exit(1)
    }
} else {
    // In safe mode, pass if app and window layer checks succeeded
    if !layerCheckPassed || (foundFinderWindow != nil && !finderPrecedencePassed) {
        exit(1)
    }
}
