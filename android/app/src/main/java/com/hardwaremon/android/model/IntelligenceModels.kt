package com.hardwaremon.android.model

import kotlin.math.max
import kotlin.math.roundToInt

enum class MonitoringLens(val label: String, val description: String) {
    BALANCED("Balanced", "Everyday health across the whole device"),
    PERFORMANCE("Performance", "Compute headroom and sustained load"),
    QUIET("Quiet", "Thermal pressure and low-power behaviour"),
    EFFICIENCY("Efficiency", "Useful work with lower battery demand"),
    RELIABILITY("Reliability", "Memory, storage, and thermal stability"),
}

data class HealthSignal(
    val label: String,
    val score: Int,
    val detail: String,
)

data class SystemHealthProfile(
    val overallScore: Int,
    val stateLabel: String,
    val observation: String,
    val bottleneck: String,
    val signals: List<HealthSignal>,
)

data class WatchSettings(
    val cpuEnabled: Boolean = true,
    val cpuThreshold: Float = 90f,
    val memoryEnabled: Boolean = true,
    val memoryThreshold: Float = 88f,
    val storageEnabled: Boolean = true,
    val storageThreshold: Float = 90f,
    val batteryEnabled: Boolean = true,
    val batteryLowThreshold: Int = 20,
    val thermalEnabled: Boolean = true,
    val thermalLevelThreshold: Int = 3,
)

data class WatchEvent(
    val id: String,
    val capturedAtMillis: Long,
    val title: String,
    val detail: String,
    val severity: String,
)

data class SessionRecord(
    val id: String,
    val capturedAtMillis: Long,
    val score: Int,
    val stateLabel: String,
    val observation: String,
    val bottleneck: String,
    val lens: MonitoringLens,
    val cpuUsage: Int?,
    val memoryUsage: Int?,
    val storageUsage: Int?,
    val batteryPercentage: Int?,
) {
    fun report(): String = buildString {
        appendLine("HardwareMon Android session snapshot")
        appendLine("Captured: $capturedAtMillis")
        appendLine("Monitoring lens: ${lens.label}")
        appendLine("Health: $score/100 · $stateLabel")
        appendLine("Observation: $observation")
        appendLine("Bottleneck: $bottleneck")
        appendLine("CPU: ${cpuUsage?.let { "$it%" } ?: "Unavailable"}")
        appendLine("Memory: ${memoryUsage?.let { "$it%" } ?: "Unavailable"}")
        appendLine("Storage: ${storageUsage?.let { "$it%" } ?: "Unavailable"}")
        appendLine("Battery: ${batteryPercentage?.let { "$it%" } ?: "Unavailable"}")
    }
}

