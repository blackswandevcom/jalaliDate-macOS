import CoreLocation
import SwiftUI

enum WeatherProviderID: String, Codable, CaseIterable, Identifiable {
    case openMeteo, metNorway, wttr, openWeatherMap, weatherAPI
    var id: String { rawValue }
    var title: String {
        switch self {
        case .openMeteo: return "Open-Meteo"
        case .metNorway: return "MET Norway (yr.no)"
        case .wttr: return "wttr.in"
        case .openWeatherMap: return "OpenWeatherMap"
        case .weatherAPI: return "WeatherAPI.com"
        }
    }
    var needsKey: Bool { self == .openWeatherMap || self == .weatherAPI }
    var detail: String {
        switch self {
        case .openMeteo: return "Free, no account. Recommended."
        case .metNorway: return "Free, Norwegian Meteorological Institute."
        case .wttr: return "Free, community service; can be slow."
        case .openWeatherMap: return "Needs a free API key from openweathermap.org."
        case .weatherAPI: return "Needs a free API key from weatherapi.com."
        }
    }
}

struct WeatherSettings: Codable, Equatable {
    var provider: WeatherProviderID = .openMeteo
    var apiKeys: [String: String] = [:]
    var unit: TemperatureUnit = .celsius
    /// City that drives the "Live weather" theme.
    var themeCity: City? = .tehran
}

enum WeatherError: LocalizedError {
    case missingKey, badResponse
    var errorDescription: String? {
        switch self {
        case .missingKey: return "This provider needs an API key."
        case .badResponse: return "Unexpected response from the weather service."
        }
    }
}

// MARK: - Providers

enum WeatherProviders {
    static func fetch(_ provider: WeatherProviderID, city: City, key: String?) async throws -> WeatherSnapshot {
        switch provider {
        case .openMeteo: return try await openMeteo(city)
        case .metNorway: return try await metNorway(city)
        case .wttr: return try await wttr(city)
        case .openWeatherMap: return try await openWeatherMap(city, key: key)
        case .weatherAPI: return try await weatherAPI(city, key: key)
        }
    }

    private static func json(_ url: URL, headers: [String: String] = [:]) async throws -> [String: Any] {
        var req = URLRequest(url: url, timeoutInterval: 20)
        req.setValue("jDate/8.0 (macOS menubar calendar; https://amirhp.com)", forHTTPHeaderField: "User-Agent")
        headers.forEach { req.setValue($1, forHTTPHeaderField: $0) }
        let (data, response) = try await URLSession.shared.data(for: req)
        guard (response as? HTTPURLResponse)?.statusCode ?? 0 < 400,
              let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { throw WeatherError.badResponse }
        return obj
    }

    private static func d(_ any: Any?) -> Double? {
        if let v = any as? Double { return v }
        if let v = any as? Int { return Double(v) }
        if let v = any as? String { return Double(v) }
        return nil
    }

