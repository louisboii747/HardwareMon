package com.hardwaremon.android.data

import android.content.Context
import com.hardwaremon.android.model.MonitoringLens
import com.hardwaremon.android.model.SessionRecord
import com.hardwaremon.android.model.WatchEvent
import com.hardwaremon.android.model.WatchSettings
import org.json.JSONArray
import org.json.JSONObject

class UserPreferencesRepository(context: Context) {
    private val preferences = context.getSharedPreferences("hardwaremon_experience", Context.MODE_PRIVATE)

    fun loadLens(): MonitoringLens = runCatching {
        MonitoringLens.valueOf(preferences.getString(KEY_LENS, MonitoringLens.BALANCED.name).orEmpty())
    }.getOrDefault(MonitoringLens.BALANCED)

    fun saveLens(lens: MonitoringLens) {
        preferences.edit().putString(KEY_LENS, lens.name).apply()
    }

    fun loadWatchSettings(): WatchSettings = WatchSettings(
        cpuEnabled = preferences.getBoolean("watch_cpu_enabled", true),
        cpuThreshold = preferences.getFloat("watch_cpu_threshold", 90f),
        memoryEnabled = preferences.getBoolean("watch_memory_enabled", true),
        memoryThreshold = preferences.getFloat("watch_memory_threshold", 88f),
        storageEnabled = preferences.getBoolean("watch_storage_enabled", true),
        storageThreshold = preferences.getFloat("watch_storage_threshold", 90f),
        batteryEnabled = preferences.getBoolean("watch_battery_enabled", true),
        batteryLowThreshold = preferences.getInt("watch_battery_threshold", 20),
        thermalEnabled = preferences.getBoolean("watch_thermal_enabled", true),
        thermalLevelThreshold = preferences.getInt("watch_thermal_threshold", 3),
    )

    fun saveWatchSettings(settings: WatchSettings) {
        preferences.edit()
            .putBoolean("watch_cpu_enabled", settings.cpuEnabled)
            .putFloat("watch_cpu_threshold", settings.cpuThreshold)
            .putBoolean("watch_memory_enabled", settings.memoryEnabled)
            .putFloat("watch_memory_threshold", settings.memoryThreshold)
            .putBoolean("watch_storage_enabled", settings.storageEnabled)
            .putFloat("watch_storage_threshold", settings.storageThreshold)
            .putBoolean("watch_battery_enabled", settings.batteryEnabled)
            .putInt("watch_battery_threshold", settings.batteryLowThreshold)
            .putBoolean("watch_thermal_enabled", settings.thermalEnabled)
            .putInt("watch_thermal_threshold", settings.thermalLevelThreshold)
            .apply()
    }

    fun loadJournal(): List<SessionRecord> = runCatching {
        val array = JSONArray(preferences.getString(KEY_JOURNAL, "[]"))
        buildList {
            for (index in 0 until array.length()) add(array.getJSONObject(index).toSessionRecord())
        }
    }.getOrDefault(emptyList())

    fun saveJournal(records: List<SessionRecord>) {
        val array = JSONArray()
        records.take(MAX_JOURNAL_ENTRIES).forEach { record -> array.put(record.toJson()) }
        preferences.edit().putString(KEY_JOURNAL, array.toString()).apply()
    }

    fun loadWatchEvents(): List<WatchEvent> = runCatching {
        val array = JSONArray(preferences.getString(KEY_WATCH_EVENTS, "[]"))
        buildList {
            for (index in 0 until array.length()) add(array.getJSONObject(index).toWatchEvent())
        }
    }.getOrDefault(emptyList())

    fun saveWatchEvents(events: List<WatchEvent>) {
        val array = JSONArray()
        events.take(MAX_WATCH_EVENTS).forEach { event -> array.put(event.toJson()) }
        preferences.edit().putString(KEY_WATCH_EVENTS, array.toString()).apply()
    }

    private fun SessionRecord.toJson() = JSONObject()
        .put("id", id)
        .put("capturedAt", capturedAtMillis)
        .put("score", score)
        .put("state", stateLabel)
        .put("observation", observation)
        .put("bottleneck", bottleneck)
        .put("lens", lens.name)
        .put("cpu", cpuUsage)
        .put("memory", memoryUsage)
        .put("storage", storageUsage)
        .put("battery", batteryPercentage)

    private fun JSONObject.toSessionRecord() = SessionRecord(
        id = getString("id"),
        capturedAtMillis = getLong("capturedAt"),
        score = getInt("score"),
        stateLabel = getString("state"),
        observation = getString("observation"),
        bottleneck = getString("bottleneck"),
        lens = runCatching { MonitoringLens.valueOf(getString("lens")) }.getOrDefault(MonitoringLens.BALANCED),
        cpuUsage = nullableInt("cpu"),
        memoryUsage = nullableInt("memory"),
        storageUsage = nullableInt("storage"),
        batteryPercentage = nullableInt("battery"),
    )

    private fun WatchEvent.toJson() = JSONObject()
        .put("id", id)
        .put("capturedAt", capturedAtMillis)
        .put("title", title)
        .put("detail", detail)
        .put("severity", severity)

    private fun JSONObject.toWatchEvent() = WatchEvent(
        id = getString("id"),
        capturedAtMillis = getLong("capturedAt"),
        title = getString("title"),
        detail = getString("detail"),
        severity = getString("severity"),
    )

    private fun JSONObject.nullableInt(key: String): Int? =
        if (isNull(key) || !has(key)) null else getInt(key)

    companion object {
        const val MAX_JOURNAL_ENTRIES = 20
        const val MAX_WATCH_EVENTS = 40
        private const val KEY_LENS = "monitoring_lens"
        private const val KEY_JOURNAL = "session_journal_v1"
        private const val KEY_WATCH_EVENTS = "watch_events_v1"
    }
}
