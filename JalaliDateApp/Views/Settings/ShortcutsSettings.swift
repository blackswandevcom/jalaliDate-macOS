import SwiftUI

/// Copy formats, the ⌘ keys in the popover, global copy shortcuts, the Open jDate shortcut and Spotlight.
struct ShortcutsSettingsView: View {
    @ObservedObject var model: AppModel
    @ObservedObject var settings: AppSettings
    @ObservedObject private var hotkeys = Hotkey.shared
    @State private var showTokens = false

    private static let presets: [(String, String)] = [
        ("{jy}/{jmm}/{jdd}", "1405/08/19"),
        ("{jd} {jmn} {jy}", "19 آبان 1405"),
        ("{wd} {jd} {jmn} {jy}", "Weekday, day, month and year"),
        ("{gy}-{gmm}-{gdd}", "2026-11-10"),
        ("{gd} {gmn} {gy}", "10 November 2026"),
        ("{wde}, {gmn} {gd}, {gy}", "Tuesday, November 10, 2026"),
        ("{hd} {hmn} {hy}", "Hijri"),
        ("{jy}-{jmm}-{jdd} | {gy}-{gmm}-{gdd}", "Jalali | Gregorian"),
        ("{jy}{jmm}{jdd}", "14050819 (file names)"),
    ]

    var body: some View {
        Form {
            Section {
                Toggle("Show shortcuts on the date tiles", isOn: $settings.copy.showHints)
                Picker("Copied date format", selection: $settings.general.copyFormat) {
                    ForEach(CopyFormat.allCases) { Text($0.title).tag($0) }
                }
                LabeledContent("Example", value: settings.general.copyFormat.string(model.now, .jalali))
            } header: {
                Text("In the popover")
            } footer: {
                Text("Hints print ⌘C, ⌘X… on the Jalali, Gregorian and Hijri tiles, with a small row under them for the other copy shortcuts. The format is used by the date tiles and their shortcuts.")
                    .font(.app(.caption)).foregroundStyle(.secondary)
            }

            ForEach($settings.copy.actions) { $action in
                actionSection($action)
            }

            Section {
                HStack {
                    Button {
                        settings.copy.actions.append(.newCustom())
                    } label: { Label("Add a custom format", systemImage: "plus") }
                    Menu("From a preset") {
                        ForEach(Self.presets, id: \.0) { pattern, title in
                            Button("\(DateTokens.format(pattern, date: model.now, persianDigits: false))   ·   \(title)") {
                                var a = CopyAction.newCustom(pattern: pattern)
                                a.name = title
                                settings.copy.actions.append(a)
                            }
                        }
                    }
                    .fixedSize()
                    Spacer()
                    Button("Format tokens…") { showTokens.toggle() }
                        .popover(isPresented: $showTokens) { tokenHelp }
                }
            } footer: {
                Text("A custom format is any text with tokens like {jy}/{jmm}/{jdd}. Give it a ⌘ key for the popover and, if you like, a global shortcut that copies today's date from any app.")
                    .font(.app(.caption)).foregroundStyle(.secondary)
            }

            openSection

            spotlightSection
        }
        .formStyle(.grouped)
    }

    // MARK: Copy actions

    @ViewBuilder
    private func actionSection(_ action: Binding<CopyAction>) -> some View {
        let a = action.wrappedValue
        Section {
            if a.kind == .custom {
                TextField("Name", text: action.name)
                TextField("Format", text: action.pattern)
                    .font(.system(.body, design: .monospaced))
                Toggle("Persian digits", isOn: action.persianDigits)
            }
            LabeledContent("Copies") {
                Text(a.text(for: model.now, format: settings.general.copyFormat))
                    .textSelection(.enabled)
                    .foregroundStyle(.secondary)
            }
            Picker("In the popover", selection: action.popoverKey) {
                Text("None").tag("")
                ForEach(CopySettings.popoverKeys, id: \.self) { Text("⌘ \($0)").tag($0) }
            }
            if let why = settings.copy.popoverConflict(a) {
                warning(why)
            }
            Toggle("Global shortcut (copies today's date from any app)", isOn: action.globalEnabled)
            if a.globalEnabled {
                ComboEditor(combo: action.global)
                if let why = settings.copy.globalConflict(a, popover: settings.general) {
                    warning(why)
                } else if hotkeys.taken.contains(a.id) {
                    warning("\(a.global.description) is already used by another app or by macOS")
                }
            }
        } header: {
            HStack {
                Label(a.kind == .custom ? (a.name.isEmpty ? "Custom format" : a.name) : a.name, systemImage: a.symbol)
                Spacer()
                if a.kind == .custom {
                    Button(role: .destructive) {
                        settings.copy.actions.removeAll { $0.id == a.id }
                    } label: { Image(systemName: "trash") }
                    .buttonStyle(.borderless)
                    .help("Remove this format")
                }
            }
        }
    }

