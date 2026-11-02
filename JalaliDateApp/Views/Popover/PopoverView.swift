import SwiftUI

struct PopoverView: View {
    @ObservedObject var model: AppModel
    @ObservedObject var settings: AppSettings
    @ObservedObject var events: EventStore
    @ObservedObject var weather: WeatherStore
    @State private var contentHeight: CGFloat = 500

    init(model: AppModel) {
        self.model = model
        settings = model.settings
        events = model.events
        weather = model.weather
    }

    private var maxHeight: CGFloat { (NSScreen.main?.visibleFrame.height ?? 900) - 60 }

    var body: some View {
        let layout = settings.layout
        let theme = ThemeResolver.resolve(settings.theme, date: model.now, weather: weather.themeSnapshot)

        ScrollView(.vertical) {
            VStack(spacing: 12) {
                if layout.arrangement == .sideBySide {
                    wideBody(layout, theme: theme)
                } else {
                    ForEach(layout.sections.filter(\.visible)) { cfg in
                        section(cfg.section, theme: theme)
                    }
                }
                Divider()
                PopoverFooter(model: model)
            }
            .padding(14)
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { contentHeight = $0 }
        }
        .scrollIndicators(contentHeight > maxHeight ? .automatic : .hidden)
        .frame(width: layout.effectiveWidth, height: min(contentHeight, maxHeight))
        .tint(theme.accent)
        // No blue keyboard-focus ring around the first tile when the popover opens.
        .focusEffectDisabled()
    }

    private static let sideSections: Set<PopoverSection> = [.calendar, .dayEvents, .upcoming]

    /// Wide layout: header/widgets keep their full-width rows; the calendar and the day's events
    /// (plus Upcoming) sit next to each other where the first of them appears in the order.
    @ViewBuilder
    private func wideBody(_ layout: PopoverLayout, theme: ResolvedTheme) -> some View {
        let visible = layout.sections.filter(\.visible).map(\.section)
        let firstSide = visible.firstIndex { Self.sideSections.contains($0) }
        ForEach(Array(visible.enumerated()), id: \.offset) { i, s in
            if !Self.sideSections.contains(s) {
                section(s, theme: theme)
            } else if i == firstSide {
                sideBySide(visible, layout: layout, theme: theme)
            }
        }
    }

