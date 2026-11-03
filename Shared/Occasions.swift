import SwiftUI

/// Themes for holidays and seasons of the year. Each one is an animated header with its own palette,
/// and can switch on by itself during its days.
enum Occasion: String, Codable, CaseIterable, Identifiable {
    // Order = priority when two overlap.
    case muharram, chaharshanbeSuri, sizdahBedar, yalda, eidFitr, eidAdha, nowruz, christmas, newYear, july4, halloween, valentine, ramadan

    var id: String { rawValue }

    /// Order shown in settings.
    static let displayOrder: [Occasion] = [.nowruz, .chaharshanbeSuri, .sizdahBedar, .yalda, .ramadan, .eidFitr, .eidAdha, .muharram,
                                           .christmas, .newYear, .july4, .halloween, .valentine]

    var title: String {
        switch self {
        case .nowruz: return "Nowruz · نوروز"
        case .chaharshanbeSuri: return "Chaharshanbe Suri · چهارشنبه‌سوری"
        case .sizdahBedar: return "Sizdah Bedar · سیزده‌بدر"
        case .yalda: return "Yalda · شب یلدا"
        case .ramadan: return "Ramadan · ماه رمضان"
        case .eidFitr: return "Eid al-Fitr · عید فطر"
        case .eidAdha: return "Eid al-Adha · عید قربان"
        case .muharram: return "Muharram · محرم"
        case .christmas: return "Christmas"
        case .newYear: return "New Year's Eve"
        case .july4: return "4th of July"
        case .halloween: return "Halloween"
        case .valentine: return "Valentine's Day"
        }
    }

    /// When it switches on by itself.
    var when: String {
        switch self {
        case .nowruz: return "25 Esfand to 12 Farvardin"
        case .chaharshanbeSuri: return "The last Tuesday of the year"
        case .sizdahBedar: return "13 Farvardin"
        case .yalda: return "30 Azar and 1 Dey"
        case .ramadan: return "The whole month of Ramadan"
        case .eidFitr: return "1 to 3 Shawwal"
        case .eidAdha: return "10 and 11 Dhu al-Hijjah"
        case .muharram: return "1 to 12 Muharram"
        case .christmas: return "20 to 26 December"
        case .newYear: return "31 December and 1 January"
        case .july4: return "3 to 5 July"
        case .halloween: return "31 October"
        case .valentine: return "14 February"
        }
    }

    var style: AnimatedStyle {
        switch self {
        case .nowruz: return .blossoms
        case .sizdahBedar: return .blossoms
        case .chaharshanbeSuri: return .embers
        case .yalda: return .lava
        case .ramadan: return .lanterns
        case .eidFitr: return .lanterns
        case .eidAdha: return .liquid
        case .muharram: return .rings
        case .christmas: return .snowfall
        case .newYear: return .fireworks
        case .july4: return .fireworks
        case .halloween: return .embers
        case .valentine: return .hearts
        }
    }

    var palette: [String] {
        switch self {
        case .nowruz: return ["#15803D", "#DB2777", "#FEF3C7"]
        case .sizdahBedar: return ["#15803D", "#BEF264", "#FFFFFF"]
        case .chaharshanbeSuri: return ["#1C1917", "#EA580C", "#FDE047"]
        case .yalda: return ["#3B0A1A", "#B91C1C", "#FB7185"]
        case .ramadan: return ["#0F172A", "#4C1D95", "#FCD34D"]
        case .eidFitr: return ["#064E3B", "#0D9488", "#FDE68A"]
        case .eidAdha: return ["#065F46", "#CA8A04", "#0E7490"]
        case .muharram: return ["#0A0A0A", "#14532D", "#166534"]
        case .christmas: return ["#14532D", "#DC2626", "#FDE68A"]
        case .newYear: return ["#0B1026", "#FACC15", "#E5E7EB"]
        case .july4: return ["#0B1F4D", "#DC2626", "#F8FAFC"]
        case .halloween: return ["#1E0B2E", "#F97316", "#A855F7"]
        case .valentine: return ["#BE185D", "#F472B6", "#FFE4E6"]
        }
    }

    var accent: String {
        switch self {
        case .muharram: return "#16A34A"
        case .newYear, .ramadan: return "#CA8A04"
        case .july4: return "#1D4ED8"
        default: return palette[1]
        }
    }

    var speed: Double { self == .muharram ? 0.35 : 1 }
    var intensity: Double { self == .muharram ? 0.3 : 0.75 }

    var theme: ResolvedTheme {
        let colors = palette.map { Color(hex: $0) }
        return ResolvedTheme(name: title, colors: [colors[0], colors[1]], accent: Color(hex: accent), symbol: nil, particle: nil,
                             effect: .animated(style, colors: colors, speed: speed, intensity: intensity))
    }

    func isActive(on date: Date) -> Bool {
        let j = CalendarService.ymd(date, .jalali)
        let h = CalendarService.ymd(date, .islamic)
        let g = CalendarService.ymd(date, .gregorian)
        switch self {
        case .chaharshanbeSuri:
            let tuesday = Calendar(identifier: .gregorian).component(.weekday, from: date) == 3
            return j.month == 12 && tuesday && j.day + 7 > CalendarService.daysInMonth(year: j.year, month: 12, .jalali)
        case .nowruz: return (j.month == 12 && j.day >= 25) || (j.month == 1 && j.day <= 12)
        case .sizdahBedar: return j.month == 1 && j.day == 13
        case .yalda: return (j.month == 9 && j.day == 30) || (j.month == 10 && j.day == 1)
        case .ramadan: return h.month == 9
        case .eidFitr: return h.month == 10 && h.day <= 3
        case .eidAdha: return h.month == 12 && (h.day == 10 || h.day == 11)
        case .muharram: return h.month == 1 && h.day <= 12
        case .christmas: return g.month == 12 && (20...26).contains(g.day)
        case .newYear: return (g.month == 12 && g.day == 31) || (g.month == 1 && g.day == 1)
        case .july4: return g.month == 7 && (3...5).contains(g.day)
        case .halloween: return g.month == 10 && g.day == 31
        case .valentine: return g.month == 2 && g.day == 14
        }
    }

    static func active(on date: Date, excluding off: Set<Occasion> = []) -> Occasion? {
        allCases.first { !off.contains($0) && $0.isActive(on: date) }
    }

    /// Next date (within a year) this occasion starts, for the settings list.
    func nextStart(from now: Date = Date()) -> Date? {
        let g = Calendar(identifier: .gregorian)
        let today = g.startOfDay(for: now)
        if isActive(on: today) { return today }
        for i in 1...400 {
            guard let d = g.date(byAdding: .day, value: i, to: today) else { return nil }
            if isActive(on: d) { return d }
        }
        return nil
    }
}
