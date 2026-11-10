import AppIntents
import AppKit
import SwiftUI

// Actions for Spotlight (⌘Space), the Shortcuts app and Siri.

enum IntentCalendar: String, AppEnum {
    case jalali, gregorian, hijri

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Calendar"
    static var caseDisplayRepresentations: [IntentCalendar: DisplayRepresentation] = [
        .jalali: DisplayRepresentation(title: "Jalali", subtitle: "Shamsi · شمسی"),
        .gregorian: DisplayRepresentation(title: "Gregorian", subtitle: "Miladi · میلادی"),
        .hijri: DisplayRepresentation(title: "Hijri", subtitle: "Ghamari · قمری"),
    ]

    var kind: CalendarKind {
        switch self {
        case .jalali: return .jalali
        case .gregorian: return .gregorian
        case .hijri: return .islamic
        }
    }
}

enum IntentInputCalendar: String, AppEnum {
    case automatic, jalali, gregorian, hijri

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Date Is In"
    static var caseDisplayRepresentations: [IntentInputCalendar: DisplayRepresentation] = [
        .automatic: DisplayRepresentation(title: "Automatic", subtitle: "Years from 1700 are Gregorian, earlier ones Jalali"),
        .jalali: "Jalali",
        .gregorian: "Gregorian",
        .hijri: "Hijri",
    ]

    var kind: CalendarKind? {
        switch self {
        case .automatic: return nil
        case .jalali: return .jalali
        case .gregorian: return .gregorian
        case .hijri: return .islamic
        }
    }
}

struct DateNotUnderstood: Error, CustomLocalizedStringResourceConvertible {
    let text: String
    var localizedStringResource: LocalizedStringResource {
        "jDate couldn't read “\(text)” as a date. Try 1405/08/19, 2026-11-10, 19 آبان, 10 Nov, tomorrow or +10."
    }
}

enum IntentSupport {
    static func date(_ text: String?, _ input: IntentInputCalendar) throws -> DateParser.Result {
        let t = text ?? ""
        guard let r = DateParser.parse(t, calendar: input.kind) else { throw DateNotUnderstood(text: t) }
        return r
    }

    @MainActor
    static func copy(_ text: String, key: String) {
        if let model = AppModel.current {
            model.copy(text, key: key)
        } else {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(text, forType: .string)
        }
    }

    /// One line per calendar: "سه‌شنبه ۱۹ آبان ۱۴۰۵ · 1405-08-19".
    static func lines(_ date: Date) -> [(CalendarKind, String, String)] {
        CalendarKind.allCases.map { k in
            let y = CalendarService.ymd(date, k).year
            let year = k == .gregorian ? "\(y)" : CalendarService.persianDigits(y)
            return (k, "\(CalendarService.long(date, k)) \(year)", CalendarService.iso(date, k))
        }
    }
}

// MARK: - Copy Date

struct CopyDateIntent: AppIntent {
    static var title: LocalizedStringResource = "Copy Date"
    static var description = IntentDescription(
        "Copies a date in the Jalali, Gregorian or Hijri calendar. Leave the date empty for today, or type one: 1405/08/19, tomorrow, +10, 3 weeks ago.",
        categoryName: "Dates", searchKeywords: ["jalali", "shamsi", "persian", "date", "copy", "تاریخ", "شمسی", "کپی"])

    @Parameter(title: "Calendar", default: .jalali)
    var calendar: IntentCalendar

    @Parameter(title: "Date", description: "Empty for today. 1405/08/19, 2026-11-10, tomorrow, +10, 3 weeks ago…",
               inputOptions: String.IntentInputOptions(keyboardType: .default, capitalizationType: .none, autocorrect: false))
    var date: String?

    @Parameter(title: "Date Is In", default: .automatic)
    var input: IntentInputCalendar

    static var parameterSummary: some ParameterSummary {
        Summary("Copy the \(\.$calendar) date of \(\.$date)") { \.$input }
    }

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let d = try IntentSupport.date(date, input)
        let text = AppSettings.shared.general.copyFormat.string(d.date, calendar.kind)
        IntentSupport.copy(text, key: "date-\(calendar.kind.rawValue)")
        return .result(value: text, dialog: "Copied \(text)")
    }
}

// MARK: - Copy in one of the user's formats

struct CopyFormatEntity: AppEntity {
    let id: String
    let name: String
    let example: String

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Copy Format"
    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)", subtitle: "\(example)")
    }
    static var defaultQuery = CopyFormatQuery()

    @MainActor
    init(_ a: CopyAction) {
        id = a.id
        name = a.name
        example = a.text(for: Date(), format: AppSettings.shared.general.copyFormat)
    }
}

