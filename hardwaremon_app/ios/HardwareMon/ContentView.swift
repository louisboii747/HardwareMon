import Charts
import SwiftUI

enum AppPage: String, CaseIterable, Identifiable {
    case overview
    case cpu
    case memory
    case storage
    case network
    case battery
    case hardware
    case history
    case settings

    var id: Self { self }

    var title: LocalizedStringResource {
        switch self {
        case .overview: "Overview"
        case .cpu: "CPU"
        case .memory: "Memory"
        case .storage: "Storage"
        case .network: "Network"
        case .battery: "Battery"
        case .hardware: "Hardware"
        case .history: "History"
        case .settings: "Settings"
        }
    }

    var symbol: String {
        switch self {
        case .overview: "gauge.with.dots.needle.67percent"
        case .cpu: "cpu"
        case .memory: "memorychip"
        case .storage: "internaldrive"
        case .network: "network"
        case .battery: "battery.75percent"
        case .hardware: "desktopcomputer"
        case .history: "chart.xyaxis.line"
        case .settings: "gearshape"
        }
    }
}

struct ContentView: View {
    let model: MonitorModel
    @State private var selection: AppPage? = .overview

    init(model: MonitorModel) {
        self.model = model
    }

    var body: some View {
        #if os(macOS)
        MacRootView(model: model, selection: $selection)
            .frame(minWidth: 900, minHeight: 620)
        #else
        IOSRootView(model: model)
        #endif
    }
}

#if os(macOS)
private struct MacRootView: View {
    let model: MonitorModel
    @Binding var selection: AppPage?

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                Section {
                    SidebarRow(page: .overview)
                }
                Section("Monitoring") {
                    SidebarRow(page: .cpu)
                    SidebarRow(page: .memory)
                    SidebarRow(page: .storage)
                    SidebarRow(page: .network)
                    if model.snapshot?.battery.value != nil {
                        SidebarRow(page: .battery)
                    }
                }
                Section("Hardware") {
                    SidebarRow(page: .hardware)
                }
                Section("Other") {
                    SidebarRow(page: .history)
                    SidebarRow(page: .settings)
                }
            }
            .navigationTitle("HardwareMon")
        } detail: {
            PageView(page: selection ?? .overview, model: model)
        }
        .task { model.start() }
        .onDisappear { model.stop() }
    }
}

private struct SidebarRow: View {
    let page: AppPage

    var body: some View {
        Label(page.title, systemImage: page.symbol)
            .tag(page)
    }
}
#else
private struct IOSRootView: View {
    let model: MonitorModel

    var body: some View {
        TabView {
            Tab("Overview", systemImage: "gauge.with.dots.needle.67percent") {
                NavigationStack { PageView(page: .overview, model: model) }
            }
            Tab("Hardware", systemImage: "cpu") {
                NavigationStack { PageView(page: .hardware, model: model) }
            }
            Tab("Live", systemImage: "waveform.path.ecg") {
                NavigationStack { PageView(page: .cpu, model: model) }
            }
            Tab("Devices", systemImage: "desktopcomputer.and.macbook") {
                NavigationStack {
                    ContentUnavailableView(
                        "No Remote Devices",
                        systemImage: "network.slash",
                        description: Text("Pairing is optional. This device remains fully functional offline.")
                    )
                    .navigationTitle("Devices")
                }
            }
        }
        .task { model.start() }
        .onDisappear { model.stop() }
    }
}
#endif

private struct PageView: View {
    let page: AppPage
    let model: MonitorModel

    var body: some View {
        switch page {
        case .overview:
            OverviewView(snapshot: model.snapshot, history: model.history)
        case .cpu:
            CPUView(snapshot: model.snapshot, history: model.history)
        case .memory:
            MemoryView(snapshot: model.snapshot, history: model.history)
        case .storage:
            StorageView(volumes: model.snapshot?.storage ?? [])
        case .network:
            NetworkView(interfaces: model.snapshot?.network ?? [], history: model.history)
        case .battery:
            BatteryView(battery: model.snapshot?.battery.value)
        case .hardware:
            HardwareView(snapshot: model.snapshot)
        case .history:
            HistoryView(history: model.history)
        case .settings:
            MonitorSettingsView(model: model)
        }
    }
}

