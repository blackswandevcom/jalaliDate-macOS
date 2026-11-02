import SwiftUI

struct DateDifferenceView: View {
    @ObservedObject var model: AppModel
    @State private var start = Calendar(identifier: .gregorian).startOfDay(for: Date())
    @State private var end = CountdownTarget.nowruz.nextDate() ?? Date()
    @State private var kind: CalendarKind = .jalali
    @State private var addDays = 100

    private let g = Calendar(identifier: .gregorian)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Picker("Enter dates in", selection: $kind) {
                    ForEach(CalendarKind.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 420)

                Card {
                    VStack(alignment: .leading, spacing: 10) {
                        DateEntry(title: "From", date: $start, kind: kind)
                        DateEntry(title: "To", date: $end, kind: kind)
                        HStack {
                            Button("Swap") { (start, end) = (end, start) }
                            Button("From = today") { start = g.startOfDay(for: Date()) }
                            Button("To = today") { end = g.startOfDay(for: Date()) }
                        }
                        .controlSize(.small)
                    }
                }

                resultCard

                Card {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Add or subtract days").font(.app(.headline))
                        HStack {
                            Text("From “From” date")
                            TextField("", value: $addDays, format: .number.grouping(.never))
                                .frame(width: 80).textFieldStyle(.roundedBorder)
                            Stepper("", value: $addDays, in: -100_000...100_000).labelsHidden()
                            Text("days →")
                        }
                        let target = g.date(byAdding: .day, value: addDays, to: start) ?? start
                        ForEach(CalendarKind.allCases) { k in
                            HStack {
                                Image(systemName: k.symbol).foregroundStyle(k.tint).frame(width: 18)
                                Text(CalendarService.long(target, k))
                                Spacer()
                                Text(CalendarService.iso(target, k)).font(.system(.body, design: .monospaced)).foregroundStyle(.secondary)
                                    .textSelection(.enabled)
                            }
                        }
                    }
                }
            }
            .padding(24)
        }
    }

    private var resultCard: some View {
        let a = g.startOfDay(for: start), b = g.startOfDay(for: end)
        let days = g.dateComponents([.day], from: a, to: b).day ?? 0
        let lo = min(a, b), hi = max(a, b)
        let parts = jalaliDiff(lo, hi)
        let weeks = abs(days) / 7, rem = abs(days) % 7

        return Card {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline) {
                    Text("\(abs(days))").font(.app(size: 38, weight: .bold, design: .rounded))
                    Text(abs(days) == 1 ? "day" : "days").font(.app(.title3)).foregroundStyle(.secondary)
                    if days < 0 { Text("(backwards)").foregroundStyle(.secondary) }
                    Spacer()
                    Button {
                        model.copy("\(abs(days))", key: "diff")
                    } label: { Image(systemName: model.copiedKey == "diff" ? "checkmark" : "doc.on.doc") }
                }
                Text("\(weeks) week\(weeks == 1 ? "" : "s") and \(rem) day\(rem == 1 ? "" : "s")")
                Text("\(parts.y) years, \(parts.m) months, \(parts.d) days (Jalali)")
                Text(CalendarService.persianDigits("\(parts.y) سال، \(parts.m) ماه و \(parts.d) روز"))
                    .environment(\.layoutDirection, .rightToLeft)
                    .foregroundStyle(.secondary)
                Text("≈ \(String(format: "%.1f", Double(abs(days)) / 30.44)) months · \(abs(days) * 24) hours")
                    .font(.app(.caption)).foregroundStyle(.secondary)
            }
        }
    }

    private func jalaliDiff(_ lo: Date, _ hi: Date) -> (y: Int, m: Int, d: Int) {
        let c = CalendarKind.jalali.calendar.dateComponents([.year, .month, .day], from: lo, to: hi)
        return (c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }
}

/// Year / month / day entry for one date in a chosen calendar.
struct DateEntry: View {
    let title: String
    @Binding var date: Date
    let kind: CalendarKind

    var body: some View {
        let p = CalendarService.ymd(date, kind)
        HStack(spacing: 8) {
            Text(title).frame(width: 40, alignment: .leading).foregroundStyle(.secondary)
            TextField("", value: Binding(get: { p.year }, set: { set($0, p.month, p.day) }), format: .number.grouping(.never))
                .frame(width: 64).textFieldStyle(.roundedBorder)
            Picker("", selection: Binding(get: { p.month }, set: { set(p.year, $0, p.day) })) {
                ForEach(1...12, id: \.self) { Text("\($0) · \(kind.monthNames[$0 - 1])").tag($0) }
            }
            .labelsHidden().frame(width: 150)
            TextField("", value: Binding(get: { p.day }, set: { set(p.year, p.month, $0) }), format: .number)
                .frame(width: 44).textFieldStyle(.roundedBorder)
            Stepper("", onIncrement: { shift(1) }, onDecrement: { shift(-1) }).labelsHidden()
            Spacer()
            Text(CalendarService.long(date, .jalali)).foregroundStyle(.secondary)
            Text(CalendarService.iso(date, .gregorian)).font(.system(.caption, design: .monospaced)).foregroundStyle(.secondary)
        }
    }

    private func shift(_ n: Int) {
        date = Calendar(identifier: .gregorian).date(byAdding: .day, value: n, to: date) ?? date
    }

    private func set(_ y: Int, _ m: Int, _ d: Int) {
        if let nd = CalendarService.date(year: y, month: m, day: d, kind) { date = nd }
    }
}
