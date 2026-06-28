package com.hardwaremon.android.data.collectors

import android.content.Context
import android.os.Build
import android.os.SystemClock
import android.provider.Settings
import com.hardwaremon.android.model.DeviceInfo

class DeviceInfoCollector(private val context: Context) {
    fun collect(): DeviceInfo {
        val configuredName = runCatching {
            Settings.Global.getString(context.contentResolver, "device_name")
        }.getOrNull()?.trim().orEmpty()

        return DeviceInfo(
            deviceName = configuredName.ifBlank { Build.MODEL.orUnknown() },
            model = Build.MODEL.orUnknown(),
            manufacturer = Build.MANUFACTURER.orUnknown(),
            androidVersion = Build.VERSION.RELEASE.orUnknown(),
            sdkVersion = Build.VERSION.SDK_INT,
            supportedAbis = Build.SUPPORTED_ABIS?.toList().orEmpty(),
            uptimeMillis = SystemClock.elapsedRealtime(),
        )
    }

    private fun String?.orUnknown(): String = this?.trim()?.takeIf(String::isNotEmpty) ?: "Unknown"
}
