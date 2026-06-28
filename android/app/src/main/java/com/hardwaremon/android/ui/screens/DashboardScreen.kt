package com.hardwaremon.android.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.safeDrawingPadding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.hardwaremon.android.model.BatteryStats
import com.hardwaremon.android.model.DeviceInfo
import com.hardwaremon.android.model.NetworkStats
import com.hardwaremon.android.model.StorageStats
import com.hardwaremon.android.model.ThermalStats
import com.hardwaremon.android.ui.components.AppBackground
import com.hardwaremon.android.ui.components.DetailRow
import com.hardwaremon.android.ui.components.GlassPanel
import com.hardwaremon.android.ui.components.MetricCard
import com.hardwaremon.android.ui.format.formatBytes
import com.hardwaremon.android.ui.format.formatPercent
import com.hardwaremon.android.ui.format.formatUptime
import com.hardwaremon.android.ui.theme.Cyan
import com.hardwaremon.android.ui.theme.Danger
import com.hardwaremon.android.ui.theme.ElectricBlue
import com.hardwaremon.android.ui.theme.Success
import com.hardwaremon.android.ui.theme.TextMuted
import com.hardwaremon.android.ui.theme.TextSecondary
import com.hardwaremon.android.ui.theme.Violet
import com.hardwaremon.android.ui.theme.Warm
import com.hardwaremon.android.viewmodel.DashboardUiState
import java.time.Instant
import java.time.ZoneId
import java.time.format.DateTimeFormatter

@Composable
fun DashboardScreen(
    state: DashboardUiState,
    onRefresh: () -> Unit,
) {
    AppBackground {
        LazyColumn(
            modifier = Modifier
                .fillMaxSize()
                .safeDrawingPadding(),
            contentPadding = PaddingValues(start = 18.dp, end = 18.dp, top = 14.dp, bottom = 32.dp),
            verticalArrangement = Arrangement.spacedBy(14.dp),
        ) {
            item { DashboardHeader(state, onRefresh) }

            if (state.errorMessage != null) {
                item { ErrorBanner(state.errorMessage) }
            }

            if (state.isLoading && state.snapshot == null) {
                item { LoadingPanel() }
            }

            state.snapshot?.let { snapshot ->
                item { SectionHeader("Performance", "Live system load") }
                item {
                    BoxWithConstraints {
                        val stackCards = maxWidth < 390.dp
                        if (stackCards) {
                            Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                                MetricCard(
                                    label = "CPU",
                                    value = formatPercent(snapshot.cpu.usagePercent),
                                    unit = if (snapshot.cpu.usagePercent != null) "%" else "",
                                    accent = ElectricBlue,
                                    progress = snapshot.cpu.usagePercent?.div(100f),
                                    supportingText = if (snapshot.cpu.usagePercent == null) {
                                        "Unavailable on this Android build"
                                    } else {
                                        "${snapshot.cpu.coreCount} logical processors"
                                    },
                                    modifier = Modifier.fillMaxWidth(),
                                )
                                MemoryCard(
                                    snapshot.memory.usagePercent,
                                    snapshot.memory.usedBytes,
                                    snapshot.memory.freeBytes,
                                    snapshot.memory.totalBytes,
                                    Modifier.fillMaxWidth(),
                                )
                            }
                        } else {
                            Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                                MetricCard(
                                    label = "CPU",
                                    value = formatPercent(snapshot.cpu.usagePercent),
                                    unit = if (snapshot.cpu.usagePercent != null) "%" else "",
                                    accent = ElectricBlue,
                                    progress = snapshot.cpu.usagePercent?.div(100f),
                                    supportingText = if (snapshot.cpu.usagePercent == null) {
                                        "Unavailable on this Android build"
                                    } else {
                                        "${snapshot.cpu.coreCount} logical processors"
                                    },
                                    modifier = Modifier.weight(1f).heightIn(min = 196.dp),
                                )
                                MemoryCard(
                                    snapshot.memory.usagePercent,
                                    snapshot.memory.usedBytes,
                                    snapshot.memory.freeBytes,
                                    snapshot.memory.totalBytes,
                                    Modifier.weight(1f).heightIn(min = 196.dp),
                                )
                            }
                        }
                    }
                }

                item { SectionHeader("Capacity", "Internal memory and storage") }
                item { StoragePanel(snapshot.storage) }

                item { SectionHeader("Power & thermals", "Battery condition and Android thermal pressure") }
                item { BatteryPanel(snapshot.battery) }
                item { ThermalPanel(snapshot.thermal) }

                item { SectionHeader("Connectivity", "Current device network") }
                item { NetworkPanel(snapshot.network) }

                item { SectionHeader("Device", "Hardware and operating system") }
                item { DevicePanel(snapshot.device) }
            }
        }
    }
}

