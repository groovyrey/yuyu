package com.yuyu.dev.engine

import android.content.Context
import android.os.Build
import android.os.Environment
import android.os.Process
import android.provider.Settings
import com.yuyu.dev.shizuku.IUnzipService
import com.yuyu.dev.shizuku.ShizukuManager
import java.io.File
import java.io.FileInputStream
import java.io.FileOutputStream
import java.util.concurrent.TimeUnit
import java.util.zip.ZipFile
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.coroutines.withTimeoutOrNull
import okhttp3.OkHttpClient
import okhttp3.Request

data class GameTarget(
    val packageName: String,
    val assetsDir: File,
    val dataDir: File
)

sealed interface ExtractionStrategy {
    suspend fun unzip(source: File, target: File)
    suspend fun deleteFolder(path: File)
    suspend fun deleteFiles(paths: List<File>)
}

class DirectStrategy : ExtractionStrategy {
    override suspend fun unzip(source: File, target: File) = withContext(Dispatchers.IO) {
        if (!source.isFile || source.length() <= 0L) {
            throw IllegalStateException("Source file not found or empty")
        }
        target.mkdirs()
        val canonicalTarget = target.canonicalPath
        val maxEntries = 10_000
        val maxTotalUncompressed = 512L * 1024 * 1024 // 512 MB
        var entries = 0
        var totalUncompressed = 0L
        // ZipFile reads the central directory first, so a truncated or
        // incomplete archive fails here instead of extracting a partial set.
        ZipFile(source).use { zf ->
            val archiveEntries = zf.entries()
            while (archiveEntries.hasMoreElements()) {
                val entry = archiveEntries.nextElement()
                entries++
                if (entries > maxEntries) {
                    throw SecurityException("Too many zip entries")
                }
                val entryName = entry.name
                if (entryName.contains("..") || entryName.startsWith("/") ||
                    entryName.startsWith("\\") || File(entryName).isAbsolute
                ) {
                    throw SecurityException("Illegal zip entry: $entryName")
                }
                val outFile = File(target, entryName).canonicalFile
                if (!outFile.path.startsWith(canonicalTarget + File.separator) &&
                    outFile.path != canonicalTarget
                ) {
                    throw SecurityException("Zip entry '$entryName' attempts path traversal")
                }
                if (entry.isDirectory) {
                    outFile.mkdirs()
                    continue
                }
                outFile.parentFile?.mkdirs()
                var written = 0L
                zf.getInputStream(entry).use { input ->
                    FileOutputStream(outFile).use { out ->
                        val buffer = ByteArray(DEFAULT_BUFFER_SIZE)
                        var read = input.read(buffer)
                        while (read > 0) {
                            totalUncompressed += read
                            if (totalUncompressed > maxTotalUncompressed) {
                                throw SecurityException("Zip exceeds maximum uncompressed size")
                            }
                            out.write(buffer, 0, read)
                            written += read
                            read = input.read(buffer)
                        }
                    }
                }
                if (entry.size >= 0L && written != entry.size) {
                    throw IllegalStateException(
                        "Incomplete entry '$entryName': expected ${entry.size} bytes, wrote $written"
                    )
                }
            }
        }
    }

    override suspend fun deleteFolder(path: File) {
        withContext(Dispatchers.IO) { path.deleteRecursively() }
    }

    override suspend fun deleteFiles(paths: List<File>) {
        withContext(Dispatchers.IO) {
            paths.forEach { path -> runCatching { if (path.exists()) path.delete() } }
        }
    }
}

