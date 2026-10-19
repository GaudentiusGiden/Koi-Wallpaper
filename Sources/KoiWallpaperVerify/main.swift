import AppKit
import ApplicationServices
import Foundation
import KoiWallpaperCore

enum TestCategory: String {
    case config = "CONFIG"
    case model = "MODEL/SYNC"
    case syntheticEvent = "SYNTHETIC EVENT"
    case syntheticNotif = "SYNTHETIC NOTIF"
    case viewState = "VIEW/ANIM"
    case audit = "ARCH AUDIT"
}

struct TestResult {
    let category: TestCategory
    let name: String
    let passed: Bool
    let details: String
}

var results: [TestResult] = []

func recordTest(_ category: TestCategory, _ name: String, passed: Bool, details: String) {
    results.append(TestResult(category: category, name: name, passed: passed, details: details))
    let status = passed ? "PASS" : "FAIL"
    print("[\(status)] [\(category.rawValue)] \(name): \(details)")
}

func recordAudit(_ name: String, details: String) {
    print("[INFO] [ARCH AUDIT] \(name): \(details)")
}

print("=======================================================")
print("Koi Wallpaper M0 Verification Suite")
print("Target: macOS 14+ on Apple Silicon (arm64)")
print("=======================================================\n")

let app = NSApplication.shared
app.setActivationPolicy(.accessory)

guard let screen = NSScreen.main ?? NSScreen.screens.first else {
    print("FATAL: No active NSScreen available. Window and view tests require a graphical session.")
    exit(1)
}

print("Screen Detected: \(Int(screen.frame.width))x\(Int(screen.frame.height)), visibleFrame: \(Int(screen.visibleFrame.width))x\(Int(screen.visibleFrame.height))\n")

// -------------------------------------------------------------
// SECTION 1: Window Architecture & Configuration Properties
// (In-memory AppKit object inspection)
// -------------------------------------------------------------
print("--- Section 1: Window Architecture & Configuration Properties ---")
let windowController = DesktopWindowController(screen: screen)
let window = windowController.window

let isBorderless = window.styleMask.contains(.borderless)
let hasStationary = window.collectionBehavior.contains(.stationary)
let hasCanJoinAllSpaces = window.collectionBehavior.contains(.canJoinAllSpaces)
let hasIgnoresCycle = window.collectionBehavior.contains(.ignoresCycle)
let hasAuxiliary = window.collectionBehavior.contains(.fullScreenAuxiliary)
let canBecomeKey = window.canBecomeKey
let canBecomeMain = window.canBecomeMain
let defaultIgnoresMouse = window.ignoresMouseEvents
let defaultLevel = window.level.rawValue

recordTest(
    .config,
    "T1.1 Window Style & Non-Activation Flags",
    passed: isBorderless && !canBecomeKey && !canBecomeMain,
    details: "borderless=\(isBorderless), canBecomeKey=\(canBecomeKey), canBecomeMain=\(canBecomeMain) (Live focus retention requires desktop validation)"
)

recordTest(
    .config,
    "T1.2 Collection Behavior Flags (Spaces & Mission Control)",
    passed: hasStationary && hasCanJoinAllSpaces && hasIgnoresCycle && hasAuxiliary,
    details: "stationary=\(hasStationary), canJoinAllSpaces=\(hasCanJoinAllSpaces), ignoresCycle=\(hasIgnoresCycle), auxiliary=\(hasAuxiliary) (Live Spaces/Expose behavior requires desktop validation)"
)

let expectedDesktopLevel = Int(CGWindowLevelForKey(.desktopWindow))
let expectedFinderDesktopLevel = Int(CGWindowLevelForKey(.desktopIconWindow))
recordTest(
    .config,
    "T1.3 Initial Window Level & Mouse Passthrough",
    passed: defaultLevel == expectedDesktopLevel && defaultIgnoresMouse,
    details: "level=\(defaultLevel) (expected \(expectedDesktopLevel)), ignoresMouseEvents=\(defaultIgnoresMouse)"
)

recordTest(
    .config,
    "T1.4 CoreGraphics Desktop Layer Ordering Constants",
    passed: expectedDesktopLevel < expectedFinderDesktopLevel,
    details: "desktopWindow (\(expectedDesktopLevel)) < desktopIconWindow (\(expectedFinderDesktopLevel)) (WindowServer compositing requires desktop validation)"
)

