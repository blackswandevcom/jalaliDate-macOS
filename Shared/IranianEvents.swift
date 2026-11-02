import Foundation

/// Bundled official Iranian holidays and cultural occasions. Lunar dates follow the app's Hijri
/// calendar and offset, so they may move by a day — the Hijri offset setting fixes that.
struct PublicEvent: Hashable {
    enum Category: String { case national, religious, cultural, international }

    let calendar: CalendarKind
    let month: Int
    /// 0 = last day of the month.
    let day: Int
    let title: String
    let holiday: Bool
    let category: Category
}

enum IranianEvents {
    private static func s(_ m: Int, _ d: Int, _ t: String, _ h: Bool = false, _ c: PublicEvent.Category = .national) -> PublicEvent {
        PublicEvent(calendar: .jalali, month: m, day: d, title: t, holiday: h, category: c)
    }
    private static func l(_ m: Int, _ d: Int, _ t: String, _ h: Bool = false) -> PublicEvent {
        PublicEvent(calendar: .islamic, month: m, day: d, title: t, holiday: h, category: .religious)
    }
    private static func g(_ m: Int, _ d: Int, _ t: String) -> PublicEvent {
        PublicEvent(calendar: .gregorian, month: m, day: d, title: t, holiday: false, category: .international)
    }

    static let solar: [PublicEvent] = [
        s(1, 1, "عید نوروز", true), s(1, 2, "عید نوروز", true), s(1, 3, "عید نوروز", true), s(1, 4, "عید نوروز", true),
        s(1, 12, "روز جمهوری اسلامی", true), s(1, 13, "روز طبیعت (سیزده‌به‌در)", true, .cultural),
        s(3, 14, "رحلت امام خمینی", true), s(3, 15, "قیام ۱۵ خرداد", true),
        s(11, 22, "پیروزی انقلاب اسلامی", true), s(12, 29, "روز ملی شدن صنعت نفت", true),
        // Occasions
        s(1, 25, "روز بزرگداشت عطار", false, .cultural), s(2, 1, "روز بزرگداشت سعدی", false, .cultural),
        s(2, 10, "روز ملی خلیج فارس", false, .national), s(2, 12, "روز معلم", false, .cultural),
        s(2, 25, "روز بزرگداشت فردوسی", false, .cultural), s(2, 28, "روز بزرگداشت خیام", false, .cultural),
        s(4, 13, "جشن تیرگان", false, .cultural), s(7, 1, "آغاز سال تحصیلی", false, .cultural),
        s(7, 8, "روز بزرگداشت مولوی", false, .cultural), s(7, 10, "جشن مهرگان", false, .cultural),
        s(7, 20, "روز بزرگداشت حافظ", false, .cultural), s(8, 13, "روز دانش‌آموز", false, .cultural),
        s(9, 16, "روز دانشجو", false, .cultural), s(9, 30, "شب یلدا", false, .cultural),
        s(11, 10, "جشن سده", false, .cultural), s(11, 29, "سپندارمذگان", false, .cultural),
    ]

    static let lunar: [PublicEvent] = [
        l(1, 9, "تاسوعای حسینی", true), l(1, 10, "عاشورای حسینی", true),
        l(2, 20, "اربعین حسینی", true), l(2, 28, "رحلت رسول اکرم و شهادت امام حسن مجتبی", true),
        l(2, 0, "شهادت امام رضا", true),
        l(3, 8, "شهادت امام حسن عسکری", true), l(3, 17, "میلاد رسول اکرم و امام جعفر صادق", true),
        l(6, 3, "شهادت حضرت فاطمه زهرا", true),
        l(7, 13, "ولادت امام علی و روز پدر", true), l(7, 27, "مبعث رسول اکرم", true),
        l(8, 15, "ولادت حضرت قائم", true),
        l(9, 21, "شهادت حضرت علی", true),
        l(10, 1, "عید سعید فطر", true), l(10, 2, "تعطیل به مناسبت عید فطر", true),
        l(10, 25, "شهادت امام جعفر صادق", true),
        l(12, 10, "عید سعید قربان", true), l(12, 18, "عید سعید غدیر خم", true),
        // Occasions
        l(1, 1, "آغاز سال هجری قمری"), l(6, 20, "ولادت حضرت فاطمه و روز مادر"),
        l(9, 1, "آغاز ماه رمضان"), l(9, 19, "شب قدر"), l(9, 23, "شب قدر"),
        l(11, 11, "ولادت امام رضا"),
    ]

    static let international: [PublicEvent] = [
        g(1, 1, "New Year's Day"), g(2, 14, "Valentine's Day"), g(3, 8, "International Women's Day"),
        g(5, 1, "Labour Day"), g(10, 31, "Halloween"), g(12, 25, "Christmas"),
    ]

    struct Options {
        var occasions = true
        var international = false
        var lunarHolidays = true
    }

    static func events(on date: Date, options: Options = Options()) -> [PublicEvent] {
        var out: [PublicEvent] = []
        let j = CalendarService.ymd(date, .jalali)
        let h = CalendarService.ymd(date, .islamic)
        let gd = CalendarService.ymd(date, .gregorian)
        let hDays = CalendarService.daysInMonth(year: h.year, month: h.month, .islamic)

        for e in solar where e.month == j.month && e.day == j.day && (e.holiday || options.occasions) {
            out.append(e)
        }
        for e in lunar where e.month == h.month && (e.holiday ? options.lunarHolidays : options.occasions) {
            if e.day == h.day || (e.day == 0 && h.day == hDays) { out.append(e) }
        }
        if options.occasions, isChaharshanbeSuri(date) {
            out.append(PublicEvent(calendar: .jalali, month: 12, day: j.day, title: "چهارشنبه‌سوری", holiday: false, category: .cultural))
        }
        if options.international {
            out += international.filter { $0.month == gd.month && $0.day == gd.day }
        }
        return out
    }

    /// Tuesday evening before the last Wednesday of the Jalali year.
    static func isChaharshanbeSuri(_ date: Date) -> Bool {
        let g = Calendar(identifier: .gregorian)
        guard g.component(.weekday, from: date) == 3,
              let wed = g.date(byAdding: .day, value: 1, to: date),
              let nextWed = g.date(byAdding: .day, value: 8, to: date) else { return false }
        return CalendarService.ymd(wed, .jalali).month == 12 && CalendarService.ymd(nextWed, .jalali).month == 1
    }

    static func isHoliday(_ date: Date, options: Options = Options()) -> Bool {
        CalendarService.isFriday(date) || events(on: date, options: options).contains { $0.holiday }
    }
}