fun buildSystemHealthProfile(
    snapshot: TelemetrySnapshot,
    history: List<TelemetrySnapshot>,
    lens: MonitoringLens,
): SystemHealthProfile {
    val cpu = snapshot.cpu.usagePercent
    val memory = snapshot.memory.usagePercent
    val storage = snapshot.storage.usagePercent
    val battery = snapshot.battery.percentage
    val thermalLevel = snapshot.thermal.statusLevel

    val performanceScore = scoreFromPressure(cpu, warningStart = 62f, multiplier = 1.15f)
    val memoryScore = scoreFromPressure(memory, warningStart = 55f, multiplier = 1.3f)
    val storageScore = scoreFromPressure(storage, warningStart = 72f, multiplier = 1.35f)
    val thermalScore = when (thermalLevel) {
        null -> 88
        0 -> 100
        1 -> 92
        2 -> 72
        3 -> 48
        else -> 24
    }
    val batteryScore = when {
        battery == null -> 88
        snapshot.battery.chargingState?.contains("Charging", ignoreCase = true) == true -> 96
        battery >= 55 -> 94
        battery >= 30 -> 78
        battery >= 15 -> 55
        else -> 28
    }

    val weights = lensWeights(lens)
    val overall = (
        performanceScore * weights[0] +
            memoryScore * weights[1] +
            thermalScore * weights[2] +
            batteryScore * weights[3] +
            storageScore * weights[4]
        ).roundToInt().coerceIn(0, 100)

    val pressures = buildMap {
        cpu?.let { put("CPU", it) }
        memory?.let { put("Memory", it) }
        storage?.let { put("Storage", it) }
        thermalLevel?.let { put("Thermals", (it / 4f * 100f).coerceIn(0f, 100f)) }
    }
    val bottleneckEntry = pressures.maxByOrNull { it.value }
    val bottleneck = if (bottleneckEntry == null || bottleneckEntry.value < 58f) {
        "No active bottleneck"
    } else {
        "${bottleneckEntry.key} is carrying the most pressure"
    }

    val observation = when {
        history.size < 3 -> "HardwareMon is learning this session. Trend confidence improves with each sample."
        thermalLevel != null && thermalLevel >= 3 -> "Android reports meaningful thermal pressure. Reduce sustained load or improve airflow."
        memory != null && memory >= 88f -> "Memory headroom is narrow. Closing an unused heavy app may improve responsiveness."
        storage != null && storage >= 90f -> "Internal storage is nearly full. Free space before updates or large captures."
        battery != null && battery <= 15 && snapshot.battery.chargingState?.contains("Charging", true) != true ->
            "Battery reserve is low and the device is not charging."
        cpu != null && cpu >= 90f -> "CPU load is near saturation. Watch whether the pressure remains sustained."
        isStable(history) -> "Device behaviour is stable across the current on-device session."
        else -> "The device is balancing the current workload without a critical constraint."
    }

    return SystemHealthProfile(
        overallScore = overall,
        stateLabel = when {
            overall >= 90 -> "Exceptional"
            overall >= 78 -> "Healthy"
            overall >= 62 -> "Watch"
            overall >= 42 -> "Stressed"
            else -> "Critical"
        },
        observation = observation,
        bottleneck = bottleneck,
        signals = listOf(
            HealthSignal("Performance", performanceScore, cpu?.let { "${it.roundToInt()}% CPU now" } ?: "Awaiting CPU data"),
            HealthSignal("Memory", memoryScore, memory?.let { "${max(0, 100 - it.roundToInt())}% headroom" } ?: "Awaiting memory data"),
            HealthSignal("Thermals", thermalScore, snapshot.thermal.status ?: "Awaiting thermal status"),
            HealthSignal("Battery", batteryScore, battery?.let { "$it% remaining" } ?: "Battery unavailable"),
            HealthSignal("Storage", storageScore, storage?.let { "${max(0, 100 - it.roundToInt())}% free" } ?: "Storage unavailable"),
        ),
    )
}

private fun scoreFromPressure(value: Float?, warningStart: Float, multiplier: Float): Int {
    if (value == null) return 88
    return (100f - max(0f, value - warningStart) * multiplier).roundToInt().coerceIn(0, 100)
}

private fun lensWeights(lens: MonitoringLens): FloatArray = when (lens) {
    MonitoringLens.BALANCED -> floatArrayOf(.26f, .22f, .22f, .16f, .14f)
    MonitoringLens.PERFORMANCE -> floatArrayOf(.45f, .22f, .14f, .08f, .11f)
    MonitoringLens.QUIET -> floatArrayOf(.12f, .16f, .38f, .25f, .09f)
    MonitoringLens.EFFICIENCY -> floatArrayOf(.15f, .16f, .23f, .36f, .10f)
    MonitoringLens.RELIABILITY -> floatArrayOf(.16f, .27f, .29f, .10f, .18f)
}

private fun isStable(history: List<TelemetrySnapshot>): Boolean {
    val recent = history.takeLast(8)
    if (recent.size < 4) return false
    val cpuValues = recent.mapNotNull { it.cpu.usagePercent }
    val memoryValues = recent.mapNotNull { it.memory.usagePercent }
    val cpuRange = if (cpuValues.isEmpty()) Float.MAX_VALUE else cpuValues.max() - cpuValues.min()
    val memoryRange = if (memoryValues.isEmpty()) Float.MAX_VALUE else memoryValues.max() - memoryValues.min()
    return cpuRange < 12f && memoryRange < 7f
}
