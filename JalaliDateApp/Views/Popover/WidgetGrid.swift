import SwiftUI

struct WidgetGrid: View {
    @ObservedObject var model: AppModel
    @ObservedObject var settings: AppSettings
    let width: CGFloat
    private let gap: CGFloat = 6

    init(model: AppModel, width: CGFloat) {
        self.model = model
        self.settings = model.settings
        self.width = width
    }

    private func w(_ size: WidgetSize) -> CGFloat {
        let unit = (width - 5 * gap) / 6
        return unit * CGFloat(size.units) + gap * CGFloat(size.units - 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: gap) {
            ForEach(Array(settings.layout.rows.enumerated()), id: \.offset) { _, row in
                HStack(spacing: gap) {
                    ForEach(row) { cfg in
                        WidgetView(model: model, config: cfg)
                            .frame(width: w(cfg.size))
                            .contextMenu { menu(for: cfg) }
                    }
                }
            }
        }
        .frame(width: width, alignment: .leading)
    }

    @ViewBuilder
    private func menu(for cfg: WidgetConfig) -> some View {
        ForEach(WidgetSize.allCases) { size in
            Button { resize(cfg, size) } label: {
                if cfg.size == size { Label(size.title, systemImage: "checkmark") } else { Text(size.title) }
            }
        }
        Divider()
        Button("Customize widgets…") { model.open(.layout) }
        Button("Remove", role: .destructive) { settings.layout.widgets.removeAll { $0.id == cfg.id }; model.syncWeatherCities() }
    }

    private func resize(_ cfg: WidgetConfig, _ size: WidgetSize) {
        if let i = settings.layout.widgets.firstIndex(where: { $0.id == cfg.id }) { settings.layout.widgets[i].size = size }
    }
}

/// Tile chrome shared by all popover widgets.
struct Tile<Content: View>: View {
    var tint: Color = .primary
    @ViewBuilder var content: Content
    @State private var hovering = false

    var body: some View {
        content
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, minHeight: 50, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.primary.opacity(hovering ? 0.09 : 0.05)))
            .contentShape(Rectangle())
            .onHover { hovering = $0 }
    }
}

struct WidgetView: View {
    @ObservedObject var model: AppModel
    let config: WidgetConfig

    var body: some View {
        switch config.kind {
        case .date(let kind): DateWidget(model: model, kind: kind, size: config.size)
        case .weather(let city): WeatherWidget(weather: model.weather, city: city, size: config.size)
        case .clock(let city): ClockWidget(city: city, size: config.size, h24: model.settings.general.clock24h)
        case .countdown(let target): CountdownWidget(target: target, size: config.size, now: model.now)
        case .upcoming: NextEventWidget(model: model, events: model.events, size: config.size)
        }
    }
}

// MARK: - Date

struct DateWidget: View {
    @ObservedObject var model: AppModel
    let kind: CalendarKind
    let size: WidgetSize

    private var copied: Bool { model.copiedKey == "today-\(kind.rawValue)" }

    var body: some View {
        Button { model.copyToday(kind) } label: {
            Tile {
                if size == .full {
                    HStack(spacing: 10) {
                        Image(systemName: kind.symbol).font(.app(size: 20)).foregroundStyle(kind.tint)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(CalendarService.long(model.now, kind)).font(.app(size: 13, weight: .medium))
                            Text(CalendarService.iso(model.now, kind)).font(.app(size: 11).monospacedDigit()).foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 0)
                        if copied {
                            Label("Copied", systemImage: "checkmark.circle.fill").font(.app(.caption)).foregroundStyle(.green)
                        } else {
                            Text("⌘\(String(kind.copyShortcut.character).uppercased())").font(.app(.caption2)).foregroundStyle(.tertiary)
                        }
                    }
                } else {
                    let p = CalendarService.ymd(model.now, kind)
                    VStack(alignment: .leading, spacing: 1) {
                        HStack(spacing: 4) {
                            Image(systemName: copied ? "checkmark.circle.fill" : kind.symbol)
                                .foregroundStyle(copied ? .green : kind.tint)
                            Text(kind.shortTitle).font(.app(size: 10, weight: .semibold)).foregroundStyle(.secondary)
                        }
                        Text(kind == .gregorian ? "\(p.day) \(CalendarService.format(model.now, .gregorian, "MMM", locale: Locale(identifier: "en_US")))"
                                                : CalendarService.persianDigits("\(p.day) \(kind.monthNames[p.month - 1])"))
                            .font(.app(size: size == .third ? 12 : 14, weight: .semibold))
                            .lineLimit(1).minimumScaleFactor(0.7)
                        Text(CalendarService.iso(model.now, kind)).font(.app(size: 10).monospacedDigit()).foregroundStyle(.secondary)
                    }
                }
            }
        }
        .buttonStyle(.plain)
        .keyboardShortcut(kind.copyShortcut, modifiers: .command)
        .help("Copy \(kind.title) date")
    }
}

