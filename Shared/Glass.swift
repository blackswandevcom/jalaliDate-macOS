import SwiftUI

/// Text colour on a glass background.
enum GlassText: String, Codable, CaseIterable, Identifiable {
    case auto, light, dark
    var id: String { rawValue }
    var title: String {
        switch self {
        case .auto: return "Automatic"
        case .light: return "Light text"
        case .dark: return "Dark text"
        }
    }
}

/// How the popover background is drawn.
enum GlassSurface: String, Codable, CaseIterable, Identifiable {
    /// macOS 26 Liquid Glass, tinted with the colour, plus a real blur of the desktop like Terminal.
    case liquid
    /// The pre-26 look: the system backdrop fades out as the blur goes down.
    case classic
    var id: String { rawValue }
    var title: String { self == .liquid ? "Liquid Glass" : "Classic" }
    static var supportsLiquid: Bool { if #available(macOS 26, *) { return true } else { return false } }
}

/// Background colour, opacity and blur, like Terminal's window background.
/// Used for the popover (app only) and for the desktop widgets (shared through the App Group).
struct GlassStyle: Codable, Equatable {
    var enabled = false
    var tint = "#0F172A"
    /// 0…1, how much of the tint colour covers the background.
    var opacity = 0.35
    /// 0…1, how blurred the desktop behind is.
    var blur = 0.6
    var text: GlassText = .auto
    /// Optional so settings saved before 8.2 still decode.
    var surfaceRaw: GlassSurface? = nil

    /// Liquid Glass where the system has it.
    var surface: GlassSurface {
        get { GlassSurface.supportsLiquid ? (surfaceRaw ?? .liquid) : .classic }
        set { surfaceRaw = newValue }
    }

    /// Window blur radius in points for the Liquid Glass popover (Terminal's 100% is about 64).
    var blurRadius: Int { Int((max(0, min(1, blur)) * 64).rounded()) }

    static let popoverKey = "PopoverGlass"
    static let widgetKey = "WidgetGlass"

    static var popover: GlassStyle { Prefs.load(GlassStyle.self, popoverKey) ?? GlassStyle() }
    static var widget: GlassStyle { Prefs.load(GlassStyle.self, widgetKey) ?? GlassStyle(enabled: false, tint: "#FFFFFF", opacity: 0.15, blur: 0.5) }

    var tintColor: Color { Color(hex: tint) }

    /// The colour scheme the text should use, or nil to follow the system.
    var forcedScheme: ColorScheme? {
        switch text {
        case .light: return .dark
        case .dark: return .light
        case .auto:
            guard opacity >= 0.45 else { return nil }
            return Color.luminance(hex: tint) < 0.5 ? .dark : .light
        }
    }

    /// Widgets can't set a blur radius, so the blur picks one of the system materials.
    var material: Material? {
        switch blur {
        case ..<0.05: return nil
        case ..<0.3: return .ultraThinMaterial
        case ..<0.55: return .thinMaterial
        case ..<0.8: return .regularMaterial
        default: return .thickMaterial
        }
    }
}

extension Color {
    /// Relative luminance (0 dark … 1 light) of a #RRGGBB colour.
    static func luminance(hex: String) -> Double {
        let s = hex.replacingOccurrences(of: "#", with: "")
        let v = UInt64(s, radix: 16) ?? 0
        let r = Double((v >> 16) & 0xFF) / 255, g = Double((v >> 8) & 0xFF) / 255, b = Double(v & 0xFF) / 255
        return 0.2126 * r + 0.7152 * g + 0.0722 * b
    }
}

extension View {
    /// Forces light or dark text when the glass asks for it.
    @ViewBuilder
    func glassScheme(_ glass: GlassStyle?) -> some View {
        if let scheme = glass?.forcedScheme { self.environment(\.colorScheme, scheme) } else { self }
    }
}

/// Live glass settings for the app. The widgets read `GlassStyle.widget` straight from the App Group.
@MainActor
final class GlassSettings: ObservableObject {
    static let shared = GlassSettings()
    @Published var popover = GlassStyle.popover { didSet { if popover != oldValue { Prefs.save(popover, GlassStyle.popoverKey) } } }
    @Published var widget = GlassStyle.widget { didSet { if widget != oldValue { Prefs.save(widget, GlassStyle.widgetKey) } } }
}
