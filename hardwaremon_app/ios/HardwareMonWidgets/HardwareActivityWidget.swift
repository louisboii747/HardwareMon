#if os(iOS)
import ActivityKit
import SwiftUI
import WidgetKit

struct HardwareActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        let cpuUsage: Double
        let memoryUsage: Double
    }

    let sessionName: String
}

struct HardwareActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: HardwareActivityAttributes.self) { context in
            VStack(alignment: .leading, spacing: 8) {
                Label(context.attributes.sessionName, systemImage: "cpu")
                    .font(.headline)
                metrics(for: context.state)
            }
            .padding()
            .activityBackgroundTint(.black.opacity(0.85))
            .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label("CPU", systemImage: "cpu")
                }

                DynamicIslandExpandedRegion(.trailing) {
                    Text(context.state.cpuUsage, format: .percent.precision(.fractionLength(0)))
                        .monospacedDigit()
                }

                DynamicIslandExpandedRegion(.bottom) {
                    metrics(for: context.state)
                }
            } compactLeading: {
                Image(systemName: "cpu")
            } compactTrailing: {
                Text(context.state.cpuUsage, format: .percent.precision(.fractionLength(0)))
                    .monospacedDigit()
            } minimal: {
                Image(systemName: "cpu")
            }
            .keylineTint(.green)
        }
    }

    private func metrics(for state: HardwareActivityAttributes.ContentState) -> some View {
        HStack {
            Text("CPU")
            Text(state.cpuUsage, format: .percent.precision(.fractionLength(0)))
                .monospacedDigit()
            Spacer()
            Text("Memory")
            Text(state.memoryUsage, format: .percent.precision(.fractionLength(0)))
                .monospacedDigit()
        }
    }
}
#endif
