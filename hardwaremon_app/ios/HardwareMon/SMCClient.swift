#if os(macOS)
import Foundation
import IOKit
import OSLog

private let smcLogger = Logger(subsystem: "com.hardwaremon.HardwareMon", category: "smc")

nonisolated struct SMCKey: Hashable, Sendable {
    let rawValue: UInt32

    init?(_ string: String) {
        guard string.utf8.count == 4 else { return nil }
        rawValue = string.utf8.reduce(0) { ($0 << 8) | UInt32($1) }
    }

    var stringValue: String {
        String(bytes: [
            UInt8((rawValue >> 24) & 0xff),
            UInt8((rawValue >> 16) & 0xff),
            UInt8((rawValue >> 8) & 0xff),
            UInt8(rawValue & 0xff)
        ], encoding: .ascii) ?? "????"
    }
}

nonisolated struct SMCValue: Sendable {
    let key: SMCKey
    let dataType: String
    let bytes: [UInt8]

    var numericValue: Double? {
        switch dataType {
        case "sp78":
            guard bytes.count >= 2 else { return nil }
            let raw = Int16(bitPattern: UInt16(bytes[0]) << 8 | UInt16(bytes[1]))
            return Double(raw) / 256
        case "fpe2":
            guard bytes.count >= 2 else { return nil }
            return Double(UInt16(bytes[0]) << 8 | UInt16(bytes[1])) / 4
        case "flt ":
            guard bytes.count >= 4 else { return nil }
            let bits = UInt32(bytes[0]) << 24 | UInt32(bytes[1]) << 16 | UInt32(bytes[2]) << 8 | UInt32(bytes[3])
            return Double(Float(bitPattern: bits))
        case "ui8 ":
            return bytes.first.map(Double.init)
        case "ui16":
            guard bytes.count >= 2 else { return nil }
            return Double(UInt16(bytes[0]) << 8 | UInt16(bytes[1]))
        default:
            return nil
        }
    }
}

private struct SMCVersion {
    var major: UInt8 = 0
    var minor: UInt8 = 0
    var build: UInt8 = 0
    var reserved: UInt8 = 0
    var release: UInt16 = 0
}

private struct SMCPowerLimitData {
    var version: UInt16 = 0
    var length: UInt16 = 0
    var cpuPLimit: UInt32 = 0
    var gpuPLimit: UInt32 = 0
    var memPLimit: UInt32 = 0
}

private struct SMCKeyInfoData {
    var dataSize: UInt32 = 0
    var dataType: UInt32 = 0
    var dataAttributes: UInt8 = 0
}

private struct SMCKeyData {
    var key: UInt32 = 0
    var vers = SMCVersion()
    var pLimitData = SMCPowerLimitData()
    var keyInfo = SMCKeyInfoData()
    var result: UInt8 = 0
    var status: UInt8 = 0
    var data8: UInt8 = 0
    var data32: UInt32 = 0
    var bytes: (
        UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
        UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
        UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
        UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8
    ) = (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
}

actor SMCClient {
    private var connection: io_connect_t = 0

    init() {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSMC"))
        guard service != IO_OBJECT_NULL else {
            smcLogger.info("AppleSMC service is unavailable on this Mac")
            return
        }
        defer { IOObjectRelease(service) }
        let result = IOServiceOpen(service, mach_task_self_, 0, &connection)
        if result != KERN_SUCCESS {
            connection = 0
            smcLogger.info("AppleSMC could not be opened: \(result)")
        }
    }

    deinit {
        if connection != 0 {
            IOServiceClose(connection)
        }
    }

    func read(_ key: SMCKey) -> SMCValue? {
        guard connection != 0 else { return nil }
        var input = SMCKeyData()
        var output = SMCKeyData()
        input.key = key.rawValue
        input.data8 = 9

        guard call(input: &input, output: &output) == KERN_SUCCESS else { return nil }
        let size = Int(output.keyInfo.dataSize)
        guard (1...32).contains(size) else { return nil }

        input.keyInfo.dataSize = output.keyInfo.dataSize
        input.data8 = 5
        guard call(input: &input, output: &output) == KERN_SUCCESS else { return nil }

        let dataType = fourCharacterString(output.keyInfo.dataType)
        let bytes = withUnsafeBytes(of: output.bytes) { Array($0.prefix(size)) }
        return SMCValue(key: key, dataType: dataType, bytes: bytes)
    }

    func readTelemetry() -> (sensors: [SensorReading], fans: [FanInfo]) {
        let now = Date()
        let temperatureKeys: [(String, String)] = [
            ("TC0P", "CPU Proximity"),
            ("TC0D", "CPU Die"),
            ("TCXC", "CPU"),
            ("TG0P", "GPU Proximity"),
            ("TG0D", "GPU Die"),
            ("TB0T", "Battery"),
            ("TN0D", "NAND"),
            ("Tm0P", "Memory"),
            ("TA0P", "Ambient")
        ]
        let sensors = temperatureKeys.compactMap { keyName, displayName -> SensorReading? in
            guard let key = SMCKey(keyName),
                  let value = read(key)?.numericValue,
                  (-20...130).contains(value) else { return nil }
            return SensorReading(
                id: keyName,
                name: displayName,
                value: value,
                unit: "°C",
                origin: .liveMeasurement,
                source: "AppleSMC \(keyName)",
                timestamp: now
            )
        }

        let fanCount: Int
        if let key = SMCKey("FNum"), let count = read(key)?.numericValue {
            fanCount = min(max(Int(count), 0), 8)
        } else {
            fanCount = 0
        }
        let fans = (0..<fanCount).compactMap { index -> FanInfo? in
            guard let actualKey = SMCKey("F\(index)Ac"),
                  let actual = read(actualKey)?.numericValue,
                  actual >= 0, actual < 20_000 else { return nil }
            let minimum = SMCKey("F\(index)Mn").flatMap { read($0)?.numericValue }
            let maximum = SMCKey("F\(index)Mx").flatMap { read($0)?.numericValue }
            return FanInfo(id: index, name: "Fan \(index + 1)", currentRPM: actual, minimumRPM: minimum, maximumRPM: maximum)
        }
        return (sensors, fans)
    }

    private func call(input: inout SMCKeyData, output: inout SMCKeyData) -> kern_return_t {
        var outputSize = MemoryLayout<SMCKeyData>.stride
        return withUnsafePointer(to: &input) { inputPointer in
            withUnsafeMutablePointer(to: &output) { outputPointer in
                IOConnectCallStructMethod(
                    connection,
                    2,
                    inputPointer,
                    MemoryLayout<SMCKeyData>.stride,
                    outputPointer,
                    &outputSize
                )
            }
        }
    }

    private func fourCharacterString(_ value: UInt32) -> String {
        String(bytes: [
            UInt8((value >> 24) & 0xff),
            UInt8((value >> 16) & 0xff),
            UInt8((value >> 8) & 0xff),
            UInt8(value & 0xff)
        ], encoding: .ascii) ?? ""
    }
}
#endif
