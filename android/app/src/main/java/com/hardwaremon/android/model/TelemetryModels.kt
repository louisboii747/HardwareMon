package com.hardwaremon.android.model

data class CpuStats(
    val usagePercent: Float? = null,
    val coreCount: Int = Runtime.getRuntime().availableProcessors(),
)

data class MemoryStats(
    val usedBytes: Long? = null,
    val freeBytes: Long? = null,
    val totalBytes: Long? = null,
) {
    val usagePercent: Float?
        get() = if (usedBytes != null && totalBytes != null && totalBytes > 0L) {
            usedBytes.toFloat() / totalBytes.toFloat() * 100f
        } else {
            null
        }
}

data class StorageStats(
    val usedBytes: Long? = null,
    val freeBytes: Long? = null,
    val totalBytes: Long? = null,
) {
    val usagePercent: Float?
        get() = if (usedBytes != null && totalBytes != null && totalBytes > 0L) {
            usedBytes.toFloat() / totalBytes.toFloat() * 100f
        } else {
            null
        }
}

data class BatteryStats(
    val percentage: Int? = null,
    val chargingState: String? = null,
    val temperatureCelsius: Float? = null,
    val voltageMillivolts: Int? = null,
    val health: String? = null,
)

data class NetworkStats(
    val connected: Boolean = false,
    val connectionType: String = "Offline",
    val localIpAddress: String? = null,
    val linkSpeedMbps: Int? = null,
)

data class ThermalStats(
    val status: String? = null,
    val statusLevel: Int? = null,
)

data class DeviceInfo(
    val deviceName: String,
    val model: String,
    val manufacturer: String,
    val androidVersion: String,
    val sdkVersion: Int,
    val supportedAbis: List<String>,
    val uptimeMillis: Long,
)

data class TelemetrySnapshot(
    val cpu: CpuStats = CpuStats(),
    val memory: MemoryStats = MemoryStats(),
    val storage: StorageStats = StorageStats(),
    val battery: BatteryStats = BatteryStats(),
    val network: NetworkStats = NetworkStats(),
    val thermal: ThermalStats = ThermalStats(),
    val device: DeviceInfo,
    val capturedAtMillis: Long = System.currentTimeMillis(),
)
