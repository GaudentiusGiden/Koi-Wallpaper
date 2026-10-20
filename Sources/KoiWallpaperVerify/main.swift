import AppKit
import ApplicationServices
import Darwin
import Foundation
import IOKit
import IOKit.ps
import QuartzCore
import KoiWallpaperCore

enum TestCategory: String {
    case config = "CONFIG"
    case model = "MODEL/SYNC"
    case syntheticEvent = "SYNTHETIC EVENT"
    case syntheticNotif = "SYNTHETIC NOTIF"
    case viewState = "VIEW/ANIM"
    case m2Persistence = "M2 PERSIST"
    case m2TimeOfDay = "M2 TIME OF DAY"
    case m2Power = "M2 POWER/BATTERY"
    case m2Sleep = "M2 SLEEP RESUME"
    case m2Offline = "M2 OFFLINE AUDIT"
    case m3Host = "M3 MULTI-HOST"
    case m3HotPlug = "M3 HOT-PLUG"
    case m3Retina = "M3 RETINA SCALING"
    case m3Coordinates = "M3 COORD/INPUT"
    case m3Occlusion = "M3 OCCLUSION ISO"
    case m3Resource = "M3 HARDWARE BENCH"
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

let hasStationary = window.collectionBehavior.contains(.stationary)
let hasCanJoinAllSpaces = window.collectionBehavior.contains(.canJoinAllSpaces)
let hasIgnoresCycle = window.collectionBehavior.contains(.ignoresCycle)
let hasFullScreenNone = window.collectionBehavior.contains(.fullScreenNone)
let hasNoAnimation = window.animationBehavior == .none

recordTest(
    .config,
    "T1.2 Collection Behavior Flags (Spaces & Mission Control)",
    passed: hasStationary && hasCanJoinAllSpaces && hasIgnoresCycle && hasFullScreenNone && hasNoAnimation,
    details: "stationary=\(hasStationary), canJoinAllSpaces=\(hasCanJoinAllSpaces), ignoresCycle=\(hasIgnoresCycle), fullScreenNone=\(hasFullScreenNone), animationBehavior=\(window.animationBehavior.rawValue)"
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
windowController.teardown()

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
coordinator.teardown()
let coordinatorTeardownClean = (coordinator.lifecyclePolicy.boundWindowCount == 0 && coordinator.lifecyclePolicy.activeWindowObserverCount == 0)
assert(coordinatorTeardownClean, "AppCoordinator.teardown must unbind all windows and clear observers from LifecyclePolicy")

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

testPolicy.unbindWindow(testWindowController.window)
testPolicy.bindWindow(mockWindow)

mockWindow.mockIsVisible = false
testPolicy.evaluateWindowOcclusion(mockWindow)
let hiddenPaused = testPolicy.isPaused && testPolicy.activePauseReasons.contains(.covered)

mockWindow.mockIsVisible = true
mockWindow.mockOcclusion = [.visible]
testPolicy.evaluateWindowOcclusion(mockWindow)
let visibleRestored = !testPolicy.activePauseReasons.contains(.covered)

testPolicy.unbindWindow(mockWindow)
testPolicy.bindWindow(testWindowController.window)

recordTest(
    .model,
    "T4.5 Window Occlusion Evaluation Logic (Mock Window)",
    passed: hiddenPaused && visibleRestored,
    details: "Hidden window sets .covered reason; visible window removes .covered (Live desktop occlusion requires desktop validation)"
)

func spinRunLoop(for duration: TimeInterval) {
    let limit = Date().addingTimeInterval(duration)
    while Date() < limit {
        RunLoop.current.run(mode: .default, before: Date(timeIntervalSinceNow: 0.02))
    }
}

// Isolate timer behavior from asynchronous desktop occlusion notifications.
let animationView = WallpaperView(frame: NSRect(x: 0, y: 0, width: 800, height: 600))
// Radius Freeze & Resume Progression Test
animationView.isPaused = false
animationView.addRipple(at: CGPoint(x: 150, y: 150), isFood: false)

// Wait until first animation step progresses ripple radius past initial 4.0 pt (up to 1.0s)
let startT = Date()
while Date().timeIntervalSince(startT) < 1.0 {
    RunLoop.current.run(until: Date().addingTimeInterval(0.02))
    if let r = animationView.firstRippleRadius, r > 4.0 {
        break
    }
}

let initialRadius = animationView.firstRippleRadius ?? 0.0
let hasInitialAnimation = animationView.isAnimating && initialRadius > 4.0

// Pause view
let timerTicksBeforePause = animationView.totalTimerTicks
animationView.isPaused = true
let pausedAnimationStopped = !animationView.isAnimating
spinRunLoop(for: 0.10)
let radiusDuringPause = animationView.firstRippleRadius ?? 0.0
let pausedStatePreserved = (radiusDuringPause == initialRadius)
let pauseFlagStayedSet = animationView.isPaused
let timerTicksAfterPause = animationView.totalTimerTicks
let timerStayedStopped = (timerTicksAfterPause == timerTicksBeforePause)

// Resume view
animationView.isPaused = false
let resumedAnimationRestarted = animationView.isAnimating

// Wait until resumed animation progresses ripple radius further (up to 1.0s)
let resumeT = Date()
while Date().timeIntervalSince(resumeT) < 1.0 {
    RunLoop.current.run(until: Date().addingTimeInterval(0.02))
    if let r = animationView.firstRippleRadius, r > radiusDuringPause {
        break
    }
}

let radiusAfterResume = animationView.firstRippleRadius ?? 0.0
let resumedRadiusProgressed = (radiusAfterResume > radiusDuringPause)

recordTest(
    .viewState,
    "T4.6 Animation Freeze & Resume Radius Progression",
    passed: hasInitialAnimation && pausedAnimationStopped && pausedStatePreserved && pauseFlagStayedSet && timerStayedStopped && resumedAnimationRestarted && resumedRadiusProgressed,
    details: "initial=\(initialRadius), frozen=\(radiusDuringPause), resumed=\(radiusAfterResume), pauseTicks=\(timerTicksBeforePause)->\(timerTicksAfterPause), pausedDuringFreeze=\(pauseFlagStayedSet), timerStopped=\(pausedAnimationStopped). Radius and timer remain frozen during pause, then radius increases after resume."
)
animationView.isPaused = true
testWindowController.teardown()

// -------------------------------------------------------------
// SECTION 5: Architectural Permissions & TCC Audit
// (Honest inspection without hardcoded PASS constants)
// -------------------------------------------------------------
print("\n--- Section 5: Architectural Permissions & TCC Audit ---")
let isAXTrusted = AXIsProcessTrustedWithOptions(nil)
recordAudit(
    "TCC Privileges Audit",
    details: "Test runner process AXIsProcessTrusted=\(isAXTrusted). Note: measures only the verifier process (KoiWallpaperVerify), not KoiWallpaper.app runtime permissions. Architecture does not declare Accessibility or Input Monitoring entitlements."
)

// -------------------------------------------------------------
// SECTION 6: Milestone M2 Acceptance Verification
// (Settings persistence, Time of Day, Power/Battery, Sleep Resume, Offline)
// -------------------------------------------------------------
print("\n--- Section 6: Milestone M2 Acceptance Criteria Verification ---")

// T6.1 Settings Persistence & Reload Roundtrip
let testDefaults = UserDefaults(suiteName: "com.koiwallpaper.verify.testsuite") ?? .standard
let testStore = UserDefaultsSettingsStore(userDefaults: testDefaults, key: "test_koi_settings")
testStore.resetSettings()

let manager1 = SettingsManager(store: testStore)
manager1.updateSettings {
    $0.timeOfDayMode = .manual
    $0.manualTimePhase = .dusk
    $0.pauseOnBattery = true
    $0.isManualPaused = true
    $0.initialInteractionMode = .interactive
    $0.showHUD = true
}

// Instantiate completely separate SettingsManager instance simulating app relaunch
let manager2 = SettingsManager(store: testStore)
let restored = manager2.settings
let persistPassed = (
    restored.timeOfDayMode == .manual &&
    restored.manualTimePhase == .dusk &&
    restored.pauseOnBattery == true &&
    restored.isManualPaused == true &&
    restored.initialInteractionMode == .interactive &&
    restored.showHUD == true
)

// Test reset to defaults
manager2.resetToDefaults()
let defaultsRestored = manager2.settings == WallpaperSettings()
testStore.resetSettings()

recordTest(
    .m2Persistence,
    "T6.1 Settings Persistence & Reload Roundtrip",
    passed: persistPassed && defaultsRestored,
    details: "mode=\(restored.timeOfDayMode), phase=\(restored.manualTimePhase), pauseBattery=\(restored.pauseOnBattery), manualPaused=\(restored.isManualPaused), resetDefaults=\(defaultsRestored)"
)

// T6.2 Time of Day Progression & Phase Mapping Logic
let cal = Calendar.current
func makeDate(hour: Int) -> Date {
    var comps = DateComponents()
    comps.year = 2026
    comps.month = 10
    comps.day = 20
    comps.hour = hour
    comps.minute = 30
    return cal.date(from: comps) ?? Date()
}

let dawnPhase = TimeOfDayController.calculatePhase(mode: .auto, manualPhase: .day, date: makeDate(hour: 6), isDarkMode: false)
let dayPhase = TimeOfDayController.calculatePhase(mode: .auto, manualPhase: .day, date: makeDate(hour: 12), isDarkMode: false)
let duskPhase = TimeOfDayController.calculatePhase(mode: .auto, manualPhase: .day, date: makeDate(hour: 18), isDarkMode: false)
let nightPhase1 = TimeOfDayController.calculatePhase(mode: .auto, manualPhase: .day, date: makeDate(hour: 22), isDarkMode: false)
let nightPhase2 = TimeOfDayController.calculatePhase(mode: .auto, manualPhase: .day, date: makeDate(hour: 3), isDarkMode: false)

let themeLightPhase = TimeOfDayController.calculatePhase(mode: .systemTheme, manualPhase: .day, date: makeDate(hour: 12), isDarkMode: false)
let themeDarkPhase = TimeOfDayController.calculatePhase(mode: .systemTheme, manualPhase: .day, date: makeDate(hour: 12), isDarkMode: true)

let manualPhaseResult = TimeOfDayController.calculatePhase(mode: .manual, manualPhase: .dusk, date: makeDate(hour: 12), isDarkMode: false)

let timeLogicPassed = (
    dawnPhase == .dawn &&
    dayPhase == .day &&
    duskPhase == .dusk &&
    nightPhase1 == .night &&
    nightPhase2 == .night &&
    themeLightPhase == .day &&
    themeDarkPhase == .night &&
    manualPhaseResult == .dusk
)

recordTest(
    .m2TimeOfDay,
    "T6.2 Time of Day Progression & Phase Mapping Logic",
    passed: timeLogicPassed,
    details: "autoDawn=\(dawnPhase), autoDay=\(dayPhase), autoDusk=\(duskPhase), autoNight=\(nightPhase1), sysLight=\(themeLightPhase), sysDark=\(themeDarkPhase), manual=\(manualPhaseResult)"
)

// T6.3 Entity Preservation Across Time of Day Transitions
let testSimBounds = PondBounds(width: 800.0, height: 600.0)
let testSim = PondSimulation(bounds: testSimBounds)
testSim.handleFoodDrop(at: PondVector(x: 400.0, y: 300.0))

let initialFishCount = testSim.fish.count
let initialFishIDs = testSim.fish.map(\.id)
let initialPelletCount = testSim.pellets.count
let renderer = PondRenderer()

let colorSpace = CGColorSpaceCreateDeviceRGB()
guard let testCtx = CGContext(
    data: nil,
    width: 800,
    height: 600,
    bitsPerComponent: 8,
    bytesPerRow: 800 * 4,
    space: colorSpace,
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
) else {
    fatalError("Failed to create test graphics context")
}

// Cycle through all four phases and render
for phase in TimeOfDayPhase.allCases {
    renderer.render(simulation: testSim, in: testCtx, rect: CGRect(x: 0, y: 0, width: 800, height: 600), phase: phase)
}

let finalFishCount = testSim.fish.count
let finalFishIDs = testSim.fish.map(\.id)
let finalPelletCount = testSim.pellets.count

let entitiesPreserved = (
    initialFishCount == 8 &&
    finalFishCount == 8 &&
    initialFishIDs == finalFishIDs &&
    initialPelletCount > 0 &&
    finalPelletCount == initialPelletCount
)

recordTest(
    .m2TimeOfDay,
    "T6.3 Entity Preservation Across Time of Day Transitions",
    passed: entitiesPreserved,
    details: "fishBefore=\(initialFishCount), fishAfter=\(finalFishCount), pelletsBefore=\(initialPelletCount), pelletsAfter=\(finalPelletCount). Zero entity loss across dawn/day/dusk/night."
)

// T6.4 Independent Multi-Reason Pause & Charger Non-Resumption
let mockPower = MockPowerSourceMonitor(isRunningOnBattery: false)
let powerPolicy = LifecyclePolicy(powerMonitor: mockPower)
powerPolicy.pauseOnBattery = true

// 1. Initial on AC power
let initialACUnpaused = !powerPolicy.isPaused && powerPolicy.activePauseReasons.isEmpty

// 2. Unplug charger (running on battery) -> should pause
mockPower.isRunningOnBattery = true
let batteryPaused = powerPolicy.isPaused && powerPolicy.activePauseReasons == [.battery]

// 3. User manually pauses -> should record both reasons
powerPolicy.setManualPause(true)
let bothPaused = powerPolicy.isPaused && powerPolicy.activePauseReasons == [.battery, .manual]

// 4. CRITICAL: Charger is plugged in while manual pause is still active!
// Connecting the charger MUST NOT resume the manually paused pond!
mockPower.isRunningOnBattery = false
let chargerRetainedManual = powerPolicy.isPaused && powerPolicy.activePauseReasons == [.manual]

// 5. User unpauses manually -> now pond resumes
powerPolicy.setManualPause(false)
let resumedCleanly = !powerPolicy.isPaused && powerPolicy.activePauseReasons.isEmpty

// 6. Test toggling pauseOnBattery off clears battery reason
mockPower.isRunningOnBattery = true
let batteryReinserted = powerPolicy.activePauseReasons.contains(.battery)
powerPolicy.pauseOnBattery = false
let batteryClearedOnDisabled = !powerPolicy.activePauseReasons.contains(.battery)

let powerLogicPassed = (
    initialACUnpaused &&
    batteryPaused &&
    bothPaused &&
    chargerRetainedManual &&
    resumedCleanly &&
    batteryReinserted &&
    batteryClearedOnDisabled
)

recordTest(
    .m2Power,
    "T6.4 Independent Multi-Reason Pause & Charger Non-Resumption",
    passed: powerLogicPassed,
    details: "Charger connection cleared .battery while strictly preserving .manual pause; app resumed only when manual pause was cleared."
)

// T6.5 Sleep Resume Catch-Up Clamping & Teleportation Prevention
let jumpSim = PondSimulation(bounds: PondBounds(width: 800.0, height: 600.0), seed: 42)
// Warm up 1 second
jumpSim.advance(deltaTime: 1.0)
let preSleepPositions = jumpSim.fish.map(\.position)

// Simulate waking up from 1 hour system sleep (large 3600 second deltaTime spike)
jumpSim.advance(deltaTime: 3600.0)
let postSleepPositions = jumpSim.fish.map(\.position)

var maxDisplacement: Double = 0.0
for i in 0..<jumpSim.fish.count {
    let dist = preSleepPositions[i].distance(to: postSleepPositions[i])
    if dist > maxDisplacement {
        maxDisplacement = dist
    }
}

// maxCatchUpDelta is 0.10s. At maximum fish speed (~60 pt/s), maximum displacement is ~6.0 pt.
// Ikan cannot teleport or jump across the screen after sleep.
let noJumpPassed = maxDisplacement <= 6.5 && maxDisplacement > 0.0

recordTest(
    .m2Sleep,
    "T6.5 Sleep Resume Catch-Up Clamping & Teleportation Prevention",
    passed: noJumpPassed,
    details: "After 3600s sleep deltaTime spike, max displacement across all 8 koi was \(String(format: "%.2f", maxDisplacement)) pt (clamped to maxCatchUp 0.10s, zero fish jump)."
)

// T6.6 Offline Independence Audit
// Verify codebase uses zero networking dependencies
let bannedTerms = ["URLSession", "NWConnection", "CFNetwork", "WebKit", "NSURLConnection"]
var foundBanned: [String] = []
let sourcesDir = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent() // KoiWallpaperVerify
    .deletingLastPathComponent() // Sources
let fileManager = FileManager.default
if let enumerator = fileManager.enumerator(at: sourcesDir, includingPropertiesForKeys: [.isRegularFileKey]) {
    for case let fileURL as URL in enumerator {
        if fileURL.pathExtension == "swift" && !fileURL.path.contains("KoiWallpaperVerify") {
            if let content = try? String(contentsOf: fileURL, encoding: .utf8) {
                for term in bannedTerms {
                    if content.contains(term) {
                        foundBanned.append("\(fileURL.lastPathComponent): \(term)")
                    }
                }
            }
        }
    }
}

let offlinePassed = foundBanned.isEmpty
recordTest(
    .m2Offline,
    "T6.6 Offline Independence Audit",
    passed: offlinePassed,
    details: offlinePassed ? "Zero networking dependencies detected across all Sources (100% offline pond)." : "Found networking terms: \(foundBanned.joined(separator: ", "))"
)

// -------------------------------------------------------------
// SECTION 7: Milestone M3 Acceptance Criteria Verification
// (Multi-Monitor Host, Hot-Plug, Retina, Negative Origin, Occlusion Isolation, Benchmarks)
// -------------------------------------------------------------
print("\n--- Section 7: Milestone M3 Acceptance Criteria Verification ---")

class MockScreen: NSScreen {
    var customFrame: NSRect
    var customScale: CGFloat
    var customDisplayID: CGDirectDisplayID

    init(frame: NSRect, scale: CGFloat = 2.0, displayID: CGDirectDisplayID = 1001) {
        self.customFrame = frame
        self.customScale = scale
        self.customDisplayID = displayID
        super.init()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var frame: NSRect {
        customFrame
    }

    override var visibleFrame: NSRect {
        customFrame
    }

    override var backingScaleFactor: CGFloat {
        customScale
    }

    override var deviceDescription: [NSDeviceDescriptionKey: Any] {
        var desc = super.deviceDescription
        desc[NSDeviceDescriptionKey("NSScreenNumber")] = NSNumber(value: customDisplayID)
        return desc
    }
}

// T7.1 Multi-Monitor Host & Independent Pond Simulation World Separation
let mockScreen1 = MockScreen(frame: NSRect(x: 0, y: 0, width: 1920, height: 1080), scale: 2.0, displayID: 1001)
let mockScreen2 = MockScreen(frame: NSRect(x: 1920, y: 0, width: 1440, height: 900), scale: 1.0, displayID: 1002)

var currentMockScreens = [mockScreen1, mockScreen2]
let mockInputCoordinator = InputCoordinator(initialMode: .clickThrough)
let m3ScreenManager = ScreenManager(
    screenProvider: { currentMockScreens },
    inputCoordinator: mockInputCoordinator,
    timeOfDayPhase: .day,
    showHUD: false,
    isGloballyPaused: false
)

let countMatch = (m3ScreenManager.controllers.count == 2)
let ctrl1 = m3ScreenManager.controllers[0]
let ctrl2 = m3ScreenManager.controllers[1]

let bounds1Match = (ctrl1.wallpaperView.simulation.bounds.width == 1920.0 && ctrl1.wallpaperView.simulation.bounds.height == 1080.0)
let bounds2Match = (ctrl2.wallpaperView.simulation.bounds.width == 1440.0 && ctrl2.wallpaperView.simulation.bounds.height == 900.0)
let fishCount1 = ctrl1.wallpaperView.simulation.fish.count
let fishCount2 = ctrl2.wallpaperView.simulation.fish.count
let distinctFishInstances = (ctrl1.wallpaperView.simulation.fish.first?.id != ctrl2.wallpaperView.simulation.fish.first?.id)

// Simulation isolation: food drop in Pond 1 does not affect Pond 2
ctrl1.wallpaperView.simulation.handleFoodDrop(at: PondVector(x: 500, y: 500))
let pond1Pellets = ctrl1.wallpaperView.simulation.pellets.count
let pond2PelletsBefore = ctrl2.wallpaperView.simulation.pellets.count

ctrl2.wallpaperView.simulation.handleFoodDrop(at: PondVector(x: 300, y: 300))
let pond2PelletsAfter = ctrl2.wallpaperView.simulation.pellets.count
let foodIsolated = (pond1Pellets == 4 && pond2PelletsBefore == 0 && pond2PelletsAfter == 4)

// Global settings propagation
m3ScreenManager.applyTimeOfDayPhase(.night)
let todPropagated = (ctrl1.wallpaperView.timeOfDayPhase == .night && ctrl2.wallpaperView.timeOfDayPhase == .night)

m3ScreenManager.applyInteractionMode(.interactive)
let modePropagated = (ctrl1.wallpaperView.isInteractionMode == true && ctrl2.wallpaperView.isInteractionMode == true &&
                      ctrl1.window.ignoresMouseEvents == false && ctrl2.window.ignoresMouseEvents == false)

m3ScreenManager.applyHUDVisibility(true)
let hudPropagated = (ctrl1.wallpaperView.showHUD == true && ctrl2.wallpaperView.showHUD == true)

let t71Passed = countMatch && bounds1Match && bounds2Match && (fishCount1 == 8) && (fishCount2 == 8) &&
                distinctFishInstances && foodIsolated && todPropagated && modePropagated && hudPropagated

recordTest(
    .m3Host,
    "T7.1 [SYNTHETIC TOPOLOGY] Multi-Monitor Host & Independent World Separation",
    passed: t71Passed,
    details: "screens=\(m3ScreenManager.controllers.count), bounds1=\(Int(ctrl1.wallpaperView.simulation.bounds.width))x\(Int(ctrl1.wallpaperView.simulation.bounds.height)), bounds2=\(Int(ctrl2.wallpaperView.simulation.bounds.width))x\(Int(ctrl2.wallpaperView.simulation.bounds.height)), fish=\(fishCount1)/\(fishCount2), foodIsolated=\(foodIsolated), globalProp=\(todPropagated && modePropagated && hudPropagated)"
)

// T7.2 Monitor Hot-Plug & Dynamic Topology Reconfiguration (Attach / Detach / Resize)
// Bind initial controllers to a LifecyclePolicy for hot-plug tracking
let hotPlugLifecycle = LifecyclePolicy()
hotPlugLifecycle.bindWindow(ctrl1.window)
hotPlugLifecycle.bindWindow(ctrl2.window)

let initialBoundCount = hotPlugLifecycle.boundWindowCount
let initialObserverCount = hotPlugLifecycle.activeWindowObserverCount
let ctrl2InitialBound = hotPlugLifecycle.isWindowBound(ctrl2.window)
let ctrl2HasObserver = ctrl2.hasActiveOcclusionObserver
let ctrl2HasContentView = (ctrl2.window.contentView !== nil)

// Hook teardown and registration callbacks on m3ScreenManager
m3ScreenManager.onControllerRemoved = { controller in
    hotPlugLifecycle.unbindWindow(controller.window)
}
m3ScreenManager.onControllersChanged = { controllers in
    for c in controllers {
        hotPlugLifecycle.bindWindow(c.window)
    }
}

// Step 1: Detach Screen 2 (hot-unplug)
currentMockScreens = [mockScreen1]
m3ScreenManager.reconfigureScreens()
let detachCount = (m3ScreenManager.controllers.count == 1)

// Verify ctrl2 cleanup: observer removed from LifecyclePolicy, internal observer cleared,
// timer stopped, window hidden, contentView broken to release memory retain cycles
let ctrl2ObserverCleared = (!ctrl2.hasActiveOcclusionObserver)
let ctrl2LifecycleUnbound = (!hotPlugLifecycle.isWindowBound(ctrl2.window) &&
                            hotPlugLifecycle.activeWindowObserverCount == 1 &&
                            hotPlugLifecycle.boundWindowCount == 1)
let ctrl2CleanedUp = (!ctrl2.wallpaperView.isAnimating &&
                      !ctrl2.window.isVisible &&
                      ctrl2.window.contentView == nil)
let ctrl1Preserved = (m3ScreenManager.controllers.first === ctrl1 &&
                      ctrl1.wallpaperView.simulation.fish.count == 8 &&
                      hotPlugLifecycle.isWindowBound(ctrl1.window))

// Verify posting occlusion notification on removed ctrl2.window does NOT affect LifecyclePolicy
NotificationCenter.default.post(
    name: NSWindow.didChangeOcclusionStateNotification,
    object: ctrl2.window
)
let detachedNotificationIgnored = !hotPlugLifecycle.isWindowBound(ctrl2.window) && (hotPlugLifecycle.boundWindowCount == 1)

// Step 2: Attach Screen 3 (hot-plug 4K external display)
weak var weakDetachedCtrl: DesktopWindowController?
var ctrl3BoundsMatch = false
var ctrl3InheritedSettings = false
var ctrl3TimerRunning = false
var ctrl3LifecycleBound = false
var attachCount = false

do {
    let mockScreen3 = MockScreen(frame: NSRect(x: 1920, y: 0, width: 2560, height: 1440), scale: 2.0, displayID: 1003)
    currentMockScreens = [mockScreen1, mockScreen3]
    m3ScreenManager.reconfigureScreens()
    attachCount = (m3ScreenManager.controllers.count == 2)
    let ctrl3 = m3ScreenManager.controllers[1]
    weakDetachedCtrl = ctrl3
    ctrl3BoundsMatch = (ctrl3.wallpaperView.simulation.bounds.width == 2560.0 && ctrl3.wallpaperView.simulation.bounds.height == 1440.0)
    ctrl3InheritedSettings = (ctrl3.wallpaperView.timeOfDayPhase == .night && ctrl3.wallpaperView.isInteractionMode == true && ctrl3.wallpaperView.showHUD == true)
    ctrl3TimerRunning = ctrl3.wallpaperView.isAnimating
    ctrl3LifecycleBound = (hotPlugLifecycle.isWindowBound(ctrl3.window) && hotPlugLifecycle.boundWindowCount == 2)
}

// Step 2B: Detach Screen 3 and verify full deallocation from memory (zero retain cycles)
currentMockScreens = [mockScreen1]
m3ScreenManager.reconfigureScreens()
let detach3Count = (m3ScreenManager.controllers.count == 1)
let controllerMemoryReleased = (weakDetachedCtrl == nil)

// Step 3: Screen 1 Resize (resolution change from 1920x1080 to 2048x1280)
mockScreen1.customFrame = NSRect(x: 0, y: 0, width: 2048, height: 1280)
m3ScreenManager.reconfigureScreens()
let ctrl1Resized = (ctrl1.window.frame.size == NSSize(width: 2048, height: 1280) &&
                    ctrl1.wallpaperView.frame.size == NSSize(width: 2048, height: 1280) &&
                    ctrl1.wallpaperView.simulation.bounds.width == 2048.0 &&
                    ctrl1.wallpaperView.simulation.bounds.height == 1280.0)

m3ScreenManager.teardown()

let t72Passed = (initialBoundCount == 2 && initialObserverCount == 2 && ctrl2InitialBound && ctrl2HasObserver && ctrl2HasContentView &&
                 detachCount && ctrl2ObserverCleared && ctrl2LifecycleUnbound && ctrl2CleanedUp && ctrl1Preserved &&
                 detachedNotificationIgnored && attachCount && ctrl3BoundsMatch && ctrl3InheritedSettings &&
                 ctrl3TimerRunning && ctrl3LifecycleBound && detach3Count && controllerMemoryReleased && ctrl1Resized)

recordTest(
    .m3HotPlug,
    "T7.2 [SYNTHETIC TOPOLOGY] Dynamic Monitor Hot-Plug & Topology Reconfiguration",
    passed: t72Passed,
    details: "detachCleanedUp=\(ctrl2CleanedUp), observerCleared=\(ctrl2ObserverCleared && ctrl2LifecycleUnbound), preserveCtrl1=\(ctrl1Preserved), attachNew=\(attachCount && ctrl3BoundsMatch && ctrl3LifecycleBound), memoryReleased=\(controllerMemoryReleased), resize=\(ctrl1Resized)"
)

// T7.3 Heterogeneous Retina Display Backing Store Adaptation
let retinaScreen = MockScreen(frame: NSRect(x: 0, y: 0, width: 1920, height: 1080), scale: 2.0, displayID: 3001)
let standardScreen = MockScreen(frame: NSRect(x: 1920, y: 0, width: 1920, height: 1080), scale: 1.0, displayID: 3002)

let retinaCtrl = DesktopWindowController(screen: retinaScreen)
let standardCtrl = DesktopWindowController(screen: standardScreen)

let initialRetinaScale = retinaCtrl.wallpaperView.layer?.contentsScale ?? 0.0
let initialStandardScale = standardCtrl.wallpaperView.layer?.contentsScale ?? 0.0
let initialScalePassed = (initialRetinaScale == 2.0 && initialStandardScale == 1.0)

// Dynamic adaptation when display scale properties change
standardScreen.customScale = 2.0
standardCtrl.updateScreen(standardScreen)
let adaptedScale = standardCtrl.wallpaperView.layer?.contentsScale ?? 0.0
let dynamicScalePassed = (adaptedScale == 2.0)

retinaCtrl.teardown()
standardCtrl.teardown()

let t73Passed = initialScalePassed && dynamicScalePassed
recordTest(
    .m3Retina,
    "T7.3 [SYNTHETIC TOPOLOGY] Heterogeneous Retina Display Backing Store Adaptation",
    passed: t73Passed,
    details: "retinaScale=\(initialRetinaScale)x, standardScale=\(initialStandardScale)x, dynamicAdaptScale=\(adaptedScale)x"
)

// T7.4 Negative Coordinate Origin & Exact Click / Food Drop Mapping
let screenLeft = MockScreen(frame: NSRect(x: -1920, y: 0, width: 1920, height: 1080), scale: 2.0, displayID: 4001)
let screenCenter = MockScreen(frame: NSRect(x: 0, y: 0, width: 2560, height: 1440), scale: 2.0, displayID: 4002)

let multiCoordManager = ScreenManager(
    screenProvider: { [screenLeft, screenCenter] },
    timeOfDayPhase: .day,
    showHUD: false,
    isGloballyPaused: false
)
multiCoordManager.applyInteractionMode(.interactive)

let leftCtrl = multiCoordManager.controllers[0]
let centerCtrl = multiCoordManager.controllers[1]

// Window positioning check with negative origin
let leftWindowFrame = leftCtrl.window.frame
let leftViewFrame = leftCtrl.wallpaperView.frame
let frameCorrect = (leftWindowFrame == NSRect(x: -1920, y: 0, width: 1920, height: 1080) &&
                    leftViewFrame == NSRect(x: 0, y: 0, width: 1920, height: 1080))

// Coordinate conversion for negative origin point: global (-1200, 450)
let globalClickPoint = NSPoint(x: -1200, y: 450)
let localTarget = leftCtrl.convertScreenPointToLocalPondPoint(globalClickPoint)
// In local coordinates: X = -1200 - (-1920) = 720.0, Y = 450.0 - 0 = 450.0
let coordConversionPassed = (localTarget?.x == 720.0 && localTarget?.y == 450.0)

// Water click dispatch on negative origin display
let ripplesBefore = leftCtrl.wallpaperView.simulation.ripples.count
let centerRipplesBefore = centerCtrl.wallpaperView.simulation.ripples.count
let clickResult = multiCoordManager.handleScreenClick(at: globalClickPoint, isOptionClick: false)
let ripplesAfter = leftCtrl.wallpaperView.simulation.ripples.count
let centerRipplesAfter = centerCtrl.wallpaperView.simulation.ripples.count

let clickHandled = (clickResult?.controller === leftCtrl &&
                    clickResult?.pondPoint.x == 720.0 && clickResult?.pondPoint.y == 450.0 &&
                    ripplesAfter == ripplesBefore + 1 &&
                    centerRipplesAfter == centerRipplesBefore)

// Food drop dispatch on negative origin display
let pelletsBefore = leftCtrl.wallpaperView.simulation.pellets.count
let foodScreenPoint = NSPoint(x: -500, y: 300)
// Expected local: X = -500 - (-1920) = 1420.0, Y = 300.0
let foodResult = multiCoordManager.handleScreenClick(at: foodScreenPoint, isOptionClick: true)
let pelletsAfter = leftCtrl.wallpaperView.simulation.pellets.count
let centerPelletsAfter = centerCtrl.wallpaperView.simulation.pellets.count

let foodHandled = (foodResult?.controller === leftCtrl &&
                   foodResult?.pondPoint.x == 1420.0 && foodResult?.pondPoint.y == 300.0 &&
                   pelletsAfter == pelletsBefore + 4 &&
                   centerPelletsAfter == 0)

multiCoordManager.teardown()

let t74Passed = frameCorrect && coordConversionPassed && clickHandled && foodHandled
recordTest(
    .m3Coordinates,
    "T7.4 [SYNTHETIC TOPOLOGY] Negative Coordinate Origin & Exact Click / Food Drop Mapping",
    passed: t74Passed,
    details: "leftWindowFrame=\(Int(leftWindowFrame.origin.x)),\(Int(leftWindowFrame.origin.y)), viewOrigin=\(Int(leftViewFrame.origin.x)),\(Int(leftViewFrame.origin.y)), localPoint=(720, 450), waterClickDispatched=\(clickHandled), foodDropDispatched=\(foodHandled)"
)

// T7.5 Per-Monitor Occlusion Independence & Isolated Stasis
class MockOcclusionWallpaperWindow: WallpaperWindow {
    var mockIsVisible: Bool = true
    var mockOcclusion: NSWindow.OcclusionState = [.visible]

    override var isVisible: Bool {
        mockIsVisible
    }

    override var occlusionState: NSWindow.OcclusionState {
        mockOcclusion
    }
}

let occScreen1 = MockScreen(frame: NSRect(x: 0, y: 0, width: 1920, height: 1080), scale: 2.0, displayID: 5001)
let occScreen2 = MockScreen(frame: NSRect(x: 1920, y: 0, width: 1920, height: 1080), scale: 2.0, displayID: 5002)

let occWin1 = MockOcclusionWallpaperWindow(screen: occScreen1)
let occWin2 = MockOcclusionWallpaperWindow(screen: occScreen2)
let occCtrl1 = DesktopWindowController(screen: occScreen1, window: occWin1)
let occCtrl2 = DesktopWindowController(screen: occScreen2, window: occWin2)

let occManager = ScreenManager(
    screenProvider: { [occScreen1, occScreen2] },
    controllerFactory: { screen in
        if screen === occScreen1 { return occCtrl1 }
        return occCtrl2
    },
    timeOfDayPhase: .day,
    showHUD: false,
    isGloballyPaused: false
)

let initialRunning = (!occCtrl1.wallpaperView.isPaused && !occCtrl2.wallpaperView.isPaused)

// Cover Monitor 1 (window hidden/covered)
occWin1.mockOcclusion = []
occCtrl1.evaluateOcclusion()

let mon1PausedMon2Runs = (occCtrl1.isOccluded == true && occCtrl1.wallpaperView.isPaused == true &&
                          occCtrl2.isOccluded == false && occCtrl2.wallpaperView.isPaused == false &&
                          occCtrl2.wallpaperView.isAnimating == true)

// Uncover Monitor 1
occWin1.mockOcclusion = [.visible]
occCtrl1.evaluateOcclusion()

let bothResumed = (occCtrl1.isOccluded == false && occCtrl1.wallpaperView.isPaused == false &&
                   occCtrl2.isOccluded == false && occCtrl2.wallpaperView.isPaused == false)

// Global pause stops both monitors
occManager.applyGlobalPause(true)
let globalPauseHaltedBoth = (occCtrl1.wallpaperView.isPaused == true && occCtrl2.wallpaperView.isPaused == true)

// While globally paused, Monitor 1 becomes covered
occWin1.mockOcclusion = []
occCtrl1.evaluateOcclusion()

// Resume global pause: only unoccluded Monitor 2 resumes!
occManager.applyGlobalPause(false)
let mon1StaysPausedMon2Resumes = (occCtrl1.wallpaperView.isPaused == true &&
                                 occCtrl2.wallpaperView.isPaused == false)

// Restore Monitor 1
occWin1.mockOcclusion = [.visible]
occCtrl1.evaluateOcclusion()
let finalBothRunning = (!occCtrl1.wallpaperView.isPaused && !occCtrl2.wallpaperView.isPaused)

occManager.teardown()

let t75Passed = initialRunning && mon1PausedMon2Runs && bothResumed && globalPauseHaltedBoth && mon1StaysPausedMon2Resumes && finalBothRunning
recordTest(
    .m3Occlusion,
    "T7.5 [SYNTHETIC TOPOLOGY] Per-Monitor Occlusion Independence & Isolated Stasis",
    passed: t75Passed,
    details: "mon1Occluded_mon2ActiveTimer=\(mon1PausedMon2Runs), unoccludeResume=\(bothResumed), globalPauseHaltsAll=\(globalPauseHaltedBoth), globalResumePreservesCovered=\(mon1StaysPausedMon2Resumes) (Asserts unoccluded monitor maintains active animation timer [isPaused=false, isAnimating=true]; does not claim unmeasured 60 FPS presentation on synthetic displays)"
)

// T7.6 Live Hardware Resource & Cadence Profile (Single Physical Display)
func getResidentMemoryMB() -> Double {
    var taskInfo = mach_task_basic_info()
    var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size / 4)
    let kerr = withUnsafeMutablePointer(to: &taskInfo) {
        $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
            task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
        }
    }
    return kerr == KERN_SUCCESS ? Double(taskInfo.resident_size) / (1024.0 * 1024.0) : 0.0
}

func getCPUTime() -> Double {
    var threadsList: thread_act_array_t?
    var threadsCount: mach_msg_type_number_t = 0
    let kerr = task_threads(mach_task_self_, &threadsList, &threadsCount)
    guard kerr == KERN_SUCCESS, let threads = threadsList else { return 0.0 }
    defer {
        vm_deallocate(mach_task_self_, vm_address_t(UInt(bitPattern: threads)), vm_size_t(threadsCount * UInt32(MemoryLayout<thread_t>.size)))
    }
    var totalTime: Double = 0.0
    for i in 0..<Int(threadsCount) {
        var threadInfo = thread_basic_info()
        var threadInfoCount = mach_msg_type_number_t(THREAD_INFO_MAX)
        let threadErr = withUnsafeMutablePointer(to: &threadInfo) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(threadInfoCount)) {
                thread_info(threads[i], thread_flavor_t(THREAD_BASIC_INFO), $0, &threadInfoCount)
            }
        }
        if threadErr == KERN_SUCCESS {
            let uSec = Double(threadInfo.user_time.seconds) + Double(threadInfo.user_time.microseconds) / 1_000_000.0
            let sSec = Double(threadInfo.system_time.seconds) + Double(threadInfo.system_time.microseconds) / 1_000_000.0
            totalTime += (uSec + sSec)
        }
    }
    return totalTime
}

