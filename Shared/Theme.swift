import SwiftUI

enum ThemeMode: String, Codable, CaseIterable, Identifiable {
    case season, weather, preset, custom, accent
    var id: String { rawValue }
    var title: String {
        switch self {
        case .season: return "Season"
        case .weather: return "Live weather"
        case .preset: return "Preset"
        case .custom: return "Custom colors"
        case .accent: return "System accent"
        }
    }
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
}

struct ResolvedTheme {
    var name: String
    var colors: [Color]
    var accent: Color
    var symbol: String?
    var particle: Particle?

    var gradient: LinearGradient {
        LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

enum ThemeResolver {
    static func resolve(_ config: ThemeConfig, date: Date = Date(), weather: WeatherSnapshot? = nil) -> ResolvedTheme {
        if config.fridayRed && CalendarService.isFriday(date) && config.mode != .custom {
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
