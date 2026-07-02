package com.hardwaremon.android.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
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
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Slider
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.hardwaremon.android.model.WatchEvent
import com.hardwaremon.android.model.WatchSettings
import com.hardwaremon.android.ui.components.AppBackground
import com.hardwaremon.android.ui.components.GlassPanel
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
import kotlin.math.roundToInt

@Composable
fun WatchCenterScreen(
    state: DashboardUiState,
    onSettingsChange: (WatchSettings) -> Unit,
    onClearEvents: () -> Unit,
) {
    val settings = state.watchSettings
    AppBackground {
        LazyColumn(
            modifier = Modifier.fillMaxSize().safeDrawingPadding(),
            contentPadding = PaddingValues(start = 18.dp, end = 18.dp, top = 14.dp, bottom = 118.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            item {
                ExperienceHeader(
                    eyebrow = "LOCAL WATCH ENGINE",
                    title = "Watch centre",
                    detail = "Thresholds are evaluated on-device while HardwareMon is monitoring.",
                )
            }
            item { WatchSummary(state) }
            item {
                WatchRuleCard(
                    title = "CPU pressure",
                    detail = "Create an event when CPU load crosses this level.",
                    enabled = settings.cpuEnabled,
                    threshold = settings.cpuThreshold,
                    range = 50f..100f,
                    unit = "%",
                    color = ElectricBlue,
                    onEnabled = { onSettingsChange(settings.copy(cpuEnabled = it)) },
                    onThreshold = { onSettingsChange(settings.copy(cpuThreshold = it)) },
                )
            }
            item {
                WatchRuleCard(
                    title = "Memory pressure",
                    detail = "Catch shrinking memory headroom before the device feels constrained.",
                    enabled = settings.memoryEnabled,
                    threshold = settings.memoryThreshold,
                    range = 50f..100f,
                    unit = "%",
                    color = Violet,
                    onEnabled = { onSettingsChange(settings.copy(memoryEnabled = it)) },
                    onThreshold = { onSettingsChange(settings.copy(memoryThreshold = it)) },
                )
            }
            item {
                WatchRuleCard(
                    title = "Storage capacity",
                    detail = "Warn when internal storage approaches its capacity limit.",
                    enabled = settings.storageEnabled,
                    threshold = settings.storageThreshold,
                    range = 60f..98f,
                    unit = "% used",
                    color = Warm,
                    onEnabled = { onSettingsChange(settings.copy(storageEnabled = it)) },
                    onThreshold = { onSettingsChange(settings.copy(storageThreshold = it)) },
                )
            }
            item {
                WatchRuleCard(
                    title = "Battery reserve",
                    detail = "Create an event below this percentage when the device is not charging.",
                    enabled = settings.batteryEnabled,
                    threshold = settings.batteryLowThreshold.toFloat(),
                    range = 5f..40f,
                    unit = "% remaining",
                    color = Success,
                    onEnabled = { onSettingsChange(settings.copy(batteryEnabled = it)) },
                    onThreshold = { onSettingsChange(settings.copy(batteryLowThreshold = it.roundToInt())) },
                )
            }
            item {
                ThermalWatchRule(
                    settings = settings,
                    onSettingsChange = onSettingsChange,
                )
            }
            item {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    SectionTitle(
                        title = "Recent watch events",
                        detail = "A new event appears only when a metric enters the watched zone.",
                    )
                    Spacer(Modifier.weight(1f))
                    if (state.watchEvents.isNotEmpty()) {
                        Text(
                            "Clear",
                            modifier = Modifier
                                .clickable(onClick = onClearEvents)
                                .padding(horizontal = 10.dp, vertical = 7.dp),
                            color = ElectricBlue,
                            fontWeight = FontWeight.Bold,
                        )
                    }
                }
            }
            if (state.watchEvents.isEmpty()) {
                item { WatchEventsEmpty() }
            } else {
                items(state.watchEvents.size, key = { state.watchEvents[it].id }) { index ->
                    WatchEventCard(state.watchEvents[index])
                }
            }
        }
    }
}

@Composable
private fun WatchSummary(state: DashboardUiState) {
    val enabledCount = listOf(
        state.watchSettings.cpuEnabled,
        state.watchSettings.memoryEnabled,
        state.watchSettings.storageEnabled,
        state.watchSettings.batteryEnabled,
        state.watchSettings.thermalEnabled,
    ).count { it }
    GlassPanel(Modifier.fillMaxWidth()) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Box(
                modifier = Modifier.size(54.dp).background(ElectricBlue.copy(alpha = .12f), CircleShape),
                contentAlignment = Alignment.Center,
            ) {
                Text(enabledCount.toString(), color = ElectricBlue, fontWeight = FontWeight.Black, fontSize = 20.sp)
            }
            Spacer(Modifier.size(13.dp))
            Column(Modifier.weight(1f)) {
                Text("$enabledCount active watches", fontWeight = FontWeight.Bold)
                Text(
                    if (state.isPaused) "Monitoring is paused; watch evaluation is frozen."
                    else "Watching the current on-device telemetry stream.",
                    color = if (state.isPaused) Warm else TextSecondary,
                    style = MaterialTheme.typography.bodySmall,
                )
            }
            Text("${state.watchEvents.size}", color = TextMuted, fontWeight = FontWeight.Bold)
            Spacer(Modifier.size(5.dp))
            Text("events", color = TextMuted, style = MaterialTheme.typography.bodySmall)
        }
    }
}

