package com.hardwaremon.android.data.collectors

import android.app.ActivityManager
import android.content.Context
import com.hardwaremon.android.model.MemoryStats

class MemoryStatsCollector(context: Context) {
    private val activityManager = context.getSystemService(ActivityManager::class.java)

    fun collect(): MemoryStats = runCatching {
        val info = ActivityManager.MemoryInfo()
        activityManager.getMemoryInfo(info)
        MemoryStats(
            usedBytes = (info.totalMem - info.availMem).coerceAtLeast(0L),
            freeBytes = info.availMem,
            totalBytes = info.totalMem,
        )
    }.getOrDefault(MemoryStats())
}