class ShizukuStrategy(
    private val awaitService: suspend () -> IUnzipService
) : ExtractionStrategy {

    override suspend fun unzip(source: File, target: File) {
        val service = awaitService()
        val done = CompletableDeferred<Result<Unit>>()
        val callback = object : com.yuyu.dev.shizuku.IUnzipCallback.Stub() {
            override fun onProgress(progress: Int, currentFile: String?) {}
            override fun onComplete() { done.complete(Result.success(Unit)) }
            override fun onError(message: String?) {
                done.complete(Result.failure(IllegalStateException(message ?: "unzip failed")))
            }
        }
        service.unzip(source.absolutePath, target.absolutePath, callback)
        val result = withTimeoutOrNull(300_000L) {
            done.await()
        } ?: throw IllegalStateException("Shizuku unzip timed out")
        result.getOrThrow()
    }

    override suspend fun deleteFolder(path: File) {
        withTimeoutOrNull(60_000L) {
            awaitService().deleteFolder(path.absolutePath)
        } ?: throw IllegalStateException("Shizuku delete timed out")
    }

    override suspend fun deleteFiles(paths: List<File>) {
        withTimeoutOrNull(60_000L) {
            val service = awaitService()
            paths.forEach { path -> runCatching { service.deleteFolder(path.absolutePath) } }
        } ?: throw IllegalStateException("Shizuku delete timed out")
    }
}

object YuyuEngine {

    private val supportedPackages = listOf(
        "com.mobile.legends", "com.vng.mlbbvn", "com.mobilelegends.hwag",
        "com.mobilelegends.mi", "com.hhgame.mlbbvn", "com.mobile.legends.usa",
        "com.mobile.legends.lite", "com.mobile.legends.beta", "com.moonton.mlbb.cn",
        "com.mobile.Legends.am", "com.mobile.legends.ft", "com.mobile.legends.bil",
        "com.mobiin.gp"
    )

    @Volatile
    private var appContext: Context? = null

    private val client = OkHttpClient.Builder()
        .connectTimeout(30, TimeUnit.SECONDS)
        .readTimeout(120, TimeUnit.SECONDS)
        .build()

    fun init(context: Context) {
        appContext = context.applicationContext
        ShizukuManager.init(context)
    }

    private fun strategy(): ExtractionStrategy =
        if (ShizukuManager.service != null) {
            ShizukuStrategy { ShizukuManager.awaitService() }
        } else {
            DirectStrategy()
        }

    fun findGame(): GameTarget? {
        val ctx = appContext ?: return null
        val pm = ctx.packageManager
        for (pkg in supportedPackages) {
            val info = runCatching { pm.getApplicationInfo(pkg, 0) }.getOrNull() ?: continue
            val assets = File("/storage/emulated/0/Android/data/$pkg/files/dragon2017/assets")
            val data = File(info.dataDir, "files/dragon2017/assets")
            return GameTarget(pkg, assets, data)
        }
        return null
    }

    suspend fun downloadFile(url: String, dest: File): Boolean = withContext(Dispatchers.IO) {
        if (dest.exists() && dest.length() > 0) {
            // Validate zip signature if it looks like a zip
            if (runCatching {
                    FileInputStream(dest).use { fis ->
                        val sig = ByteArray(4)
                        if (fis.read(sig) != 4) return@runCatching false
                        sig[0] == 0x50.toByte() && sig[1] == 0x4B.toByte()
                    }
                }.getOrDefault(false)) {
                return@withContext true
            } else if (dest.length() > 0) {
                // Try to re-download if invalid
            }
        }
        runCatching {
            val request = Request.Builder().url(url).build()
            client.newCall(request).execute().use { response ->
                check(response.isSuccessful) { "HTTP ${response.code}" }

                val body = response.body
                    ?: throw IllegalStateException("Response body is null")

                val contentLength = body.contentLength()
                if (contentLength > 0 && contentLength > 200L * 1024 * 1024) {
                    throw IllegalStateException("File too large")
                }
                dest.parentFile?.mkdirs()
                val tmpFile = File(dest.parent, "${dest.name}.tmp")

                try {
                    FileOutputStream(tmpFile).use { output ->
                        body.byteStream().use { input ->
                            val buffer = ByteArray(DEFAULT_BUFFER_SIZE)
                            var total: Long = 0
                            var read = input.read(buffer)
                            while (read > 0) {
                                total += read
                                if (total > 200L * 1024 * 1024) {
                                    throw IllegalStateException("File too large")
                                }
                                output.write(buffer, 0, read)
                                read = input.read(buffer)
                            }
                        }
                    }
                    if (contentLength > 0 && tmpFile.length() != contentLength) {
                        tmpFile.delete()
                        throw IllegalStateException(
                            "Incomplete download: expected $contentLength bytes, got ${tmpFile.length()}"
                        )
                    }
                    if (tmpFile.length() == 0L) {
                        tmpFile.delete()
                        throw IllegalStateException("Downloaded file is empty")
                    }
                    // Validate zip signature
                    val validZip = FileInputStream(tmpFile).use { fis ->
                        val sig = ByteArray(4)
                        if (fis.read(sig) != 4) return@use false
                        sig[0] == 0x50.toByte() && sig[1] == 0x4B.toByte()
                    }
                    if (!validZip) {
                        tmpFile.delete()
                        throw IllegalStateException("Downloaded file is not a valid zip")
                    }
                    if (dest.exists()) dest.delete()
                    tmpFile.renameTo(dest)
                } catch (e: Exception) {
                    tmpFile.delete()
                    throw e
                }
            }
        }.isSuccess
    }

