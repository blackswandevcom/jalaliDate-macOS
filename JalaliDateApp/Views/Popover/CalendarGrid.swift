import SwiftUI

struct CalendarGrid: View {
    @ObservedObject var model: AppModel
    @ObservedObject var events: EventStore
    let theme: ResolvedTheme
    @State private var monthOffset = 0

    private let cal = CalendarKind.jalali.calendar
    private let weekdayInitials = ["ش", "ی", "د", "س", "چ", "پ", "ج"] // Saturday first

    private var monthStart: Date {
        let comps = cal.dateComponents([.year, .month], from: model.now)
        let start = cal.date(from: comps) ?? model.now
        return cal.date(byAdding: .month, value: monthOffset, to: start) ?? start
    }

    var body: some View {
        let _ = events.revision
        let start = monthStart
        let days = cal.range(of: .day, in: .month, for: start)?.count ?? 30
        let leading = cal.component(.weekday, from: start) % 7 // Sat → 0 … Fri → 6
        let last = cal.date(byAdding: .day, value: days - 1, to: start) ?? start

        VStack(spacing: 6) {
            HStack {
                Button { monthOffset -= 1 } label: { Image(systemName: "chevron.backward") }
                    .help("Previous month")
                Spacer()
                VStack(spacing: 0) {
                    Text(CalendarService.format(start, .jalali, "MMMM yyyy", locale: Locale(identifier: "fa_IR")))
                        .font(.app(size: 13, weight: .semibold))
                    if model.settings.layout.cellGregorian || !model.settings.layout.cellHijri {
                        Text(gregorianSpan(start, last))
                            .font(.app(size: 10)).foregroundStyle(.secondary)
                            .environment(\.layoutDirection, .leftToRight)
                    }
                    if model.settings.layout.cellHijri {
                        Text(hijriSpan(start, last))
                            .font(.app(size: 10)).foregroundStyle(Color.green.opacity(0.85))
                    }
                }
                .onTapGesture { goToday() }
                Spacer()
                Button { monthOffset += 1 } label: { Image(systemName: "chevron.forward") }
                    .help("Next month")
            }
            .buttonStyle(.borderless)
            .overlay(alignment: .leading) {
                if monthOffset != 0 {
                    Button("امروز") { goToday() }
                        .buttonStyle(.borderless).font(.app(size: 11)).padding(.leading, 22)
                }
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 7), spacing: 2) {
                ForEach(0..<(7 + leading + days), id: \.self) { cell in
                    if cell < 7 {
                        Text(weekdayInitials[cell])
                            .font(.app(size: 11, weight: .medium))
                            .foregroundStyle(cell == 6 ? Color.red : Color.secondary)
                            .frame(maxWidth: .infinity)
                    } else if cell < 7 + leading {
                        Color.clear.frame(height: 20)
                    } else {
                        let i = cell - 7 - leading
                        let date = cal.date(byAdding: .day, value: i, to: start) ?? start
                        DayCell(day: i + 1, date: date,
                                isToday: cal.isDate(date, inSameDayAs: model.now),
                                isSelected: cal.isDate(date, inSameDayAs: model.selectedDay),
                                marks: events.marks(on: date), accent: theme.accent,
                                style: CellStyle(model.settings.layout)) {
                            model.selectedDay = date
                        }
                    }
                }
            }
        }
        .environment(\.layoutDirection, .rightToLeft)
        .onChange(of: model.popoverVisible) { _, visible in
            if visible { goToday() }
        }
    }

    private func goToday() {
        monthOffset = 0
        model.selectedDay = model.now
    }

    private func hijriSpan(_ first: Date, _ last: Date) -> String {
        let fa = Locale(identifier: "fa_IR")
        let a = CalendarService.format(first, .islamic, "MMMM", locale: fa)
        let b = CalendarService.format(last, .islamic, "MMMM yyyy", locale: fa)
        return a == CalendarService.format(last, .islamic, "MMMM", locale: fa) ? b : "\(a) – \(b)"
    }

    private func gregorianSpan(_ first: Date, _ last: Date) -> String {
        let a = CalendarService.format(first, .gregorian, "MMM", locale: Locale(identifier: "en_US"))
        let b = CalendarService.format(last, .gregorian, "MMM yyyy", locale: Locale(identifier: "en_US"))
        return "\(a) – \(b)"
    }
}

struct CellStyle {
    var gregorian: Bool
    var hijri: Bool
    var dayFont: CGFloat
    var secondaryFont: CGFloat
    init(_ l: PopoverLayout) {
        gregorian = l.cellGregorian; hijri = l.cellHijri
        dayFont = l.cellDayFont; secondaryFont = l.cellSecondaryFont
    }
}

