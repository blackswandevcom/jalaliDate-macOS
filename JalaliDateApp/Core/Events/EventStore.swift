import Combine
import EventKit
import SwiftUI

struct DayEvent: Identifiable, Hashable {
    enum Kind: String { case holiday, occasion, calendar, birthday, feed }

    var id: String
    var title: String
    var subtitle: String?
    var kind: Kind
    var colorHex: String
    var time: String?
    var sort: Int = 0
    /// Video-call link (Google Meet, Zoom, Teams…) found in a calendar event.
    var meetingURL: URL? = nil

    var color: Color { Color(hex: colorHex) }

    var symbol: String {
        switch kind {
        case .holiday: return "flag.fill"
        case .occasion: return "sparkle"
        case .calendar: return "calendar"
        case .birthday: return "gift.fill"
        case .feed: return "globe"
        }
    }
}

struct ICSFeed: Codable, Identifiable, Hashable {
    var id = UUID()
    var name: String
    var url: String
    var enabled = true
    var colorHex = "#8B5CF6"
    /// Feed events are official holidays (replaces the bundled lunar holidays where it has data).
    var holidays = false

    static let googleIran = ICSFeed(
        name: "Google · Holidays in Iran",
        url: "https://calendar.google.com/calendar/ical/fa.ir%23holiday%40group.v.calendar.google.com/public/basic.ics",
        enabled: false, colorHex: "#E11D48", holidays: true)
}

struct EventSettings: Codable, Equatable {
    var showOfficialHolidays = true
    var showOccasions = true
    var showInternational = false
    var showSystemCalendars = false
    /// nil = all calendars.
    var enabledCalendarIDs: [String]?
    var feeds: [ICSFeed] = [.googleIran]
    /// Stored inverted so settings saved by older versions keep it on.
    var hideMeetingLinks: Bool? = nil

    /// Camera icon next to events with a Google Meet / Zoom / Teams link; clicking the event joins.
    var showMeetingLinks: Bool {
        get { hideMeetingLinks != true }
        set { hideMeetingLinks = newValue ? nil : true }
    }
}

@MainActor
final class EventStore: ObservableObject {
    @Published var settings: EventSettings { didSet { Prefs.save(settings, Prefs.eventSettingsKey); invalidate() } }
    /// Bumps whenever any source changes; views observe this.
    @Published private(set) var revision = 0
    @Published private(set) var feedStatus: [UUID: String] = [:]
    @Published private(set) var calendarAccess: EKAuthorizationStatus = EKEventStore.authorizationStatus(for: .event)

    let ekStore = EKEventStore()
    let birthdays: BirthdayStore

    private var feedEvents: [UUID: [String: [DayEvent]]] = [:]   // feed → iso → events
    private var feedRange: [UUID: ClosedRange<String>] = [:]
    private var systemCache: [String: [String: [DayEvent]]] = [:] // yyyy-MM → iso → events
    private var bag = Set<AnyCancellable>()

