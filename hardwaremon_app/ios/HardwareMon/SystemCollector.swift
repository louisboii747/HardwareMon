import Darwin
import Foundation
import Metal
import OSLog

#if os(iOS)
import UIKit
#elseif os(macOS)
import IOKit.ps
#endif

private let telemetryLogger = Logger(subsystem: "com.hardwaremon.HardwareMon", category: "telemetry")

nonisolated struct CPUTicks: Sendable, Equatable {
    let user: UInt64
    let system: UInt64
    let idle: UInt64
    let nice: UInt64

    var total: UInt64 { user + system + idle + nice }
}

nonisolated enum DeltaCalculator {
    static func cpu(previous: CPUTicks, current: CPUTicks) -> CPUUsage? {
        guard current.total >= previous.total else { return nil }
        let user = current.user - previous.user
        let system = current.system - previous.system
        let idle = current.idle - previous.idle
        let nice = current.nice - previous.nice
        let total = user + system + idle + nice
        guard total > 0 else { return nil }
        let divisor = Double(total)
        let userPercent = Double(user + nice) / divisor * 100
        let systemPercent = Double(system) / divisor * 100
        let idlePercent = Double(idle) / divisor * 100
        return CPUUsage(
            totalPercent: max(0, 100 - idlePercent),
            userPercent: userPercent,
            systemPercent: systemPercent,
            idlePercent: idlePercent,
            perCorePercent: [],
            loadAverages: SystemCollector.loadAverages()
        )
    }

    static func rate(previousBytes: UInt64, currentBytes: UInt64, elapsed: TimeInterval) -> Double {
        guard elapsed > 0, elapsed.isFinite else { return 0 }
        let delta = currentBytes >= previousBytes ? currentBytes - previousBytes : currentBytes
        return Double(delta) / elapsed
    }
}

