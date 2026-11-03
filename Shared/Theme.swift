import SwiftUI

enum ThemeMode: String, Codable, CaseIterable, Identifiable {
    case season, weather, preset, custom, accent, animated, media, occasion
    var id: String { rawValue }
    var title: String {
        switch self {
        case .season: return "Season"
        case .weather: return "Weather"
        case .preset: return "Preset"
        case .custom: return "Custom"
        case .accent: return "Accent"
        case .animated: return "Animated"
        case .media: return "Photo / Video"
        case .occasion: return "Occasions"
        }
    }
    var symbol: String {
        switch self {
        case .season: return "leaf"
        case .weather: return "cloud.sun"
        case .preset: return "swatchpalette"
        case .custom: return "paintpalette"
        case .accent: return "circle.lefthalf.filled"
        case .animated: return "sparkles"
        case .media: return "play.rectangle"
        case .occasion: return "party.popper"
        }
    }
}

/// Live, customisable header backgrounds.
enum AnimatedStyle: String, Codable, CaseIterable, Identifiable {
    case aurora, liquid, waves, lava, starfield, girih, rings, fireworks, lanterns, snowfall, blossoms, embers, hearts
    var id: String { rawValue }
    var title: String {
        switch self {
        case .aurora: return "Aurora"
        case .liquid: return "Liquid mesh"
        case .waves: return "Waves"
        case .lava: return "Lava lamp"
        case .starfield: return "Starfield"
        case .girih: return "Girih (Persian tiles)"
        case .rings: return "Ripples"
        case .fireworks: return "Fireworks"
        case .lanterns: return "Crescent & lanterns"
        case .snowfall: return "Snow & lights"
        case .blossoms: return "Spring blossoms"
        case .embers: return "Bonfire sparks"
        case .hearts: return "Floating hearts"
        }
    }
    var detail: String {
        switch self {
        case .aurora: return "Soft northern lights drifting across the header."
        case .liquid: return "A flowing mesh gradient that slowly mixes your colours."
        case .waves: return "Layered sea waves rolling under the date."
        case .lava: return "Blobs that merge and split like a lava lamp."
        case .starfield: return "Flying through stars, tinted with your colours."
        case .girih: return "A turning eight-point star pattern from Persian tilework."
        case .rings: return "Rings rippling out like a drop in a pool."
        case .fireworks: return "Bursts of fireworks over a night sky."
        case .lanterns: return "A crescent moon, twinkling stars and swaying lanterns."
        case .snowfall: return "Falling snow over soft blinking lights."
        case .blossoms: return "Petals drifting down in the spring sun."
        case .embers: return "Sparks rising from a bonfire."
        case .hearts: return "Hearts floating up and fading away."
        }
    }
    /// Starting palette when the style is picked.
    var palette: [String] {
        switch self {
        case .aurora: return ["#0B1026", "#22D3EE", "#A855F7"]
        case .liquid: return ["#F97316", "#DB2777", "#6366F1"]
        case .waves: return ["#0EA5E9", "#1E3A8A", "#67E8F9"]
        case .lava: return ["#7C2D12", "#F97316", "#FDE047"]
        case .starfield: return ["#020617", "#1E1B4B", "#E0E7FF"]
        case .girih: return ["#0E8FB0", "#1F4FA8", "#FFB43A"]
        case .rings: return ["#14B8A6", "#0F766E", "#CCFBF1"]
        case .fireworks: return ["#0B1026", "#F59E0B", "#EC4899"]
        case .lanterns: return ["#1E1B4B", "#7C3AED", "#FCD34D"]
        case .snowfall: return ["#14532D", "#DC2626", "#FDE68A"]
        case .blossoms: return ["#15803D", "#DB2777", "#FEF3C7"]
        case .embers: return ["#1C1917", "#EA580C", "#FDE047"]
        case .hearts: return ["#BE185D", "#F472B6", "#FFE4E6"]
        }
    }
}

enum MediaKind: String, Codable { case image, video }

/// Custom header backgrounds that run while the popover is open.
enum HeaderEffect: Equatable {
    case animated(AnimatedStyle, colors: [Color], speed: Double, intensity: Double)
    case media(URL, MediaKind, dim: Double)
}

