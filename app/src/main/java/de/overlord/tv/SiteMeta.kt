package de.overlord.tv

import android.content.Context
import android.graphics.Color
import android.os.Handler
import android.os.Looper
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL
import java.util.concurrent.Executors

/**
 * Liest Vorschaubild (og:image), Symbol (apple-touch-icon), Markenfarbe (theme-color),
 * Titel und Beschreibung einer Webseite – für schöne Kacheln ohne Handarbeit.
 */
object SiteMeta {
    class Meta(
        val image: String,
        val icon: String,
        val themeColor: Int?,
        val title: String,
        val description: String,
        val fetched: Long,
    ) {
        fun toJson(): JSONObject = JSONObject().put("image", image).put("icon", icon)
            .put("theme", themeColor ?: 0).put("hasTheme", themeColor != null)
            .put("title", title).put("description", description).put("fetched", fetched)

        companion object {
            fun fromJson(o: JSONObject) = Meta(
                o.optString("image"), o.optString("icon"),
                if (o.optBoolean("hasTheme")) o.optInt("theme") else null,
                o.optString("title"), o.optString("description"), o.optLong("fetched"),
            )
        }
    }

    private const val PREFS = "sitemeta"
    private const val MAX_AGE = 7L * 24 * 3600 * 1000
    private const val UA = "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36"
    private val pool = Executors.newFixedThreadPool(2)
    private val main = Handler(Looper.getMainLooper())
    private val inFlight = HashSet<String>()

    private fun prefs() = App.instance.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
    private fun key(url: String) = hostOf(url).lowercase() + (android.net.Uri.parse(url).path ?: "").trimEnd('/')

    fun get(url: String): Meta? = try {
        prefs().getString(key(url), null)?.let { Meta.fromJson(JSONObject(it)) }
    } catch (e: Exception) {
        null
    }

    /** Großes Symbol über einen öffentlichen Favicon-Dienst (Ausweichlösung). */
    fun fallbackIcon(url: String) = "https://www.google.com/s2/favicons?domain=${hostOf(url)}&sz=128"

    fun iconUrls(url: String): List<String> {
        val m = get(url)
        return listOfNotNull(m?.icon?.takeIf { it.isNotBlank() }, fallbackIcon(url))
    }

    /** Lädt die Daten im Hintergrund, falls sie fehlen oder älter als eine Woche sind. */
    fun ensure(url: String, onUpdate: (Meta) -> Unit) {
        val k = key(url)
        val cur = get(url)
        if (cur != null && System.currentTimeMillis() - cur.fetched < MAX_AGE) return
        synchronized(inFlight) { if (!inFlight.add(k)) return }
        pool.execute {
            val meta = try { fetch(url) } catch (e: Throwable) { null }
            synchronized(inFlight) { inFlight.remove(k) }
            if (meta != null) {
                prefs().edit().putString(k, meta.toJson().toString()).apply()
                main.post { onUpdate(meta) }
            }
        }
    }

    private fun fetch(pageUrl: String): Meta? {
        var url = URL(pageUrl)
        var conn: HttpURLConnection
        var hops = 0
        while (true) {
            conn = url.openConnection() as HttpURLConnection
            conn.instanceFollowRedirects = false
            conn.connectTimeout = 8000
            conn.readTimeout = 10000
            conn.setRequestProperty("User-Agent", UA)
            conn.setRequestProperty("Accept", "text/html,application/xhtml+xml")
            conn.setRequestProperty("Accept-Language", "de-DE,de;q=0.9,en;q=0.6")
            val code = conn.responseCode
            if (code in 300..399 && hops < 5) {
                val loc = conn.getHeaderField("Location") ?: break
                url = URL(url, loc)
                hops++
                conn.disconnect()
                continue
            }
            if (code != 200) return null
            break
        }
        val sb = StringBuilder()
        conn.inputStream.bufferedReader().use { r ->
            val buf = CharArray(8192)
            while (sb.length < 400_000) {
                val n = r.read(buf)
                if (n < 0) break
                sb.append(buf, 0, n)
                if (sb.indexOf("</head>", (sb.length - n - 8).coerceAtLeast(0)) >= 0) break
            }
        }
        return parse(sb.toString(), url)
    }

