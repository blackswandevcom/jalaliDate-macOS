import AppIntents
import SwiftUI
import WidgetKit

@main
struct JDateWidgetBundle: WidgetBundle {
    var body: some Widget {
        TodayWidget()
        MonthWidget()
        WorldClockWidget()
        UpcomingWidget()
        WeatherWidget()
        CountdownWidget()
    }
}

// MARK: - World clock

struct ClockIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "World Clock"
    static let description = IntentDescription("Time in other cities.")

    @Parameter(title: "Cities", size: [.systemSmall: 1, .systemMedium: 4, .systemLarge: 8]) var cities: [CityEntity]?
    @Parameter(title: "24-hour", default: true) var h24: Bool
    @Parameter(title: "Style", default: .plain) var style: StyleChoice

    init() {}
}

struct ClockEntry: TimelineEntry {
    let date: Date
    let config: ClockIntent
}

struct ClockProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> ClockEntry { ClockEntry(date: Date(), config: ClockIntent()) }
    func snapshot(for configuration: ClockIntent, in context: Context) async -> ClockEntry { ClockEntry(date: Date(), config: configuration) }

    func timeline(for configuration: ClockIntent, in context: Context) async -> Timeline<ClockEntry> {
        // One entry per minute for the next 2 hours.
        let g = Calendar.current
        let now = Date()
        let minute = g.date(from: g.dateComponents([.year, .month, .day, .hour, .minute], from: now)) ?? now
        let entries = (0..<120).map { ClockEntry(date: minute.addingTimeInterval(Double($0) * 60), config: configuration) }
        return Timeline(entries: entries, policy: .atEnd)
    }
}

struct WorldClockWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "jdate.clock", intent: ClockIntent.self, provider: ClockProvider()) { entry in
            ClockWidgetView(entry: entry)
        }
        .configurationDisplayName("World Clock")
        .description("Cities with their time and difference from yours.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

struct ClockWidgetView: View {
    let entry: ClockEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        let theme = entry.config.style.theme(entry.date)
        let max = family == .systemSmall ? 1 : family == .systemMedium ? 4 : 8
        let picked = (entry.config.cities?.isEmpty == false ? entry.config.cities! : CityEntity.defaults)
        let cities = Array(picked.prefix(max))

        Group {
            if family == .systemSmall, let c = cities.first {
                VStack(alignment: .leading, spacing: 2) {
                    cityHeader(c, big: true)
                    Spacer(minLength: 0)
                    Text(time(c, entry.date))
                        .font(.app(size: 34, weight: .semibold, design: .rounded)).monospacedDigit()
                        .minimumScaleFactor(0.6).lineLimit(1).widgetAccentable()
                    Text([c.city.offsetText(at: entry.date), c.city.dayRelation(at: entry.date)].compactMap { $0 }.joined(separator: " · "))
                        .font(.app(size: 11)).opacity(0.7)
                    Text(dateText(c, entry.date)).font(.app(size: 11)).opacity(0.7)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            } else if family == .systemMedium {
                Grid(horizontalSpacing: 8, verticalSpacing: 8) {
                    ForEach(0..<2, id: \.self) { r in
                        GridRow {
                            ForEach(0..<2, id: \.self) { col in
                                let i = r * 2 + col
                                if i < cities.count { tile(cities[i], theme: theme) } else { Color.clear }
                            }
                        }
                    }
                }
            } else {
                VStack(spacing: 0) {
                    ForEach(cities, id: \.self) { c in
                        HStack {
                            cityHeader(c, big: false)
                            Spacer()
                            VStack(alignment: .trailing, spacing: 0) {
                                Text(time(c, entry.date)).font(.app(size: 20, weight: .semibold, design: .rounded)).monospacedDigit()
                                Text(c.city.offsetText(at: entry.date)).font(.app(size: 10)).opacity(0.7)
                            }
                        }
                        .frame(maxHeight: .infinity)
                        if c != cities.last { Divider().opacity(0.4) }
                    }
                }
            }
        }
        .widgetBackground(theme)
    }

    private func tile(_ c: CityEntity, theme: ResolvedTheme?) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            cityHeader(c, big: false)
            Text(time(c, entry.date)).font(.app(size: 20, weight: .semibold, design: .rounded)).monospacedDigit()
                .lineLimit(1).minimumScaleFactor(0.6)
            Text([c.city.offsetText(at: entry.date), c.city.dayRelation(at: entry.date)].compactMap { $0 }.joined(separator: " · "))
                .font(.app(size: 9)).opacity(0.7).lineLimit(1)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(.horizontal, 8)
        .background(RoundedRectangle(cornerRadius: 10).fill((theme == nil ? Color.primary : Color.white).opacity(0.07)))
    }

    private func cityHeader(_ c: CityEntity, big: Bool) -> some View {
        let night = c.city.isNight(at: entry.date)
        return HStack(spacing: 4) {
            Image(systemName: night ? "moon.fill" : "sun.max.fill").font(.app(size: big ? 11 : 9))
                .foregroundStyle(night ? Color.indigo : Color.orange)
            Text(c.name).font(.app(size: big ? 13 : 11, weight: .semibold)).lineLimit(1)
        }
    }

    private func time(_ c: CityEntity, _ d: Date) -> String {
        let f = DateFormatter()
        f.timeZone = c.tz
        f.locale = Locale(identifier: "en_US")
        f.dateFormat = entry.config.h24 ? "HH:mm" : "h:mm a"
        return f.string(from: d)
    }

    private func dateText(_ c: CityEntity, _ d: Date) -> String {
        let f = DateFormatter()
        f.timeZone = c.tz
        f.locale = Locale(identifier: "en_US")
        f.dateFormat = "EEE d MMM"
        return f.string(from: d)
    }
}

