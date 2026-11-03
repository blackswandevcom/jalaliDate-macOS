import AppIntents
import SwiftUI
import WidgetKit

// MARK: - Shared day timeline

struct DayEntry<Intent: WidgetConfigurationIntent>: TimelineEntry {
    let date: Date
    let config: Intent
    let cache: SharedCache
}

/// One entry per day, refreshed right after midnight (and every 2 hours so new events show up).
struct DayProvider<Intent: WidgetConfigurationIntent>: AppIntentTimelineProvider {
    let makeDefault: () -> Intent

    func placeholder(in context: Context) -> DayEntry<Intent> {
        DayEntry(date: Date(), config: makeDefault(), cache: SharedCache())
    }

    func snapshot(for configuration: Intent, in context: Context) async -> DayEntry<Intent> {
        DayEntry(date: Date(), config: configuration, cache: WidgetData.cache)
    }

    func timeline(for configuration: Intent, in context: Context) async -> Timeline<DayEntry<Intent>> {
        let now = Date()
        let cache = WidgetData.cache
        let midnight = WidgetData.nextMidnight(after: now)
        let entries = [DayEntry(date: now, config: configuration, cache: cache),
                       DayEntry(date: midnight.addingTimeInterval(1), config: configuration, cache: cache)]
        return Timeline(entries: entries, policy: .after(min(midnight.addingTimeInterval(60), now.addingTimeInterval(2 * 3600))))
    }
}

// MARK: - Today

struct TodayIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Today"
    static let description = IntentDescription("Today's date in your calendars.")

    @Parameter(title: "Main calendar", default: .jalali) var main: CalendarChoice
    @Parameter(title: "Show Jalali", default: true) var showJalali: Bool
    @Parameter(title: "Show Gregorian", default: true) var showGregorian: Bool
    @Parameter(title: "Show Hijri", default: true) var showHijri: Bool
    @Parameter(title: "Persian digits", default: true) var persianDigits: Bool
    @Parameter(title: "Show events", default: true) var showEvents: Bool
    @Parameter(title: "Style", default: .app) var style: StyleChoice

    init() {}
}

