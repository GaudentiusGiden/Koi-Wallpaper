import AppKit

public final class AppDelegate: NSObject, NSApplicationDelegate {
    public private(set) var coordinator: AppCoordinator?

    public func applicationDidFinishLaunching(_ notification: Notification) {
        if let bundleID = Bundle.main.bundleIdentifier {
            let currentPID = ProcessInfo.processInfo.processIdentifier
            let otherInstances = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
                .filter { $0.processIdentifier != currentPID && !$0.isTerminated }
            if !otherInstances.isEmpty {
                NSApp.terminate(nil)
                return
            }
        }

        // Run as accessory app: no Dock icon, menu bar only
        NSApp.setActivationPolicy(.accessory)

        let coordinator = AppCoordinator()
        coordinator.start()
        self.coordinator = coordinator
    }

    public func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        coordinator?.statusBarController?.popUpMenu()
        return false
    }

    public func applicationWillTerminate(_ notification: Notification) {
        coordinator?.teardown()
    }
}
