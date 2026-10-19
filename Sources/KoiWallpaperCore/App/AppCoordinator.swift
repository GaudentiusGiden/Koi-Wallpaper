import AppKit
import OSLog

private let logger = Logger(subsystem: "com.koiwallpaper.KoiWallpaper", category: "Coordinator")

public final class AppCoordinator: NSObject,
                                    LifecyclePolicyDelegate,
                                    InputCoordinatorDelegate,
                                    StatusBarControllerDelegate {

    public let lifecyclePolicy: LifecyclePolicy
    public let inputCoordinator: InputCoordinator
    public private(set) var desktopWindowController: DesktopWindowController?
    public private(set) var statusBarController: StatusBarController?

    public init(
        lifecyclePolicy: LifecyclePolicy = LifecyclePolicy(),
        inputCoordinator: InputCoordinator = InputCoordinator(initialMode: .clickThrough)
    ) {
        self.lifecyclePolicy = lifecyclePolicy
        self.inputCoordinator = inputCoordinator
        super.init()

        self.lifecyclePolicy.delegate = self
        self.inputCoordinator.delegate = self
    }

    public func start() {
        logger.info("Starting KoiWallpaper M0 Desktop Host...")

        guard let screen = NSScreen.main ?? NSScreen.screens.first else {
            logger.error("No active NSScreen found.")
            return
        }

        // Initialize desktop window controller
        let windowController = DesktopWindowController(screen: screen)
        windowController.wallpaperView.inputCoordinator = inputCoordinator
        windowController.applyInteractionMode(inputCoordinator.currentMode)
        windowController.show()
        self.desktopWindowController = windowController

        // Bind window to lifecycle policy
        lifecyclePolicy.bindWindow(windowController.window)
        windowController.wallpaperView.isPaused = lifecyclePolicy.isPaused

        // Initialize menu bar status item
        let statusController = StatusBarController()
        statusController.delegate = self
        statusController.updateInteractionMode(inputCoordinator.currentMode)
        statusController.updatePauseState(
            isPaused: lifecyclePolicy.isPaused,
            reasons: lifecyclePolicy.activePauseReasons
        )
        self.statusBarController = statusController

        logger.info("KoiWallpaper M0 started successfully on screen \(screen.frame.size.width)x\(screen.frame.size.height).")
    }

    // MARK: - LifecyclePolicyDelegate

    public func lifecyclePolicy(_ policy: LifecyclePolicy, didUpdatePauseReasons reasons: Set<PauseReason>, isPaused: Bool) {
        logger.info("Lifecycle pause state updated. isPaused: \(isPaused), reasons: \(reasons.map(\.rawValue).joined(separator: ", "))")
        desktopWindowController?.wallpaperView.isPaused = isPaused
        statusBarController?.updatePauseState(isPaused: isPaused, reasons: reasons)
    }

    public func lifecyclePolicyDidRequestScreenReconfiguration(_ policy: LifecyclePolicy) {
        logger.info("Screen reconfiguration requested.")
        desktopWindowController?.updateScreenConfiguration()
    }

    // MARK: - InputCoordinatorDelegate

    public func inputCoordinator(_ coordinator: InputCoordinator, didChangeMode mode: InputInteractionMode) {
        logger.info("Input mode changed to: \(mode.rawValue)")
        desktopWindowController?.applyInteractionMode(mode)
        statusBarController?.updateInteractionMode(mode)
    }

    public func inputCoordinator(_ coordinator: InputCoordinator, didReceiveClickAt point: CGPoint, isOptionClick: Bool) {
        logger.info("Input received in interactive mode at (\(point.x), \(point.y)), isOptionClick: \(isOptionClick)")
    }

    // MARK: - StatusBarControllerDelegate

    public func statusBarDidToggleInteractionMode(_ controller: StatusBarController) {
        inputCoordinator.toggleMode()
    }

    public func statusBarDidToggleManualPause(_ controller: StatusBarController) {
        let isManualPaused = lifecyclePolicy.activePauseReasons.contains(.manual)
        lifecyclePolicy.setManualPause(!isManualPaused)
    }

    public func statusBarDidRequestQuit(_ controller: StatusBarController) {
        logger.info("User requested quit. Terminating application.")
        NSApplication.shared.terminate(nil)
    }
}