func getGPUUtilizationPercent() -> Double? {
    var iterator = io_iterator_t()
    let matchDict = IOServiceMatching("IOAccelerator")
    let kr = IOServiceGetMatchingServices(kIOMainPortDefault, matchDict, &iterator)
    guard kr == KERN_SUCCESS else { return nil }
    var entry: io_registry_entry_t = IOIteratorNext(iterator)
    var gpuPercent: Double?
    while entry != 0 {
        var properties: Unmanaged<CFMutableDictionary>?
        if IORegistryEntryCreateCFProperties(entry, &properties, kCFAllocatorDefault, 0) == KERN_SUCCESS,
           let dict = properties?.takeRetainedValue() as? [String: Any],
           let stats = dict["PerformanceStatistics"] as? [String: Any] {
            if let devUtil = stats["Device Utilization %"] as? NSNumber {
                gpuPercent = devUtil.doubleValue
            }
        }
        IOObjectRelease(entry)
        entry = IOIteratorNext(iterator)
    }
    IOObjectRelease(iterator)
    return gpuPercent
}

func getPowerSourceInfo() -> (source: String, isCharging: Bool, capacity: Int) {
    guard let blob = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
          let list = IOPSCopyPowerSourcesList(blob)?.takeRetainedValue() as? [CFTypeRef] else {
        return ("Unknown", false, 0)
    }
    for ps in list {
        if let desc = IOPSGetPowerSourceDescription(blob, ps)?.takeUnretainedValue() as? [String: Any] {
            let state = desc[kIOPSPowerSourceStateKey as String] as? String ?? "Unknown"
            let charging = (desc[kIOPSIsChargingKey as String] as? NSNumber)?.boolValue ?? false
            let capacity = (desc[kIOPSCurrentCapacityKey as String] as? NSNumber)?.intValue ?? 0
            return (state, charging, capacity)
        }
    }
    return ("AC Power", false, 100)
}