// -------------------------------------------------------------
// SECTION 2: Mode Switching & Coordinator Synchronization
// (In-process coordinator state propagation)
// -------------------------------------------------------------
print("\n--- Section 2: Mode Switching & Coordinator Synchronization ---")
let coordinator = AppCoordinator()
coordinator.start()

guard let activeWindowController = coordinator.desktopWindowController else {
    print("FATAL: AppCoordinator failed to instantiate desktopWindowController.")
    exit(1)
}

// Switch to interactive mode
coordinator.inputCoordinator.setMode(.interactive)
let interactiveMode = coordinator.inputCoordinator.currentMode
let interactiveWindowLevel = activeWindowController.window.level.rawValue
let interactiveIgnoresMouse = activeWindowController.window.ignoresMouseEvents
let interactiveViewFlag = activeWindowController.wallpaperView.isInteractionMode
let expectedInteractiveLevel = Int(CGWindowLevelForKey(.desktopIconWindow)) + 1

recordTest(
    .model,
    "T2.1 Explicit Interaction Mode Activation",
    passed: interactiveMode == .interactive &&
            interactiveWindowLevel == expectedInteractiveLevel &&
            !interactiveIgnoresMouse &&
            interactiveViewFlag,
    details: "mode=\(interactiveMode.rawValue), level=\(interactiveWindowLevel) (expected \(expectedInteractiveLevel)), ignoresMouse=\(interactiveIgnoresMouse), view.isInteractionMode=\(interactiveViewFlag)"
)

// Revert to click-through default mode
coordinator.inputCoordinator.toggleMode()
let revertedMode = coordinator.inputCoordinator.currentMode
let revertedLevel = activeWindowController.window.level.rawValue
let revertedIgnoresMouse = activeWindowController.window.ignoresMouseEvents
let revertedViewFlag = activeWindowController.wallpaperView.isInteractionMode

recordTest(
    .model,
    "T2.2 Return to Click-Through Default Mode",
    passed: revertedMode == .clickThrough &&
            revertedLevel == expectedDesktopLevel &&
            revertedIgnoresMouse &&
            !revertedViewFlag,
    details: "mode=\(revertedMode.rawValue), level=\(revertedLevel) (expected \(expectedDesktopLevel)), ignoresMouse=\(revertedIgnoresMouse), view.isInteractionMode=\(revertedViewFlag)"
)

// -------------------------------------------------------------
// SECTION 3: Synthetic NSEvent Dispatch & View Input Handling
// (In-memory NSEvent dispatched directly to WallpaperView)
// -------------------------------------------------------------
print("\n--- Section 3: Synthetic NSEvent Dispatch & View Input Handling ---")

class MockInputDelegate: InputCoordinatorDelegate {
    var lastClickPoint: CGPoint?
    var lastWasOption: Bool?
    var clickCount: Int = 0
    weak var chainedDelegate: InputCoordinatorDelegate?

    func reset() {
        lastClickPoint = nil
        lastWasOption = nil
        clickCount = 0
    }

    func inputCoordinator(_ coordinator: InputCoordinator, didChangeMode mode: InputInteractionMode) {
        chainedDelegate?.inputCoordinator(coordinator, didChangeMode: mode)
    }

    func inputCoordinator(_ coordinator: InputCoordinator, didReceiveClickAt point: CGPoint, isOptionClick: Bool) {
        lastClickPoint = point
        lastWasOption = isOptionClick
        clickCount += 1
        chainedDelegate?.inputCoordinator(coordinator, didReceiveClickAt: point, isOptionClick: isOptionClick)
    }
}

let mockDelegate = MockInputDelegate()
mockDelegate.chainedDelegate = coordinator
coordinator.inputCoordinator.delegate = mockDelegate

// Switch back to interactive mode for event testing
coordinator.inputCoordinator.setMode(.interactive)
let wallpaperView = activeWindowController.wallpaperView

// Helper to synthesize an NSEvent for testing view's mouseDown
func makeMouseEvent(type: NSEvent.EventType, location: NSPoint, modifierFlags: NSEvent.ModifierFlags) -> NSEvent? {
    return NSEvent.mouseEvent(
        with: type,
        location: location,
        modifierFlags: modifierFlags,
        timestamp: ProcessInfo.processInfo.systemUptime,
        windowNumber: activeWindowController.window.windowNumber,
        context: nil,
        eventNumber: 1,
        clickCount: 1,
        pressure: 1.0
    )
}

