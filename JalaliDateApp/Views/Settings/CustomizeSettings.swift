import ServiceManagement
import SwiftUI
import UniformTypeIdentifiers

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
                    Toggle("Show the button bar at the bottom", isOn: $settings.layout.showFooter)
                    Toggle("Show the selected day's events in the header", isOn: Binding(
                        get: { settings.layout.header.visible(.events) },
                        set: { settings.layout.header[.events].visible = $0 }))
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
                    Text("Drag to reorder, switch off to hide. Without the button bar, right-click the date in the menu bar for Settings and Quit; the shortcuts ⌘E, ⌘D, ⌘, and ⌘Q still work in the popover.").font(.app(.caption)).foregroundStyle(.secondary)
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
                    Picker("Date tiles", selection: $settings.layout.compactDates) {
                        Text("Cards").tag(false)
                        Text("One line").tag(true)
                    }
                    .pickerStyle(.segmented)
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
    @ObservedObject var glass = GlassSettings.shared
    @State private var mediaError: String?
    @State private var importing = false

    var body: some View {
        Form {
            Section {
                HeroView(date: model.now, now: model.now,
                         theme: ThemeResolver.resolve(settings.theme, date: model.now, weather: model.weather.themeSnapshot),
                         weather: model.weather, animated: settings.theme.animated,
                         header: settings.layout.header,
                         events: settings.layout.header.visible(.events) ? model.events.events(on: model.now) : [])
                    .frame(width: 360)
                    .frame(maxWidth: .infinity)
            }

            Section {
                ForEach(HeaderItem.allCases) { item in
                    HeaderItemRow(item: item, style: Binding(
                        get: { settings.layout.header[item] },
                        set: { settings.layout.header[item] = $0 }))
                }
                HStack {
                    Spacer()
                    Button("Reset header") { settings.layout.headerRaw = nil }.controlSize(.small)
                }
            } header: {
                Text("Header contents")
            } footer: {
                caption("Show or hide each line of the header, and set its size and color. Weather shows on today; “Back to today” shows when another day is picked in the calendar. With “The day's events” on, the events of the picked day show in the header instead of the panel under the calendar.")
            }

            Section("Header theme") {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 72), spacing: 8)], spacing: 8) {
                    ForEach(ThemeMode.allCases) { mode in
                        let on = settings.theme.mode == mode
                        Button { settings.theme.mode = mode } label: {
                            VStack(spacing: 4) {
                                Image(systemName: mode.symbol).font(.app(size: 16)).frame(height: 20)
                                Text(mode.title).font(.app(.caption)).lineLimit(1)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(on ? Color.accentColor.opacity(0.18) : Color.primary.opacity(0.05)))
                            .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .strokeBorder(on ? Color.accentColor : .clear, lineWidth: 1.5))
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                switch settings.theme.mode {
                case .season:
                    caption("Changes with the Persian seasons: spring blossoms, summer saffron, autumn leaves, winter snow.")
                case .weather:
                    caption(model.weather.settings.themeCity == nil
                            ? "Pick a main city in Weather first."
                            : "Follows the current weather in \(model.weather.settings.themeCity!.name): clear, cloudy, rain, snow, storm, day and night.")
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
                    ColorPicker("From", selection: hexBinding(\.customA), supportsOpacity: false)
                    ColorPicker("To", selection: hexBinding(\.customB), supportsOpacity: false)
                case .accent:
                    caption("Uses your macOS accent color (System Settings › Appearance).")
                case .animated:
                    animatedControls
                case .media:
                    mediaControls
                case .occasion:
                    occasionGrid(pick: true)
                }
            }

            Section("Options") {
                Toggle("Animate the header while the popover is open", isOn: $settings.theme.animated)
                Toggle("Red header on Fridays (season, weather, preset and accent styles)", isOn: $settings.theme.fridayRed)
            }

            Section {
                Toggle("Switch to occasion themes on their days", isOn: $settings.theme.autoOccasions)
                if settings.theme.autoOccasions {
                    ForEach(Occasion.displayOrder) { o in
                        Toggle(isOn: Binding(
                            get: { !settings.theme.occasionsOff.contains(o) },
                            set: { on in
                                var off = settings.theme.occasionsOff
                                if on { off.remove(o) } else { off.insert(o) }
                                settings.theme.occasionsOff = off
                            })) {
                            HStack(spacing: 8) {
                                LinearGradient(colors: o.palette.map { Color(hex: $0) }, startPoint: .leading, endPoint: .trailing)
                                    .frame(width: 26, height: 14).clipShape(Capsule())
                                Text(o.title)
                                Spacer()
                                Text(o.when).font(.app(.caption)).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            } header: {
                Text("Occasions")
            } footer: {
                caption("During Nowruz, Yalda, Ramadan, Christmas and the other days below, the header changes to that day's theme, then goes back to your own style. Lunar dates follow your Hijri setting.")
            }

            Section {
                ColorPicker("Holidays", selection: hexBinding(\.holidayColor), supportsOpacity: false)
                ColorPicker("Weekends", selection: hexBinding(\.weekendColor), supportsOpacity: false)
                LabeledContent("Weekend days") {
                    HStack(spacing: 4) {
                        ForEach([7, 1, 2, 3, 4, 5, 6], id: \.self) { wd in
                            let on = settings.theme.weekendDays.contains(wd)
                            Button {
                                var days = settings.theme.weekendDays
                                if on { days.remove(wd) } else { days.insert(wd) }
                                settings.theme.weekendDays = days
                            } label: {
                                Text(Self.weekdayShort[wd - 1])
                                    .font(.app(size: 11, weight: on ? .semibold : .regular))
                                    .frame(width: 34, height: 24)
                                    .background(RoundedRectangle(cornerRadius: 6).fill(on ? Color(hex: settings.theme.weekendColor).opacity(0.22) : Color.primary.opacity(0.06)))
                                    .foregroundStyle(on ? Color(hex: settings.theme.weekendColor) : Color.primary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                HStack {
                    ForEach(DayColors.presets, id: \.0) { title, days in
                        Button(title) { settings.theme.weekendDays = days }.controlSize(.small)
                    }
                    Spacer()
                    Button("Reset") {
                        settings.theme.holidayColorRaw = nil
                        settings.theme.weekendColorRaw = nil
                        settings.theme.weekendDaysRaw = nil
                    }
                    .controlSize(.small)
                }
                dayColorPreview
            } header: {
                Text("Holidays & weekends")
            } footer: {
                caption("Used in the popover calendar, the events list and the desktop widgets.")
            }

            Section {
                Toggle("Custom popover background", isOn: $glass.popover.enabled)
                if glass.popover.enabled {
                    GlassControls(style: $glass.popover, showsSurface: true)
                }
            } header: {
                Text("Popover background")
            } footer: {
                caption("Like Terminal's window background: pick a color, how much of it covers the popover, and how blurred the desktop behind it is. Low opacity and low blur make the popover see-through. Liquid Glass keeps the macOS 26 glass edges and blurs the desktop the way Terminal does; Classic is the older frosted look. The Terminal preset matches Terminal's Pro profile.")
            }
        }
        .formStyle(.grouped)
    }

    static let weekdayShort = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

    private var dayColorPreview: some View {
        HStack(spacing: 14) {
            ForEach([("Normal", Color.primary), ("Weekend", Color(hex: settings.theme.weekendColor)), ("Holiday", Color(hex: settings.theme.holidayColor))], id: \.0) { label, color in
                VStack(spacing: 2) {
                    Text(CalendarService.persianDigits(label == "Normal" ? 12 : label == "Weekend" ? 15 : 22))
                        .font(.app(size: 15, weight: .medium)).foregroundStyle(color)
                        .frame(width: 34, height: 28)
                        .background(RoundedRectangle(cornerRadius: 7).fill(label == "Holiday" ? color.opacity(0.1) : .clear))
                    Text(label).font(.app(.caption2)).foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
    }

    // MARK: Occasions

    @ViewBuilder
    private func occasionGrid(pick: Bool) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 10)], spacing: 10) {
            ForEach(Occasion.displayOrder) { o in
                let selected = settings.theme.occasion == o
                Button { settings.theme.occasion = o } label: {
                    VStack(alignment: .leading, spacing: 3) {
                        AnimatedBackground(style: o.style, colors: o.palette.map { Color(hex: $0) },
                                           speed: o.speed, intensity: o.intensity, paused: !settings.theme.animated)
                            .frame(height: 52)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .strokeBorder(selected ? Color.accentColor : Color.primary.opacity(0.1), lineWidth: selected ? 2.5 : 1))
                        Text(o.title).font(.app(.caption)).lineLimit(1)
                        Text(o.when).font(.app(.caption2)).foregroundStyle(.secondary).lineLimit(1)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        caption("Shows the picked occasion all the time. To use them only on their days, keep your usual style and turn on \u{201C}Switch to occasion themes on their days\u{201D} below.")
    }

    // MARK: Animated

    @ViewBuilder
    private var animatedControls: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 130), spacing: 10)], spacing: 10) {
            ForEach(AnimatedStyle.allCases) { style in
                let selected = settings.theme.animStyle == style
                Button {
                    settings.theme.animStyle = style
                    settings.theme.animColorsRaw = nil
                } label: {
                    VStack(spacing: 4) {
                        AnimatedBackground(style: style, colors: (selected ? settings.theme.animColors : style.palette).map { Color(hex: $0) },
                                           speed: selected ? settings.theme.animSpeed : 1, intensity: selected ? settings.theme.animIntensity : 0.7,
                                           paused: !settings.theme.animated)
                            .frame(height: 48)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .strokeBorder(selected ? Color.accentColor : Color.primary.opacity(0.1), lineWidth: selected ? 2.5 : 1))
                        Text(style.title).font(.app(.caption)).lineLimit(1)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        caption(settings.theme.animStyle.detail)
        HStack(spacing: 14) {
            ForEach(0..<3, id: \.self) { i in
                ColorPicker(["Base", "Glow", "Detail"][i], selection: Binding(
                    get: { Color(hex: settings.theme.animColors[safe: i] ?? "#FFFFFF") },
                    set: { c in
                        var list = settings.theme.animColors
                        while list.count < 3 { list.append(list.last ?? "#FFFFFF") }
                        list[i] = c.hexString
                        settings.theme.animColors = list
                    }), supportsOpacity: false)
            }
            Spacer()
            Button("Reset colors") { settings.theme.animColorsRaw = nil }
                .disabled(settings.theme.animColorsRaw == nil)
        }
        LabeledContent("Speed") {
            Slider(value: $settings.theme.animSpeed, in: 0.2...3) { EmptyView() } minimumValueLabel: { Image(systemName: "tortoise") } maximumValueLabel: { Image(systemName: "hare") }
        }
        LabeledContent("Intensity") {
            Slider(value: $settings.theme.animIntensity, in: 0...1) { EmptyView() } minimumValueLabel: { Image(systemName: "circle.dotted") } maximumValueLabel: { Image(systemName: "circle.hexagongrid.fill") }
        }
    }

    // MARK: Photo / video

    @ViewBuilder
    private var mediaControls: some View {
        HStack(spacing: 10) {
            if let url = settings.theme.mediaPosterURL, let image = NSImage(contentsOf: url) {
                Image(nsImage: image).resizable().scaledToFill()
                    .frame(width: 96, height: 54)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(settings.theme.mediaFile == nil ? "No photo or video yet"
                     : settings.theme.mediaKind == .video ? "Video (loops, muted)" : "Photo")
                    .fontWeight(.medium)
                caption("Any photo, or a short video (mp4, mov). Videos play muted and loop while the popover is open; widgets show a still frame.")
            }
            Spacer()
            if importing { ProgressView().controlSize(.small) }
            Button(settings.theme.mediaFile == nil ? "Choose…" : "Replace…", action: pickMedia)
            if settings.theme.mediaFile != nil {
                Button("Remove", role: .destructive) {
                    HeaderMedia.remove(settings.theme.mediaFile)
                    HeaderMedia.removePoster()
                    settings.theme.mediaFile = nil
                    settings.theme.mediaKind = nil
                }
            }
        }
        if let mediaError { Text(mediaError).font(.app(.caption)).foregroundStyle(.red) }
        if settings.theme.mediaFile != nil {
            LabeledContent("Darken for readable text") {
                Slider(value: $settings.theme.mediaDim, in: 0...0.8)
            }
        }
    }

    private func pickMedia() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image, .movie]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.message = "Choose a photo or a short video for the jDate header"
        guard panel.runModal() == .OK, let src = panel.url else { return }
        importing = true
        mediaError = nil
        Task {
            defer { importing = false }
            do {
                let (name, kind) = try await HeaderMedia.importFile(src)
                let old = settings.theme.mediaFile
                settings.theme.mediaFile = name
                settings.theme.mediaKind = kind
                settings.theme.mode = .media
                if old != name { HeaderMedia.remove(old) }
                MediaCache.clear()
            } catch {
                mediaError = error.localizedDescription
            }
        }
    }

    private func hexBinding(_ key: WritableKeyPath<ThemeConfig, String>) -> Binding<Color> {
        Binding(get: { Color(hex: settings.theme[keyPath: key]) }, set: { settings.theme[keyPath: key] = $0.hexString })
    }

    private func caption(_ s: String) -> some View {
        Text(s).font(.app(.caption)).foregroundStyle(.secondary)
    }
}

/// One header line: on/off, size and colour.
struct HeaderItemRow: View {
    let item: HeaderItem
    @Binding var style: HeaderItemStyle

    var body: some View {
        HStack(spacing: 10) {
            Toggle(item.title, isOn: $style.visible)
                .frame(maxWidth: .infinity, alignment: .leading)
            Group {
                Slider(value: Binding(get: { style.size ?? item.defaultSize },
                                      set: { style.size = $0 == item.defaultSize ? nil : $0 }),
                       in: item.sizeRange, step: 1)
                    .frame(width: 110)
                Text("\(Int(style.size ?? item.defaultSize)) pt")
                    .font(.app(.caption).monospacedDigit()).frame(width: 36, alignment: .trailing)
                ColorPicker("", selection: Binding(get: { style.color.map { Color(hex: $0) } ?? .white },
                                                   set: { style.color = $0.hexString }),
                            supportsOpacity: false)
                    .labelsHidden()
                Button {
                    style.color = nil; style.size = nil
                } label: { Image(systemName: "arrow.counterclockwise") }
                    .buttonStyle(.borderless)
                    .help("Default size and color")
                    .opacity(style.color == nil && style.size == nil ? 0 : 1)
                    .disabled(style.color == nil && style.size == nil)
            }
            .disabled(!style.visible)
        }
    }
}

/// Color, opacity, blur and text controls shared by the popover and the widgets.
struct GlassControls: View {
    @Binding var style: GlassStyle
    var blurNote: String? = nil
    /// The popover can use Liquid Glass; the desktop widgets can't.
    var showsSurface = false

    var body: some View {
        LabeledContent("Preset") {
            HStack(spacing: 6) {
                ForEach(Self.presets, id: \.0) { title, preset in
                    Button {
                        var p = preset
                        p.enabled = style.enabled
                        style = p
                    } label: {
                        Label(title, systemImage: "checkmark").labelStyle(PresetLabelStyle(selected: matches(preset)))
                    }
                    .controlSize(.small)
                }
            }
        }
        if showsSurface && GlassSurface.supportsLiquid {
            Picker("Material", selection: $style.surface) {
                ForEach(GlassSurface.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
        }
        ColorPicker("Color", selection: Binding(get: { style.tintColor }, set: { style.tint = $0.hexString }), supportsOpacity: false)
        LabeledContent("Opacity") {
            HStack {
                Slider(value: $style.opacity, in: 0...1)
                Text("\(Int((style.opacity * 100).rounded()))%").monospacedDigit().frame(width: 40, alignment: .trailing)
            }
        }
        LabeledContent("Blur") {
            HStack {
                Slider(value: $style.blur, in: 0...1)
                Text("\(Int((style.blur * 100).rounded()))%").monospacedDigit().frame(width: 40, alignment: .trailing)
            }
        }
        if let blurNote { Text(blurNote).font(.app(.caption)).foregroundStyle(.secondary) }
        Picker("Text", selection: $style.text) {
            ForEach(GlassText.allCases) { Text($0.title).tag($0) }
        }
    }

    /// The current settings are this preset (sliders within half a percent).
    private func matches(_ p: GlassStyle) -> Bool {
        style.tint.uppercased() == p.tint.uppercased() && abs(style.opacity - p.opacity) < 0.005
            && abs(style.blur - p.blur) < 0.005 && style.text == p.text
            && (!showsSurface || style.surface == p.surface)
    }

    static let presets: [(String, GlassStyle)] = [
        // Terminal's "Pro" profile: black at 71%, blur 75%.
        ("Terminal", GlassStyle(enabled: true, tint: "#000000", opacity: 0.71, blur: 0.75, text: .light, surfaceRaw: .liquid)),
        ("Clear", GlassStyle(enabled: true, tint: "#000000", opacity: 0.0, blur: 0.0, text: .auto)),
        ("Frosted", GlassStyle(enabled: true, tint: "#FFFFFF", opacity: 0.15, blur: 1, text: .auto)),
        ("Smoke", GlassStyle(enabled: true, tint: "#0F172A", opacity: 0.55, blur: 0.5, text: .light)),
        ("Paper", GlassStyle(enabled: true, tint: "#FAF7F0", opacity: 0.85, blur: 0.6, text: .dark)),
    ]
}

/// Preset button title, with a check mark on the one in use.
private struct PresetLabelStyle: LabelStyle {
    var selected: Bool
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 3) {
            if selected { configuration.icon.font(.system(size: 9, weight: .bold)) }
            configuration.title
        }
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
    @ObservedObject var glass = GlassSettings.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Card {
                    HStack(alignment: .top, spacing: 18) {
                        VStack(alignment: .leading, spacing: 10) {
                            Label("Glass background", systemImage: "square.on.square.intersection.dashed").font(.app(.headline))
                            Toggle("Use for all jDate widgets", isOn: $glass.widget.enabled)
                            Text("Or turn it on per widget: right-click a widget › Edit Widget › Style › Glass.")
                                .font(.app(.caption)).foregroundStyle(.secondary)
                            Form {
                                GlassControls(style: $glass.widget,
                                              blurNote: "Widgets can't set an exact blur, so the blur picks the nearest system material.")
                            }
                            .formStyle(.columns)
                        }
                        WidgetGlassPreview(style: glass.widget)
                    }
                }
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

/// Rough preview of a small widget on the desktop with the glass settings.
struct WidgetGlassPreview: View {
    let style: GlassStyle

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: "#0E8FB0"), Color(hex: "#F59E0B"), Color(hex: "#DB2777")],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            Circle().fill(.white.opacity(0.7)).frame(width: 40).offset(x: -40, y: -30)
            Circle().fill(Color(hex: "#1F4FA8")).frame(width: 60).offset(x: 45, y: 40)
            VStack(alignment: .trailing, spacing: 2) {
                let now = Date()
                Text(CalendarService.weekday(now, .jalali)).font(.app(size: 12, weight: .semibold))
                Text(CalendarService.persianDigits(CalendarService.ymd(now, .jalali).day)).font(.app(size: 34, weight: .bold, design: .rounded))
                Text(CalendarService.format(now, .jalali, "MMMM yyyy", locale: Locale(identifier: "fa_IR"))).font(.app(size: 11)).foregroundStyle(.secondary)
            }
            .frame(width: 120, height: 120)
            .background {
                ZStack {
                    if let m = style.material { Rectangle().fill(m) }
                    style.tintColor.opacity(style.opacity)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .glassScheme(style)
        }
        .frame(width: 170, height: 170)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
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
