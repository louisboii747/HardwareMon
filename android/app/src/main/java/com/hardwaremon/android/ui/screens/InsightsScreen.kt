package com.hardwaremon.android.ui.screens

import android.content.Intent
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
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
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.hardwaremon.android.model.MonitoringLens
import com.hardwaremon.android.model.SessionRecord
import com.hardwaremon.android.model.SystemHealthProfile
import com.hardwaremon.android.model.TelemetrySnapshot
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
fun InsightsScreen(
    state: DashboardUiState,
    onPausedChange: (Boolean) -> Unit,
    onLensChange: (MonitoringLens) -> Unit,
    onCaptureSession: () -> Unit,
    onRemoveSession: (String) -> Unit,
) {
    val context = LocalContext.current
    AppBackground {
        LazyColumn(
            modifier = Modifier.fillMaxSize().safeDrawingPadding(),
            contentPadding = PaddingValues(start = 18.dp, end = 18.dp, top = 14.dp, bottom = 118.dp),
            verticalArrangement = Arrangement.spacedBy(14.dp),
        ) {
            item {
                ExperienceHeader(
                    eyebrow = "ON-DEVICE INTELLIGENCE",
                    title = "Session insights",
                    detail = "Health, trends, and private snapshots interpreted on this device.",
                )
            }
            item {
                LensSelector(
                    selected = state.monitoringLens,
                    onSelected = onLensChange,
                )
            }
            state.healthProfile?.let { profile ->
                item { HealthHero(profile, state.monitoringLens) }
                item { HealthSignals(profile) }
                item {
                    SessionActions(
                        paused = state.isPaused,
                        onPausedChange = onPausedChange,
                        onCapture = onCaptureSession,
                        onShare = {
                            val report = currentSessionReport(state)
                            context.startActivity(
                                Intent.createChooser(
                                    Intent(Intent.ACTION_SEND).apply {
                                        type = "text/plain"
                                        putExtra(Intent.EXTRA_SUBJECT, "HardwareMon session snapshot")
                                        putExtra(Intent.EXTRA_TEXT, report)
                                    },
                                    "Share HardwareMon snapshot",
                                ),
                            )
                        },
                    )
                }
                item { TrendPanel(state.history) }
            } ?: item { IntelligenceLoading() }

            item {
                SectionTitle(
                    title = "Session journal",
                    detail = "Up to 20 snapshots, stored locally and never uploaded.",
                )
            }
            if (state.journal.isEmpty()) {
                item { JournalEmptyState() }
            } else {
                items(state.journal.size, key = { state.journal[it].id }) { index ->
                    JournalCard(
                        record = state.journal[index],
                        onDelete = { onRemoveSession(state.journal[index].id) },
                        onShare = {
                            context.startActivity(
                                Intent.createChooser(
                                    Intent(Intent.ACTION_SEND).apply {
                                        type = "text/plain"
                                        putExtra(Intent.EXTRA_TEXT, state.journal[index].report())
                                    },
                                    "Share HardwareMon snapshot",
                                ),
                            )
                        },
                    )
                }
            }
        }
    }
}

@Composable
internal fun ExperienceHeader(eyebrow: String, title: String, detail: String) {
    Column(modifier = Modifier.padding(bottom = 4.dp)) {
        Text(
            eyebrow,
            color = ElectricBlue,
            style = MaterialTheme.typography.labelLarge,
            letterSpacing = 1.4.sp,
        )
        Spacer(Modifier.height(6.dp))
        Text(title, style = MaterialTheme.typography.headlineMedium)
        Spacer(Modifier.height(4.dp))
        Text(detail, style = MaterialTheme.typography.bodyMedium, color = TextSecondary)
    }
}

