import Foundation

struct Release: Identifiable {
    let version: String
    /// Gregorian `yyyy-MM-dd`.
    let date: String
    let notes: [String]

    var id: String { version }
}

/// Keep in sync with CHANGELOG.md in the repo root. Newest first.
enum Changelog {
    static let releases: [Release] = [
        Release(version: "8.2", date: "2026-11-03", notes: [
            "The Jalali, Gregorian and Hijri date tiles follow the day you click in the calendar, and clicking one (or ⌘C, ⌘X, ⌘A) copies that day's date",
            "Header contents: show or hide each line of the header (weekdays, Gregorian and Hijri dates, weather, the day number and more) and set each one's size and color",
            "Option to show the picked day's events inside the header instead of the panel under the calendar",
            "Birthdays: a year calendar with every month and the birthdays on each day (click a day for the details, or to add one), and a timeline of the next twelve months",
            "Birthdays that synced accounts left in Contacts more than once now show, and notify, only once",
            "Date tiles can be one line with less padding (Popover Layout › Widgets › Date tiles: One line)",
            "Option to hide the button bar at the bottom of the popover (Popover Layout); its shortcuts keep working and the menu bar right-click menu still has Settings and Quit",
            "jDate › Settings… (⌘,) opens jDate's settings instead of an empty window, and the app menu is named jDate",
            "Liquid Glass popover background on macOS 26: the glass edges stay and the desktop behind is really blurred, the way Terminal blurs its windows (Theme › Popover background › Material; Classic keeps the old look). New Terminal preset matching Terminal's Pro profile, and the preset in use is checked",
        ]),
        Release(version: "8.1", date: "2026-11-03", notes: [
            "Click a day in the calendar and the header shows that day; click the header to jump back to today. The events panel no longer repeats the date",
            "Animated headers: Aurora, Liquid mesh, Waves, Lava lamp, Starfield, Girih (Persian tiles) and Ripples, each with your own three colors, speed and intensity",
            "Photo or video header: pick any photo or a short clip. Videos loop muted while the popover is open; widgets show a still frame",
            "Popover background like Terminal: your own color with opacity and blur, from see-through to frosted, with light or dark text and four quick presets",
            "Glass desktop widgets: color, opacity and blur for all jDate widgets at once, or per widget with the new Glass style",
            "Theme picker redesigned as tiles, with a live preview of every animated style",
            "Occasion themes that switch on by themselves: Nowruz, Chaharshanbe Suri, Sizdah Bedar, Yalda, Ramadan, Eid al-Fitr, Eid al-Adha, Muharram, Christmas, New Year's Eve, 4th of July, Halloween and Valentine's Day. Turn each one on or off, or pick one to keep",
            "Six new animated styles: Fireworks, Crescent & lanterns, Snow & lights, Spring blossoms, Bonfire sparks and Floating hearts",
            "Your own colors for holidays and weekends, and pick which days are the weekend (Friday, Thursday and Friday, Saturday and Sunday…), in the popover and the widgets",
        ]),
        Release(version: "8.0", date: "2026-11-02", notes: [
            "Desktop & Notification Center widgets: Today, Month, World Clock, Upcoming, Weather and Countdown — each configurable (calendar, digits, style, cities…)",
            "Click a day in the popover calendar to see its holidays, occasions, birthdays and calendar events right below it",
            "Built-in Iranian public calendar: official holidays (solar and lunar), occasions like Yalda and Chaharshanbe Suri, optional international days",
            "Google Calendar, iCloud and other calendars via macOS Calendar, plus public ICS subscriptions (Google “Holidays in Iran” preset)",
            "Birthday reminders from Contacts and your own list, in Jalali, Gregorian or Hijri, with notifications on the day or days before",
            "Weather from Open-Meteo, MET Norway, wttr.in, OpenWeatherMap or WeatherAPI.com, with automatic fallback",
            "Popover widgets in full, half or one-third width: dates, weather, world clocks with time difference, countdowns and next event",
            "Show, hide and reorder popover sections; choose the popover width; live preview",
            "Header themes: seasons, live weather, presets, custom colors or system accent, with optional rain/snow/leaf animation",
            "Menubar icon designer: circle, square, rounded, filled, calendar page or no shape; custom colors, text and date-format tokens",
            "Date Difference tool, global shortcut (⌃⌥J), copy formats, Hijri calendar variants and an Upcoming list",
            "Wide popover: calendar and the selected day's events side by side (640–880 pt)",
            "Month calendar options: show or hide the Gregorian and Hijri day under each date, and set the day and small-date font sizes",
            "App fonts: use any font installed on your Mac (Persian fonts listed first) with a size control, optionally in widgets and the menubar",
            "Weather: 5–7 day forecast in the full-size weather widget and a new large desktop weather widget; real day/night icons from sunrise/sunset; full-day high/low",
            "New flat app icon — a calendar page showing 13 Aban 1403, the day jDate was first released",
        ]),
        Release(version: "7.0", date: "2026-11-02", notes: [
            "Brand-new SwiftUI popover replaces the old dropdown menu",
            "Today card with the Jalali, Gregorian and Hijri dates — click any of them to copy",
            "Mini Jalali month calendar with Gregorian days; click a day to open it in the converter",
            "Redesigned Date Converter with a days-from-today hint",
            "New app window with Converter, Months, Settings, About and Changelog",
            "Menubar icon styles: day badge, date text, or both",
            "Launch at login",
            "The date now refreshes right after midnight and after the Mac wakes up",
            "Fixed: editing the Hijri date in the converter ignored the Hijri day offset",
        ]),
        Release(version: "6.1", date: "2025-03-28", notes: [
            "Removed the double-click action on the menubar icon",
            "Menubar icon fix",
        ]),
        Release(version: "6.0", date: "2025-03-23", notes: [
            "Date Converter: live conversion between Jalali, Gregorian and Hijri",
            "Copy each converted date on its own",
            "Previous / Today / Next day navigation and weekday names",
        ]),
        Release(version: "5.0", date: "2025-03-23", notes: [
            "Islamic (Hijri) date in the menu",
            "Hijri day offset setting (−4 to +4)",
            "Months name table for all three calendars",
            "Cleaner menu with icons",
        ]),
        Release(version: "4.1", date: "2024-11-26", notes: [
            "Fixed the date not updating while the app stays open",
        ]),
        Release(version: "4.0", date: "2024-11-24", notes: [
            "Polish and stability improvements",
        ]),
        Release(version: "3.0", date: "2024-11-24", notes: [
            "Gregorian date next to the Jalali date",
            "Copy dates with keyboard shortcuts",
            "Checkmark on the menubar icon after copying",
        ]),
        Release(version: "2.0", date: "2024-11-04", notes: [
            "Menu with copyable dates",
            "About window",
            "App icon",
        ]),
        Release(version: "1.0", date: "2024-11-03", notes: [
            "First release: today's Jalali day in the menubar",
        ]),
    ]
}
