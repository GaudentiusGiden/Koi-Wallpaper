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
    case m2Persistence = "M2 PERSIST"
    case m2TimeOfDay = "M2 TIME OF DAY"
    case m2Power = "M2 POWER/BATTERY"
    case m2Sleep = "M2 SLEEP RESUME"
    case m2Offline = "M2 OFFLINE AUDIT"
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

func spinRunLoop(for duration: TimeInterval) {
    let limit = Date().addingTimeInterval(duration)
    while Date() < limit {
        RunLoop.current.run(mode: .default, before: Date(timeIntervalSinceNow: 0.02))
    }
}

// Radius Freeze & Resume Progression Test
testView.isPaused = false
testView.addRipple(at: CGPoint(x: 150, y: 150), isFood: false)

// Wait until first animation step progresses ripple radius past initial 4.0 pt (up to 0.25s)
let startT = Date()
while Date().timeIntervalSince(startT) < 0.25 {
    RunLoop.current.run(mode: .default, before: Date(timeIntervalSinceNow: 0.02))
    if let r = testView.firstRippleRadius, r > 4.0 {
        break
    }
}

let initialRadius = testView.firstRippleRadius ?? 0.0
let hasInitialAnimation = testView.isAnimating && initialRadius > 4.0

// Pause view
testView.isPaused = true
let pausedAnimationStopped = !testView.isAnimating
spinRunLoop(for: 0.10)
let radiusDuringPause = testView.firstRippleRadius ?? 0.0
let pausedStatePreserved = (radiusDuringPause == initialRadius)

// Resume view
testView.isPaused = false
let resumedAnimationRestarted = testView.isAnimating

// Wait until resumed animation progresses ripple radius further (up to 0.25s)
let resumeT = Date()
while Date().timeIntervalSince(resumeT) < 0.25 {
    RunLoop.current.run(mode: .default, before: Date(timeIntervalSinceNow: 0.02))
    if let r = testView.firstRippleRadius, r > radiusDuringPause {
        break
    }
}

let radiusAfterResume = testView.firstRippleRadius ?? 0.0
let resumedRadiusProgressed = (radiusAfterResume > radiusDuringPause)

recordTest(
    .viewState,
    "T4.6 Animation Freeze & Resume Radius Progression",
    passed: hasInitialAnimation && pausedAnimationStopped && pausedStatePreserved && resumedAnimationRestarted && resumedRadiusProgressed,
    details: "initial=\(initialRadius), frozen=\(radiusDuringPause), resumed=\(radiusAfterResume). Radius is preserved during pause and increases after resume."
)

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
All tests above verified in-memory AppKit object configurations, state
coordinators, synthetic NSEvent dispatch, and synthetic notification handling.
THEY DO NOT PROVE REAL macOS DESKTOP WINDOW SERVER INTEGRATION.

Real macOS desktop integration (Finder interaction, window layering, focus
behavior, Spaces/fullscreen transitions, occlusion, and hardware sleep/wake)
is outside the scope of this in-process test suite.
Refer to docs/M0_AUDIT.md Section 5 for the live desktop validation checklist
and latest verified status.
--------------------------------------------------------------------------------
""")

if failCount > 0 {
    exit(1)
}
