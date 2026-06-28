package com.hardwaremon.companion.data.models

import com.squareup.moshi.Json
import com.squareup.moshi.JsonClass

/**
 * Flexible identity response for GET /device/self.
 *
 * The preferred backend shape is { "name": "Gaming PC" }. Aliases are kept
 * nullable so older or platform-specific backends can return hostname or
 * device_name without breaking the app.
 */
@JsonClass(generateAdapter = false)
data class DeviceSelf(
    val name: String? = null,
    @param:Json(name = "device_name") val deviceName: String? = null,
    val hostname: String? = null,
    val platform: String? = null,
    val os: String? = null,
    val version: String? = null,
) {
    val displayName: String
        get() = sequenceOf(name, deviceName, hostname)
            .mapNotNull { it?.trim()?.takeIf(String::isNotEmpty) }
            .firstOrNull()
            ?: "HardwareMon Desktop"
}
