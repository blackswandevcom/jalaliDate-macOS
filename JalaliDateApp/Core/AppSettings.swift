import Combine
import SwiftUI

// MARK: - Menubar icon

enum IconShape: String, Codable, CaseIterable, Identifiable {
    case circle, filledCircle, roundedSquare, filledRoundedSquare, square, filledSquare, calendarPage, none
    var id: String { rawValue }
    var title: String {
        switch self {
        case .circle: return "Circle"
        case .filledCircle: return "Filled circle"
        case .roundedSquare: return "Rounded square"
        case .filledRoundedSquare: return "Filled rounded square"
        case .square: return "Square"
        case .filledSquare: return "Filled square"
        case .calendarPage: return "Calendar page"
        case .none: return "No shape"
        }
    }
    var filled: Bool { [.filledCircle, .filledRoundedSquare, .filledSquare].contains(self) }
}

enum IconLayout: String, Codable, CaseIterable, Identifiable {
    case badge, text, both
    var id: String { rawValue }
    var title: String {
        switch self {
        case .badge: return "Badge"
        case .text: return "Text"
        case .both: return "Badge + text"
        }
    }
}

struct IconConfig: Codable, Equatable {
    var layout: IconLayout = .badge
    var shape: IconShape = .circle
    var badgeFormat = "{jd}"
    var textFormat = "{wd} {jd} {jmn}"
    var badgePersianDigits = false
    var textPersianDigits = true
    var useCustomColors = false
    var shapeColor = "#F97316"
    var textColor = "#FFFFFF"
    var fontSize: Double = 10
    var bold = true

    /// Migrates the v7 three-way icon style.
    static func initial() -> IconConfig {
        var c = IconConfig()
        switch Prefs.defaults.string(forKey: Prefs.legacyIconStyleKey) {
        case "text": c.layout = .text; c.textFormat = "{jd} {jmn}"
        case "both": c.layout = .both; c.textFormat = "{jd} {jmn}"
        default: break
        }
        return c
    }
}

// MARK: - Popover layout

enum PopoverSection: String, Codable, CaseIterable, Identifiable {
    case hero, widgets, calendar, dayEvents, upcoming
    var id: String { rawValue }
    var title: String {
        switch self {
        case .hero: return "Today header"
        case .widgets: return "Widgets"
        case .calendar: return "Month calendar"
        case .dayEvents: return "Events of the selected day"
        case .upcoming: return "Upcoming (next 7 days)"
        }
    }
    var symbol: String {
        switch self {
        case .hero: return "rectangle.fill"
        case .widgets: return "square.grid.2x2"
        case .calendar: return "calendar"
        case .dayEvents: return "list.bullet"
        case .upcoming: return "clock.arrow.circlepath"
        }
    }
}

enum PopoverArrangement: String, Codable, CaseIterable, Identifiable {
    case stacked, sideBySide
    var id: String { rawValue }
    var title: String { self == .stacked ? "Stacked (narrow)" : "Calendar and events side by side (wide)" }
}

struct SectionConfig: Codable, Identifiable, Equatable {
    var section: PopoverSection
    var visible = true
    var id: String { section.rawValue }
}

enum WidgetSize: String, Codable, CaseIterable, Identifiable {
    case full, half, third
    var id: String { rawValue }
    var units: Int { self == .full ? 6 : self == .half ? 3 : 2 }
    var title: String { self == .full ? "Full width" : self == .half ? "Half" : "One third" }
}

struct CountdownTarget: Codable, Hashable {
    var title: String
    var calendar: CalendarKind
    var month: Int
    var day: Int
    /// nil = repeats every year.
    var year: Int?

    static let nowruz = CountdownTarget(title: "Nowruz", calendar: .jalali, month: 1, day: 1, year: nil)

    func nextDate(from now: Date = Date()) -> Date? {
        let today = Calendar(identifier: .gregorian).startOfDay(for: now)
        if let year { return CalendarService.date(year: year, month: month, day: day, calendar) }
        let y = CalendarService.ymd(now, calendar).year
        for candidate in [y, y + 1] {
            if let d = CalendarService.date(year: candidate, month: month, day: day, calendar), d >= today { return d }
        }
        return nil
    }
}

enum WidgetKind: Codable, Hashable {
    case date(CalendarKind)
    case weather(City)
    case clock(City)
    case countdown(CountdownTarget)
    case upcoming

    var title: String {
        switch self {
        case .date(let k): return "\(k.shortTitle) date"
        case .weather(let c): return "Weather · \(c.name)"
        case .clock(let c): return "Clock · \(c.name)"
        case .countdown(let t): return "Countdown · \(t.title)"
        case .upcoming: return "Next event"
        }
    }

