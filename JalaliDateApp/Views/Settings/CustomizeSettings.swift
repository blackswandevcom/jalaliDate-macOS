import ServiceManagement
import SwiftUI

// MARK: - Popover layout

struct LayoutView: View {
    @ObservedObject var model: AppModel
    @ObservedObject var settings: AppSettings
    @State private var addKind = "clock"
    @State private var addSize: WidgetSize = .half
    @State private var countdown = CountdownTarget(title: "", calendar: .jalali, month: 1, day: 1, year: nil)

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            Form {
                Section {
                    List {
                        ForEach($settings.layout.sections) { $s in
                            HStack {
                                Image(systemName: "line.3.horizontal").foregroundStyle(.tertiary)
                                Image(systemName: s.section.symbol).frame(width: 20)
                                Text(s.section.title)
                                Spacer()
                                Toggle("", isOn: $s.visible).labelsHidden().toggleStyle(.switch).controlSize(.small)
                            }
                        }
                        .onMove { settings.layout.sections.move(fromOffsets: $0, toOffset: $1) }
                    }
                    .frame(height: CGFloat(settings.layout.sections.count) * 30 + 8)
                    Picker("Arrangement", selection: $settings.layout.arrangement) {
                        ForEach(PopoverArrangement.allCases) { Text($0.title).tag($0) }
                    }
                    if settings.layout.arrangement == .sideBySide {
                        Picker("Popover width", selection: $settings.layout.wideWidth) {
                            ForEach(PopoverLayout.wideWidths, id: \.self) { Text("\(Int($0)) pt").tag($0) }
                        }
                        Toggle("Calendar on the right", isOn: $settings.layout.calendarOnRight)
                    } else {
                    Picker("Popover width", selection: $settings.layout.width) {
                        ForEach(PopoverLayout.widths, id: \.self) { Text("\(Int($0)) pt").tag($0) }
                    }
                    }
                    Divider()
                    Toggle("Show Gregorian day under each date", isOn: $settings.layout.cellGregorian)
                    Toggle("Show Hijri day under each date", isOn: $settings.layout.cellHijri)
                    HStack {
                        Text("Day number size")
                        Slider(value: $settings.layout.cellDayFont, in: 10...20, step: 1)
                        Text("\(Int(settings.layout.cellDayFont)) pt").monospacedDigit().frame(width: 40, alignment: .trailing)
                    }
                    HStack {
                        Text("Small dates size")
                        Slider(value: $settings.layout.cellSecondaryFont, in: 7...13, step: 1)
                        Text("\(Int(settings.layout.cellSecondaryFont)) pt").monospacedDigit().frame(width: 40, alignment: .trailing)
                    }
                    .disabled(!settings.layout.cellGregorian && !settings.layout.cellHijri)
                } header: {
                    Text("Sections")
                } footer: {
                    Text("Drag to reorder, switch off to hide. The footer buttons are always shown.").font(.app(.caption)).foregroundStyle(.secondary)
                }

                Section {
                    List {
                        ForEach($settings.layout.widgets) { $w in
                            HStack {
                                Image(systemName: "line.3.horizontal").foregroundStyle(.tertiary)
                                Image(systemName: w.kind.symbol).frame(width: 20)
                                Text(w.kind.title).lineLimit(1)
                                Spacer()
                                Picker("", selection: $w.size) {
                                    ForEach(WidgetSize.allCases) { Text($0.title).tag($0) }
                                }
                                .labelsHidden().frame(width: 110)
                                Button(role: .destructive) {
                                    settings.layout.widgets.removeAll { $0.id == w.id }
                                    model.syncWeatherCities()
                                } label: { Image(systemName: "minus.circle.fill").foregroundStyle(.red) }
                                    .buttonStyle(.borderless)
                            }
                        }
                        .onMove { settings.layout.widgets.move(fromOffsets: $0, toOffset: $1) }
                    }
                    .frame(height: max(40, CGFloat(settings.layout.widgets.count) * 32 + 8))
                } header: {
                    Text("Widgets")
                } footer: {
                    Text("Full = whole row, Half = 2 per row, One third = 3 per row. Widgets flow left to right. Right-click a widget in the popover to resize or remove it.")
                        .font(.app(.caption)).foregroundStyle(.secondary)
                }

                Section("Add a widget") {
                    Picker("Type", selection: $addKind) {
                        Text("World clock").tag("clock")
                        Text("Weather").tag("weather")
                        Text("Date").tag("date")
                        Text("Countdown").tag("countdown")
                        Text("Next event").tag("upcoming")
                    }
                    Picker("Size", selection: $addSize) {
                        ForEach(WidgetSize.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    switch addKind {
                    case "clock", "weather":
                        CityPicker(title: "Search a city to add…") { city in
                            add(addKind == "clock" ? .clock(city) : .weather(city))
                        }
                        if addKind == "weather", let c = model.weather.settings.themeCity {
                            Button("Add \(c.name) (main city)") { add(.weather(c)) }
                        }
                    case "date":
                        HStack {
                            ForEach(CalendarKind.allCases) { k in
                                Button(k.title) { add(.date(k)) }
                            }
                        }
                    case "countdown":
                        TextField("Title", text: $countdown.title)
                        Picker("Calendar", selection: $countdown.calendar) {
                            ForEach(CalendarKind.allCases) { Text($0.title).tag($0) }
                        }
                        HStack {
                            Picker("Month", selection: $countdown.month) {
                                ForEach(1...12, id: \.self) { Text("\($0) · \(countdown.calendar.monthNames[$0 - 1])").tag($0) }
                            }
                            Picker("Day", selection: $countdown.day) {
                                ForEach(1...31, id: \.self) { Text("\($0)").tag($0) }
                            }
                            .frame(width: 100)
                            TextField("Year (empty = yearly)", value: $countdown.year, format: .number.grouping(.never))
                                .frame(width: 150)
                        }
                        HStack {
                            Button("Nowruz") { add(.countdown(.nowruz)) }
                            Button("Yalda") { add(.countdown(CountdownTarget(title: "Yalda", calendar: .jalali, month: 9, day: 30, year: nil))) }
                            Spacer()
                            Button("Add countdown") {
                                var t = countdown
                                if t.title.isEmpty { t.title = "Countdown" }
                                add(.countdown(t))
                            }
                        }
                    default:
                        Button("Add next event") { add(.upcoming) }
                    }
                }

                Section {
                    HStack {
                        Spacer()
                        Button("Reset popover to default") { settings.layout = PopoverLayout(); model.syncWeatherCities() }
                    }
                }
            }
            .formStyle(.grouped)

            Divider()
            ScrollView {
                VStack(spacing: 6) {
                    Text("Live preview").font(.app(.caption)).foregroundStyle(.secondary)
                    PopoverView(model: model)
                        .allowsHitTesting(false)
                        .background(RoundedRectangle(cornerRadius: 12).fill(.background))
                        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.primary.opacity(0.12)))
                        .scaleEffect(previewScale, anchor: .top)
                        .frame(width: settings.layout.effectiveWidth * previewScale)
                }
                .padding(12)
            }
            .frame(width: 380)
        }
    }

    private var previewScale: CGFloat { min(0.8, 350 / settings.layout.effectiveWidth) }

    private func add(_ kind: WidgetKind) {
        settings.layout.widgets.append(WidgetConfig(kind: kind, size: addSize))
        if !settings.layout.isVisible(.widgets),
           let i = settings.layout.sections.firstIndex(where: { $0.section == .widgets }) {
            settings.layout.sections[i].visible = true
        }
        model.syncWeatherCities()
    }
}

