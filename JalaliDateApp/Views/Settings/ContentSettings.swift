import EventKit
import SwiftUI

// MARK: - Events & calendars

struct EventsSettingsView: View {
    @ObservedObject var model: AppModel
    @ObservedObject var events: EventStore
    @State private var newFeedName = ""
    @State private var newFeedURL = ""
    @State private var refreshing = false

    var body: some View {
        Form {
            Section {
                Toggle("Official holidays (red days)", isOn: $events.settings.showOfficialHolidays)
                Toggle("Iranian occasions (Yalda, Chaharshanbe Suri, Mehregan, poets' days…)", isOn: $events.settings.showOccasions)
                Toggle("International days (New Year, Christmas, Valentine's…)", isOn: $events.settings.showInternational)
            } header: {
                Text("Iranian public calendar")
            } footer: {
                Text("Built in and works offline. Lunar holidays follow the Hijri calendar, including your offset in General.")
                    .font(.app(.caption)).foregroundStyle(.secondary)
            }

            Section {
                Toggle("Show events from macOS Calendar", isOn: Binding(
                    get: { events.settings.showSystemCalendars },
                    set: { on in
                        events.settings.showSystemCalendars = on
                        if on && !events.hasCalendarAccess { Task { await events.requestCalendarAccess() } }
                    }))
                if events.settings.showSystemCalendars {
                    if events.hasCalendarAccess {
                        let cals = events.allCalendars
                        if cals.isEmpty {
                            Text("No calendars found.").foregroundStyle(.secondary)
                        }
                        ForEach(Dictionary(grouping: cals, by: { $0.source.title }).sorted(by: { $0.key < $1.key }), id: \.key) { source, list in
                            Text(source).font(.app(.caption).weight(.semibold)).foregroundStyle(.secondary)
                            ForEach(list, id: \.calendarIdentifier) { cal in
                                Toggle(isOn: Binding(get: { events.isCalendarEnabled(cal) }, set: { events.setCalendar(cal, enabled: $0) })) {
                                    HStack(spacing: 6) {
                                        Circle().fill(Color(cgColor: cal.cgColor)).frame(width: 9, height: 9)
                                        Text(cal.title)
                                    }
                                }
                            }
                        }
                    } else {
                        HStack {
                            Text(events.calendarAccess == .denied ? "Calendar access was denied." : "jDate needs access to your calendars.")
                                .foregroundStyle(.secondary)
                            Spacer()
                            if events.calendarAccess == .denied {
                                Button("Open Privacy Settings") {
                                    NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars")!)
                                }
                            } else {
                                Button("Allow access") { Task { await events.requestCalendarAccess() } }
                            }
                        }
                    }
                }
            } header: {
                Text("Google Calendar, iCloud & other calendars")
            } footer: {
                VStack(alignment: .leading, spacing: 4) {
                    Text("To see your Google Calendar: System Settings › Internet Accounts › Add Account › Google, and turn on Calendars. Its calendars then appear in the list above.")
                    Button("Open Internet Accounts") {
                        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.Internet-Accounts-Settings.extension")!)
                    }
                    .buttonStyle(.link)
                }
                .font(.app(.caption)).foregroundStyle(.secondary)
            }

            Section {
                ForEach($events.settings.feeds) { $feed in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Toggle("", isOn: $feed.enabled).labelsHidden().toggleStyle(.checkbox)
                                .help("Show this feed")
                            ColorPicker("", selection: Binding(get: { Color(hex: feed.colorHex) }, set: { feed.colorHex = $0.hexString }),
                                        supportsOpacity: false).labelsHidden().frame(width: 24)
                            TextField("", text: $feed.name, prompt: Text("Name")).labelsHidden()
                                .textFieldStyle(.plain).fontWeight(.medium)
                            Spacer()
                            Toggle("Holidays", isOn: $feed.holidays).toggleStyle(.checkbox)
                                .help("Mark this feed's events as red holidays")
                            Button(role: .destructive) {
                                events.settings.feeds.removeAll { $0.id == feed.id }
                            } label: { Image(systemName: "trash") }
                                .buttonStyle(.borderless)
                        }
                        Text(feed.url).font(.app(.caption)).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
                        if let status = events.feedStatus[feed.id] {
                            Text(status).font(.app(.caption2)).foregroundStyle(.tertiary)
                        }
                    }
                }
                HStack {
                    TextField("", text: $newFeedName, prompt: Text("Name")).labelsHidden()
                        .textFieldStyle(.roundedBorder).frame(width: 140)
                    TextField("", text: $newFeedURL, prompt: Text("https://… .ics or webcal://…")).labelsHidden()
                        .textFieldStyle(.roundedBorder)
                    Button("Add") {
                        let url = newFeedURL.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: "webcal://", with: "https://")
                        guard URL(string: url) != nil, !url.isEmpty else { return }
                        events.settings.feeds.append(ICSFeed(name: newFeedName.isEmpty ? "Calendar" : newFeedName, url: url))
                        newFeedName = ""; newFeedURL = ""
                        Task { await events.refreshFeeds() }
                    }
                    .disabled(newFeedURL.isEmpty)
                }
                HStack {
                    if !events.settings.feeds.contains(where: { $0.url == ICSFeed.googleIran.url }) {
                        Button("Add “Holidays in Iran” (Google)") { events.settings.feeds.append(.googleIran) }
                    }
                    Spacer()
                    if refreshing { ProgressView().controlSize(.small) }
                    Button("Refresh now") {
                        refreshing = true
                        Task { await events.refreshFeeds(); refreshing = false }
                    }
                }
            } header: {
                Text("Public calendar subscriptions (ICS)")
            } footer: {
                Text("Any public iCalendar link works — e.g. a Google calendar's “Public address in iCal format”. Feeds refresh at launch and when you press Refresh.")
                    .font(.app(.caption)).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Birthdays

struct BirthdaysView: View {
    @ObservedObject var model: AppModel
    @ObservedObject var store: BirthdayStore
    @State private var draft = Birthday(name: "", month: 1, day: 1)
    @State private var editingID: String?
    @State private var testSent = false

    var body: some View {
        Form {
            Section(editingID == nil ? "Add a birthday" : "Edit birthday") {
                TextField("Name", text: $draft.name)
                Picker("Calendar", selection: $draft.calendar) {
                    ForEach(CalendarKind.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                HStack {
                    Picker("Month", selection: $draft.month) {
                        ForEach(1...12, id: \.self) { Text("\($0) · \(draft.calendar.monthNames[$0 - 1])").tag($0) }
                    }
                    Picker("Day", selection: $draft.day) {
                        ForEach(1...31, id: \.self) { Text("\($0)").tag($0) }
                    }
                    .frame(width: 110)
                    TextField("Year", value: $draft.year, format: .number.grouping(.never), prompt: Text("optional"))
                        .frame(width: 140)
                }
                TextField("Note", text: $draft.note)
                HStack {
                    if editingID != nil {
                        Button("Cancel") { reset() }
                    }
                    Spacer()
                    Button(editingID == nil ? "Add" : "Save") { save() }
                        .keyboardShortcut(.defaultAction)
                        .disabled(draft.name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }

            Section("My list (\(store.manual.count))") {
                if store.manual.isEmpty {
                    Text("No birthdays yet.").foregroundStyle(.secondary)
                }
                ForEach(sorted(store.manual)) { b in row(b, editable: true) }
            }

            Section {
                Toggle("Include birthdays from Contacts", isOn: Binding(
                    get: { store.settings.useContacts },
                    set: { on in
                        if on { Task { await store.enableContacts() } } else { store.settings.useContacts = false }
                    }))
                if store.settings.useContacts {
                    if store.contacts.isEmpty {
                        Text(store.contactsStatus == .denied ? "Contacts access was denied — allow it in System Settings › Privacy & Security › Contacts."
                                                            : "No contacts with a birthday.")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(sorted(store.contacts)) { b in row(b, editable: false) }
                }
            } header: {
                Text("Contacts")
            } footer: {
                Text("Both Gregorian and non-Gregorian (Persian / Islamic) birthdays from Contacts are supported.")
                    .font(.app(.caption)).foregroundStyle(.secondary)
            }

            Section("Reminders") {
                Toggle("Notify me about birthdays", isOn: $store.settings.notify)
                DatePicker("At", selection: Binding(
                    get: { Calendar.current.date(bySettingHour: store.settings.hour, minute: store.settings.minute, second: 0, of: Date()) ?? Date() },
                    set: {
                        let c = Calendar.current.dateComponents([.hour, .minute], from: $0)
                        store.settings.hour = c.hour ?? 9
                        store.settings.minute = c.minute ?? 0
                    }), displayedComponents: .hourAndMinute)
                HStack {
                    Text("Remind me")
                    Spacer()
                    ForEach([0, 1, 3, 7], id: \.self) { lead in
                        Toggle(lead == 0 ? "On the day" : "\(lead) day\(lead == 1 ? "" : "s") before", isOn: Binding(
                            get: { store.settings.leadDays.contains(lead) },
                            set: { on in
                                var s = Set(store.settings.leadDays)
                                if on { s.insert(lead) } else { s.remove(lead) }
                                store.settings.leadDays = s.sorted()
                            }))
                        .toggleStyle(.checkbox)
                    }
                }
                Toggle("Also tell me in the morning when today is a public holiday", isOn: $store.settings.holidayMorningNotice)
                HStack {
                    Spacer()
                    Button(testSent ? "Sent — arrives in 5 s" : "Send a test notification") {
                        Task { await Notifier.sendTest(); testSent = true }
                    }
                }
            }
        }
        .formStyle(.grouped)
    }

    private func sorted(_ list: [Birthday]) -> [Birthday] {
        list.sorted { (store.nextOccurrence($0) ?? .distantFuture) < (store.nextOccurrence($1) ?? .distantFuture) }
    }

    private func row(_ b: Birthday, editable: Bool) -> some View {
        let next = store.nextOccurrence(b)
        let days = next.map { CalendarService.daysFromToday($0) }
        return HStack {
            Image(systemName: b.source == .contacts ? "person.crop.circle" : "gift").foregroundStyle(.pink)
            VStack(alignment: .leading, spacing: 1) {
                Text(b.name).fontWeight(.medium)
                Text(b.dateText + (b.note.isEmpty ? "" : " · \(b.note)")).font(.app(.caption)).foregroundStyle(.secondary)
            }
            Spacer()
            if let next, let days {
                VStack(alignment: .trailing, spacing: 1) {
                    Text(days == 0 ? "Today 🎉" : "in \(days) day\(days == 1 ? "" : "s")")
                        .font(.app(.caption).weight(.semibold)).foregroundStyle(days <= 7 ? Color.pink : Color.secondary)
                    if let age = store.age(of: b, on: next) { Text("turns \(age)").font(.app(.caption2)).foregroundStyle(.secondary) }
                }
            }
            if editable {
                Button { draft = b; editingID = b.id } label: { Image(systemName: "pencil") }.buttonStyle(.borderless)
                Button(role: .destructive) { store.manual.removeAll { $0.id == b.id } } label: { Image(systemName: "trash") }
                    .buttonStyle(.borderless)
            }
        }
    }

    private func save() {
        var b = draft
        b.name = b.name.trimmingCharacters(in: .whitespaces)
        b.day = min(b.day, b.calendar == .jalali ? (b.month <= 6 ? 31 : 30) : (b.calendar == .islamic ? 30 : 31))
        if let id = editingID, let i = store.manual.firstIndex(where: { $0.id == id }) {
            store.manual[i] = b
        } else {
            b.id = UUID().uuidString
            store.manual.append(b)
        }
        reset()
    }

    private func reset() {
        draft = Birthday(name: "", calendar: draft.calendar, month: 1, day: 1)
        editingID = nil
    }
}

// MARK: - Weather

struct WeatherSettingsView: View {
    @ObservedObject var model: AppModel
    @ObservedObject var weather: WeatherStore
    @State private var locating = false
    private let location = LocationFetcher()

    var body: some View {
        Form {
            Section {
                Picker("Source", selection: $weather.settings.provider) {
                    ForEach(WeatherProviderID.allCases) { p in
                        VStack(alignment: .leading, spacing: 1) {
                            Text(p.title)
                            Text(p.detail).font(.app(.caption)).foregroundStyle(.secondary)
                        }
                        .tag(p)
                    }
                }
                .pickerStyle(.radioGroup)
                if weather.settings.provider.needsKey {
                    SecureField("\(weather.settings.provider.title) API key", text: Binding(
                        get: { weather.settings.apiKeys[weather.settings.provider.rawValue] ?? "" },
                        set: { weather.settings.apiKeys[weather.settings.provider.rawValue] = $0 }))
                }
                Picker("Units", selection: $weather.settings.unit) {
                    Text("°C").tag(TemperatureUnit.celsius)
                    Text("°F").tag(TemperatureUnit.fahrenheit)
                }
                .pickerStyle(.segmented)
                if let notice = weather.notice {
                    Label(notice, systemImage: "exclamationmark.triangle").font(.app(.caption)).foregroundStyle(.orange)
                }
            } header: {
                Text("Weather source")
            } footer: {
                Text("If the chosen source fails, jDate automatically tries the other free sources (Open-Meteo, MET Norway, wttr.in) so widgets never go blank.")
                    .font(.app(.caption)).foregroundStyle(.secondary)
            }

            Section {
                if let city = weather.settings.themeCity {
                    HStack {
                        Label("\(city.name), \(city.country)", systemImage: "mappin.and.ellipse")
                        Spacer()
                        if let s = weather.snapshots[city.id] {
                            Image(systemName: s.condition.symbol(isDay: s.isDay)).symbolRenderingMode(.multicolor)
                            Text("\(weather.format(s.temperature)) · \(s.condition.title)").foregroundStyle(.secondary)
                        }
                        Button("Remove") { weather.settings.themeCity = nil }.buttonStyle(.borderless)
                    }
                }
                CityPicker(title: "Search a city…") { weather.settings.themeCity = $0 }
                HStack {
                    Button {
                        locating = true
                        Task {
                            if let c = await location.current() { weather.settings.themeCity = c }
                            locating = false
                        }
                    } label: { Label("Use my location", systemImage: "location") }
                    if locating { ProgressView().controlSize(.small) }
                }
            } header: {
                Text("Main city")
            } footer: {
                Text("Shown in the popover header and used by the “Live weather” theme. Add more cities as weather widgets in Popover Layout.")
                    .font(.app(.caption)).foregroundStyle(.secondary)
            }

            Section("Status") {
                ForEach(weather.allCities) { c in
                    HStack {
                        Text(c.name)
                        Spacer()
                        if let s = weather.snapshots[c.id] {
                            Text("\(weather.format(s.temperature)) · \(s.provider) · \(s.fetchedAt.formatted(date: .omitted, time: .shortened))")
                                .font(.app(.caption)).foregroundStyle(.secondary)
                        } else if let e = weather.errors[c.id] {
                            Text(e).font(.app(.caption)).foregroundStyle(.red)
                        } else {
                            Text("Not loaded yet").font(.app(.caption)).foregroundStyle(.secondary)
                        }
                    }
                }
                HStack {
                    Spacer()
                    if weather.isLoading { ProgressView().controlSize(.small) }
                    Button("Refresh now") { Task { await weather.refresh(force: true) } }
                }
            }
        }
        .formStyle(.grouped)
    }
}
