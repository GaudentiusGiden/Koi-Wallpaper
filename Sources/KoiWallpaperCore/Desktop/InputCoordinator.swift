import AppKit

public enum InputInteractionMode: String, CaseIterable, Codable, Sendable {
    /// Default mode: mouse events pass through completely to Finder and desktop icons.
    case clickThrough = "clickThrough"
    /// Explicit mode: window captures mouse events (clicks, Option+clicks, drags) for koi pond interaction.
    case interactive = "interactive"
}

public protocol InputCoordinatorDelegate: AnyObject {
    func inputCoordinator(_ coordinator: InputCoordinator, didChangeMode mode: InputInteractionMode)
    func inputCoordinator(_ coordinator: InputCoordinator, didReceiveClickAt point: CGPoint, isOptionClick: Bool)
}

public final class InputCoordinator {
    public weak var delegate: InputCoordinatorDelegate?

    public private(set) var currentMode: InputInteractionMode = .clickThrough {
        didSet {
            if oldValue != currentMode {
                delegate?.inputCoordinator(self, didChangeMode: currentMode)
            }
        }
    }

    public init(initialMode: InputInteractionMode = .clickThrough) {
        self.currentMode = initialMode
    }

    public func setMode(_ mode: InputInteractionMode) {
        self.currentMode = mode
    }

    public func toggleMode() {
        setMode(currentMode == .clickThrough ? .interactive : .clickThrough)
    }

    public func handleClick(at point: CGPoint, modifierFlags: NSEvent.ModifierFlags) {
        let isOption = modifierFlags.contains(.option)
        delegate?.inputCoordinator(self, didReceiveClickAt: point, isOptionClick: isOption)
    }
}
