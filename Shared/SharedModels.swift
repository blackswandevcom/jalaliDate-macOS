import Foundation
import SwiftUI

// MARK: - City

struct City: Codable, Identifiable, Hashable {
    var id = UUID()
    var name: String
    var country: String = ""
    var latitude: Double = 0
    var longitude: Double = 0
    var timeZone: String

    var tz: TimeZone { TimeZone(identifier: timeZone) ?? .current }

    /// "+3:30" style difference from the Mac's time zone.
    func offsetText(at date: Date = Date()) -> String {
        let diff = tz.secondsFromGMT(for: date) - TimeZone.current.secondsFromGMT(for: date)
        if diff == 0 { return "Same time" }
        let sign = diff > 0 ? "+" : "−"
        let h = abs(diff) / 3600, m = (abs(diff) % 3600) / 60
        return m == 0 ? "\(sign)\(h)h" : "\(sign)\(h):\(String(format: "%02d", m))"
    }

    /// "Today" / "Tomorrow" / "Yesterday" relative to local.
    func dayRelation(at date: Date = Date()) -> String? {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = tz
        let there = cal.dateComponents([.year, .month, .day], from: date)
        var local = Calendar(identifier: .gregorian)
        local.timeZone = .current
        let here = local.dateComponents([.year, .month, .day], from: date)
        guard let a = local.date(from: there), let b = local.date(from: here) else { return nil }
        let d = local.dateComponents([.day], from: b, to: a).day ?? 0
        return d == 0 ? nil : (d > 0 ? "Tomorrow" : "Yesterday")
    }

    /// True when the sun is below the horizon (solar elevation from the city's coordinates;
    /// falls back to 6:00–19:00 for time-zone-only cities).
    func isNight(at date: Date = Date()) -> Bool {
        guard latitude != 0 || longitude != 0 else {
            var cal = Calendar(identifier: .gregorian)
            cal.timeZone = tz
            let h = cal.component(.hour, from: date)
            return h < 6 || h >= 19
        }
        return City.solarElevation(at: date, latitude: latitude, longitude: longitude) < -0.833
    }

    /// Approximate solar elevation in degrees (NOAA formulas, ±0.5°).
    static func solarElevation(at date: Date, latitude: Double, longitude: Double) -> Double {
        let jd = date.timeIntervalSince1970 / 86400 + 2440587.5
        let n = jd - 2451545.0
        let L = (280.460 + 0.9856474 * n).truncatingRemainder(dividingBy: 360)
        let g = ((357.528 + 0.9856003 * n).truncatingRemainder(dividingBy: 360)) * .pi / 180
        let lambda = (L + 1.915 * sin(g) + 0.020 * sin(2 * g)) * .pi / 180
        let eps = (23.439 - 0.0000004 * n) * .pi / 180
        let decl = asin(sin(eps) * sin(lambda))
        let ra = atan2(cos(eps) * sin(lambda), cos(lambda))
        let gmst = (280.46061837 + 360.98564736629 * n).truncatingRemainder(dividingBy: 360)
        let ha = (gmst + longitude) * .pi / 180 - ra
        let lat = latitude * .pi / 180
        return asin(sin(lat) * sin(decl) + cos(lat) * cos(decl) * cos(ha)) * 180 / .pi
    }

    static let tehran = City(name: "Tehran", country: "Iran", latitude: 35.6892, longitude: 51.389, timeZone: "Asia/Tehran")
}

// MARK: - Weather

enum WeatherCondition: String, Codable, CaseIterable {
    case clear, partlyCloudy, cloudy, fog, drizzle, rain, snow, sleet, thunder

    func symbol(isDay: Bool) -> String {
        switch self {
        case .clear: return isDay ? "sun.max.fill" : "moon.stars.fill"
        case .partlyCloudy: return isDay ? "cloud.sun.fill" : "cloud.moon.fill"
        case .cloudy: return "cloud.fill"
        case .fog: return "cloud.fog.fill"
        case .drizzle: return "cloud.drizzle.fill"
        case .rain: return "cloud.rain.fill"
        case .snow: return "cloud.snow.fill"
        case .sleet: return "cloud.sleet.fill"
        case .thunder: return "cloud.bolt.rain.fill"
        }
    }

    var title: String {
        switch self {
        case .clear: return "Clear"
        case .partlyCloudy: return "Partly cloudy"
        case .cloudy: return "Cloudy"
        case .fog: return "Fog"
        case .drizzle: return "Drizzle"
        case .rain: return "Rain"
        case .snow: return "Snow"
        case .sleet: return "Sleet"
        case .thunder: return "Thunderstorm"
        }
    }

