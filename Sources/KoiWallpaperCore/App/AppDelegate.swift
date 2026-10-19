import AppKit

public final class AppDelegate: NSObject, NSApplicationDelegate {
    public private(set) var coordinator: AppCoordinator?

    public func applicationDidFinishLaunching(_ notification: Notification) {
        // Run as accessory app: no Dock icon, menu bar only
        NSApp.setActivationPolicy(.accessory)

        let coordinator = AppCoordinator()
        coordinator.start()
        self.coordinator = coordinator
    }

    public func applicationWillTerminate(_ notification: Notification) {
        // Cleanup upon termination
    }
}
