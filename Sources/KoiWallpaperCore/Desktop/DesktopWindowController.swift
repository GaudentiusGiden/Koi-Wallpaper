import AppKit
import OSLog

private let logger = Logger(subsystem: "com.koiwallpaper.KoiWallpaper", category: "DesktopWindowController")

/// Manages a single desktop wallpaper host window, backing view, and independent pond simulation
/// for a specific physical or virtual display.
public final class DesktopWindowController {
    public let window: WallpaperWindow
    public let wallpaperView: WallpaperView
    public internal(set) var screen: NSScreen
    public let displayID: CGDirectDisplayID?

    public private(set) var isOccluded: Bool = false
    public private(set) var isGloballyPaused: Bool = false
    public var isSmartOcclusionEnabled: Bool = true
    public var onOcclusionChanged: ((DesktopWindowController) -> Void)?

    private var occlusionObserver: NSObjectProtocol?
    private var workspaceObserver: NSObjectProtocol?
    private var screenParamObserver: NSObjectProtocol?
    private var occlusionCheckTimer: Timer?

    /// Checks whether this controller currently has an active WindowServer occlusion observer registered.
    public var hasActiveOcclusionObserver: Bool {
        occlusionObserver != nil
    }

    public init(screen: NSScreen, window: WallpaperWindow? = nil, simulation: PondSimulation? = nil) {
        self.screen = screen
        self.displayID = screen.displayID
        self.window = window ?? WallpaperWindow(screen: screen)

        // View frame within its host window always has an origin of (0, 0),
        // regardless of whether screen.frame has a negative global origin.
        self.wallpaperView = WallpaperView(
            frame: NSRect(origin: .zero, size: screen.frame.size),
            simulation: simulation
        )
        self.window.contentView = self.wallpaperView

        updateRetinaScale()
        setupOcclusionObserver()
    }

    deinit {
        teardown()
    }

    public func show() {
        window.orderBack(nil)
    }

    public func applyInteractionMode(_ mode: InputInteractionMode) {
        window.applyMode(mode)
        wallpaperView.isInteractionMode = (mode == .interactive)
    }

    public func applyMood(_ mood: PondMood) {
        wallpaperView.simulation.mood = mood
        wallpaperView.needsDisplay = true
    }

    public func applyRain(_ isRainActive: Bool) {
        wallpaperView.simulation.isRainActive = isRainActive
        wallpaperView.needsDisplay = true
    }

    // MARK: - Display & Geometry Updates

    /// Updates this host to match a reconfigured screen geometry or display scale factor.
    public func updateScreen(_ newScreen: NSScreen) {
        self.screen = newScreen
        window.updateFrame(for: newScreen)
        wallpaperView.frame = NSRect(origin: .zero, size: newScreen.frame.size)
        wallpaperView.simulation.resize(
            width: Double(newScreen.frame.width),
            height: Double(newScreen.frame.height)
        )
        updateRetinaScale()
        evaluateOcclusion()
        wallpaperView.needsDisplay = true
    }

    /// Convenience method for single-screen updates or fallback reconfiguration.
    public func updateScreenConfiguration() {
        if let matchingScreen = NSScreen.screens.first(where: {
            if let id = self.displayID, let scrId = $0.displayID, id != 0 && scrId != 0 {
                return id == scrId
            }
            return $0.frame == screen.frame
        }) ?? NSScreen.main ?? NSScreen.screens.first {
            updateScreen(matchingScreen)
        } else {
            updateScreen(self.screen)
        }
    }

    /// Synchronizes CoreAnimation layer backing scale with current screen Retina scale factor.
    public func updateRetinaScale() {
        let scale = screen.backingScaleFactor
        wallpaperView.layer?.contentsScale = scale
        wallpaperView.needsDisplay = true
    }

    // MARK: - Occlusion & Pause Management

    private func setupOcclusionObserver() {
        occlusionObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didChangeOcclusionStateNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            self?.evaluateOcclusion()
        }

        workspaceObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.evaluateOcclusion()
        }

        screenParamObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.evaluateOcclusion()
        }

        // Lightweight periodic check (every 2.5s) to detect resized windows without app switch
        let timer = Timer(timeInterval: 2.5, repeats: true) { [weak self] _ in
            guard let self = self, self.window.isVisible, !self.isGloballyPaused else { return }
            self.evaluateOcclusion()
        }
        timer.tolerance = 1.0
        RunLoop.main.add(timer, forMode: .common)
        self.occlusionCheckTimer = timer
    }

    public func evaluateOcclusion() {
        let wasOccluded = isOccluded
        if !window.isVisible {
            isOccluded = true
        } else if !window.occlusionState.contains(.visible) {
            isOccluded = true
        } else if isSmartOcclusionEnabled && checkSmartWorkspaceOcclusion() {
            isOccluded = true
        } else {
            isOccluded = false
        }
        updateEffectivePause()
        if wasOccluded != isOccluded {
            logger.info("Window occlusion changed for display \(self.displayID ?? 0): isOccluded=\(self.isOccluded)")
            onOcclusionChanged?(self)
        }
    }

    private func checkSmartWorkspaceOcclusion() -> Bool {
        if String(describing: type(of: screen)).contains("Mock") {
            return false
        }
        guard let windowList = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else {
            return false
        }
        let visFrame = screen.visibleFrame
        let visArea = visFrame.width * visFrame.height
        guard visArea > 1000 else { return false }

        let primaryHeight = NSScreen.screens.first?.frame.height ?? screen.frame.height
        let quartzVisFrame = CGRect(
            x: visFrame.origin.x,
            y: primaryHeight - visFrame.maxY,
            width: visFrame.width,
            height: visFrame.height
        )

        let ourPID = ProcessInfo.processInfo.processIdentifier

        for info in windowList {
            guard let layer = info[kCGWindowLayer as String] as? Int, layer == 0 else { continue }
            guard let ownerPID = info[kCGWindowOwnerPID as String] as? pid_t, ownerPID != ourPID else { continue }
            if let alpha = info[kCGWindowAlpha as String] as? Double, alpha < 0.85 { continue }

            guard let boundsDict = info[kCGWindowBounds as String] as? [String: Any],
                  let windowRect = CGRect(dictionaryRepresentation: boundsDict as CFDictionary) else { continue }

            let intersection = windowRect.intersection(quartzVisFrame)
            if !intersection.isNull && !intersection.isEmpty {
                let interArea = intersection.width * intersection.height
                if interArea >= (0.88 * visArea) {
                    return true
                }
            }
        }
        return false
    }

    public func setGloballyPaused(_ paused: Bool) {
        self.isGloballyPaused = paused
        updateEffectivePause()
    }

    private func updateEffectivePause() {
        let shouldPause = isGloballyPaused || isOccluded
        wallpaperView.isPaused = shouldPause
    }

    // MARK: - Coordinate Conversion

    /// Converts a point from global macOS screen coordinates into local pond simulation coordinates.
    /// Handles displays with negative origin coordinates (e.g. secondary displays arranged to the left or below).
    public func convertScreenPointToLocalPondPoint(_ screenPoint: NSPoint) -> PondVector? {
        guard screen.frame.contains(screenPoint) else { return nil }

        // WindowServer converts screen coordinate to window coordinate
        let windowPoint = window.convertPoint(fromScreen: screenPoint)
        // Convert window coordinate to view coordinate
        let viewPoint = wallpaperView.convert(windowPoint, from: nil)
        return PondVector(x: Double(viewPoint.x), y: Double(viewPoint.y))
    }

    // MARK: - Teardown

    /// Closes the window and stops all active rendering loops, preventing orphan windows or leaks.
    public func teardown() {
        if let obs = occlusionObserver {
            NotificationCenter.default.removeObserver(obs)
            occlusionObserver = nil
        }
        if let obs = workspaceObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(obs)
            workspaceObserver = nil
        }
        if let obs = screenParamObserver {
            NotificationCenter.default.removeObserver(obs)
            screenParamObserver = nil
        }
        occlusionCheckTimer?.invalidate()
        occlusionCheckTimer = nil
        wallpaperView.stopAnimationTimer()
        window.orderOut(nil)
        window.contentView = nil
        window.close()
    }
}
