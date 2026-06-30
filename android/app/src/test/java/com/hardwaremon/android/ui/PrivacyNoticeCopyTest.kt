package com.hardwaremon.android.ui

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class PrivacyNoticeCopyTest {
    @Test
    fun summaryClearlyStatesLocalProcessingAndNoUploads() {
        val summary = PrivacyNoticeCopy.summary.lowercase()

        assertTrue(summary.contains("stay on this device"))
        assertTrue(summary.contains("does not currently upload"))
        assertTrue(summary.contains("benchmark results"))
        assertFalse(summary.contains("always uploads"))
    }
}
