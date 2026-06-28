package com.hardwaremon.android.data.collectors

import com.hardwaremon.android.model.CpuStats
import java.io.RandomAccessFile

class CpuStatsCollector {
    private var previousTimes: CpuTimes? = null

    @Synchronized
    fun collect(): CpuStats {
        val currentTimes = readCpuTimes() ?: return CpuStats()
        val previous = previousTimes
        previousTimes = currentTimes

        if (previous == null) return CpuStats()

        val totalDelta = currentTimes.total - previous.total
        val idleDelta = currentTimes.idle - previous.idle
        val usage = if (totalDelta > 0L) {
            ((totalDelta - idleDelta).toFloat() / totalDelta.toFloat() * 100f)
                .coerceIn(0f, 100f)
        } else {
            null
        }
        return CpuStats(usagePercent = usage)
    }

    private fun readCpuTimes(): CpuTimes? = runCatching {
        val line = RandomAccessFile("/proc/stat", "r").use { it.readLine() }
        parseCpuLine(line)
    }.getOrNull()

    companion object {
        internal fun parseCpuLine(line: String): CpuTimes {
            val values = line.trim().split(Regex("\\s+")).drop(1).map(String::toLong)
            require(values.size >= 4) { "Unexpected /proc/stat CPU row" }
            val idle = values[3] + values.getOrElse(4) { 0L }
            return CpuTimes(total = values.take(8).sum(), idle = idle)
        }
    }
}

internal data class CpuTimes(val total: Long, val idle: Long)