private struct OverviewView: View {
    let snapshot: TelemetrySnapshot?
    let history: [HistoryPoint]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 260), spacing: 16)], spacing: 16) {
                MetricCard(
                    title: "CPU",
                    value: HardwareMonFormat.percent(snapshot?.cpu.value?.totalPercent ?? 0),
                    detail: snapshot?.processor.name ?? "Sampling…",
                    symbol: "cpu",
                    tint: .cyan
                )
                MetricCard(
                    title: "Memory",
                    value: memoryValue,
                    detail: memoryDetail,
                    symbol: "memorychip",
                    tint: .purple
                )
                MetricCard(
                    title: "Thermal",
                    value: snapshot?.thermalState.value?.rawValue.capitalized ?? "Sampling…",
                    detail: "System thermal state",
                    symbol: "thermometer.medium",
                    tint: thermalColor
                )
                MetricCard(
                    title: "Network",
                    value: HardwareMonFormat.rate(downloadRate),
                    detail: "Upload \(HardwareMonFormat.rate(uploadRate))",
                    symbol: "arrow.up.arrow.down",
                    tint: .blue
                )
            }
            .padding()

            if let snapshot {
                DeviceHero(identity: snapshot.device, os: snapshot.operatingSystem, processor: snapshot.processor)
                    .padding([.horizontal, .bottom])
            }
        }
        .navigationTitle("Overview")
    }

    private var downloadRate: Double {
        snapshot?.network.filter { $0.kind != .loopback }.reduce(0) { $0 + $1.downloadBytesPerSecond } ?? 0
    }

    private var uploadRate: Double {
        snapshot?.network.filter { $0.kind != .loopback }.reduce(0) { $0 + $1.uploadBytesPerSecond } ?? 0
    }

    private var memoryValue: String {
        guard let memory = snapshot?.memory.value else { return "Sampling…" }
        return HardwareMonFormat.percent(memory.usedFraction * 100)
    }

    private var memoryDetail: String {
        guard let memory = snapshot?.memory.value else { return "Live memory" }
        return "\(HardwareMonFormat.bytes(memory.usedBytes)) / \(HardwareMonFormat.bytes(memory.totalBytes))"
    }

    private var thermalColor: Color {
        switch snapshot?.thermalState.value {
        case .nominal: .green
        case .fair: .yellow
        case .serious: .orange
        case .critical: .red
        case .unknown, nil: .secondary
        }
    }
}

private struct MetricCard: View {
    let title: LocalizedStringResource
    let value: String
    let detail: String
    let symbol: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(title, systemImage: symbol)
                .font(.headline)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(.largeTitle, design: .rounded, weight: .semibold))
                .monospacedDigit()
                .contentTransition(.numericText())
            Text(detail)
                .font(.callout)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, minHeight: 120, alignment: .leading)
        .padding(18)
        .background(tint.opacity(0.1), in: RoundedRectangle(cornerRadius: 18))
        .overlay {
            RoundedRectangle(cornerRadius: 18)
                .strokeBorder(tint.opacity(0.18))
        }
        .accessibilityElement(children: .combine)
    }
}

private struct DeviceHero: View {
    let identity: DeviceIdentity
    let os: OperatingSystemInfo
    let processor: ProcessorInfo

    var body: some View {
        HStack(spacing: 18) {
            Image(systemName: identity.family == "Mac" ? "laptopcomputer" : "iphone.gen3")
                .font(.system(size: 42))
                .foregroundStyle(.tint)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 5) {
                Text(identity.marketingName)
                    .font(.title2.weight(.semibold))
                Text("\(processor.name) · \(HardwareMonFormat.duration(os.uptime)) uptime")
                    .foregroundStyle(.secondary)
                Text("\(os.name) \(os.version)")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            Spacer()
        }
        .padding(20)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 18))
    }
}

private struct CPUView: View {
    let snapshot: TelemetrySnapshot?
    let history: [HistoryPoint]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                TelemetryChart(
                    title: "CPU Utilisation",
                    history: history,
                    value: { $0.cpuPercent },
                    tint: .cyan,
                    unit: "%"
                )
                if let cpu = snapshot?.cpu.value {
                    DetailsGrid(rows: [
                        DetailRow(label: "User", value: HardwareMonFormat.percent(cpu.userPercent)),
                        DetailRow(label: "System", value: HardwareMonFormat.percent(cpu.systemPercent)),
                        DetailRow(label: "Idle", value: HardwareMonFormat.percent(cpu.idlePercent)),
                        DetailRow(label: "Logical processors", value: String(snapshot?.processor.logicalCoreCount ?? 0)),
                        DetailRow(label: "Active processors", value: String(snapshot?.processor.activeCoreCount ?? 0)),
                        DetailRow(label: "Load average", value: cpu.loadAverages.map { $0.formatted(.number.precision(.fractionLength(2))) }.joined(separator: " · "))
                    ])
                }
            }
            .padding()
        }
        .navigationTitle("CPU")
    }
}