    private val TAG_META = Regex("<meta\\s[^>]*>", RegexOption.IGNORE_CASE)
    private val TAG_LINK = Regex("<link\\s[^>]*>", RegexOption.IGNORE_CASE)
    private val ATTR = Regex("([a-zA-Z_:][-a-zA-Z0-9_:.]*)\\s*=\\s*(\"([^\"]*)\"|'([^']*)'|([^\\s\"'>]+))")
    private val TITLE = Regex("<title[^>]*>([^<]*)</title>", RegexOption.IGNORE_CASE)

    private fun attrs(tag: String): Map<String, String> {
        val m = HashMap<String, String>()
        ATTR.findAll(tag).forEach { mr ->
            val v = mr.groups[3]?.value ?: mr.groups[4]?.value ?: mr.groups[5]?.value ?: ""
            m[mr.groupValues[1].lowercase()] = unescape(v)
        }
        return m
    }

    private fun unescape(s: String) = s.replace("&amp;", "&").replace("&quot;", "\"").replace("&#39;", "'")
        .replace("&#039;", "'").replace("&lt;", "<").replace("&gt;", ">").replace("&#x2F;", "/").trim()

    private fun parse(html: String, base: URL): Meta {
        var ogImage = ""
        var twImage = ""
        var theme: Int? = null
        var desc = ""
        var ogDesc = ""
        var ogTitle = ""
        var siteName = ""
        for (mr in TAG_META.findAll(html)) {
            val a = attrs(mr.value)
            val key = (a["property"] ?: a["name"] ?: a["itemprop"] ?: "").lowercase()
            val content = a["content"] ?: continue
            when (key) {
                "og:image", "og:image:url", "og:image:secure_url" -> if (ogImage.isEmpty()) ogImage = content
                "twitter:image", "twitter:image:src" -> if (twImage.isEmpty()) twImage = content
                "theme-color" -> if (theme == null) theme = parseColor(content)
                "description" -> if (desc.isEmpty()) desc = content
                "og:description" -> if (ogDesc.isEmpty()) ogDesc = content
                "og:title" -> if (ogTitle.isEmpty()) ogTitle = content
                "og:site_name", "application-name" -> if (siteName.isEmpty()) siteName = content
            }
        }
        var bestIcon = ""
        var bestSize = -1
        for (mr in TAG_LINK.findAll(html)) {
            val a = attrs(mr.value)
            val rel = (a["rel"] ?: "").lowercase()
            val href = a["href"] ?: continue
            if (href.endsWith(".svg", true) || (a["type"] ?: "").contains("svg")) continue
            val size = (a["sizes"] ?: "").lowercase().split(' ').mapNotNull { it.substringBefore('x').toIntOrNull() }.maxOrNull() ?: 0
            val score = when {
                rel.contains("apple-touch-icon") -> 1000 + (if (size == 0) 180 else size)
                rel.split(' ').contains("icon") && size >= 96 -> size
                else -> -1
            }
            if (score > bestSize) { bestSize = score; bestIcon = href }
        }
        fun abs(u: String) = if (u.isBlank()) "" else try { URL(base, u).toString() } catch (e: Exception) { "" }
        val title = siteName.ifBlank { ogTitle }.ifBlank { TITLE.find(html)?.groupValues?.get(1)?.let { unescape(it) } ?: "" }
        return Meta(
            image = abs(ogImage.ifBlank { twImage }),
            icon = abs(bestIcon),
            themeColor = theme?.takeIf { usableColor(it) },
            title = title.take(80),
            description = ogDesc.ifBlank { desc }.take(300),
            fetched = System.currentTimeMillis(),
        )
    }

    /** Nur kräftige Farben übernehmen (Weiß/Schwarz/Grau ergeben langweilige Kacheln). */
    private fun usableColor(c: Int): Boolean {
        val hsv = FloatArray(3)
        Color.colorToHSV(c, hsv)
        return hsv[1] >= 0.25f && hsv[2] >= 0.2f
    }
}