    suspend fun unzip(source: File, target: File) =
        strategy().unzip(source, target)

    suspend fun deleteFolder(path: File) =
        strategy().deleteFolder(path)

    suspend fun deleteFiles(paths: List<File>) =
        strategy().deleteFiles(paths)

    fun listZipEntries(zip: File): List<Pair<String, Long>> {
        if (!zip.isFile || zip.length() <= 0L) return emptyList()
        return runCatching {
            ZipFile(zip).use { zf ->
                val result = mutableListOf<Pair<String, Long>>()
                val entries = zf.entries()
                var count = 0
                while (entries.hasMoreElements()) {
                    val entry = entries.nextElement()
                    count++
                    if (count > 10_000) break
                    if (entry.isDirectory) continue
                    result.add(entry.name to entry.size)
                }
                result
            }
        }.getOrDefault(emptyList())
    }

    suspend fun clearRepairMarkers(game: GameTarget) {
        val configDir = game.dataDir.parentFile ?: game.dataDir
        val markers = listOf(
            File(game.assetsDir.parentFile ?: game.dataDir, "config.ini"),
            File(configDir, "dragon2017/config.ini"),
            File(game.dataDir, "config.ini")
        ).filter { it.exists() }
        if (markers.isNotEmpty()) runCatching { strategy().deleteFiles(markers) }
    }

    fun storageGranted(): Boolean {
        val ctx = appContext ?: return false
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            Environment.isExternalStorageManager()
        } else {
            ctx.checkSelfPermission(android.Manifest.permission.WRITE_EXTERNAL_STORAGE) ==
                android.content.pm.PackageManager.PERMISSION_GRANTED
        }
    }

    fun openStorageSettings() {
        val ctx = appContext ?: return

        val directIntent = android.content.Intent(
            Settings.ACTION_MANAGE_APP_ALL_FILES_ACCESS_PERMISSION
        )
            .setData(android.net.Uri.parse("package:${ctx.packageName}"))
            .addFlags(android.content.Intent.FLAG_ACTIVITY_NEW_TASK)

        val listIntent = android.content.Intent(
            Settings.ACTION_MANAGE_ALL_FILES_ACCESS_PERMISSION
        ).addFlags(android.content.Intent.FLAG_ACTIVITY_NEW_TASK)

        val appInfoIntent = android.content.Intent(
            Settings.ACTION_APPLICATION_DETAILS_SETTINGS
        )
            .setData(android.net.Uri.parse("package:${ctx.packageName}"))
            .addFlags(android.content.Intent.FLAG_ACTIVITY_NEW_TASK)

        val pm = ctx.packageManager
        when {
            directIntent.resolveActivity(pm) != null ->
                runCatching { ctx.startActivity(directIntent) }
                    .onFailure { runCatching { ctx.startActivity(listIntent) }
                        .onFailure { ctx.startActivity(appInfoIntent) } }
            listIntent.resolveActivity(pm) != null ->
                runCatching { ctx.startActivity(listIntent) }
                    .onFailure { ctx.startActivity(appInfoIntent) }
            else ->
                runCatching { ctx.startActivity(appInfoIntent) }
        }
    }
}
