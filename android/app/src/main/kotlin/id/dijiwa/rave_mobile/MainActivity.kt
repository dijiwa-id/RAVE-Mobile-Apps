package id.dijiwa.rave_mobile

import android.content.ActivityNotFoundException
import android.content.ClipData
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import androidx.core.content.FileProvider
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

// audio_service butuh activity ini agar mesin Flutter dipakai bersama layanan pemutaran latar belakang.
class MainActivity : AudioServiceActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "id.dijiwa.rave/share").setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "isInstalled" -> result.success(isInstalled(call.argument<String>("package") ?: ""))
                    "instagramStory" -> result.success(
                        instagramStory(
                            call.argument<ByteArray>("png") ?: ByteArray(0),
                            call.argument<String>("contentUrl"),
                            call.argument<String>("appId"),
                        )
                    )
                    else -> result.notImplemented()
                }
            } catch (e: Exception) {
                // Galat apa pun → Dart memakai cadangan share sheet sistem.
                result.success(false)
            }
        }
    }

    private fun isInstalled(pkg: String): Boolean {
        if (pkg.isEmpty()) return false
        return try {
            if (Build.VERSION.SDK_INT >= 33) packageManager.getPackageInfo(pkg, PackageManager.PackageInfoFlags.of(0))
            else @Suppress("DEPRECATION") packageManager.getPackageInfo(pkg, 0)
            true
        } catch (_: PackageManager.NameNotFoundException) {
            false
        }
    }

    /**
     * Kartu cerita → Instagram Stories. Berkas ditulis ke cache/share (FileProvider `RaveShareProvider`), lalu:
     * 1) Dengan Facebook App ID: intent resmi `com.instagram.share.ADD_TO_STORY` (gambar latar + `content_url`).
     * 2) Tanpa App ID (Instagram menolak ADD_TO_STORY tanpa ID sejak 2023): ACTION_SEND langsung ke aktivitas
     *    "Story" milik Instagram (target "Cerita" di share sheet sistem).
     * Mengembalikan false bila Instagram tidak ada / tidak ada aktivitas yang cocok → Dart memakai share sheet.
     */
    private fun instagramStory(png: ByteArray, contentUrl: String?, appId: String?): Boolean {
        if (png.isEmpty() || !isInstalled(IG)) return false
        val dir = File(cacheDir, "share").apply { mkdirs() }
        // Bersihkan kartu lama (>1 jam) agar cache tidak menumpuk.
        dir.listFiles()?.filter { System.currentTimeMillis() - it.lastModified() > 3_600_000 }?.forEach { it.delete() }
        val file = File(dir, "rave-story-${System.currentTimeMillis()}.png").apply { writeBytes(png) }
        val uri: Uri = FileProvider.getUriForFile(this, "$packageName.rave_share", file)
        grantUriPermission(IG, uri, Intent.FLAG_GRANT_READ_URI_PERMISSION)

        if (!appId.isNullOrBlank()) {
            val story = Intent("com.instagram.share.ADD_TO_STORY").apply {
                setDataAndType(uri, "image/png")
                setPackage(IG)
                putExtra("source_application", appId)
                if (!contentUrl.isNullOrBlank()) putExtra("content_url", contentUrl)
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            if (launch(story)) return true
        }

        val send = Intent(Intent.ACTION_SEND).apply {
            type = "image/png"
            putExtra(Intent.EXTRA_STREAM, uri)
            clipData = ClipData.newRawUri("", uri)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        val target = queryActivities(send).firstOrNull { it.first == IG && it.second.contains("Story", ignoreCase = true) && !it.second.contains("Custom", ignoreCase = true) }
            ?: return false
        send.setClassName(target.first, target.second)
        return launch(send)
    }

    private fun queryActivities(intent: Intent): List<Pair<String, String>> {
        val list = if (Build.VERSION.SDK_INT >= 33) packageManager.queryIntentActivities(intent, PackageManager.ResolveInfoFlags.of(0))
        else @Suppress("DEPRECATION") packageManager.queryIntentActivities(intent, 0)
        return list.mapNotNull { r -> r.activityInfo?.let { it.packageName to it.name } }
    }

    private fun launch(intent: Intent): Boolean = try {
        startActivity(intent)
        true
    } catch (_: ActivityNotFoundException) {
        false
    } catch (_: SecurityException) {
        false
    }

    companion object {
        private const val IG = "com.instagram.android"
    }
}