struct TodayWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "jdate.today", intent: TodayIntent.self, provider: DayProvider { TodayIntent() }) { entry in
            TodayView(entry: entry)
        }
        .configurationDisplayName("Today")
        .description("Today in Jalali, Gregorian and Hijri, with holidays and events.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

struct TodayView: View {
    let entry: DayEntry<TodayIntent>
    @Environment(\.widgetFamily) private var family

    private var cfg: TodayIntent { entry.config }
    private var theme: ResolvedTheme? { cfg.style.theme(entry.date) }
    private var main: CalendarKind { cfg.main.kind }
    private var others: [CalendarKind] {
        CalendarKind.allCases.filter { k in
            k != main && (k == .jalali ? cfg.showJalali : k == .gregorian ? cfg.showGregorian : cfg.showHijri)
        }
    }
    private var events: [WidgetEvent] { cfg.showEvents ? WidgetData.events(on: entry.date, cache: entry.cache) : [] }
    private var holiday: Bool { WidgetData.isHoliday(entry.date, cache: entry.cache) }
    private var isEventHoliday: Bool { WidgetData.events(on: entry.date, cache: entry.cache).contains(where: \.holiday) }
    private var persian: Bool { cfg.persianDigits && main != .gregorian }

    var body: some View {
        Group {
            switch family {
            case .systemSmall: small
            case .systemLarge: large
            default: medium
            }
        }
        .widgetBackground(theme, glass: cfg.style.glass)
    }

    private var bigDay: some View {
        let p = CalendarService.ymd(entry.date, main)
        return Text(WidgetData.digits(p.day, persian))
            .font(.app(size: family == .systemSmall ? 46 : 56, weight: .bold, design: .rounded))
            .foregroundStyle(theme == nil && holiday ? (DayColors.color(holiday: isEventHoliday, date: entry.date) ?? .primary) : (theme == nil ? Color.primary : Color.white))
            .widgetAccentable()
            .minimumScaleFactor(0.6)
    }

    private var monthLine: some View {
        let p = CalendarService.ymd(entry.date, main)
        return Text("\(WidgetData.monthName(entry.date, main)) \(WidgetData.digits(p.year, persian))")
            .font(.app(size: 13, weight: .semibold))
            .lineLimit(1).minimumScaleFactor(0.7)
    }

    private func otherLine(_ k: CalendarKind, size: CGFloat = 11) -> some View {
        let p = CalendarService.ymd(entry.date, k)
        let digitsP = cfg.persianDigits && k != .gregorian
        return HStack(spacing: 4) {
            Image(systemName: k.symbol).font(.app(size: size - 1)).opacity(0.75)
            Text("\(WidgetData.digits(p.day, digitsP)) \(WidgetData.monthName(entry.date, k)) \(WidgetData.digits(p.year, digitsP))")
                .font(.app(size: size)).lineLimit(1).minimumScaleFactor(0.7)
        }
        .opacity(0.9)
    }

    private var weekday: some View {
        Text(CalendarService.weekday(entry.date, main == .gregorian ? .gregorian : .jalali))
            .font(.app(size: 12, weight: .medium)).opacity(0.85)
    }

    private var small: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack { weekday; Spacer(); if holiday { Image(systemName: "flag.fill").font(.app(.caption2)).foregroundStyle(theme == nil ? DayColors.holiday : .white) } }
            bigDay.padding(.vertical, -4)
            monthLine
            Spacer(minLength: 2)
            ForEach(others.prefix(2), id: \.self) { otherLine($0, size: 10) }
            if let e = events.first, others.count < 2 { EventLine(event: e, onTheme: theme != nil, font: 10) }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var medium: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 0) {
                weekday
                bigDay.padding(.vertical, -4)
                monthLine
            }
            .frame(width: 118, alignment: .leading)
            VStack(alignment: .leading, spacing: 4) {
                ForEach(others, id: \.self) { otherLine($0, size: 12) }
                if !events.isEmpty {
                    Divider().opacity(0.4)
                    ForEach(events.prefix(others.count >= 2 ? 2 : 3), id: \.self) { EventLine(event: $0, onTheme: theme != nil) }
                } else if cfg.showEvents {
                    Text(holiday ? "Holiday" : "No events today").font(.app(size: 11)).opacity(0.6)
                }
                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var large: some View {
        VStack(alignment: .leading, spacing: 8) {
            medium.frame(height: 110)
            MonthGrid(date: entry.date, kind: main == .gregorian ? .gregorian : .jalali, persian: persian,
                      onTheme: theme != nil, cache: entry.cache, compact: true)
            if cfg.showEvents {
                let up = WidgetData.upcoming(days: 10, from: entry.date, cache: entry.cache).filter { !Calendar.current.isDate($0.0, inSameDayAs: entry.date) }
                if let (d, list) = up.first, let e = list.first {
                    HStack(spacing: 4) {
                        Text("in \(CalendarService.daysFromToday(d, now: entry.date))d").font(.app(size: 10, weight: .semibold)).opacity(0.7)
                        EventLine(event: e, onTheme: theme != nil, font: 11)
                    }
                }
            }
        }
    }
}

// MARK: - Month

struct MonthIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Month"
    static let description = IntentDescription("A month calendar with holidays.")

    @Parameter(title: "Calendar", default: .jalali) var calendar: MonthCalendarChoice
    @Parameter(title: "Persian digits", default: true) var persianDigits: Bool
    @Parameter(title: "Show second calendar's days", default: true) var secondary: Bool
    @Parameter(title: "Show today's events (large)", default: true) var showEvents: Bool
    @Parameter(title: "Style", default: .plain) var style: StyleChoice

    init() {}
}

struct MonthWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "jdate.month", intent: MonthIntent.self, provider: DayProvider { MonthIntent() }) { entry in
            MonthWidgetView(entry: entry)
        }
        .configurationDisplayName("Month")
        .description("The Jalali or Gregorian month, with holidays and weekends in your colors.")
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}

struct MonthWidgetView: View {
    let entry: DayEntry<MonthIntent>
    @Environment(\.widgetFamily) private var family

    var body: some View {
        let cfg = entry.config
        let theme = cfg.style.theme(entry.date)
        let kind = cfg.calendar.kind
        let persian = cfg.persianDigits && kind == .jalali
        Group {
            if family == .systemMedium {
                HStack(alignment: .top, spacing: 10) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(CalendarService.weekday(entry.date, kind)).font(.app(size: 12, weight: .medium)).opacity(0.8)
                        Text(WidgetData.digits(CalendarService.ymd(entry.date, kind).day, persian))
                            .font(.app(size: 40, weight: .bold, design: .rounded)).widgetAccentable()
                        Text(WidgetData.monthName(entry.date, kind)).font(.app(size: 13, weight: .semibold))
                        Text(WidgetData.digits(CalendarService.ymd(entry.date, kind).year, persian)).font(.app(size: 11)).opacity(0.7)
                        Spacer(minLength: 0)
                        if let e = WidgetData.events(on: entry.date, cache: entry.cache).first {
                            Text(e.title).font(.app(size: 9)).lineLimit(2).opacity(0.8)
                        }
                    }
                    .frame(width: 92, alignment: .leading)
                    MonthGrid(date: entry.date, kind: kind, persian: persian, onTheme: theme != nil, cache: entry.cache,
                              compact: true, secondary: false, showTitle: false)
                }
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    MonthGrid(date: entry.date, kind: kind, persian: persian, onTheme: theme != nil, cache: entry.cache,
                              compact: false, secondary: cfg.secondary)
                    if cfg.showEvents {
                        let list = WidgetData.events(on: entry.date, cache: entry.cache)
                        ForEach(list.prefix(2), id: \.self) { EventLine(event: $0, onTheme: theme != nil) }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .widgetBackground(theme, glass: cfg.style.glass)
    }
}

/// Month grid used by the Month and the large Today widget.
struct MonthGrid: View {
    let date: Date
    let kind: CalendarKind
    let persian: Bool
    let onTheme: Bool
    let cache: SharedCache
    var compact = false
    var secondary = false
    var showTitle = true