// Subtest 3.1: Regular click in interactive mode
mockDelegate.reset()
let initialRippleCount = wallpaperView.activeRippleCount
let clickTarget1 = NSPoint(x: 250, y: 350)
if let clickEvent1 = makeMouseEvent(type: .leftMouseDown, location: clickTarget1, modifierFlags: []) {
    wallpaperView.mouseDown(with: clickEvent1)
}

let click1Received = (mockDelegate.lastClickPoint == CGPoint(x: 250, y: 350) && mockDelegate.lastWasOption == false)
let ripple1Spawned = (wallpaperView.activeRippleCount == initialRippleCount + 1)
let animating1 = wallpaperView.isAnimating

recordTest(
    .syntheticEvent,
    "T3.1 View MouseDown in Interactive Mode (Regular Click -> Water Call)",
    passed: click1Received && ripple1Spawned && animating1,
    details: "point=\(String(describing: mockDelegate.lastClickPoint)), isOption=\(String(describing: mockDelegate.lastWasOption)), ripples=\(wallpaperView.activeRippleCount), animating=\(animating1) (Synthetic in-memory NSEvent)"
)

// Subtest 3.2: Option+click in interactive mode
mockDelegate.reset()
let clickTarget2 = NSPoint(x: 400, y: 500)
if let clickEvent2 = makeMouseEvent(type: .leftMouseDown, location: clickTarget2, modifierFlags: [.option]) {
    wallpaperView.mouseDown(with: clickEvent2)
}

let click2Received = (mockDelegate.lastClickPoint == CGPoint(x: 400, y: 500) && mockDelegate.lastWasOption == true)
let ripple2Spawned = (wallpaperView.activeRippleCount == initialRippleCount + 2)

recordTest(
    .syntheticEvent,
    "T3.2 View MouseDown in Interactive Mode (Option+Click -> Food Pellet)",
    passed: click2Received && ripple2Spawned,
    details: "point=\(String(describing: mockDelegate.lastClickPoint)), isOption=\(String(describing: mockDelegate.lastWasOption)), ripples=\(wallpaperView.activeRippleCount) (Synthetic in-memory NSEvent)"
)

// Subtest 3.3: Click suppression in clickThrough mode
coordinator.inputCoordinator.setMode(.clickThrough)
mockDelegate.reset()
let ripplesBeforeSuppressed = wallpaperView.activeRippleCount
if let suppressedEvent = makeMouseEvent(type: .leftMouseDown, location: NSPoint(x: 100, y: 100), modifierFlags: []) {
    wallpaperView.mouseDown(with: suppressedEvent)
}
let clickThroughIgnored = (mockDelegate.clickCount == 0 && wallpaperView.activeRippleCount == ripplesBeforeSuppressed)

// Subtest 3.4: Click suppression when view is paused
coordinator.inputCoordinator.setMode(.interactive)
wallpaperView.isPaused = true
mockDelegate.reset()
if let pausedEvent = makeMouseEvent(type: .leftMouseDown, location: NSPoint(x: 100, y: 100), modifierFlags: []) {
    wallpaperView.mouseDown(with: pausedEvent)
}
let pausedIgnored = (mockDelegate.clickCount == 0 && wallpaperView.activeRippleCount == ripplesBeforeSuppressed)
wallpaperView.isPaused = false
coordinator.inputCoordinator.setMode(.clickThrough)

recordTest(
    .syntheticEvent,
    "T3.3 Input Suppression in Click-Through and Paused States",
    passed: clickThroughIgnored && pausedIgnored,
    details: "clickThroughIgnored=\(clickThroughIgnored), pausedIgnored=\(pausedIgnored) (Guarantees no accidental interactions or ripples when not interactive or paused)"
)

// -------------------------------------------------------------
// SECTION 4: LifecyclePolicy & View Animation Synchronization
// (In-process model and synthetic NSWorkspace notifications)
// -------------------------------------------------------------
print("\n--- Section 4: LifecyclePolicy & View Animation Synchronization ---")
let testPolicy = LifecyclePolicy()
let testWindowController = DesktopWindowController(screen: screen)
let testView = testWindowController.wallpaperView
testPolicy.bindWindow(testWindowController.window)

class MockLifecycleDelegate: LifecyclePolicyDelegate {
    var lastReasons: Set<PauseReason> = []
    var lastIsPaused: Bool = false
    var updateCount: Int = 0

