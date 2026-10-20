import Foundation
import IOKit.ps
import OSLog

private let logger = Logger(subsystem: "com.koiwallpaper.KoiWallpaper", category: "Power")

/// Abstraction for power source observation (AC wall power vs internal battery).
public protocol PowerSourceMonitoring: AnyObject {
    var isRunningOnBattery: Bool { get }
    var onPowerSourceChanged: (() -> Void)? { get set }
    func startMonitoring()
    func stopMonitoring()
}

/// Native macOS power source monitoring using IOKit IOPowerSources.
public final class IOKitPowerSourceMonitor: PowerSourceMonitoring {
    public var onPowerSourceChanged: (() -> Void)?
    private var runLoopSource: CFRunLoopSource?

    public init() {}

    public var isRunningOnBattery: Bool {
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue() else {
            return false
        }
        guard let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef] else {
            return false
        }
        for source in sources {
            if let desc = IOPSGetPowerSourceDescription(snapshot, source)?.takeUnretainedValue() as? [String: Any],
               let state = desc[kIOPSPowerSourceStateKey as String] as? String {
                if state == (kIOPSBatteryPowerValue as String) {
                    return true
                }
            }
        }
        return false
    }

    public func startMonitoring() {
        stopMonitoring()
        let context = Unmanaged.passUnretained(self).toOpaque()
        let source = IOPSNotificationCreateRunLoopSource({ info in
            guard let info = info else { return }
            let monitor = Unmanaged<IOKitPowerSourceMonitor>.fromOpaque(info).takeUnretainedValue()
            logger.info("Power source changed notification received from IOKit.")
            monitor.onPowerSourceChanged?()
        }, context)?.takeRetainedValue()

        if let source = source {
            CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
            self.runLoopSource = source
        }
    }

    public func stopMonitoring() {
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
            runLoopSource = nil
        }
    }

    deinit {
        stopMonitoring()
    }
}

/// Mock power source monitor for deterministic testing.
public final class MockPowerSourceMonitor: PowerSourceMonitoring {
    public var isRunningOnBattery: Bool {
        didSet {
            if oldValue != isRunningOnBattery {
                onPowerSourceChanged?()
            }
        }
    }

    public var onPowerSourceChanged: (() -> Void)?

    public init(isRunningOnBattery: Bool = false) {
        self.isRunningOnBattery = isRunningOnBattery
    }

    public func startMonitoring() {}
    public func stopMonitoring() {}
}