    // Open-Meteo
    static func openMeteo(_ c: City) async throws -> WeatherSnapshot {
        let url = URL(string: "https://api.open-meteo.com/v1/forecast?latitude=\(c.latitude)&longitude=\(c.longitude)&current=temperature_2m,apparent_temperature,relative_humidity_2m,weather_code,is_day,wind_speed_10m&hourly=temperature_2m,weather_code,is_day&daily=temperature_2m_max,temperature_2m_min,weather_code,precipitation_probability_max&timezone=GMT&forecast_days=7")!
        let o = try await json(url)
        guard let cur = o["current"] as? [String: Any], let daily = o["daily"] as? [String: Any],
              let hourly = o["hourly"] as? [String: Any] else { throw WeatherError.badResponse }
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "GMT")
        f.dateFormat = "yyyy-MM-dd'T'HH:mm"
        let times = (hourly["time"] as? [String] ?? []).compactMap { f.date(from: $0) }
        let temps = hourly["temperature_2m"] as? [Any] ?? []
        let codes = hourly["weather_code"] as? [Any] ?? []
        let days = hourly["is_day"] as? [Any] ?? []
        var points: [HourPoint] = []
        let now = Date()
        for (i, t) in times.enumerated() where t >= now.addingTimeInterval(-3600) && points.count < 12 {
            points.append(HourPoint(date: t, temperature: d(temps[safe: i]) ?? 0,
                                    condition: .fromWMO(Int(d(codes[safe: i]) ?? 0)), isDay: (d(days[safe: i]) ?? 1) == 1))
        }
        // Re-bucket the hourly data by the city's local day (the request is in GMT).
        var dayList = dailyBuckets(c, times.enumerated().map { (i, t) in
            (t, d(temps[safe: i]) ?? 0, WeatherCondition.fromWMO(Int(d(codes[safe: i]) ?? 0)))
        })
        let probs = (daily["precipitation_probability_max"] as? [Any] ?? []).map { d($0).map(Int.init) }
        for i in dayList.indices where i < probs.count { dayList[i].precipChance = probs[i] }
        let today = dayList.first
        return WeatherSnapshot(temperature: d(cur["temperature_2m"]) ?? 0,
                               feelsLike: d(cur["apparent_temperature"]) ?? 0,
                               condition: .fromWMO(Int(d(cur["weather_code"]) ?? 0)),
                               isDay: (d(cur["is_day"]) ?? 1) == 1,
                               high: today?.high ?? d((daily["temperature_2m_max"] as? [Any])?.first) ?? 0,
                               low: today?.low ?? d((daily["temperature_2m_min"] as? [Any])?.first) ?? 0,
                               humidity: d(cur["relative_humidity_2m"]), windKmh: d(cur["wind_speed_10m"]),
                               hourly: points, provider: "Open-Meteo", daily: dayList)
    }

    /// Groups (time, temperature, condition) samples into the city's local days: high/low and the
    /// most common daytime condition (rain/snow/thunder win when they cover 3+ daytime hours).
    static func dailyBuckets(_ c: City, _ samples: [(Date, Double, WeatherCondition)]) -> [DayForecast] {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = c.tz
        let today = cal.startOfDay(for: Date())
        var groups: [Date: [(Date, Double, WeatherCondition)]] = [:]
        for s in samples {
            let day = cal.startOfDay(for: s.0)
            guard day >= today else { continue }
            groups[day, default: []].append(s)
        }
        return groups.keys.sorted().prefix(7).compactMap { day in
            let list = groups[day]!
            guard list.count >= 2 || day == today else { return nil }
            let daytime = list.filter { (8...18).contains(cal.component(.hour, from: $0.0)) }
            let pool = (daytime.isEmpty ? list : daytime).map(\.2)
            var counts: [WeatherCondition: Int] = [:]
            pool.forEach { counts[$0, default: 0] += 1 }
            let wet: [WeatherCondition] = [.thunder, .snow, .sleet, .rain, .drizzle]
            let hours = daytime.isEmpty ? list.count : daytime.count
            let need = hours >= 6 ? 3 : 1
            let cond = wet.first { (counts[$0] ?? 0) >= need }
                ?? counts.max { a, b in a.value == b.value ? a.key.rawValue > b.key.rawValue : a.value < b.value }?.key ?? .cloudy
            let temps = list.map(\.1)
            return DayForecast(date: day, high: temps.max() ?? 0, low: temps.min() ?? 0, condition: cond, precipChance: nil)
        }
    }

    // MET Norway
    static func metNorway(_ c: City) async throws -> WeatherSnapshot {
        let url = URL(string: String(format: "https://api.met.no/weatherapi/locationforecast/2.0/compact?lat=%.4f&lon=%.4f", c.latitude, c.longitude))!
        let o = try await json(url)
        guard let props = o["properties"] as? [String: Any], let series = props["timeseries"] as? [[String: Any]],
              !series.isEmpty else { throw WeatherError.badResponse }
        let iso = ISO8601DateFormatter()
        func cond(_ s: String?) -> WeatherCondition {
            let s = s ?? "cloudy"
            if s.contains("thunder") { return .thunder }
            if s.contains("sleet") { return .sleet }
            if s.contains("snow") { return .snow }
            if s.contains("drizzle") || s.hasPrefix("light") { return .drizzle }
            if s.contains("rain") { return .rain }
            if s.contains("fog") { return .fog }
            if s.hasPrefix("clearsky") { return .clear }
            if s.hasPrefix("fair") || s.hasPrefix("partlycloudy") { return .partlyCloudy }
            return .cloudy
        }
        struct Row { var date: Date; var temp: Double; var hum: Double?; var wind: Double?; var cond: WeatherCondition }
        let rows: [Row] = series.compactMap { e in
            guard let date = iso.date(from: e["time"] as? String ?? "") else { return nil }
            let data = e["data"] as? [String: Any]
            let det = (data?["instant"] as? [String: Any])?["details"] as? [String: Any]
            func sym(_ k: String) -> String? { ((data?[k] as? [String: Any])?["summary"] as? [String: Any])?["symbol_code"] as? String }
            return Row(date: date, temp: d(det?["air_temperature"]) ?? 0, hum: d(det?["relative_humidity"]),
                       wind: d(det?["wind_speed"]), cond: cond(sym("next_1_hours") ?? sym("next_6_hours")))
        }
        // The series starts at the top of the current hour; pick the sample closest to now.
        let nowDate = Date()
        guard let now = rows.min(by: { abs($0.date.timeIntervalSince(nowDate)) < abs($1.date.timeIntervalSince(nowDate)) }) else { throw WeatherError.badResponse }
        let days = dailyBuckets(c, rows.map { ($0.date, $0.temp, $0.cond) })
        let today = days.first
        let upcoming = rows.filter { $0.date >= nowDate.addingTimeInterval(-3600) }
        return WeatherSnapshot(temperature: now.temp, feelsLike: now.temp, condition: now.cond, isDay: !c.isNight(at: nowDate),
                               high: max(today?.high ?? now.temp, now.temp), low: min(today?.low ?? now.temp, now.temp),
                               humidity: now.hum, windKmh: now.wind.map { $0 * 3.6 },
                               hourly: upcoming.prefix(12).map { HourPoint(date: $0.date, temperature: $0.temp, condition: $0.cond, isDay: !c.isNight(at: $0.date)) },
                               provider: "MET Norway", daily: days)
    }

    // wttr.in
    static func wttr(_ c: City) async throws -> WeatherSnapshot {
        let url = URL(string: String(format: "https://wttr.in/%.4f,%.4f?format=j1", c.latitude, c.longitude))!
        let o = try await json(url)
        guard let cur = (o["current_condition"] as? [[String: Any]])?.first,
              let today = (o["weather"] as? [[String: Any]])?.first else { throw WeatherError.badResponse }
        func cond(_ code: Int) -> WeatherCondition {
            switch code {
            case 113: return .clear
            case 116: return .partlyCloudy
            case 119, 122: return .cloudy
            case 143, 248, 260: return .fog
            case 263, 266, 281, 284, 293, 296: return .drizzle
            case 176, 299...314, 353...359: return .rain
            case 179, 182, 185, 317, 320, 350, 362...377: return .sleet
            case 227, 230, 323...338, 368, 371, 392, 395: return .snow
            case 200, 386, 389: return .thunder
            default: return .cloudy
            }
        }
        let night = c.isNight()
        var points: [HourPoint] = []
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = c.tz
        let start = cal.startOfDay(for: Date())
        for h in today["hourly"] as? [[String: Any]] ?? [] {
            let minutes = Int(d(h["time"]) ?? 0)
            let date = start.addingTimeInterval(Double(minutes / 100 * 3600))
            guard date > Date().addingTimeInterval(-3 * 3600) else { continue }
            points.append(HourPoint(date: date, temperature: d(h["tempC"]) ?? 0,
                                    condition: cond(Int(d(h["weatherCode"]) ?? 116)), isDay: !c.isNight(at: date)))
        }
        let dayFormatter = DateFormatter()
        dayFormatter.locale = Locale(identifier: "en_US_POSIX")
        dayFormatter.timeZone = c.tz
        dayFormatter.dateFormat = "yyyy-MM-dd"
        let daily: [DayForecast] = (o["weather"] as? [[String: Any]] ?? []).compactMap { w in
            guard let date = dayFormatter.date(from: w["date"] as? String ?? "") else { return nil }
            let hours = w["hourly"] as? [[String: Any]] ?? []
            let noon = hours.first { Int(d($0["time"]) ?? 0) == 1200 } ?? hours.first
            let chance = hours.compactMap { d($0["chanceofrain"]) }.max().map(Int.init)
            return DayForecast(date: date, high: d(w["maxtempC"]) ?? 0, low: d(w["mintempC"]) ?? 0,
                               condition: cond(Int(d(noon?["weatherCode"]) ?? 116)), precipChance: chance)
        }
        return WeatherSnapshot(temperature: d(cur["temp_C"]) ?? 0, feelsLike: d(cur["FeelsLikeC"]) ?? 0,
                               condition: cond(Int(d(cur["weatherCode"]) ?? 116)), isDay: !night,
                               high: d(today["maxtempC"]) ?? 0, low: d(today["mintempC"]) ?? 0,
                               humidity: d(cur["humidity"]), windKmh: d(cur["windspeedKmph"]),
                               hourly: points, provider: "wttr.in", daily: daily)
    }

    // OpenWeatherMap
    static func openWeatherMap(_ c: City, key: String?) async throws -> WeatherSnapshot {
        guard let key, !key.isEmpty else { throw WeatherError.missingKey }
        let base = "https://api.openweathermap.org/data/2.5"
        let q = "lat=\(c.latitude)&lon=\(c.longitude)&units=metric&appid=\(key)"
        let o = try await json(URL(string: "\(base)/weather?\(q)")!)
        let f = try? await json(URL(string: "\(base)/forecast?\(q)")!)
        func cond(_ id: Int) -> WeatherCondition {
            switch id {
            case 200..<300: return .thunder
            case 300..<400: return .drizzle
            case 511, 611...616: return .sleet
            case 500..<600: return .rain
            case 600..<700: return .snow
            case 700..<800: return .fog
            case 800: return .clear
            case 801, 802: return .partlyCloudy
            default: return .cloudy
            }
        }
        guard let main = o["main"] as? [String: Any], let w = (o["weather"] as? [[String: Any]])?.first else { throw WeatherError.badResponse }
        let icon = w["icon"] as? String ?? "d"
        let points: [HourPoint] = (f?["list"] as? [[String: Any]] ?? []).map { item in
            let m = item["main"] as? [String: Any]
            let ww = (item["weather"] as? [[String: Any]])?.first
            return HourPoint(date: Date(timeIntervalSince1970: d(item["dt"]) ?? 0), temperature: d(m?["temp"]) ?? 0,
                             condition: cond(Int(d(ww?["id"]) ?? 800)), isDay: ((ww?["icon"] as? String) ?? "d").hasSuffix("d"))
        }
        let days = dailyBuckets(c, points.map { ($0.date, $0.temperature, $0.condition) })
        let temps = points.prefix(8).map(\.temperature) + [d(main["temp"]) ?? 0]
        return WeatherSnapshot(temperature: d(main["temp"]) ?? 0, feelsLike: d(main["feels_like"]) ?? 0,
                               condition: cond(Int(d(w["id"]) ?? 800)), isDay: icon.hasSuffix("d"),
                               high: max(d(main["temp_max"]) ?? 0, temps.max() ?? 0), low: min(d(main["temp_min"]) ?? 0, temps.min() ?? 0),
                               humidity: d(main["humidity"]), windKmh: d((o["wind"] as? [String: Any])?["speed"]).map { $0 * 3.6 },
                               hourly: Array(points.prefix(8)), provider: "OpenWeatherMap", daily: days)
    }

    // WeatherAPI.com
    static func weatherAPI(_ c: City, key: String?) async throws -> WeatherSnapshot {
        guard let key, !key.isEmpty else { throw WeatherError.missingKey }
        let o = try await json(URL(string: "https://api.weatherapi.com/v1/forecast.json?key=\(key)&q=\(c.latitude),\(c.longitude)&days=7")!)
        func cond(_ code: Int) -> WeatherCondition {
            switch code {
            case 1000: return .clear
            case 1003: return .partlyCloudy
            case 1006, 1009: return .cloudy
            case 1030, 1135, 1147: return .fog
            case 1150, 1153, 1168, 1171: return .drizzle
            case 1063, 1180...1201, 1240...1246: return .rain
            case 1069, 1072, 1198, 1204...1207, 1237, 1249...1252, 1261, 1264: return .sleet
            case 1066, 1114, 1117, 1210...1225, 1255, 1258: return .snow
            case 1087, 1273...1282: return .thunder
            default: return .cloudy
            }
        }
        guard let cur = o["current"] as? [String: Any],
              let days = (o["forecast"] as? [String: Any])?["forecastday"] as? [[String: Any]],
              let day = days.first?["day"] as? [String: Any] else { throw WeatherError.badResponse }
        let now = Date().timeIntervalSince1970 - 3600
        let points: [HourPoint] = days.flatMap { ($0["hour"] as? [[String: Any]]) ?? [] }
            .filter { (d($0["time_epoch"]) ?? 0) >= now }.prefix(12).map { h in
                HourPoint(date: Date(timeIntervalSince1970: d(h["time_epoch"]) ?? 0), temperature: d(h["temp_c"]) ?? 0,
                          condition: cond(Int(d((h["condition"] as? [String: Any])?["code"]) ?? 1000)),
                          isDay: (d(h["is_day"]) ?? 1) == 1)
            }
        return WeatherSnapshot(temperature: d(cur["temp_c"]) ?? 0, feelsLike: d(cur["feelslike_c"]) ?? 0,
                               condition: cond(Int(d((cur["condition"] as? [String: Any])?["code"]) ?? 1000)),
                               isDay: (d(cur["is_day"]) ?? 1) == 1,
                               high: d(day["maxtemp_c"]) ?? 0, low: d(day["mintemp_c"]) ?? 0,
                               humidity: d(cur["humidity"]), windKmh: d(cur["wind_kph"]),
                               hourly: points, provider: "WeatherAPI.com",
                               daily: days.compactMap { fd in
                                   guard let day = fd["day"] as? [String: Any], let e = d(fd["date_epoch"]) else { return nil }
                                   var cal = Calendar(identifier: .gregorian)
                                   cal.timeZone = c.tz
                                   return DayForecast(date: cal.startOfDay(for: Date(timeIntervalSince1970: e + 43200)),
                                                      high: d(day["maxtemp_c"]) ?? 0, low: d(day["mintemp_c"]) ?? 0,
                                                      condition: cond(Int(d((day["condition"] as? [String: Any])?["code"]) ?? 1000)),
                                                      precipChance: d(day["daily_chance_of_rain"]).map(Int.init))
                               })
    }
}