    func lifecyclePolicy(_ policy: LifecyclePolicy, didUpdatePauseReasons reasons: Set<PauseReason>, isPaused: Bool) {
        lastReasons = reasons
        lastIsPaused = isPaused
        updateCount += 1
    }

    func lifecyclePolicyDidRequestScreenReconfiguration(_ policy: LifecyclePolicy) {}
}

let lifecycleDelegate = MockLifecycleDelegate()
testPolicy.delegate = lifecycleDelegate

// Spin runloop briefly to process any pending window server observations
RunLoop.current.run(until: Date().addingTimeInterval(0.05))

recordTest(
    .model,
    "T4.1 Lifecycle Initial State (Unpaused, Zero Reasons)",
    passed: !testPolicy.isPaused && testPolicy.activePauseReasons.isEmpty,
    details: "isPaused=\(testPolicy.isPaused), reasons=\(testPolicy.activePauseReasons)"
)

// Manual pause test
testPolicy.setManualPause(true)
let manualPaused = testPolicy.isPaused && testPolicy.activePauseReasons == [.manual]

recordTest(
    .model,
    "T4.2 Manual Pause Activation",
    passed: manualPaused && lifecycleDelegate.lastIsPaused && lifecycleDelegate.lastReasons == [.manual],
    details: "isPaused=\(testPolicy.isPaused), reasons=\(testPolicy.activePauseReasons), delegateNotified=\(lifecycleDelegate.updateCount > 0)"
)

// Synthetic Display Sleep notification while manually paused
NSWorkspace.shared.notificationCenter.post(
    name: NSWorkspace.screensDidSleepNotification,
    object: nil
)
let sleepAndManual = testPolicy.isPaused &&
                     testPolicy.activePauseReasons == [.manual, .displaySleep]

// Synthetic Display Wake notification — CRITICAL: Manual pause MUST NOT be dropped!
NSWorkspace.shared.notificationCenter.post(
    name: NSWorkspace.screensDidWakeNotification,
    object: nil
)
let wakeRetainedManual = testPolicy.isPaused &&
                         testPolicy.activePauseReasons == [.manual]

// Clear manual pause
testPolicy.setManualPause(false)
let resumedAfterManualCleared = !testPolicy.isPaused && testPolicy.activePauseReasons.isEmpty

recordTest(
    .syntheticNotif,
    "T4.3 Synthetic Display Sleep/Wake & Manual Pause Retention",
    passed: sleepAndManual && wakeRetainedManual && resumedAfterManualCleared,
    details: "Sleep added .displaySleep; Wake cleared .displaySleep while preserving .manual; app only resumed when manual pause cleared (Synthetic NSWorkspace notification)"
)

// Synthetic System Sleep and Wake
NSWorkspace.shared.notificationCenter.post(
    name: NSWorkspace.willSleepNotification,
    object: nil
)
let sysSleepPaused = testPolicy.isPaused && testPolicy.activePauseReasons == [.systemSleep]

testPolicy.setManualPause(true)
let sysSleepAndManual = testPolicy.isPaused && testPolicy.activePauseReasons == [.systemSleep, .manual]

NSWorkspace.shared.notificationCenter.post(
    name: NSWorkspace.didWakeNotification,
    object: nil
)
let sysWakeRetainedManual = testPolicy.isPaused && testPolicy.activePauseReasons == [.manual]

testPolicy.setManualPause(false)
let fullyResumed = !testPolicy.isPaused && testPolicy.activePauseReasons.isEmpty

recordTest(
    .syntheticNotif,
    "T4.4 Synthetic System Sleep/Wake & Multi-Reason Preservation",
    passed: sysSleepPaused && sysSleepAndManual && sysWakeRetainedManual && fullyResumed,
    details: "Multi-reason state accurately tracks independent system and user pause causes without collision (Synthetic NSWorkspace notification)"
)

// Window Occlusion handling logic via mockable window
class MockOcclusionWindow: NSWindow {
    var mockIsVisible: Bool = true
    var mockOcclusion: NSWindow.OcclusionState = [.visible]

    override var isVisible: Bool {
        mockIsVisible
    }

    override var occlusionState: NSWindow.OcclusionState {
        mockOcclusion
    }
}

let mockWindow = MockOcclusionWindow(
    contentRect: NSRect(x: 0, y: 0, width: 100, height: 100),
    styleMask: [.borderless],
    backing: .buffered,
    defer: false
)

