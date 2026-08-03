package com.ryu.vx.data.store

import android.content.Context
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import com.ryu.vx.data.model.Favorite
import com.ryu.vx.data.model.History
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.map
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json

private val Context.dataStore by preferencesDataStore(name = "ryumoto_store")

class FavoritesStore(private val context: Context) {

    private val key = stringPreferencesKey("favorites")

    private val json = Json { ignoreUnknownKeys = true }

    val favorites: Flow<List<Favorite>> = context.dataStore.data.map { prefs ->
        prefs[key]?.let {
            runCatching { json.decodeFromString<List<Favorite>>(it) }.getOrDefault(emptyList())
        } ?: emptyList()
    }

    suspend fun add(favorite: Favorite) {
        val current = favorites.first()
        if (current.any { it.heroId == favorite.heroId && it.skinName == favorite.skinName }) return
        val updated = current + favorite
        context.dataStore.edit { it[key] = json.encodeToString(updated) }
    }

    suspend fun remove(heroId: Int, skinName: String) {
        val updated = favorites.first()
            .filterNot { it.heroId == heroId && it.skinName == skinName }
        context.dataStore.edit { it[key] = json.encodeToString(updated) }
    }

    suspend fun isFavorite(heroId: Int, skinName: String): Boolean =
        favorites.first().any { it.heroId == heroId && it.skinName == skinName }
}

class HistoryStore(private val context: Context) {

    private val key = stringPreferencesKey("history")

    private val json = Json { ignoreUnknownKeys = true }

    val history: Flow<List<History>> = context.dataStore.data.map { prefs ->
        prefs[key]?.let {
            runCatching { json.decodeFromString<List<History>>(it) }.getOrDefault(emptyList())
        } ?: emptyList()
    }

    suspend fun add(entry: History) {
        val updated = (listOf(entry) + history.first())
            .distinctBy { "${it.heroName}:${it.skinName}" }
            .take(200)
        context.dataStore.edit { it[key] = json.encodeToString(updated) }
    }

    suspend fun clear() {
        context.dataStore.edit { it.remove(key) }
    }
}
