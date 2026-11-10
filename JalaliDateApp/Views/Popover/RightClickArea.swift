import AppKit
import SwiftUI

extension View {
    /// Runs `action` on a right-click (or Control-click) without taking left clicks away from the view.
    func onRightClick(_ action: (() -> Void)?) -> some View {
        overlay {
            if let action { RightClickArea(action: action) }
        }
    }
}

private struct RightClickArea: NSViewRepresentable {
    let action: () -> Void

    func makeNSView(context: Context) -> CatcherView {
        let v = CatcherView()
        v.action = action
        return v
    }

    func updateNSView(_ v: CatcherView, context: Context) { v.action = action }

    final class CatcherView: NSView {
        var action: (() -> Void)?

        private static func isSecondary(_ e: NSEvent) -> Bool {
            switch e.type {
            case .rightMouseDown, .rightMouseUp: return true
            case .leftMouseDown, .leftMouseUp: return e.modifierFlags.contains(.control)
            default: return false
            }
        }

        // Only claim secondary clicks; everything else falls through to SwiftUI underneath.
        override func hitTest(_ point: NSPoint) -> NSView? {
            guard let e = NSApp.currentEvent, Self.isSecondary(e) else { return nil }
            return super.hitTest(point)
        }

        override func rightMouseDown(with event: NSEvent) { action?() }
        override func mouseDown(with event: NSEvent) { action?() }
        override func menu(for event: NSEvent) -> NSMenu? { nil }
    }
}