    private func warning(_ text: String) -> some View {
        Label(text, systemImage: "exclamationmark.triangle.fill")
            .font(.app(.caption))
            .foregroundStyle(.orange)
    }

    private var tokenHelp: some View {
        ScrollView {
            Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 4) {
                ForEach(DateTokens.help, id: \.0) { token, meaning in
                    GridRow {
                        Text(token).font(.system(.caption, design: .monospaced)).fontWeight(.semibold).textSelection(.enabled)
                        Text(meaning).font(.app(.caption))
                        Text(DateTokens.format(token, date: model.now, persianDigits: false)).font(.app(.caption)).foregroundStyle(.secondary)
                    }
                }
            }
            .padding(14)
        }
        .frame(width: 380, height: 420)
    }

    // MARK: Open jDate

    private var openSection: some View {
        Section {
            Toggle("Open jDate with a keyboard shortcut", isOn: $settings.general.hotkeyEnabled)
            if settings.general.hotkeyEnabled {
                ComboEditor(combo: Binding(
                    get: { settings.general.hotkeyCombo },
                    set: { c in
                        settings.general.hotkeyKey = c.key
                        settings.general.hotkeyControl = c.control
                        settings.general.hotkeyOption = c.option
                        settings.general.hotkeyCommand = c.command
                        settings.general.hotkeyShift = c.shift
                    }))
                if hotkeys.taken.contains("popover") {
                    warning("\(settings.general.hotkeyDescription) is already used by another app or by macOS")
                }
            }
        } header: {
            Text("Open jDate")
        } footer: {
            Text("Works from any app. Pick at least one modifier.").font(.app(.caption)).foregroundStyle(.secondary)
        }
    }

    // MARK: Spotlight

    private var spotlightSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                spotlightRow("doc.on.doc", "Copy Date", "Copies a Jalali, Gregorian or Hijri date: today, tomorrow, +10, or any date you type.")
                spotlightRow("text.badge.plus", "Copy Date in Format", "Copies today's date (or any date) in one of your formats above.")
                spotlightRow("arrow.left.arrow.right", "Convert Date", "Type 1405/08/19, 2026-11-10, 19 آبان or 10 Nov and see it in all three calendars.")
                spotlightRow("plusminus", "Days Until Date", "How many days, weeks and months from today to a date, or since it.")
                spotlightRow("arrow.up.forward.app", "Open in Date Converter", "Opens the converter on a date.")
            }
            .padding(.vertical, 2)
        } header: {
            Text("Spotlight & Shortcuts")
        } footer: {
            Text("Press ⌘Space, type the action's name (or “jDate”), then Tab to fill in the date. The same actions are in the Shortcuts app, so you can give them their own keyboard shortcuts or use them with Siri.")
                .font(.app(.caption)).foregroundStyle(.secondary)
        }
    }

    private func spotlightRow(_ symbol: String, _ title: String, _ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: symbol).foregroundStyle(.tint).frame(width: 18)
            VStack(alignment: .leading, spacing: 1) {
                Text(title).fontWeight(.medium)
                Text(text).font(.app(.caption)).foregroundStyle(.secondary)
            }
        }
    }
}

/// Modifier checkboxes plus a key, for a global shortcut.
struct ComboEditor: View {
    @Binding var combo: KeyCombo

    var body: some View {
        HStack(spacing: 12) {
            Toggle("⌃", isOn: $combo.control).help("Control")
            Toggle("⌥", isOn: $combo.option).help("Option")
            Toggle("⇧", isOn: $combo.shift).help("Shift")
            Toggle("⌘", isOn: $combo.command).help("Command")
            Picker("Key", selection: $combo.key) {
                Text("–").tag("")
                ForEach(Hotkey.keys, id: \.self) { Text($0).tag($0) }
            }
            .frame(maxWidth: 140)
            Spacer()
            Text(combo.isValid ? combo.description : "Not set")
                .font(.system(.body, design: .rounded).weight(.semibold))
                .foregroundStyle(combo.isValid ? .primary : .secondary)
        }
        .toggleStyle(.checkbox)
    }
}
