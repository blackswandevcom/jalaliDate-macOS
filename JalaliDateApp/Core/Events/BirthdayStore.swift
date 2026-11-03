import Contacts
import SwiftUI
import UserNotifications

struct Birthday: Codable, Identifiable, Hashable {
    enum Source: String, Codable { case manual, contacts }

    var id = UUID().uuidString
    var name: String
    var calendar: CalendarKind = .jalali
    var month: Int
    var day: Int
    var year: Int?
    var source: Source = .manual
    var note: String = ""

    var dateText: String {
        let monthName = calendar.monthNames[max(0, min(11, month - 1))]
        let y = year.map { " \($0)" } ?? ""
        return calendar == .gregorian ? "\(day) \(monthName)\(y)" : CalendarService.persianDigits("\(day) \(monthName)\(y)")
    }
}

struct BirthdaySettings: Codable, Equatable {
    var useContacts = false
    var notify = true
    var hour = 9
    var minute = 0
    /// Days before the birthday to remind (0 = on the day).
    var leadDays: [Int] = [0, 1]
    var holidayMorningNotice = false
}

@MainActor
final class BirthdayStore: ObservableObject {
    @Published var manual: [Birthday] { didSet { Prefs.save(manual, Prefs.birthdaysKey) } }
    @Published private(set) var contacts: [Birthday] = []
    @Published var settings: BirthdaySettings { didSet { Prefs.save(settings, Prefs.birthdaySettingsKey) } }
    @Published private(set) var contactsStatus = CNContactStore.authorizationStatus(for: .contacts)

    /// Your list plus Contacts, without the copies that synced accounts (iCloud, Google…) leave in Contacts.
    var all: [Birthday] {
        var seen = Set<String>()
        return (manual + (settings.useContacts ? contacts : [])).filter { b in
            let key = "\(b.name.lowercased().trimmingCharacters(in: .whitespaces))|\(b.calendar.rawValue)|\(b.month)|\(b.day)"
            return seen.insert(key).inserted
        }
    }

    init() {
        manual = Prefs.load([Birthday].self, Prefs.birthdaysKey) ?? []
        settings = Prefs.load(BirthdaySettings.self, Prefs.birthdaySettingsKey) ?? BirthdaySettings()
        if settings.useContacts && contactsStatus == .authorized { loadContacts() }
        NotificationCenter.default.addObserver(forName: .CNContactStoreDidChange, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.settings.useContacts else { return }
                self.loadContacts()
            }
        }
    }

    func occurring(on date: Date) -> [Birthday] {
        all.filter { matches($0, date) }
    }

    func matches(_ b: Birthday, _ date: Date) -> Bool {
        let p = CalendarService.ymd(date, b.calendar)
        guard p.month == b.month else { return false }
        if p.day == b.day { return true }
        // 30 Esfand / 29 Feb in a short year: celebrate on the month's last day.
        let last = CalendarService.daysInMonth(year: p.year, month: p.month, b.calendar)
        return b.day > last && p.day == last
    }

    func age(of b: Birthday, on date: Date) -> Int? {
        guard let y = b.year else { return nil }
        return CalendarService.ymd(date, b.calendar).year - y
    }

    func nextOccurrence(_ b: Birthday, from now: Date = Date()) -> Date? {
        let g = Calendar(identifier: .gregorian)
        let start = g.startOfDay(for: now)
        for offset in 0..<400 {
            if let d = g.date(byAdding: .day, value: offset, to: start), matches(b, d) { return d }
        }
        return nil
    }

    // MARK: Contacts

    func enableContacts() async {
        let store = CNContactStore()
        let granted = (try? await store.requestAccess(for: .contacts)) ?? false
        contactsStatus = CNContactStore.authorizationStatus(for: .contacts)
        settings.useContacts = granted
        if granted { loadContacts() }
    }

    func loadContacts() {
        let keys = [CNContactGivenNameKey, CNContactFamilyNameKey, CNContactOrganizationNameKey,
                    CNContactBirthdayKey, CNContactNonGregorianBirthdayKey] as [CNKeyDescriptor]
        Task.detached {
            var found: [Birthday] = []
            let request = CNContactFetchRequest(keysToFetch: keys)
            try? CNContactStore().enumerateContacts(with: request) { contact, _ in
                var name = "\(contact.givenName) \(contact.familyName)".trimmingCharacters(in: .whitespaces)
                if name.isEmpty { name = contact.organizationName }
                if let ng = contact.nonGregorianBirthday, let m = ng.month, let d = ng.day {
                    let kind: CalendarKind = ng.calendar?.identifier == .persian ? .jalali : .islamic
                    found.append(Birthday(id: "c-\(contact.identifier)", name: name, calendar: kind, month: m, day: d,
                                          year: ng.year, source: .contacts))
                } else if let b = contact.birthday, let m = b.month, let d = b.day {
                    found.append(Birthday(id: "c-\(contact.identifier)", name: name, calendar: .gregorian, month: m, day: d,
                                          year: b.year, source: .contacts))
                }
            }
            await MainActor.run { self.contacts = found.sorted { $0.name < $1.name } }
        }
    }
}

