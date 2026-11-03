<p align="center">
  <img src="docs/icon.png" width="160" alt="jDate icon">
</p>

<h1 align="center">jDate — Jalali Date for your Mac menubar</h1>

<p align="center">
  Today's date in the <b>Jalali (Persian)</b>, <b>Gregorian</b> and <b>Hijri</b> calendars, right in your menubar —
  with Iranian holidays, your calendars, birthdays, weather, world clocks and desktop widgets.
</p>

<p align="center">
  <a href="https://github.com/blackswandevcom/jalaliDate-macOS/releases">
    <img src="docs/download-button.svg" width="420" alt="Download jDate 8.2 for macOS">
  </a>
</p>

<p align="center">
  <a href="https://github.com/blackswandevcom/jalaliDate-macOS/releases/latest"><img src="https://img.shields.io/github/v/release/blackswandevcom/jalaliDate-macOS?label=latest&color=0E8FB0" alt="latest release"></a>
  <img src="https://img.shields.io/badge/macOS-15%2B-1F4FA8" alt="macOS 15+">
  <img src="https://img.shields.io/badge/price-free-18C6B8" alt="free">
</p>

---

<p align="center">
  <img src="docs/screenshots/popover-wide.png" width="820" alt="Wide popover: calendar and the selected day's events side by side">
</p>

## Install

1. **[Download the latest .dmg from Releases](https://github.com/blackswandevcom/jalaliDate-macOS/releases)**
2. Open it and drag **Jalali Date** into **Applications**.
3. Open the app from Applications. The date shows up in the menubar.

> First launch: if macOS says the app can't be checked, right-click the app → **Open** → **Open**.
> Or run `xattr -dr com.apple.quarantine "/Applications/Jalali Date.app"` once.

Requires macOS 15 (Sequoia) or later. Upgrading from an older version: quit it, then replace the app in Applications.

## Features

- **Three calendars at a glance** — Jalali, Gregorian and Hijri; click any date to copy it (⌘C / ⌘X / ⌘A). The tiles follow the day you pick in the calendar, as cards or one line each.
- **Month calendar** — Fridays and holidays in red, optional Gregorian and Hijri day under each date, adjustable font sizes.
- **Day events** — click a day to see its holidays, occasions, birthdays and calendar events.
- **Iranian public calendar** built in — solar and lunar holidays, Yalda, Chaharshanbe Suri and more, no internet needed.
- **Your calendars** — Google, iCloud and others through macOS Calendar, plus public ICS subscriptions.
- **Birthday reminders** from Contacts or your own list, in any of the three calendars, with a year calendar and a timeline of the next twelve months.
- **Weather** with a 5–7 day forecast — Open-Meteo, MET Norway, wttr.in, OpenWeatherMap or WeatherAPI.com.
- **World clocks**, countdowns and an upcoming-events list as popover widgets in full, half or one-third width.
- **Two layouts** — the classic stacked popover, or a wide one with the calendar and events side by side.
- **Themes** — seasons, live weather, presets, your own colors, 13 animated styles, or your own photo or looping muted video.
- **Occasion themes** — Nowruz, Chaharshanbe Suri, Sizdah Bedar, Yalda, Ramadan, Eid al-Fitr, Eid al-Adha, Muharram, Christmas, New Year's Eve, 4th of July, Halloween and Valentine's Day switch on by themselves on their days.
- **Liquid Glass background** — color, opacity and blur for the popover and the desktop widgets, like Terminal's window background, with a preset that matches Terminal's Pro profile.
- **Header contents** — show or hide each line of the header, set its size and color, and show the picked day's events in it.
- **Holiday and weekend colors** — pick both colors and which days are the weekend.
- **Menubar icon designer** — shapes, colors and your own date format.
- **Desktop & Notification Center widgets** — Today, Month, World Clock, Upcoming, Weather and Countdown.
- **Any font on your Mac** — Persian fonts listed first, with a size control.
- Date converter, date difference tool, global shortcut (⌃⌥J), launch at login.

## Screenshots

<p align="center">
  <img src="docs/screenshots/occasion-headers.png" width="820" alt="Occasion headers: Nowruz, Ramadan, Christmas, 4th of July, Chaharshanbe Suri and Yalda">
</p>

<table>
  <tr>
    <td width="40%"><img src="docs/screenshots/popover-liquid-glass.png" alt="Liquid Glass popover with the Terminal preset"></td>
    <td>
      <img src="docs/screenshots/birthdays-year.png" alt="Birthdays year calendar"><br><br>
      <img src="docs/screenshots/header-contents.png" alt="Header contents settings">
    </td>
  </tr>
  <tr>
    <td width="40%"><img src="docs/screenshots/popover.png" alt="Popover with seasonal theme, widgets and calendar"></td>
    <td>
      <img src="docs/screenshots/converter.png" alt="Date converter"><br><br>
      <img src="docs/screenshots/themes.png" alt="Themes">
    </td>
  </tr>
  <tr>
    <td width="40%"><img src="docs/screenshots/popover-glass.png" alt="See-through popover with the lava lamp header and a picked day"></td>
    <td>
      <img src="docs/screenshots/theme-occasions.png" alt="Occasion themes"><br><br>
      <img src="docs/screenshots/widgets-glass.png" alt="Glass background for the widgets">
    </td>
  </tr>
  <tr>
    <td colspan="2"><img src="docs/screenshots/customize.png" alt="Customize the popover: show, hide and reorder sections and widgets"></td>
  </tr>
  <tr>
    <td colspan="2"><img src="docs/screenshots/fonts.png" alt="App fonts"></td>
  </tr>
</table>

### Desktop widgets

<p align="center">
  <img src="docs/screenshots/widget-today.png" width="420" alt="Today widget">
  <img src="docs/screenshots/widget-weather.png" width="300" alt="Weather widget with forecast">
  <img src="docs/screenshots/widget-month.png" width="300" alt="Month widget">
</p>

## What's new

See the **[changelog](CHANGELOG.md)**. Version 8.2 makes the popover real Liquid Glass with a Terminal-style blur and a
Terminal preset, adds a birthday year calendar and timeline, lets you choose each line of the header (size and color too) and
show the picked day's events in it, makes the date tiles copy the day you pick, adds one-line tiles and lets you hide the
button bar. Version 8.1 added occasion themes (Nowruz, Ramadan, Christmas, 4th of July and more),
animated and photo/video headers, a Terminal-style glass background for the popover and widgets, your own holiday and weekend
colors, and a header that shows the day you click. Version 8.0 brought events, birthdays, weather, world clocks, widgets, fonts,
a wide layout and the new icon — a calendar page showing **۱۳ آبان ۱۴۰۳**, the day jDate was first released.

## Build from source

Open `JalaliDateApp.xcodeproj` in Xcode, pick the **JalaliDateApp** scheme and run. The widgets live in the
`JDateWidgets` target and share data with the app through the `DFDRW6TJH5.blackswan.jdate` App Group —
change the team and group to your own when you build it.

## Author

Made by **Amirhossein Hosseinpour** — [amirhp.com](https://amirhp.com) · [BlackSwanDev.com](https://blackswandev.com)

## License

Free and open source under the **GNU General Public License v3.0** — use, modify and share it, as long as derivative
works stay under the same license. Provided as-is; double-check dates before using them for anything critical.

Suggestions and bug reports are welcome in [Issues](https://github.com/blackswandevcom/jalaliDate-macOS/issues).
