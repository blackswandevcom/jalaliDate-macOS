import AppIntents
import SwiftUI
import WidgetKit

// MARK: - Configuration enums

enum CalendarChoice: String, AppEnum {
    case jalali, gregorian, islamic

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Calendar"
    static let caseDisplayRepresentations: [CalendarChoice: DisplayRepresentation] = [
        .jalali: "Jalali (Persian)",
        .gregorian: "Gregorian",
        .islamic: "Hijri (Islamic)",
    ]

    var kind: CalendarKind { CalendarKind(rawValue: rawValue) ?? .jalali }
}

enum MonthCalendarChoice: String, AppEnum {
    case jalali, gregorian

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Calendar"
    static let caseDisplayRepresentations: [MonthCalendarChoice: DisplayRepresentation] = [
        .jalali: "Jalali (Persian)",
        .gregorian: "Gregorian",
    ]

    var kind: CalendarKind { self == .jalali ? .jalali : .gregorian }
}

enum StyleChoice: String, AppEnum {
    case app, season, weather, plain, turquoise, lapis, pomegranate, pistachio, saffron, rose, classic, graphite, midnight

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Style"
    static let caseDisplayRepresentations: [StyleChoice: DisplayRepresentation] = [
        .app: "Same as jDate theme",
        .season: "Season",
        .weather: "Live weather",
        .plain: "Plain (system)",
        .turquoise: "Persian turquoise",
        .lapis: "Lapis",
        .pomegranate: "Pomegranate",
        .pistachio: "Pistachio",
        .saffron: "Saffron",
        .rose: "Damask rose",
        .classic: "Classic orange",
        .graphite: "Graphite",
        .midnight: "Midnight",
    ]

    /// nil = plain system background.
    func theme(_ date: Date) -> ResolvedTheme? {
        let cache = WidgetData.cache
        let weather = cache.weatherCities.first.flatMap { cache.weather[$0.id.uuidString] }
        switch self {
        case .plain: return nil
        case .app:
            let config = Prefs.load(ThemeConfig.self, Prefs.themeKey) ?? ThemeConfig()
            return ThemeResolver.resolve(config, date: date, weather: weather)
        case .season: return ThemeResolver.season(date)
        case .weather: return weather.map(ThemeResolver.weatherTheme) ?? ThemeResolver.season(date)
        default:
            let preset = ThemePreset(rawValue: rawValue) ?? .classic
            return ResolvedTheme(name: preset.title, colors: preset.colors, accent: preset.colors[0], symbol: nil, particle: nil)
        }
    }
}

// MARK: - Cities (world clock)

struct CityEntity: AppEntity, Hashable {
    /// "Time/Zone|Name"
    let id: String
    var name: String { String(id.split(separator: "|").last ?? "") }
    var timeZoneID: String { String(id.split(separator: "|").first ?? "") }
    var tz: TimeZone { TimeZone(identifier: timeZoneID) ?? .current }

    init(_ name: String, _ tz: String) { id = "\(tz)|\(name)" }
    init(id: String) { self.id = id }

    var city: City { City(name: name, timeZone: timeZoneID) }

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "City"
    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)", subtitle: "\(timeZoneID)")
    }
    static let defaultQuery = CityQuery()

    static let popular: [CityEntity] = [
        .init("Tehran", "Asia/Tehran"), .init("Mashhad", "Asia/Tehran"), .init("Isfahan", "Asia/Tehran"),
        .init("Dubai", "Asia/Dubai"), .init("Istanbul", "Europe/Istanbul"), .init("London", "Europe/London"),
        .init("Paris", "Europe/Paris"), .init("Berlin", "Europe/Berlin"), .init("Amsterdam", "Europe/Amsterdam"),
        .init("Stockholm", "Europe/Stockholm"), .init("Moscow", "Europe/Moscow"), .init("New York", "America/New_York"),
        .init("Toronto", "America/Toronto"), .init("Vancouver", "America/Vancouver"), .init("Los Angeles", "America/Los_Angeles"),
        .init("Chicago", "America/Chicago"), .init("São Paulo", "America/Sao_Paulo"), .init("Tokyo", "Asia/Tokyo"),
        .init("Beijing", "Asia/Shanghai"), .init("Delhi", "Asia/Kolkata"), .init("Kabul", "Asia/Kabul"),
        .init("Baku", "Asia/Baku"), .init("Yerevan", "Asia/Yerevan"), .init("Riyadh", "Asia/Riyadh"),
        .init("Doha", "Asia/Qatar"), .init("Baghdad", "Asia/Baghdad"), .init("Sydney", "Australia/Sydney"),
        .init("Melbourne", "Australia/Melbourne"), .init("Kuala Lumpur", "Asia/Kuala_Lumpur"), .init("Singapore", "Asia/Singapore"),
        .init("UTC", "UTC"),
    ]

    static let defaults: [CityEntity] = [.init("Tehran", "Asia/Tehran"), .init("London", "Europe/London"),
                                         .init("New York", "America/New_York"), .init("Tokyo", "Asia/Tokyo")]
}

struct CityQuery: EntityStringQuery {
    func entities(for identifiers: [String]) async throws -> [CityEntity] {
        identifiers.map { CityEntity(id: $0) }
    }

    func suggestedEntities() async throws -> [CityEntity] {
        // Cities the user already uses in jDate first.
        let mine = WidgetData.cache.weatherCities.map { CityEntity($0.name, $0.timeZone) }
        var seen = Set<String>()
        return (mine + CityEntity.popular).filter { seen.insert($0.id).inserted }
    }