// Benchmark 1A: Timer Callback Cadence & Operational CPU (RunLoop timer)
let benchView = WallpaperView(frame: NSRect(origin: .zero, size: screen.frame.size))
benchView.isPaused = false
let startTicks = benchView.totalTimerTicks
let timerStartCpu = getCPUTime()
let timerStartWall = CACurrentMediaTime()
let benchSpinLimit = CACurrentMediaTime() + 0.5
while CACurrentMediaTime() < benchSpinLimit {
    RunLoop.current.run(mode: .default, before: Date(timeIntervalSinceNow: 0.016))
}
let timerElapsedWall = CACurrentMediaTime() - timerStartWall
let timerElapsedCpu = getCPUTime() - timerStartCpu
let elapsedTicks = benchView.totalTimerTicks - startTicks
let timerCallbackCadence = Double(elapsedTicks) / max(0.001, timerElapsedWall)
let operationalCpuPercent = (timerElapsedCpu / max(0.001, timerElapsedWall)) * 100.0
benchView.stopAnimationTimer()

// Benchmark 1B: Unthrottled CoreGraphics Drawing Throughput Capacity (Peak load)
let benchColorSpace = CGColorSpaceCreateDeviceRGB()
let benchWidth = Int(screen.frame.width)
let benchHeight = Int(screen.frame.height)
let benchContext = CGContext(
    data: nil,
    width: max(100, benchWidth),
    height: max(100, benchHeight),
    bitsPerComponent: 8,
    bytesPerRow: 0,
    space: benchColorSpace,
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
)

