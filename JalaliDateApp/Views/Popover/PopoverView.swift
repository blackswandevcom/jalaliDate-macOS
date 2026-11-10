import SwiftUI

struct PopoverView: View {
    @ObservedObject var model: AppModel
    @ObservedObject var settings: AppSettings
    @ObservedObject var events: EventStore
    @ObservedObject var weather: WeatherStore
    @ObservedObject var glass = GlassSettings.shared
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
                    ForEach(shownSections(layout), id: \.self) { s in
                        section(s, theme: theme)
                    }
                }
                if settings.copy.showHints {
                    ShortcutHintBar(model: model, settings: settings)
                }
                if layout.showFooter {
                    Divider()
                    PopoverFooter(model: model)
                }
            }
            .padding(14)
            // With the button bar hidden, its shortcuts (⌘E, ⌘,, ⌘Q) keep working.
            .background {
                CopyShortcutKeys(model: model, copy: settings.copy)
                if !layout.showFooter {
                    PopoverFooter(model: model).opacity(0).frame(width: 0, height: 0).clipped().allowsHitTesting(false)
                }
            }
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { contentHeight = $0 }
        }
        .scrollIndicators(contentHeight > maxHeight ? .automatic : .hidden)
        .frame(width: layout.effectiveWidth, height: min(contentHeight, maxHeight))
        .background {
            if glass.popover.enabled {
                glass.popover.tintColor.opacity(glass.popover.opacity).ignoresSafeArea()
            }
        }
        .glassScheme(glass.popover.enabled ? glass.popover : nil)
        .tint(theme.accent)
        // No blue keyboard-focus ring around the first tile when the popover opens.
        .focusEffectDisabled()
    }

    /// Visible sections; the day's events panel steps aside when the header shows the events.
    private func shownSections(_ layout: PopoverLayout) -> [PopoverSection] {
        let inHeader = layout.isVisible(.hero) && layout.header.visible(.events)
        return layout.sections.filter(\.visible).map(\.section).filter { !(inHeader && $0 == .dayEvents) }
    }

    private static let sideSections: Set<PopoverSection> = [.calendar, .dayEvents, .upcoming]

    /// Wide layout: header/widgets keep their full-width rows; the calendar and the day's events
    /// (plus Upcoming) sit next to each other where the first of them appears in the order.
    @ViewBuilder
    private func wideBody(_ layout: PopoverLayout, theme: ResolvedTheme) -> some View {
        let visible = shownSections(layout)
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
            HeroView(date: model.selectedDay, now: model.now, theme: theme, weather: weather,
                     animated: settings.theme.animated && model.popoverVisible,
                     header: settings.layout.header,
                     events: settings.layout.header.visible(.events) ? events.events(on: model.selectedDay) : [],
                     onToday: { model.goToday() },
                     onRightClick: { model.openConverter(at: model.selectedDay) })
        case .widgets:
            if !settings.layout.widgets.isEmpty {
                WidgetGrid(model: model, width: settings.layout.effectiveWidth - 28)
            }
        case .calendar:
            CalendarGrid(model: model, events: events, theme: theme)
        case .dayEvents:
            DayEventsPanel(model: model, events: events, showsDate: !settings.layout.isVisible(.hero))
        case .upcoming:
            UpcomingList(model: model, events: events)
        }
    }
}

// MARK: - Hero

/// The coloured header. Shows the day picked in the calendar; click it to go back to today.
struct HeroView: View {
    /// The day shown (today, or the day picked in the calendar).
    let date: Date
    let now: Date
    let theme: ResolvedTheme
    @ObservedObject var weather: WeatherStore
    let animated: Bool
    var header = HeaderLayout()
    /// The day's events, shown under the dates when the header is set to show them.
    var events: [DayEvent] = []
    var onToday: (() -> Void)? = nil
    /// Right-click: open the converter on the shown day.
    var onRightClick: (() -> Void)? = nil
    @State private var hovering = false

    private var isToday: Bool { Calendar(identifier: .gregorian).isDate(date, inSameDayAs: now) }

