import Foundation
import Observation
import OSLog

actor TelemetryEngine {
    private let collector: SystemCollector
    private var samplingTask: Task<Void, Never>?

    init(collector: SystemCollector = SystemCollector()) {
        self.collector = collector
    }

    func snapshots(interval: Duration) -> AsyncStream<TelemetrySnapshot> {
        samplingTask?.cancel()
        return AsyncStream(bufferingPolicy: .bufferingNewest(1)) { continuation in
            samplingTask = Task {
                while !Task.isCancelled {
                    let snapshot = await collector.collect()
                    continuation.yield(snapshot)
                    do {
                        try await Task.sleep(for: interval)
                    } catch {
                        break
                    }
                }
                continuation.finish()
            }
            continuation.onTermination = { [weak self] _ in
                Task { await self?.stop() }
            }
        }
    }

    func stop() {
        samplingTask?.cancel()
        samplingTask = nil
    }
}

@MainActor
@Observable
final class MonitorModel {
    private(set) var snapshot: TelemetrySnapshot?
    private(set) var history: [HistoryPoint] = []
    private(set) var lastError: String?
    var samplingInterval: TimeInterval = 1 {
        didSet {
            guard samplingInterval != oldValue else { return }
            restart()
        }
    }

    private let engine: TelemetryEngine
    private var monitoringTask: Task<Void, Never>?

    init(engine: TelemetryEngine = TelemetryEngine()) {
        self.engine = engine
    }

    func start() {
        guard monitoringTask == nil else { return }
        monitoringTask = Task {
            let duration = Duration.milliseconds(Int64(max(samplingInterval, 1) * 1_000))
            let stream = await engine.snapshots(interval: duration)
            for await snapshot in stream {
                guard !Task.isCancelled else { break }
                self.snapshot = snapshot
                appendHistory(snapshot)
            }
        }
    }

    func stop() {
        monitoringTask?.cancel()
        monitoringTask = nil
        Task { await engine.stop() }
    }

    func restart() {
        stop()
        start()
    }

    func exportReportData() throws -> Data {
        guard let snapshot else {
            throw CocoaError(.fileNoSuchFile)
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(snapshot)
    }

    private func appendHistory(_ snapshot: TelemetrySnapshot) {
        let point = HistoryPoint(
            id: snapshot.id,
            timestamp: snapshot.timestamp,
            cpuPercent: snapshot.cpu.value?.totalPercent ?? 0,
            memoryPercent: (snapshot.memory.value?.usedFraction ?? 0) * 100,
            downloadBytesPerSecond: snapshot.network
                .filter { $0.kind != .loopback }
                .reduce(0) { $0 + $1.downloadBytesPerSecond },
            uploadBytesPerSecond: snapshot.network
                .filter { $0.kind != .loopback }
                .reduce(0) { $0 + $1.uploadBytesPerSecond },
            temperatureCelsius: snapshot.sensors.first(where: { $0.unit == "°C" })?.value
        )
        history.append(point)
        if history.count > 900 {
            history.removeFirst(history.count - 900)
        }
    }
}

enum PreviewTelemetry {
    @MainActor
    static let snapshot = TelemetrySnapshot(
        id: UUID(),
        schemaVersion: 1,
        timestamp: .now,
        device: DeviceIdentity(
            installationID: UUID(),
            machineIdentifier: "Mac15,12",
            marketingName: "MacBook Air",
            family: "Mac",
            architecture: "arm64",
            hostname: "HardwareMon Mac"
        ),
        operatingSystem: OperatingSystemInfo(name: "macOS", version: "27.0", kernelVersion: "Darwin", uptime: 172_800),
        processor: ProcessorInfo(name: "Apple M3", physicalCoreCount: 8, logicalCoreCount: 8, activeCoreCount: 8, performanceCoreCount: 4, efficiencyCoreCount: 4, architecture: "arm64"),
        cpu: .live(CPUUsage(totalPercent: 18, userPercent: 12, systemPercent: 6, idlePercent: 82, perCorePercent: [], loadAverages: [1.1, 1.0, 0.9]), source: "Preview", unit: "%"),
        memory: .live(MemoryInfo(totalBytes: 17_179_869_184, usedBytes: 9_878_425_600, availableBytes: 7_301_443_584, activeBytes: 5_000_000_000, inactiveBytes: 2_000_000_000, wiredBytes: 2_000_000_000, compressedBytes: 878_425_600, swapTotalBytes: 0, swapUsedBytes: 0), source: "Preview", unit: "bytes"),
        storage: [StorageInfo(name: "Macintosh HD", mountPoint: "/", fileSystem: "APFS", totalBytes: 494_384_795_648, availableBytes: 221_000_000_000, isRemovable: false, isInternal: true)],
        network: [NetworkInterfaceInfo(name: "en0", kind: .wifi, addresses: ["192.168.1.x"], isActive: true, receivedBytes: 1_000_000, sentBytes: 500_000, downloadBytesPerSecond: 8_400_000, uploadBytesPerSecond: 1_100_000)],
        battery: .live(BatteryInfo(levelPercent: 82, isCharging: false, isFullyCharged: false, isPluggedIn: false, cycleCount: nil, condition: nil, designCapacityMAh: nil, maximumCapacityMAh: nil, voltageMillivolts: nil, amperageMilliamps: nil, temperatureCelsius: nil), source: "Preview"),
        thermalState: .live(.nominal, source: "Preview"),
        sensors: [],
        fans: [],
        gpus: [GPUInfo(id: 1, name: "Apple M3", isLowPower: false, isRemovable: false, hasUnifiedMemory: true)],
        failures: []
    )
}
