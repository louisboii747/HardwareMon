package com.hardwaremon.android.data

import android.content.Context
import com.hardwaremon.android.data.collectors.BatteryStatsCollector
import com.hardwaremon.android.data.collectors.CpuStatsCollector
import com.hardwaremon.android.data.collectors.DeviceInfoCollector
import com.hardwaremon.android.data.collectors.MemoryStatsCollector
import com.hardwaremon.android.data.collectors.NetworkStatsCollector
import com.hardwaremon.android.data.collectors.StorageStatsCollector
import com.hardwaremon.android.data.collectors.ThermalStatsCollector
import com.hardwaremon.android.model.TelemetrySnapshot
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

class TelemetryRepository(context: Context) {
    private val cpuCollector = CpuStatsCollector()
    private val memoryCollector = MemoryStatsCollector(context)
    private val storageCollector = StorageStatsCollector()
    private val batteryCollector = BatteryStatsCollector(context)
    private val networkCollector = NetworkStatsCollector(context)
    private val thermalCollector = ThermalStatsCollector(context)
    private val deviceInfoCollector = DeviceInfoCollector(context)

    suspend fun collectSnapshot(): TelemetrySnapshot = withContext(Dispatchers.IO) {
        TelemetrySnapshot(
            cpu = cpuCollector.collect(),
            memory = memoryCollector.collect(),
            storage = storageCollector.collect(),
            battery = batteryCollector.collect(),
            network = networkCollector.collect(),
            thermal = thermalCollector.collect(),
            device = deviceInfoCollector.collect(),
        )
    }
}
