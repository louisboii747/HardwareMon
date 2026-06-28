package com.hardwaremon.android.data.collectors

import android.content.Context
import android.os.Build
import android.os.PowerManager
import com.hardwaremon.android.model.ThermalStats

class ThermalStatsCollector(context: Context) {
    private val powerManager = context.getSystemService(PowerManager::class.java)

    fun collect(): ThermalStats {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) return ThermalStats()
        return runCatching {
            val level = powerManager.currentThermalStatus
            ThermalStats(status = thermalStatus(level), statusLevel = level)
        }.getOrDefault(ThermalStats())
    }

    private fun thermalStatus(status: Int): String = when (status) {
        PowerManager.THERMAL_STATUS_NONE -> "Nominal"
        PowerManager.THERMAL_STATUS_LIGHT -> "Light throttling"
        PowerManager.THERMAL_STATUS_MODERATE -> "Moderate throttling"
        PowerManager.THERMAL_STATUS_SEVERE -> "Severe throttling"
        PowerManager.THERMAL_STATUS_CRITICAL -> "Critical"
        PowerManager.THERMAL_STATUS_EMERGENCY -> "Emergency"
        PowerManager.THERMAL_STATUS_SHUTDOWN -> "Shutdown imminent"
        else -> "Unknown"
    }
}
