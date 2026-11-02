package com.yuyu.dev.shizuku

import android.app.Service
import android.content.Intent
import android.os.IBinder
import android.os.Process
import java.io.File
import java.io.FileOutputStream
import java.util.zip.ZipFile

/**
 * Runs inside the Shizuku (or root) server process with elevated privileges,
 * allowing the app to unzip into and delete from directories owned by other
 * apps (the MLBB data folder) that the normal app process cannot reach.
 */
class UserService : Service() {

    private val binder = object : IUnzipService.Stub() {

        override fun unzip(source: String, target: String, callback: IUnzipCallback?) {
            val srcFile = File(source)
            val targetDir = File(target)

            if (!srcFile.exists() || srcFile.length() <= 0L) {
                callback?.onError("Source file not found or empty")
                return
            }
            if (!targetDir.exists()) targetDir.mkdirs()
            if (!targetDir.isDirectory) {
                callback?.onError("Target is not a directory")
                return
            }

            val canonicalTarget = runCatching { targetDir.canonicalPath }.getOrNull() ?: targetDir.absolutePath
            val maxEntries = 10_000
            val maxTotalUncompressed = 512L * 1024 * 1024

            try {
                // ZipFile reads the central directory first, so a truncated or
                // incomplete archive fails here instead of extracting a partial set.
                ZipFile(srcFile).use { zf ->
                    val archiveEntries = zf.entries()
                    val totalEntries = zf.size().coerceAtLeast(1)
                    var index = 0
                    var totalUncompressed = 0L
                    while (archiveEntries.hasMoreElements()) {
                        val entry = archiveEntries.nextElement()
                        index++
                        if (index > maxEntries) {
                            throw SecurityException("Too many zip entries")
                        }
                        val entryName = entry.name
                        // Prevent zip slip / path traversal
                        if (entryName.contains("..") || entryName.startsWith("/") || entryName.startsWith("\\") || File(entryName).isAbsolute) {
                            throw SecurityException("Illegal zip entry: $entryName")
                        }
                        val outFile = File(targetDir, entryName).canonicalFile
                        if (!outFile.path.startsWith(canonicalTarget + File.separator) && outFile.path != canonicalTarget) {
                            throw SecurityException("Zip entry '$entryName' attempts path traversal")
                        }
                        if (entry.isDirectory) {
                            outFile.mkdirs()
                        } else {
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
                        val percent = ((index * 100L) / totalEntries).toInt().coerceIn(0, 100)
                        callback?.onProgress(percent, entryName)
                    }
                }
                callback?.onComplete()
            } catch (e: Exception) {
                callback?.onError(e.message ?: "Unknown error")
            }
        }

        override fun deleteFolder(path: String): Boolean {
            return runCatching {
                deleteRecursively(File(path))
            }.getOrDefault(false)
        }

        override fun destroy() {
            Process.killProcess(Process.myPid())
        }
    }

    override fun onBind(intent: Intent): IBinder = binder

    private fun deleteRecursively(file: File): Boolean {
        if (file.isDirectory) {
            file.listFiles()?.forEach { deleteRecursively(it) }
        }
        return file.delete()
    }
}