    var body: some View {
        let cal = kind.calendar
        let start = cal.date(from: cal.dateComponents([.year, .month], from: date)) ?? date
        let days = cal.range(of: .day, in: .month, for: start)?.count ?? 30
        let weekday = Calendar(identifier: .gregorian).component(.weekday, from: start) // 1 = Sun
        // Jalali weeks start on Saturday, Gregorian on Monday.
        let leading = kind == .jalali ? weekday % 7 : (weekday + 5) % 7
        let headers = kind == .jalali ? ["ش", "ی", "د", "س", "چ", "پ", "ج"] : ["M", "T", "W", "T", "F", "S", "S"]
        let rows = Int(ceil(Double(leading + days) / 7))
        let g = Calendar(identifier: .gregorian)
        let today = g.startOfDay(for: date)

        VStack(spacing: compact ? 1 : 3) {
            if showTitle {
                HStack {
                    Text("\(kind.monthNames[CalendarService.ymd(date, kind).month - 1]) \(WidgetData.digits(CalendarService.ymd(date, kind).year, persian))")
                        .font(.app(size: 12, weight: .semibold))
                    Spacer()
                }
            }
            Grid(horizontalSpacing: 0, verticalSpacing: compact ? 0 : 2) {
                GridRow {
                    ForEach(0..<7, id: \.self) { i in
                        Text(headers[i]).font(.app(size: 9, weight: .medium))
                            .foregroundStyle(DayColors.isWeekend(weekday: DayColors.weekday(column: i, jalali: kind == .jalali)) && !onTheme ? DayColors.weekend : Color.secondary)
                            .frame(maxWidth: .infinity)
                    }
                }
                ForEach(0..<rows, id: \.self) { r in
                    GridRow {
                        ForEach(0..<7, id: \.self) { c in
                            let idx = r * 7 + c - leading
                            if idx >= 0 && idx < days, let d = g.date(byAdding: .day, value: idx, to: start) {
                                let isToday = g.isDate(d, inSameDayAs: today)
                                let dayColor = DayColors.color(holiday: WidgetData.events(on: d, cache: cache).contains(where: \.holiday), date: d)
                                VStack(spacing: 0) {
                                    Text(WidgetData.digits(idx + 1, persian))
                                        .font(.app(size: compact ? 10 : 12, weight: isToday ? .bold : .regular))
                                    if secondary {
                                        Text(kind == .jalali ? "\(g.component(.day, from: d))" : CalendarService.persianDigits(CalendarService.ymd(d, .jalali).day))
                                            .font(.app(size: 7)).opacity(0.55)
                                    }
                                }
                                .foregroundStyle(isToday ? (onTheme ? Color.black : Color.white) : (dayColor != nil && !onTheme ? dayColor! : (onTheme ? Color.white : Color.primary)))
                                .frame(maxWidth: .infinity).frame(height: compact ? 16 : (secondary ? 34 : 30))
                                .background {
                                    if isToday {
                                        Circle().fill(onTheme ? Color.white : Color.accentColor).frame(width: compact ? 17 : 26, height: compact ? 17 : 26)
                                            .widgetAccentable()
                                    }
                                }
                                .overlay(alignment: .bottom) {
                                    if dayColor != nil && onTheme && !isToday { Circle().fill(.white).frame(width: 2.5, height: 2.5).offset(y: 1) }
                                }
                            } else {
                                Color.clear.frame(maxWidth: .infinity).frame(height: compact ? 16 : (secondary ? 34 : 30))
                            }
                        }
                    }
                }
            }
        }
        .environment(\.layoutDirection, kind == .jalali ? .rightToLeft : .leftToRight)
    }
}
