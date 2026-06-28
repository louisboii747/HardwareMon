package com.hardwaremon.companion.ui

import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.platform.LocalContext
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import com.hardwaremon.companion.data.SettingsRepository
import com.hardwaremon.companion.data.TelemetryRepository
import com.hardwaremon.companion.ui.screens.ConnectScreen
import com.hardwaremon.companion.ui.screens.DashboardScreen
import com.hardwaremon.companion.ui.theme.HardwareMonTheme
import com.hardwaremon.companion.viewmodel.AppScreen
import com.hardwaremon.companion.viewmodel.MainViewModel

@Composable
fun HardwareMonCompanionApp() {
    val context = LocalContext.current.applicationContext
    val mainViewModel: MainViewModel = viewModel(
        factory = MainViewModel.Factory(
            telemetryRepository = TelemetryRepository(),
            settingsRepository = SettingsRepository(context),
        ),
    )
    val uiState by mainViewModel.uiState.collectAsStateWithLifecycle()

    HardwareMonTheme {
        when (uiState.screen) {
            AppScreen.CONNECT -> ConnectScreen(
                state = uiState,
                onUrlChanged = mainViewModel::onBackendUrlChanged,
                onConnect = mainViewModel::connect,
            )

            AppScreen.DASHBOARD -> DashboardScreen(
                state = uiState,
                onRefresh = mainViewModel::refresh,
                onChangeBackend = mainViewModel::changeBackend,
                onDismissError = mainViewModel::dismissError,
            )
        }
    }
}