// MARK: - Theme

struct ThemeView: View {
    @ObservedObject var model: AppModel
    @ObservedObject var settings: AppSettings

    var body: some View {
        Form {
            Section {
                HeroView(now: model.now,
                         theme: ThemeResolver.resolve(settings.theme, date: model.now, weather: model.weather.themeSnapshot),
                         weather: model.weather, animated: settings.theme.animated)
                    .frame(maxWidth: 380)
                    .frame(maxWidth: .infinity)
            }

            Section("Header theme") {
                Picker("Style", selection: $settings.theme.mode) {
                    ForEach(ThemeMode.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                switch settings.theme.mode {
                case .season:
                    Text("Changes with the Persian seasons: spring blossoms, summer saffron, autumn leaves, winter snow.")
                        .font(.app(.caption)).foregroundStyle(.secondary)
                case .weather:
                    Text(model.weather.settings.themeCity == nil
                         ? "Pick a main city in Weather first."
                         : "Follows the current weather in \(model.weather.settings.themeCity!.name): clear, cloudy, rain, snow, storm, day and night.")
                        .font(.app(.caption)).foregroundStyle(.secondary)
                    Button("Weather settings…") { model.tab = .weather }
                case .preset:
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 120))], spacing: 10) {
                        ForEach(ThemePreset.allCases) { p in
                            Button { settings.theme.preset = p } label: {
                                VStack(spacing: 4) {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(LinearGradient(colors: p.colors, startPoint: .topLeading, endPoint: .bottomTrailing))
                                        .frame(height: 40)
                                        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(settings.theme.preset == p ? Color.accentColor : .clear, lineWidth: 2.5))
                                    Text(p.title).font(.app(.caption))
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                case .custom:
                    ColorPicker("From", selection: Binding(get: { Color(hex: settings.theme.customA) }, set: { settings.theme.customA = $0.hexString }), supportsOpacity: false)
                    ColorPicker("To", selection: Binding(get: { Color(hex: settings.theme.customB) }, set: { settings.theme.customB = $0.hexString }), supportsOpacity: false)
                case .accent:
                    Text("Uses your macOS accent color (System Settings › Appearance).").font(.app(.caption)).foregroundStyle(.secondary)
                }
            }

            Section("Options") {
                Toggle("Animated effects (rain, snow, leaves…) while the popover is open", isOn: $settings.theme.animated)
                Toggle("Fridays and holidays in red", isOn: $settings.theme.fridayRed)
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Menubar icon

struct IconDesignerView: View {
    @ObservedObject var model: AppModel
    @ObservedObject var settings: AppSettings

    var body: some View {
        Form {
            Section {
                HStack(spacing: 24) {
                    Spacer()
                    preview(dark: false)
                    preview(dark: true)
                    Spacer()
                }
                .padding(.vertical, 6)
            }

            Section("Layout") {
                Picker("Show", selection: $settings.icon.layout) {
                    ForEach(IconLayout.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
            }

            if settings.icon.layout != .text {
                Section("Badge") {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 92))], spacing: 8) {
                        ForEach(IconShape.allCases) { shape in
                            var c = settings.icon
                            let _ = c.shape = shape
                            Button { settings.icon.shape = shape } label: {
                                VStack(spacing: 4) {
                                    Image(nsImage: MenubarIcon.badge(MenubarIcon.badgeText(c), config: c, height: 22))
                                        .frame(height: 26)
                                    Text(shape.title).font(.app(.caption2))
                                }
                                .frame(maxWidth: .infinity)
                                .padding(6)
                                .background(RoundedRectangle(cornerRadius: 8).fill(settings.icon.shape == shape ? Color.accentColor.opacity(0.18) : Color.primary.opacity(0.04)))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    TextField("Badge format", text: $settings.icon.badgeFormat)
                    Toggle("Persian digits in badge", isOn: $settings.icon.badgePersianDigits)
                    HStack {
                        Text("Font size")
                        Slider(value: $settings.icon.fontSize, in: 7...14, step: 0.5)
                        Text(String(format: "%.1f", settings.icon.fontSize)).monospacedDigit().frame(width: 34)
                    }
                    Toggle("Bold", isOn: $settings.icon.bold)
                }
            }

            if settings.icon.layout != .badge {
                Section("Text") {
                    TextField("Text format", text: $settings.icon.textFormat)
                    Toggle("Persian digits in text", isOn: $settings.icon.textPersianDigits)
                    HStack {
                        ForEach(["{wd} {jd} {jmn}", "{jd} {jmn} {jy}", "{jy}/{jm}/{jd}", "{wds} {gd} {gms}", "{jd} {jmn} · {time}"], id: \.self) { preset in
                            Button(preset) { settings.icon.textFormat = preset }.controlSize(.small)
                        }
                    }
                }
            }

            Section("Colors") {
                Toggle("Custom colors (off = follows the menubar, light or dark)", isOn: $settings.icon.useCustomColors)
                if settings.icon.useCustomColors {
                    ColorPicker("Shape / text color", selection: Binding(get: { Color(hex: settings.icon.shapeColor) }, set: { settings.icon.shapeColor = $0.hexString }), supportsOpacity: false)
                    ColorPicker("Text inside filled shapes", selection: Binding(get: { Color(hex: settings.icon.textColor) }, set: { settings.icon.textColor = $0.hexString }), supportsOpacity: false)
                }
            }

            Section("Format tokens") {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: 4) {
                    ForEach(DateTokens.help, id: \.0) { token, meaning in
                        HStack {
                            Text(token).font(.system(.caption, design: .monospaced)).fontWeight(.semibold)
                            Text(meaning).font(.app(.caption)).foregroundStyle(.secondary)
                            Spacer()
                            Text(DateTokens.format(token, date: model.now, persianDigits: false)).font(.app(.caption)).foregroundStyle(.tertiary)
                        }
                    }
                }
                Text("Anything that isn't a token is shown as typed, e.g. “📅 {jd}/{jm}”.").font(.app(.caption)).foregroundStyle(.secondary)
            }

            Section {
                HStack { Spacer(); Button("Reset icon") { settings.icon = IconConfig() } }
            }
        }
        .formStyle(.grouped)
    }

    private func preview(dark: Bool) -> some View {
        let cfg = settings.icon
        return HStack(spacing: 4) {
            if cfg.layout != .text {
                Image(nsImage: MenubarIcon.badge(MenubarIcon.badgeText(cfg, date: model.now), config: cfg))
                    .renderingMode(cfg.useCustomColors ? .original : .template)
            }
            if cfg.layout != .badge {
                Text(AttributedString(MenubarIcon.title(cfg, date: model.now)))
                    .font(.app(size: 13))
            }
        }
        .foregroundStyle(dark ? Color.white : Color.black)
        .padding(.horizontal, 14)
        .frame(height: 28)
        .background(RoundedRectangle(cornerRadius: 6).fill(dark ? Color(white: 0.16) : Color(white: 0.93)))
        .environment(\.colorScheme, dark ? .dark : .light)
    }
}

// MARK: - Desktop widgets help

struct DesktopWidgetsView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Card {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Add jDate to your desktop or Notification Center", systemImage: "rectangle.3.group").font(.app(.headline))
                        Text("1. Right-click an empty spot on the desktop and choose **Edit Widgets…** (or click the date/time in the menubar and scroll to **Edit Widgets**).")
                        Text("2. Search for **jDate**, pick a widget and a size, and drag it onto the desktop or into the sidebar.")
                        Text("3. Right-click the placed widget › **Edit Widget** to change its settings.")
                        Button("Open Notification Center widget gallery") {
                            NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Library/CoreServices/NotificationCenter.app"))
                        }
                        .buttonStyle(.link)
                    }
                }
                ForEach(Self.kinds, id: \.0) { title, symbol, detail in
                    Card {
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: symbol).font(.app(.title2)).foregroundStyle(.tint).frame(width: 30)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(title).fontWeight(.semibold)
                                Text(detail).font(.app(.callout)).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                Text("Widgets read weather, events and birthdays that the jDate app saved, so keep jDate running in the menubar for them to stay fresh. Dates and clocks always update on their own.")
                    .font(.app(.caption)).foregroundStyle(.secondary)
            }
            .padding(24)
        }
    }

    static let kinds: [(String, String, String)] = [
        ("Today", "calendar", "Today in Jalali, Gregorian and Hijri. Choose the main calendar, which calendars to show, Persian or Latin digits, theme and today's events. Small, medium and large."),
        ("Month", "calendar.badge.clock", "A full month grid in Jalali or Gregorian with holidays in red and today highlighted. Medium and large."),
        ("World Clock", "globe", "Up to four cities with live time, day/night and the difference from your time. Small and medium."),
        ("Upcoming", "list.bullet", "Holidays, occasions, birthdays and your calendar events for the coming days."),
        ("Weather", "cloud.sun", "Current weather of your cities as last fetched by jDate."),
        ("Countdown", "hourglass", "Days left until Nowruz, Yalda or any date you choose in any calendar."),
    ]
}

// MARK: - General

struct GeneralView: View {
    @ObservedObject var model: AppModel
    @ObservedObject var settings: AppSettings
    @AppStorage(Prefs.islamicOffsetKey, store: Prefs.defaults) private var islamicOffset = 0
    @AppStorage(Prefs.hijriVariantKey, store: Prefs.defaults) private var hijriVariant: HijriVariant = .islamic
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var loginError: String?

