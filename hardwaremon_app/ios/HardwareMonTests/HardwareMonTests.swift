import Foundation
import Testing
@testable import HardwareMon

struct FormattingTests {
    @Test
    func bytesUseHumanReadableBinaryUnits() {
        let formatted = HardwareMonFormat.bytes(1_073_741_824)
        #expect(formatted.contains("GB"))
    }

    @Test
    func rejectsInvalidTemperatures() {
        #expect(HardwareMonFormat.temperature(-128) == "Unavailable")
        #expect(HardwareMonFormat.temperature(712) == "Unavailable")
        #expect(HardwareMonFormat.temperature(25, unit: .fahrenheit).contains("77"))
    }
}

struct DeltaCalculatorTests {
    @Test
    func cpuUsesCounterDeltasRatherThanCumulativeTicks() throws {
        let previous = CPUTicks(user: 100, system: 100, idle: 800, nice: 0)
        let current = CPUTicks(user: 120, system: 110, idle: 870, nice: 0)
        let usage = try #require(DeltaCalculator.cpu(previous: previous, current: current))
        #expect(abs(usage.totalPercent - 30) < 0.001)
        #expect(abs(usage.userPercent - 20) < 0.001)
        #expect(abs(usage.systemPercent - 10) < 0.001)
        #expect(abs(usage.idlePercent - 70) < 0.001)
    }

    @Test
    func networkRateHandlesResetWithoutUnderflow() {
        #expect(DeltaCalculator.rate(previousBytes: 1_000, currentBytes: 500, elapsed: 1) == 500)
        #expect(DeltaCalculator.rate(previousBytes: 1_000, currentBytes: 2_000, elapsed: 2) == 500)
    }
}

struct MemoryCalculationTests {
    @Test
    func usedFractionIsBounded() {
        let memory = MemoryInfo(
            totalBytes: 100,
            usedBytes: 70,
            availableBytes: 30,
            activeBytes: 50,
            inactiveBytes: 20,
            wiredBytes: 10,
            compressedBytes: 5,
            swapTotalBytes: nil,
            swapUsedBytes: nil
        )
        #expect(memory.usedFraction == 0.7)
    }
}

struct DeviceDatabaseTests {
    @Test
    func unknownIdentifierFallsBackSafely() {
        let unknown = DeviceDatabase.fallback(identifier: "iPhone99,9", architecture: "arm64")
        #expect(unknown.identifier == "iPhone99,9")
        #expect(unknown.marketingName == "Unknown Apple device")
        #expect(unknown.family == "iPhone")
    }

    @Test
    func bundledDatabaseHasUniqueSaneEntries() async {
        let devices = await DeviceDatabase.shared.allDevices()
        #expect(!devices.isEmpty)
        #expect(Set(devices.map(\.identifier)).count == devices.count)
        #expect(devices.allSatisfy { ($0.memoryBytes ?? 0) < 1_099_511_627_776 })
        #expect(devices.allSatisfy { ($0.cpu?.cores ?? 1) > 0 && ($0.cpu?.cores ?? 1) < 64 })
    }
}

struct TelemetryCodingTests {
    @Test
    @MainActor
    func snapshotRoundTripsThroughVersionedJSON() throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(PreviewTelemetry.snapshot)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(TelemetrySnapshot.self, from: data)

        #expect(decoded.schemaVersion == 1)
        #expect(decoded.device.machineIdentifier == "Mac15,12")
        #expect(decoded.cpu.value?.totalPercent == 18)
    }
}