extension Array {
    subscript(safe i: Int) -> Element? { indices.contains(i) ? self[i] : nil }
}

// MARK: - City search

enum CitySearch {
    static func search(_ query: String) async -> [City] {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard q.count >= 2, let enc = q.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://geocoding-api.open-meteo.com/v1/search?name=\(enc)&count=10&language=en&format=json"),
              let (data, _) = try? await URLSession.shared.data(from: url),
              let o = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let results = o["results"] as? [[String: Any]] else { return offline(q) }
        return results.compactMap { r in
            guard let name = r["name"] as? String, let lat = r["latitude"] as? Double, let lon = r["longitude"] as? Double else { return nil }
            let region = [r["admin1"] as? String, r["country"] as? String].compactMap { $0 }.joined(separator: ", ")
            return City(name: name, country: region, latitude: lat, longitude: lon,
                        timeZone: r["timezone"] as? String ?? TimeZone.current.identifier)
        }
    }

    /// Time-zone-only matches (works offline; no coordinates, so clocks only).
    static func offline(_ q: String) -> [City] {
        TimeZone.knownTimeZoneIdentifiers.filter { $0.localizedCaseInsensitiveContains(q.replacingOccurrences(of: " ", with: "_")) }
            .prefix(10).map { id in
                City(name: id.split(separator: "/").last.map { $0.replacingOccurrences(of: "_", with: " ") } ?? id,
                     country: id, timeZone: id)
            }
    }
}