    /// WMO weather interpretation codes (Open-Meteo).
    static func fromWMO(_ code: Int) -> WeatherCondition {
        switch code {
        case 0: return .clear
        case 1, 2: return .partlyCloudy
        case 3: return .cloudy
        case 45, 48: return .fog
        case 51...57: return .drizzle
        case 61...67, 80...82: return .rain
        case 71...77, 85, 86: return .snow
        case 95...99: return .thunder
        default: return .cloudy
        }
    }
}

struct HourPoint: Codable, Hashable {
    var date: Date
    var temperature: Double
    var condition: WeatherCondition
    var isDay: Bool
}

struct DayForecast: Codable, Hashable {
    var date: Date            // local midnight of that day in the city's time zone
    var high: Double
    var low: Double
    var condition: WeatherCondition
    var precipChance: Int?    // %, when the provider gives it
}

struct WeatherSnapshot: Codable, Hashable {
    var temperature: Double
    var feelsLike: Double
    var condition: WeatherCondition
    var isDay: Bool
    var high: Double
    var low: Double
    var humidity: Double?
    var windKmh: Double?
    var hourly: [HourPoint] = []
    var fetchedAt = Date()
    var provider: String = ""
    /// Today + following days (optional so older caches still decode).
    var daily: [DayForecast]? = nil
}

enum TemperatureUnit: String, Codable, CaseIterable {
    case celsius, fahrenheit
    func format(_ c: Double) -> String {
        let v = self == .celsius ? c : c * 9 / 5 + 32
        return "\(Int(v.rounded()))°"
    }
}

// MARK: - Cache written by the app, read by the widgets

struct CachedEvent: Codable, Hashable {
    var date: String          // Gregorian yyyy-MM-dd
    var title: String
    var kind: String          // holiday / occasion / calendar / birthday
    var colorHex: String?
    var time: String?
}

struct SharedCache: Codable {
    var events: [CachedEvent] = []
    var weather: [String: WeatherSnapshot] = [:]   // key: city id
    var weatherCities: [City] = []
    var unit: TemperatureUnit = .celsius
    var updated = Date()

    static var url: URL { Prefs.containerURL.appendingPathComponent("widget-cache.json") }

    static func load() -> SharedCache {
        guard let data = try? Data(contentsOf: url),
              let cache = try? JSONDecoder().decode(SharedCache.self, from: data) else { return SharedCache() }
        return cache
    }

    func save() {
        if let data = try? JSONEncoder().encode(self) { try? data.write(to: SharedCache.url, options: .atomic) }
    }

    func events(on date: Date) -> [CachedEvent] {
        let key = CalendarService.iso(date, .gregorian)
        return events.filter { $0.date == key }
    }
}

// MARK: - Date tokens (menubar icon and widgets)

enum DateTokens {
    static let help: [(String, String)] = [
        ("{jd}", "Jalali day"), ("{jdd}", "Jalali day, 2 digits"), ("{jm}", "Jalali month number"),
        ("{jmn}", "Jalali month name"), ("{jy}", "Jalali year"), ("{wd}", "Weekday (Persian)"),
        ("{wde}", "Weekday (English)"), ("{wds}", "Weekday short (English)"),
        ("{gd}", "Gregorian day"), ("{gm}", "Gregorian month number"), ("{gmn}", "Gregorian month"),
        ("{gms}", "Gregorian month short"), ("{gy}", "Gregorian year"),
        ("{hd}", "Hijri day"), ("{hm}", "Hijri month number"), ("{hmn}", "Hijri month name"), ("{hy}", "Hijri year"),
        ("{time}", "Time 24h"), ("{time12}", "Time 12h"),
    ]

    static func format(_ template: String, date: Date = Date(), persianDigits: Bool) -> String {
        let j = CalendarService.ymd(date, .jalali)
        let g = CalendarService.ymd(date, .gregorian)
        let h = CalendarService.ymd(date, .islamic)
        let en = Locale(identifier: "en_US")
        let tf = DateFormatter()
        tf.locale = en
        func time(_ f: String) -> String { tf.dateFormat = f; return tf.string(from: date) }

        let values: [String: String] = [
            "{jd}": "\(j.day)", "{jdd}": String(format: "%02d", j.day), "{jm}": "\(j.month)",
            "{jmn}": CalendarKind.jalali.monthNames[j.month - 1], "{jy}": "\(j.year)",
            "{wd}": CalendarService.weekday(date, .jalali),
            "{wde}": CalendarService.weekday(date, .gregorian),
            "{wds}": CalendarService.format(date, .gregorian, "EEE", locale: en),
            "{gd}": "\(g.day)", "{gm}": "\(g.month)", "{gmn}": CalendarKind.gregorian.monthNames[g.month - 1],
            "{gms}": CalendarService.format(date, .gregorian, "MMM", locale: en), "{gy}": "\(g.year)",
            "{hd}": "\(h.day)", "{hm}": "\(h.month)", "{hmn}": CalendarKind.islamic.monthNames[h.month - 1], "{hy}": "\(h.year)",
            "{time}": time("HH:mm"), "{time12}": time("h:mm a"),
        ]
        var out = template
        // Longest tokens first so {jdd} isn't eaten by {jd}.
        for key in values.keys.sorted(by: { $0.count > $1.count }) {
            out = out.replacingOccurrences(of: key, with: values[key]!)
        }
        return persianDigits ? CalendarService.persianDigits(out) : out
    }
}

