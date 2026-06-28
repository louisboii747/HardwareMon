package com.hardwaremon.android.data.collectors

import org.junit.Assert.assertEquals
import org.junit.Test

class CpuStatsCollectorTest {
    @Test
    fun `parseCpuLine separates idle and total time`() {
        val times = CpuStatsCollector.parseCpuLine("cpu  100 20 30 400 50 6 7 8 9 10")

        assertEquals(621L, times.total)
        assertEquals(450L, times.idle)
    }
}