@Composable
private fun WatchRuleCard(
    title: String,
    detail: String,
    enabled: Boolean,
    threshold: Float,
    range: ClosedFloatingPointRange<Float>,
    unit: String,
    color: Color,
    onEnabled: (Boolean) -> Unit,
    onThreshold: (Float) -> Unit,
) {
    GlassPanel(Modifier.fillMaxWidth()) {
        Column {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Box(Modifier.size(8.dp).background(if (enabled) color else TextMuted, CircleShape))
                Spacer(Modifier.size(9.dp))
                Column(Modifier.weight(1f)) {
                    Text(title, fontWeight = FontWeight.Bold)
                    Text(detail, color = TextMuted, style = MaterialTheme.typography.bodySmall)
                }
                Switch(checked = enabled, onCheckedChange = onEnabled)
            }
            Spacer(Modifier.height(9.dp))
            Row(verticalAlignment = Alignment.CenterVertically) {
                Slider(
                    value = threshold.coerceIn(range.start, range.endInclusive),
                    onValueChange = onThreshold,
                    valueRange = range,
                    enabled = enabled,
                    modifier = Modifier.weight(1f),
                )
                Spacer(Modifier.size(9.dp))
                Box(
                    modifier = Modifier
                        .background(color.copy(alpha = if (enabled) .11f else .04f), RoundedCornerShape(10.dp))
                        .padding(horizontal = 9.dp, vertical = 7.dp),
                ) {
                    Text(
                        "${threshold.roundToInt()} $unit",
                        color = if (enabled) color else TextMuted,
                        fontWeight = FontWeight.Bold,
                        fontSize = 10.sp,
                    )
                }
            }
        }
    }
}

@Composable
private fun ThermalWatchRule(
    settings: WatchSettings,
    onSettingsChange: (WatchSettings) -> Unit,
) {
    GlassPanel(Modifier.fillMaxWidth()) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Box(Modifier.size(8.dp).background(if (settings.thermalEnabled) Danger else TextMuted, CircleShape))
            Spacer(Modifier.size(9.dp))
            Column(Modifier.weight(1f)) {
                Text("Thermal pressure", fontWeight = FontWeight.Bold)
                Text(
                    "Trigger at Android thermal level ${settings.thermalLevelThreshold} or above.",
                    color = TextMuted,
                    style = MaterialTheme.typography.bodySmall,
                )
            }
            Switch(
                checked = settings.thermalEnabled,
                onCheckedChange = { onSettingsChange(settings.copy(thermalEnabled = it)) },
            )
        }
    }
}

@Composable
private fun WatchEventCard(event: WatchEvent) {
    val color = if (event.severity == "critical") Danger else Warm
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .background(color.copy(alpha = .055f), RoundedCornerShape(16.dp))
            .border(1.dp, color.copy(alpha = .17f), RoundedCornerShape(16.dp))
            .padding(13.dp),
        verticalAlignment = Alignment.Top,
    ) {
        Box(Modifier.size(9.dp).background(color, CircleShape))
        Spacer(Modifier.size(10.dp))
        Column(Modifier.weight(1f)) {
            Text(event.title, fontWeight = FontWeight.Bold, fontSize = 13.sp)
            Spacer(Modifier.height(3.dp))
            Text(event.detail, color = TextSecondary, style = MaterialTheme.typography.bodySmall)
        }
        Text(event.capturedAtMillis.asEventTime(), color = TextMuted, fontSize = 9.sp)
    }
}

@Composable
private fun WatchEventsEmpty() {
    GlassPanel(Modifier.fillMaxWidth()) {
        Column(horizontalAlignment = Alignment.CenterHorizontally, modifier = Modifier.fillMaxWidth()) {
            Text("✓", color = Success, fontSize = 27.sp, fontWeight = FontWeight.Black)
            Text("No watch events", fontWeight = FontWeight.Bold)
            Spacer(Modifier.height(4.dp))
            Text(
                "Metrics have not entered any enabled watch zone.",
                color = TextMuted,
                style = MaterialTheme.typography.bodySmall,
            )
        }
    }
}

private fun Long.asEventTime(): String = Instant.ofEpochMilli(this)
    .atZone(ZoneId.systemDefault())
    .format(DateTimeFormatter.ofPattern("HH:mm"))
