import AppKit
import Foundation
import OSLog

private let logger = Logger(subsystem: "com.koiwallpaper.KoiWallpaper", category: "ScreenManager")

extension NSScreen {
    /// Returns the unique hardware display identifier for this screen, if available.
    public var displayID: CGDirectDisplayID? {
        (deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value
    }
}

/// Manages multiple desktop wallpaper hosts across all connected monitors.
/// Provides independent simulation worlds per display while propagating global settings
/// (time of day, interaction mode, HUD, and global pause policies).
public final class ScreenManager {

    public typealias ScreenProvider = () -> [NSScreen]

    public var screenProvider: ScreenProvider
    public private(set) var controllers: [DesktopWindowController] = []

    public var primaryController: DesktopWindowController? {
        controllers.first
    }

    public var screenCount: Int {
        controllers.count
    }

    public private(set) var currentMode: InputInteractionMode = .clickThrough
    public private(set) var currentPhase: TimeOfDayPhase = .day
    public private(set) var currentTheme: PondTheme = .day
    public private(set) var currentShowHUD: Bool = false
    public private(set) var isGloballyPaused: Bool = false
    public private(set) var currentMood: PondMood = .calm
    public private(set) var currentIsRainActive: Bool = false
    public weak var inputCoordinator: InputCoordinator?

    public var onControllersChanged: (([DesktopWindowController]) -> Void)?
    public var onControllerRemoved: ((DesktopWindowController) -> Void)?
    public var onOcclusionChanged: ((DesktopWindowController) -> Void)?
    public var controllerFactory: ((NSScreen) -> DesktopWindowController)?

    private var screenParamObserver: NSObjectProtocol?

    public init(
        screenProvider: @escaping ScreenProvider = { NSScreen.screens },
        controllerFactory: ((NSScreen) -> DesktopWindowController)? = nil,
        inputCoordinator: InputCoordinator? = nil,
        timeOfDayPhase: TimeOfDayPhase = .day,
        theme: PondTheme? = nil,
        showHUD: Bool = false,
        isGloballyPaused: Bool = false,
        mood: PondMood = .calm,
        isRainActive: Bool = false
    ) {
        self.screenProvider = screenProvider
        self.controllerFactory = controllerFactory
        self.inputCoordinator = inputCoordinator
        let resolvedTheme = theme ?? timeOfDayPhase.theme
        self.currentTheme = resolvedTheme
        self.currentPhase = resolvedTheme.asTimePhase ?? timeOfDayPhase
        self.currentShowHUD = showHUD
        self.isGloballyPaused = isGloballyPaused
        self.currentMood = mood
        self.currentIsRainActive = isRainActive
        if let input = inputCoordinator {
            self.currentMode = input.currentMode
        }

        reconfigureScreens(initial: true)
        setupNotificationObserver()
    }

    deinit {
        teardown()
    }

    // MARK: - Screen Lifecycle & Reconfiguration

    private func setupNotificationObserver() {
        screenParamObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.reconfigureScreens(initial: false)
        }
    }

    /// Re-evaluates connected screens, detaching disconnected monitors and instantiating hosts for new ones.
    public func reconfigureScreens(initial: Bool = false) {
        let activeScreens = screenProvider()
        logger.info("Reconfiguring screens. Detected \(activeScreens.count) active screen(s).")

        var remainingControllers: [DesktopWindowController] = []
        var unmatchedScreens = activeScreens

        // 1. Match and update existing controllers
        for controller in controllers {
            if let matchIndex = unmatchedScreens.firstIndex(where: { screenMatches(controller: controller, screen: $0) }) {
                let matchedScreen = unmatchedScreens.remove(at: matchIndex)
                controller.updateScreen(matchedScreen)
                remainingControllers.append(controller)
            } else {
                // Screen was removed / disconnected (hot-unplug)
                logger.info("Screen removed. Tearing down controller for display \(controller.displayID ?? 0).")
                onControllerRemoved?(controller)
                controller.teardown()
            }
        }

        // 2. Add controllers for newly connected screens (hot-plug)
        for newScreen in unmatchedScreens {
            logger.info("New screen detected. Creating host controller for display \(newScreen.displayID ?? 0).")
            let newController = createController(for: newScreen)
            remainingControllers.append(newController)
        }

        self.controllers = remainingControllers

        if !initial {
            onControllersChanged?(controllers)
        }
    }

    private func screenMatches(controller: DesktopWindowController, screen: NSScreen) -> Bool {
        if let ctrlID = controller.displayID, let scrID = screen.displayID, ctrlID != 0 && scrID != 0 {
            return ctrlID == scrID
        }
        return controller.screen === screen || controller.screen.frame == screen.frame
    }

