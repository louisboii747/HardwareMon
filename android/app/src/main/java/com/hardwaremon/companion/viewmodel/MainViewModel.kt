package com.hardwaremon.companion.viewmodel

import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewModelScope
import com.hardwaremon.companion.data.ApiClient
import com.hardwaremon.companion.data.SettingsRepository
import com.hardwaremon.companion.data.TelemetryRepository
import com.hardwaremon.companion.data.models.StatsResponse
import kotlinx.coroutines.Job
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import retrofit2.HttpException
import java.net.ConnectException
import java.net.UnknownHostException
import java.net.SocketTimeoutException

enum class AppScreen { CONNECT, DASHBOARD }

enum class ConnectionStatus { IDLE, CONNECTING, CONNECTED, DISCONNECTED }

data class MainUiState(
    val screen: AppScreen = AppScreen.CONNECT,
    val backendUrl: String = "",
    val connectionStatus: ConnectionStatus = ConnectionStatus.IDLE,
    val deviceName: String = "HardwareMon Desktop",
    val stats: StatsResponse? = null,
    val lastUpdatedEpochMillis: Long? = null,
    val isRefreshing: Boolean = false,
    val errorMessage: String? = null,
)

class MainViewModel(
    private val telemetryRepository: TelemetryRepository,
    private val settingsRepository: SettingsRepository,
) : ViewModel() {
    private val _uiState = MutableStateFlow(MainUiState())
    val uiState: StateFlow<MainUiState> = _uiState.asStateFlow()

    private var connectionJob: Job? = null

    init {
        viewModelScope.launch {
            val savedUrl = settingsRepository.backendUrl.first()
            if (savedUrl.isNotBlank()) {
                _uiState.update { it.copy(backendUrl = savedUrl) }
                connect()
            }
        }
    }

    fun onBackendUrlChanged(value: String) {
        _uiState.update {
            it.copy(
                backendUrl = value,
                errorMessage = null,
                connectionStatus = ConnectionStatus.IDLE,
            )
        }
    }

    fun connect() {
        connectionJob?.cancel()
        val rawUrl = _uiState.value.backendUrl
        val normalizedUrl = runCatching { ApiClient.normalizeBaseUrl(rawUrl) }
            .getOrElse { error ->
                _uiState.update {
                    it.copy(
                        connectionStatus = ConnectionStatus.DISCONNECTED,
                        errorMessage = error.message,
                    )
                }
                return
            }

        connectionJob = viewModelScope.launch {
            _uiState.update {
                it.copy(
                    backendUrl = normalizedUrl.trimEnd('/'),
                    connectionStatus = ConnectionStatus.CONNECTING,
                    errorMessage = null,
                )
            }
            runCatching { telemetryRepository.connect(normalizedUrl) }
                .onSuccess { result ->
                    settingsRepository.saveBackendUrl(normalizedUrl)
                    _uiState.update {
                        it.copy(
                            screen = AppScreen.DASHBOARD,
                            connectionStatus = ConnectionStatus.CONNECTED,
                            deviceName = result.device.displayName,
                            stats = result.stats,
                            lastUpdatedEpochMillis = System.currentTimeMillis(),
                            errorMessage = null,
                        )
                    }
                }
                .onFailure { error ->
                    _uiState.update {
                        it.copy(
                            connectionStatus = ConnectionStatus.DISCONNECTED,
                            errorMessage = error.toConnectionMessage(),
                        )
                    }
                }
        }
    }

    fun refresh() {
        val url = _uiState.value.backendUrl
        if (url.isBlank() || _uiState.value.isRefreshing) return

        viewModelScope.launch {
            _uiState.update { it.copy(isRefreshing = true, errorMessage = null) }
            runCatching { telemetryRepository.refresh(url) }
                .onSuccess { stats ->
                    _uiState.update {
                        it.copy(
                            stats = stats,
                            lastUpdatedEpochMillis = System.currentTimeMillis(),
                            connectionStatus = ConnectionStatus.CONNECTED,
                            isRefreshing = false,
                        )
                    }
                }
                .onFailure { error ->
                    _uiState.update {
                        it.copy(
                            connectionStatus = ConnectionStatus.DISCONNECTED,
                            isRefreshing = false,
                            errorMessage = error.toConnectionMessage(),
                        )
                    }
                }
        }
    }

    fun changeBackend() {
        connectionJob?.cancel()
        _uiState.update {
            it.copy(
                screen = AppScreen.CONNECT,
                connectionStatus = ConnectionStatus.IDLE,
                errorMessage = null,
                isRefreshing = false,
            )
        }
    }

    fun dismissError() {
        _uiState.update { it.copy(errorMessage = null) }
    }

    private fun Throwable.toConnectionMessage(): String = when (this) {
        is HttpException -> when (code()) {
            404 -> "The desktop responded, but the required endpoint was not found. Check that this HardwareMon backend provides /device/self and /stats."
            else -> "The desktop returned HTTP ${code()}."
        }
        is SocketTimeoutException -> "The desktop took too long to respond. Check its address and firewall."
        is UnknownHostException -> "The desktop address could not be found. Check the URL and Wi-Fi network."
        is ConnectException -> "Connection refused. Make sure HardwareMon is running and reachable on this network."
        is IllegalArgumentException -> message ?: "The backend URL is not valid."
        else -> message?.takeIf { it.isNotBlank() }
            ?: "Could not connect to the HardwareMon desktop."
    }

    class Factory(
        private val telemetryRepository: TelemetryRepository,
        private val settingsRepository: SettingsRepository,
    ) : ViewModelProvider.Factory {
        @Suppress("UNCHECKED_CAST")
        override fun <T : ViewModel> create(modelClass: Class<T>): T {
            require(modelClass.isAssignableFrom(MainViewModel::class.java))
            return MainViewModel(telemetryRepository, settingsRepository) as T
        }
    }
}
