import SwiftUI

// MARK: - Index

/// Finds birthdays on a day quickly: birthdays are grouped by calendar and month once,
/// so a whole year needs only three date conversions per day.
/// The birthdays on one day.
struct BirthdayDay: Identifiable {
    let date: Date
    let people: [Birthday]
    var id: Date { date }
}

struct BirthdayIndex {
    private var byMonth: [String: [Birthday]] = [:]

    init(_ list: [Birthday]) {
        for b in list { byMonth["\(b.calendar.rawValue)-\(b.month)", default: []].append(b) }
    }

    var isEmpty: Bool { byMonth.isEmpty }

    func on(_ date: Date) -> [Birthday] {
        guard !byMonth.isEmpty else { return [] }
        var out: [Birthday] = []
        for kind in CalendarKind.allCases {
            let p = CalendarService.ymd(date, kind)
            guard let list = byMonth["\(kind.rawValue)-\(p.month)"] else { continue }
            let last = CalendarService.daysInMonth(year: p.year, month: p.month, kind)
            // 30 Esfand / 29 Feb in a short year: celebrate on the month's last day.
            out += list.filter { $0.day == p.day || ($0.day > last && p.day == last) }
        }
        return out.sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
    }

    /// Every day with a birthday in the next `days` days, starting today.
    func upcoming(from start: Date, days: Int) -> [BirthdayDay] {
        let g = Calendar(identifier: .gregorian)
        let today = g.startOfDay(for: start)
        return (0..<days).compactMap { offset in
            guard let d = g.date(byAdding: .day, value: offset, to: today) else { return nil }
            let list = on(d)
            return list.isEmpty ? nil : BirthdayDay(date: d, people: list)
        }
    }
}

// MARK: - Avatar

struct BirthdayAvatar: View {
    let name: String
    var size: CGFloat = 32

    private static let palettes: [[Color]] = [
        [.pink, .orange], [.purple, .pink], [.blue, .teal], [.orange, .yellow],
        [.indigo, .purple], [.teal, .green], [.red, .pink], [.mint, .cyan],
    ]

    private var initials: String {
        let parts = name.split(separator: " ").prefix(2)
        let s = parts.compactMap(\.first).map(String.init).joined()
        return s.isEmpty ? "🎂" : s.uppercased()
    }

    var body: some View {
        let hash = name.unicodeScalars.reduce(0) { ($0 &* 31 &+ Int($1.value)) & 0xFFFF }
        let colors = Self.palettes[hash % Self.palettes.count]
        Circle()
            .fill(LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing))
            .frame(width: size, height: size)
            .overlay(Text(initials).font(.app(size: size * 0.38, weight: .bold)).foregroundStyle(.white))
    }
}

// MARK: - Details of one day

struct BirthdayDayDetail: View {
    @ObservedObject var store: BirthdayStore
    let date: Date
    let people: [Birthday]
    var onAdd: (Date) -> Void
    var onEdit: (Birthday) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(CalendarService.long(date, .jalali)).font(.app(size: 14, weight: .semibold))
                    .environment(\.layoutDirection, .rightToLeft)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                Text(CalendarService.format(date, .gregorian, "EEEE d MMMM yyyy", locale: Locale(identifier: "en_US")))
                    .font(.app(.caption)).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            if people.isEmpty {
                Text("No birthdays on this day.").font(.app(.callout)).foregroundStyle(.secondary)
            }
            ForEach(people) { b in
                HStack(spacing: 10) {
                    BirthdayAvatar(name: b.name, size: 34)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(b.name).font(.app(size: 13, weight: .semibold))
                        Text(subtitle(b)).font(.app(.caption)).foregroundStyle(.secondary)
                        if !b.note.isEmpty { Text(b.note).font(.app(.caption)).foregroundStyle(.tertiary) }
                    }
                    Spacer(minLength: 0)
                    if b.source == .manual {
                        Button { onEdit(b) } label: { Image(systemName: "pencil") }
                            .buttonStyle(.borderless).help("Edit")
                    } else {
                        Image(systemName: "person.crop.circle").foregroundStyle(.secondary).help("From Contacts")
                    }
                }
            }
            Divider()
            Button { onAdd(date) } label: { Label("Add a birthday on this day", systemImage: "plus.circle") }
                .buttonStyle(.borderless)
        }
        .padding(14)
        .frame(width: 290)
    }

    private func subtitle(_ b: Birthday) -> String {
        let age = store.age(of: b, on: date).map { "turns \($0) · " } ?? ""
        return age + b.dateText
    }
}

