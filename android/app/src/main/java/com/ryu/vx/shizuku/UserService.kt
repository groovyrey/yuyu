package com.ryu.vx.shizuku

import android.app.Service
import android.content.Intent
import android.os.IBinder
import android.os.Process
import java.io.File
import java.io.FileInputStream
import java.io.FileOutputStream
import java.security.MessageDigest
import java.util.zip.ZipEntry
import java.util.zip.ZipInputStream

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

            val total = srcFile.length()
            var processed = 0L

            try {
                ZipInputStream(FileInputStream(srcFile)).use { zis ->
                    var entry: ZipEntry? = zis.nextEntry
                    while (entry != null) {
                        val current = entry
                        val outFile = File(targetDir, current.name)
                        if (current.isDirectory) {
                            outFile.mkdirs()
                        } else {
                            outFile.parentFile?.mkdirs()
                            FileOutputStream(outFile).use { out ->
                                val entryName = current.name
                                val buffer = ByteArray(DEFAULT_BUFFER_SIZE)
                                var read = zis.read(buffer)
                                while (read > 0) {
                                    out.write(buffer, 0, read)
                                    processed += read
                                    if (total > 0) {
                                        val percent = ((processed * 100L) / total).toInt()
                                        callback?.onProgress(percent, entryName)
                                    }
                                    read = zis.read(buffer)
                                }
                            }
                        }
                        zis.closeEntry()
                        entry = zis.nextEntry
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

        override fun sha256Files(paths: Array<out String>?): Array<String?>? {
            if (paths == null) return null
            val digest = MessageDigest.getInstance("SHA-256")
            return paths.map { path ->
                runCatching {
                    val file = File(path)
                    if (!file.isFile) return@runCatching null
                    digest.reset()
                    FileInputStream(file).use { input ->
                        val buffer = ByteArray(DEFAULT_BUFFER_SIZE)
                        var read = input.read(buffer)
                        while (read > 0) {
                            digest.update(buffer, 0, read)
                            read = input.read(buffer)
                        }
                    }
                    digest.digest().joinToString("") { "%02x".format(it) }
                }.getOrNull()
            }.toTypedArray()
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
