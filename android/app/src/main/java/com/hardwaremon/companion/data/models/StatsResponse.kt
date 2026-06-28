package com.hardwaremon.companion.data.models

import com.squareup.moshi.Json
import com.squareup.moshi.JsonClass

/**
 * Shared Windows/Linux GET /stats payload. Every sensor is nullable because
 * hardware and vendor support differs between desktop hosts.
 */
@JsonClass(generateAdapter = false)
data class StatsResponse(
    val cpu: Double? = null,
    @param:Json(name = "cpu_temp") val cpuTemperature: Double? = null,
    @param:Json(name = "cpu_power") val cpuPower: Double? = null,
    @param:Json(name = "cpu_clock") val cpuClock: Double? = null,
    @param:Json(name = "cpu_name") val cpuName: String? = null,
    val ram: Double? = null,
    @param:Json(name = "ram_used") val ramUsed: Double? = null,
    @param:Json(name = "ram_available") val ramAvailable: Double? = null,
    @param:Json(name = "ram_total") val ramTotal: Double? = null,
    @param:Json(name = "gpu_usage") val gpuUsage: Double? = null,
    @param:Json(name = "gpu_temp") val gpuTemperature: Double? = null,
    @param:Json(name = "gpu_power") val gpuPower: Double? = null,
    @param:Json(name = "gpu_vram_used") val gpuVramUsed: Double? = null,
    @param:Json(name = "gpu_name") val gpuName: String? = null,
) {
    val hasGpu: Boolean
        get() = !gpuName.isNullOrPlaceholder() || gpuUsage.isAvailable() || gpuTemperature.isAvailable()

    private fun String?.isNullOrPlaceholder(): Boolean {
        val value = this?.trim().orEmpty()
        return value.isEmpty() || value.equals("Unknown GPU", ignoreCase = true) ||
            value.equals("Unavailable", ignoreCase = true)
    }

    private fun Double?.isAvailable(): Boolean = this != null && this > 0.0
}