// MARK: - Current location

@MainActor
final class LocationFetcher: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var continuation: CheckedContinuation<CLLocation?, Never>?

    func current() async -> City? {
        let location: CLLocation? = await withCheckedContinuation { c in
            continuation = c
            manager.delegate = self
            manager.desiredAccuracy = kCLLocationAccuracyKilometer
            manager.requestWhenInUseAuthorization()
            manager.requestLocation()
        }
        guard let location else { return nil }
        let placemark = try? await CLGeocoder().reverseGeocodeLocation(location).first
        return City(name: placemark?.locality ?? "My location", country: placemark?.country ?? "",
                    latitude: location.coordinate.latitude, longitude: location.coordinate.longitude,
                    timeZone: placemark?.timeZone?.identifier ?? TimeZone.current.identifier)
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let loc = locations.last
        Task { @MainActor in self.finish(loc) }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in self.finish(nil) }
    }

    private func finish(_ loc: CLLocation?) {
        continuation?.resume(returning: loc)
        continuation = nil
    }
}

// MARK: - Store

@MainActor
final class WeatherStore: ObservableObject {
    @Published var settings: WeatherSettings { didSet { Prefs.save(settings, Prefs.weatherSettingsKey) } }
    @Published private(set) var snapshots: [UUID: WeatherSnapshot] = [:]
    @Published private(set) var errors: [UUID: String] = [:]
    @Published private(set) var notice: String?
    @Published private(set) var isLoading = false