/// Schedules birthday and holiday notifications for the next 60 days.
@MainActor
enum Notifier {
    static let prefix = "jdate."

    static func reschedule(birthdays: BirthdayStore, events: EventStore) async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests().map(\.identifier).filter { $0.hasPrefix(prefix) }
        center.removePendingNotificationRequests(withIdentifiers: pending)

        let s = birthdays.settings
        guard s.notify || s.holidayMorningNotice else { return }
        guard (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) == true else { return }

        let g = Calendar(identifier: .gregorian)
        let now = Date()
        let today = g.startOfDay(for: now)
        var requests: [UNNotificationRequest] = []

        for offset in 0..<60 {
            guard let day = g.date(byAdding: .day, value: offset, to: today) else { continue }
            if s.notify {
                for b in birthdays.occurring(on: day) {
                    for lead in s.leadDays.sorted() {
                        guard let fireDay = g.date(byAdding: .day, value: -lead, to: day),
                              let fire = g.date(bySettingHour: s.hour, minute: s.minute, second: 0, of: fireDay),
                              fire > now else { continue }
                        let content = UNMutableNotificationContent()
                        let age = birthdays.age(of: b, on: day).map { " — turns \($0)" } ?? ""
                        content.title = lead == 0 ? "🎂 Today is \(b.name)'s birthday" : "🎂 \(b.name)'s birthday in \(lead) day\(lead == 1 ? "" : "s")"
                        content.body = "\(b.dateText)\(age)"
                        content.sound = .default
                        let comps = g.dateComponents([.year, .month, .day, .hour, .minute], from: fire)
                        requests.append(UNNotificationRequest(identifier: "\(prefix)bd.\(b.id).\(offset).\(lead)", content: content,
                                                              trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)))
                    }
                }
            }
            if s.holidayMorningNotice {
                let holidays = events.events(on: day).filter { $0.kind == .holiday }
                if !holidays.isEmpty, let fire = g.date(bySettingHour: s.hour, minute: s.minute, second: 0, of: day), fire > now {
                    let content = UNMutableNotificationContent()
                    content.title = "Today is a holiday"
                    content.body = holidays.map(\.title).joined(separator: " · ")
                    let comps = g.dateComponents([.year, .month, .day, .hour, .minute], from: fire)
                    requests.append(UNNotificationRequest(identifier: "\(prefix)hol.\(offset)", content: content,
                                                          trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)))
                }
            }
        }
        // macOS keeps at most 64 pending notifications per app.
        for r in requests.prefix(60) { try? await center.add(r) }
    }

    static func sendTest() async {
        let center = UNUserNotificationCenter.current()
        guard (try? await center.requestAuthorization(options: [.alert, .sound])) == true else { return }
        let content = UNMutableNotificationContent()
        content.title = "🎂 jDate test reminder"
        content.body = "Birthday reminders will look like this."
        content.sound = .default
        try? await center.add(UNNotificationRequest(identifier: "\(prefix)test", content: content,
                                                    trigger: UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)))
    }
}