// MARK: - Daily forecast strip (popover + desktop widgets)

struct DailyForecastStrip: View {
    let days: [DayForecast]
    let city: City
    let unit: TemperatureUnit
    var count = 5
    var compact = false

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(days.prefix(count).enumerated()), id: \.offset) { i, day in
                VStack(spacing: compact ? 2 : 3) {
                    Text(Self.label(day.date, city: city, first: i == 0))
                        .font(.app(size: compact ? 9 : 10, weight: .semibold)).lineLimit(1).minimumScaleFactor(0.7)
                    Image(systemName: day.condition.symbol(isDay: true)).symbolRenderingMode(.multicolor)
                        .font(.app(size: compact ? 12 : 15)).frame(height: compact ? 14 : 18)
                    Text(day.precipChance.map { $0 >= 20 ? "\(CalendarService.persianDigits($0))٪" : " " } ?? " ")
                        .font(.app(size: 8, weight: .medium)).foregroundStyle(Color(red: 0.6, green: 0.88, blue: 1))
                    Text(unit.format(day.high)).font(.app(size: compact ? 10 : 11, weight: .semibold))
                    Text(unit.format(day.low)).font(.app(size: compact ? 9 : 10)).opacity(0.6)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .environment(\.layoutDirection, .rightToLeft)
    }

    static func label(_ date: Date, city: City, first: Bool) -> String {
        if first {
            var cal = Calendar(identifier: .gregorian)
            cal.timeZone = city.tz
            if cal.isDateInToday(date) { return "امروز" }
        }
        // Weekday of that local day, in Persian.
        let f = DateFormatter()
        f.locale = Locale(identifier: "fa_IR")
        f.timeZone = city.tz
        f.dateFormat = "EEEE"
        return f.string(from: date.addingTimeInterval(12 * 3600))
    }
}

/// Apple-Weather-style list: day · icon · rain % · low ▬▬ high (right-to-left).
struct DailyForecastList: View {
    let days: [DayForecast]
    let city: City
    let unit: TemperatureUnit
    var count = 5

    var body: some View {
        let list = Array(days.prefix(count))
        let lo = list.map(\.low).min() ?? 0, hi = list.map(\.high).max() ?? 1
        VStack(spacing: 0) {
            ForEach(Array(list.enumerated()), id: \.offset) { i, day in
                HStack(spacing: 8) {
                    Text(DailyForecastStrip.label(day.date, city: city, first: i == 0))
                        .font(.app(size: 12, weight: .semibold)).frame(width: 62, alignment: .leading)
                    VStack(spacing: 0) {
                        Image(systemName: day.condition.symbol(isDay: true)).symbolRenderingMode(.multicolor).font(.app(size: 14))
                        if let p = day.precipChance, p >= 20 {
                            Text("\(CalendarService.persianDigits(p))٪").font(.app(size: 8, weight: .semibold)).foregroundStyle(Color(red: 0.6, green: 0.88, blue: 1))
                        }
                    }
                    .frame(width: 28)
                    Text(unit.format(day.low)).font(.app(size: 12)).opacity(0.65).frame(width: 30, alignment: .trailing)
                    GeometryReader { g in
                        let span = max(hi - lo, 1)
                        let a = (day.low - lo) / span, b = (day.high - lo) / span
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.primary.opacity(0.15))
                            Capsule().fill(LinearGradient(colors: [.teal, .yellow, .orange], startPoint: .leading, endPoint: .trailing))
                                .frame(width: max(6, g.size.width * (b - a)))
                                .offset(x: g.size.width * a)
                        }
                        .frame(height: 4).frame(maxHeight: .infinity)
                    }
                    .environment(\.layoutDirection, .leftToRight)
                    .scaleEffect(x: -1)   // cold on the right, warm on the left, matching RTL reading
                    Text(unit.format(day.high)).font(.app(size: 12, weight: .semibold)).frame(width: 30, alignment: .leading)
                }
                .frame(maxHeight: .infinity)
            }
        }
        .environment(\.layoutDirection, .rightToLeft)
    }
}