    /// Cities used by weather widgets (set by the app from the popover layout).
    var widgetCities: [City] = []
    var allCities: [City] {
        var seen = Set<UUID>()
        return ([settings.themeCity].compactMap { $0 } + widgetCities).filter { seen.insert($0.id).inserted }
    }

    private var lastFetch: [UUID: Date] = [:]
    private static var cacheURL: URL { Prefs.containerURL.appendingPathComponent("weather-cache.json") }

    init() {
        settings = Prefs.load(WeatherSettings.self, Prefs.weatherSettingsKey) ?? WeatherSettings()
        if let data = try? Data(contentsOf: Self.cacheURL),
           let cached = try? JSONDecoder().decode([UUID: WeatherSnapshot].self, from: data) {
            snapshots = cached
            for (id, s) in cached { lastFetch[id] = s.fetchedAt }
        }
    }

    var themeSnapshot: WeatherSnapshot? { settings.themeCity.flatMap { snapshots[$0.id] } }

    func format(_ c: Double) -> String { settings.unit.format(c) }

    /// Forecast-only sources (MET Norway) don't know the hours already gone today, so keep the
    /// highest/lowest temperature seen today across fetches, like a full-day high/low.
    private func merged(_ new: WeatherSnapshot, _ city: City) -> WeatherSnapshot {
        var s = new
        s.high = max(s.high, s.temperature)
        s.low = min(s.low, s.temperature)
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = city.tz
        if let old = snapshots[city.id], cal.isDate(old.fetchedAt, inSameDayAs: s.fetchedAt) {
            s.high = max(s.high, old.high, old.temperature)
            s.low = min(s.low, old.low, old.temperature)
        }
        if var days = s.daily, !days.isEmpty, cal.isDate(days[0].date, inSameDayAs: s.fetchedAt) {
            days[0].high = s.high
            days[0].low = s.low
            s.daily = days
        }
        return s
    }

