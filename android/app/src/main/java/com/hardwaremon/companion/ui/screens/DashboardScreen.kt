package com.hardwaremon.companion.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.safeDrawingPadding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.FilledTonalButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.hardwaremon.companion.data.models.StatsResponse
import com.hardwaremon.companion.ui.components.AppBackground
import com.hardwaremon.companion.ui.components.MetricCard
import com.hardwaremon.companion.ui.theme.Cyan
import com.hardwaremon.companion.ui.theme.Danger
import com.hardwaremon.companion.ui.theme.ElectricBlue
import com.hardwaremon.companion.ui.theme.Success
import com.hardwaremon.companion.ui.theme.TextSecondary
import com.hardwaremon.companion.ui.theme.Violet
import com.hardwaremon.companion.ui.theme.Warm
import com.hardwaremon.companion.viewmodel.ConnectionStatus
import com.hardwaremon.companion.viewmodel.MainUiState
import java.time.Instant
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.util.Locale
import kotlin.math.roundToInt

@Composable
fun DashboardScreen(
    state: MainUiState,
    onRefresh: () -> Unit,
    onChangeBackend: () -> Unit,
    onDismissError: () -> Unit,
) {
    AppBackground {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .safeDrawingPadding()
                .padding(horizontal = 18.dp),
        ) {
            DashboardHeader(state, onRefresh, onChangeBackend)

            if (state.connectionStatus == ConnectionStatus.DISCONNECTED || state.errorMessage != null) {
                DisconnectedBanner(
                    message = state.errorMessage ?: "The desktop is currently unreachable.",
                    onDismiss = onDismissError,
                )
                Spacer(Modifier.height(12.dp))
            }

            Text("Telemetry", style = MaterialTheme.typography.headlineSmall)
            Text(
                text = state.lastUpdatedEpochMillis.formatLastUpdated(),
                style = MaterialTheme.typography.bodyMedium,
                color = TextSecondary,
            )
            Spacer(Modifier.height(16.dp))

            TelemetryGrid(
                stats = state.stats,
                modifier = Modifier.weight(1f),
            )
        }
    }
}

@Composable
private fun DashboardHeader(
    state: MainUiState,
    onRefresh: () -> Unit,
    onChangeBackend: () -> Unit,
) {
    Column(modifier = Modifier.padding(top = 18.dp, bottom = 22.dp)) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = state.deviceName,
                    style = MaterialTheme.typography.titleLarge,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
                Spacer(Modifier.height(5.dp))
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Box(
                        Modifier
                            .size(8.dp)
                            .background(
                                if (state.connectionStatus == ConnectionStatus.CONNECTED) Success else Danger,
                                CircleShape,
                            ),
                    )
                    Spacer(Modifier.width(8.dp))
                    Text(
                        if (state.connectionStatus == ConnectionStatus.CONNECTED) "Connected" else "Disconnected",
                        style = MaterialTheme.typography.bodyMedium,
                        color = TextSecondary,
                    )
                }
            }
            TextButton(onClick = onChangeBackend) {
                Text("Change")
            }
            FilledTonalButton(
                onClick = onRefresh,
                enabled = !state.isRefreshing,
                colors = ButtonDefaults.filledTonalButtonColors(
                    containerColor = ElectricBlue.copy(alpha = 0.16f),
                    contentColor = ElectricBlue,
                ),
            ) {
                if (state.isRefreshing) {
                    CircularProgressIndicator(
                        modifier = Modifier.size(18.dp),
                        color = ElectricBlue,
                        strokeWidth = 2.dp,
                    )
                } else {
                    Text("↻  Refresh", fontWeight = FontWeight.SemiBold)
                }
            }
        }
    }
}