    private func line(_ item: HeaderItem, _ text: String, weight: Font.Weight = .regular) -> some View {
        Text(text)
            .font(.app(size: header.size(item), weight: weight))
            .foregroundStyle(header.color(item))
            .lineLimit(1).minimumScaleFactor(0.6)
            .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder
    private func headerEvent(_ e: DayEvent, size: CGFloat, custom: Bool) -> some View {
        let row = HStack(spacing: 6) {
            Capsule().fill(e.kind == .holiday || custom ? header.color(.events) : e.color)
                .overlay(Capsule().strokeBorder(.white.opacity(0.6), lineWidth: 0.5))
                .frame(width: 4, height: size + 1)
            Text(e.title)
                .font(.app(size: size, weight: e.kind == .holiday ? .semibold : .medium))
                .foregroundStyle(header.color(.events))
                .lineLimit(1)
            Spacer(minLength: 0)
            if let t = e.time {
                Text(t).font(.app(size: max(8, size - 2)).monospacedDigit())
                    .foregroundStyle(header.color(.events).opacity(0.8))
            }
            if e.meetingURL != nil { MeetingIcon(color: header.color(.events)) }
        }
        .contentShape(Rectangle())
        if let url = e.meetingURL {
            Button { NSWorkspace.shared.open(url) } label: { row }
                .buttonStyle(.plain)
                .help("Join on \(MeetingLink.name(of: url))")
        } else {
            row
        }
    }

    private func eventList(_ list: [DayEvent]) -> some View {
        let size = header.size(.events)
        let custom = header.style(.events).color != nil
        return VStack(alignment: .leading, spacing: 4) {
            ForEach(list.prefix(4)) { e in
                headerEvent(e, size: size, custom: custom)
            }
            if list.count > 4 {
                Text("و \(CalendarService.persianDigits(list.count - 4)) رویداد دیگر")
                    .font(.app(size: max(8, size - 2))).foregroundStyle(header.color(.events).opacity(0.8))
            }
        }
        .padding(.horizontal, 9).padding(.vertical, 7)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(.black.opacity(0.16)))
        .environment(\.layoutDirection, .rightToLeft)
    }