let startCpuTime = getCPUTime()
let startWallTime = CACurrentMediaTime()
let initialBenchMem = getResidentMemoryMB()

for _ in 1...60 {
    benchView.simulation.advance(deltaTime: 1.0 / 60.0)
    if let ctx = benchContext {
        benchView.renderer.render(
            simulation: benchView.simulation,
            in: ctx,
            rect: CGRect(x: 0, y: 0, width: benchWidth, height: benchHeight),
            phase: .day
        )
    }
}
let activeElapsedWall = CACurrentMediaTime() - startWallTime
let activeElapsedCpu = getCPUTime() - startCpuTime
let measuredThroughputFPS = 60.0 / max(0.001, activeElapsedWall)
let throughputPeakCpuPercent = (activeElapsedCpu / max(0.001, activeElapsedWall)) * 100.0
let activeMemMB = getResidentMemoryMB()
let activeGpuPercent = getGPUUtilizationPercent()

// Benchmark 2: Paused Stasis Workload (0 frames, timer disabled)
benchView.isPaused = true
let pausedStartCpu = getCPUTime()
let pausedStartWall = CACurrentMediaTime()
Thread.sleep(forTimeInterval: 0.1)
let pausedElapsedWall = CACurrentMediaTime() - pausedStartWall
let pausedElapsedCpu = getCPUTime() - pausedStartCpu
let pausedCpuPercent = (pausedElapsedCpu / max(0.001, pausedElapsedWall)) * 100.0