enum ThemePreset: String, Codable, CaseIterable, Identifiable {
    case classic, turquoise, lapis, pomegranate, pistachio, saffron, rose, graphite, midnight
    var id: String { rawValue }
    var title: String {
        switch self {
        case .classic: return "Classic orange"
        case .turquoise: return "Persian turquoise"
        case .lapis: return "Lapis"
        case .pomegranate: return "Pomegranate"
        case .pistachio: return "Pistachio"
        case .saffron: return "Saffron"
        case .rose: return "Damask rose"
        case .graphite: return "Graphite"
        case .midnight: return "Midnight"
        }
    }
    var colors: [Color] {
        switch self {
        case .classic: return [Color(hex: "#F59E0B"), Color(hex: "#EA580C")]
        case .turquoise: return [Color(hex: "#14B8A6"), Color(hex: "#0E7490")]
        case .lapis: return [Color(hex: "#3B82F6"), Color(hex: "#1E3A8A")]
        case .pomegranate: return [Color(hex: "#F43F5E"), Color(hex: "#9F1239")]
        case .pistachio: return [Color(hex: "#84CC16"), Color(hex: "#3F6212")]
        case .saffron: return [Color(hex: "#FBBF24"), Color(hex: "#D97706")]
        case .rose: return [Color(hex: "#F472B6"), Color(hex: "#BE185D")]
        case .graphite: return [Color(hex: "#6B7280"), Color(hex: "#1F2937")]
        case .midnight: return [Color(hex: "#312E81"), Color(hex: "#0F172A")]
        }
    }
}

enum Particle: String, Codable { case rain, snow, leaves, petals, stars, sun }

struct ThemeConfig: Codable, Equatable {
    var mode: ThemeMode = .season
    var preset: ThemePreset = .classic
    var customA = "#F97316"
    var customB = "#DB2777"
    var animated = true
    var fridayRed = true
    // v8.1 — optional so themes saved by 8.0 still decode.
    var animStyleRaw: AnimatedStyle? = nil
    var animColorsRaw: [String]? = nil
    var animSpeedRaw: Double? = nil
    var animIntensityRaw: Double? = nil
    var mediaKindRaw: MediaKind? = nil
    var mediaFileRaw: String? = nil
    var mediaDimRaw: Double? = nil
    var occasionRaw: Occasion? = nil
    var autoOccasionsRaw: Bool? = nil
    var occasionsOffRaw: [Occasion]? = nil
    var holidayColorRaw: String? = nil
    var weekendColorRaw: String? = nil
    /// Gregorian weekday numbers (1 = Sunday … 7 = Saturday).
    var weekendDaysRaw: [Int]? = nil

    var animStyle: AnimatedStyle { get { animStyleRaw ?? .aurora } set { animStyleRaw = newValue } }
    var animColors: [String] { get { animColorsRaw ?? animStyle.palette } set { animColorsRaw = newValue } }
    var animSpeed: Double { get { animSpeedRaw ?? 1 } set { animSpeedRaw = newValue } }
    var animIntensity: Double { get { animIntensityRaw ?? 0.7 } set { animIntensityRaw = newValue } }
    var mediaKind: MediaKind? { get { mediaKindRaw } set { mediaKindRaw = newValue } }
    /// File name inside the shared container.
    var mediaFile: String? { get { mediaFileRaw } set { mediaFileRaw = newValue } }
    var mediaDim: Double { get { mediaDimRaw ?? 0.25 } set { mediaDimRaw = newValue } }

    /// The occasion picked in the Occasions style.
    var occasion: Occasion { get { occasionRaw ?? .nowruz } set { occasionRaw = newValue } }
    /// Switch to an occasion's theme on its days, whatever the style.
    var autoOccasions: Bool { get { autoOccasionsRaw ?? true } set { autoOccasionsRaw = newValue } }
    var occasionsOff: Set<Occasion> { get { Set(occasionsOffRaw ?? []) } set { occasionsOffRaw = Occasion.allCases.filter(newValue.contains) } }

    var mediaURL: URL? { mediaFile.map { Prefs.containerURL.appendingPathComponent($0) } }
    /// Still frame of the photo or video, used by the widgets.
    var mediaPosterURL: URL? { mediaFile == nil ? nil : Prefs.containerURL.appendingPathComponent("header-poster.jpg") }
}

struct ResolvedTheme {
    var name: String
    var colors: [Color]
    var accent: Color
    var symbol: String?
    var particle: Particle?
    var effect: HeaderEffect? = nil

