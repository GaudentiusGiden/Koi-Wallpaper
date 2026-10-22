import Foundation

/// Action to execute if an automatic idle condition is evaluated.
public enum IdleAction: String, Codable, CaseIterable, Sendable {
    case none = "none"
    case pauseSimulation = "pauseSimulation"
    case enterFullscreen = "enterFullscreen"

    public var displayName: String {
        switch self {
        case .none: return "Tidak Ada (None)"
        case .pauseSimulation: return "Jeda Simulasi (Pause)"
        case .enterFullscreen: return "Mode Layar Penuh (Enter Fullscreen)"
        }
    }
}

/// Architectural policy separating automatic user/system idle decisions from manual fullscreen mode.
///
/// Design Guarantees:
/// 1. Zero system power interference: Does NOT alter macOS system sleep, display sleep, screen lock,
///    or power management settings.
/// 2. Clear isolation: Manual fullscreen is strictly an explicit user action (menu bar / shortcut)
///    independent of idle state.
/// 3. Not a macOS screen saver: Manual fullscreen is an in-app visual mode and makes no claim of
///    integrating as a native macOS screen saver bundle.
public struct IdleBehaviorPolicy: Codable, Equatable, Sendable {
    /// Whether automatic idle handling is enabled. Disabled by default.
    public var isEnabled: Bool

    /// User inactivity duration in seconds before idle evaluation.
    public var idleTimeoutSeconds: TimeInterval

    /// Action selected for idle state.
    public var action: IdleAction

    public init(
        isEnabled: Bool = false,
        idleTimeoutSeconds: TimeInterval = 300.0,
        action: IdleAction = .none
    ) {
        self.isEnabled = isEnabled
        self.idleTimeoutSeconds = idleTimeoutSeconds
        self.action = action
    }
}
