import SwiftUI

extension ThemeConfig {
    var holidayColor: String { get { holidayColorRaw ?? DayColors.defaultHoliday } set { holidayColorRaw = newValue } }
    var weekendColor: String { get { weekendColorRaw ?? DayColors.defaultWeekend } set { weekendColorRaw = newValue } }
    var weekendDays: Set<Int> { get { Set(weekendDaysRaw ?? [6]) } set { weekendDaysRaw = newValue.sorted() } }
}

/// Holiday and weekend colors and which days are the weekend. Read by the calendar grid,
/// the events list and the widgets.
enum DayColors {
    static let defaultHoliday = "#EF4444"
    static let defaultWeekend = "#EF4444"

    nonisolated(unsafe) private static var cached: ThemeConfig?
    nonisolated(unsafe) private static var loadedAt = Date.distantPast
    nonisolated(unsafe) private static var pinned = false

    /// The app pushes every change here; the widgets re-read the shared settings.
    static func update(_ config: ThemeConfig) {
        cached = config
        pinned = true
    }

    static var config: ThemeConfig {
        if let c = cached, pinned || Date().timeIntervalSince(loadedAt) < 5 { return c }
        let c = Prefs.load(ThemeConfig.self, Prefs.themeKey) ?? ThemeConfig()
        cached = c
        loadedAt = Date()
        return c
    }

    static var holiday: Color { Color(hex: config.holidayColor) }
    static var weekend: Color { Color(hex: config.weekendColor) }

    static func isWeekend(_ date: Date) -> Bool {
        config.weekendDays.contains(Calendar(identifier: .gregorian).component(.weekday, from: date))
    }

    static func isWeekend(weekday: Int) -> Bool { config.weekendDays.contains(weekday) }

    /// Color of a day number: holiday first, then weekend, else nil (normal text).
    static func color(holiday: Bool, date: Date) -> Color? {
        if holiday { return self.holiday }
        if isWeekend(date) { return weekend }
        return nil
    }

    /// Weekday shown in a column: Jalali grids start on Saturday, Gregorian ones on Monday.
    static func weekday(column: Int, jalali: Bool) -> Int {
        jalali ? ((column + 6) % 7) + 1 : ((column + 1) % 7) + 1
    }

    static let presets: [(String, Set<Int>)] = [
        ("Friday (Iran)", [6]),
        ("Thursday + Friday", [5, 6]),
        ("Friday + Saturday", [6, 7]),
        ("Saturday + Sunday", [7, 1]),
    ]
}
