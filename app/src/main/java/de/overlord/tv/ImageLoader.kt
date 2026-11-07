package de.overlord.tv

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.os.Handler
import android.os.Looper
import android.util.LruCache
import android.widget.ImageView
import java.io.File
import java.net.HttpURLConnection
import java.net.URL
import java.security.MessageDigest
import java.util.concurrent.Executors

/** Minimaler Bild-Lader (ohne Glide/Picasso): Speicher- und Disk-Cache, Hintergrund-Threads, Fallback-URLs. */
object ImageLoader {
    private val main = Handler(Looper.getMainLooper())
    private val pool = Executors.newFixedThreadPool(4)
    private val cache = object : LruCache<String, Bitmap>((Runtime.getRuntime().maxMemory() / 7).toInt()) {
        override fun sizeOf(key: String, value: Bitmap) = value.byteCount
    }
    private val failed = HashSet<String>()
    @Volatile
    private var diskDir: File? = null
    private const val DISK_MAX = 80L * 1024 * 1024
    private const val UA = "Mozilla/5.0 (Linux; Android 9; AFTMM) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36"

    fun init(ctx: Context) {
        val dir = File(ctx.cacheDir, "img").apply { mkdirs() }
        diskDir = dir
        pool.execute { trim(dir) }
    }

    fun load(view: ImageView, urls: List<String>, maxWidth: Int = 640, referer: String? = null, onLoaded: ((Bitmap) -> Unit)? = null) {
        val key = urls.joinToString("|") + "@" + maxWidth
        view.tag = key
        if (urls.isEmpty()) { view.setImageDrawable(null); return }
        cache.get(key)?.let { view.setImageBitmap(it); onLoaded?.invoke(it); return }
        view.setImageDrawable(null)
        pool.execute {
            var bmp: Bitmap? = null
            for (u in urls) {
                if (u.isBlank() || synchronized(failed) { failed.contains(u) }) continue
                bmp = fetch(u, maxWidth, referer)
                if (bmp != null) break
                synchronized(failed) { failed.add(u) }
            }
            val result = bmp ?: return@execute
            cache.put(key, result)
            main.post {
                if (view.tag == key) {
                    view.setImageBitmap(result)
                    onLoaded?.invoke(result)
                }
            }
        }
    }

    private fun md5(s: String): String =
        MessageDigest.getInstance("MD5").digest(s.toByteArray()).joinToString("") { "%02x".format(it) }

    private fun fetch(url: String, maxWidth: Int, referer: String? = null): Bitmap? = try {
        val file = diskDir?.let { File(it, md5(url)) }
        val bytes: ByteArray? = if (file != null && file.exists() && file.length() > 0) {
            file.setLastModified(System.currentTimeMillis())
            file.readBytes()
        } else {
            val conn = URL(url).openConnection() as HttpURLConnection
            conn.connectTimeout = 8000
            conn.readTimeout = 15000
            conn.setRequestProperty("User-Agent", UA)
            if (!referer.isNullOrBlank()) conn.setRequestProperty("Referer", referer)
            if (conn.responseCode != 200) null else conn.inputStream.use { it.readBytes() }.also { b ->
                try { file?.writeBytes(b) } catch (e: Exception) { }
            }
        }
        if (bytes == null || bytes.isEmpty()) null else {
            val opts = BitmapFactory.Options().apply { inJustDecodeBounds = true }
            BitmapFactory.decodeByteArray(bytes, 0, bytes.size, opts)
            var sample = 1
            while (opts.outWidth / (sample * 2) >= maxWidth) sample *= 2
            BitmapFactory.decodeByteArray(bytes, 0, bytes.size, BitmapFactory.Options().apply { inSampleSize = sample })
        }
    } catch (e: Throwable) {
        null
    }

    private fun trim(dir: File) {
        try {
            val files = dir.listFiles() ?: return
            var total = files.sumOf { it.length() }
            if (total <= DISK_MAX) return
            for (f in files.sortedBy { it.lastModified() }) {
                total -= f.length()
                f.delete()
                if (total < DISK_MAX / 2) break
            }
        } catch (e: Exception) { }
    }
}