@Composable
private fun DashboardHeader(state: DashboardUiState, onRefresh: () -> Unit) {
    Row(
        modifier = Modifier.fillMaxWidth().padding(bottom = 6.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Box(
            modifier = Modifier
                .size(45.dp)
                .clip(RoundedCornerShape(14.dp))
                .background(Brush.linearGradient(listOf(ElectricBlue, Violet))),
            contentAlignment = Alignment.Center,
        ) {
            Text("HM", color = Color.White, fontWeight = FontWeight.Black, letterSpacing = (-0.5).sp)
        }
        Spacer(Modifier.width(12.dp))
        Column(modifier = Modifier.weight(1f)) {
            Text("HardwareMon", style = MaterialTheme.typography.titleLarge)
            Row(verticalAlignment = Alignment.CenterVertically) {
                Box(Modifier.size(7.dp).background(Success, CircleShape))
                Spacer(Modifier.width(7.dp))
                Text(
                    text = state.snapshot?.capturedAtMillis?.let { "On-device · ${it.asTime()}" }
                        ?: "Starting on-device monitor",
                    style = MaterialTheme.typography.bodyMedium,
                    color = TextSecondary,
                )
            }
        }
        IconButton(
            onClick = onRefresh,
            enabled = !state.isRefreshing,
            modifier = Modifier
                .size(43.dp)
                .clip(CircleShape)
                .background(Color.White.copy(alpha = 0.06f))
                .border(1.dp, Color.White.copy(alpha = 0.07f), CircleShape),
        ) {
            if (state.isRefreshing) {
                CircularProgressIndicator(Modifier.size(19.dp), strokeWidth = 2.dp, color = ElectricBlue)
            } else {
                Text("↻", color = ElectricBlue, fontSize = 25.sp, textAlign = TextAlign.Center)
            }
        }
    }
}

@Composable
private fun SectionHeader(title: String, subtitle: String) {
    Column(modifier = Modifier.padding(top = 10.dp, bottom = 1.dp)) {
        Text(title, style = MaterialTheme.typography.headlineSmall)
        Text(subtitle, style = MaterialTheme.typography.bodyMedium, color = TextSecondary)
    }
}

@Composable
private fun MemoryCard(
    usage: Float?,
    usedBytes: Long?,
    freeBytes: Long?,
    totalBytes: Long?,
    modifier: Modifier = Modifier,
) {
    MetricCard(
        label = "RAM",
        value = formatPercent(usage),
        unit = if (usage != null) "%" else "",
        accent = Violet,
        progress = usage?.div(100f),
        supportingText = if (usedBytes == null) {
            "Unavailable"
        } else {
            "${formatBytes(usedBytes)} used · ${formatBytes(freeBytes)} free\n${formatBytes(totalBytes)} total"
        },
        modifier = modifier,
    )
}

@Composable
private fun StoragePanel(storage: StorageStats) {
    GlassPanel(Modifier.fillMaxWidth()) {
        Column {
            PanelTitle("INTERNAL STORAGE", Cyan)
            Spacer(Modifier.height(14.dp))
            Row(verticalAlignment = Alignment.Bottom) {
                Text(formatPercent(storage.usagePercent), style = MaterialTheme.typography.displaySmall)
                if (storage.usagePercent != null) {
                    Text("% used", modifier = Modifier.padding(start = 5.dp, bottom = 4.dp), color = Cyan)
                }
            }
            Spacer(Modifier.height(14.dp))
            ProgressTrack(storage.usagePercent?.div(100f), Cyan)
            Spacer(Modifier.height(16.dp))
            DetailRow("Used", formatBytes(storage.usedBytes))
            Spacer(Modifier.height(8.dp))
            DetailRow("Free", formatBytes(storage.freeBytes))
            Spacer(Modifier.height(8.dp))
            DetailRow("Total", formatBytes(storage.totalBytes))
        }
    }
}

@Composable
private fun BatteryPanel(battery: BatteryStats) {
    GlassPanel(Modifier.fillMaxWidth()) {
        Column {
            PanelTitle("BATTERY", Warm)
            Spacer(Modifier.height(14.dp))
            Row(verticalAlignment = Alignment.Bottom) {
                Text(battery.percentage?.toString() ?: "—", style = MaterialTheme.typography.displaySmall)
                if (battery.percentage != null) {
                    Text("%", modifier = Modifier.padding(start = 4.dp, bottom = 4.dp), color = Warm)
                }
                Spacer(Modifier.weight(1f))
                StatusPill(battery.chargingState ?: "Unavailable", Warm)
            }
            Spacer(Modifier.height(14.dp))
            ProgressTrack(battery.percentage?.div(100f), Warm)
            Spacer(Modifier.height(16.dp))
            DetailRow("Temperature", battery.temperatureCelsius?.let { "${"%.1f".format(it)} °C" } ?: "Unavailable")
            Spacer(Modifier.height(8.dp))
            DetailRow("Voltage", battery.voltageMillivolts?.let { "${it} mV" } ?: "Unavailable")
            Spacer(Modifier.height(8.dp))
            DetailRow("Health", battery.health ?: "Unavailable")
        }
    }
}

@Composable
private fun ThermalPanel(thermal: ThermalStats) {
    val color = when (thermal.statusLevel) {
        null -> TextMuted
        0, 1 -> Success
        2 -> Warm
        else -> Danger
    }
    GlassPanel(Modifier.fillMaxWidth()) {
        Column {
            PanelTitle("THERMAL STATUS", color)
            Spacer(Modifier.height(14.dp))
            Text(
                thermal.status ?: "Unavailable",
                style = MaterialTheme.typography.titleLarge,
                color = color,
            )
            Spacer(Modifier.height(6.dp))
            Text(
                if (thermal.status == null) {
                    "Android does not expose thermal pressure on this device or OS version."
                } else {
                    "Reported by Android's public thermal API. Component temperatures are restricted."
                },
                style = MaterialTheme.typography.bodyMedium,
                color = TextSecondary,
            )
        }
    }
}

@Composable
private fun NetworkPanel(network: NetworkStats) {
    val accent = if (network.connected) Success else TextMuted
    GlassPanel(Modifier.fillMaxWidth()) {
        Column {
            Row(verticalAlignment = Alignment.CenterVertically) {
                PanelTitle("NETWORK", accent)
                Spacer(Modifier.weight(1f))
                StatusPill(if (network.connected) "Connected" else "Offline", accent)
            }
            Spacer(Modifier.height(16.dp))
            DetailRow("Connection", network.connectionType)
            Spacer(Modifier.height(8.dp))
            DetailRow("Local IP", network.localIpAddress ?: "Unavailable")
            Spacer(Modifier.height(8.dp))
            DetailRow("Wi-Fi link speed", network.linkSpeedMbps?.let { "$it Mbps" } ?: "Unavailable")
        }
    }
}

@Composable
private fun DevicePanel(device: DeviceInfo) {
    GlassPanel(Modifier.fillMaxWidth()) {
        Column {
            PanelTitle("THIS DEVICE", ElectricBlue)
            Spacer(Modifier.height(14.dp))
            Text(
                device.deviceName,
                style = MaterialTheme.typography.titleLarge,
                maxLines = 2,
                overflow = TextOverflow.Ellipsis,
            )
            Text(
                "${device.manufacturer} ${device.model}",
                style = MaterialTheme.typography.bodyMedium,
                color = TextSecondary,
            )
            Spacer(Modifier.height(18.dp))
            DetailRow("Android", "${device.androidVersion} · API ${device.sdkVersion}")
            Spacer(Modifier.height(8.dp))
            DetailRow("Supported ABIs", device.supportedAbis.joinToString().ifBlank { "Unavailable" })
            Spacer(Modifier.height(8.dp))
            DetailRow("Uptime", formatUptime(device.uptimeMillis))
        }
    }
}

@Composable
private fun PanelTitle(text: String, accent: Color) {
    Row(verticalAlignment = Alignment.CenterVertically) {
        Box(Modifier.size(7.dp).background(accent, CircleShape))
        Spacer(Modifier.width(8.dp))
        Text(
            text,
            style = MaterialTheme.typography.labelLarge,
            color = TextSecondary,
            letterSpacing = 1.sp,
        )
    }
}

@Composable
private fun StatusPill(text: String, color: Color) {
    Box(
        Modifier
            .clip(CircleShape)
            .background(color.copy(alpha = 0.13f))
            .padding(horizontal = 10.dp, vertical = 5.dp),
    ) {
        Text(text, color = color, style = MaterialTheme.typography.labelLarge, maxLines = 1)
    }
}

@Composable
private fun ProgressTrack(progress: Float?, accent: Color) {
    Box(
        Modifier
            .fillMaxWidth()
            .height(6.dp)
            .clip(CircleShape)
            .background(Color.White.copy(alpha = 0.07f)),
    ) {
        if (progress != null) {
            Box(
                Modifier
                    .fillMaxWidth(progress.coerceIn(0f, 1f))
                    .height(6.dp)
                    .background(Brush.horizontalGradient(listOf(accent.copy(alpha = 0.55f), accent))),
            )
        }
    }
}

@Composable
private fun ErrorBanner(message: String) {
    Text(
        text = message,
        modifier = Modifier
            .fillMaxWidth()
            .background(Danger.copy(alpha = 0.1f), RoundedCornerShape(16.dp))
            .border(1.dp, Danger.copy(alpha = 0.22f), RoundedCornerShape(16.dp))
            .padding(14.dp),
        style = MaterialTheme.typography.bodyMedium,
        color = Danger,
    )
}

@Composable
private fun LoadingPanel() {
    GlassPanel(Modifier.fillMaxWidth().height(180.dp)) {
        Column(
            modifier = Modifier.fillMaxSize(),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.Center,
        ) {
            CircularProgressIndicator(color = ElectricBlue, strokeWidth = 2.dp)
            Spacer(Modifier.height(14.dp))
            Text("Reading this device…", color = TextSecondary)
        }
    }
}

private fun Long.asTime(): String = Instant.ofEpochMilli(this)
    .atZone(ZoneId.systemDefault())
    .format(DateTimeFormatter.ofPattern("HH:mm:ss"))