    init(birthdays: BirthdayStore) {
        self.birthdays = birthdays
        settings = Prefs.load(EventSettings.self, Prefs.eventSettingsKey) ?? EventSettings()
        loadFeedCache()
        birthdays.objectWillChange.sink { [weak self] _ in
            Task { @MainActor in self?.invalidate() }
        }.store(in: &bag)
        NotificationCenter.default.addObserver(forName: .EKEventStoreChanged, object: ekStore, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.invalidate() }
        }
    }

    #if DEBUG
    /// Screenshot helper: extra events shown on today.
    var debugExtra: [DayEvent] = [] { didSet { invalidate() } }
    #endif

    func invalidate() {
        systemCache.removeAll()
        revision += 1
    }

    // MARK: Query

    func events(on date: Date) -> [DayEvent] {
        let iso = CalendarService.iso(date, .gregorian)
        var out: [DayEvent] = []

        let officialFeed = settings.feeds.first { $0.enabled && $0.holidays && feedRange[$0.id]?.contains(iso) == true }
        if settings.showOfficialHolidays || settings.showOccasions || settings.showInternational {
            let opts = IranianEvents.Options(occasions: settings.showOccasions,
                                             international: settings.showInternational,
                                             lunarHolidays: officialFeed == nil)
            for (i, e) in IranianEvents.events(on: date, options: opts).enumerated() {
                if e.holiday && !settings.showOfficialHolidays { continue }
                out.append(DayEvent(id: "pub-\(iso)-\(i)", title: e.title, subtitle: e.holiday ? "Official holiday" : nil,
                                    kind: e.holiday ? .holiday : .occasion,
                                    colorHex: e.holiday ? "#E11D48" : "#F59E0B", sort: e.holiday ? 0 : 2))
            }
        }

        for feed in settings.feeds where feed.enabled {
            for var e in feedEvents[feed.id]?[iso] ?? [] {
                if feed.holidays && !settings.showOfficialHolidays { continue }
                e.colorHex = feed.colorHex
                out.append(e)
            }
        }

        for b in birthdays.occurring(on: date) {
            let age = birthdays.age(of: b, on: date).map { "turns \($0)" }
            out.append(DayEvent(id: "bd-\(b.id)-\(iso)", title: "🎂 \(b.name)", subtitle: age ?? "Birthday",
                                kind: .birthday, colorHex: "#EC4899", sort: 1))
        }

        if settings.showSystemCalendars && hasCalendarAccess {
            out += systemEvents(on: date)
        }
        #if DEBUG
        if Calendar(identifier: .gregorian).isDateInToday(date) { out += debugExtra }
        #endif
        return out.sorted { ($0.sort, $0.time ?? "", $0.title) < ($1.sort, $1.time ?? "", $1.title) }
    }

    struct Marks { var holiday = false; var events = false; var birthday = false }

    func marks(on date: Date) -> Marks {
        let list = events(on: date)
        return Marks(holiday: list.contains { $0.kind == .holiday },
                     events: list.contains { $0.kind == .calendar || $0.kind == .occasion || ($0.kind == .feed) },
                     birthday: list.contains { $0.kind == .birthday })
    }

    func upcoming(days: Int, from now: Date = Date()) -> [(Date, [DayEvent])] {
        let g = Calendar(identifier: .gregorian)
        let start = g.startOfDay(for: now)
        return (0..<days).compactMap { offset in
            guard let d = g.date(byAdding: .day, value: offset, to: start) else { return nil }
            let list = events(on: d)
            return list.isEmpty ? nil : (d, list)
        }
    }

    // MARK: System calendars (EventKit)

    var hasCalendarAccess: Bool {
        calendarAccess == .fullAccess
    }

    func requestCalendarAccess() async {
        _ = try? await ekStore.requestFullAccessToEvents()
        calendarAccess = EKEventStore.authorizationStatus(for: .event)
        if hasCalendarAccess { settings.showSystemCalendars = true }
        invalidate()
    }

    var allCalendars: [EKCalendar] {
        hasCalendarAccess ? ekStore.calendars(for: .event).sorted { ($0.source.title, $0.title) < ($1.source.title, $1.title) } : []
    }

    func isCalendarEnabled(_ cal: EKCalendar) -> Bool {
        settings.enabledCalendarIDs?.contains(cal.calendarIdentifier) ?? true
    }

    func setCalendar(_ cal: EKCalendar, enabled: Bool) {
        var ids = Set(settings.enabledCalendarIDs ?? allCalendars.map(\.calendarIdentifier))
        if enabled { ids.insert(cal.calendarIdentifier) } else { ids.remove(cal.calendarIdentifier) }
        settings.enabledCalendarIDs = Array(ids)
    }

    private func systemEvents(on date: Date) -> [DayEvent] {
        let iso = CalendarService.iso(date, .gregorian)
        let monthKey = String(iso.prefix(7))
        if systemCache[monthKey] == nil { systemCache[monthKey] = loadSystemMonth(containing: date) }
        return systemCache[monthKey]?[iso] ?? []
    }

    private func loadSystemMonth(containing date: Date) -> [String: [DayEvent]] {
        let g = Calendar(identifier: .gregorian)
        guard let start = g.date(from: g.dateComponents([.year, .month], from: date)),
              let end = g.date(byAdding: .month, value: 1, to: start) else { return [:] }
        let cals = allCalendars.filter(isCalendarEnabled)
        guard !cals.isEmpty else { return [:] }
        let predicate = ekStore.predicateForEvents(withStart: start, end: end, calendars: cals)
        let meetings = settings.showMeetingLinks
        let tf = DateFormatter()
        tf.dateFormat = AppSettings.shared.general.clock24h ? "HH:mm" : "h:mm a"
        var out: [String: [DayEvent]] = [:]
        for ev in ekStore.events(matching: predicate) {
            // Multi-day events appear on each day they cover.
            var day = g.startOfDay(for: ev.startDate)
            let last = ev.isAllDay ? g.date(byAdding: .second, value: -1, to: ev.endDate) ?? ev.endDate : ev.endDate
            var guardCount = 0
            let meeting = meetings ? MeetingLink.find(in: ev) : nil
            while day <= (last ?? day) && guardCount < 40 {
                if day >= start && day < end {
                    let iso = CalendarService.iso(day, .gregorian)
                    let color = NSColor(cgColor: ev.calendar.cgColor).map { Color(nsColor: $0).hexString } ?? "#3B82F6"
                    out[iso, default: []].append(DayEvent(
                        id: "ek-\(ev.eventIdentifier ?? UUID().uuidString)-\(iso)",
                        title: ev.title ?? "(No title)",
                        subtitle: ev.calendar.title,
                        kind: .calendar, colorHex: color,
                        time: ev.isAllDay ? nil : tf.string(from: ev.startDate), sort: 3,
                        meetingURL: meeting))
                }
                guard let next = g.date(byAdding: .day, value: 1, to: day) else { break }
                day = next
                guardCount += 1
            }
        }
        return out
    }

    // MARK: ICS feeds

    func refreshFeeds() async {
        for feed in settings.feeds where feed.enabled {
            guard let url = URL(string: feed.url) else { feedStatus[feed.id] = "Invalid URL"; continue }
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                let text = String(decoding: data, as: UTF8.self)
                try? data.write(to: feedCacheURL(feed.id), options: .atomic)
                apply(ics: text, feed: feed)
                feedStatus[feed.id] = "Updated \(Date().formatted(date: .omitted, time: .shortened)) · \(feedEvents[feed.id]?.values.reduce(0) { $0 + $1.count } ?? 0) events"
            } catch {
                feedStatus[feed.id] = "Couldn't load: \(error.localizedDescription)"
            }
        }
        invalidate()
    }

    private func feedCacheURL(_ id: UUID) -> URL {
        Prefs.containerURL.appendingPathComponent("feed-\(id.uuidString).ics")
    }

    private func loadFeedCache() {
        for feed in settings.feeds {
            if let data = try? Data(contentsOf: feedCacheURL(feed.id)) {
                apply(ics: String(decoding: data, as: UTF8.self), feed: feed)
            }
        }
    }

    private func apply(ics: String, feed: ICSFeed) {
        var map: [String: [DayEvent]] = [:]
        for (i, e) in ICSParser.parse(ics).enumerated() {
            map[e.date, default: []].append(DayEvent(
                id: "feed-\(feed.id)-\(i)", title: e.summary, subtitle: feed.name,
                kind: feed.holidays ? .holiday : .feed, colorHex: feed.colorHex,
                time: e.time, sort: feed.holidays ? 0 : 3))
        }
        feedEvents[feed.id] = map
        if let lo = map.keys.min(), let hi = map.keys.max() { feedRange[feed.id] = lo...hi }
    }

    // MARK: Widget cache

    func writeWidgetCache(weather: WeatherStore) {
        var cache = SharedCache()
        for (date, list) in upcoming(days: 60) {
            let iso = CalendarService.iso(date, .gregorian)
            cache.events += list.map { CachedEvent(date: iso, title: $0.title, kind: $0.kind.rawValue, colorHex: $0.colorHex, time: $0.time) }
        }
        cache.weatherCities = weather.allCities
        for c in weather.allCities { if let s = weather.snapshots[c.id] { cache.weather[c.id.uuidString] = s } }
        cache.unit = weather.settings.unit
        cache.save()
    }
}

