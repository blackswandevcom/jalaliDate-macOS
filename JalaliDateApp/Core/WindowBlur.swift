import AppKit
import QuartzCore

/// Terminal-style blur of whatever is behind the window, with a radius.
/// It's a backdrop layer that samples the screen behind the window (what NSVisualEffectView uses
/// inside), with only a gaussian blur on it, so it stays inside the view and its shape.
/// Built from private Core Animation classes; if they're missing the view stays empty.
final class BackdropBlurView: NSView {
    var radius: CGFloat = 0 { didSet { if radius != oldValue { applyFilters() } } }

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.setValue(true, forKey: "windowServerAware")
        layer?.setValue("jdate.backdrop.\(UUID().uuidString)", forKey: "groupName")
        layer?.setValue(1.0, forKey: "scale")
        applyFilters()
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    override func makeBackingLayer() -> CALayer {
        (NSClassFromString("CABackdropLayer") as? CALayer.Type)?.init() ?? CALayer()
    }

    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    private func applyFilters() {
        guard let layer, NSStringFromClass(type(of: layer)) == "CABackdropLayer",
              let cls = NSClassFromString("CAFilter") as? NSObject.Type else { return }
        let sel = NSSelectorFromString("filterWithType:")
        guard cls.responds(to: sel), let blur = cls.perform(sel, with: "gaussianBlur")?.takeUnretainedValue() as? NSObject else { return }
        blur.setValue(radius, forKey: "inputRadius")
        blur.setValue(true, forKey: "inputNormalizeEdges")
        layer.filters = radius > 0 ? [blur] : []
        layer.isHidden = radius <= 0
    }
}
