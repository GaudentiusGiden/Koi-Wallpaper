import QuartzCore
import CoreGraphics
import CoreImage

/// Shared native compositor. Cached water/shoreline textures stay in the layer tree;
/// only the small logical swimmer bitmap and bounded surface paths change per tick.
public final class PondSceneLayer: CALayer {
    public let renderer: PondRenderer
    private let bedLayerA = CALayer()
    private let bedLayerB = CALayer()
    private let causticContainers = (0..<3).map { _ in CALayer() }
    private let causticSourceLayersA = (0..<3).map { _ in CALayer() }
    private let causticPairLayers = (0..<3).map { _ in CALayer() }
    private let causticLayersB = (0..<3).map { _ in CALayer() }
    private let swimmerLayer = CALayer()
    private var strokeLayers: [CAShapeLayer] = []
    private let surfaceLayer = CALayer()
    private let floraLayersA = (0..<6).map { _ in CALayer() }
    private let floraLayersB = (0..<6).map { _ in CALayer() }
    private let insectLayer = CALayer()
    private let tintLayer = CALayer()

    public init(renderer: PondRenderer) {
        self.renderer = renderer
        super.init()
        masksToBounds = true
        name = "Koi Pond Scene"

        addSublayer(bedLayerA)
        addSublayer(bedLayerB)
        for (index, container) in causticContainers.enumerated() {
            container.masksToBounds = false
            let pairLayer = causticPairLayers[index]
            pairLayer.masksToBounds = false
            pairLayer.addSublayer(causticSourceLayersA[index])
            // The addition target is grouped with its matching source, so the filter receives
            // only that caustic pair as its backdrop. The group is then source-over composited
            // with bed and scene siblings outside this container.
            pairLayer.addSublayer(causticLayersB[index])
            container.addSublayer(pairLayer)
            addSublayer(container)
        }
        addSublayer(swimmerLayer)
        surfaceLayer.name = "surface"
        addSublayer(surfaceLayer)
        for layer in floraLayersA { addSublayer(layer) }
        for layer in floraLayersB { addSublayer(layer) }
        insectLayer.name = "insects"
        addSublayer(insectLayer)
        addSublayer(tintLayer)

        bedLayerB.isHidden = true
        causticContainers.forEach { $0.isHidden = true }
        causticSourceLayersA.forEach { $0.isHidden = true }
        causticLayersB.forEach { layer in
            layer.isHidden = true
            guard let filter = CIFilter(name: "CIAdditionCompositing") else {
                preconditionFailure("macOS Core Image is missing CIAdditionCompositing")
            }
            layer.compositingFilter = filter
        }
        floraLayersB.forEach { $0.isHidden = true }
    }

    public override init(layer: Any) {
        renderer = (layer as? PondSceneLayer)?.renderer ?? PondRenderer()
        super.init(layer: layer)
    }

    required init?(coder: NSCoder) { return nil }

    public func update(simulation: PondSimulation, bounds: CGRect, backingScale: CGFloat, phase: TimeOfDayPhase = .day) {
        update(simulation: simulation, bounds: bounds, backingScale: backingScale, fromTheme: phase.theme, toTheme: phase.theme, progress: 1.0)
    }

    public func update(simulation: PondSimulation, bounds: CGRect, backingScale: CGFloat, theme: PondTheme) {
        update(simulation: simulation, bounds: bounds, backingScale: backingScale, fromTheme: theme, toTheme: theme, progress: 1.0)
    }