@Composable
private fun TelemetryGrid(stats: StatsResponse?, modifier: Modifier = Modifier) {
    LazyVerticalGrid(
        columns = GridCells.Adaptive(minSize = 156.dp),
        modifier = modifier.fillMaxWidth(),
        contentPadding = PaddingValues(bottom = 28.dp),
        horizontalArrangement = Arrangement.spacedBy(12.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        item {
            MetricCard(
                label = "CPU",
                value = stats?.cpu.asDisplayNumber(),
                unit = if (stats?.cpu != null) "%" else "",
                accent = ElectricBlue,
                progress = stats?.cpu?.toProgress(),
                supportingText = stats?.cpuName.cleanLabel("Processor usage"),
            )
        }
        item {
            MetricCard(
                label = "Memory",
                value = stats?.ram.asDisplayNumber(),
                unit = if (stats?.ram != null) "%" else "",
                accent = Violet,
                progress = stats?.ram?.toProgress(),
                supportingText = stats?.ramSummary() ?: "System memory usage",
            )
        }
        if (stats?.hasGpu == true && stats.gpuUsage != null) {
            item {
                MetricCard(
                    label = "GPU",
                    value = stats.gpuUsage.asDisplayNumber(),
                    unit = "%",
                    accent = Cyan,
                    progress = stats.gpuUsage.toProgress(),
                    supportingText = stats.gpuName.cleanLabel("Graphics usage"),
                )
            }
        }
        if (stats?.cpuTemperature.isSensorAvailable()) {
            item {
                MetricCard(
                    label = "CPU temp",
                    value = stats?.cpuTemperature.asDisplayNumber(),
                    unit = "°C",
                    accent = Warm,
                    progress = stats?.cpuTemperature?.div(100.0)?.toFloat(),
                    supportingText = "CPU package temperature",
                )
            }
        }
        if (stats?.gpuTemperature.isSensorAvailable()) {
            item {
                MetricCard(
                    label = "GPU temp",
                    value = stats?.gpuTemperature.asDisplayNumber(),
                    unit = "°C",
                    accent = Warm,
                    progress = stats?.gpuTemperature?.div(100.0)?.toFloat(),
                    supportingText = stats?.gpuName.cleanLabel("GPU core temperature"),
                )
            }
        }
    }
}

@Composable
private fun DisconnectedBanner(message: String, onDismiss: () -> Unit) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .background(Danger.copy(alpha = 0.1f), RoundedCornerShape(16.dp))
            .border(1.dp, Danger.copy(alpha = 0.22f), RoundedCornerShape(16.dp))
            .padding(start = 14.dp, top = 12.dp, bottom = 12.dp, end = 6.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(
            text = message,
            modifier = Modifier.weight(1f),
            style = MaterialTheme.typography.bodyMedium,
            color = Danger,
        )
        TextButton(onClick = onDismiss) { Text("Dismiss", color = Danger) }
    }
}

private fun Double?.asDisplayNumber(): String =
    this?.takeIf { it.isFinite() }?.roundToInt()?.toString() ?: "—"

private fun Double.toProgress(): Float = (this / 100.0).toFloat().coerceIn(0f, 1f)

private fun Double?.isSensorAvailable(): Boolean = this != null && isFinite() && this > 0.0

private fun String?.cleanLabel(fallback: String): String =
    this?.trim()?.takeIf {
        it.isNotEmpty() && !it.equals("Unknown GPU", ignoreCase = true)
    } ?: fallback

private fun StatsResponse.ramSummary(): String {
    val used = ramUsed ?: return "System memory usage"
    val total = ramTotal ?: return "${used.cleanDecimal()} GB used"
    return "${used.cleanDecimal()} of ${total.cleanDecimal()} GB"
}

private fun Double.cleanDecimal(): String =
    if (this % 1.0 == 0.0) roundToInt().toString() else String.format(Locale.ROOT, "%.1f", this)

private fun Long?.formatLastUpdated(): String {
    if (this == null) return "Waiting for the first reading"
    val time = Instant.ofEpochMilli(this)
        .atZone(ZoneId.systemDefault())
        .format(DateTimeFormatter.ofPattern("HH:mm:ss"))
    return "Last updated $time"
}
