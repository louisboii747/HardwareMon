import Foundation

nonisolated enum ValueOrigin: String, Codable, Sendable {
    case liveMeasurement
    case staticSpecification
    case calculated
    case unavailable
}

nonisolated struct Metric<Value: Codable & Sendable & Equatable>: Codable, Sendable, Equatable {
    let value: Value?
    let origin: ValueOrigin
    let source: String
    let timestamp: Date
    let unit: String?
    let confidence: Double

    static func live(_ value: Value, source: String, unit: String? = nil, timestamp: Date = .now) -> Self {
        Self(value: value, origin: .liveMeasurement, source: source, timestamp: timestamp, unit: unit, confidence: 1)
    }

    static func calculated(_ value: Value, source: String, unit: String? = nil, timestamp: Date = .now) -> Self {
        Self(value: value, origin: .calculated, source: source, timestamp: timestamp, unit: unit, confidence: 0.95)
    }

    static func unavailable(source: String, timestamp: Date = .now) -> Self {
        Self(value: nil, origin: .unavailable, source: source, timestamp: timestamp, unit: nil, confidence: 1)
    }
}

nonisolated struct DeviceIdentity: Codable, Sendable, Equatable {
    let installationID: UUID
    let machineIdentifier: String
    let marketingName: String
    let family: String
    let architecture: String
    let hostname: String?
}

nonisolated struct OperatingSystemInfo: Codable, Sendable, Equatable {
    let name: String
    let version: String
    let kernelVersion: String
    let uptime: TimeInterval
}

nonisolated struct ProcessorInfo: Codable, Sendable, Equatable {
    let name: String
    let physicalCoreCount: Int
    let logicalCoreCount: Int
    let activeCoreCount: Int
    let performanceCoreCount: Int?
    let efficiencyCoreCount: Int?
    let architecture: String
}

nonisolated struct CPUUsage: Codable, Sendable, Equatable {
    let totalPercent: Double
    let userPercent: Double
    let systemPercent: Double
    let idlePercent: Double
    let perCorePercent: [Double]
    let loadAverages: [Double]
}

nonisolated struct MemoryInfo: Codable, Sendable, Equatable {
    let totalBytes: UInt64
    let usedBytes: UInt64
    let availableBytes: UInt64
    let activeBytes: UInt64
    let inactiveBytes: UInt64
    let wiredBytes: UInt64
    let compressedBytes: UInt64
    let swapTotalBytes: UInt64?
    let swapUsedBytes: UInt64?

    var usedFraction: Double {
        guard totalBytes > 0 else { return 0 }
        return min(max(Double(usedBytes) / Double(totalBytes), 0), 1)
    }
}

nonisolated struct StorageInfo: Codable, Sendable, Equatable, Identifiable {
    var id: String { mountPoint }
    let name: String
    let mountPoint: String
    let fileSystem: String?
    let totalBytes: UInt64
    let availableBytes: UInt64
    let isRemovable: Bool?
    let isInternal: Bool?

    var usedBytes: UInt64 { totalBytes >= availableBytes ? totalBytes - availableBytes : 0 }
}

nonisolated enum NetworkInterfaceKind: String, Codable, Sendable {
    case wifi, ethernet, cellular, thunderbolt, vpn, loopback, other
}

nonisolated struct NetworkInterfaceInfo: Codable, Sendable, Equatable, Identifiable {
    var id: String { name }
    let name: String
    let kind: NetworkInterfaceKind
    let addresses: [String]
    let isActive: Bool
    let receivedBytes: UInt64
    let sentBytes: UInt64
    let downloadBytesPerSecond: Double
    let uploadBytesPerSecond: Double
}

nonisolated struct BatteryInfo: Codable, Sendable, Equatable {
    let levelPercent: Double?
    let isCharging: Bool?
    let isFullyCharged: Bool?
    let isPluggedIn: Bool?
    let cycleCount: Int?
    let condition: String?
    let designCapacityMAh: Int?
    let maximumCapacityMAh: Int?
    let voltageMillivolts: Int?
    let amperageMilliamps: Int?
    let temperatureCelsius: Double?
}

nonisolated enum ThermalState: String, Codable, Sendable {
    case nominal, fair, serious, critical, unknown
}

nonisolated struct SensorReading: Codable, Sendable, Equatable, Identifiable {
    let id: String
    let name: String
    let value: Double
    let unit: String
    let origin: ValueOrigin
    let source: String
    let timestamp: Date
}

nonisolated struct FanInfo: Codable, Sendable, Equatable, Identifiable {
    let id: Int
    let name: String
    let currentRPM: Double
    let minimumRPM: Double?
    let maximumRPM: Double?
}

nonisolated struct GPUInfo: Codable, Sendable, Equatable, Identifiable {
    let id: UInt64
    let name: String
    let isLowPower: Bool
    let isRemovable: Bool
    let hasUnifiedMemory: Bool?
}

nonisolated struct TelemetrySnapshot: Codable, Sendable, Equatable, Identifiable {
    let id: UUID
    let schemaVersion: Int
    let timestamp: Date
    let device: DeviceIdentity
    let operatingSystem: OperatingSystemInfo
    let processor: ProcessorInfo
    let cpu: Metric<CPUUsage>
    let memory: Metric<MemoryInfo>
    let storage: [StorageInfo]
    let network: [NetworkInterfaceInfo]
    let battery: Metric<BatteryInfo>
    let thermalState: Metric<ThermalState>
    let sensors: [SensorReading]
    let fans: [FanInfo]
    let gpus: [GPUInfo]
    let failures: [String]
}

nonisolated struct HistoryPoint: Sendable, Equatable, Identifiable {
    let id: UUID
    let timestamp: Date
    let cpuPercent: Double
    let memoryPercent: Double
    let downloadBytesPerSecond: Double
    let uploadBytesPerSecond: Double
    let temperatureCelsius: Double?
}
