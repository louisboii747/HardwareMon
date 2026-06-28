package com.hardwaremon.android.data.collectors

import android.os.Environment
import android.os.StatFs
import com.hardwaremon.android.model.StorageStats

class StorageStatsCollector {
    fun collect(): StorageStats = runCatching {
        val stats = StatFs(Environment.getDataDirectory().absolutePath)
        val total = stats.totalBytes
        val free = stats.availableBytes
        StorageStats(
            usedBytes = (total - free).coerceAtLeast(0L),
            freeBytes = free,
            totalBytes = total,
        )
    }.getOrDefault(StorageStats())
}