private struct DayCell: View {
    let day: Int
    let date: Date
    let isToday: Bool
    let isSelected: Bool
    let marks: EventStore.Marks
    let accent: Color
    let style: CellStyle
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        let red = CalendarService.isFriday(date) || marks.holiday
        Button(action: action) {
            VStack(spacing: 0) {
                Text(CalendarService.persianDigits(day))
                    .font(.app(size: style.dayFont, weight: isToday ? .bold : .regular))
                if style.gregorian || style.hijri {
                    HStack(spacing: 3) {
                        if style.gregorian {
                            Text("\(Calendar(identifier: .gregorian).component(.day, from: date))")
                        }
                        if style.hijri {
                            Text(CalendarService.persianDigits(CalendarService.ymd(date, .islamic).day))
                                .foregroundStyle(isToday ? Color.white : Color.green)
                        }
                    }
                    .font(.app(size: style.secondaryFont))
                    .opacity(isToday ? 0.85 : 0.6)
                }
                HStack(spacing: 2) {
                    if marks.birthday { Circle().fill(isToday ? Color.white : Color.pink).frame(width: 3.5, height: 3.5) }
                    if marks.events { Circle().fill(isToday ? Color.white : accent).frame(width: 3.5, height: 3.5) }
                }
                .frame(height: 4)
            }
            .foregroundStyle(isToday ? Color.white : (red ? Color.red : Color.primary))
            .frame(maxWidth: .infinity, minHeight: style.dayFont + (style.gregorian || style.hijri ? style.secondaryFont + 12 : 10))
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(isToday ? accent : (red && marks.holiday ? Color.red.opacity(0.08) : Color.primary.opacity(hovering ? 0.08 : 0)))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .strokeBorder(isSelected && !isToday ? accent : .clear, lineWidth: 1.5)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .help(CalendarService.iso(date, .gregorian))
    }
}

// MARK: - Selected day panel (right-to-left, Persian)

/// "امروز" / "۲ روز دیگر" / "۳ روز پیش"
func persianRelative(_ diff: Int) -> String {
    diff == 0 ? "امروز" : diff == 1 ? "فردا" : diff == -1 ? "دیروز"
        : diff > 0 ? "\(CalendarService.persianDigits(diff)) روز دیگر" : "\(CalendarService.persianDigits(-diff)) روز پیش"
}

struct DayEventsPanel: View {
    @ObservedObject var model: AppModel
    @ObservedObject var events: EventStore

    var body: some View {
        let _ = events.revision
        let day = model.selectedDay
        let list = events.events(on: day)
        let diff = CalendarService.daysFromToday(day, now: model.now)

        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(CalendarService.long(day, .jalali)).font(.app(size: 13, weight: .semibold))
                    Text("\(CalendarService.format(day, .islamic, "d MMMM", locale: Locale(identifier: "fa_IR"))) · \(CalendarService.format(day, .gregorian, "EEE d MMM yyyy", locale: Locale(identifier: "en_US")))")
                        .font(.app(size: 10)).foregroundStyle(.secondary)
                }
                Spacer()
                if diff != 0 {
                    Text(persianRelative(diff)).font(.app(size: 10)).foregroundStyle(.secondary)
                }
                Button { model.openConverter(at: day) } label: { Image(systemName: "arrow.left.arrow.right") }
                    .buttonStyle(.borderless).help("Open in converter")
            }
            if list.isEmpty {
                Text(CalendarService.isFriday(day) ? "تعطیل آخر هفته" : "رویدادی ثبت نشده")
                    .font(.app(size: 11)).foregroundStyle(.tertiary)
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(list) { e in EventRow(event: e) }
                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.primary.opacity(0.04)))
        .environment(\.layoutDirection, .rightToLeft)
    }
}

struct EventRow: View {
    let event: DayEvent

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            RoundedRectangle(cornerRadius: 1.5).fill(event.color).frame(width: 3, height: 12)
            VStack(alignment: .leading, spacing: 0) {
                Text(event.title).font(.app(size: 12, weight: event.kind == .holiday ? .semibold : .regular))
                    .foregroundStyle(event.kind == .holiday ? Color.red : Color.primary)
                    .lineLimit(2)
                if let sub = event.subtitle {
                    Text(sub).font(.app(size: 9)).foregroundStyle(.secondary).lineLimit(1)
                }
            }
            Spacer(minLength: 0)
            if let t = event.time { Text(t).font(.app(size: 10).monospacedDigit()).foregroundStyle(.secondary) }
        }
    }
}

// MARK: - Upcoming

struct UpcomingList: View {
    @ObservedObject var model: AppModel
    @ObservedObject var events: EventStore

    var body: some View {
        let _ = events.revision
        let items = events.upcoming(days: 7, from: model.now)
        VStack(alignment: .leading, spacing: 6) {
            Label("۷ روز آینده", systemImage: "clock.arrow.circlepath").font(.app(size: 11, weight: .semibold)).foregroundStyle(.secondary)
            if items.isEmpty {
                Text("رویدادی در پیش نیست").font(.app(size: 11)).foregroundStyle(.tertiary)
            }
            ForEach(items, id: \.0) { date, list in
                HStack(alignment: .top, spacing: 8) {
                    VStack(spacing: 0) {
                        Text(CalendarService.persianDigits(CalendarService.ymd(date, .jalali).day)).font(.app(size: 14, weight: .bold))
                        Text(CalendarService.weekday(date, .jalali)).font(.app(size: 8)).foregroundStyle(.secondary)
                    }
                    .frame(width: 40)
                    VStack(alignment: .leading, spacing: 3) {
                        ForEach(list.prefix(3)) { EventRow(event: $0) }
                        if list.count > 3 { Text("و \(CalendarService.persianDigits(list.count - 3)) رویداد دیگر").font(.app(size: 9)).foregroundStyle(.secondary) }
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture { model.selectedDay = date }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.primary.opacity(0.04)))
        .environment(\.layoutDirection, .rightToLeft)
    }
}
