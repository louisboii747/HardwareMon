import SwiftUI

struct ContentView: View {
    var body: some View {
        NavigationSplitView {
            List {
                NavigationLink {
                    HardwareOverviewView()
                } label: {
                    Label("Overview", systemImage: "gauge.with.dots.needle.67percent")
                }

                NavigationLink {
                    Text("Sensor history will appear here.")
                } label: {
                    Label("History", systemImage: "chart.xyaxis.line")
                }
            }
            .navigationTitle("HardwareMon")
        } detail: {
            HardwareOverviewView()
        }
    }
}

private struct HardwareOverviewView: View {
    var body: some View {
        ContentUnavailableView {
            Label("Ready to Monitor", systemImage: "cpu")
        } description: {
            Text("Connect hardware data sources to begin showing live metrics.")
        }
        .navigationTitle("Overview")
    }
}

#Preview {
    ContentView()
}