    var body: some View {
        let jalali = CalendarService.ymd(date, .jalali)
        let diff = CalendarService.daysFromToday(date, now: now)
        let h = header
        let leftEmpty = !h.visible(.gregorianWeekday) && !h.visible(.gregorianDate) && !h.visible(.hijriDate)
            && !(isToday && h.visible(.weather)) && !(!isToday && h.visible(.backToToday))

        VStack(alignment: .leading, spacing: 10) {
        HStack(alignment: .center, spacing: 14) {
            if !leftEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    if h.visible(.gregorianWeekday) {
                        line(.gregorianWeekday, CalendarService.weekday(date, .gregorian), weight: .semibold)
                    }
                    if h.visible(.gregorianDate) {
                        line(.gregorianDate, CalendarService.format(date, .gregorian, "d MMMM yyyy", locale: Locale(identifier: "en_US")))
                    }
                    if h.visible(.hijriDate) {
                        line(.hijriDate, CalendarService.format(date, .islamic, "d MMMM yyyy", locale: Locale(identifier: "fa_IR")))
                    }
                    if isToday, h.visible(.weather), let w = weather.themeSnapshot, let city = weather.settings.themeCity {
                        Label("\(weather.format(w.temperature)) \(city.name)", systemImage: w.condition.symbol(isDay: w.isDay))
                            .font(.app(size: h.size(.weather), weight: .medium))
                            .foregroundStyle(h.color(.weather))
                            .symbolRenderingMode(h.style(.weather).color == nil ? .multicolor : .monochrome)
                            .lineLimit(1)
                            .padding(.top, 2)
                    } else if !isToday, h.visible(.backToToday) {
                        Label("Back to today", systemImage: "arrow.uturn.backward")
                            .font(.app(size: h.size(.backToToday), weight: .semibold))
                            .foregroundStyle(h.color(.backToToday))
                            .padding(.horizontal, 7).padding(.vertical, 2)
                            .background(Capsule().fill(.white.opacity(hovering ? 0.32 : 0.2)))
                            .padding(.top, 3)
                    }
                }
                .layoutPriority(1)
            }
            Spacer(minLength: 0)
            VStack(alignment: .trailing, spacing: 0) {
                if h.visible(.jalaliWeekday) {
                    line(.jalaliWeekday, CalendarService.weekday(date, .jalali), weight: .semibold)
                }
                if h.visible(.jalaliMonth) {
                    line(.jalaliMonth, CalendarService.format(date, .jalali, "MMMM yyyy", locale: Locale(identifier: "fa_IR")))
                }
                if h.visible(.caption) {
                    line(.caption, isToday ? theme.name : persianRelative(diff), weight: .medium)
                        .padding(.top, 2)
                }
            }
            .layoutPriority(1)
            if h.visible(.dayNumber) {
                Text(CalendarService.persianDigits(jalali.day))
                    .font(.app(size: h.size(.dayNumber), weight: .bold, design: .rounded))
                    .foregroundStyle(h.color(.dayNumber))
                    .frame(minWidth: h.size(.dayNumber) * 1.28)
                    .contentTransition(.numericText())
            }
        }
            if h.visible(.events), !events.isEmpty {
                eventList(events)
            }
        }
        .foregroundStyle(.white)
        .shadow(color: .black.opacity(0.18), radius: 2, y: 1)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background {
            ZStack {
                if let effect = theme.effect {
                    HeaderEffectView(effect: effect, paused: !animated)
                } else {
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
            }
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .onTapGesture { withAnimation(.snappy) { onToday?() } }
        .onRightClick(onRightClick)
        .onHover { hovering = $0 }
        .help((isToday ? "Today" : "Click to go back to today") + (onRightClick == nil ? "" : " · Right-click to open the date converter"))
        .animation(.snappy, value: date)
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
            FooterButton(symbol: "doc.on.clipboard", help: "Copy version dates" + (model.settings.copy.actions.first { $0.kind == .versionDates }?.popoverHint.map { " (\($0))" } ?? "")) {
                model.copyVersionDates()
            }
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

// MARK: - Copy shortcuts

/// Invisible buttons that give every copy action its ⌘-key, whether or not its tile is shown.
struct CopyShortcutKeys: View {
    @ObservedObject var model: AppModel
    let copy: CopySettings

    var body: some View {
        ZStack {
            ForEach(copy.actions.filter { !$0.popoverKey.isEmpty && copy.popoverConflict($0) == nil }) { a in
                Button("") { model.perform(a, date: model.selectedDay) }
                    .keyboardShortcut(KeyEquivalent(Character(a.popoverKey.lowercased())), modifiers: .command)
            }
        }
        .opacity(0).frame(width: 0, height: 0).clipped().allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// A small row naming the copy shortcuts that aren't already printed on a date tile.
struct ShortcutHintBar: View {
    @ObservedObject var model: AppModel
    @ObservedObject var settings: AppSettings

    var body: some View {
        let layout = settings.layout
        let tiles: Set<CalendarKind> = layout.isVisible(.widgets)
            ? Set(layout.widgets.compactMap { if case .date(let k) = $0.kind { return k } else { return nil } })
            : []
        let list = settings.copy.actions.filter { a in
            a.popoverHint != nil && settings.copy.popoverConflict(a) == nil && !(a.calendar.map(tiles.contains) ?? false)
        }
        if !list.isEmpty {
            ViewThatFits(in: .horizontal) {
                row(list)
                ScrollView(.horizontal, showsIndicators: false) { row(list) }
            }
        }
    }

    private func row(_ list: [CopyAction]) -> some View {
        HStack(spacing: 6) {
            ForEach(list) { a in
                Button { model.perform(a, date: model.selectedDay) } label: {
                    HStack(spacing: 6) {
                        KeyCap(text: a.popoverHint ?? "")
                        Text(model.copiedKey == a.copiedKey ? "Copied" : a.name)
                            .font(.app(size: 12, weight: .medium)).lineLimit(1)
                            .foregroundStyle(model.copiedKey == a.copiedKey ? AnyShapeStyle(.green) : AnyShapeStyle(.primary.opacity(0.85)))
                    }
                    .padding(.leading, 4).padding(.trailing, 10).padding(.vertical, 4)
                    .background(Capsule().fill(Color.primary.opacity(0.08)))
                }
                .buttonStyle(.plain)
                .help("Copy: \(a.text(for: model.selectedDay, format: settings.general.copyFormat))")
            }
            Spacer(minLength: 0)
        }
    }
}

/// A shortcut like ⌘C drawn as a small key.
struct KeyCap: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .foregroundStyle(.primary.opacity(0.9))
            .padding(.horizontal, 5).padding(.vertical, 1.5)
            .background(RoundedRectangle(cornerRadius: 5, style: .continuous).fill(Color.primary.opacity(0.12)))
            .overlay(RoundedRectangle(cornerRadius: 5, style: .continuous).strokeBorder(Color.primary.opacity(0.18), lineWidth: 0.5))
            .fixedSize()
    }
}