    private func createController(for screen: NSScreen) -> DesktopWindowController {
        let controller = controllerFactory?(screen) ?? DesktopWindowController(screen: screen)
        controller.wallpaperView.simulation.setAutomaticSwanEnabled(true)
        controller.wallpaperView.inputCoordinator = inputCoordinator
        controller.wallpaperView.theme = currentTheme
        controller.wallpaperView.showHUD = currentShowHUD
        controller.applyMood(currentMood)
        controller.applyRain(currentIsRainActive)
        controller.applyInteractionMode(currentMode)
        controller.setGloballyPaused(isGloballyPaused)
        if !isGloballyPaused {
            controller.wallpaperView.startAnimationTimer()
        }
        controller.onOcclusionChanged = { [weak self, weak controller] _ in
            guard let self = self, let ctrl = controller else { return }
            self.onOcclusionChanged?(ctrl)
        }
        controller.show()
        return controller
    }

    public func teardown() {
        if let obs = screenParamObserver {
            NotificationCenter.default.removeObserver(obs)
            screenParamObserver = nil
        }
        for controller in controllers {
            onControllerRemoved?(controller)
            controller.teardown()
        }
        controllers.removeAll()
    }

    // MARK: - Global Settings Propagation

    public func applyInteractionMode(_ mode: InputInteractionMode) {
        self.currentMode = mode
        for controller in controllers {
            controller.applyInteractionMode(mode)
        }
    }

    public func applyTheme(_ theme: PondTheme) {
        self.currentTheme = theme
        if let phase = theme.asTimePhase {
            self.currentPhase = phase
        }
        for controller in controllers {
            controller.wallpaperView.theme = theme
        }
    }

    public func applyTimeOfDayPhase(_ phase: TimeOfDayPhase) {
        applyTheme(phase.theme)
    }

    public func applyHUDVisibility(_ show: Bool) {
        self.currentShowHUD = show
        for controller in controllers {
            controller.wallpaperView.showHUD = show
        }
    }

    public func applyGlobalPause(_ isPaused: Bool) {
        self.isGloballyPaused = isPaused
        for controller in controllers {
            controller.setGloballyPaused(isPaused)
        }
    }

    public func applyMood(_ mood: PondMood) {
        self.currentMood = mood
        for controller in controllers {
            controller.applyMood(mood)
        }
    }

    public func applyRain(_ isRainActive: Bool) {
        self.currentIsRainActive = isRainActive
        for controller in controllers {
            controller.applyRain(isRainActive)
        }
    }

    // MARK: - Visitors Management

    /// Spawns a visitor on all managed screen pond simulations.
    @discardableResult
    public func spawnVisitor(type: PondVisitorType, at point: PondVector? = nil) -> [PondVisitor] {
        var created: [PondVisitor] = []
        for controller in controllers {
            let v = controller.wallpaperView.simulation.spawnVisitor(type: type, at: point)
            created.append(v)
            controller.wallpaperView.needsDisplay = true
        }
        return created
    }

    /// Clears all visitors across all screen simulations, guaranteeing no stuck koi targets.
    public func clearVisitors() {
        for controller in controllers {
            controller.wallpaperView.simulation.clearVisitors()
            controller.wallpaperView.needsDisplay = true
        }
    }

    public var totalVisitorsCount: Int {
        controllers.reduce(0) { count, controller in
            count + controller.wallpaperView.simulation.visitors.filter { !$0.isAutonomous }.count
        }
    }

    // MARK: - Coordinate Conversion & Click Dispatch

    /// Locates the DesktopWindowController hosting the given global screen point.
    public func controller(forScreenPoint screenPoint: NSPoint) -> DesktopWindowController? {
        controllers.first { $0.screen.frame.contains(screenPoint) }
    }

    /// Dispatches a click in global screen coordinates to the appropriate monitor's pond simulation.
    @discardableResult
    public func handleScreenClick(at screenPoint: NSPoint, isOptionClick: Bool) -> (controller: DesktopWindowController, pondPoint: PondVector)? {
        guard let controller = controller(forScreenPoint: screenPoint),
              let localPoint = controller.convertScreenPointToLocalPondPoint(screenPoint) else {
            return nil
        }

        if isOptionClick {
            controller.wallpaperView.simulation.handleFoodDrop(at: localPoint)
        } else {
            controller.wallpaperView.simulation.handleWaterClick(at: localPoint)
        }
        controller.wallpaperView.needsDisplay = true
        inputCoordinator?.handleClick(at: CGPoint(x: localPoint.x, y: localPoint.y), modifierFlags: isOptionClick ? [.option] : [])
        return (controller, localPoint)
    }

    // MARK: - State Inspection

    public var isAllScreensCovered: Bool {
        !controllers.isEmpty && controllers.allSatisfy { $0.isOccluded }
    }

    public var isAnyScreenActive: Bool {
        controllers.contains { !$0.wallpaperView.isPaused }
    }
}