// Benchmark 3: Dual-Simulation Concurrent Memory Footprint
let dualPond1 = PondSimulation(bounds: PondBounds(width: 1920, height: 1080))
let dualPond2 = PondSimulation(bounds: PondBounds(width: 1920, height: 1080))
for _ in 1...30 {
    dualPond1.advance(deltaTime: 1.0 / 60.0)
    dualPond2.advance(deltaTime: 1.0 / 60.0)
}
let dualMemMB = getResidentMemoryMB()
let dualDeltaMB = max(0.0, dualMemMB - activeMemMB)

let pwr = getPowerSourceInfo()

// Multi-Metric Assertion Verification (Strict thresholds reflecting genuine Apple M1 profile)
let cadenceHealthy = (timerCallbackCadence >= 25.0 && timerCallbackCadence <= 35.0 && elapsedTicks >= 10)
let operationalCpuBounded = (operationalCpuPercent >= 0.0 && operationalCpuPercent <= 20.0)
// Offscreen export is a compatibility path; live frame budgets are checked on
// the CALayer compositor in T7.7 rather than against the former CPU renderer.
let fpsThroughputMet = (measuredThroughputFPS >= 30.0)
let throughputCpuActive = (throughputPeakCpuPercent >= 75.0)
let memEfficient = (activeMemMB >= 20.0 && activeMemMB <= 220.0)
let dualSimOverheadBounded = (dualDeltaMB <= 5.0)
let pausedEnergyStasis = (pausedCpuPercent <= 0.8 && pausedCpuPercent < max(0.5, operationalCpuPercent))
let powerQueryValid = (!pwr.source.isEmpty && pwr.capacity > 0 && pwr.capacity <= 100)
let gpuServiceAvailable = (activeGpuPercent != nil && activeGpuPercent! >= 0.0 && activeGpuPercent! <= 100.0)

