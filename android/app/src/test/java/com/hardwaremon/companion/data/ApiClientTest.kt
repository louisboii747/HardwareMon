package com.hardwaremon.companion.data

import org.junit.Assert.assertEquals
import org.junit.Assert.assertThrows
import org.junit.Test

class ApiClientTest {
    @Test
    fun normalizeBaseUrl_addsTrailingSlash() {
        assertEquals(
            "http://192.168.1.10:8384/",
            ApiClient.normalizeBaseUrl(" http://192.168.1.10:8384 "),
        )
    }

    @Test
    fun normalizeBaseUrl_rejectsMissingScheme() {
        assertThrows(IllegalArgumentException::class.java) {
            ApiClient.normalizeBaseUrl("192.168.1.10:8384")
        }
    }
}
