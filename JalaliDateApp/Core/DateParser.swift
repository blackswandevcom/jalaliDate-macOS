import Foundation

/// Reads a typed date: "1405/08/19", "2026-11-10", "19 آبان 1405", "10 Nov", "tomorrow", "+10", "3 weeks ago", "۱۴۰۵/۸/۱۹".
enum DateParser {
    struct Result {
        let date: Date
        /// Calendar the text was read in (nil for relative words like "tomorrow").
        let calendar: CalendarKind?
    }

    /// `calendar` nil = guess: years from 1700 on are Gregorian, earlier ones Jalali (say Hijri to read Hijri).
    static func parse(_ raw: String, calendar: CalendarKind? = nil, now: Date = Date()) -> Result? {
        let s = normalize(raw)
        let g = Calendar(identifier: .gregorian)
        let today = g.startOfDay(for: now)
        func offset(_ n: Int, _ unit: Calendar.Component = .day) -> Result? {
            let cal = calendar?.calendar ?? CalendarKind.jalali.calendar
            return cal.date(byAdding: unit, value: n, to: today).map { Result(date: g.startOfDay(for: $0), calendar: nil) }
        }

        switch s {
        case "", "today", "now", "امروز", "الان": return Result(date: today, calendar: nil)
        case "tomorrow", "فردا": return offset(1)
        case "yesterday", "دیروز": return offset(-1)
        case "day after tomorrow", "پس فردا", "پسفردا": return offset(2)
        case "day before yesterday", "پریروز": return offset(-2)
        default: break
        }

        if let r = relative(s) { return offset(r.0, r.1) }
        return absolute(s, calendar: calendar, now: now)
    }

    // MARK: Relative

    private static let units: [(Calendar.Component, [String])] = [
        (.day, ["d", "day", "days", "روز"]),
        (.weekOfYear, ["w", "wk", "week", "weeks", "هفته"]),
        (.month, ["m", "mo", "month", "months", "ماه"]),
        (.year, ["y", "yr", "year", "years", "سال"]),
    ]

    /// "+10", "-3w", "in 10 days", "10 days ago", "10 روز بعد", "۳ هفته پیش".
    private static func relative(_ s: String) -> (Int, Calendar.Component)? {
        var t = s
        var sign = 1
        var hadMarker = false
        for (word, value) in [("in ", 1)] where t.hasPrefix(word) { t.removeFirst(word.count); sign = value; hadMarker = true }
        for (word, value) in [(" ago", -1), (" later", 1), (" from now", 1), (" from today", 1), (" before", -1), (" after", 1),
                              (" پیش", -1), (" قبل", -1), (" بعد", 1), (" دیگر", 1), (" بعد از امروز", 1)] where t.hasSuffix(word) {
            t.removeLast(word.count); sign = value; hadMarker = true
        }
        t = t.trimmingCharacters(in: .whitespaces)
        if let f = t.first, f == "+" || f == "-" {
            sign = f == "-" ? -1 : 1
            t.removeFirst()
            hadMarker = true
        }
        t = t.trimmingCharacters(in: .whitespaces)
        let digits = t.prefix { $0.isASCII && $0.isNumber }
        guard !digits.isEmpty, let n = Int(digits) else { return nil }
        let unitText = t.dropFirst(digits.count).trimmingCharacters(in: .whitespaces)
        // A bare number needs + / - / in / ago; "10 days" alone means ten days from today.
        if unitText.isEmpty { return hadMarker ? (sign * n, .day) : nil }
        guard let unit = units.first(where: { $0.1.contains(unitText) })?.0 else { return nil }
        return (sign * n, unit)
    }

    // MARK: Absolute

    private static let monthWords: [(CalendarKind, [[String]])] = [
        (.jalali, [["فروردین", "farvardin"], ["اردیبهشت", "ordibehesht"], ["خرداد", "khordad"], ["تیر", "tir"],
                   ["مرداد", "امرداد", "mordad", "amordad"], ["شهریور", "shahrivar"], ["مهر", "mehr"], ["آبان", "ابان", "aban"],
                   ["آذر", "اذر", "azar"], ["دی", "dey", "dei"], ["بهمن", "bahman"], ["اسفند", "esfand"]]),
        (.gregorian, [["january", "jan", "ژانویه"], ["february", "feb", "فوریه"], ["march", "mar", "مارس"], ["april", "apr", "آوریل"],
                      ["may", "مه", "می"], ["june", "jun", "ژوئن"], ["july", "jul", "ژوئیه", "جولای"], ["august", "aug", "اوت", "آگوست"],
                      ["september", "sep", "sept", "سپتامبر"], ["october", "oct", "اکتبر"], ["november", "nov", "نوامبر"],
                      ["december", "dec", "دسامبر"]]),
        (.islamic, [["محرم", "muharram"], ["صفر", "safar"], ["ربیعالاول", "ربیع الاول", "rabi1", "rabi al-awwal"],
                    ["ربیعالثانی", "ربیع الثانی", "rabi2", "rabi al-thani"], ["جمادیالاول", "جمادی الاول", "jumada1"],
                    ["جمادیالثانی", "جمادی الثانی", "jumada2"], ["رجب", "rajab"], ["شعبان", "shaban", "sha'ban"],
                    ["رمضان", "ramadan", "ramazan"], ["شوال", "shawwal", "shavval"], ["ذیالقعده", "ذی القعده", "dhu al-qadah"],
                    ["ذیالحجه", "ذی الحجه", "dhu al-hijjah"]]),
    ]

