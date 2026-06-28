package com.hardwaremon.android.data.collectors

import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.BatteryManager
import com.hardwaremon.android.model.BatteryStats

class BatteryStatsCollector(private val context: Context) {
    fun collect(): BatteryStats = runCatching {
        val intent = context.registerReceiver(null, IntentFilter(Intent.ACTION_BATTERY_CHANGED))
            ?: return BatteryStats()
        val level = intent.getIntExtra(BatteryManager.EXTRA_LEVEL, -1)
        val scale = intent.getIntExtra(BatteryManager.EXTRA_SCALE, -1)
        val temperature = intent.getIntExtra(BatteryManager.EXTRA_TEMPERATURE, Int.MIN_VALUE)
        val voltage = intent.getIntExtra(BatteryManager.EXTRA_VOLTAGE, -1)

        BatteryStats(
            percentage = if (level >= 0 && scale > 0) level * 100 / scale else null,
            chargingState = chargingState(intent.getIntExtra(BatteryManager.EXTRA_STATUS, -1)),
            temperatureCelsius = temperature.takeIf { it != Int.MIN_VALUE }?.div(10f),
            voltageMillivolts = voltage.takeIf { it > 0 },
            health = batteryHealth(intent.getIntExtra(BatteryManager.EXTRA_HEALTH, -1)),
        )
    }.getOrDefault(BatteryStats())

    private fun chargingState(status: Int): String? = when (status) {
        BatteryManager.BATTERY_STATUS_CHARGING -> "Charging"
        BatteryManager.BATTERY_STATUS_FULL -> "Full"
        BatteryManager.BATTERY_STATUS_DISCHARGING -> "Discharging"
        BatteryManager.BATTERY_STATUS_NOT_CHARGING -> "Not charging"
        else -> null
    }

    private fun batteryHealth(health: Int): String? = when (health) {
        BatteryManager.BATTERY_HEALTH_GOOD -> "Good"
        BatteryManager.BATTERY_HEALTH_OVERHEAT -> "Overheating"
        BatteryManager.BATTERY_HEALTH_DEAD -> "Dead"
        BatteryManager.BATTERY_HEALTH_OVER_VOLTAGE -> "Over voltage"
        BatteryManager.BATTERY_HEALTH_UNSPECIFIED_FAILURE -> "Failure"
        BatteryManager.BATTERY_HEALTH_COLD -> "Cold"
        else -> null
    }
}
