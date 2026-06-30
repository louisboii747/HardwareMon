package com.hardwaremon.android.ui

import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.getValue
import androidx.compose.ui.platform.LocalContext
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.lifecycle.compose.LocalLifecycleOwner
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import com.hardwaremon.android.ui.screens.DashboardScreen
import com.hardwaremon.android.ui.theme.HardwareMonTheme
import com.hardwaremon.android.viewmodel.DashboardViewModel

@Composable
fun HardwareMonApp() {
    val context = LocalContext.current
    val lifecycleOwner = LocalLifecycleOwner.current
    val dashboardViewModel: DashboardViewModel = viewModel(
        factory = DashboardViewModel.Factory(context),
    )
    val state by dashboardViewModel.uiState.collectAsStateWithLifecycle()

    DisposableEffect(lifecycleOwner, dashboardViewModel) {
        val observer = LifecycleEventObserver { _, event ->
            when (event) {
                Lifecycle.Event.ON_START -> dashboardViewModel.startMonitoring()
                Lifecycle.Event.ON_STOP -> dashboardViewModel.stopMonitoring()
                else -> Unit
            }
        }
        lifecycleOwner.lifecycle.addObserver(observer)
        if (lifecycleOwner.lifecycle.currentState.isAtLeast(Lifecycle.State.STARTED)) {
            dashboardViewModel.startMonitoring()
        }
        onDispose {
            lifecycleOwner.lifecycle.removeObserver(observer)
            dashboardViewModel.stopMonitoring()
        }
    }

    HardwareMonTheme {
        PrivacyNoticeHost {
            DashboardScreen(
                state = state,
                onRefresh = dashboardViewModel::refreshNow,
            )
        }
    }
}