private struct MemoryView: View {
    let snapshot: TelemetrySnapshot?
    let history: [HistoryPoint]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                TelemetryChart(title: "Memory Used", history: history, value: { $0.memoryPercent }, tint: .purple, unit: "%")
                if let memory = snapshot?.memory.value {
                    DetailsGrid(rows: [
                        DetailRow(label: "Installed", value: HardwareMonFormat.bytes(memory.totalBytes)),
                        DetailRow(label: "Used", value: HardwareMonFormat.bytes(memory.usedBytes)),
                        DetailRow(label: "Available", value: HardwareMonFormat.bytes(memory.availableBytes)),
                        DetailRow(label: "Wired", value: HardwareMonFormat.bytes(memory.wiredBytes)),
                        DetailRow(label: "Active", value: HardwareMonFormat.bytes(memory.activeBytes)),
                        DetailRow(label: "Inactive", value: HardwareMonFormat.bytes(memory.inactiveBytes)),
                        DetailRow(label: "Compressed", value: HardwareMonFormat.bytes(memory.compressedBytes))
                    ])
                }
            }
            .padding()
        }
        .navigationTitle("Memory")
    }
}

private struct TelemetryChart: View {
    let title: LocalizedStringResource
    let history: [HistoryPoint]
    let value: (HistoryPoint) -> Double
    let tint: Color
    let unit: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
            Chart(history) { point in
                LineMark(
                    x: .value("Time", point.timestamp),
                    y: .value("Value", value(point))
                )
                .foregroundStyle(tint)
                AreaMark(
                    x: .value("Time", point.timestamp),
                    y: .value("Value", value(point))
                )
                .foregroundStyle(
                    .linearGradient(colors: [tint.opacity(0.28), tint.opacity(0.02)], startPoint: .top, endPoint: .bottom)
                )
            }
            .chartYScale(domain: 0...100)
            .frame(minHeight: 220)
            .accessibilityLabel(title)
            .accessibilityValue(history.last.map { "\(value($0).formatted(.number.precision(.fractionLength(0))))\(unit)" } ?? "No samples")
        }
        .padding(18)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 18))
    }
}

private struct DetailRow: Identifiable {
    let id = UUID()
    let label: LocalizedStringResource
    let value: String
}

private struct DetailsGrid: View {
    let rows: [DetailRow]

    var body: some View {
        Grid(alignment: .leading, horizontalSpacing: 28, verticalSpacing: 12) {
            ForEach(rows) { row in
                GridRow {
                    Text(row.label)
                        .foregroundStyle(.secondary)
                    Text(row.value)
                        .monospacedDigit()
                        .textSelection(.enabled)
                }
            }
        }
        .padding(18)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 18))
    }
}

private struct StorageView: View {
    let volumes: [StorageInfo]

    var body: some View {
        List(volumes) { volume in
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label(volume.name, systemImage: volume.isRemovable == true ? "externaldrive" : "internaldrive")
                    Spacer()
                    Text(HardwareMonFormat.bytes(volume.availableBytes) + " available")
                        .foregroundStyle(.secondary)
                }
                ProgressView(value: Double(volume.usedBytes), total: Double(max(volume.totalBytes, 1)))
                Text("\(HardwareMonFormat.bytes(volume.usedBytes)) used of \(HardwareMonFormat.bytes(volume.totalBytes)) · \(volume.mountPoint)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
            .padding(.vertical, 6)
        }
        .navigationTitle("Storage")
        .overlay {
            if volumes.isEmpty {
                ContentUnavailableView("Storage Unavailable", systemImage: "internaldrive.fill.badge.questionmark")
            }
        }
    }
}

private struct NetworkView: View {
    let interfaces: [NetworkInterfaceInfo]
    let history: [HistoryPoint]

    var body: some View {
        List(interfaces) { interface in
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Label(interface.name, systemImage: interface.isActive ? "network" : "network.slash")
                    Text(interface.kind.rawValue.capitalized)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("↓ \(HardwareMonFormat.rate(interface.downloadBytesPerSecond))  ↑ \(HardwareMonFormat.rate(interface.uploadBytesPerSecond))")
                        .monospacedDigit()
                }
                if !interface.addresses.isEmpty {
                    Text(interface.addresses.joined(separator: " · "))
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
            }
            .padding(.vertical, 5)
        }
        .navigationTitle("Network")
    }
}