    var gradient: LinearGradient {
        LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

enum ThemeResolver {
    static func resolve(_ config: ThemeConfig, date: Date = Date(), weather: WeatherSnapshot? = nil) -> ResolvedTheme {
        if config.mode == .occasion { return config.occasion.theme }
        if config.autoOccasions, let o = Occasion.active(on: date, excluding: config.occasionsOff) { return o.theme }
        if config.fridayRed && CalendarService.isFriday(date) && ![.custom, .animated, .media].contains(config.mode) {
            return ResolvedTheme(name: "Friday", colors: [Color(hex: "#F43F5E"), Color(hex: "#DB2777")],
                                 accent: Color(hex: "#E11D48"), symbol: "sparkles", particle: nil)
        }
        switch config.mode {
        case .season: return season(date)
        case .weather: return weather.map(weatherTheme) ?? season(date)
        case .preset:
            let c = config.preset.colors
            return ResolvedTheme(name: config.preset.title, colors: c, accent: c[0], symbol: nil, particle: nil)
        case .custom:
            let a = Color(hex: config.customA), b = Color(hex: config.customB)
            return ResolvedTheme(name: "Custom", colors: [a, b], accent: a, symbol: nil, particle: nil)
        case .accent:
            return ResolvedTheme(name: "Accent", colors: [Color.accentColor, Color.accentColor.opacity(0.7)],
                                 accent: .accentColor, symbol: nil, particle: nil)
        case .animated:
            let c = config.animColors.map { Color(hex: $0) }
            let accent = c.count > 1 ? c[1] : c.first ?? .orange
            return ResolvedTheme(name: config.animStyle.title, colors: Array(c.prefix(2)), accent: accent, symbol: nil, particle: nil,
                                 effect: .animated(config.animStyle, colors: c, speed: config.animSpeed, intensity: config.animIntensity))
        case .occasion:
            return config.occasion.theme
        case .media:
            guard let url = config.mediaURL, let kind = config.mediaKind, FileManager.default.fileExists(atPath: url.path) else {
                return season(date)
            }
            return ResolvedTheme(name: kind == .video ? "Video" : "Photo", colors: [Color(hex: "#1E293B"), Color(hex: "#0F172A")],
                                 accent: Color(hex: "#0EA5E9"), symbol: nil, particle: nil,
                                 effect: .media(url, kind, dim: config.mediaDim))
        }
    }

    static func season(_ date: Date) -> ResolvedTheme {
        switch CalendarService.ymd(date, .jalali).month {
        case 1...3:
            return ResolvedTheme(name: "Spring · بهار", colors: [Color(hex: "#34D399"), Color(hex: "#EC4899")],
                                 accent: Color(hex: "#10B981"), symbol: "camera.macro", particle: .petals)
        case 4...6:
            return ResolvedTheme(name: "Summer · تابستان", colors: [Color(hex: "#FBBF24"), Color(hex: "#F97316")],
                                 accent: Color(hex: "#F59E0B"), symbol: "sun.max.fill", particle: .sun)
        case 7...9:
            return ResolvedTheme(name: "Autumn · پاییز", colors: [Color(hex: "#F59E0B"), Color(hex: "#9A3412")],
                                 accent: Color(hex: "#EA580C"), symbol: "leaf.fill", particle: .leaves)
        default:
            return ResolvedTheme(name: "Winter · زمستان", colors: [Color(hex: "#60A5FA"), Color(hex: "#1E40AF")],
                                 accent: Color(hex: "#3B82F6"), symbol: "snowflake", particle: .snow)
        }
    }

    static func weatherTheme(_ w: WeatherSnapshot) -> ResolvedTheme {
        let sym = w.condition.symbol(isDay: w.isDay)
        if !w.isDay {
            switch w.condition {
            case .clear, .partlyCloudy:
                return ResolvedTheme(name: "Clear night", colors: [Color(hex: "#312E81"), Color(hex: "#0F172A")],
                                     accent: Color(hex: "#6366F1"), symbol: sym, particle: .stars)
            default: break
            }
        }
        switch w.condition {
        case .clear:
            return ResolvedTheme(name: "Sunny", colors: [Color(hex: "#38BDF8"), Color(hex: "#F59E0B")],
                                 accent: Color(hex: "#0EA5E9"), symbol: sym, particle: .sun)
        case .partlyCloudy:
            return ResolvedTheme(name: "Partly cloudy", colors: [Color(hex: "#60A5FA"), Color(hex: "#94A3B8")],
                                 accent: Color(hex: "#3B82F6"), symbol: sym, particle: nil)
        case .cloudy, .fog:
            return ResolvedTheme(name: w.condition.title, colors: [Color(hex: "#94A3B8"), Color(hex: "#475569")],
                                 accent: Color(hex: "#64748B"), symbol: sym, particle: nil)
        case .drizzle, .rain:
            return ResolvedTheme(name: "Rainy", colors: [Color(hex: "#475569"), Color(hex: "#1E3A8A")],
                                 accent: Color(hex: "#3B82F6"), symbol: sym, particle: .rain)
        case .snow, .sleet:
            return ResolvedTheme(name: "Snowy", colors: [Color(hex: "#93C5FD"), Color(hex: "#64748B")],
                                 accent: Color(hex: "#60A5FA"), symbol: sym, particle: .snow)
        case .thunder:
            return ResolvedTheme(name: "Storm", colors: [Color(hex: "#334155"), Color(hex: "#111827")],
                                 accent: Color(hex: "#A855F7"), symbol: sym, particle: .rain)
        }
    }
}
