package com.hardwaremon.companion.data

import com.hardwaremon.companion.data.models.DeviceSelf
import com.hardwaremon.companion.data.models.StatsResponse

class TelemetryRepository {
    private var activeApi: HardwareMonApi? = null
    private var activeBaseUrl: String? = null

    data class ConnectionResult(
        val device: DeviceSelf,
        val stats: StatsResponse,
    )

    suspend fun connect(baseUrl: String): ConnectionResult {
        val api = ApiClient.create(baseUrl)
        val device = api.getDeviceSelf()
        val stats = api.getStats()
        activeApi = api
        activeBaseUrl = ApiClient.normalizeBaseUrl(baseUrl)
        return ConnectionResult(device, stats)
    }

    suspend fun refresh(baseUrl: String): StatsResponse {
        val normalizedUrl = ApiClient.normalizeBaseUrl(baseUrl)
        val api = activeApi?.takeIf { activeBaseUrl == normalizedUrl }
            ?: ApiClient.create(normalizedUrl).also {
                activeApi = it
                activeBaseUrl = normalizedUrl
            }
        return api.getStats()
    }
}