/// Minimal iCalendar reader: date + summary (+ start time) of each VEVENT.
enum ICSParser {
    struct Item { var date: String; var summary: String; var time: String? }

    static func parse(_ text: String) -> [Item] {
        // Unfold continuation lines.
        let unfolded = text.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\n ", with: "")
        var items: [Item] = []
        var date: String?, time: String?, summary: String?
        var inEvent = false
        for line in unfolded.split(separator: "\n", omittingEmptySubsequences: true) {
            let l = String(line)
            if l == "BEGIN:VEVENT" { inEvent = true; date = nil; time = nil; summary = nil; continue }
            if l == "END:VEVENT" {
                if let date, let summary { items.append(Item(date: date, summary: summary, time: time)) }
                inEvent = false
                continue
            }
            guard inEvent, let colon = l.firstIndex(of: ":") else { continue }
            let key = l[..<colon], value = String(l[l.index(after: colon)...])
            if key.hasPrefix("DTSTART") {
                let digits = value.filter(\.isNumber)
                guard digits.count >= 8 else { continue }
                let y = digits.prefix(4), m = digits.dropFirst(4).prefix(2), d = digits.dropFirst(6).prefix(2)
                date = "\(y)-\(m)-\(d)"
                if digits.count >= 12 {
                    let hh = digits.dropFirst(8).prefix(2), mm = digits.dropFirst(10).prefix(2)
                    time = "\(hh):\(mm)"
                }
            } else if key.hasPrefix("SUMMARY") {
                summary = value.replacingOccurrences(of: "\\,", with: ",").replacingOccurrences(of: "\\;", with: ";")
            }
        }
        return items
    }
}