    @ViewBuilder
    private func sideBySide(_ visible: [PopoverSection], layout: PopoverLayout, theme: ResolvedTheme) -> some View {
        let calendarWidth: CGFloat = 330
        let hasCalendar = visible.contains(.calendar)
        let list = visible.filter { $0 == .dayEvents || $0 == .upcoming }
        let calendar = CalendarGrid(model: model, events: events, theme: theme).frame(width: calendarWidth)
        let column = VStack(spacing: 12) {
            ForEach(list, id: \.self) { section($0, theme: theme) }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .top)

        HStack(alignment: .top, spacing: 14) {
            if hasCalendar && !layout.calendarOnRight { calendar; Divider() }
            if !list.isEmpty { column }
            if hasCalendar && layout.calendarOnRight { Divider(); calendar }
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder
    private func section(_ s: PopoverSection, theme: ResolvedTheme) -> some View {
        switch s {
        case .hero:
            HeroView(now: model.now, theme: theme, weather: weather, animated: settings.theme.animated && model.popoverVisible)
        case .widgets:
            if !settings.layout.widgets.isEmpty {
                WidgetGrid(model: model, width: settings.layout.effectiveWidth - 28)
            }
        case .calendar:
            CalendarGrid(model: model, events: events, theme: theme)
        case .dayEvents:
            DayEventsPanel(model: model, events: events)
        case .upcoming:
            UpcomingList(model: model, events: events)
        }
    }
}

// MARK: - Hero

struct HeroView: View {
    let now: Date
    let theme: ResolvedTheme
    @ObservedObject var weather: WeatherStore
    let animated: Bool

    var body: some View {
        let jalali = CalendarService.ymd(now, .jalali)

        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text(CalendarService.weekday(now, .gregorian))
                    .font(.app(size: 13, weight: .semibold))
                Text(CalendarService.format(now, .gregorian, "d MMMM yyyy", locale: Locale(identifier: "en_US")))
                    .font(.app(size: 12)).opacity(0.9)
                Text(CalendarService.format(now, .islamic, "d MMMM yyyy", locale: Locale(identifier: "fa_IR")))
                    .font(.app(size: 11)).opacity(0.8)
                if let w = weather.themeSnapshot, let city = weather.settings.themeCity {
                    Label("\(weather.format(w.temperature)) \(city.name)", systemImage: w.condition.symbol(isDay: w.isDay))
                        .font(.app(size: 11, weight: .medium))
                        .symbolRenderingMode(.multicolor)
                        .padding(.top, 2)
                }
            }
            Spacer(minLength: 0)
            VStack(alignment: .trailing, spacing: 0) {
                Text(CalendarService.weekday(now, .jalali))
                    .font(.app(size: 13, weight: .semibold))
                Text(CalendarService.format(now, .jalali, "MMMM yyyy", locale: Locale(identifier: "fa_IR")))
                    .font(.app(size: 12)).opacity(0.9)
                Text(theme.name).font(.app(size: 9, weight: .medium)).opacity(0.7).padding(.top, 2)
            }
            Text(CalendarService.persianDigits(jalali.day))
                .font(.app(size: 42, weight: .bold, design: .rounded))
                .frame(minWidth: 54)
        }
        .foregroundStyle(.white)
        .shadow(color: .black.opacity(0.15), radius: 2, y: 1)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background {
            ZStack {
                theme.gradient
                if let symbol = theme.symbol {
                    Image(systemName: symbol)
                        .font(.app(size: 90))
                        .foregroundStyle(.white.opacity(0.12))
                        .rotationEffect(.degrees(-12))
                        .offset(x: -60, y: 18)
                }
                if let p = theme.particle {
                    ParticleLayer(particle: p, paused: !animated)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .environment(\.layoutDirection, .leftToRight)
    }
}

/// Light-weight decorative animation (rain, snow, leaves, petals, stars, sun rays).
struct ParticleLayer: View {
    let particle: Particle
    let paused: Bool

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30, paused: paused)) { context in
            Canvas { ctx, size in
                let t = context.date.timeIntervalSinceReferenceDate
                switch particle {
                case .sun:
                    let center = CGPoint(x: size.width * 0.2, y: -10)
                    for i in 0..<10 {
                        let a = Double(i) / 10 * .pi * 2 + t * 0.15
                        var p = Path()
                        p.move(to: center)
                        p.addLine(to: CGPoint(x: center.x + cos(a) * 160, y: center.y + sin(a) * 160))
                        ctx.stroke(p, with: .color(.white.opacity(0.08)), lineWidth: 10)
                    }
                case .stars:
                    for i in 0..<22 {
                        let x = seeded(i, 1) * size.width, y = seeded(i, 2) * size.height
                        let o = 0.25 + 0.5 * (0.5 + 0.5 * sin(t * 2 + Double(i)))
                        ctx.fill(Path(ellipseIn: CGRect(x: x, y: y, width: 2, height: 2)), with: .color(.white.opacity(o)))
                    }
                default:
                    let count = particle == .rain ? 40 : 18
                    for i in 0..<count {
                        let speed = particle == .rain ? 140.0 : 18 + seeded(i, 3) * 14
                        let x0 = seeded(i, 1) * size.width
                        let y = (seeded(i, 2) * (size.height + 20) + t * speed).truncatingRemainder(dividingBy: size.height + 20) - 10
                        let sway = particle == .rain ? -y * 0.15 : sin(t + Double(i)) * 8
                        let x = x0 + sway
                        switch particle {
                        case .rain:
                            var p = Path()
                            p.move(to: CGPoint(x: x, y: y))
                            p.addLine(to: CGPoint(x: x - 2, y: y + 9))
                            ctx.stroke(p, with: .color(.white.opacity(0.35)), lineWidth: 1)
                        case .snow:
                            let s = 2 + seeded(i, 4) * 3
                            ctx.fill(Path(ellipseIn: CGRect(x: x, y: y, width: s, height: s)), with: .color(.white.opacity(0.7)))
                        case .leaves, .petals:
                            var c = ctx
                            c.translateBy(x: x, y: y)
                            c.rotate(by: .radians(t + Double(i)))
                            let color: Color = particle == .leaves ? Color(hex: "#FDE68A") : Color(hex: "#FBCFE8")
                            c.fill(Path(ellipseIn: CGRect(x: -4, y: -2, width: 8, height: 4)), with: .color(color.opacity(0.6)))
                        default: break
                        }
                    }
                }
            }
        }
        .allowsHitTesting(false)
    }

    private func seeded(_ i: Int, _ salt: Int) -> Double {
        let v = sin(Double(i * 7919 + salt * 104729)) * 43758.5453
        return v - floor(v)
    }
}

// MARK: - Footer

struct PopoverFooter: View {
    @ObservedObject var model: AppModel

    var body: some View {
        HStack(spacing: 4) {
            FooterButton(symbol: MainTab.converter.symbol, help: "Date Converter (⌘E)") { model.open(.converter) }
                .keyboardShortcut("e", modifiers: .command)
            FooterButton(symbol: MainTab.months.symbol, help: "Months table") { model.open(.months) }
            FooterButton(symbol: "doc.on.clipboard", help: "Copy version dates (⌘D)") { model.copyVersionDates() }
                .keyboardShortcut("d", modifiers: .command)
                .overlay(alignment: .topTrailing) {
                    if model.copiedKey == "version" {
                        Image(systemName: "checkmark.circle.fill").font(.app(size: 9)).foregroundStyle(.green)
                    }
                }
            FooterButton(symbol: MainTab.layout.symbol, help: "Customize popover") { model.open(.layout) }
            FooterButton(symbol: MainTab.general.symbol, help: "Settings (⌘,)") { model.open(.general) }
                .keyboardShortcut(",", modifiers: .command)
            FooterButton(symbol: MainTab.about.symbol, help: "About & changelog") { model.open(.about) }
            Spacer()
            Text("v\(AppModel.appVersion)").font(.app(.caption2)).foregroundStyle(.tertiary)
            FooterButton(symbol: "power", help: "Quit jDate (⌘Q)") { NSApp.terminate(nil) }
                .keyboardShortcut("q", modifiers: .command)
        }
    }
}

struct FooterButton: View {
    let symbol: String
    let help: String
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.app(size: 13))
                .frame(width: 28, height: 24)
                .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(Color.primary.opacity(hovering ? 0.08 : 0)))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
        .onHover { hovering = $0 }
        .help(help)
    }
}