    var symbol: String {
        switch self {
        case .date(let k): return k.symbol
        case .weather: return "cloud.sun.fill"
        case .clock: return "clock.fill"
        case .countdown: return "hourglass"
        case .upcoming: return "bell.fill"
        }
    }
}

struct WidgetConfig: Codable, Identifiable, Hashable {
    var id = UUID()
    var kind: WidgetKind
    var size: WidgetSize = .full
}

struct PopoverLayout: Codable, Equatable {
    var sections: [SectionConfig] = PopoverSection.allCases.map { SectionConfig(section: $0, visible: $0 != .upcoming) }
    var widgets: [WidgetConfig] = [
        WidgetConfig(kind: .date(.jalali)),
        WidgetConfig(kind: .date(.gregorian)),
        WidgetConfig(kind: .date(.islamic)),
    ]
    var width: Double = 340
    // Optional so layouts saved by earlier builds still decode.
    var arrangementRaw: PopoverArrangement? = nil
    var wideWidthRaw: Double? = nil
    var calendarOnRightRaw: Bool? = nil
    var cellGregorianRaw: Bool? = nil
    var cellHijriRaw: Bool? = nil
    var cellDayFontRaw: Double? = nil
    var cellSecondaryFontRaw: Double? = nil
    var headerRaw: HeaderLayout? = nil
    var compactDatesRaw: Bool? = nil
    var showFooterRaw: Bool? = nil

    /// The button bar at the bottom of the popover.
    var showFooter: Bool {
        get { showFooterRaw ?? true }
        set { showFooterRaw = newValue }
    }

    /// Date tiles on one line with less padding.
    var compactDates: Bool {
        get { compactDatesRaw ?? false }
        set { compactDatesRaw = newValue }
    }

    /// What the coloured header shows, and each line's size and colour.
    var header: HeaderLayout {
        get { headerRaw ?? HeaderLayout() }
        set { headerRaw = newValue }
    }

    static let widths: [Double] = [320, 340, 380, 440]
    static let wideWidths: [Double] = [640, 720, 800, 880]

    var arrangement: PopoverArrangement {
        get { arrangementRaw ?? .stacked }
        set { arrangementRaw = newValue }
    }
    var wideWidth: Double {
        get { wideWidthRaw ?? 720 }
        set { wideWidthRaw = newValue }
    }
    /// Side-by-side: calendar on the right (Persian reading order), events on the left.
    var calendarOnRight: Bool {
        get { calendarOnRightRaw ?? true }
        set { calendarOnRightRaw = newValue }
    }
    /// Month calendar: which extra calendars show under each Jalali day, and the type sizes.
    var cellGregorian: Bool { get { cellGregorianRaw ?? true } set { cellGregorianRaw = newValue } }
    var cellHijri: Bool { get { cellHijriRaw ?? false } set { cellHijriRaw = newValue } }
    var cellDayFont: Double { get { cellDayFontRaw ?? 12 } set { cellDayFontRaw = newValue } }
    var cellSecondaryFont: Double { get { cellSecondaryFontRaw ?? 8 } set { cellSecondaryFontRaw = newValue } }

    /// Width actually used by the popover.
    var effectiveWidth: Double { arrangement == .sideBySide ? wideWidth : width }

    func isVisible(_ s: PopoverSection) -> Bool { sections.first { $0.section == s }?.visible ?? false }

    /// Packs widgets into rows of 6 units.
    var rows: [[WidgetConfig]] {
        var rows: [[WidgetConfig]] = []
        var current: [WidgetConfig] = []
        var used = 0
        for w in widgets {
            if used + w.size.units > 6 { rows.append(current); current = []; used = 0 }
            current.append(w)
            used += w.size.units
        }
        if !current.isEmpty { rows.append(current) }
        return rows
    }
}

// MARK: - Header contents

/// One line (or the big number) in the coloured header.
enum HeaderItem: String, CaseIterable, Identifiable, Codable {
    case gregorianWeekday, gregorianDate, hijriDate, weather, backToToday
    case jalaliWeekday, jalaliMonth, caption, dayNumber, events
    var id: String { rawValue }

    var title: String {
        switch self {
        case .gregorianWeekday: return "Weekday (English)"
        case .gregorianDate: return "Gregorian date"
        case .hijriDate: return "Hijri date"
        case .weather: return "Weather"
        case .backToToday: return "“Back to today” button"
        case .jalaliWeekday: return "Weekday (Persian)"
        case .jalaliMonth: return "Persian month and year"
        case .caption: return "Theme name / days from today"
        case .dayNumber: return "Day number"
        case .events: return "The day's events"
        }
    }