private struct BatteryView: View {
    let battery: BatteryInfo?

    var body: some View {
        if let battery {
            List {
                LabeledContent("Charge", value: battery.levelPercent.map(HardwareMonFormat.percent) ?? "Unavailable")
                LabeledContent("Power", value: battery.isPluggedIn == true ? "Power adapter" : "Battery")
                LabeledContent("State", value: battery.isFullyCharged == true ? "Full" : battery.isCharging == true ? "Charging" : "Not charging")
                LabeledContent("Cycle count", value: battery.cycleCount.map(String.init) ?? "Unavailable")
                LabeledContent("Condition", value: battery.condition ?? "Unavailable")
            }
            .navigationTitle("Battery")
        } else {
            ContentUnavailableView("No Battery Detected", systemImage: "battery.0percent")
                .navigationTitle("Battery")
        }
    }
}

private struct HardwareView: View {
    let snapshot: TelemetrySnapshot?

    var body: some View {
        List {
            if let snapshot {
                Section("Device") {
                    LabeledContent("Model", value: snapshot.device.marketingName)
                    LabeledContent("Identifier", value: snapshot.device.machineIdentifier)
                    LabeledContent("Architecture", value: snapshot.device.architecture)
                    LabeledContent("Hostname", value: snapshot.device.hostname ?? "Unavailable")
                }
                Section("Processor") {
                    LabeledContent("Name", value: snapshot.processor.name)
                    LabeledContent("Logical cores", value: String(snapshot.processor.logicalCoreCount))
                    LabeledContent("Active cores", value: String(snapshot.processor.activeCoreCount))
                    LabeledContent("Performance cores", value: snapshot.processor.performanceCoreCount.map(String.init) ?? "Unavailable")
                    LabeledContent("Efficiency cores", value: snapshot.processor.efficiencyCoreCount.map(String.init) ?? "Unavailable")
                }
                Section("GPU") {
                    ForEach(snapshot.gpus) { gpu in
                        LabeledContent(gpu.name, value: gpu.hasUnifiedMemory == true ? "Unified memory" : "Discrete memory")
                    }
                }
                Section("Operating System") {
                    LabeledContent("System", value: "\(snapshot.operatingSystem.name) \(snapshot.operatingSystem.version)")
                    LabeledContent("Kernel", value: snapshot.operatingSystem.kernelVersion)
                    LabeledContent("Uptime", value: HardwareMonFormat.duration(snapshot.operatingSystem.uptime))
                }
            }
        }
        .navigationTitle("Hardware")
        .overlay {
            if snapshot == nil {
                ProgressView("Identifying device…")
            }
        }
    }
}

private struct HistoryView: View {
    let history: [HistoryPoint]

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                TelemetryChart(title: "CPU", history: history, value: { $0.cpuPercent }, tint: .cyan, unit: "%")
                TelemetryChart(title: "Memory", history: history, value: { $0.memoryPercent }, tint: .purple, unit: "%")
            }
            .padding()
        }
        .navigationTitle("History")
    }
}

private struct MonitorSettingsView: View {
    let model: MonitorModel
    @AppStorage("temperatureUnit") private var temperatureUnit = TemperatureUnit.celsius.rawValue
    @AppStorage("dataUnitStandard") private var dataUnitStandard = DataUnitStandard.binary.rawValue

    var body: some View {
        Form {
            Section("Monitoring") {
                Picker("Sample interval", selection: Bindable(model).samplingInterval) {
                    Text("1 second").tag(1.0)
                    Text("2 seconds").tag(2.0)
                    Text("5 seconds").tag(5.0)
                    Text("10 seconds").tag(10.0)
                }
            }
            Section("Units") {
                Picker("Temperature", selection: $temperatureUnit) {
                    Text("Celsius").tag(TemperatureUnit.celsius.rawValue)
                    Text("Fahrenheit").tag(TemperatureUnit.fahrenheit.rawValue)
                }
                Picker("Data", selection: $dataUnitStandard) {
                    Text("Binary (GiB)").tag(DataUnitStandard.binary.rawValue)
                    Text("Decimal (GB)").tag(DataUnitStandard.decimal.rawValue)
                }
            }
            Section("Privacy") {
                LabeledContent("Telemetry upload", value: "Off")
                Text("Local monitoring works without a server. HardwareMon does not upload serial numbers or credentials.")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Settings")
    }
}

#Preview {
    ContentView(model: MonitorModel())
}
