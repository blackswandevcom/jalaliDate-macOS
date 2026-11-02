import SwiftUI

struct ChangelogView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(Changelog.releases.enumerated()), id: \.element.id) { index, release in
                    ReleaseRow(release: release, isLatest: index == 0, isLast: index == Changelog.releases.count - 1)
                }
            }
            .padding(24)
        }
    }
}

private struct ReleaseRow: View {
    let release: Release
    let isLatest: Bool
    let isLast: Bool

    var body: some View {
        let date = CalendarService.fromISO(release.date)

        HStack(alignment: .top, spacing: 14) {
            // Timeline
            VStack(spacing: 0) {
                Circle()
                    .fill(isLatest ? Color.orange : Color.secondary.opacity(0.5))
                    .frame(width: 11, height: 11)
                    .padding(.top, 5)
                if !isLast {
                    Rectangle()
                        .fill(Color.secondary.opacity(0.25))
                        .frame(width: 2)
                }
            }
            .frame(width: 12)

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("v\(release.version)")
                        .font(.app(size: 17, weight: .bold))
                    if isLatest {
                        Text("Latest")
                            .font(.app(size: 10, weight: .semibold))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Color.orange.opacity(0.2)))
                            .foregroundStyle(.orange)
                    }
                    Spacer()
                    if let date {
                        Text("\(CalendarService.iso(date, .gregorian))  ·  \(CalendarService.iso(date, .jalali))")
                            .font(.app(size: 11).monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(release.notes, id: \.self) { note in
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text("•").foregroundStyle(.secondary)
                            Text(note)
                        }
                    }
                }
                .font(.app(size: 13))
            }
            .padding(.bottom, 22)
        }
    }
}
