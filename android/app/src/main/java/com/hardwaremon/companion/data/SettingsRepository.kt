package com.hardwaremon.companion.data

import android.content.Context
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map

private val Context.settingsDataStore by preferencesDataStore(name = "companion_settings")

class SettingsRepository(private val context: Context) {
    val backendUrl: Flow<String> = context.settingsDataStore.data.map { preferences ->
        preferences[BACKEND_URL].orEmpty()
    }

    suspend fun saveBackendUrl(url: String) {
        context.settingsDataStore.edit { preferences ->
            preferences[BACKEND_URL] = ApiClient.normalizeBaseUrl(url).trimEnd('/')
        }
    }

    private companion object {
        val BACKEND_URL = stringPreferencesKey("backend_url")
    }
}
