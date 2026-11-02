import AppKit
import Combine
import SwiftUI

/// Observable wrapper around the `AppFont` keys, so open windows rebuild when the font changes.
@MainActor
final class FontSettings: ObservableObject {
    static let shared = FontSettings()

    @Published var family: String { didSet { Prefs.defaults.set(family, forKey: AppFont.familyKey) } }
    @Published var scale: Double { didSet { Prefs.defaults.set(scale, forKey: AppFont.scaleKey) } }
    @Published var useInWidgets: Bool { didSet { Prefs.defaults.set(useInWidgets, forKey: AppFont.widgetsKey) } }
    @Published var useInMenubar: Bool { didSet { Prefs.defaults.set(useInMenubar, forKey: AppFont.menubarKey) } }

    private init() {
        family = Prefs.defaults.string(forKey: AppFont.familyKey) ?? ""
        let s = Prefs.defaults.double(forKey: AppFont.scaleKey)
        scale = s == 0 ? 1 : s
        useInWidgets = AppFont.useInWidgets
        useInMenubar = AppFont.useInMenubar
    }

    var signature: String { "\(family)|\(scale)" }

    /// Kept here (not in view state) so a rebuild after picking a font keeps the search and list.
    @Published var query = ""
    var persian: [String] = []
    var other: [String] = []
}

/// Root wrapper: sets the default font for unstyled text and rebuilds the tree on font changes.
struct FontRoot<Content: View>: View {
    @ObservedObject private var fonts = FontSettings.shared
    @ViewBuilder let content: () -> Content

    @State private var applied = AppFont.signature

    var body: some View {
        content()
            .font(.app(size: 13))
            .id(applied)
            // Debounced so dragging the size slider doesn't rebuild on every step.
            .onReceive(fonts.$scale.combineLatest(fonts.$family).debounce(for: .seconds(0.35), scheduler: RunLoop.main)) { _ in
                if applied != AppFont.signature { applied = AppFont.signature }
            }
    }
}

struct FontSettingsView: View {
    @ObservedObject var fonts: FontSettings
    @State private var persian: [String] = FontSettings.shared.persian
    @State private var other: [String] = FontSettings.shared.other

    private static let systemLabel = "System (San Francisco)"

    var body: some View {
        Form {
            Section {
                LabeledContent("Current font", value: fonts.family.isEmpty ? Self.systemLabel : fonts.family)
                HStack {
                    Text("Size")
                    Slider(value: $fonts.scale, in: 0.85...1.3, step: 0.05)
                    Text("\(Int((fonts.scale * 100).rounded()))%").monospacedDigit().frame(width: 44, alignment: .trailing)
                }
                Toggle("Use in desktop widgets", isOn: $fonts.useInWidgets)
                Toggle("Use in the menubar icon and text", isOn: $fonts.useInMenubar)
                if !fonts.family.isEmpty || fonts.scale != 1 {
                    Button("Reset to system font") { fonts.family = ""; fonts.scale = 1 }
                }
            } header: {
                Text("App font")
            } footer: {
                Text("Applies to the popover, this window and (optionally) the widgets and menubar. Any font installed on this Mac can be used; fonts that can write Persian are listed first.")
                    .font(.app(.caption)).foregroundStyle(.secondary)
            }

            Section("Preview") {
                VStack(alignment: .trailing, spacing: 4) {
                    Text("دوشنبه ۱۱ آبان ۱۴۰۵").font(.app(size: 20, weight: .bold))
                    Text("۲۲ جمادی‌الاول ۱۴۴۸ · Monday 2 November 2026").font(.app(size: 13))
                    Text("رویداد امروز: روز دانش‌آموز · 0123456789 · ۰۱۲۳۴۵۶۷۸۹").font(.app(size: 11)).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
                .environment(\.layoutDirection, .rightToLeft)
            }

            Section {
                TextField("Search fonts", text: $fonts.query).textFieldStyle(.roundedBorder)
                fontRow(Self.systemLabel, value: "")
                let p = filtered(persian), o = filtered(other)
                if !p.isEmpty {
                    Text("Persian / Arabic (\(p.count))").font(.app(.caption).weight(.semibold)).foregroundStyle(.secondary)
                    ForEach(p, id: \.self) { fontRow($0, value: $0) }
                }
                if !o.isEmpty {
                    Text("Other fonts (\(o.count))").font(.app(.caption).weight(.semibold)).foregroundStyle(.secondary)
                    ForEach(o, id: \.self) { fontRow($0, value: $0) }
                }
                if persian.isEmpty && other.isEmpty { ProgressView().controlSize(.small) }
            } header: {
                Text("Installed fonts")
            }
        }
        .formStyle(.grouped)
        .task {
            guard persian.isEmpty else { return }
            let list = await Task.detached(priority: .userInitiated) { AppFont.families() }.value
            persian = list.persian
            other = list.other
            fonts.persian = list.persian
            fonts.other = list.other
        }
    }

    private func filtered(_ list: [String]) -> [String] {
        let q = fonts.query.trimmingCharacters(in: .whitespaces)
        return q.isEmpty ? list : list.filter { $0.localizedCaseInsensitiveContains(q) }
    }

    private func fontRow(_ title: String, value: String) -> some View {
        Button {
            fonts.family = value
        } label: {
            HStack {
                Image(systemName: fonts.family == value ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(fonts.family == value ? Color.accentColor : Color.secondary)
                Text(title).font(.system(size: 13))
                Spacer()
                Text("آبان ۱۴۰۵ Aa")
                    .font(value.isEmpty ? .system(size: 14) : .custom(value, size: 14))
                    .foregroundStyle(.secondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