// MARK: - Upcoming

struct UpcomingIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Upcoming"
    static let description = IntentDescription("Holidays, occasions, birthdays and events coming up.")

    @Parameter(title: "Days ahead", default: 14, inclusiveRange: (1, 60)) var days: Int
    @Parameter(title: "Holidays only", default: false) var holidaysOnly: Bool
    @Parameter(title: "Style", default: .plain) var style: StyleChoice

    init() {}
}

struct UpcomingWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "jdate.upcoming", intent: UpcomingIntent.self, provider: DayProvider { UpcomingIntent() }) { entry in
            UpcomingWidgetView(entry: entry)
        }
        .configurationDisplayName("Upcoming")
        .description("What's coming in the next days.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

struct UpcomingWidgetView: View {
    let entry: DayEntry<UpcomingIntent>
    @Environment(\.widgetFamily) private var family

    var body: some View {
        let theme = entry.config.style.theme(entry.date)
        let items: [(Date, [WidgetEvent])] = WidgetData.upcoming(days: entry.config.days, from: entry.date, cache: entry.cache)
            .map { ($0.0, entry.config.holidaysOnly ? $0.1.filter(\.holiday) : $0.1) }
            .filter { !$0.1.isEmpty }
        let maxLines = family == .systemSmall ? 4 : family == .systemMedium ? 5 : 12

        VStack(alignment: .leading, spacing: 4) {
            Label("Upcoming", systemImage: "calendar.badge.clock").font(.app(size: 11, weight: .semibold)).opacity(0.75)
            if items.isEmpty {
                Spacer()
                Text("Nothing in the next \(entry.config.days) days").font(.app(size: 11)).opacity(0.6)
                Spacer()
            }
            ForEach(Array(flatten(items).prefix(maxLines).enumerated()), id: \.offset) { _, pair in
                HStack(spacing: 6) {
                    let d = CalendarService.daysFromToday(pair.0, now: entry.date)
                    Text(family == .systemSmall ? (d == 0 ? "today" : "\(d)d") :
                            "\(CalendarService.persianDigits(CalendarService.ymd(pair.0, .jalali).day)) \(WidgetData.monthName(pair.0, .jalali))")
                        .font(.app(size: 10, weight: .semibold)).monospacedDigit()
                        .frame(width: family == .systemSmall ? 30 : 64, alignment: .leading)
                        .opacity(0.8)
                    EventLine(event: pair.1, onTheme: theme != nil, font: family == .systemSmall ? 10 : 11)
                    if family != .systemSmall {
                        Text(d == 0 ? "today" : "in \(d)d").font(.app(size: 9)).opacity(0.6)
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .widgetBackground(theme)
    }

    private func flatten(_ items: [(Date, [WidgetEvent])]) -> [(Date, WidgetEvent)] {
        items.flatMap { d, list in list.map { (d, $0) } }
    }
}

// MARK: - Weather

struct WeatherIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Weather"
    static let description = IntentDescription("Weather of a city you added in jDate.")

    @Parameter(title: "City") var city: WeatherCityEntity?
    @Parameter(title: "Style", default: .weather) var style: StyleChoice

    init() {}
}

struct WeatherEntry: TimelineEntry {
    let date: Date
    let config: WeatherIntent
    let cache: SharedCache
}

struct WeatherProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> WeatherEntry { WeatherEntry(date: Date(), config: WeatherIntent(), cache: SharedCache()) }
    func snapshot(for configuration: WeatherIntent, in context: Context) async -> WeatherEntry {
        WeatherEntry(date: Date(), config: configuration, cache: WidgetData.cache)
    }
    func timeline(for configuration: WeatherIntent, in context: Context) async -> Timeline<WeatherEntry> {
        Timeline(entries: [WeatherEntry(date: Date(), config: configuration, cache: WidgetData.cache)],
                 policy: .after(Date().addingTimeInterval(30 * 60)))
    }
}

struct WeatherWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "jdate.weather", intent: WeatherIntent.self, provider: WeatherProvider()) { entry in
            WeatherWidgetView(entry: entry)
        }
        .configurationDisplayName("Weather")
        .description("Current weather from jDate. Add cities in jDate › Popover Layout or Weather.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

struct WeatherWidgetView: View {
    let entry: WeatherEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        let cache = entry.cache
        let city = entry.config.city.flatMap { e in cache.weatherCities.first { $0.id.uuidString == e.id } } ?? cache.weatherCities.first
        let snap = city.flatMap { cache.weather[$0.id.uuidString] }
        let theme: ResolvedTheme? = entry.config.style == .weather
            ? (snap.map(ThemeResolver.weatherTheme) ?? ThemeResolver.season(entry.date))
            : entry.config.style.theme(entry.date)
        let f = { (c: Double) in cache.unit.format(c) }

        Group {
            if let city, let s = snap {
                if family == .systemSmall {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(city.name).font(.app(size: 13, weight: .semibold)).lineLimit(1)
                        Text(f(s.temperature)).font(.app(size: 38, weight: .medium, design: .rounded)).widgetAccentable()
                        Spacer(minLength: 0)
                        Image(systemName: s.condition.symbol(isDay: s.isDay)).symbolRenderingMode(.multicolor).font(.app(size: 18))
                        Text(s.condition.title).font(.app(size: 11, weight: .medium))
                        Text("↑\(f(s.high)) ↓\(f(s.low))").font(.app(size: 10)).opacity(0.8)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                } else {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 0) {
                                Text(city.name).font(.app(size: 13, weight: .semibold))
                                Text(f(s.temperature)).font(.app(size: 34, weight: .medium, design: .rounded)).widgetAccentable()
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Image(systemName: s.condition.symbol(isDay: s.isDay)).symbolRenderingMode(.multicolor).font(.app(size: 20))
                                Text(s.condition.title).font(.app(size: 11, weight: .medium))
                                Text("↑\(f(s.high)) ↓\(f(s.low))").font(.app(size: 10)).opacity(0.8)
                            }
                        }
                        HStack(spacing: 0) {
                            ForEach(Array(s.hourly.filter { $0.date >= entry.date.addingTimeInterval(-3600) }.prefix(6).enumerated()), id: \.offset) { _, h in
                                VStack(spacing: 2) {
                                    Text(hour(h.date, city)).font(.app(size: 9)).opacity(0.75)
                                    Image(systemName: h.condition.symbol(isDay: h.isDay)).symbolRenderingMode(.multicolor).font(.app(size: 11))
                                    Text(f(h.temperature)).font(.app(size: 10, weight: .medium))
                                }
                                .frame(maxWidth: .infinity)
                            }
                        }
                        if family == .systemLarge, let days = s.daily, days.count > 1 {
                            Divider().overlay(Color.primary.opacity(0.15))
                            DailyForecastList(days: days, city: city, unit: cache.unit, count: 6)
                            HStack {
                                if let h = s.humidity { Label("\(Int(h))%", systemImage: "humidity.fill") }
                                if let w = s.windKmh { Label("\(Int(w.rounded())) km/h", systemImage: "wind") }
                                Spacer()
                                Text(s.provider).opacity(0.6)
                            }
                            .font(.app(size: 10))
                        }
                    }
                }
            } else {
                VStack(spacing: 6) {
                    Image(systemName: "cloud.sun").font(.app(.title2))
                    Text("Open jDate and add a city in Weather settings.").font(.app(size: 11)).multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .widgetBackground(theme)
    }

    private func hour(_ d: Date, _ c: City) -> String {
        let f = DateFormatter()
        f.timeZone = c.tz
        f.dateFormat = "HH"
        return f.string(from: d)
    }
}

// MARK: - Countdown

struct CountdownIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Countdown"
    static let description = IntentDescription("Days left until a date.")

    @Parameter(title: "Title", default: "Nowruz") var title: String
    @Parameter(title: "Calendar", default: .jalali) var calendar: CalendarChoice
    @Parameter(title: "Month", default: 1, inclusiveRange: (1, 12)) var month: Int
    @Parameter(title: "Day", default: 1, inclusiveRange: (1, 31)) var day: Int
    @Parameter(title: "Year (0 = every year)", default: 0) var year: Int
    @Parameter(title: "Style", default: .season) var style: StyleChoice

    init() {}
}

struct CountdownWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "jdate.countdown", intent: CountdownIntent.self, provider: DayProvider { CountdownIntent() }) { entry in
            CountdownWidgetView(entry: entry)
        }
        .configurationDisplayName("Countdown")
        .description("Days until Nowruz, Yalda or any date.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct CountdownWidgetView: View {
    let entry: DayEntry<CountdownIntent>
    @Environment(\.widgetFamily) private var family

    var body: some View {
        let c = entry.config
        let theme = c.style.theme(entry.date)
        let kind = c.calendar.kind
        let target = nextDate(kind: kind, month: c.month, day: c.day, year: c.year == 0 ? nil : c.year)
        let days = target.map { CalendarService.daysFromToday($0, now: entry.date) }

        VStack(alignment: .leading, spacing: 2) {
            Label(c.title, systemImage: "hourglass").font(.app(size: 12, weight: .semibold)).lineLimit(1).opacity(0.85)
            Spacer(minLength: 0)
            if let days, let target {
                Text(days == 0 ? "🎉" : "\(days)")
                    .font(.app(size: family == .systemSmall ? 44 : 50, weight: .bold, design: .rounded)).widgetAccentable()
                Text(days == 0 ? "Today!" : days == 1 ? "day left" : "days left").font(.app(size: 12, weight: .medium))
                Text(CalendarService.long(target, kind)).font(.app(size: 10)).opacity(0.75).lineLimit(1)
                if family == .systemMedium {
                    Text("\(CalendarService.long(target, kind == .gregorian ? .jalali : .gregorian)) · \(days / 7) weeks \(days % 7) days")
                        .font(.app(size: 10)).opacity(0.65)
                }
            } else {
                Text("Date passed").font(.app(size: 14))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .widgetBackground(theme)
    }

    private func nextDate(kind: CalendarKind, month: Int, day: Int, year: Int?) -> Date? {
        let today = Calendar(identifier: .gregorian).startOfDay(for: entry.date)
        if let year { return CalendarService.date(year: year, month: month, day: day, kind) }
        let y = CalendarService.ymd(entry.date, kind).year
        for cand in [y, y + 1] {
            if let d = CalendarService.date(year: cand, month: month, day: day, kind), d >= today { return d }
        }
        return nil
    }
}
