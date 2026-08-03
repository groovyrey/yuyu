package com.ryu.vx.engine

import com.ryu.vx.data.model.Favorite
import com.ryu.vx.data.model.InjectedFile
import com.ryu.vx.data.model.InjectedSkin
import com.ryu.vx.data.store.HistoryStore
import com.ryu.vx.data.store.FavoritesStore
import com.ryu.vx.data.model.History
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.json.Json
import kotlinx.serialization.decodeFromString
import kotlinx.serialization.encodeToString
import okhttp3.OkHttpClient
import okhttp3.Request
import java.io.File
import java.io.FileInputStream
import java.io.FileOutputStream
import java.security.MessageDigest
import java.util.concurrent.TimeUnit
import java.util.zip.ZipEntry
import java.util.zip.ZipInputStream

/**
 * A target MLBB installation detected on the device.
 */
data class GameTarget(
    val packageName: String,
    val assetsDir: File,
    val dataDir: File
)

/**
 * Filesystem operation used to reach the game assets folder.
 * [Direct] works on Android 10 and below (legacy external storage) and whenever
 * the app process can already reach the folder; [Shizuku] is required on newer
 * Android versions where /Android/data of other apps is sandboxed.
 */
sealed interface ExtractionStrategy {
    suspend fun unzip(source: File, target: File)
    suspend fun deleteFolder(path: File)
    /** SHA-256 hex of each file, or null when missing/unreadable. */
    suspend fun sha256Files(paths: List<File>): List<String?>
}

class DirectStrategy : ExtractionStrategy {
    override suspend fun unzip(source: File, target: File) {
        withContext(Dispatchers.IO) {
            target.mkdirs()
            ZipInputStream(FileInputStream(source)).use { zis ->
                var entry: ZipEntry? = zis.nextEntry
                while (entry != null) {
                    val outFile = File(target, entry.name)
                    if (entry.isDirectory) {
                        outFile.mkdirs()
                    } else {
                        outFile.parentFile?.mkdirs()
                        FileOutputStream(outFile).use { out -> zis.copyTo(out) }
                    }
                    zis.closeEntry()
                    entry = zis.nextEntry
                }
            }
        }
    }

    override suspend fun deleteFolder(path: File) {
        withContext(Dispatchers.IO) { path.deleteRecursively() }
    }

    override suspend fun sha256Files(paths: List<File>): List<String?> =
        withContext(Dispatchers.IO) {
            val digest = MessageDigest.getInstance("SHA-256")
            paths.map { path ->
                runCatching {
                    if (!path.isFile) return@runCatching null
                    digest.reset()
                    FileInputStream(path).use { input ->
                        val buffer = ByteArray(DEFAULT_BUFFER_SIZE)
                        var read = input.read(buffer)
                        while (read > 0) {
                            digest.update(buffer, 0, read)
                            read = input.read(buffer)
                        }
                    }
                    digest.digest().joinToString("") { "%02x".format(it) }
                }.getOrNull()
            }
        }
}

class ShizukuStrategy(
    private val awaitService: suspend () -> com.ryu.vx.shizuku.IUnzipService
) : ExtractionStrategy {

    override suspend fun unzip(source: File, target: File) {
        val service = awaitService()
        val done = kotlinx.coroutines.CompletableDeferred<Result<Unit>>()
        val callback = object : com.ryu.vx.shizuku.IUnzipCallback.Stub() {
            override fun onProgress(progress: Int, currentFile: String?) {}
            override fun onComplete() { done.complete(Result.success(Unit)) }
            override fun onError(message: String?) {
                done.complete(Result.failure(IllegalStateException(message ?: "unzip failed")))
            }
        }
        service.unzip(source.absolutePath, target.absolutePath, callback)
        done.await().getOrThrow()
    }

    override suspend fun deleteFolder(path: File) {
        awaitService().deleteFolder(path.absolutePath)
    }

    override suspend fun sha256Files(paths: List<File>): List<String?> {
        val service = awaitService()
        val result = service.sha256Files(paths.map { it.absolutePath }.toTypedArray())
        return result?.toList() ?: List(paths.size) { null }
    }
}

