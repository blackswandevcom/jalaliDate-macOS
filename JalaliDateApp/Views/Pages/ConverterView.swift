import SwiftUI

struct ConverterView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        let date = model.converterDate

        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                summary(date)

                ForEach(CalendarKind.allCases) { kind in
                    ConverterRow(kind: kind, date: $model.converterDate, model: model)
                }

                ConverterCopyCard(model: model, settings: model.settings, date: date)

                HStack(spacing: 8) {
                    Button { shift(-1) } label: { Label("Previous day", systemImage: "chevron.left") }
                        .keyboardShortcut(.leftArrow, modifiers: .command)
                    Button { model.converterDate = Date() } label: { Label("Today", systemImage: "calendar.circle") }
                        .keyboardShortcut("t", modifiers: .command)
                    Button { shift(1) } label: { Label("Next day", systemImage: "chevron.right") }
                        .keyboardShortcut(.rightArrow, modifiers: .command)
                    Spacer()
                    Text("Type a value and press Return, or use the arrows.")
                        .font(.app(.caption))
                        .foregroundStyle(.secondary)
                }
                .controlSize(.large)
            }
            .padding(24)
        }
    }

    private func shift(_ days: Int) {
        model.converterDate = Calendar(identifier: .gregorian).date(byAdding: .day, value: days, to: model.converterDate) ?? model.converterDate
    }

    private func summary(_ date: Date) -> some View {
        let diff = CalendarService.daysFromToday(date)
        let relative: String = diff == 0 ? "Today"
            : diff > 0 ? "In \(diff) day\(diff == 1 ? "" : "s")"
            : "\(-diff) day\(diff == -1 ? "" : "s") ago"

        return HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(CalendarService.long(date, .jalali))
                    .font(.app(size: 22, weight: .bold))
                Text("\(CalendarService.weekday(date, .gregorian)) · \(CalendarService.weekday(date, .islamic)) · \(CalendarService.weekday(date, .jalali))")
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(relative)
                .font(.app(size: 12, weight: .semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Capsule().fill(diff == 0 ? Color.orange.opacity(0.2) : Color.primary.opacity(0.07)))
                .foregroundStyle(diff == 0 ? Color.orange : Color.secondary)
        }
        .padding(.bottom, 4)
    }
}

private struct ConverterRow: View {
    let kind: CalendarKind
    @Binding var date: Date
    @ObservedObject var model: AppModel

    private var parts: (year: Int, month: Int, day: Int) { CalendarService.ymd(date, kind) }

    private func set(year: Int? = nil, month: Int? = nil, day: Int? = nil) {
        let p = parts
        if let d = CalendarService.date(year: year ?? p.year, month: month ?? p.month, day: day ?? p.day, kind) {
            date = d
        }
    }

    /// Sets the day counting from the 1st of the current month, so 31 in a 30-day month is the next month's 1st.
    private func setDay(_ n: Int) {
        let p = parts
        guard let first = CalendarService.date(year: p.year, month: p.month, day: 1, kind) else { return }
        let offset = min(max(n, -3650), 3650) - 1
        date = Calendar(identifier: .gregorian).date(byAdding: .day, value: offset, to: first) ?? date
    }

    var body: some View {
        let p = parts
        let maxDay = CalendarService.daysInMonth(year: p.year, month: p.month, kind)
        let key = "conv-\(kind.rawValue)"
        let copied = model.copiedKey == key

        Card {
            HStack(spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: kind.symbol).foregroundStyle(kind.tint).font(.app(size: 20))
                    VStack(alignment: .leading, spacing: 1) {
                        Text(kind.title).font(.app(size: 13, weight: .semibold))
                        Text(CalendarService.iso(date, kind))
                            .font(.app(size: 12, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                }
                .frame(width: 160, alignment: .leading)

                field(value: p.year, width: 62, range: 1...9999) { set(year: $0) }

                Picker("Month", selection: Binding(get: { p.month }, set: { set(month: $0) })) {
                    ForEach(1...12, id: \.self) { m in
                        Text("\(m) · \(kind.monthNames[m - 1])").tag(m)
                    }
                }
                .labelsHidden()
                .frame(width: 150)

                // Day rolls over: past the last day → next month's 1st, below 1 → previous month's last day.
                field(value: p.day, width: 40, range: 0...(maxDay + 1), clampText: false) { setDay($0) }

                Spacer(minLength: 8)

                Button {
                    model.copyDate(date, kind, key: key)
                } label: {
                    Image(systemName: copied ? "checkmark" : "doc.on.doc")
                        .frame(width: 16)
                        .foregroundStyle(copied ? Color.green : Color.primary)
                }
                .help("Copy \(kind.title) date")
            }
        }
    }

    private func field(value: Int, width: CGFloat, range: ClosedRange<Int>, clampText: Bool = true, commit: @escaping (Int) -> Void) -> some View {
        HStack(spacing: 2) {
            TextField("", value: Binding(get: { value }, set: { commit(clampText ? min(max($0, range.lowerBound), range.upperBound) : $0) }),
                      format: .number.grouping(.never))
                .multilineTextAlignment(.center)
                .frame(width: width)
                .textFieldStyle(.roundedBorder)
            Stepper("", value: Binding(get: { value }, set: { commit($0) }), in: range)
                .labelsHidden()
        }
    }
}

/// The other copy actions (version dates and the user's custom formats) for the converter's date.
struct ConverterCopyCard: View {
    @ObservedObject var model: AppModel
    @ObservedObject var settings: AppSettings
    let date: Date

    private var actions: [CopyAction] {
        settings.copy.actions.filter { $0.kind == .versionDates || $0.kind == .custom }
    }

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Copy this date").font(.app(size: 13, weight: .semibold))
                    Spacer()
                    Button("Add a format…") { model.open(.shortcuts) }
                        .buttonStyle(.link)
                        .font(.app(.caption))
                }
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 230), spacing: 8)], alignment: .leading, spacing: 8) {
                    ForEach(actions) { action in
                        button(action)
                    }
                }
            }
        }
    }

    private func button(_ action: CopyAction) -> some View {
        let key = "conv-\(action.copiedKey)"
        let copied = model.copiedKey == key
        let text = action.text(for: date, format: settings.general.copyFormat)
        return Button {
            model.copy(text, key: key)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: copied ? "checkmark" : action.symbol)
                    .foregroundStyle(copied ? Color.green : Color.accentColor)
                    .frame(width: 18)
                VStack(alignment: .leading, spacing: 1) {
                    Text(action.name.isEmpty ? "Custom format" : action.name)
                        .font(.app(size: 12, weight: .medium))
                        .lineLimit(1)
                    Text(text)
                        .font(.app(size: 12, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(1).truncationMode(.middle)
                }
                Spacer(minLength: 0)
                Image(systemName: "doc.on.doc").foregroundStyle(.secondary).font(.app(size: 11))
            }
            .padding(.horizontal, 10).padding(.vertical, 7)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color.primary.opacity(0.05)))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("Copy “\(text)”")
    }
}