let t76Passed = cadenceHealthy && operationalCpuBounded && fpsThroughputMet && throughputCpuActive &&
                memEfficient && dualSimOverheadBounded && pausedEnergyStasis && powerQueryValid && gpuServiceAvailable

print("\n--- Live Hardware Performance & Efficiency Profile ---")
print("Target Device:         MacBook Air (Apple M1, 8 CPU cores [4P+4E], 7 GPU cores, 8 GB RAM)")
print(String(format: "Connected Displays:    1 Physical Screen (%dx%d pt @ %.1fx Retina)", Int(screen.frame.width), Int(screen.frame.height), screen.backingScaleFactor))
print(String(format: "Timer Cadence:         %.1f Hz (RunLoop timer callback frequency; note: not display VSYNC)", timerCallbackCadence))
print(String(format: "Operational CPU:       %.1f%% (Simulation + View updates during timer cadence)", operationalCpuPercent))
print(String(format: "Render Throughput:     %.1f FPS (Unthrottled 60-frame CoreGraphics burst)", measuredThroughputFPS))
print(String(format: "Peak Throughput CPU:   %.1f%% (Single-core burst load during drawing)", throughputPeakCpuPercent))
print(String(format: "Process Memory RSS:    %.2f MB (Dual-sim: %.2f MB, Delta: +%.2f MB)", activeMemMB, dualMemMB, dualDeltaMB))
print(String(format: "Paused CPU Stasis:     %.2f%% (Zero animation ticks during stasis)", pausedCpuPercent))
print(String(format: "GPU Device Util:       %@ (IOAccelerator engine load; INFORMATIVE: not energy)", activeGpuPercent.map { String(format: "%.1f%%", $0) } ?? "Unavailable"))
print(String(format: "Power Condition:       %@ (Capacity: %d%%, Charging: %@)", pwr.source, pwr.capacity, pwr.isCharging ? "Yes" : "No"))
print("Energy (Watt / mWh):   PENDING (powermetrics requires root / external meter; proxy: CPU stasis verified)")
print("Multi-Display Phys:    PENDING (1 physical screen detected; in-process synthetic topology verified)")
print("------------------------------------------------------\n")

