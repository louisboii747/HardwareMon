package com.hardwaremon.android.ui.format

import org.junit.Assert.assertEquals
import org.junit.Test

class TelemetryFormattersTest {
    @Test
    fun `formatBytes uses readable GiB values`() {
        assertEquals("1.5 GB", formatBytes(1_610_612_736L))
        assertEquals("Unavailable", formatBytes(null))
    }

    @Test
    fun `formatPercent clamps and handles missing values`() {
        assertEquals("42", formatPercent(42.4f))
        assertEquals("100", formatPercent(140f))
        assertEquals("—", formatPercent(null))
    }

    @Test
    fun `formatUptime includes useful largest units`() {
        assertEquals("2d 3h 4m", formatUptime(183_840_000L))
        assertEquals("12m", formatUptime(720_000L))
    }
}