struct CopyFormatQuery: EntityQuery {
    @MainActor
    func entities(for identifiers: [String]) async throws -> [CopyFormatEntity] {
        AppSettings.shared.copy.actions.filter { identifiers.contains($0.id) }.map(CopyFormatEntity.init)
    }

    @MainActor
    func suggestedEntities() async throws -> [CopyFormatEntity] {
        AppSettings.shared.copy.actions.map(CopyFormatEntity.init)
    }
}

struct CopyFormattedDateIntent: AppIntent {
    static var title: LocalizedStringResource = "Copy Date in Format"
    static var description = IntentDescription(
        "Copies a date in one of the formats from jDate › Copy & Shortcuts, including your own custom formats.",
        categoryName: "Dates", searchKeywords: ["format", "custom", "copy", "date", "تاریخ"])

    @Parameter(title: "Format")
    var format: CopyFormatEntity

    @Parameter(title: "Date", description: "Empty for today.",
               inputOptions: String.IntentInputOptions(keyboardType: .default, capitalizationType: .none, autocorrect: false))
    var date: String?

    @Parameter(title: "Date Is In", default: .automatic)
    var input: IntentInputCalendar

    static var parameterSummary: some ParameterSummary {
        Summary("Copy \(\.$format) for \(\.$date)") { \.$input }
    }

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let d = try IntentSupport.date(date, input)
        guard let action = AppSettings.shared.copy.actions.first(where: { $0.id == format.id }) else {
            throw DateNotUnderstood(text: format.name)
        }
        let text = action.text(for: d.date, format: AppSettings.shared.general.copyFormat)
        IntentSupport.copy(text, key: action.copiedKey)
        return .result(value: text, dialog: "Copied \(text)")
    }
}

// MARK: - Convert

/// Target of "Convert … to …". Automatic flips between Jalali and Gregorian.
enum IntentTargetCalendar: String, AppEnum {
    case automatic, jalali, gregorian, hijri

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Calendar"
    static var caseDisplayRepresentations: [IntentTargetCalendar: DisplayRepresentation] = [
        .automatic: DisplayRepresentation(title: "Jalali or Gregorian", subtitle: "Jalali dates become Gregorian, the rest Jalali"),
        .jalali: DisplayRepresentation(title: "Jalali", subtitle: "Persian · شمسی"),
        .gregorian: DisplayRepresentation(title: "Gregorian", subtitle: "میلادی"),
        .hijri: DisplayRepresentation(title: "Hijri", subtitle: "قمری"),
    ]

    func kind(from source: CalendarKind?) -> CalendarKind {
        switch self {
        case .automatic: return source == .jalali ? .gregorian : .jalali
        case .jalali: return .jalali
        case .gregorian: return .gregorian
        case .hijri: return .islamic
        }
    }
}

struct ConvertDateIntent: AppIntent {
    static var title: LocalizedStringResource = "Convert Date"
    static var description = IntentDescription(
        "Converts a date between the Jalali (Persian), Gregorian and Hijri calendars and copies the result. Type 1405/02/24, 2026-11-10, 19 آبان 1405, 10 Nov or tomorrow.",
        categoryName: "Dates", searchKeywords: ["convert", "jalali", "persian", "gregorian", "hijri", "shamsi", "miladi", "تبدیل", "تاریخ"])

    @Parameter(title: "Date",
               inputOptions: String.IntentInputOptions(keyboardType: .default, capitalizationType: .none, autocorrect: false),
               requestValueDialog: IntentDialog("Which date? 1405/02/24, 2026-11-10, 19 آبان…"))
    var date: String

    @Parameter(title: "Calendar", default: .automatic)
    var to: IntentTargetCalendar

    @Parameter(title: "Date Is In", default: .automatic)
    var input: IntentInputCalendar

    @Parameter(title: "Copy Result", default: true)
    var copyResult: Bool

    static var parameterSummary: some ParameterSummary {
        Summary("Convert \(\.$date) to \(\.$to)") {
            \.$input
            \.$copyResult
        }
    }

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog & ShowsSnippetView {
        let d = try IntentSupport.date(date, input)
        let target = to.kind(from: d.calendar)
        let result = AppSettings.shared.general.copyFormat.string(d.date, target)
        let long = IntentSupport.lines(d.date).first { $0.0 == target }?.1 ?? result
        if copyResult { IntentSupport.copy(result, key: "date-\(target.rawValue)") }
        let dist = DateParser.distance(to: d.date)
        return .result(value: result,
                       dialog: IntentDialog(stringLiteral: "\(result) · \(long)" + (copyResult ? " (copied)" : "")),
                       view: DateSnippet(date: d.date, headline: result, detail: dist.text + (dist.detail.isEmpty ? "" : " · \(dist.detail)"),
                                         highlight: target))
    }
}

