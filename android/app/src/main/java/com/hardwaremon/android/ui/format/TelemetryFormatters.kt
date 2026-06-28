package com.hardwaremon.android.ui.format

import java.util.Locale
import java.util.concurrent.TimeUnit
import kotlin.math.roundToInt

fun formatBytes(bytes: Long?): String {
    if (bytes == null || bytes < 0L) return "Unavailable"
    val gibibytes = bytes.toDouble() / (1024.0 * 1024.0 * 1024.0)
    return if (gibibytes >= 10.0) {
        "${gibibytes.roundToInt()} GB"
    } else {
        String.format(Locale.ROOT, "%.1f GB", gibibytes)
    }
}

fun formatPercent(percent: Float?): String =
    percent?.takeIf(Float::isFinite)?.roundToInt()?.coerceIn(0, 100)?.toString() ?: "—"

fun formatUptime(millis: Long): String {
    val days = TimeUnit.MILLISECONDS.toDays(millis)
    val hours = TimeUnit.MILLISECONDS.toHours(millis) % 24
    val minutes = TimeUnit.MILLISECONDS.toMinutes(millis) % 60
    return when {
        days > 0 -> "${days}d ${hours}h ${minutes}m"
        hours > 0 -> "${hours}h ${minutes}m"
        else -> "${minutes}m"
    }
}