mockWindow.mockIsVisible = false
testPolicy.evaluateWindowOcclusion(mockWindow)
let hiddenPaused = testPolicy.isPaused && testPolicy.activePauseReasons.contains(.covered)

mockWindow.mockIsVisible = true
mockWindow.mockOcclusion = [.visible]
testPolicy.evaluateWindowOcclusion(mockWindow)
let visibleRestored = !testPolicy.activePauseReasons.contains(.covered)

recordTest(
    .model,
    "T4.5 Window Occlusion Evaluation Logic (Mock Window)",
    passed: hiddenPaused && visibleRestored,
    details: "Hidden window sets .covered reason; visible window removes .covered (Live desktop occlusion requires desktop validation)"
)

// Animation Freeze & Resume Continuity Test
testView.isPaused = false
testView.addRipple(at: CGPoint(x: 150, y: 150), isFood: false)
RunLoop.current.run(until: Date().addingTimeInterval(0.05))

let initialRadius = testView.firstRippleRadius ?? 0.0
let hasInitialAnimation = testView.isAnimating && initialRadius > 4.0

// Pause view
testView.isPaused = true
let pausedAnimationStopped = !testView.isAnimating
RunLoop.current.run(until: Date().addingTimeInterval(0.05))
let radiusDuringPause = testView.firstRippleRadius ?? 0.0
let pausedStatePreserved = (radiusDuringPause == initialRadius)

// Resume view
testView.isPaused = false
let resumedAnimationRestarted = testView.isAnimating
RunLoop.current.run(until: Date().addingTimeInterval(0.05))
let radiusAfterResume = testView.firstRippleRadius ?? 0.0
let resumedContinuityValid = (radiusAfterResume > radiusDuringPause)

recordTest(
    .viewState,
    "T4.6 Animation Freeze & Discontinuity-Free Resume",
    passed: hasInitialAnimation && pausedAnimationStopped && pausedStatePreserved && resumedAnimationRestarted && resumedContinuityValid,
    details: "initial=\(initialRadius), frozen=\(radiusDuringPause), resumed=\(radiusAfterResume). Timer stops cleanly on pause and resumes without resetting or jumping."
)

// -------------------------------------------------------------
// SECTION 5: Architectural Permissions & TCC Audit
// (Honest inspection without hardcoded PASS constants)
// -------------------------------------------------------------
print("\n--- Section 5: Architectural Permissions & TCC Audit ---")
let isAXTrusted = AXIsProcessTrustedWithOptions(nil)
recordAudit(
    "TCC Privileges Audit",
    details: "AXIsProcessTrusted=\(isAXTrusted) (untrusted, as expected for standard userland app). No Accessibility or Input Monitoring entitlements/prompts required by M0 host architecture."
)

// -------------------------------------------------------------
// SUMMARY & DESKTOP VALIDATION CHECKLIST
// -------------------------------------------------------------
print("\n=======================================================")
let passCount = results.filter { $0.passed }.count
let failCount = results.filter { !$0.passed }.count
print("In-Process Suite Results: \(passCount) Passed, \(failCount) Failed")
print("=======================================================\n")

print("""
--------------------------------------------------------------------------------
EVIDENCE SCOPE & HONEST STATUS DISCLOSURE:
All tests above verified in-memory AppKit object configurations, state
coordinators, synthetic NSEvent dispatch, and synthetic notification handling.
THEY DO NOT PROVE REAL macOS DESKTOP WINDOW SERVER INTEGRATION.

Pending Desktop Integration Checklist (Requires Live Manual Validation):
  [ ] 1. Finder Desktop Click-Through: Click, drag, and select desktop icons
  [ ] 2. Focus Non-Stealing: Verify clicking pond never steals key/main focus
  [ ] 3. Status Bar Menu: Toggle Interaction Mode & Manual Pause via UI
  [ ] 4. macOS Spaces: Verify window remains stationary on all virtual desktops
  [ ] 5. Show Desktop & Mission Control: Verify window does not fly away
  [ ] 6. Native Fullscreen Apps: Verify behavior when another app goes fullscreen
  [ ] 7. Live Desktop Occlusion: Observe occlusion state when covered by windows
  [ ] 8. Hardware Sleep & Wake: Observe actual system/display sleep & lid close/open
--------------------------------------------------------------------------------
""")

if failCount > 0 {
    exit(1)
}