    var defaultSize: Double {
        switch self {
        case .gregorianWeekday, .jalaliWeekday: return 13
        case .gregorianDate, .jalaliMonth: return 12
        case .hijriDate, .weather: return 11
        case .backToToday: return 10
        case .caption: return 10
        case .dayNumber: return 42
        case .events: return 12
        }
    }

    var sizeRange: ClosedRange<Double> { self == .dayNumber ? 20...72 : 8...24 }

    /// Events start off in the panel below the calendar.
    var defaultVisible: Bool { self != .events }

    /// How strong the default (white) text is.
    var defaultOpacity: Double {
        switch self {
        case .gregorianDate, .jalaliMonth: return 0.9
        case .hijriDate: return 0.8
        case .caption: return 0.75
        default: return 1
        }
    }
}

struct HeaderItemStyle: Codable, Equatable {
    var visible = true
    var size: Double? = nil
    /// #RRGGBB, or nil for the theme's text colour.
    var color: String? = nil
}

struct HeaderLayout: Codable, Equatable {
    var items: [String: HeaderItemStyle] = [:]

    func style(_ i: HeaderItem) -> HeaderItemStyle { items[i.rawValue] ?? HeaderItemStyle(visible: i.defaultVisible) }
    func visible(_ i: HeaderItem) -> Bool { style(i).visible }
    func size(_ i: HeaderItem) -> CGFloat { CGFloat(style(i).size ?? i.defaultSize) }
    func color(_ i: HeaderItem) -> Color {
        if let hex = style(i).color { return Color(hex: hex) }
        return Color.white.opacity(i.defaultOpacity)
    }

    subscript(_ i: HeaderItem) -> HeaderItemStyle {
        get { style(i) }
        set { items[i.rawValue] = newValue }
    }
}

// MARK: - General

enum CopyFormat: String, Codable, CaseIterable, Identifiable {
    case dash, slash, dashPersian, slashPersian, long
    var id: String { rawValue }
    var title: String {
        switch self {
        case .dash: return "1405-08-11"
        case .slash: return "1405/08/11"
        case .dashPersian: return "۱۴۰۵-۰۸-۱۱"
        case .slashPersian: return "۱۴۰۵/۰۸/۱۱"
        case .long: return "Long (دوشنبه ۱۱ آبان ۱۴۰۵)"
        }
    }

    func string(_ date: Date, _ kind: CalendarKind) -> String {
        let iso = CalendarService.iso(date, kind)
        switch self {
        case .dash: return iso
        case .slash: return iso.replacingOccurrences(of: "-", with: "/")
        case .dashPersian: return CalendarService.persianDigits(iso)
        case .slashPersian: return CalendarService.persianDigits(iso.replacingOccurrences(of: "-", with: "/"))
        case .long:
            let year = CalendarService.ymd(date, kind).year
            let y = kind == .gregorian ? "\(year)" : CalendarService.persianDigits(year)
            return "\(CalendarService.long(date, kind)) \(y)"
        }
    }
}

struct GeneralSettings: Codable, Equatable {
    var copyFormat: CopyFormat = .dash
    var clock24h = true
    var hotkeyEnabled = true
    var hotkeyKey = "J"
    var hotkeyControl = true
    var hotkeyOption = true
    var hotkeyCommand = false
    var hotkeyShift = false

    var hotkeyDescription: String {
        (hotkeyControl ? "⌃" : "") + (hotkeyOption ? "⌥" : "") + (hotkeyShift ? "⇧" : "") + (hotkeyCommand ? "⌘" : "") + hotkeyKey
    }
}

// MARK: - Store

@MainActor
final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    @Published var icon: IconConfig { didSet { Prefs.save(icon, Prefs.iconConfigKey) } }
    @Published var theme: ThemeConfig { didSet { Prefs.save(theme, Prefs.themeKey); DayColors.update(theme) } }
    @Published var layout: PopoverLayout { didSet { Prefs.save(layout, Prefs.layoutKey) } }
    @Published var general: GeneralSettings { didSet { Prefs.save(general, Prefs.generalKey) } }

    private init() {
        Prefs.migrate()
        icon = Prefs.load(IconConfig.self, Prefs.iconConfigKey) ?? IconConfig.initial()
        theme = Prefs.load(ThemeConfig.self, Prefs.themeKey) ?? ThemeConfig()
        layout = Prefs.load(PopoverLayout.self, Prefs.layoutKey) ?? PopoverLayout()
        general = Prefs.load(GeneralSettings.self, Prefs.generalKey) ?? GeneralSettings()
        DayColors.update(theme)
        // Make sure sections added in later versions appear.
        for s in PopoverSection.allCases where !layout.sections.contains(where: { $0.section == s }) {
            layout.sections.append(SectionConfig(section: s, visible: false))
        }
    }
}
