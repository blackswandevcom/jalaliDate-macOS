import AppKit
import SwiftUI

enum MainTab: String, CaseIterable, Identifiable, Hashable {
    case converter, difference, months
    case events, birthdays, weather
    case layout, theme, fonts, icon, desktopWidgets
    case general, about, changelog

    var id: String { rawValue }

    var title: String {
        switch self {
        case .converter: return "Date Converter"
        case .difference: return "Date Difference"
        case .months: return "Months"
        case .events: return "Events & Calendars"
        case .birthdays: return "Birthdays"
        case .weather: return "Weather"
        case .layout: return "Popover Layout"
        case .theme: return "Theme"
        case .fonts: return "Fonts"
        case .icon: return "Menubar Icon"
        case .desktopWidgets: return "Desktop Widgets"
        case .general: return "General"
        case .about: return "About"
        case .changelog: return "Changelog"
        }
    }

    var symbol: String {
        switch self {
        case .converter: return "arrow.left.arrow.right"
        case .difference: return "plusminus"
        case .months: return "tablecells"
        case .events: return "calendar.badge.clock"
        case .birthdays: return "gift"
        case .weather: return "cloud.sun"
        case .layout: return "square.grid.2x2"
        case .theme: return "paintpalette"
        case .fonts: return "textformat"
        case .icon: return "menubar.rectangle"
        case .desktopWidgets: return "rectangle.3.group"
        case .general: return "gearshape"
        case .about: return "info.circle"
        case .changelog: return "list.bullet.rectangle"
        }
    }

    static let groups: [(String, [MainTab])] = [
        ("Tools", [.converter, .difference, .months]),
        ("Content", [.events, .birthdays, .weather]),
        ("Customize", [.layout, .theme, .fonts, .icon, .desktopWidgets]),
        ("App", [.general, .about, .changelog]),
    ]
}

/// Shared state between the menubar, the popover and the main window.
@MainActor
final class AppModel: ObservableObject {
    @Published var now = Date()
    /// Key of the item that was just copied (drives the inline ✓).
    @Published var copiedKey: String?
    @Published var tab: MainTab = .converter
    @Published var converterDate = Date()
    /// Day picked in the popover calendar.
    @Published var selectedDay = Date()
    @Published var popoverVisible = false

    let settings = AppSettings.shared
    let birthdays: BirthdayStore
    let events: EventStore
    let weather = WeatherStore()

    var onCopy: (() -> Void)?
    var onOpenMain: (() -> Void)?

    init() {
        birthdays = BirthdayStore()
        events = EventStore(birthdays: birthdays)
        syncWeatherCities()
    }

    static var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "8.0"
    }

    static var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? ""
    }

    func syncWeatherCities() {
        weather.widgetCities = settings.layout.widgets.compactMap {
            if case .weather(let c) = $0.kind { return c }
            return nil
        }
    }

    func copy(_ text: String, key: String) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(text, forType: .string)
        copiedKey = key
        onCopy?()
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.4))
            if self.copiedKey == key { self.copiedKey = nil }
        }
    }

    func copyDate(_ date: Date, _ kind: CalendarKind, key: String) {
        copy(settings.general.copyFormat.string(date, kind), key: key)
    }

    func copyToday(_ kind: CalendarKind) {
        copyDate(Date(), kind, key: "today-\(kind.rawValue)")
    }

    /// `2026-11-02 | 1405-08-11` — handy for release notes.
    func copyVersionDates() {
        let d = Date()
        copy("\(CalendarService.iso(d, .gregorian)) | \(CalendarService.iso(d, .jalali))", key: "version")
    }

    func open(_ tab: MainTab) {
        self.tab = tab
        onOpenMain?()
    }

    func openConverter(at date: Date) {
        converterDate = date
        open(.converter)
    }
}
