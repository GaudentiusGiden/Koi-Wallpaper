import AppKit
import Foundation
import OSLog
import ServiceManagement

private let logger = Logger(subsystem: "com.koiwallpaper.KoiWallpaper", category: "LaunchAtLogin")

/// Protocol abstraction for managing macOS Launch at Login / Start on Boot.
public protocol LaunchAtLoginManaging: AnyObject {
    /// Indicates whether the app is currently configured to launch automatically when the user logs in or MacBook boots up.
    var isEnabled: Bool { get }

    /// Indicates whether user approval is required in System Settings -> General -> Login Items.
    var requiresApproval: Bool { get }

    /// Human-readable status description for logging or UI.
    var statusDescription: String { get }

    /// Sets whether the app should launch at login.
    func setEnabled(_ enabled: Bool) throws

    /// Opens macOS System Settings directly to the Login Items section.
    func openLoginItemsSettings()
}

/// Standard production implementation using macOS 13+ / 14+ `SMAppService.mainApp`.
public final class SystemLaunchAtLoginManager: LaunchAtLoginManaging {
    public init() {}

    private var isAppBundle: Bool {
        Bundle.main.bundleURL.pathExtension.lowercased() == "app"
    }

    public var isEnabled: Bool {
        guard isAppBundle else { return false }
        return SMAppService.mainApp.status == .enabled
    }

    public var requiresApproval: Bool {
        guard isAppBundle else { return false }
        return SMAppService.mainApp.status == .requiresApproval
    }

    public var statusDescription: String {
        guard isAppBundle else {
            return "Tidak Ditemukan (Aplikasi belum terpasang sebagai bundle)"
        }
        switch SMAppService.mainApp.status {
        case .enabled:
            return "Aktif"
        case .notRegistered:
            return "Nonaktif"
        case .requiresApproval:
            return "Memerlukan Persetujuan Pengguna di Pengaturan Sistem"
        case .notFound:
            return "Tidak Ditemukan (Aplikasi belum terpasang sebagai bundle)"
        @unknown default:
            return "Status Tidak Diketahui"
        }
    }

    public func setEnabled(_ enabled: Bool) throws {
        guard isAppBundle else {
            logger.warning("Skipping SMAppService \(enabled ? "registration" : "unregistration"): process is not running within a .app bundle.")
            return
        }
        if enabled {
            logger.info("Registering main application with SMAppService...")
            try SMAppService.mainApp.register()
            logger.info("SMAppService registration succeeded. Status: \(String(describing: SMAppService.mainApp.status.rawValue))")
        } else {
            logger.info("Unregistering main application with SMAppService...")
            try SMAppService.mainApp.unregister()
            logger.info("SMAppService unregistration succeeded. Status: \(String(describing: SMAppService.mainApp.status.rawValue))")
        }
    }

    public func openLoginItemsSettings() {
        logger.info("Opening System Settings -> Login Items...")
        SMAppService.openSystemSettingsLoginItems()
    }
}

/// Mock implementation for deterministic automated testing.
public final class MockLaunchAtLoginManager: LaunchAtLoginManaging {
    public var isEnabled: Bool
    public var requiresApproval: Bool
    public var statusDescription: String
    public var shouldThrowOnSetEnabled: Bool = false
    public var setEnabledCalls: [Bool] = []
    public var openLoginItemsSettingsCalled: Bool = false

    public init(
        isEnabled: Bool = false,
        requiresApproval: Bool = false,
        statusDescription: String = "Mock Status"
    ) {
        self.isEnabled = isEnabled
        self.requiresApproval = requiresApproval
        self.statusDescription = statusDescription
    }

    public func setEnabled(_ enabled: Bool) throws {
        if shouldThrowOnSetEnabled {
            throw NSError(
                domain: "com.koiwallpaper.mock.launchatlogin",
                code: 1001,
                userInfo: [NSLocalizedDescriptionKey: "Simulated registration error"]
            )
        }
        setEnabledCalls.append(enabled)
        self.isEnabled = enabled
        self.statusDescription = enabled ? "Aktif" : "Nonaktif"
    }

    public func openLoginItemsSettings() {
        openLoginItemsSettingsCalled = true
    }
}
