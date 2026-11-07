import SwiftUI

struct AboutView: View {
    @ObservedObject var model: AppModel

    static let repoURL = URL(string: "https://github.com/blackswandevcom/jalaliDate-macOS")!
    static let siteURL = URL(string: "https://blackswandevcom.github.io/jalaliDate-macOS/")!

    var body: some View {
        let latest = Changelog.releases.first
        let releaseDate = latest.flatMap { CalendarService.fromISO($0.date) }

        ScrollView {
            VStack(spacing: 18) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 112, height: 112)
                    .shadow(color: .black.opacity(0.15), radius: 8, y: 4)

                VStack(spacing: 4) {
                    Text("jDate Menubar")
                        .font(.app(size: 26, weight: .bold))
                    Text("Version \(AppModel.appVersion)" + (AppModel.buildNumber.isEmpty ? "" : " (\(AppModel.buildNumber))"))
                        .foregroundStyle(.secondary)
                    if let releaseDate {
                        Text("Released \(CalendarService.iso(releaseDate, .gregorian))  ·  \(CalendarService.iso(releaseDate, .jalali))")
                            .font(.app(.caption))
                            .foregroundStyle(.tertiary)
                    }
                }

                Text("Today's date in the Jalali (Persian), Gregorian and Islamic (Hijri) calendars, right in your menubar. Iranian holidays and occasions, your calendar events and birthdays, weather and world clocks, desktop widgets, a date converter and more. Clean, customizable, free and open source.")
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 460)

                Button {
                    model.tab = .changelog
                } label: {
                    Label("What's new in \(AppModel.appVersion)", systemImage: "sparkles")
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
                .controlSize(.large)

                HStack(spacing: 10) {
                    Link(destination: Self.repoURL) {
                        Label("Source on GitHub", systemImage: "chevron.left.forwardslash.chevron.right")
                    }
                    ShareLink(item: Self.siteURL,
                              subject: Text("jDate: Jalali calendar for the Mac menubar"),
                              message: Text("jDate puts the Jalali, Gregorian and Hijri dates in your Mac menubar, with Iranian holidays, birthdays, weather and widgets. Free and open source.")) {
                        Label("Share jDate", systemImage: "square.and.arrow.up")
                    }
                }
                .buttonStyle(.bordered)

                Divider().frame(maxWidth: 320)

                VStack(spacing: 8) {
                    Text("Developed by Amirhossein Hosseinpour")
                        .font(.app(size: 13, weight: .medium))
                    Text("First released on 13 Aban 1403 · 3 November 2024")
                        .font(.app(.caption))
                        .foregroundStyle(.secondary)
                    HStack(spacing: 10) {
                        Link(destination: URL(string: "https://amirhp.com")!) {
                            Label("Amirhp.com", systemImage: "person.crop.circle")
                        }
                        Link(destination: URL(string: "https://blackswandev.com")!) {
                            Label("BlackSwanDev.com", systemImage: "globe")
                        }
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding(32)
            .frame(maxWidth: .infinity)
        }
    }
}
