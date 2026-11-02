import SwiftUI
#if canImport(AppKit)
import AppKit
#endif

/// User-chosen typeface for the whole app (and optionally the desktop widgets and menubar).
/// Stored as plain keys in the shared defaults so every `Font.app(...)` call is a cheap lookup.
enum AppFont {
    static let familyKey = "FontFamily"        // nil / "" = system (San Francisco)
    static let scaleKey = "FontScale"          // 0.8 … 1.3
    static let widgetsKey = "FontInWidgets"
    static let menubarKey = "FontInMenubar"

    static var isWidgetProcess: Bool { Bundle.main.bundlePath.hasSuffix(".appex") }

    static var family: String? {
        let f = Prefs.defaults.string(forKey: familyKey) ?? ""
        guard !f.isEmpty else { return nil }
        if isWidgetProcess && !useInWidgets { return nil }
        return f
    }
    static var scale: Double {
        if isWidgetProcess && !useInWidgets { return 1 }
        let s = Prefs.defaults.double(forKey: scaleKey)
        return s == 0 ? 1 : s
    }
    static var useInWidgets: Bool { Prefs.defaults.object(forKey: widgetsKey) as? Bool ?? true }
    static var useInMenubar: Bool { Prefs.defaults.object(forKey: menubarKey) as? Bool ?? false }

    /// Changes whenever any font setting changes — used as a view identity to rebuild open windows.
    static var signature: String { "\(Prefs.defaults.string(forKey: familyKey) ?? "")|\(scale)|\(useInWidgets)|\(useInMenubar)" }

    #if canImport(AppKit)
    /// NSFont in the chosen family (menubar icon). Falls back to the system font.
    static func nsFont(size: CGFloat, weight: NSFont.Weight) -> NSFont {
        let sys = NSFont.systemFont(ofSize: size, weight: weight)
        guard useInMenubar, let family = Prefs.defaults.string(forKey: familyKey), !family.isEmpty else { return sys }
        let traits: NSFontManager = .shared
        let w = weight == .bold || weight == .heavy || weight == .black ? 9 : (weight == .semibold ? 8 : 5)
        return traits.font(withFamily: family, traits: [], weight: w, size: size) ?? sys
    }

    /// Installed families, with the ones that can write Persian first.
    static func families() -> (persian: [String], other: [String]) {
        let all = NSFontManager.shared.availableFontFamilies.filter { !$0.hasPrefix(".") }
        let pe: Character = "پ"
        var persian: [String] = [], other: [String] = []
        for f in all {
            if let font = NSFont(name: f, size: 12) ?? NSFontManager.shared.font(withFamily: f, traits: [], weight: 5, size: 12),
               font.coveredCharacterSet.contains(pe.unicodeScalars.first!) {
                persian.append(f)
            } else {
                other.append(f)
            }
        }
        return (persian, other)
    }
    #endif
}

extension Font {
    /// Drop-in replacement for `.system(size:weight:design:)` that follows the user's font choice.
    static func app(size: CGFloat, weight: Font.Weight = .regular, design: Font.Design = .default) -> Font {
        let s = size * AppFont.scale
        if let family = AppFont.family {
            return .custom(family, size: s).weight(weight)
        }
        return .system(size: s, weight: weight, design: design)
    }

    /// Text-style variant (sizes match macOS defaults).
    static func app(_ style: Font.TextStyle) -> Font {
        switch style {
        case .largeTitle: return .app(size: 26)
        case .title: return .app(size: 22)
        case .title2: return .app(size: 17)
        case .title3: return .app(size: 15)
        case .headline: return .app(size: 13, weight: .bold)
        case .subheadline: return .app(size: 11)
        case .callout: return .app(size: 12)
        case .footnote: return .app(size: 10)
        case .caption: return .app(size: 10)
        case .caption2: return .app(size: 10)
        default: return .app(size: 13)
        }
    }
}
