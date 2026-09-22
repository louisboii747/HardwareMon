import SwiftUI
import WidgetKit

struct HardwareSnapshotEntry: TimelineEntry {
    let date: Date
    let cpuUsage: Double
    let memoryUsage: Double
}

struct HardwareSnapshotProvider: TimelineProvider {
    func placeholder(in context: Context) -> HardwareSnapshotEntry {
        HardwareSnapshotEntry(date: .now, cpuUsage: 0.42, memoryUsage: 0.68)
    }

    func getSnapshot(
        in context: Context,
        completion: @escaping (HardwareSnapshotEntry) -> Void
    ) {
        completion(placeholder(in: context))
    }

    func getTimeline(
        in context: Context,
        completion: @escaping (Timeline<HardwareSnapshotEntry>) -> Void
    ) {
        let entry = HardwareSnapshotEntry(date: .now, cpuUsage: 0, memoryUsage: 0)
        completion(Timeline(entries: [entry], policy: .after(.now.addingTimeInterval(15 * 60))))
    }
}

struct HardwareSnapshotWidgetView: View {
    let entry: HardwareSnapshotEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("HardwareMon", systemImage: "cpu")
                .font(.headline)

            metricRow("CPU", value: entry.cpuUsage)
            metricRow("Memory", value: entry.memoryUsage)

            Text(entry.date, style: .time)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func metricRow(_ title: LocalizedStringKey, value: Double) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value, format: .percent.precision(.fractionLength(0)))
                .monospacedDigit()
        }
    }
}

struct HardwareMonWidgets: Widget {
    let kind = "HardwareMonSnapshot"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: HardwareSnapshotProvider()) { entry in
            HardwareSnapshotWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Hardware Snapshot")
        .description("See current hardware utilization at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

#Preview(as: .systemSmall) {
    HardwareMonWidgets()
} timeline: {
    HardwareSnapshotEntry(date: .now, cpuUsage: 0.42, memoryUsage: 0.68)
}
