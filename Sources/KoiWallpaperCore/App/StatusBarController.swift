import AppKit

public protocol StatusBarControllerDelegate: AnyObject {
    func statusBarDidToggleInteractionMode(_ controller: StatusBarController)
    func statusBarDidToggleManualPause(_ controller: StatusBarController)
    func statusBarDidRequestQuit(_ controller: StatusBarController)
}

public final class StatusBarController {
    public weak var delegate: StatusBarControllerDelegate?

    private var statusItem: NSStatusItem?
    private let menu = NSMenu()

    // Menu item references for dynamic updates
    private let headerItem = NSMenuItem(title: "Koi Wallpaper (M0)", action: nil, keyEquivalent: "")
    private let interactionToggleItem = NSMenuItem(
        title: "Mode Interaksi (Tangkap Klik)",
        action: #selector(interactionToggled),
        keyEquivalent: "i"
    )
    private let interactionDescItem = NSMenuItem(title: "Status: Tembus Klik Finder (Default)", action: nil, keyEquivalent: "")
    private let levelInfoItem = NSMenuItem(title: "Level Jendela: Desktop", action: nil, keyEquivalent: "")
    private let pauseStatusItem = NSMenuItem(title: "Status Kolam: Aktif", action: nil, keyEquivalent: "")
    private let pauseToggleItem = NSMenuItem(
        title: "Jeda Manual (Pause)",
        action: #selector(pauseToggled),
        keyEquivalent: "p"
    )
    private let quitItem = NSMenuItem(
        title: "Keluar Koi Wallpaper",
        action: #selector(quitClicked),
        keyEquivalent: "q"
    )

    public init() {
        setupStatusItem()
    }

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            button.title = "🐟"
            button.toolTip = "Koi Wallpaper"
        }

        setupMenu()
        item.menu = menu
        self.statusItem = item
    }

    private func setupMenu() {
        headerItem.isEnabled = false
        interactionDescItem.isEnabled = false
        levelInfoItem.isEnabled = false
        pauseStatusItem.isEnabled = false

        interactionToggleItem.target = self
        pauseToggleItem.target = self
        quitItem.target = self

        menu.addItem(headerItem)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(interactionToggleItem)
        menu.addItem(interactionDescItem)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(levelInfoItem)
        menu.addItem(pauseStatusItem)
        menu.addItem(pauseToggleItem)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(quitItem)
    }

    public func updateInteractionMode(_ mode: InputInteractionMode) {
        let isInteractive = (mode == .interactive)
        interactionToggleItem.state = isInteractive ? .on : .off
        interactionDescItem.title = isInteractive
            ? "Status: Tangkap Klik (Kolam Interaktif)"
            : "Status: Tembus Klik Finder (Default)"
        levelInfoItem.title = isInteractive
            ? "Level Jendela: Di atas Ikon Desktop (-2147483602)"
            : "Level Jendela: Lapisan Desktop (-2147483623)"

        if let button = statusItem?.button {
            button.title = isInteractive ? "🐟⚡" : "🐟"
        }
    }

    public func updatePauseState(isPaused: Bool, reasons: Set<PauseReason>) {
        if isPaused {
            let reasonStr = reasons.map(\.rawValue).sorted().joined(separator: ", ")
            pauseStatusItem.title = "Status Kolam: Paused (\(reasonStr))"
            pauseToggleItem.state = reasons.contains(.manual) ? .on : .off
        } else {
            pauseStatusItem.title = "Status Kolam: Aktif"
            pauseToggleItem.state = .off
        }
    }

    @objc private func interactionToggled() {
        delegate?.statusBarDidToggleInteractionMode(self)
    }

    @objc private func pauseToggled() {
        delegate?.statusBarDidToggleManualPause(self)
    }

    @objc private func quitClicked() {
        delegate?.statusBarDidRequestQuit(self)
    }
}