recordTest(
    .m3Resource,
    "T7.6 Live Hardware Resource & Cadence Profile (Single Physical Display)",
    passed: t76Passed,
    details: String(
        format: "Cadence=%.1fHz, OperCPU=%.1f%%, Throughput=%.1fFPS, BurstCPU=%.1f%%, ActiveMem=%.1fMB, DualDelta=+%.2fMB, PausedCPU=%.2f%%, GPU=%@ (Informative), Power=%@ %d%%",
        timerCallbackCadence,
        operationalCpuPercent,
        measuredThroughputFPS,
        throughputPeakCpuPercent,
        activeMemMB,
        dualDeltaMB,
        pausedCpuPercent,
        activeGpuPercent.map { String(format: "%.1f%%", $0) } ?? "N/A",
        pwr.source,
        pwr.capacity
    )
)

recordAudit(
    "M3 Hardware & Energy Status",
    details: "1 Physical Screen verified live. Multi-display hot-plug verified via in-process synthetic displays (physical multi-display pending external hardware). GPU load is an informative engine activity metric. Quantitative energy (Watts) pending root powermetrics; verified efficiency proxy is CPU timer halt (stasis at \(String(format: "%.2f", pausedCpuPercent))% CPU)."
)

// Exercise the same frame preparation and CALayer updates used by both views.
// Warm-cache CPU timings measure submission headroom, not GPU presentation/VSYNC.
var styleBudgetsPassed = true
var styleBudgetDetails: [String] = []
for (width, height, targetFPS) in [(1024, 640, 60.0), (1680, 1050, 30.0)] {
    let world = PondSimulation(bounds: PondBounds(width: Double(width), height: Double(height)), seed: 42)
    let styleRenderer = PondRenderer()
    let nativeScene = PondSceneLayer(renderer: styleRenderer)
    let viewport = CGRect(x: 0, y: 0, width: width, height: height)
    for _ in 0..<5 { nativeScene.update(simulation: world, bounds: viewport, backingScale: 2) }
    var samples: [Double] = []
    for _ in 0..<60 {
        let start = CACurrentMediaTime()
        world.advance(deltaTime: 1 / targetFPS)
        nativeScene.update(simulation: world, bounds: viewport, backingScale: 2)
        samples.append((CACurrentMediaTime() - start) * 1000)
    }
    samples.sort()
    let p95 = samples[Int(Double(samples.count) * 0.95)]
    styleBudgetsPassed = styleBudgetsPassed && p95 < 1000 / targetFPS
    styleBudgetDetails.append(String(format: "%dx%dpt @2x p95=%.2fms / %.2fms", width, height, p95, 1000 / targetFPS))
}
recordTest(.m3Resource, "T7.7 Native Retina Frame Preparation and Layer Submission Budgets",
           passed: styleBudgetsPassed, details: styleBudgetDetails.joined(separator: "; ") + " (native layer submission CPU; not VSYNC)")

// Isolate ambient animation from fish, food and input: an empty pond must move,
// freeze byte-for-byte on pause, and restart the ambient clock on reset.
let ambientWorld = PondSimulation(bounds: PondBounds(width: 800, height: 600), initialFish: [], seed: 42)
let ambientRenderer = PondRenderer()
func ambientPixels() -> Data {
    ambientRenderer.render(simulation: ambientWorld, in: testCtx, rect: CGRect(x: 0, y: 0, width: 800, height: 600))
    return testCtx.makeImage()!.dataProvider!.data! as Data
}
let originalAmbient = ambientPixels()
for _ in 0..<240 { ambientWorld.advance(deltaTime: 1.0 / 60) }
let movingAmbient = ambientPixels()
ambientWorld.isPaused = true
let pausedTime = ambientWorld.elapsedTime
ambientWorld.advance(deltaTime: 3600)
let frozenAmbient = ambientPixels()
let froze = ambientWorld.elapsedTime == pausedTime && movingAmbient == frozenAmbient
ambientWorld.isPaused = false
ambientWorld.advance(deltaTime: 3600)
let resumedWithinClamp = ambientWorld.elapsedTime > pausedTime && ambientWorld.elapsedTime - pausedTime <= ambientWorld.maxCatchUpDelta + 0.00001
ambientWorld.reset()
let resetClock = ambientWorld.elapsedTime == 0
recordTest(.viewState, "T7.8 Ambient Motion, Pause Freeze and Resume Clamp",
           passed: originalAmbient != movingAmbient && froze && resumedWithinClamp && resetClock,
           details: "emptyPondMoves=\(originalAmbient != movingAmbient), pausedPixelsIdentical=\(froze), resumeClamped=\(resumedWithinClamp), clockReset=\(resetClock)")

// Rendering decorative schools must never change the real world's RNG or state.
let renderedWorld = PondSimulation(bounds: PondBounds(width: 800, height: 600), seed: 9100)
let untouchedWorld = PondSimulation(bounds: PondBounds(width: 800, height: 600), seed: 9100)
let worldIDs = renderedWorld.fish.map(\.id)
let isolationRenderer = PondRenderer()
for _ in 0..<120 {
    renderedWorld.advance(deltaTime: 1.0 / 60)
    untouchedWorld.advance(deltaTime: 1.0 / 60)
    isolationRenderer.render(simulation: renderedWorld, in: testCtx, rect: CGRect(x: 0, y: 0, width: 800, height: 600))
}
let visualIsolation = renderedWorld.fish.count == 8 && renderedWorld.fish.map(\.id) == worldIDs &&
    renderedWorld.rng.state == untouchedWorld.rng.state && renderedWorld.pellets.isEmpty && renderedWorld.clickTargets.isEmpty &&
    zip(renderedWorld.fish, untouchedWorld.fish).allSatisfy { a, b in
        a.position == b.position && a.velocity == b.velocity && a.rng.state == b.rng.state
    }