// MARK: - Year calendar

struct BirthdayYearView: View {
    @ObservedObject var store: BirthdayStore
    var onAdd: (Date) -> Void
    var onEdit: (Birthday) -> Void
    @State private var year = CalendarService.ymd(Date(), .jalali).year
    @State private var picked: Date?

    private let cal = CalendarKind.jalali.calendar
    private let weekdayInitials = ["ش", "ی", "د", "س", "چ", "پ", "ج"]

    var body: some View {
        let index = BirthdayIndex(store.all)
        let months = (1...12).map { month(index, $0) }
        let total = months.reduce(0) { $0 + $1.days.reduce(0) { $0 + $1.people.count } }

        ScrollView {
            VStack(spacing: 14) {
                HStack(spacing: 10) {
                    Button { year -= 1 } label: { Image(systemName: "chevron.backward") }.help("Previous year")
                    VStack(spacing: 0) {
                        Text("سال \(CalendarService.persianDigits(year))").font(.app(size: 18, weight: .bold))
                        Text(gregorianSpan).font(.app(.caption)).foregroundStyle(.secondary)
                    }
                    Button { year += 1 } label: { Image(systemName: "chevron.forward") }.help("Next year")
                    Spacer()
                    if year != CalendarService.ymd(Date(), .jalali).year {
                        Button("امسال") { year = CalendarService.ymd(Date(), .jalali).year }
                    }
                    Label("\(CalendarService.persianDigits(total)) تولد", systemImage: "gift.fill")
                        .font(.app(size: 12, weight: .semibold)).foregroundStyle(.pink)
                }
                .buttonStyle(.borderless)

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 196), spacing: 14)], spacing: 14) {
                    ForEach(months, id: \.month) { m in monthCard(m) }
                }
            }
            .padding(18)
        }
        .environment(\.layoutDirection, .rightToLeft)
    }

    private struct Month {
        let month: Int
        let leading: Int
        let days: [BirthdayDay]
    }

    private func month(_ index: BirthdayIndex, _ m: Int) -> Month {
        guard let start = CalendarService.date(year: year, month: m, day: 1, .jalali) else { return Month(month: m, leading: 0, days: []) }
        let count = CalendarService.daysInMonth(year: year, month: m, .jalali)
        let leading = cal.component(.weekday, from: start) % 7 // Sat → 0
        let g = Calendar(identifier: .gregorian)
        let days = (0..<count).map { i -> BirthdayDay in
            let d = g.date(byAdding: .day, value: i, to: start) ?? start
            return BirthdayDay(date: d, people: index.on(d))
        }
        return Month(month: m, leading: leading, days: days)
    }

    private var gregorianSpan: String {
        guard let a = CalendarService.date(year: year, month: 1, day: 1, .jalali) else { return "" }
        let y = Calendar(identifier: .gregorian).component(.year, from: a)
        return "\(y) – \(y + 1)"
    }

    private func monthCard(_ m: Month) -> some View {
        let today = Date()
        let now = CalendarService.ymd(today, .jalali)
        let isCurrent = now.year == year && now.month == m.month
        let count = m.days.reduce(0) { $0 + $1.people.count }
        let first = m.days.first?.date ?? today, last = m.days.last?.date ?? today
        let en = Locale(identifier: "en_US")

        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(CalendarKind.jalali.monthNames[m.month - 1]).font(.app(size: 14, weight: .bold))
                Spacer()
                if count > 0 {
                    Label(CalendarService.persianDigits(count), systemImage: "gift.fill")
                        .font(.app(size: 11, weight: .semibold)).foregroundStyle(.pink)
                }
            }
            Text("\(CalendarService.format(first, .gregorian, "MMM", locale: en)) – \(CalendarService.format(last, .gregorian, "MMM", locale: en))")
                .font(.app(size: 10)).foregroundStyle(.secondary)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 7), spacing: 3) {
                // Weekday row, then always six weeks so every month card has the same height.
                ForEach(0..<49, id: \.self) { cell in
                    if cell < 7 {
                        Text(weekdayInitials[cell]).font(.app(size: 9, weight: .medium))
                            .foregroundStyle(DayColors.isWeekend(weekday: DayColors.weekday(column: cell, jalali: true)) ? DayColors.weekend : Color.secondary)
                    } else if case let i = cell - 7 - m.leading, i >= 0, i < m.days.count {
                        dayCell(i + 1, m.days[i].date, m.days[i].people)
                    } else {
                        Color.clear.frame(height: 22)
                    }
                }
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.primary.opacity(0.04)))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
            .strokeBorder(isCurrent ? Color.accentColor.opacity(0.6) : Color.primary.opacity(0.06), lineWidth: isCurrent ? 1.5 : 1))
    }

    private func dayCell(_ day: Int, _ date: Date, _ people: [Birthday]) -> some View {
        let g = Calendar(identifier: .gregorian)
        let isToday = g.isDate(date, inSameDayAs: Date())
        let has = !people.isEmpty
        let isPicked = picked.map { g.isDate($0, inSameDayAs: date) } ?? false

        return Button { picked = date } label: {
            Text(CalendarService.persianDigits(day))
                .font(.app(size: 11, weight: has || isToday ? .bold : .regular))
                .foregroundStyle(has ? Color.white : (DayColors.isWeekend(date) ? DayColors.weekend : Color.primary))
                .frame(width: 22, height: 22)
                .background {
                    if has {
                        Circle().fill(LinearGradient(colors: [.pink, .orange], startPoint: .topLeading, endPoint: .bottomTrailing))
                    }
                }
                .overlay {
                    if isToday { Circle().strokeBorder(Color.accentColor, lineWidth: 1.5).padding(-2) }
                }
                .overlay(alignment: .topLeading) {
                    if people.count > 1 {
                        Text(CalendarService.persianDigits(people.count))
                            .font(.app(size: 7, weight: .bold)).foregroundStyle(.white)
                            .padding(2).background(Circle().fill(Color.purple))
                            .offset(x: -4, y: -4)
                    }
                }
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(has ? people.map(\.name).joined(separator: ", ") : CalendarService.format(date, .gregorian, "d MMM yyyy", locale: Locale(identifier: "en_US")))
        .popover(isPresented: Binding(get: { isPicked }, set: { if !$0 { picked = nil } }), arrowEdge: .bottom) {
            BirthdayDayDetail(store: store, date: date, people: people,
                              onAdd: { picked = nil; onAdd($0) },
                              onEdit: { picked = nil; onEdit($0) })
                .environment(\.layoutDirection, .leftToRight)
        }
    }
}

