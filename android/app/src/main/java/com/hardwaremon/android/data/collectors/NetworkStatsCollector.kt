package com.hardwaremon.android.data.collectors

import android.content.Context
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.net.wifi.WifiInfo
import android.net.wifi.WifiManager
import android.os.Build
import com.hardwaremon.android.model.NetworkStats
import java.net.Inet4Address

class NetworkStatsCollector(private val context: Context) {
    private val connectivityManager = context.getSystemService(ConnectivityManager::class.java)

    fun collect(): NetworkStats = runCatching {
        val network = connectivityManager.activeNetwork ?: return NetworkStats()
        val capabilities = connectivityManager.getNetworkCapabilities(network) ?: return NetworkStats()
        val connected = true
        val connectionType = when {
            capabilities.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) -> "Wi-Fi"
            capabilities.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR) -> "Mobile"
            capabilities.hasTransport(NetworkCapabilities.TRANSPORT_ETHERNET) -> "Ethernet"
            capabilities.hasTransport(NetworkCapabilities.TRANSPORT_VPN) -> "VPN"
            else -> "Connected"
        }
        val addresses = connectivityManager.getLinkProperties(network)
            ?.linkAddresses
            .orEmpty()
            .map { it.address }
            .filterNot { it.isLoopbackAddress || it.isLinkLocalAddress }
        val localAddress = (addresses.firstOrNull { it is Inet4Address } ?: addresses.firstOrNull())
            ?.hostAddress
            ?.substringBefore('%')

        NetworkStats(
            connected = connected,
            connectionType = connectionType,
            localIpAddress = localAddress,
            linkSpeedMbps = wifiLinkSpeed(capabilities),
        )
    }.getOrDefault(NetworkStats())

    @Suppress("DEPRECATION")
    private fun wifiLinkSpeed(capabilities: NetworkCapabilities): Int? {
        val wifiInfo = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            capabilities.transportInfo as? WifiInfo
        } else {
            context.applicationContext.getSystemService(WifiManager::class.java)?.connectionInfo
        }
        return wifiInfo?.linkSpeed?.takeIf { it > 0 }
    }
}
