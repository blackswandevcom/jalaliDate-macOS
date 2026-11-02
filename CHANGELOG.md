# Changelog — jDate Menubar

Newest first. Dates are Gregorian · Jalali. Keep in sync with `JalaliDateApp/Core/Changelog.swift`.

## v8.0 — 2026-11-02 · 1405-08-11
- Desktop & Notification Center widgets: Today, Month, World Clock, Upcoming, Weather and Countdown — each configurable (calendar, digits, style, cities…)
- Click a day in the popover calendar to see its holidays, occasions, birthdays and calendar events right below it
- Built-in Iranian public calendar: official holidays (solar and lunar), occasions like Yalda and Chaharshanbe Suri, optional international days
- Google Calendar, iCloud and other calendars via macOS Calendar, plus public ICS subscriptions (Google “Holidays in Iran” preset)
- Birthday reminders from Contacts and your own list, in Jalali, Gregorian or Hijri, with notifications on the day or days before
- Weather from Open-Meteo, MET Norway, wttr.in, OpenWeatherMap or WeatherAPI.com, with automatic fallback
- Popover widgets in full, half or one-third width: dates, weather, world clocks with time difference, countdowns and next event
- Show, hide and reorder popover sections; choose the popover width; live preview
- Header themes: seasons, live weather, presets, custom colors or system accent, with optional rain/snow/leaf animation
- Menubar icon designer: circle, square, rounded, filled, calendar page or no shape; custom colors, text and date-format tokens
- Date Difference tool, global shortcut (⌃⌥J), copy formats, Hijri calendar variants and an Upcoming list
- Wide popover: calendar and the selected day's events side by side (640–880 pt)
- Month calendar options: show or hide the Gregorian and Hijri day under each date, and set the day and small-date font sizes
- App fonts: use any font installed on your Mac (Persian fonts listed first) with a size control, optionally in widgets and the menubar
- Weather: 5–7 day forecast in the full-size weather widget and a new large desktop weather widget; real day/night icons from sunrise/sunset; full-day high/low
- New flat app icon — a calendar page showing 13 Aban 1403, the day jDate was first released

## v7.0 — 2026-11-02 · 1405-08-11
- Brand-new SwiftUI popover replaces the old dropdown menu
- Today card with the Jalali, Gregorian and Hijri dates — click any of them to copy
- Mini Jalali month calendar with Gregorian days; click a day to open it in the converter
- Redesigned Date Converter with a days-from-today hint
- New app window with Converter, Months, Settings, About and Changelog
- Menubar icon styles: day badge, date text, or both
- Launch at login
- The date now refreshes right after midnight and after the Mac wakes up
- Fixed: editing the Hijri date in the converter ignored the Hijri day offset

## v6.1 — 2025-03-28 · 1404-01-08
- Removed the double-click action on the menubar icon
- Menubar icon fix

## v6.0 — 2025-03-23 · 1404-01-03
- Date Converter: live conversion between Jalali, Gregorian and Hijri
- Copy each converted date on its own
- Previous / Today / Next day navigation and weekday names

## v5.0 — 2025-03-23 · 1404-01-03
- Islamic (Hijri) date in the menu
- Hijri day offset setting (−4 to +4)
- Months name table for all three calendars
- Cleaner menu with icons

## v4.1 — 2024-11-26 · 1403-09-06
- Fixed the date not updating while the app stays open

## v4.0 — 2024-11-24 · 1403-09-04
- Polish and stability improvements

## v3.0 — 2024-11-24 · 1403-09-04
- Gregorian date next to the Jalali date
- Copy dates with keyboard shortcuts
- Checkmark on the menubar icon after copying

## v2.0 — 2024-11-04 · 1403-08-14
- Menu with copyable dates
- About window
- App icon

## v1.0 — 2024-11-03 · 1403-08-13
- First release: today's Jalali day in the menubar