// MARK: - Weather

struct WeatherWidget: View {
    @ObservedObject var weather: WeatherStore
    let city: City
    let size: WidgetSize

    var body: some View {
        Tile {
            if let s = weather.snapshots[city.id] {
                switch size {
                case .third:
                    VStack(alignment: .leading, spacing: 2) {
                        Text(city.name).font(.app(size: 10, weight: .semibold)).foregroundStyle(.secondary).lineLimit(1)
                        HStack(spacing: 4) {
                            Image(systemName: s.condition.symbol(isDay: s.isDay)).symbolRenderingMode(.multicolor)
                            Text(weather.format(s.temperature)).font(.app(size: 16, weight: .semibold))
                        }
                    }
                case .half:
                    HStack(spacing: 8) {
                        Image(systemName: s.condition.symbol(isDay: s.isDay)).symbolRenderingMode(.multicolor).font(.app(size: 22))
                        VStack(alignment: .leading, spacing: 1) {
                            Text("\(weather.format(s.temperature))  \(city.name)").font(.app(size: 13, weight: .semibold)).lineLimit(1)
                            Text("↑\(weather.format(s.high)) ↓\(weather.format(s.low))").font(.app(size: 10)).foregroundStyle(.secondary)
                        }
                    }
                case .full:
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 10) {
                            Image(systemName: s.condition.symbol(isDay: s.isDay)).symbolRenderingMode(.multicolor).font(.app(size: 26))
                            VStack(alignment: .leading, spacing: 1) {
                                Text("\(city.name) · \(s.condition.title)").font(.app(size: 12, weight: .semibold))
                                Text("Feels \(weather.format(s.feelsLike)) · ↑\(weather.format(s.high)) ↓\(weather.format(s.low))"
                                     + (s.humidity.map { " · 💧\(Int($0))%" } ?? ""))
                                    .font(.app(size: 10)).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(weather.format(s.temperature)).font(.app(size: 26, weight: .semibold, design: .rounded))
                        }
                        if !s.hourly.isEmpty {
                            HStack(spacing: 0) {
                                ForEach(Array(s.hourly.prefix(6).enumerated()), id: \.offset) { _, h in
                                    VStack(spacing: 2) {
                                        Text(hour(h.date)).font(.app(size: 9)).foregroundStyle(.secondary)
                                        Image(systemName: h.condition.symbol(isDay: h.isDay)).symbolRenderingMode(.multicolor).font(.app(size: 11))
                                        Text(weather.format(h.temperature)).font(.app(size: 10, weight: .medium))
                                    }
                                    .frame(maxWidth: .infinity)
                                }
                            }
                        }
                        if let days = s.daily, days.count > 1 {
                            Divider().opacity(0.5)
                            DailyForecastStrip(days: days, city: city, unit: weather.settings.unit)
                        }
                    }
                }
            } else {
                HStack(spacing: 6) {
                    Image(systemName: "cloud").foregroundStyle(.secondary)
                    Text(weather.errors[city.id] ?? "Loading \(city.name)…").font(.app(size: 10)).foregroundStyle(.secondary).lineLimit(2)
                }
            }
        }
        .help(weather.snapshots[city.id].map { "\(city.name) · \($0.provider) · \($0.fetchedAt.formatted(date: .omitted, time: .shortened))" } ?? city.name)
    }

    private func hour(_ d: Date) -> String {
        let f = DateFormatter()
        f.timeZone = city.tz
        f.dateFormat = "HH"
        return f.string(from: d)
    }
}

