import Foundation
import SwiftUI

/// The three calendars the app works with.
enum CalendarKind: String, CaseIterable, Identifiable, Codable, Hashable {
    case jalali, gregorian, islamic

    var id: String { rawValue }

    var calendar: Calendar {
        switch self {
        case .jalali: return Calendar(identifier: .persian)
        case .gregorian: return Calendar(identifier: .gregorian)
        case .islamic: return Calendar(identifier: HijriVariant.current.identifier)
        }
    }

    var title: String {
        switch self {
        case .jalali: return "Jalali (Shamsi)"
        case .gregorian: return "Gregorian"
        case .islamic: return "Islamic (Hijri)"
        }
    }

    var shortTitle: String {
        switch self {
        case .jalali: return "Jalali"
        case .gregorian: return "Gregorian"
        case .islamic: return "Hijri"
        }
    }

    var symbol: String {
        switch self {
        case .jalali: return "j.circle.fill"
        case .gregorian: return "g.circle.fill"
        case .islamic: return "h.circle.fill"
        }
    }

    var tint: Color {
        switch self {
        case .jalali: return .orange
        case .gregorian: return .blue
        case .islamic: return .green
        }
    }

    /// ⌘-shortcut used in the popover to copy today's date (kept from v6).
    var copyShortcut: KeyEquivalent {
        switch self {
        case .jalali: return "c"
        case .gregorian: return "x"
        case .islamic: return "a"
        }
    }

    var monthNames: [String] {
        switch self {
        case .gregorian:
            return ["January", "February", "March", "April", "May", "June",
                    "July", "August", "September", "October", "November", "December"]
        case .jalali:
            return ["فروردین", "اردیبهشت", "خرداد", "تیر", "مرداد", "شهریور",
                    "مهر", "آبان", "آذر", "دی", "بهمن", "اسفند"]
        case .islamic:
            return ["محرم", "صفر", "ربیع‌الاول", "ربیع‌الثانی", "جمادی‌الاول", "جمادی‌الثانی",
                    "رجب", "شعبان", "رمضان", "شوال", "ذی‌القعده", "ذی‌الحجه"]
        }
    }
}

/// All date math and formatting. The Hijri day offset from Settings is applied here.
enum CalendarService {
    static var islamicOffset: Int {
        Prefs.defaults.integer(forKey: Prefs.islamicOffsetKey)
    }

    /// The instant whose calendar fields should be read for `kind` (Hijri gets the user offset).
    static func adjusted(_ date: Date, for kind: CalendarKind) -> Date {
        guard kind == .islamic, islamicOffset != 0 else { return date }
        return Calendar(identifier: .gregorian).date(byAdding: .day, value: islamicOffset, to: date) ?? date
    }

    static func format(_ date: Date, _ kind: CalendarKind, _ pattern: String, locale: Locale = Locale(identifier: "en_US_POSIX")) -> String {
        let f = DateFormatter()
        f.calendar = kind.calendar
        f.locale = locale
        f.dateFormat = pattern
        return f.string(from: adjusted(date, for: kind))
    }

    /// `yyyy-MM-dd` — the string that gets copied.
    static func iso(_ date: Date, _ kind: CalendarKind) -> String {
        format(date, kind, "yyyy-MM-dd")
    }

    /// Human-readable form: "یکشنبه ۱۱ آبان", "Sunday 2 November", "الأحد ۱۰ جمادی‌الاول".
    static func long(_ date: Date, _ kind: CalendarKind) -> String {
        switch kind {
        case .jalali: return format(date, .jalali, "EEEE d MMMM", locale: Locale(identifier: "fa_IR"))
        case .gregorian: return format(date, .gregorian, "EEEE d MMMM", locale: Locale(identifier: "en_US"))
        case .islamic:
            return "\(weekday(date, .islamic)) \(format(date, .islamic, "d MMMM", locale: Locale(identifier: "fa_IR")))"
        }
    }

    static func weekday(_ date: Date, _ kind: CalendarKind) -> String {
        let locale: Locale
        switch kind {
        case .jalali: locale = Locale(identifier: "fa_IR")
        case .gregorian: locale = Locale(identifier: "en_US")
        case .islamic: locale = Locale(identifier: "ar_AE")
        }
        let f = DateFormatter()
        f.calendar = kind.calendar
        f.locale = locale
        f.dateFormat = "EEEE"
        return f.string(from: date) // weekday is the same instant, no offset
    }

    static func ymd(_ date: Date, _ kind: CalendarKind) -> (year: Int, month: Int, day: Int) {
        let c = kind.calendar.dateComponents([.year, .month, .day], from: adjusted(date, for: kind))
        return (c.year ?? 1, c.month ?? 1, c.day ?? 1)
    }

    static func daysInMonth(year: Int, month: Int, _ kind: CalendarKind) -> Int {
        let cal = kind.calendar
        guard let first = cal.date(from: DateComponents(year: year, month: month, day: 1)),
              let range = cal.range(of: .day, in: .month, for: first) else { return 30 }
        return range.count
    }

    /// Builds a date from fields of `kind`; the day is clamped to the month length and the Hijri offset is undone.
    static func date(year: Int, month: Int, day: Int, _ kind: CalendarKind) -> Date? {
        let y = min(max(year, 1), 9999)
        let m = min(max(month, 1), 12)
        let d = min(max(day, 1), daysInMonth(year: y, month: m, kind))
        guard let date = kind.calendar.date(from: DateComponents(year: y, month: m, day: d)) else { return nil }
        guard kind == .islamic, islamicOffset != 0 else { return date }
        return Calendar(identifier: .gregorian).date(byAdding: .day, value: -islamicOffset, to: date)
    }

    static func isFriday(_ date: Date) -> Bool {
        Calendar(identifier: .gregorian).component(.weekday, from: date) == 6
    }

    /// Whole days from today to `date` (negative = past).
    static func daysFromToday(_ date: Date, now: Date = Date()) -> Int {
        let cal = Calendar(identifier: .gregorian)
        return cal.dateComponents([.day], from: cal.startOfDay(for: now), to: cal.startOfDay(for: date)).day ?? 0
    }

    static func persianDigits(_ n: Int) -> String {
        persianDigits(String(n))
    }

    static func persianDigits(_ s: String) -> String {
        let map: [Character: Character] = ["0": "۰", "1": "۱", "2": "۲", "3": "۳", "4": "۴",
                                           "5": "۵", "6": "۶", "7": "۷", "8": "۸", "9": "۹"]
        return String(s.map { map[$0] ?? $0 })
    }

    static func fromISO(_ s: String) -> Date? {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f.date(from: s)
    }
}
