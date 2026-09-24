import Foundation

nonisolated struct AppleDeviceSpecification: Codable, Sendable, Equatable, Identifiable {
    struct CPU: Codable, Sendable, Equatable {
        let cores: Int
        let performanceCores: Int?
        let efficiencyCores: Int?
    }

    struct GPU: Codable, Sendable, Equatable {
        let cores: Int?
    }

    struct Display: Codable, Sendable, Equatable {
        let diagonalInches: Double?
        let nativeWidth: Int?
        let nativeHeight: Int?
        let maximumRefreshRate: Int?
    }

    var id: String { identifier }
    let identifier: String
    let marketingName: String
    let family: String
    let soc: String?
    let architecture: String
    let cpu: CPU?
    let gpu: GPU?
    let memoryBytes: UInt64?
    let display: Display?
    let neuralEngineCores: Int?
}

nonisolated struct AppleDeviceDatabasePayload: Codable, Sendable {
    let schemaVersion: Int
    let devices: [AppleDeviceSpecification]
}

actor DeviceDatabase {
    static let shared = DeviceDatabase()

    private var cache: [String: AppleDeviceSpecification]?
    private(set) var schemaVersion = 0

    func device(identifier: String) async -> AppleDeviceSpecification? {
        if cache == nil {
            load()
        }
        return cache?[identifier]
    }

    func allDevices() async -> [AppleDeviceSpecification] {
        if cache == nil {
            load()
        }
        return Array(cache?.values ?? [:].values)
    }

    private func load() {
        guard let url = Bundle.main.url(forResource: "apple-devices", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let payload = try? JSONDecoder().decode(AppleDeviceDatabasePayload.self, from: data) else {
            cache = [:]
            return
        }
        schemaVersion = payload.schemaVersion
        cache = Dictionary(payload.devices.map { ($0.identifier, $0) }, uniquingKeysWith: { first, _ in first })
    }

    static func fallback(identifier: String, architecture: String) -> AppleDeviceSpecification {
        AppleDeviceSpecification(
            identifier: identifier,
            marketingName: "Unknown Apple device",
            family: identifier.hasPrefix("iPad") ? "iPad" : identifier.hasPrefix("iPhone") ? "iPhone" : "Mac",
            soc: nil,
            architecture: architecture,
            cpu: nil,
            gpu: nil,
            memoryBytes: nil,
            display: nil,
            neuralEngineCores: nil
        )
    }
}