// MARK: - World clock

struct ClockWidget: View {
    let city: City
    let size: WidgetSize
    let h24: Bool

    var body: some View {
        TimelineView(.everyMinute) { ctx in
            Tile {
                let night = city.isNight(at: ctx.date)
                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 4) {
                        Image(systemName: night ? "moon.fill" : "sun.max.fill")
                            .font(.app(size: 9))
                            .foregroundStyle(night ? Color.indigo : Color.orange)
                        Text(city.name).font(.app(size: 10, weight: .semibold)).foregroundStyle(.secondary).lineLimit(1)
                        if size == .full { Spacer(); Text(city.offsetText(at: ctx.date)).font(.app(size: 10)).foregroundStyle(.secondary) }
                    }
                    Text(time(ctx.date))
                        .font(.app(size: size == .third ? 17 : 20, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .lineLimit(1).minimumScaleFactor(0.6)
                    HStack(spacing: 4) {
                        if size != .full { Text(city.offsetText(at: ctx.date)) }
                        if let rel = city.dayRelation(at: ctx.date) { Text(rel) }
                        if size == .full { Text(date(ctx.date)) }
                    }
                    .font(.app(size: 9)).foregroundStyle(.secondary).lineLimit(1)
                }
            }
        }
    }

    private func time(_ d: Date) -> String {
        let f = DateFormatter()
        f.timeZone = city.tz
        f.locale = Locale(identifier: "en_US")
        f.dateFormat = h24 ? "HH:mm" : "h:mm a"
        return f.string(from: d)
    }

    private func date(_ d: Date) -> String {
        let f = DateFormatter()
        f.timeZone = city.tz
        f.locale = Locale(identifier: "en_US")
        f.dateFormat = "EEE d MMM"
        return f.string(from: d)
    }
}

// MARK: - Countdown

struct CountdownWidget: View {
    let target: CountdownTarget
    let size: WidgetSize
    let now: Date

    var body: some View {
        Tile {
            let days = target.nextDate(from: now).map { CalendarService.daysFromToday($0, now: now) }
            VStack(alignment: .leading, spacing: 1) {
                Label(target.title, systemImage: "hourglass").font(.app(size: 10, weight: .semibold)).foregroundStyle(.secondary).lineLimit(1)
                if let days {
                    Text(days == 0 ? "Today 🎉" : "\(days) day\(days == 1 ? "" : "s")")
                        .font(.app(size: size == .third ? 15 : 18, weight: .bold, design: .rounded))
                    if size != .third, let d = target.nextDate(from: now) {
                        Text(CalendarService.long(d, target.calendar)).font(.app(size: 10)).foregroundStyle(.secondary).lineLimit(1)
                    }
                } else {
                    Text("Passed").font(.app(size: 14)).foregroundStyle(.secondary)
                }
            }
        }
    }
}

// MARK: - Next event

struct NextEventWidget: View {
    @ObservedObject var model: AppModel
    @ObservedObject var events: EventStore
    let size: WidgetSize

    var body: some View {
        Tile {
            let next = events.upcoming(days: 60, from: model.now).first { pair in pair.1.contains { $0.kind != .occasion } }
                ?? events.upcoming(days: 60, from: model.now).first
            if let (date, list) = next, let e = list.first {
                let days = CalendarService.daysFromToday(date, now: model.now)
                VStack(alignment: .leading, spacing: 1) {
                    Label(days == 0 ? "Today" : "In \(days) day\(days == 1 ? "" : "s")", systemImage: e.symbol)
                        .font(.app(size: 10, weight: .semibold)).foregroundStyle(e.color)
                    Text(e.title).font(.app(size: 12, weight: .medium)).lineLimit(size == .full ? 1 : 2)
                    if size == .full {
                        Text(CalendarService.long(date, .jalali)).font(.app(size: 10)).foregroundStyle(.secondary)
                    }
                }
            } else {
                Text("No upcoming events").font(.app(size: 11)).foregroundStyle(.secondary)
            }
        }
    }
}
