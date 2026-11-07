package de.overlord.tv

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.os.Handler
import android.os.Looper
import android.util.LruCache
import android.widget.ImageView
import java.net.HttpURLConnection
import java.net.URL
import java.util.concurrent.Executors

/** Minimaler Bild-Lader (ohne Glide/Picasso): Cache + Hintergrund-Threads + Fallback-URLs. */
object ImageLoader {
    private val main = Handler(Looper.getMainLooper())
    private val pool = Executors.newFixedThreadPool(3)
    private val cache = object : LruCache<String, Bitmap>((Runtime.getRuntime().maxMemory() / 8).toInt()) {
        override fun sizeOf(key: String, value: Bitmap) = value.byteCount
    }
    private val failed = HashSet<String>()

    fun load(view: ImageView, urls: List<String>, maxWidth: Int = 640, onLoaded: ((Bitmap) -> Unit)? = null) {
        val key = urls.joinToString("|")
        view.tag = key
        if (urls.isEmpty()) { view.setImageDrawable(null); return }
        cache.get(key)?.let { view.setImageBitmap(it); onLoaded?.invoke(it); return }
        view.setImageDrawable(null)
        pool.execute {
            var bmp: Bitmap? = null
            for (u in urls) {
                if (synchronized(failed) { failed.contains(u) }) continue
                bmp = fetch(u, maxWidth)
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

    private fun fetch(url: String, maxWidth: Int): Bitmap? = try {
        val conn = URL(url).openConnection() as HttpURLConnection
        conn.connectTimeout = 8000
        conn.readTimeout = 15000
        if (conn.responseCode != 200) null else {
            val bytes = conn.inputStream.use { it.readBytes() }
            val opts = BitmapFactory.Options().apply { inJustDecodeBounds = true }
            BitmapFactory.decodeByteArray(bytes, 0, bytes.size, opts)
            var sample = 1
            while (opts.outWidth / (sample * 2) >= maxWidth) sample *= 2
            BitmapFactory.decodeByteArray(bytes, 0, bytes.size, BitmapFactory.Options().apply { inSampleSize = sample })
        }
    } catch (e: Throwable) {
        null
    }
}