    func refresh(force: Bool = false) async {
        let due = allCities.filter { force || snapshots[$0.id]?.daily == nil
            || (lastFetch[$0.id].map { Date().timeIntervalSince($0) > 30 * 60 } ?? true) }
        guard !due.isEmpty else { return }
        isLoading = true
        notice = nil
        for city in due {
            let provider = settings.provider
            do {
                snapshots[city.id] = merged(try await WeatherProviders.fetch(provider, city: city, key: settings.apiKeys[provider.rawValue]), city)
                errors[city.id] = nil
            } catch {
                // Fall back to the other free sources so widgets never go blank.
                var recovered = false
                for backup in [WeatherProviderID.openMeteo, .metNorway, .wttr] where backup != provider {
                    if let s = try? await WeatherProviders.fetch(backup, city: city, key: nil) {
                        snapshots[city.id] = merged(s, city)
                        notice = "\(provider.title) failed (\(error.localizedDescription)); used \(backup.title) instead."
                        errors[city.id] = nil
                        recovered = true
                        break
                    }
                }
                if !recovered { errors[city.id] = error.localizedDescription }
            }
            lastFetch[city.id] = Date()
        }
        isLoading = false
        if let data = try? JSONEncoder().encode(snapshots) { try? data.write(to: Self.cacheURL, options: .atomic) }
    }
}
