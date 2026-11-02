import AppKit
import SwiftUI

enum MenubarIcon {
    /// Badge image for the given config. Template (follows menubar) unless custom colors are on.
    static func badge(_ text: String, config: IconConfig, height: CGFloat = 18) -> NSImage {
        let font = AppFont.nsFont(size: config.fontSize, weight: config.bold ? .bold : .medium)
        let attrsMeasure: [NSAttributedString.Key: Any] = [.font: font]
        let textSize = text.size(withAttributes: attrsMeasure)
        let shape = config.shape
        let pagePad: CGFloat = shape == .calendarPage ? 3 : 0
        let width = shape == .none ? ceil(textSize.width + 2) : max(height, ceil(textSize.width + 8))
        let size = NSSize(width: width, height: height)
        let template = !config.useCustomColors
        let shapeColor = template ? NSColor.black : NSColor(Color(hex: config.shapeColor))
        let textColor = template ? NSColor.black : NSColor(Color(hex: config.textColor))

        let image = NSImage(size: size, flipped: false) { rect in
            let r = rect.insetBy(dx: 0.75, dy: 0.75)
            let path: NSBezierPath?
            switch shape {
            case .circle, .filledCircle:
                path = NSBezierPath(roundedRect: r, xRadius: r.height / 2, yRadius: r.height / 2)
            case .roundedSquare, .filledRoundedSquare, .calendarPage:
                path = NSBezierPath(roundedRect: r, xRadius: 4, yRadius: 4)
            case .square, .filledSquare:
                path = NSBezierPath(rect: r)
            case .none:
                path = nil
            }

            if let path {
                if shape.filled {
                    shapeColor.setFill()
                    path.fill()
                } else {
                    shapeColor.setStroke()
                    path.lineWidth = 1.3
                    path.stroke()
                }
                if shape == .calendarPage {
                    NSGraphicsContext.saveGraphicsState()
                    path.addClip()
                    shapeColor.setFill()
                    NSRect(x: r.minX, y: r.maxY - 4, width: r.width, height: 4).fill()
                    NSGraphicsContext.restoreGraphicsState()
                }
            }

            let style = NSMutableParagraphStyle()
            style.alignment = .center
            // On a filled template badge the text is punched out so it shows the menubar through it.
            let knockout = template && shape.filled
            let attrs: [NSAttributedString.Key: Any] = [
                .font: font, .foregroundColor: knockout ? NSColor.black : textColor, .paragraphStyle: style,
            ]
            let textRect = NSRect(x: 0, y: (rect.height - textSize.height) / 2 - pagePad / 2 + 0.5,
                                  width: rect.width, height: textSize.height)
            if knockout, let ctx = NSGraphicsContext.current {
                ctx.compositingOperation = .destinationOut
                text.draw(in: textRect, withAttributes: attrs)
                ctx.compositingOperation = .sourceOver
            } else {
                text.draw(in: textRect, withAttributes: attrs)
            }
            return true
        }
        image.isTemplate = template
        return image
    }

    static func title(_ config: IconConfig, date: Date = Date()) -> NSAttributedString {
        let text = DateTokens.format(config.textFormat, date: date, persianDigits: config.textPersianDigits)
        var attrs: [NSAttributedString.Key: Any] = [.font: AppFont.useInMenubar ? AppFont.nsFont(size: NSFont.systemFontSize, weight: .regular) : NSFont.menuBarFont(ofSize: 0)]
        if config.useCustomColors { attrs[.foregroundColor] = NSColor(Color(hex: config.shapeColor)) }
        return NSAttributedString(string: text, attributes: attrs)
    }

    static func badgeText(_ config: IconConfig, date: Date = Date()) -> String {
        DateTokens.format(config.badgeFormat, date: date, persianDigits: config.badgePersianDigits)
    }
}
