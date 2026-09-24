//
//  HardwareMonApp.swift
//  HardwareMon
//
//  Created by Louis Hinchliffe on 22/09/2026.
//

import SwiftUI
#if os(macOS)
import AppKit
#endif

@main
struct HardwareMonApp: App {
    @State private var model = MonitorModel()

    var body: some Scene {
        WindowGroup("HardwareMon", id: "main") {
            ContentView(model: model)
        }

        #if os(macOS)
        MenuBarExtra {
            MenuBarStatusView(model: model)
        } label: {
            Text(menuBarTitle)
        }
        .menuBarExtraStyle(.window)

        Settings {
            NativeSettingsView(model: model)
        }
        #endif
    }

    private var menuBarTitle: String {
        guard let cpu = model.snapshot?.cpu.value?.totalPercent else { return "HardwareMon" }
        if let temperature = model.snapshot?.sensors.first(where: { $0.unit == "°C" })?.value {
            return "CPU \(HardwareMonFormat.percent(cpu)) · \(HardwareMonFormat.temperature(temperature))"
        }
        return "CPU \(HardwareMonFormat.percent(cpu))"
    }
}

#if os(macOS)
private struct MenuBarStatusView: View {
    let model: MonitorModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("HardwareMon")
                .font(.headline)
            LabeledContent("CPU", value: HardwareMonFormat.percent(model.snapshot?.cpu.value?.totalPercent ?? 0))
            LabeledContent("Memory", value: HardwareMonFormat.percent((model.snapshot?.memory.value?.usedFraction ?? 0) * 100))
            LabeledContent("Thermal", value: model.snapshot?.thermalState.value?.rawValue.capitalized ?? "Unavailable")
            Divider()
            Button("Open HardwareMon") { openWindow(id: "main") }
                .keyboardShortcut("o")
            Button("Quit HardwareMon") { NSApplication.shared.terminate(nil) }
                .keyboardShortcut("q")
        }
        .padding()
        .frame(width: 260)
        .task { model.start() }
    }
}

private struct NativeSettingsView: View {
    let model: MonitorModel

    var body: some View {
        Form {
            Picker("Sample interval", selection: Bindable(model).samplingInterval) {
                Text("1 second").tag(1.0)
                Text("2 seconds").tag(2.0)
                Text("5 seconds").tag(5.0)
                Text("10 seconds").tag(10.0)
            }
            LabeledContent("Remote monitoring", value: "Off")
            Text("Local monitoring remains available without a backend.")
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(width: 480)
    }
}
#endif