    public func update(
        simulation: PondSimulation,
        bounds: CGRect,
        backingScale: CGFloat,
        fromTheme: PondTheme,
        toTheme: PondTheme,
        progress: CGFloat
    ) {
        guard bounds.width > 0, bounds.height > 0 else { return }
        let scale = max(1, backingScale)
        let frame = renderer.makeTransitionFrame(
            simulation: simulation,
            size: bounds.size,
            scale: scale,
            fromTheme: fromTheme,
            toTheme: toTheme,
            progress: progress
        )
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        self.frame = bounds
        contentsScale = backingScale

        let isTransitioning = frame.isTransitioning
        let progress = Float(frame.transitionProgress)

        // Bed layers: Layer A remains fully opaque (1.0) while Layer B fades in at progress.
        // Standard source-over compositing guarantees full 100% opacity throughout the crossfade,
        // preventing the window background from showing through.
        if let bed = frame.bed {
            bedLayerA.isHidden = false
            apply(bed, to: bedLayerA)
            bedLayerA.opacity = 1.0
        } else {
            bedLayerA.isHidden = true
        }

        if let bedTarget = frame.bedTarget, isTransitioning {
            bedLayerB.isHidden = false
            apply(bedTarget, to: bedLayerB)
            bedLayerB.opacity = progress
        } else {
            bedLayerB.isHidden = true
            bedLayerB.contents = nil
        }

        // Each caustics pair uses premultiplied RGBA addition inside its own container.
        // The same (1-p, p) weights are used by the offscreen and snapshot paths.
        let causticAlphaA: Float = isTransitioning ? (1.0 - progress) : 1.0
        let causticAlphaB: Float = isTransitioning ? progress : 0.0

        for (index, container) in causticContainers.enumerated() {
            let hasA = index < frame.caustics.count
            let hasB = isTransitioning && (index < frame.causticsTarget.count)
            container.isHidden = !hasA && !hasB
            guard !container.isHidden else { continue }
            container.frame = CGRect(origin: .zero, size: bounds.size)

            let pairLayer = causticPairLayers[index]
            let referencePlacement = hasA ? frame.caustics[index] : frame.causticsTarget[index]
            pairLayer.frame = referencePlacement.rect

            let sourceLayer = causticSourceLayersA[index]
            sourceLayer.isHidden = !hasA
            if hasA {
                apply(frame.caustics[index], to: sourceLayer)
                sourceLayer.frame = CGRect(origin: .zero, size: frame.caustics[index].rect.size)
                sourceLayer.opacity = causticAlphaA
            }

            pairLayer.isHidden = !hasA && !hasB

            let layerB = causticLayersB[index]
            layerB.isHidden = !hasB
            if hasB {
                apply(frame.causticsTarget[index], to: layerB)
                // Use pair-local coordinates so the filter backdrop is source A only.
                layerB.frame = CGRect(origin: .zero, size: frame.causticsTarget[index].rect.size)
                layerB.opacity = causticAlphaB
            } else {
                layerB.contents = nil
            }
        }

        // Swimmer bitmap
        if let swimmers = frame.swimmers { apply(swimmers, to: swimmerLayer) }

        // Surface glimmers and ripples
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
            let shouldHide = index >= frame.surface.count
            if layer.isHidden != shouldHide { layer.isHidden = shouldHide }
            if !shouldHide {
                let stroke = frame.surface[index]
                if layer.path !== stroke.path { layer.path = stroke.path }
                if layer.strokeColor != stroke.color { layer.strokeColor = stroke.color }
                if layer.fillColor != stroke.fillColor { layer.fillColor = stroke.fillColor }
                if layer.lineWidth != stroke.width { layer.lineWidth = stroke.width }
                if layer.contentsScale != backingScale { layer.contentsScale = backingScale }
            }
        }
        if strokeLayers.count > 64 && frame.surface.count <= 24 {
            let excess = strokeLayers.suffix(from: 32)
            for layer in excess { layer.removeFromSuperlayer() }
            strokeLayers.removeSubrange(32..<strokeLayers.count)
        }

        // Flora layers: Layer A remains fully opaque (1.0) while Layer B fades in at progress.
        // Flora bodies stay completely opaque; swimmers never ghost through lily pads.
        for (index, layer) in floraLayersA.enumerated() {
            layer.isHidden = index >= frame.flora.count
            if index < frame.flora.count {
                apply(frame.flora[index], to: layer)
                layer.opacity = 1.0
            }
        }

        for (index, layer) in floraLayersB.enumerated() {
            let active = isTransitioning && (index < frame.floraTarget.count)
            layer.isHidden = !active
            if active {
                apply(frame.floraTarget[index], to: layer)
                layer.opacity = progress
            } else {
                layer.contents = nil
            }
        }

        // Insects layer (vector layer above flora and below atmospheric tint)
        if let insects = frame.insects {
            insectLayer.isHidden = false
            apply(insects, to: insectLayer)
        } else {
            insectLayer.isHidden = true
            insectLayer.contents = nil
        }

        // Atmospheric tint
        if let tint = frame.tint {
            tintLayer.isHidden = false
            tintLayer.frame = CGRect(origin: .zero, size: bounds.size)
            tintLayer.backgroundColor = tint
        } else {
            tintLayer.isHidden = true
            tintLayer.backgroundColor = nil
        }
        CATransaction.commit()
    }

    private func apply(_ placement: PondImagePlacement, to layer: CALayer) {
        let filter: CALayerContentsFilter = placement.pixelated ? .nearest : .linear
        if layer.magnificationFilter != filter {
            layer.magnificationFilter = filter
            layer.minificationFilter = filter
        }
        if layer.contentsGravity != .resize {
            layer.contentsGravity = .resize
        }
        if (layer.contents as AnyObject) !== (placement.image as AnyObject) {
            layer.contents = placement.image
        }
        if placement.angle == 0 {
            if !layer.affineTransform().isIdentity {
                layer.setAffineTransform(.identity)
            }
            if layer.frame != placement.rect {
                layer.frame = placement.rect
            }
        } else {
            let desiredTransform = CGAffineTransform(rotationAngle: placement.angle)
            if layer.affineTransform() != desiredTransform || layer.frame != placement.rect {
                layer.setAffineTransform(.identity)
                layer.frame = placement.rect
                layer.setAffineTransform(desiredTransform)
            }
        }
    }
}