/**
 * Core injection logic: downloads skin packs, extracts them into the MLBB
 * asset folder, keeps a backup manifest, and runs the advanced restore
 * algorithm (offline restore by triggering the game's asset repair).
 */
class InjectEngine(
    private val context: android.content.Context,
    private val favoritesStore: FavoritesStore,
    private val historyStore: HistoryStore,
    private val strategy: ExtractionStrategy
) {

    private val client = OkHttpClient.Builder()
        .connectTimeout(30, TimeUnit.SECONDS)
        .readTimeout(120, TimeUnit.SECONDS)
        .build()

    /** All MLBB package variants that this tool supports. */
    private val supportedPackages = listOf(
        "com.mobile.legends", "com.vng.mlbbvn", "com.mobilelegends.hwag",
        "com.mobilelegends.mi", "com.hhgame.mlbbvn", "com.mobile.legends.usa",
        "com.mobile.legends.lite", "com.mobile.legends.beta", "com.moonton.mlbb.cn",
        "com.mobile.Legends.am", "com.mobile.legends.ft", "com.mobile.legends.bil",
        "com.mobiin.gp"
    )

    private fun cacheDir(): File =
        File(context.getExternalFilesDir(null), "skin_cache").apply { mkdirs() }

    private fun backupManifest(): File = File(context.filesDir, "injected.json")

    /** Detects an installed MLBB variant, or returns null. */
    fun findGame(): GameTarget? {
        val pm = context.packageManager
        for (pkg in supportedPackages) {
            val info = runCatching { pm.getApplicationInfo(pkg, 0) }.getOrNull() ?: continue
            val assets = File(
                "/storage/emulated/0/Android/data/$pkg/files/dragon2017/assets"
            )
            val data = File(info.dataDir, "files/dragon2017/assets")
            return GameTarget(pkg, assets, data)
        }
        return null
    }

    /** Downloads a zip to the local cache. */
    suspend fun downloadZip(url: String, name: String): File = withContext(Dispatchers.IO) {
        val safe = name.replace(Regex("[^A-Za-z0-9._-]"), "_") + ".zip"
        val dest = File(cacheDir(), safe)
        if (dest.exists() && dest.length() > 0) return@withContext dest
        val request = Request.Builder().url(url).build()
        client.newCall(request).execute().use { response ->
            check(response.isSuccessful) { "HTTP ${response.code} downloading $url" }
            response.body?.byteStream()?.use { input ->
                FileOutputStream(dest).use { output -> input.copyTo(output) }
            }
        }
        dest
    }

    /**
     * Injects a single favorite: download, extract, record history and
     * update the backup manifest with the extracted file hashes.
     */
    suspend fun injectFavorite(favorite: Favorite): Result<Unit> = runCatching {
        require(favorite.skinSc.isNotBlank()) { "No download URL for ${favorite.skinName}" }
        val zip = downloadZip(favorite.skinSc, "${favorite.heroName}-${favorite.skinName}")
        val game = findGame() ?: error("Mobile Legends is not installed")
        strategy.unzip(zip, game.assetsDir)
        recordInjected(buildInjectedSkin(favorite, zip, game))
        historyStore.add(
            History(heroName = favorite.heroName, skinName = favorite.skinName)
        )
    }

    /**
     * Injects every favorite in order, reporting progress.
     * Returns (okCount, failedCount, failureDetails).
     */
    suspend fun injectAllFavorites(
        favorites: List<Favorite>,
        onProgress: (Int, String) -> Unit
    ): Result<Triple<Int, Int, String>> = runCatching {
        var done = 0
        val failures = mutableListOf<String>()
        for (favorite in favorites) {
            onProgress(done, "Injecting ${favorite.skinName}")
            runCatching { injectFavorite(favorite) }
                .onFailure { failures.add("${favorite.skinName}: ${it.message}") }
            done++
        }
        Triple(done, failures.size, failures.joinToString("\n"))
    }

    /**
     * Advanced restore algorithm (offline).
     *
     * For each favorite it restores the injected skin WITHOUT a fresh download:
     *  - re-applies the skin from the locally cached zip (so the mod stays), and
     *  - clears the game's repair/verification markers for the modified assets.
     *
     * Clearing the markers makes the game treat the modded files as "corrupted"
     * and silently rebuild/repair them on the next launch, which is how the
     * advanced algorithm recovers the original skins without backups.
     */
    suspend fun advancedRestoreAll(
        favorites: List<Favorite>,
        onProgress: (Int, String) -> Unit
    ): Result<Pair<Int, Int>> = runCatching {
        var done = 0
        val failures = mutableListOf<String>()
        for (favorite in favorites) {
            onProgress(done, "Restoring ${favorite.skinName}")
            runCatching { advancedRestoreFavorite(favorite) }
                .onFailure { failures.add("${favorite.skinName}: ${it.message}") }
            done++
        }
        done to failures.size
    }

    private suspend fun advancedRestoreFavorite(favorite: Favorite) {
        val game = findGame() ?: error("Mobile Legends is not installed")
        val cached = File(cacheDir(), safeName(favorite) + ".zip")

        // 1. Clear repair/verification markers so the game rechecks the assets.
        clearRepairMarkers(game)

        // 2. If we still have the mod cached locally, re-apply it so the skin
        //    remains injected; otherwise the game re-downloads the originals.
        if (cached.exists() && favorite.skinSc.isNotBlank()) {
            strategy.unzip(cached, game.assetsDir)
        }
        historyStore.add(
            History(heroName = favorite.heroName, skinName = favorite.skinName)
        )
    }

    /**
     * Checks which skins recorded in the injected manifest are still actually
     * present in the game assets. A skin counts as injected only when every
     * recorded file exists and its SHA-256 still matches what we wrote.
     *
     * Entries recorded by older versions carry no file hashes, so they are
     * backfilled from the locally cached skin zip on first run.
     *
     * Returns keys of the form "heroId:skinName".
     */
    suspend fun checkAllInjected(): Set<String> = withContext(Dispatchers.IO) {
        val game = findGame() ?: return@withContext emptySet()
        val manifest = loadManifest().toMutableList()
        var backfilled = false
        for ((index, entry) in manifest.withIndex()) {
            if (entry.files.isNotEmpty()) continue
            val rebuilt = backfillInjectedSkin(entry)
            if (rebuilt != null) {
                manifest[index] = rebuilt
                backfilled = true
            }
        }
        if (backfilled) {
            runCatching {
                backupManifest().writeText(Json.encodeToString<List<InjectedSkin>>(manifest))
            }
        }
        val result = mutableSetOf<String>()
        for (entry in manifest) {
            if (entry.files.isEmpty()) continue
            val files = entry.files.map { File(game.assetsDir, it.path) }
            val hashes = strategy.sha256Files(files)
            val allMatch = entry.files.zip(hashes).all { (recorded, current) ->
                !current.isNullOrBlank() && current.equals(recorded.sha256, ignoreCase = true)
            }
            if (allMatch) result.add("${entry.heroId}:${entry.skinName}")
        }
        result
    }

    /** Deletes files the game uses to fingerprint/verify modded assets. */
    private suspend fun clearRepairMarkers(game: GameTarget) {
        val configDir = game.dataDir.parentFile ?: game.dataDir
        listOf(
            File(game.assetsDir.parentFile ?: game.dataDir, "config.ini"),
            File(configDir, "dragon2017/config.ini"),
            File(game.dataDir, "config.ini")
        ).forEach { marker ->
            if (marker.exists()) runCatching { strategy.deleteFolder(marker) }
        }
    }

    /** Enumerates the non-directory entries of a downloaded skin pack. */
    private fun zipEntryNames(zip: File): List<String> = runCatching {
        val names = mutableListOf<String>()
        ZipInputStream(FileInputStream(zip)).use { zis ->
            var entry: ZipEntry? = zis.nextEntry
            while (entry != null) {
                if (!entry.isDirectory) names.add(entry.name)
                zis.closeEntry()
                entry = zis.nextEntry
            }
        }
        names
    }.getOrDefault(emptyList())

    /**
     * Rebuilds the file manifest of an old-format [InjectedSkin] from the
     * locally cached skin zip. The expected hashes are computed from the zip's
     * own bytes (what was originally deployed), not from the current game files,
     * so the injected check stays truthful.
     */
    private fun backfillInjectedSkin(entry: InjectedSkin): InjectedSkin? {
        val zip = File(cacheDir(), safeName(Favorite(heroName = entry.heroName, skinName = entry.skinName)) + ".zip")
        if (!zip.isFile) return null
        val files = zipEntryHashes(zip)
        if (files.isEmpty()) return null
        return entry.copy(files = files)
    }

    private fun zipEntryHashes(zip: File): List<InjectedFile> = runCatching {
        val digest = MessageDigest.getInstance("SHA-256")
        val files = mutableListOf<InjectedFile>()
        ZipInputStream(FileInputStream(zip)).use { zis ->
            var entry: ZipEntry? = zis.nextEntry
            while (entry != null) {
                if (!entry.isDirectory) {
                    digest.reset()
                    val buffer = ByteArray(DEFAULT_BUFFER_SIZE)
                    var read = zis.read(buffer)
                    while (read > 0) {
                        digest.update(buffer, 0, read)
                        read = zis.read(buffer)
                    }
                    files.add(
                        InjectedFile(
                            path = entry.name,
                            sha256 = digest.digest().joinToString("") { "%02x".format(it) }
                        )
                    )
                }
                zis.closeEntry()
                entry = zis.nextEntry
            }
        }
        files
    }.getOrDefault(emptyList())

    /** Builds an [InjectedSkin] with the deployed file hashes for the checker. */
    private suspend fun buildInjectedSkin(
        favorite: Favorite,
        zip: File,
        game: GameTarget
    ): InjectedSkin {
        val names = zipEntryNames(zip)
        if (names.isEmpty()) {
            return InjectedSkin(
                heroName = favorite.heroName,
                heroId = favorite.heroId,
                skinName = favorite.skinName,
                skinImage = favorite.skinImage,
                skinSc = favorite.skinSc
            )
        }
        val hashes = strategy.sha256Files(names.map { File(game.assetsDir, it) })
        val files = names.zip(hashes).mapNotNull { (name, hash) ->
            if (hash.isNullOrBlank()) null else InjectedFile(path = name, sha256 = hash)
        }
        return InjectedSkin(
            heroName = favorite.heroName,
            heroId = favorite.heroId,
            skinName = favorite.skinName,
            skinImage = favorite.skinImage,
            skinSc = favorite.skinSc,
            files = files
        )
    }

    private fun loadManifest(): List<InjectedSkin> = runCatching {
        Json.decodeFromString<List<InjectedSkin>>(backupManifest().readText())
    }.getOrDefault(emptyList())

    private fun recordInjected(injected: InjectedSkin) {
        val manifest = loadManifest()
        val updated = manifest.filterNot {
            it.heroId == injected.heroId && it.skinName == injected.skinName
        } + injected
        runCatching {
            backupManifest().writeText(
                Json.encodeToString<List<InjectedSkin>>(updated)
            )
        }
    }

    private fun safeName(favorite: Favorite) =
        "${favorite.heroName}-${favorite.skinName}".replace(Regex("[^A-Za-z0-9._-]"), "_")
}
