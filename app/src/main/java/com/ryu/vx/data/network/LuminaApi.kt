package com.ryu.vx.data.network

import com.ryu.vx.data.model.AppUpdateResponse
import com.ryu.vx.data.model.CosmeticItem
import com.ryu.vx.data.model.HeroEntry
import com.ryu.vx.data.model.NewlyAddedSkin
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.json.Json
import okhttp3.OkHttpClient
import okhttp3.Request
import java.util.concurrent.TimeUnit

/**
 * Loads and decrypts the remote data hosted on the Cloudflare Pages origin.
 * Every payload is AES-256-CBC encrypted base64 (see [AesCrypto]).
 */
object LuminaApi {

    private const val BASE_URL = "https://luminadata-v2.pages.dev"

    private const val HEROES = "/heroes-bytes.txt"
    private const val NEWLY_ADDED = "/newly-added-skin-bytes.txt"
    private const val UPDATE = "/update-ryumoto-bytes.txt"
    private const val EMOTE = "/emote-bytes.txt"
    private const val TRAIL = "/trail-bytes.txt"
    private const val RECALL = "/recall-bytes.txt"
    private const val ELIMINATION = "/elimination-bytes.txt"
    private const val RESPAWN = "/luminadarespawn-bytes.txt"

    private val json = Json {
        ignoreUnknownKeys = true
        coerceInputValues = true
    }

    private val client = OkHttpClient.Builder()
        .connectTimeout(30, TimeUnit.SECONDS)
        .readTimeout(60, TimeUnit.SECONDS)
        .build()

    private suspend fun fetchRaw(endpoint: String): String =
        withContext(Dispatchers.IO) {
            val request = Request.Builder().url(BASE_URL + endpoint).build()
            client.newCall(request).execute().use { response ->
                check(response.isSuccessful) { "HTTP ${response.code} for $endpoint" }
                response.body?.string().orEmpty()
            }
        }

    /** Downloads a payload and decrypts it if required. */
    private suspend fun fetchDecrypted(endpoint: String): String {
        val raw = fetchRaw(endpoint)
        return AesCrypto.decryptBase64(raw) ?: raw
    }

    suspend fun fetchHeroes(): List<HeroEntry> = withContext(Dispatchers.IO) {
        val text = fetchDecrypted(HEROES)
        json.decodeFromString<List<HeroEntry>>(text)
    }

    suspend fun fetchNewlyAdded(): List<NewlyAddedSkin> = withContext(Dispatchers.IO) {
        val text = fetchDecrypted(NEWLY_ADDED)
        json.decodeFromString<List<NewlyAddedSkin>>(text)
    }

    suspend fun fetchEmotes(): List<CosmeticItem> = fetchCosmetic(EMOTE)

    suspend fun fetchTrails(): List<CosmeticItem> = fetchCosmetic(TRAIL)

    suspend fun fetchRecalls(): List<CosmeticItem> = fetchCosmetic(RECALL)

    suspend fun fetchEliminations(): List<CosmeticItem> = fetchCosmetic(ELIMINATION)

    suspend fun fetchRespaws(): List<CosmeticItem> = fetchCosmetic(RESPAWN)

    private suspend fun fetchCosmetic(endpoint: String): List<CosmeticItem> =
        withContext(Dispatchers.IO) {
            val text = fetchDecrypted(endpoint)
            json.decodeFromString<List<CosmeticItem>>(text)
        }

    suspend fun fetchUpdateInfo(): AppUpdateResponse = withContext(Dispatchers.IO) {
        val text = fetchDecrypted(UPDATE)
        json.decodeFromString<AppUpdateResponse>(text)
    }
}