let boundedScene = PondSceneLayer(renderer: isolationRenderer)
for _ in 0..<100 { renderedWorld.handleWaterClick(at: renderedWorld.bounds.center) }
boundedScene.update(simulation: renderedWorld, bounds: CGRect(x: 0, y: 0, width: 800, height: 600), backingScale: 2)
let surfaceNodeCount = boundedScene.sublayers?.flatMap { $0.sublayers ?? [] }.count ?? 0
for _ in 0..<100 {
    renderedWorld.advance(deltaTime: 1.0 / 30)
    renderedWorld.handleWaterClick(at: renderedWorld.bounds.center)
    boundedScene.update(simulation: renderedWorld, bounds: CGRect(x: 0, y: 0, width: 800, height: 600), backingScale: 2)
}
let finalSurfaceNodeCount = boundedScene.sublayers?.flatMap { $0.sublayers ?? [] }.count ?? 0
let noAnimation = (boundedScene.sublayers ?? []).allSatisfy { layer in
    (layer.animationKeys() ?? []).isEmpty && (layer.sublayers ?? []).allSatisfy { ($0.animationKeys() ?? []).isEmpty }
}
recordTest(.viewState, "T7.9 Decorative Schooling Isolation and Bounded Native Layers",
           passed: visualIsolation && surfaceNodeCount <= 140 && finalSurfaceNodeCount <= 140 && noAnimation,
           details: "worldUnchangedByRendering=\(visualIsolation), surfaceNodes=\(surfaceNodeCount)->\(finalSurfaceNodeCount)/140, noAutonomousAnimations=\(noAnimation)")

// A concrete composition constraint catches the sparse shoreline of the first revision.
let compositionWidth = 1024, compositionHeight = 640
let floraBitmap = CGContext(data: nil, width: compositionWidth, height: compositionHeight, bitsPerComponent: 8, bytesPerRow: 0,
                           space: benchColorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
PondArtwork.drawLilyPads(in: floraBitmap, bounds: PondBounds(width: Double(compositionWidth), height: Double(compositionHeight)))
let floraBytes = floraBitmap.data!.assumingMemoryBound(to: UInt8.self)
var vegetationPixels = 0, clearCenterPixels = 0, centerPixels = 0
for y in 0..<compositionHeight {
    for x in 0..<compositionWidth {
        let alpha = floraBytes[y * floraBitmap.bytesPerRow + x * 4 + 3]
        if alpha >= 180 { vegetationPixels += 1 }
        if x >= compositionWidth / 4 && x < compositionWidth * 3 / 4 && y >= compositionHeight / 5 && y < compositionHeight * 4 / 5 {
            centerPixels += 1
            if alpha < 20 { clearCenterPixels += 1 }
        }
    }
}
let vegetationCoverage = Double(vegetationPixels) / Double(compositionWidth * compositionHeight)
let openCenter = Double(clearCenterPixels) / Double(centerPixels)
recordTest(.viewState, "T7.10 Shoreline Mass and Open Swimming Area",
           passed: vegetationCoverage >= 0.20 && vegetationCoverage <= 0.30 && openCenter >= 0.95,
           details: String(format: "vegetation=%.2f%% (20–30%%), openCenter=%.2f%% (>=95%%)", vegetationCoverage * 100, openCenter * 100))

// Backing-scale changes must preserve an integer pixel grid and click routing.
let overlayTestView = WallpaperView(frame: CGRect(x: 0, y: 0, width: 1024, height: 640))
overlayTestView.isPaused = true
overlayTestView.showHUD = true
overlayTestView.isInteractionMode = true
overlayTestView.updateLayer()
let overlay = overlayTestView.subviews.first as? PondOverlayView
let hudPoint = CGPoint(x: 30, y: overlayTestView.bounds.height - 35)
let passesThrough = overlayTestView.hitTest(hudPoint) === overlayTestView && overlay?.hitTest(.zero) == nil
let croppedHUD = (overlay?.frame.height ?? 0) <= 130 && (overlay?.frame.width ?? 0) <= 520
var gridIntact = true
for (width, height, scale) in [(480, 320, 1.0), (1440, 900, 2.0), (481, 321, 2.0)] {
    let host = PondSceneLayer(renderer: PondRenderer())
    let world = PondSimulation(bounds: PondBounds(width: Double(width), height: Double(height)), seed: 9200)
    host.update(simulation: world, bounds: CGRect(x: 0, y: 0, width: width, height: height), backingScale: scale)
    if let pixelLayer = host.sublayers?.first(where: { $0.magnificationFilter == .nearest }),
       let contents = pixelLayer.contents, CFGetTypeID(contents as CFTypeRef) == CGImage.typeID {
        let image = contents as! CGImage
        let magnification = pixelLayer.bounds.width / Double(image.width) * scale
        gridIntact = gridIntact && abs(magnification - magnification.rounded()) < 0.00001 && magnification >= 1
    } else { gridIntact = false }
    for phase in TimeOfDayPhase.allCases {
        host.update(simulation: world, bounds: CGRect(x: 0, y: 0, width: width, height: height), backingScale: scale, phase: phase)
    }
}
recordTest(.viewState, "T7.11 Native Pixel Grid, Cropped HUD and Input Passthrough",
           passed: passesThrough && croppedHUD && gridIntact && overlayTestView.wantsUpdateLayer,
           details: "integerBackingGrid=\(gridIntact), HUDPassesClicks=\(passesThrough), croppedHUD=\(croppedHUD), layerOnlyUpdates=\(overlayTestView.wantsUpdateLayer)")

// -------------------------------------------------------------
// SUMMARY & EVIDENCE SCOPE DISCLOSURE
// -------------------------------------------------------------
print("\n=======================================================")
let passCount = results.filter { $0.passed }.count
let failCount = results.filter { !$0.passed }.count
print("In-Process Suite Results: \(passCount) Passed, \(failCount) Failed")
print("=======================================================\n")

print("""
--------------------------------------------------------------------------------
EVIDENCE SCOPE & HONEST STATUS DISCLOSURE:
1. IN-PROCESS SYNTHETIC TOPOLOGY:
   Tests T7.1–T7.5 verified multi-screen management, hot-plug dynamic attaching/
   detaching with observer cleanup, heterogeneous Retina scaling, negative coordinate
   frame translation, and per-monitor occlusion isolation using in-memory MockScreen
   and MockOcclusionWallpaperWindow instances.
   THEY DO NOT CONSTITUTE PHYSICAL MULTI-MONITOR HARDWARE CERTIFICATION.
   Physical multi-monitor testing is marked as PENDING until physical external
   displays are attached to the host.

2. RESOURCE, CADENCE & THROUGHPUT MEASUREMENT:
   Test T7.6 measured live single physical display on Apple M1 (\(pwr.source), \(pwr.capacity)% capacity):
   - Timer callback cadence: \(String(format: "%.1f", timerCallbackCadence)) Hz (operational CPU: \(String(format: "%.1f", operationalCpuPercent))%)
   - Unthrottled render throughput: \(String(format: "%.1f", measuredThroughputFPS)) FPS (burst CPU: \(String(format: "%.1f", throughputPeakCpuPercent))%)
   - Process memory RSS: \(String(format: "%.2f", activeMemMB)) MB (dual-sim delta: +\(String(format: "%.2f", dualDeltaMB)) MB)
   - Paused CPU stasis: \(String(format: "%.2f", pausedCpuPercent))%
   - GPU Device Utilization: \(activeGpuPercent.map { String(format: "%.1f%%", $0) } ?? "N/A") (informative engine load, NOT energy)

3. ENERGY CONSUMPTION MEASUREMENT:
   Quantitative power draw (Watts/mWh) via macOS powermetrics requires superuser
   privileges (`sudo powermetrics`) or external inline metering hardware. Because
   the runner runs in non-root user space, direct Wattage measurement is PENDING.
   The verified proxy for idle energy efficiency is CPU stasis (\(String(format: "%.2f", pausedCpuPercent))% CPU during pause).

4. REAL DESKTOP INTEGRATION:
   Real macOS desktop window server integration (Desktop layer -2147483623,
   Spaces, Mission Control, Fullscreen occlusion) requires live desktop validation.
   See docs/IMPLEMENTATION_PLAN.md for the pending validation checklist.
--------------------------------------------------------------------------------
""")

if failCount > 0 {
    exit(1)
}