    func entities(matching string: String) async throws -> [CityEntity] {
        let q = string.lowercased().trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return try await suggestedEntities() }
        var out = CityEntity.popular.filter { $0.name.lowercased().contains(q) }
        for id in TimeZone.knownTimeZoneIdentifiers where id.lowercased().contains(q) {
            let name = id.split(separator: "/").last.map { $0.replacingOccurrences(of: "_", with: " ") } ?? id
            let e = CityEntity(name, id)
            if !out.contains(e) { out.append(e) }
        }
        return Array(out.prefix(40))
    }
}

// MARK: - Weather cities (from the app's cache)

struct WeatherCityEntity: AppEntity, Hashable {
    let id: String
    let name: String

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "City"
    var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(name)") }
    static let defaultQuery = WeatherCityQuery()
}

struct WeatherCityQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [WeatherCityEntity] {
        let all = try await suggestedEntities()
        return identifiers.map { id in all.first { $0.id == id } ?? WeatherCityEntity(id: id, name: "City") }
    }

    func suggestedEntities() async throws -> [WeatherCityEntity] {
        WidgetData.cache.weatherCities.map { WeatherCityEntity(id: $0.id.uuidString, name: $0.name) }
    }

    func defaultResult() async -> WeatherCityEntity? { try? await suggestedEntities().first }
}

// MARK: - Data helpers

struct WidgetEvent: Hashable {
    var title: String
    var holiday: Bool
    var colorHex: String
    var time: String?
    var symbol: String
}

enum WidgetData {
    static var cache: SharedCache { SharedCache.load() }

    /// Events from the app's cache (includes calendars and birthdays); falls back to the built-in
    /// Iranian calendar for days the cache doesn't cover.
    static func events(on date: Date, cache: SharedCache) -> [WidgetEvent] {
        let g = Calendar(identifier: .gregorian)
        let start = g.startOfDay(for: cache.updated)
        let covered = !cache.events.isEmpty && date >= start && date < (g.date(byAdding: .day, value: 59, to: start) ?? start)
        if covered {
            return cache.events(on: date).map {
                WidgetEvent(title: $0.title, holiday: $0.kind == "holiday", colorHex: $0.colorHex ?? "#8B5CF6", time: $0.time,
                            symbol: $0.kind == "birthday" ? "gift.fill" : $0.kind == "calendar" ? "calendar" : $0.kind == "holiday" ? "flag.fill" : "star.fill")
            }
        }
        return IranianEvents.events(on: date).map {
            WidgetEvent(title: $0.title, holiday: $0.holiday, colorHex: $0.holiday ? "#EF4444" : "#F59E0B", time: nil,
                        symbol: $0.holiday ? "flag.fill" : "star.fill")
        }
    }

    static func isHoliday(_ date: Date, cache: SharedCache) -> Bool {
        CalendarService.isFriday(date) || events(on: date, cache: cache).contains(where: \.holiday)
    }

    static func upcoming(days: Int, from now: Date, cache: SharedCache) -> [(Date, [WidgetEvent])] {
        let g = Calendar(identifier: .gregorian)
        let today = g.startOfDay(for: now)
        return (0..<days).compactMap { i in
            guard let d = g.date(byAdding: .day, value: i, to: today) else { return nil }
            let list = events(on: d, cache: cache)
            return list.isEmpty ? nil : (d, list)
        }
    }

    static func nextMidnight(after date: Date) -> Date {
        let g = Calendar.current
        return g.date(byAdding: .day, value: 1, to: g.startOfDay(for: date)) ?? date.addingTimeInterval(3600)
    }

    static func digits(_ n: Int, _ persian: Bool) -> String { persian ? CalendarService.persianDigits(n) : "\(n)" }
    static func digits(_ s: String, _ persian: Bool) -> String { persian ? CalendarService.persianDigits(s) : s }

    static func monthName(_ date: Date, _ kind: CalendarKind) -> String {
        kind.monthNames[CalendarService.ymd(date, kind).month - 1]
    }
}

// MARK: - Shared chrome

extension View {
    /// Theme gradient (or the system background) as the widget container background.
    @ViewBuilder
    func widgetBackground(_ theme: ResolvedTheme?) -> some View {
        if let theme {
            self.containerBackground(for: .widget) {
                ZStack {
                    theme.gradient
                    if let s = theme.symbol {
                        Image(systemName: s).font(.app(size: 80)).foregroundStyle(.white.opacity(0.10))
                            .rotationEffect(.degrees(-12)).offset(x: 50, y: 30)
                    }
                }
            }
            .foregroundStyle(.white)
        } else {
            self.containerBackground(.background, for: .widget)
        }
    }
}

struct EventLine: View {
    let event: WidgetEvent
    var onTheme: Bool
    var font: CGFloat = 11

    var body: some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 1).fill(onTheme ? Color.white.opacity(0.85) : Color(hex: event.colorHex))
                .frame(width: 2.5, height: font)
            Text(event.title)
                .font(.app(size: font, weight: event.holiday ? .semibold : .regular))
                .foregroundStyle(event.holiday && !onTheme ? Color.red : (onTheme ? Color.white : Color.primary))
                .lineLimit(1)
            Spacer(minLength: 0)
            if let t = event.time {
                Text(t).font(.app(size: font - 1)).opacity(0.7)
            }
        }
    }
}