    private static func absolute(_ s: String, calendar: CalendarKind?, now: Date) -> Result? {
        // A month name, if there is one (longest names first, so "ربیع الاول" beats "ربیع").
        var month: Int?
        var kind = calendar
        var rest = s
        var candidates: [(CalendarKind, Int, String)] = []
        for (k, months) in monthWords where calendar == nil || calendar == k {
            for (i, names) in months.enumerated() { for n in names { candidates.append((k, i + 1, n)) } }
        }
        for (k, m, name) in candidates.sorted(by: { $0.2.count > $1.2.count }) {
            if let r = wordRange(of: name, in: rest) {
                month = m
                if kind == nil { kind = k }
                rest.replaceSubrange(r, with: " ")
                break
            }
        }

        let numbers = rest.split { !($0.isASCII && $0.isNumber) }.compactMap { Int($0) }
        var y: Int?, m: Int?, d: Int?
        if let month {
            m = month
            switch numbers.count {
            case 1: d = numbers[0]
            case 2: (d, y) = numbers[0] > 31 ? (numbers[1], numbers[0]) : (numbers[0], numbers[1])
            default: return nil
            }
        } else {
            switch numbers.count {
            case 3:
                if numbers[0] > 31 { (y, m, d) = (numbers[0], numbers[1], numbers[2]) }
                else if numbers[2] > 31 {
                    // 10/11/2026: day first, unless the first number can't be a month… or the second can't.
                    (d, m, y) = numbers[1] > 12 ? (numbers[1], numbers[0], numbers[2]) : (numbers[0], numbers[1], numbers[2])
                } else { return nil }
            case 2:
                (m, d) = (numbers[0], numbers[1])
            default: return nil
            }
        }

        if kind == nil, let y { kind = y >= 1700 ? .gregorian : .jalali }
        let k = kind ?? .jalali
        let year = y ?? CalendarService.ymd(now, k).year
        guard let m, let d, (1...12).contains(m), (1...31).contains(d), (1...9999).contains(year),
              d <= CalendarService.daysInMonth(year: year, month: m, k),
              let date = CalendarService.date(year: year, month: m, day: d, k) else { return nil }
        return Result(date: Calendar(identifier: .gregorian).startOfDay(for: date), calendar: k)
    }

    /// Where `word` appears as a whole word.
    private static func wordRange(of word: String, in s: String) -> Range<String.Index>? {
        var from = s.startIndex
        while let r = s.range(of: word, range: from..<s.endIndex) {
            let beforeOK = r.lowerBound == s.startIndex || !s[s.index(before: r.lowerBound)].isLetter
            let afterOK = r.upperBound == s.endIndex || !s[r.upperBound].isLetter
            if beforeOK && afterOK { return r }
            from = r.upperBound
        }
        return nil
    }

    /// Latin digits, lower case, Persian ی/ک, no half-spaces, single spaces.
    static func normalize(_ raw: String) -> String {
        var out = ""
        // Half-spaces join the letter before them into one Character, so drop them as scalars first.
        var scalars = String.UnicodeScalarView()
        scalars.append(contentsOf: raw.unicodeScalars.filter { !["\u{200C}", "\u{200E}", "\u{200F}"].contains($0) })
        for ch in String(scalars).lowercased() {
            switch ch {
            case "۰"..."۹": out.append(Character(String(ch.unicodeScalars.first!.value - 0x06F0)))
            case "٠"..."٩": out.append(Character(String(ch.unicodeScalars.first!.value - 0x0660)))
            case "ي": out.append("ی")
            case "ك": out.append("ک")
            case "\u{200C}", "\u{200F}", "\u{200E}": continue
            case ",", "،", "\t", "\n": out.append(" ")
            default: out.append(ch)
            }
        }
        return out.split(separator: " ", omittingEmptySubsequences: true).joined(separator: " ")
    }

    // MARK: Describing a distance

    /// "Today", "Tomorrow", "In 38 days (5 weeks and 3 days)", "12 days ago".
    static func distance(to date: Date, now: Date = Date()) -> (days: Int, text: String, detail: String) {
        let days = CalendarService.daysFromToday(date, now: now)
        let n = abs(days)
        let text: String
        switch days {
        case 0: text = "Today"
        case 1: text = "Tomorrow"
        case -1: text = "Yesterday"
        default: text = days > 0 ? "In \(n) days" : "\(n) days ago"
        }
        let g = Calendar(identifier: .gregorian)
        let a = g.startOfDay(for: now), b = g.startOfDay(for: date)
        let c = CalendarKind.jalali.calendar.dateComponents([.year, .month, .day], from: min(a, b), to: max(a, b))
        var parts: [String] = []
        if n >= 7 { parts.append("\(n / 7) week\(n / 7 == 1 ? "" : "s")" + (n % 7 > 0 ? " and \(n % 7) day\(n % 7 == 1 ? "" : "s")" : "")) }
        if (c.year ?? 0) > 0 || (c.month ?? 0) > 0 {
            var ymd: [String] = []
            if let y = c.year, y > 0 { ymd.append("\(y) year\(y == 1 ? "" : "s")") }
            if let m = c.month, m > 0 { ymd.append("\(m) month\(m == 1 ? "" : "s")") }
            if let d = c.day, d > 0 { ymd.append("\(d) day\(d == 1 ? "" : "s")") }
            parts.append(ymd.joined(separator: ", "))
        }
        return (days, text, parts.joined(separator: " · "))
    }
}