actor SystemCollector {
    private struct NetworkCounter: Sendable {
        let received: UInt64
        let sent: UInt64
        let timestamp: Date
    }

    private var previousCPUTicks: CPUTicks?
    private var previousNetworkCounters: [String: NetworkCounter] = [:]
    private let installationID: UUID
    #if os(macOS)
    private let smcClient = SMCClient()
    #endif

    init() {
        let key = "HardwareMonInstallationID"
        if let stored = UserDefaults.standard.string(forKey: key), let uuid = UUID(uuidString: stored) {
            installationID = uuid
        } else {
            let uuid = UUID()
            UserDefaults.standard.set(uuid.uuidString, forKey: key)
            installationID = uuid
        }
    }

    func collect() async -> TelemetrySnapshot {
        let timestamp = Date()
        let identity = await collectIdentity()
        let currentTicks = Self.cpuTicks()
        let cpuUsage: CPUUsage
        if let previousCPUTicks, let delta = DeltaCalculator.cpu(previous: previousCPUTicks, current: currentTicks) {
            cpuUsage = delta
        } else {
            cpuUsage = CPUUsage(
                totalPercent: 0,
                userPercent: 0,
                systemPercent: 0,
                idlePercent: 100,
                perCorePercent: [],
                loadAverages: Self.loadAverages()
            )
        }
        previousCPUTicks = currentTicks

        let network = collectNetwork(timestamp: timestamp)
        let memory = Self.memory()
        let storage = Self.storage()
        let battery = Self.battery()
        let thermal = Self.thermalState()
        let processor = await collectProcessor(identity: identity)
        #if os(macOS)
        let smcTelemetry = await smcClient.readTelemetry()
        #else
        let smcTelemetry: (sensors: [SensorReading], fans: [FanInfo]) = ([], [])
        #endif

        return TelemetrySnapshot(
            id: UUID(),
            schemaVersion: 1,
            timestamp: timestamp,
            device: identity,
            operatingSystem: Self.operatingSystem(),
            processor: processor,
            cpu: .live(cpuUsage, source: "Mach host_statistics", unit: "%", timestamp: timestamp),
            memory: .live(memory, source: "Mach host_statistics64", unit: "bytes", timestamp: timestamp),
            storage: storage,
            network: network,
            battery: battery.map { .live($0, source: Self.batterySource, timestamp: timestamp) }
                ?? .unavailable(source: Self.batterySource, timestamp: timestamp),
            thermalState: .live(thermal, source: "ProcessInfo.thermalState", timestamp: timestamp),
            sensors: smcTelemetry.sensors,
            fans: smcTelemetry.fans,
            gpus: Self.gpus(),
            failures: []
        )
    }

    private func collectIdentity() async -> DeviceIdentity {
        let identifier = Self.machineIdentifier()
        let architecture = Self.architecture()
        let specification = await DeviceDatabase.shared.device(identifier: identifier)
            ?? DeviceDatabase.fallback(identifier: identifier, architecture: architecture)
        return DeviceIdentity(
            installationID: installationID,
            machineIdentifier: identifier,
            marketingName: specification.marketingName,
            family: specification.family,
            architecture: architecture,
            hostname: ProcessInfo.processInfo.hostName
        )
    }

    private func collectProcessor(identity: DeviceIdentity) async -> ProcessorInfo {
        let specification = await DeviceDatabase.shared.device(identifier: identity.machineIdentifier)
        return ProcessorInfo(
            name: specification?.soc ?? Self.sysctlString("machdep.cpu.brand_string") ?? "Apple processor",
            physicalCoreCount: ProcessInfo.processInfo.processorCount,
            logicalCoreCount: ProcessInfo.processInfo.processorCount,
            activeCoreCount: ProcessInfo.processInfo.activeProcessorCount,
            performanceCoreCount: specification?.cpu?.performanceCores,
            efficiencyCoreCount: specification?.cpu?.efficiencyCores,
            architecture: identity.architecture
        )
    }

    private func collectNetwork(timestamp: Date) -> [NetworkInterfaceInfo] {
        var addresses: [String: [String]] = [:]
        var active: [String: Bool] = [:]
        var counters: [String: (received: UInt64, sent: UInt64)] = [:]
        var pointer: UnsafeMutablePointer<ifaddrs>?

        guard getifaddrs(&pointer) == 0, let first = pointer else { return [] }
        defer { freeifaddrs(pointer) }

        for item in sequence(first: first, next: { $0.pointee.ifa_next }) {
            let interface = item.pointee
            let name = String(cString: interface.ifa_name)
            active[name] = (interface.ifa_flags & UInt32(IFF_UP)) != 0
            guard let address = interface.ifa_addr else { continue }
            let family = Int32(address.pointee.sa_family)

            if family == AF_INET || family == AF_INET6 {
                var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                let length = socklen_t(address.pointee.sa_len)
                if getnameinfo(address, length, &host, socklen_t(host.count), nil, 0, NI_NUMERICHOST) == 0 {
                    addresses[name, default: []].append(String(cString: host))
                }
            } else if family == AF_LINK, let data = interface.ifa_data {
                let interfaceData = data.assumingMemoryBound(to: if_data.self).pointee
                counters[name] = (UInt64(interfaceData.ifi_ibytes), UInt64(interfaceData.ifi_obytes))
            }
        }

        let interfaces = Set(addresses.keys).union(counters.keys)
        let result = interfaces.sorted().map { name -> NetworkInterfaceInfo in
            let current = counters[name] ?? (0, 0)
            let previous = previousNetworkCounters[name]
            let elapsed = previous.map { timestamp.timeIntervalSince($0.timestamp) } ?? 0
            return NetworkInterfaceInfo(
                name: name,
                kind: Self.networkKind(name),
                addresses: addresses[name] ?? [],
                isActive: active[name] ?? false,
                receivedBytes: current.0,
                sentBytes: current.1,
                downloadBytesPerSecond: previous.map { DeltaCalculator.rate(previousBytes: $0.received, currentBytes: current.0, elapsed: elapsed) } ?? 0,
                uploadBytesPerSecond: previous.map { DeltaCalculator.rate(previousBytes: $0.sent, currentBytes: current.1, elapsed: elapsed) } ?? 0
            )
        }
        previousNetworkCounters = Dictionary(uniqueKeysWithValues: counters.map {
            ($0.key, NetworkCounter(received: $0.value.received, sent: $0.value.sent, timestamp: timestamp))
        })
        return result
    }

    nonisolated static func cpuTicks() -> CPUTicks {
        var statistics = host_cpu_load_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info_data_t>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &statistics) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return CPUTicks(user: 0, system: 0, idle: 0, nice: 0) }
        return CPUTicks(
            user: UInt64(statistics.cpu_ticks.0),
            system: UInt64(statistics.cpu_ticks.1),
            idle: UInt64(statistics.cpu_ticks.2),
            nice: UInt64(statistics.cpu_ticks.3)
        )
    }

    nonisolated static func loadAverages() -> [Double] {
        var values = [Double](repeating: 0, count: 3)
        guard getloadavg(&values, 3) == 3 else { return [] }
        return values
    }

    nonisolated static func memory() -> MemoryInfo {
        let pageSize = UInt64(vm_kernel_page_size)
        var statistics = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &statistics) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        let total = ProcessInfo.processInfo.physicalMemory
        guard result == KERN_SUCCESS else {
            return MemoryInfo(totalBytes: total, usedBytes: 0, availableBytes: total, activeBytes: 0, inactiveBytes: 0, wiredBytes: 0, compressedBytes: 0, swapTotalBytes: nil, swapUsedBytes: nil)
        }
        let active = UInt64(statistics.active_count) * pageSize
        let inactive = UInt64(statistics.inactive_count) * pageSize
        let wired = UInt64(statistics.wire_count) * pageSize
        let compressed = UInt64(statistics.compressor_page_count) * pageSize
        let free = UInt64(statistics.free_count + statistics.speculative_count) * pageSize
        let available = min(total, free + inactive)
        let used = total >= available ? total - available : 0
        return MemoryInfo(
            totalBytes: total,
            usedBytes: used,
            availableBytes: available,
            activeBytes: active,
            inactiveBytes: inactive,
            wiredBytes: wired,
            compressedBytes: compressed,
            swapTotalBytes: nil,
            swapUsedBytes: nil
        )
    }

    nonisolated static func storage() -> [StorageInfo] {
        #if os(macOS)
        let keys: Set<URLResourceKey> = [.volumeNameKey, .volumeTotalCapacityKey, .volumeAvailableCapacityForImportantUsageKey, .volumeIsRemovableKey, .volumeIsInternalKey]
        let urls = FileManager.default.mountedVolumeURLs(includingResourceValuesForKeys: Array(keys), options: [.skipHiddenVolumes]) ?? []
        #else
        let keys: Set<URLResourceKey> = [.volumeNameKey, .volumeTotalCapacityKey, .volumeAvailableCapacityForImportantUsageKey]
        let urls = [URL(fileURLWithPath: NSHomeDirectory())]
        #endif
        return urls.compactMap { url in
            guard let values = try? url.resourceValues(forKeys: keys),
                  let totalValue = values.volumeTotalCapacity else { return nil }
            let total = UInt64(max(totalValue, 0))
            let available = UInt64(max(values.volumeAvailableCapacityForImportantUsage ?? 0, 0))
            return StorageInfo(
                name: values.volumeName ?? url.lastPathComponent,
                mountPoint: url.path,
                fileSystem: nil,
                totalBytes: total,
                availableBytes: min(total, available),
                isRemovable: values.volumeIsRemovable,
                isInternal: values.volumeIsInternal
            )
        }
    }

    nonisolated static var batterySource: String {
        #if os(iOS)
        "UIDevice battery API"
        #elseif os(macOS)
        "IOPowerSources"
        #else
        "Unsupported platform"
        #endif
    }

    nonisolated static func battery() -> BatteryInfo? {
        #if os(iOS)
        UIDevice.current.isBatteryMonitoringEnabled = true
        let level = UIDevice.current.batteryLevel
        guard level >= 0 else { return nil }
        let state = UIDevice.current.batteryState
        return BatteryInfo(
            levelPercent: Double(level) * 100,
            isCharging: state == .charging,
            isFullyCharged: state == .full,
            isPluggedIn: state == .charging || state == .full,
            cycleCount: nil,
            condition: nil,
            designCapacityMAh: nil,
            maximumCapacityMAh: nil,
            voltageMillivolts: nil,
            amperageMilliamps: nil,
            temperatureCelsius: nil
        )
        #elseif os(macOS)
        guard let blob = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let list = IOPSCopyPowerSourcesList(blob)?.takeRetainedValue() as? [CFTypeRef] else { return nil }
        for source in list {
            guard let description = IOPSGetPowerSourceDescription(blob, source)?.takeUnretainedValue() as? [String: Any],
                  description[kIOPSTypeKey] as? String == kIOPSInternalBatteryType else { continue }
            let capacity = description[kIOPSCurrentCapacityKey] as? Int
            let maximum = description[kIOPSMaxCapacityKey] as? Int
            let state = description[kIOPSPowerSourceStateKey] as? String
            return BatteryInfo(
                levelPercent: capacity.map(Double.init),
                isCharging: description[kIOPSIsChargingKey] as? Bool,
                isFullyCharged: capacity != nil && capacity == maximum,
                isPluggedIn: state == kIOPSACPowerValue,
                cycleCount: nil,
                condition: nil,
                designCapacityMAh: nil,
                maximumCapacityMAh: maximum,
                voltageMillivolts: nil,
                amperageMilliamps: nil,
                temperatureCelsius: nil
            )
        }
        return nil
        #else
        return nil
        #endif
    }

    nonisolated static func thermalState() -> ThermalState {
        switch ProcessInfo.processInfo.thermalState {
        case .nominal: .nominal
        case .fair: .fair
        case .serious: .serious
        case .critical: .critical
        @unknown default: .unknown
        }
    }

    nonisolated static func gpus() -> [GPUInfo] {
        #if os(macOS)
        return MTLCopyAllDevices().map {
            GPUInfo(id: $0.registryID, name: $0.name, isLowPower: $0.isLowPower, isRemovable: $0.isRemovable, hasUnifiedMemory: $0.hasUnifiedMemory)
        }
        #else
        guard let device = MTLCreateSystemDefaultDevice() else { return [] }
        return [GPUInfo(id: device.registryID, name: device.name, isLowPower: false, isRemovable: false, hasUnifiedMemory: device.hasUnifiedMemory)]
        #endif
    }

    nonisolated static func operatingSystem() -> OperatingSystemInfo {
        let version = ProcessInfo.processInfo.operatingSystemVersionString
        return OperatingSystemInfo(
            name: {
                #if os(macOS)
                "macOS"
                #elseif os(iOS)
                "iOS"
                #else
                "Apple OS"
                #endif
            }(),
            version: version,
            kernelVersion: sysctlString("kern.version") ?? "Unavailable",
            uptime: ProcessInfo.processInfo.systemUptime
        )
    }

    nonisolated static func machineIdentifier() -> String {
        #if targetEnvironment(simulator)
        if let simulated = ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"] {
            return simulated
        }
        #endif
        return sysctlString("hw.model") ?? unameMachine()
    }

    nonisolated static func architecture() -> String {
        #if arch(arm64)
        "arm64"
        #elseif arch(x86_64)
        "x86_64"
        #else
        "unknown"
        #endif
    }

    nonisolated static func unameMachine() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)
        return withUnsafePointer(to: &systemInfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) { String(cString: $0) }
        }
    }

    nonisolated static func sysctlString(_ name: String) -> String? {
        var size = 0
        guard sysctlbyname(name, nil, &size, nil, 0) == 0, size > 0 else { return nil }
        var value = [CChar](repeating: 0, count: size)
        guard sysctlbyname(name, &value, &size, nil, 0) == 0 else { return nil }
        return String(cString: value)
    }

    nonisolated static func networkKind(_ name: String) -> NetworkInterfaceKind {
        if name == "lo0" { return .loopback }
        if name.hasPrefix("utun") || name.hasPrefix("ppp") || name.hasPrefix("ipsec") { return .vpn }
        if name.hasPrefix("pdp_ip") { return .cellular }
        if name.hasPrefix("en") { return .ethernet }
        if name.hasPrefix("bridge") { return .thunderbolt }
        return .other
    }
}
