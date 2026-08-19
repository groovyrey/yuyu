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
import java.security.MessageDigest
import java.util.concurrent.TimeUnit
import java.util.zip.ZipEntry
import java.util.zip.ZipInputStream
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
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
    suspend fun sha256Files(paths: List<File>): List<String?>
}

class DirectStrategy : ExtractionStrategy {
    override suspend fun unzip(source: File, target: File) = withContext(Dispatchers.IO) {
        target.mkdirs()
        ZipInputStream(FileInputStream(source)).use { zis ->
            var entry: ZipEntry? = zis.nextEntry
            while (entry != null) {
                if (!entry.isDirectory) {
                    val canonicalTarget = target.canonicalPath
                    val outFile = File(target, entry.name).canonicalFile
                    if (!outFile.path.startsWith(canonicalTarget)) {
                        throw SecurityException(
                            "Zip entry '${entry.name}' attempts path traversal"
                        )
                    }
                    outFile.parentFile?.mkdirs()
                    FileOutputStream(outFile).use { out -> zis.copyTo(out) }
                } else {
                    val dir = File(target, entry.name)
                    dir.mkdirs()
                }
                zis.closeEntry()
                entry = zis.nextEntry
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
        if (dest.exists() && dest.length() > 0) return@withContext true
        runCatching {
            val request = Request.Builder().url(url).build()
            client.newCall(request).execute().use { response ->
                check(response.isSuccessful) { "HTTP ${response.code}" }

                val body = response.body
                    ?: throw IllegalStateException("Response body is null")

                val contentLength = body.contentLength()
                dest.parentFile?.mkdirs()
                val tmpFile = File(dest.parent, "${dest.name}.tmp")

                try {
                    FileOutputStream(tmpFile).use { output ->
                        body.byteStream().use { input ->
                            input.copyTo(output)
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

    suspend fun sha256Files(paths: List<File>): List<String?> =
        strategy().sha256Files(paths)

    fun hashZipEntries(zip: File): List<Pair<String, String>> {
        if (!zip.isFile) return emptyList()
        val digest = MessageDigest.getInstance("SHA-256")
        val result = mutableListOf<Pair<String, String>>()
        runCatching {
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
                        result.add(entry.name to digest.digest().joinToString("") { "%02x".format(it) })
                    }
                    zis.closeEntry()
                    entry = zis.nextEntry
                }
            }
        }
        return result
    }

    suspend fun clearRepairMarkers(game: GameTarget) {
        val configDir = game.dataDir.parentFile ?: game.dataDir
        listOf(
            File(game.assetsDir.parentFile ?: game.dataDir, "config.ini"),
            File(configDir, "dragon2017/config.ini"),
            File(game.dataDir, "config.ini")
        ).forEach { marker ->
            if (marker.exists()) runCatching { strategy().deleteFolder(marker) }
        }
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
