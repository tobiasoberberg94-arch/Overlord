package de.overlord.tv

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import org.json.JSONObject
import java.io.File
import java.net.HttpURLConnection
import java.net.URL

/**
 * Selbst-Update über das GitHub-Release „latest“: prüft version.json und lädt bei Bedarf
 * die neue APK herunter, die dann über den System-Installer eingespielt wird.
 */
object Updater {
    class Info(val code: Int, val name: String, val notes: String)

    @Volatile
    var available: Info? = null
        private set

    @Volatile
    var lastCheck = 0L
        private set

    private fun open(url: String): HttpURLConnection {
        var u = URL(url)
        var hops = 0
        while (true) {
            val c = u.openConnection() as HttpURLConnection
            c.instanceFollowRedirects = false
            c.connectTimeout = 10_000
            c.readTimeout = 20_000
            c.setRequestProperty("User-Agent", "OverlordTV/${BuildConfig.VERSION_NAME}")
            val code = c.responseCode
            if (code in 300..399 && hops < 6) {
                u = URL(u, c.getHeaderField("Location") ?: return c)
                c.disconnect()
                hops++
                continue
            }
            return c
        }
    }

    /** Blockierend (Hintergrund-Thread): liefert eine neuere Version oder null. */
    fun check(): Info? {
        lastCheck = System.currentTimeMillis()
        return try {
            val c = open(BuildConfig.UPDATE_BASE + "version.json")
            if (c.responseCode != 200) return null
            val o = JSONObject(c.inputStream.bufferedReader().use { it.readText() })
            val info = Info(o.optInt("versionCode"), o.optString("versionName"), o.optString("notes"))
            (if (info.code > BuildConfig.VERSION_CODE) info else null).also { available = it }
        } catch (e: Exception) {
            null
        }
    }

    /** Blockierend: lädt die APK herunter; [progress] bekommt 0–100. */
    fun download(activity: Activity, progress: (Int) -> Unit): File? = try {
        val dir = (activity.getExternalFilesDir("updates") ?: File(activity.cacheDir, "updates")).apply { mkdirs() }
        dir.listFiles()?.forEach { it.delete() }
        val file = File(dir, "overlord-tv.apk")
        val c = open(BuildConfig.UPDATE_BASE + "overlord-tv.apk")
        if (c.responseCode != 200) null else {
            val total = c.contentLength.toLong()
            var done = 0L
            var last = -1
            c.inputStream.use { input ->
                file.outputStream().use { out ->
                    val buf = ByteArray(64 * 1024)
                    while (true) {
                        val n = input.read(buf)
                        if (n < 0) break
                        out.write(buf, 0, n)
                        done += n
                        if (total > 0) {
                            val p = (done * 100 / total).toInt()
                            if (p != last) { last = p; progress(p) }
                        }
                    }
                }
            }
            file.setReadable(true, false)
            file
        }
    } catch (e: Exception) {
        null
    }

    /** System-Installer starten (fragt ggf. nach der Erlaubnis für „unbekannte Quellen“). */
    fun install(activity: Activity, file: File) {
        if (Build.VERSION.SDK_INT >= 26 && !activity.packageManager.canRequestPackageInstalls()) {
            activity.tvToast("Bitte „Apps aus unbekannten Quellen“ für Overlord TV erlauben und erneut versuchen", R.drawable.ic_shield)
            try {
                activity.startActivity(Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES, Uri.parse("package:" + activity.packageName)))
            } catch (e: Exception) { }
            return
        }
        val uri = if (Build.VERSION.SDK_INT >= 24) {
            androidx.core.content.FileProvider.getUriForFile(activity, activity.packageName + ".files", file)
        } else Uri.fromFile(file)
        val i = Intent(Intent.ACTION_VIEW)
            .setDataAndType(uri, "application/vnd.android.package-archive")
            .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_ACTIVITY_NEW_TASK)
        try {
            activity.startActivity(i)
        } catch (e: Exception) {
            activity.tvToast("Installer konnte nicht gestartet werden", R.drawable.ic_warning)
        }
    }

    /** Kompletter Ablauf mit Rückfrage und Fortschritt. */
    fun runInteractive(activity: Activity, info: Info) {
        Tv.confirm(activity, "Update auf ${info.name} installieren?",
            (if (info.notes.isNotBlank()) info.notes + "\n\n" else "") + "Die neue Version wird heruntergeladen und über den System-Installer eingespielt. Einstellungen und Kacheln bleiben erhalten.",
            "Installieren", icon = R.drawable.ic_refresh) {
            activity.tvToast("Lade Update …", R.drawable.ic_refresh)
            Thread {
                var lastShown = -10
                val file = download(activity) { p ->
                    if (p - lastShown >= 25) { lastShown = p; activity.runOnUiThread { activity.tvToast("Update: $p %", R.drawable.ic_refresh) } }
                }
                activity.runOnUiThread {
                    if (file == null) activity.tvToast("Download fehlgeschlagen", R.drawable.ic_warning) else install(activity, file)
                }
            }.start()
        }
    }
}
