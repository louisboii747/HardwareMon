package com.hardwaremon.android.viewmodel

import android.content.Context
import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewModelScope
import com.hardwaremon.android.data.TelemetryRepository
import com.hardwaremon.android.data.UserPreferencesRepository
import com.hardwaremon.android.model.MonitoringLens
import com.hardwaremon.android.model.SessionRecord
import com.hardwaremon.android.model.SystemHealthProfile
import com.hardwaremon.android.model.TelemetrySnapshot
import com.hardwaremon.android.model.WatchEvent
import com.hardwaremon.android.model.WatchSettings
import com.hardwaremon.android.model.buildSystemHealthProfile
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
    val history: List<TelemetrySnapshot> = emptyList(),
    val healthProfile: SystemHealthProfile? = null,
    val monitoringLens: MonitoringLens = MonitoringLens.BALANCED,
    val isPaused: Boolean = false,
    val watchSettings: WatchSettings = WatchSettings(),
    val watchEvents: List<WatchEvent> = emptyList(),
    val journal: List<SessionRecord> = emptyList(),
    val isLoading: Boolean = true,
    val isRefreshing: Boolean = false,
    val errorMessage: String? = null,
)

class DashboardViewModel(
    private val repository: TelemetryRepository,
    private val preferencesRepository: UserPreferencesRepository,
) : ViewModel() {
    private val _uiState = MutableStateFlow(
        DashboardUiState(
            monitoringLens = preferencesRepository.loadLens(),
            watchSettings = preferencesRepository.loadWatchSettings(),
            watchEvents = preferencesRepository.loadWatchEvents(),
            journal = preferencesRepository.loadJournal(),
        ),
    )
    val uiState: StateFlow<DashboardUiState> = _uiState.asStateFlow()

    private val collectionMutex = Mutex()
    private var monitoringJob: Job? = null
    private val activeWatchKeys = mutableSetOf<String>()

    fun startMonitoring() {
        if (_uiState.value.isPaused) return
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

    fun setPaused(paused: Boolean) {
        _uiState.update { it.copy(isPaused = paused) }
        if (paused) stopMonitoring() else startMonitoring()
    }

    fun setMonitoringLens(lens: MonitoringLens) {
        preferencesRepository.saveLens(lens)
        _uiState.update { state ->
            state.copy(
                monitoringLens = lens,
                healthProfile = state.snapshot?.let {
                    buildSystemHealthProfile(it, state.history, lens)
                },
            )
        }
    }

    fun updateWatchSettings(settings: WatchSettings) {
        preferencesRepository.saveWatchSettings(settings)
        _uiState.update { it.copy(watchSettings = settings) }
    }

    fun captureSession() {
        val state = _uiState.value
        val snapshot = state.snapshot ?: return
        val profile = state.healthProfile ?: return
        val record = SessionRecord(
            id = System.currentTimeMillis().toString(),
            capturedAtMillis = System.currentTimeMillis(),
            score = profile.overallScore,
            stateLabel = profile.stateLabel,
            observation = profile.observation,
            bottleneck = profile.bottleneck,
            lens = state.monitoringLens,
            cpuUsage = snapshot.cpu.usagePercent?.toInt(),
            memoryUsage = snapshot.memory.usagePercent?.toInt(),
            storageUsage = snapshot.storage.usagePercent?.toInt(),
            batteryPercentage = snapshot.battery.percentage,
        )
        val updated = (listOf(record) + state.journal)
            .take(UserPreferencesRepository.MAX_JOURNAL_ENTRIES)
        preferencesRepository.saveJournal(updated)
        _uiState.update { it.copy(journal = updated) }
    }

    fun removeSession(id: String) {
        val updated = _uiState.value.journal.filterNot { it.id == id }
        preferencesRepository.saveJournal(updated)
        _uiState.update { it.copy(journal = updated) }
    }

    fun clearWatchEvents() {
        preferencesRepository.saveWatchEvents(emptyList())
        _uiState.update { it.copy(watchEvents = emptyList()) }
    }

    private suspend fun collectTelemetry(showRefreshIndicator: Boolean) {
        collectionMutex.withLock {
            if (showRefreshIndicator) {
                _uiState.update { it.copy(isRefreshing = true) }
            }
            runCatching { repository.collectSnapshot() }
                .onSuccess { snapshot ->
                    _uiState.update { state ->
                        val history = (state.history + snapshot).takeLast(MAX_HISTORY_SAMPLES)
                        val newEvents = evaluateWatches(snapshot, state.watchSettings)
                        val events = (newEvents + state.watchEvents)
                            .take(UserPreferencesRepository.MAX_WATCH_EVENTS)
                        if (newEvents.isNotEmpty()) {
                            preferencesRepository.saveWatchEvents(events)
                        }
                        state.copy(
                            snapshot = snapshot,
                            history = history,
                            healthProfile = buildSystemHealthProfile(
                                snapshot,
                                history,
                                state.monitoringLens,
                            ),
                            watchEvents = events,
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

    private fun evaluateWatches(
        snapshot: TelemetrySnapshot,
        settings: WatchSettings,
    ): List<WatchEvent> {
        val events = mutableListOf<WatchEvent>()
        fun evaluate(
            key: String,
            condition: Boolean,
            title: String,
            detail: String,
            severity: String,
        ) {
            if (!condition) {
                activeWatchKeys.remove(key)
                return
            }
            if (activeWatchKeys.add(key)) {
                val now = System.currentTimeMillis()
                events += WatchEvent("$key-$now", now, title, detail, severity)
            }
        }

        val cpu = snapshot.cpu.usagePercent
        evaluate(
            key = "cpu",
            condition = settings.cpuEnabled && cpu != null && cpu >= settings.cpuThreshold,
            title = "CPU watch triggered",
            detail = "CPU reached ${cpu?.toInt()}% against a ${settings.cpuThreshold.toInt()}% watch.",
            severity = "warning",
        )
        val memory = snapshot.memory.usagePercent
        evaluate(
            key = "memory",
            condition = settings.memoryEnabled && memory != null && memory >= settings.memoryThreshold,
            title = "Memory watch triggered",
            detail = "Memory reached ${memory?.toInt()}% against a ${settings.memoryThreshold.toInt()}% watch.",
            severity = "warning",
        )
        val storage = snapshot.storage.usagePercent
        evaluate(
            key = "storage",
            condition = settings.storageEnabled && storage != null && storage >= settings.storageThreshold,
            title = "Storage watch triggered",
            detail = "Storage reached ${storage?.toInt()}% used.",
            severity = "critical",
        )
        val battery = snapshot.battery.percentage
        val charging = snapshot.battery.chargingState?.contains("Charging", ignoreCase = true) == true
        evaluate(
            key = "battery",
            condition = settings.batteryEnabled && battery != null && battery <= settings.batteryLowThreshold && !charging,
            title = "Low battery watch triggered",
            detail = "Battery reserve fell to ${battery ?: 0}% while not charging.",
            severity = "warning",
        )
        val thermal = snapshot.thermal.statusLevel
        evaluate(
            key = "thermal",
            condition = settings.thermalEnabled && thermal != null && thermal >= settings.thermalLevelThreshold,
            title = "Thermal watch triggered",
            detail = "Android reports ${snapshot.thermal.status ?: "elevated thermal pressure"}.",
            severity = "critical",
        )
        return events
    }

    class Factory(context: Context) : ViewModelProvider.Factory {
        private val repository = TelemetryRepository(context.applicationContext)
        private val preferencesRepository = UserPreferencesRepository(context.applicationContext)

        @Suppress("UNCHECKED_CAST")
        override fun <T : ViewModel> create(modelClass: Class<T>): T {
            require(modelClass.isAssignableFrom(DashboardViewModel::class.java))
            return DashboardViewModel(repository, preferencesRepository) as T
        }
    }

    companion object {
        const val REFRESH_INTERVAL_MILLIS = 3_000L
        const val MAX_HISTORY_SAMPLES = 60
    }
}
