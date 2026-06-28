package com.hardwaremon.android.viewmodel

import android.content.Context
import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewModelScope
import com.hardwaremon.android.data.TelemetryRepository
import com.hardwaremon.android.model.TelemetrySnapshot
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock

data class DashboardUiState(
    val snapshot: TelemetrySnapshot? = null,
    val isLoading: Boolean = true,
    val isRefreshing: Boolean = false,
    val errorMessage: String? = null,
)

class DashboardViewModel(
    private val repository: TelemetryRepository,
) : ViewModel() {
    private val _uiState = MutableStateFlow(DashboardUiState())
    val uiState: StateFlow<DashboardUiState> = _uiState.asStateFlow()

    private val collectionMutex = Mutex()
    private var monitoringJob: Job? = null

    fun startMonitoring() {
        if (monitoringJob?.isActive == true) return
        monitoringJob = viewModelScope.launch {
            while (isActive) {
                collectTelemetry(showRefreshIndicator = false)
                delay(REFRESH_INTERVAL_MILLIS)
            }
        }
    }

    fun stopMonitoring() {
        monitoringJob?.cancel()
        monitoringJob = null
    }

    fun refreshNow() {
        viewModelScope.launch { collectTelemetry(showRefreshIndicator = true) }
    }

    private suspend fun collectTelemetry(showRefreshIndicator: Boolean) {
        collectionMutex.withLock {
            if (showRefreshIndicator) {
                _uiState.update { it.copy(isRefreshing = true) }
            }
            runCatching { repository.collectSnapshot() }
                .onSuccess { snapshot ->
                    _uiState.update {
                        it.copy(
                            snapshot = snapshot,
                            isLoading = false,
                            isRefreshing = false,
                            errorMessage = null,
                        )
                    }
                }
                .onFailure { error ->
                    _uiState.update {
                        it.copy(
                            isLoading = false,
                            isRefreshing = false,
                            errorMessage = error.message ?: "Telemetry could not be refreshed.",
                        )
                    }
                }
        }
    }

    class Factory(context: Context) : ViewModelProvider.Factory {
        private val repository = TelemetryRepository(context.applicationContext)

        @Suppress("UNCHECKED_CAST")
        override fun <T : ViewModel> create(modelClass: Class<T>): T {
            require(modelClass.isAssignableFrom(DashboardViewModel::class.java))
            return DashboardViewModel(repository) as T
        }
    }

    companion object {
        const val REFRESH_INTERVAL_MILLIS = 3_000L
    }
}
