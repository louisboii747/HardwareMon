package com.hardwaremon.android.ui.screens

import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.hardwaremon.android.model.MonitoringLens
import com.hardwaremon.android.model.SessionRecord
import com.hardwaremon.android.model.WatchSettings
import com.hardwaremon.android.ui.theme.CardNavy
import com.hardwaremon.android.ui.theme.CardNavyLight
import com.hardwaremon.android.ui.theme.ElectricBlue
import com.hardwaremon.android.ui.theme.TextMuted
import com.hardwaremon.android.viewmodel.DashboardUiState

private enum class HomeTab(val label: String, val symbol: String) {
    OVERVIEW("Overview", "◫"),
    INSIGHTS("Insights", "◎"),
    WATCHES("Watches", "◉"),
}

@Composable
fun HardwareMonHome(
    state: DashboardUiState,
    onRefresh: () -> Unit,
    onPausedChange: (Boolean) -> Unit,
    onLensChange: (MonitoringLens) -> Unit,
    onCaptureSession: () -> Unit,
    onRemoveSession: (String) -> Unit,
    onWatchSettingsChange: (WatchSettings) -> Unit,
    onClearWatchEvents: () -> Unit,
) {
    var selectedTab by rememberSaveable { mutableStateOf(HomeTab.OVERVIEW) }

    Box(Modifier.fillMaxSize()) {
        AnimatedContent(
            targetState = selectedTab,
            transitionSpec = { fadeIn() togetherWith fadeOut() },
            label = "HardwareMon section",
        ) { tab ->
            when (tab) {
                HomeTab.OVERVIEW -> DashboardScreen(state = state, onRefresh = onRefresh)
                HomeTab.INSIGHTS -> InsightsScreen(
                    state = state,
                    onPausedChange = onPausedChange,
                    onLensChange = onLensChange,
                    onCaptureSession = onCaptureSession,
                    onRemoveSession = onRemoveSession,
                )
                HomeTab.WATCHES -> WatchCenterScreen(
                    state = state,
                    onSettingsChange = onWatchSettingsChange,
                    onClearEvents = onClearWatchEvents,
                )
            }
        }

        HomeNavigation(
            selected = selectedTab,
            onSelected = { selectedTab = it },
            modifier = Modifier.align(Alignment.BottomCenter),
        )
    }
}

@Composable
private fun HomeNavigation(
    selected: HomeTab,
    onSelected: (HomeTab) -> Unit,
    modifier: Modifier = Modifier,
) {
    Box(
        modifier = modifier
            .fillMaxWidth()
            .navigationBarsPadding()
            .padding(horizontal = 18.dp, vertical = 12.dp),
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(24.dp))
                .background(
                    Brush.linearGradient(
                        listOf(CardNavyLight.copy(alpha = .98f), CardNavy.copy(alpha = .97f)),
                    ),
                )
                .border(1.dp, Color.White.copy(alpha = .09f), RoundedCornerShape(24.dp))
                .padding(7.dp),
            horizontalArrangement = Arrangement.spacedBy(6.dp),
        ) {
            HomeTab.entries.forEach { tab ->
                val active = tab == selected
                Row(
                    modifier = Modifier
                        .weight(1f)
                        .clip(RoundedCornerShape(17.dp))
                        .background(if (active) ElectricBlue.copy(alpha = .14f) else Color.Transparent)
                        .clickable { onSelected(tab) }
                        .padding(horizontal = 8.dp, vertical = 10.dp),
                    horizontalArrangement = Arrangement.Center,
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Box(
                        modifier = Modifier
                            .size(25.dp)
                            .background(
                                if (active) ElectricBlue.copy(alpha = .13f) else Color.White.copy(alpha = .04f),
                                CircleShape,
                            ),
                        contentAlignment = Alignment.Center,
                    ) {
                        Text(tab.symbol, color = if (active) ElectricBlue else TextMuted, fontSize = 14.sp)
                    }
                    Spacer(Modifier.size(7.dp))
                    Column {
                        Text(
                            tab.label,
                            style = MaterialTheme.typography.labelLarge,
                            color = if (active) MaterialTheme.colorScheme.onSurface else TextMuted,
                            fontWeight = if (active) FontWeight.Bold else FontWeight.Medium,
                        )
                        if (active) {
                            Text("LIVE", color = ElectricBlue, fontSize = 7.sp, letterSpacing = 1.sp)
                        }
                    }
                }
            }
        }
    }
}
