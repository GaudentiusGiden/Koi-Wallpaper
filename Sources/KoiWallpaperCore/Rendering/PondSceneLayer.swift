import QuartzCore
import CoreGraphics

/// Shared native compositor. Cached water/shoreline textures are moved by the GPU;
/// only the small logical swimmer bitmap and bounded surface paths change per tick.
public final class PondSceneLayer: CALayer {
    public let renderer: PondRenderer
    private let bedLayer = CALayer()
    private let causticLayers = [CALayer(), CALayer()]
    private let swimmerLayer = CALayer()
    private var strokeLayers: [CAShapeLayer] = []
    private let surfaceLayer = CALayer()
    private let floraLayers = (0..<6).map { _ in CALayer() }
    private let tintLayer = CALayer()

    public init(renderer: PondRenderer) {
        self.renderer = renderer
        super.init()
        masksToBounds = true
        name = "Koi Pond Scene"
        addSublayer(bedLayer)
        for layer in causticLayers { addSublayer(layer) }
        addSublayer(swimmerLayer)
        addSublayer(surfaceLayer)
        for layer in floraLayers { addSublayer(layer) }
        addSublayer(tintLayer)
    }

    public override init(layer: Any) {
        renderer = (layer as? PondSceneLayer)?.renderer ?? PondRenderer()
        super.init(layer: layer)
    }

    required init?(coder: NSCoder) { return nil }

    public func update(simulation: PondSimulation, bounds: CGRect, backingScale: CGFloat, phase: TimeOfDayPhase = .day) {
        guard bounds.width > 0, bounds.height > 0 else { return }
        let frame = renderer.makeFrame(simulation: simulation, size: bounds.size, scale: max(1, backingScale), phase: phase)
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        self.frame = bounds
        contentsScale = backingScale
        if let bed = frame.bed { apply(bed, to: bedLayer) }
        for (index, layer) in causticLayers.enumerated() {
            layer.isHidden = index >= frame.caustics.count
            if index < frame.caustics.count { apply(frame.caustics[index], to: layer) }
        }
        if let swimmers = frame.swimmers { apply(swimmers, to: swimmerLayer) }
        surfaceLayer.frame = CGRect(origin: .zero, size: bounds.size)
        while strokeLayers.count < frame.surface.count {
            let shape = CAShapeLayer()
            shape.fillColor = nil
            shape.lineCap = .round
            shape.contentsScale = backingScale
            surfaceLayer.addSublayer(shape)
            strokeLayers.append(shape)
        }
        for (index, layer) in strokeLayers.enumerated() {
            layer.isHidden = index >= frame.surface.count
            if index < frame.surface.count {
                let stroke = frame.surface[index]
                layer.path = stroke.path
                layer.strokeColor = stroke.color
                layer.lineWidth = stroke.width
                layer.contentsScale = backingScale
            }
        }
        for (index, layer) in floraLayers.enumerated() {
            layer.isHidden = index >= frame.flora.count
            if index < frame.flora.count { apply(frame.flora[index], to: layer) }
        }
        tintLayer.frame = CGRect(origin: .zero, size: bounds.size)
        tintLayer.backgroundColor = frame.tint
        CATransaction.commit()
    }

    private func apply(_ placement: PondImagePlacement, to layer: CALayer) {
        // Set untransformed geometry first; CALayer.frame is undefined under rotation.
        layer.setAffineTransform(.identity)
        layer.frame = placement.rect
        layer.contents = placement.image
        layer.contentsGravity = .resize
        layer.magnificationFilter = placement.pixelated ? .nearest : .linear
        layer.minificationFilter = placement.pixelated ? .nearest : .linear
        if placement.angle != 0 { layer.setAffineTransform(CGAffineTransform(rotationAngle: placement.angle)) }
    }
}
