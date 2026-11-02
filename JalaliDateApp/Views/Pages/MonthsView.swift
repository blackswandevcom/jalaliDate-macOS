import SwiftUI

struct MonthsView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        let current: [CalendarKind: Int] = Dictionary(uniqueKeysWithValues: CalendarKind.allCases.map {
            ($0, CalendarService.ymd(model.now, $0).month)
        })
        let columns: [CalendarKind] = [.gregorian, .islamic, .jalali]

        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Card {
                    Grid(alignment: .center, horizontalSpacing: 6, verticalSpacing: 4) {
                        GridRow {
                            Text("#").gridColumnAlignment(.center)
                            ForEach(columns) { kind in
                                Label(kind.title, systemImage: kind.symbol)
                                    .foregroundStyle(kind.tint)
                            }
                            Text("#")
                        }
                        .font(.app(size: 12, weight: .semibold))
                        .padding(.bottom, 4)

                        Divider().gridCellUnsizedAxes(.horizontal)

                        ForEach(1...12, id: \.self) { m in
                            GridRow {
                                Text("\(m)")
                                    .foregroundStyle(.secondary)
                                    .monospacedDigit()
                                ForEach(columns) { kind in
                                    let isCurrent = current[kind] == m
                                    Text(kind.monthNames[m - 1])
                                        .font(.app(size: 13, weight: isCurrent ? .semibold : .regular))
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 5)
                                        .background(
                                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                                .fill(isCurrent ? kind.tint.opacity(0.18) : Color.clear)
                                        )
                                        .foregroundStyle(isCurrent ? kind.tint : Color.primary)
                                }
                                Text(CalendarService.persianDigits(m))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                HStack(spacing: 14) {
                    ForEach(columns) { kind in
                        Label("Current \(kind.shortTitle) month", systemImage: "circle.fill")
                            .foregroundStyle(kind.tint)
                    }
                }
                .font(.app(.caption))
            }
            .padding(24)
        }
    }
}