    var body: some View {
        Form {
            Section("General") {
                Toggle("Launch at login", isOn: Binding(get: { launchAtLogin }, set: setLaunchAtLogin))
                if let loginError { Text(loginError).font(.app(.caption)).foregroundStyle(.red) }
                Toggle("24-hour clocks", isOn: $settings.general.clock24h)
            }

            Section {
                Picker("Copied date format", selection: $settings.general.copyFormat) {
                    ForEach(CopyFormat.allCases) { Text($0.title).tag($0) }
                }
                LabeledContent("Example", value: settings.general.copyFormat.string(model.now, .jalali))
            } header: {
                Text("Copy")
            } footer: {
                Text("Used when you click a date in the popover (⌘C / ⌘X / ⌘A) or in the converter.").font(.app(.caption)).foregroundStyle(.secondary)
            }

            Section {
                Toggle("Open jDate with a keyboard shortcut", isOn: $settings.general.hotkeyEnabled)
                if settings.general.hotkeyEnabled {
                    HStack(spacing: 12) {
                        Toggle("⌃ Control", isOn: $settings.general.hotkeyControl)
                        Toggle("⌥ Option", isOn: $settings.general.hotkeyOption)
                        Toggle("⌘ Command", isOn: $settings.general.hotkeyCommand)
                        Toggle("⇧ Shift", isOn: $settings.general.hotkeyShift)
                    }
                    .toggleStyle(.checkbox)
                    Picker("Key", selection: $settings.general.hotkeyKey) {
                        ForEach(Hotkey.keys, id: \.self) { Text($0).tag($0) }
                    }
                    LabeledContent("Shortcut", value: settings.general.hotkeyDescription)
                }
            } header: {
                Text("Global shortcut")
            } footer: {
                Text("Works from any app. Pick at least one modifier.").font(.app(.caption)).foregroundStyle(.secondary)
            }

            Section {
                Picker("Calendar", selection: $hijriVariant) {
                    ForEach(HijriVariant.allCases) { Text($0.title).tag($0) }
                }
                Stepper(value: $islamicOffset, in: -4...4) {
                    LabeledContent("Day offset", value: islamicOffset > 0 ? "+\(islamicOffset)" : "\(islamicOffset)")
                }
                LabeledContent("Today in Hijri") {
                    Text("\(CalendarService.long(model.now, .islamic))  ·  \(CalendarService.iso(model.now, .islamic))")
                        .id("\(islamicOffset)-\(hijriVariant.rawValue)")
                }
            } header: {
                Text("Islamic (Hijri) date")
            } footer: {
                Text("The Hijri date depends on moon sighting and can differ by a day or two between countries. Shift it here to match your local calendar; lunar holidays move with it.")
                    .font(.app(.caption)).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .onAppear { launchAtLogin = SMAppService.mainApp.status == .enabled }
        .onChange(of: islamicOffset) { _, _ in model.events.invalidate() }
        .onChange(of: hijriVariant) { _, _ in model.events.invalidate() }
    }

    private func setLaunchAtLogin(_ on: Bool) {
        do {
            if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            loginError = nil
        } catch {
            loginError = "Couldn't change the login item: \(error.localizedDescription)"
        }
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }
}
