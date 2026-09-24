import Foundation

enum DataUnitStandard: String, CaseIterable, Codable, Sendable, Identifiable {
    case binary
    case decimal

    var id: Self { self }
}

enum TemperatureUnit: String, CaseIterable, Codable, Sendable, Identifiable {
    case celsius
    case fahrenheit

    var id: Self { self }
}

enum HardwareMonFormat {
    static func bytes(_ value: UInt64, standard: DataUnitStandard = .binary) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB, .useTB]
        formatter.countStyle = standard == .binary ? .binary : .decimal
        formatter.includesUnit = true
        formatter.isAdaptive = true
        return formatter.string(fromByteCount: Int64(clamping: value))
    }

    static func rate(_ bytesPerSecond: Double, standard: DataUnitStandard = .binary) -> String {
        guard bytesPerSecond.isFinite, bytesPerSecond >= 0 else { return "Unavailable" }
        return "\(bytes(UInt64(bytesPerSecond), standard: standard))/s"
    }

    static func percent(_ value: Double) -> String {
        guard value.isFinite else { return "Unavailable" }
        return value.formatted(.number.precision(.fractionLength(0))) + "%"
    }

    static func temperature(_ celsius: Double, unit: TemperatureUnit = .celsius) -> String {
        guard celsius.isFinite, (-50...150).contains(celsius) else { return "Unavailable" }
        let displayed = unit == .celsius ? celsius : celsius * 9 / 5 + 32
        let suffix = unit == .celsius ? "°C" : "°F"
        return displayed.formatted(.number.precision(.fractionLength(1))) + suffix
    }

    static func duration(_ seconds: TimeInterval) -> String {
        Duration.seconds(max(0, seconds)).formatted(.units(allowed: [.days, .hours, .minutes], width: .abbreviated, maximumUnitCount: 2))
    }
}
