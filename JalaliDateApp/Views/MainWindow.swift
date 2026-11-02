import SwiftUI

struct MainWindowView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        NavigationSplitView {
            List(selection: Binding(get: { model.tab }, set: { if let t = $0 { model.tab = t } })) {
                ForEach(MainTab.groups, id: \.0) { group in
                    Section(group.0) {
                        ForEach(group.1) { tab in
                            Label(tab.title, systemImage: tab.symbol).tag(tab)
                        }
                    }
                }
            }
            .navigationSplitViewColumnWidth(min: 190, ideal: 205, max: 260)
        } detail: {
            Group {
                switch model.tab {
                case .converter: ConverterView(model: model)
                case .difference: DateDifferenceView(model: model)
                case .months: MonthsView(model: model)
                case .events: EventsSettingsView(model: model, events: model.events)
                case .birthdays: BirthdaysView(model: model, store: model.birthdays)
                case .weather: WeatherSettingsView(model: model, weather: model.weather)
                case .layout: LayoutView(model: model, settings: model.settings)
                case .theme: ThemeView(model: model, settings: model.settings)
                case .fonts: FontSettingsView(fonts: FontSettings.shared)
                case .icon: IconDesignerView(model: model, settings: model.settings)
                case .desktopWidgets: DesktopWidgetsView()
                case .general: GeneralView(model: model, settings: model.settings)
                case .about: AboutView(model: model)
                case .changelog: ChangelogView()
                }
            }
            .navigationTitle(model.tab.title)
        }
        .frame(minWidth: 860, minHeight: 580)
    }
}

/// Rounded card used by the detail pages.
struct Card<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.primary.opacity(0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.08))
            )
    }
}

/// City search field used by weather, clocks and theme pages.
struct CityPicker: View {
    let title: String
    let onPick: (City) -> Void
    @State private var query = ""
    @State private var results: [City] = []
    @State private var searching = false
    @State private var task: Task<Void, Never>?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                TextField(title, text: $query)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(search)
                    .onChange(of: query) { _, _ in
                        task?.cancel()
                        task = Task {
                            try? await Task.sleep(for: .milliseconds(450))
                            if !Task.isCancelled { search() }
                        }
                    }
                if searching { ProgressView().controlSize(.small) }
            }
            ForEach(results) { c in
                Button {
                    onPick(c)
                    query = ""
                    results = []
                } label: {
                    HStack {
                        Image(systemName: "mappin.circle.fill").foregroundStyle(.secondary)
                        Text(c.name).fontWeight(.medium)
                        Text(c.country).foregroundStyle(.secondary)
                        Spacer()
                        Text(c.timeZone).font(.app(.caption)).foregroundStyle(.secondary)
                        Text(c.offsetText()).font(.app(.caption).monospacedDigit()).foregroundStyle(.secondary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.vertical, 2)
            }
        }
    }

    private func search() {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard q.count >= 2 else { results = []; return }
        searching = true
        Task {
            let r = await CitySearch.search(q)
            if q == query.trimmingCharacters(in: .whitespaces) { results = Array(r.prefix(6)) }
            searching = false
        }
    }
}