// MARK: - Days between

struct DaysUntilIntent: AppIntent {
    static var title: LocalizedStringResource = "Days Until Date"
    static var description = IntentDescription(
        "How many days, weeks and months there are between today and a date, in the future or the past.",
        categoryName: "Dates", searchKeywords: ["days", "until", "since", "between", "difference", "countdown", "چند روز", "فاصله"])

    @Parameter(title: "Date",
               inputOptions: String.IntentInputOptions(keyboardType: .default, capitalizationType: .none, autocorrect: false),
               requestValueDialog: IntentDialog("Which date? 1406/01/01, 2027-01-01, 29 اسفند…"))
    var date: String

    @Parameter(title: "Date Is In", default: .automatic)
    var input: IntentInputCalendar

    static var parameterSummary: some ParameterSummary {
        Summary("Days between today and \(\.$date)") { \.$input }
    }

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<Int> & ProvidesDialog & ShowsSnippetView {
        let d = try IntentSupport.date(date, input)
        let dist = DateParser.distance(to: d.date)
        let line = "\(dist.text)" + (dist.detail.isEmpty ? "" : " (\(dist.detail))")
        return .result(value: dist.days, dialog: "\(line)", view: DateSnippet(date: d.date, headline: dist.text, detail: dist.detail))
    }
}

// MARK: - Open in converter

struct OpenConverterIntent: AppIntent {
    static var title: LocalizedStringResource = "Open in Date Converter"
    static var description = IntentDescription("Opens jDate's date converter, on a date if you give one.", categoryName: "Dates")
    static var openAppWhenRun = true

    @Parameter(title: "Date", description: "Empty for today.")
    var date: String?

    @Parameter(title: "Date Is In", default: .automatic)
    var input: IntentInputCalendar

    @MainActor
    func perform() async throws -> some IntentResult {
        let d = try IntentSupport.date(date, input)
        AppModel.current?.openConverter(at: d.date)
        return .result()
    }
}

// MARK: - Snippet

struct DateSnippet: View {
    let date: Date
    let headline: String
    let detail: String
    var highlight: CalendarKind? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(headline).font(.title3.weight(.semibold))
                if !detail.isEmpty { Text(detail).font(.callout).foregroundStyle(.secondary) }
            }
            ForEach(IntentSupport.lines(date), id: \.0) { k, long, iso in
                HStack(spacing: 8) {
                    Image(systemName: k.symbol).foregroundStyle(k.tint)
                    Text(long).font(.body).fontWeight(k == highlight ? .semibold : .regular)
                    Spacer(minLength: 8)
                    Text(iso).font(.system(.body, design: .monospaced))
                        .foregroundStyle(k == highlight ? AnyShapeStyle(.primary) : AnyShapeStyle(.secondary))
                }
            }
        }
        .padding()
    }
}

// MARK: - Spotlight phrases

struct JDateShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: ConvertDateIntent(), phrases: [
            "Convert a date with \(.applicationName)",
            "Convert date to \(\.$to) with \(.applicationName)",
        ], shortTitle: "Convert Date", systemImageName: "arrow.left.arrow.right")
        AppShortcut(intent: CopyDateIntent(), phrases: [
            "Copy today's date with \(.applicationName)",
            "Copy the \(\.$calendar) date with \(.applicationName)",
        ], shortTitle: "Copy Date", systemImageName: "doc.on.doc")
        AppShortcut(intent: CopyFormattedDateIntent(), phrases: [
            "Copy \(\.$format) with \(.applicationName)",
            "Copy a formatted date with \(.applicationName)",
        ], shortTitle: "Copy Date in Format", systemImageName: "text.badge.plus")
        AppShortcut(intent: DaysUntilIntent(), phrases: [
            "Days until a date with \(.applicationName)",
            "Count days with \(.applicationName)",
        ], shortTitle: "Days Until Date", systemImageName: "plusminus")
        AppShortcut(intent: OpenConverterIntent(), phrases: [
            "Open the date converter in \(.applicationName)",
        ], shortTitle: "Date Converter", systemImageName: "calendar")
    }
}
