package com.hardwaremon.companion.data

import com.hardwaremon.companion.data.models.DeviceSelf
import com.hardwaremon.companion.data.models.StatsResponse
import retrofit2.http.GET

interface HardwareMonApi {
    @GET("device/self")
    suspend fun getDeviceSelf(): DeviceSelf

    @GET("stats")
    suspend fun getStats(): StatsResponse
}