// MARK: - Timeline

struct BirthdayTimelineView: View {
    @ObservedObject var store: BirthdayStore
    var onEdit: (Birthday) -> Void
    @State private var picked: String?

    private struct Group: Identifiable {
        let id: String
        let year: Int, month: Int
        var entries: [BirthdayDay]
    }

    var body: some View {
        let entries = BirthdayIndex(store.all).upcoming(from: Date(), days: 366)
        let groups = grouped(entries)

        if entries.isEmpty {
            ContentUnavailableView("No birthdays yet", systemImage: "gift",
                                   description: Text("Add birthdays in the List tab, or include them from Contacts."))
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
                    ForEach(groups) { group in
                        Section {
                            ForEach(group.entries) { e in
                                row(e.date, e.people)
                            }
                        } header: {
                            monthHeader(group)
                        }
                    }
                }
                .padding(.horizontal, 18).padding(.bottom, 18)
            }
        }
    }

    private func grouped(_ entries: [BirthdayDay]) -> [Group] {
        var out: [Group] = []
        for e in entries {
            let p = CalendarService.ymd(e.date, .jalali)
            let id = "\(p.year)-\(p.month)"
            if out.last?.id == id { out[out.count - 1].entries.append(e) }
            else { out.append(Group(id: id, year: p.year, month: p.month, entries: [e])) }
        }
        return out
    }

    private func monthHeader(_ g: Group) -> some View {
        let count = g.entries.reduce(0) { $0 + $1.people.count }
        let first = g.entries.first!.date
        return HStack(alignment: .firstTextBaseline) {
            Text("\(CalendarKind.jalali.monthNames[g.month - 1]) \(CalendarService.persianDigits(g.year))")
                .font(.app(size: 15, weight: .bold))
            Text(CalendarService.format(first, .gregorian, "MMMM yyyy", locale: Locale(identifier: "en_US")))
                .font(.app(.caption)).foregroundStyle(.secondary)
            Spacer()
            Text("\(count) birthday\(count == 1 ? "" : "s")").font(.app(.caption)).foregroundStyle(.secondary)
        }
        .padding(.vertical, 8)
        .padding(.top, 8)
        .background(.bar)
    }

    private func row(_ date: Date, _ people: [Birthday]) -> some View {
        let days = CalendarService.daysFromToday(date)
        let soon = days <= 7
        return HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 0) {
                Text(CalendarService.persianDigits(CalendarService.ymd(date, .jalali).day))
                    .font(.app(size: 22, weight: .bold, design: .rounded))
                Text(CalendarService.weekday(date, .jalali)).font(.app(size: 10)).foregroundStyle(.secondary)
                Text(CalendarService.format(date, .gregorian, "MMM d", locale: Locale(identifier: "en_US")))
                    .font(.app(size: 9)).foregroundStyle(.tertiary)
            }
            .frame(width: 58)
            .padding(.top, 6)

            VStack(spacing: 0) {
                Circle().fill(soon ? Color.pink : Color.secondary.opacity(0.5)).frame(width: 10, height: 10).padding(.top, 14)
                Rectangle().fill(Color.secondary.opacity(0.2)).frame(width: 2)
            }

            VStack(spacing: 6) {
                ForEach(people) { b in card(b, date: date, days: days) }
            }
            .padding(.bottom, 10)
        }
    }

    private func card(_ b: Birthday, date: Date, days: Int) -> some View {
        let today = days == 0
        let age = store.age(of: b, on: date)
        return HStack(spacing: 12) {
            BirthdayAvatar(name: b.name, size: 38)
            VStack(alignment: .leading, spacing: 2) {
                Text(b.name).font(.app(size: 14, weight: .semibold))
                Text((age.map { "turns \($0) · " } ?? "") + b.dateText + (b.note.isEmpty ? "" : " · \(b.note)"))
                    .font(.app(.caption)).foregroundStyle(today ? Color.white.opacity(0.85) : Color.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            Text(today ? "Today 🎉" : days == 1 ? "Tomorrow" : "in \(days) days")
                .font(.app(size: 11, weight: .semibold))
                .padding(.horizontal, 9).padding(.vertical, 4)
                .background(Capsule().fill(today ? Color.white.opacity(0.25) : (days <= 7 ? Color.pink.opacity(0.15) : Color.primary.opacity(0.06))))
                .foregroundStyle(today ? Color.white : (days <= 7 ? Color.pink : Color.secondary))
            if b.source == .manual {
                Button { onEdit(b) } label: { Image(systemName: "pencil") }
                    .buttonStyle(.borderless).help("Edit")
            }
        }
        .foregroundStyle(today ? Color.white : Color.primary)
        .padding(10)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(today ? AnyShapeStyle(LinearGradient(colors: [.pink, .orange], startPoint: .leading, endPoint: .trailing))
                            : AnyShapeStyle(Color.primary.opacity(0.045)))
        }
    }
}