@Composable
private fun LensSelector(selected: MonitoringLens, onSelected: (MonitoringLens) -> Unit) {
    GlassPanel(Modifier.fillMaxWidth()) {
        Column {
            SectionTitle("Monitoring lens", "Change what HardwareMon prioritises in its health score.")
            Spacer(Modifier.height(12.dp))
            Row(
                modifier = Modifier.fillMaxWidth().horizontalScroll(rememberScrollState()),
                horizontalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                MonitoringLens.entries.forEach { lens ->
                    val active = selected == lens
                    Column(
                        modifier = Modifier
                            .width(136.dp)
                            .clip(RoundedCornerShape(16.dp))
                            .background(if (active) ElectricBlue.copy(alpha = .13f) else Color.White.copy(alpha = .035f))
                            .border(
                                1.dp,
                                if (active) ElectricBlue.copy(alpha = .35f) else Color.White.copy(alpha = .06f),
                                RoundedCornerShape(16.dp),
                            )
                            .clickable { onSelected(lens) }
                            .padding(12.dp),
                    ) {
                        Text(
                            lens.label,
                            color = if (active) ElectricBlue else MaterialTheme.colorScheme.onSurface,
                            fontWeight = FontWeight.Bold,
                        )
                        Spacer(Modifier.height(4.dp))
                        Text(
                            lens.description,
                            color = TextMuted,
                            style = MaterialTheme.typography.bodySmall,
                            maxLines = 3,
                            overflow = TextOverflow.Ellipsis,
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun HealthHero(profile: SystemHealthProfile, lens: MonitoringLens) {
    val color = scoreColor(profile.overallScore)
    GlassPanel(Modifier.fillMaxWidth()) {
        Column {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Box(
                    modifier = Modifier
                        .size(88.dp)
                        .background(color.copy(alpha = .10f), CircleShape)
                        .border(5.dp, color.copy(alpha = .65f), CircleShape),
                    contentAlignment = Alignment.Center,
                ) {
                    Column(horizontalAlignment = Alignment.CenterHorizontally) {
                        Text(
                            profile.overallScore.toString(),
                            style = MaterialTheme.typography.headlineMedium,
                            fontWeight = FontWeight.Black,
                        )
                        Text(profile.stateLabel.uppercase(), color = color, fontSize = 8.sp, letterSpacing = .8.sp)
                    }
                }
                Spacer(Modifier.width(16.dp))
                Column(Modifier.weight(1f)) {
                    Text("${lens.label.uppercase()} HEALTH", color = color, fontSize = 9.sp, letterSpacing = 1.2.sp)
                    Spacer(Modifier.height(7.dp))
                    Text(
                        profile.observation,
                        style = MaterialTheme.typography.titleMedium,
                        fontWeight = FontWeight.SemiBold,
                    )
                }
            }
            Spacer(Modifier.height(14.dp))
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .background(color.copy(alpha = .07f), RoundedCornerShape(12.dp))
                    .padding(11.dp),
            ) {
                Text("◎  ${profile.bottleneck}", color = TextSecondary, style = MaterialTheme.typography.bodyMedium)
            }
        }
    }
}

@Composable
private fun HealthSignals(profile: SystemHealthProfile) {
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        profile.signals.chunked(2).forEach { rowSignals ->
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                rowSignals.forEach { signal ->
                    val color = scoreColor(signal.score)
                    Box(
                        modifier = Modifier
                            .weight(1f)
                            .background(color.copy(alpha = .055f), RoundedCornerShape(16.dp))
                            .border(1.dp, color.copy(alpha = .15f), RoundedCornerShape(16.dp))
                            .padding(12.dp),
                    ) {
                        Column {
                            Row(verticalAlignment = Alignment.CenterVertically) {
                                Text(signal.score.toString(), color = color, fontWeight = FontWeight.Black, fontSize = 18.sp)
                                Spacer(Modifier.width(7.dp))
                                Text(signal.label, fontWeight = FontWeight.Bold, fontSize = 12.sp)
                            }
                            Spacer(Modifier.height(4.dp))
                            Text(signal.detail, color = TextMuted, style = MaterialTheme.typography.bodySmall)
                        }
                    }
                }
                if (rowSignals.size == 1) Spacer(Modifier.weight(1f))
            }
        }
    }
}

@Composable
private fun SessionActions(
    paused: Boolean,
    onPausedChange: (Boolean) -> Unit,
    onCapture: () -> Unit,
    onShare: () -> Unit,
) {
    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        ActionChip(if (paused) "Resume" else "Pause", if (paused) "▶" else "Ⅱ", ElectricBlue) {
            onPausedChange(!paused)
        }
        ActionChip("Save", "＋", Violet, onCapture)
        ActionChip("Share", "↗", Cyan, onShare)
    }
}

@Composable
private fun ActionChip(label: String, symbol: String, color: Color, onClick: () -> Unit) {
    Row(
        modifier = Modifier
            .clip(RoundedCornerShape(14.dp))
            .background(color.copy(alpha = .10f))
            .border(1.dp, color.copy(alpha = .22f), RoundedCornerShape(14.dp))
            .clickable(onClick = onClick)
            .padding(horizontal = 14.dp, vertical = 10.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(symbol, color = color, fontWeight = FontWeight.Black)
        Spacer(Modifier.width(7.dp))
        Text(label, fontWeight = FontWeight.Bold, fontSize = 12.sp)
    }
}

@Composable
private fun TrendPanel(history: List<TelemetrySnapshot>) {
    val first = history.firstOrNull()
    val latest = history.lastOrNull()
    GlassPanel(Modifier.fillMaxWidth()) {
        Column {
            SectionTitle("Session drift", "Change from the oldest sample retained in this app session.")
            Spacer(Modifier.height(12.dp))
            if (first == null || latest == null || history.size < 2) {
                Text("Collecting enough samples to compare this session.", color = TextMuted)
            } else {
                TrendRow("CPU", first.cpu.usagePercent, latest.cpu.usagePercent, "%")
                Spacer(Modifier.height(9.dp))
                TrendRow("Memory", first.memory.usagePercent, latest.memory.usagePercent, "%")
                Spacer(Modifier.height(9.dp))
                TrendRow("Storage", first.storage.usagePercent, latest.storage.usagePercent, "%")
                Spacer(Modifier.height(9.dp))
                Row {
                    Text("Samples retained", color = TextSecondary)
                    Spacer(Modifier.weight(1f))
                    Text("${history.size} / 60", fontWeight = FontWeight.Bold)
                }
            }
        }
    }
}

@Composable
private fun TrendRow(label: String, first: Float?, latest: Float?, unit: String) {
    val delta = if (first != null && latest != null) latest - first else null
    Row {
        Text(label, color = TextSecondary)
        Spacer(Modifier.weight(1f))
        Text(
            delta?.let { "${if (it >= 0) "+" else ""}${"%.1f".format(it)}$unit" } ?: "Unavailable",
            color = when {
                delta == null -> TextMuted
                delta > 8 -> Warm
                delta < -8 -> Success
                else -> MaterialTheme.colorScheme.onSurface
            },
            fontWeight = FontWeight.Bold,
        )
    }
}

@Composable
private fun JournalCard(record: SessionRecord, onDelete: () -> Unit, onShare: () -> Unit) {
    val color = scoreColor(record.score)
    GlassPanel(Modifier.fillMaxWidth()) {
        Column {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Box(
                    modifier = Modifier.size(44.dp).background(color.copy(alpha = .12f), CircleShape),
                    contentAlignment = Alignment.Center,
                ) {
                    Text(record.score.toString(), color = color, fontWeight = FontWeight.Black)
                }
                Spacer(Modifier.width(11.dp))
                Column(Modifier.weight(1f)) {
                    Text("${record.stateLabel} · ${record.lens.label}", fontWeight = FontWeight.Bold)
                    Text(record.capturedAtMillis.asDateTime(), color = TextMuted, style = MaterialTheme.typography.bodySmall)
                }
                Text("↗", modifier = Modifier.clickable(onClick = onShare).padding(10.dp), color = ElectricBlue)
                Text("×", modifier = Modifier.clickable(onClick = onDelete).padding(10.dp), color = TextMuted)
            }
            Spacer(Modifier.height(10.dp))
            Text(record.observation, color = TextSecondary, style = MaterialTheme.typography.bodyMedium)
            Spacer(Modifier.height(10.dp))
            Row(horizontalArrangement = Arrangement.spacedBy(7.dp)) {
                MiniMetric("CPU", record.cpuUsage)
                MiniMetric("RAM", record.memoryUsage)
                MiniMetric("Storage", record.storageUsage)
                MiniMetric("Battery", record.batteryPercentage)
            }
        }
    }
}

@Composable
private fun MiniMetric(label: String, value: Int?) {
    Column(
        modifier = Modifier
            .background(Color.White.copy(alpha = .04f), RoundedCornerShape(9.dp))
            .padding(horizontal = 8.dp, vertical = 6.dp),
    ) {
        Text(label, color = TextMuted, fontSize = 7.sp)
        Text(value?.let { "$it%" } ?: "—", fontSize = 10.sp, fontWeight = FontWeight.Bold)
    }
}

@Composable
private fun JournalEmptyState() {
    GlassPanel(Modifier.fillMaxWidth()) {
        Column(horizontalAlignment = Alignment.CenterHorizontally, modifier = Modifier.fillMaxWidth()) {
            Text("＋", color = Violet, fontSize = 30.sp)
            Text("Capture your first session", fontWeight = FontWeight.Bold)
            Spacer(Modifier.height(5.dp))
            Text(
                "Save a baseline, heavy workload, or thermal event for later comparison.",
                color = TextMuted,
                style = MaterialTheme.typography.bodySmall,
            )
        }
    }
}

@Composable
private fun IntelligenceLoading() {
    GlassPanel(Modifier.fillMaxWidth().height(180.dp)) {
        Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
            CircularProgressIndicator(color = ElectricBlue, strokeWidth = 2.dp)
        }
    }
}

@Composable
internal fun SectionTitle(title: String, detail: String) {
    Column {
        Text(title, style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold)
        Text(detail, style = MaterialTheme.typography.bodySmall, color = TextMuted)
    }
}

private fun scoreColor(score: Int): Color = when {
    score >= 82 -> Success
    score >= 65 -> Cyan
    score >= 45 -> Warm
    else -> Danger
}

private fun currentSessionReport(state: DashboardUiState): String {
    val snapshot = state.snapshot ?: return "HardwareMon is still collecting telemetry."
    val profile = state.healthProfile ?: return "HardwareMon is still calculating device health."
    return buildString {
        appendLine("HardwareMon Android live session")
        appendLine("Lens: ${state.monitoringLens.label}")
        appendLine("Health: ${profile.overallScore}/100 · ${profile.stateLabel}")
        appendLine(profile.observation)
        appendLine(profile.bottleneck)
        appendLine("CPU: ${snapshot.cpu.usagePercent?.roundToInt()?.let { "$it%" } ?: "Unavailable"}")
        appendLine("Memory: ${snapshot.memory.usagePercent?.roundToInt()?.let { "$it%" } ?: "Unavailable"}")
        appendLine("Storage: ${snapshot.storage.usagePercent?.roundToInt()?.let { "$it%" } ?: "Unavailable"}")
        appendLine("Battery: ${snapshot.battery.percentage?.let { "$it%" } ?: "Unavailable"}")
    }
}

private fun Long.asDateTime(): String = Instant.ofEpochMilli(this)
    .atZone(ZoneId.systemDefault())
    .format(DateTimeFormatter.ofPattern("EEE, d MMM · HH:mm"))
