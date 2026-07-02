package com.hardwaremon.android.model

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class SystemIntelligenceTest {
    @Test
    fun `performance lens reacts more strongly to cpu saturation`() {
        val snapshot = snapshot(cpu = 96f, memory = 42f, storage = 55f, thermal = 0)
        val history = List(5) { snapshot }

        val performance = buildSystemHealthProfile(snapshot, history, MonitoringLens.PERFORMANCE)
        val quiet = buildSystemHealthProfile(snapshot, history, MonitoringLens.QUIET)

        assertTrue(performance.overallScore < quiet.overallScore)
        assertTrue(performance.bottleneck.contains("CPU"))
    }

    @Test
    fun `sparse history is described as calibration`() {
        val snapshot = snapshot(cpu = 18f, memory = 30f, storage = 40f, thermal = null)

        val profile = buildSystemHealthProfile(snapshot, listOf(snapshot), MonitoringLens.BALANCED)

        assertTrue(profile.observation.contains("learning this session"))
        assertEquals(5, profile.signals.size)
    }

    @Test
    fun `session record report remains shareable with unavailable values`() {
        val record = SessionRecord(
            id = "1",
            capturedAtMillis = 1L,
            score = 88,
            stateLabel = "Healthy",
            observation = "Stable",
            bottleneck = "No active bottleneck",
            lens = MonitoringLens.RELIABILITY,
            cpuUsage = null,
            memoryUsage = 44,
            storageUsage = 51,
            batteryPercentage = 80,
        )

        assertTrue(record.report().contains("CPU: Unavailable"))
        assertTrue(record.report().contains("Monitoring lens: Reliability"))
    }

    private fun snapshot(
        cpu: Float,
        memory: Float,
        storage: Float,
        thermal: Int?,
    ): TelemetrySnapshot {
        val total = 1_000L
        fun bytes(percent: Float) = (total * percent / 100f).toLong()
        return TelemetrySnapshot(
            cpu = CpuStats(usagePercent = cpu, coreCount = 8),
            memory = MemoryStats(usedBytes = bytes(memory), freeBytes = total - bytes(memory), totalBytes = total),
            storage = StorageStats(usedBytes = bytes(storage), freeBytes = total - bytes(storage), totalBytes = total),
            battery = BatteryStats(percentage = 75, chargingState = "Discharging", health = "Good"),
            network = NetworkStats(connected = true, connectionType = "Wi-Fi"),
            thermal = ThermalStats(status = thermal?.let { "Level $it" }, statusLevel = thermal),
            device = DeviceInfo(
                deviceName = "Test device",
                model = "Model",
                manufacturer = "HardwareMon",
                androidVersion = "16",
                sdkVersion = 36,
                supportedAbis = listOf("arm64-v8a"),
                uptimeMillis = 1_000L,
            ),
        )
    }
}
