package de.overlord.tv

import java.net.HttpURLConnection
import java.net.URL
import java.util.Locale

/**
 * Minimaler HLS-Parser (ohne Bibliothek): liest Qualitätsstufen aus einer Master-Playlist und die
 * Gesamtlänge aus einer Medien-Playlist. Allgemein für jeden HLS-Stream – keine Regeln für einzelne Seiten.
 */
object Hls {
    data class Variant(val url: String, val width: Int, val height: Int, val bandwidth: Long, val name: String) {
        val label: String
            get() = when {
                height > 0 -> "${height}p"
                name.isNotBlank() -> name
                bandwidth > 0 -> rate
                else -> "Variante"
            }
        val rate: String get() = if (bandwidth > 0) String.format(Locale.GERMANY, "%.1f Mbit/s", bandwidth / 1_000_000.0) else ""
    }

    /** [durationSec] = Länge der Medien-Playlist (bei Live-Streams nur das aktuelle Fenster), [live] ohne #EXT-X-ENDLIST. */
    data class Info(val variants: List<Variant>, val durationSec: Double, val live: Boolean) {
        val summary: String
            get() {
                val parts = ArrayList<String>()
                parts.add("HLS")
                variants.firstOrNull()?.let { top -> parts.add(if (variants.size > 1) "bis ${top.label} · ${variants.size} Stufen" else top.label) }
                if (live) parts.add("Live")
                return parts.joinToString(" · ")
            }
    }

    fun isHls(url: String) = url.contains(".m3u8", ignoreCase = true)

    private fun fetch(url: String, headers: Map<String, String>): String? = try {
        val c = URL(url).openConnection() as HttpURLConnection
        c.connectTimeout = 8000
        c.readTimeout = 10000
        c.instanceFollowRedirects = true
        headers.forEach { (k, v) -> if (v.isNotBlank()) c.setRequestProperty(k, v) }
        if (c.responseCode !in 200..299) null
        else c.inputStream.use { s ->
            // Playlists sind klein – mehr als 1 MB wäre kein Text-Manifest
            val buf = s.readBytes()
            if (buf.size > 1_000_000) null else String(buf, Charsets.UTF_8)
        }
    } catch (e: Exception) {
        null
    }

    fun parse(base: String, text: String): Info {
        if (!text.trimStart().startsWith("#EXTM3U")) return Info(emptyList(), 0.0, false)
        val found = ArrayList<Variant>()
        var duration = 0.0
        var media = false
        var ended = false
        var pending: Map<String, String>? = null
        for (raw in text.lineSequence()) {
            val l = raw.trim()
            when {
                l.startsWith("#EXT-X-STREAM-INF:") -> pending = attributes(l.substringAfter(':'))
                l.startsWith("#EXTINF:") -> { media = true; duration += l.substringAfter(':').substringBefore(',').trim().toDoubleOrNull() ?: 0.0 }
                l.startsWith("#EXT-X-ENDLIST") -> ended = true
                pending != null && l.isNotEmpty() && !l.startsWith("#") -> {
                    val res = pending["RESOLUTION"].orEmpty()
                    found.add(Variant(
                        url = resolve(base, l),
                        width = res.substringBefore('x').toIntOrNull() ?: 0,
                        height = res.substringAfter('x', "").toIntOrNull() ?: 0,
                        bandwidth = pending["BANDWIDTH"]?.toLongOrNull() ?: pending["AVERAGE-BANDWIDTH"]?.toLongOrNull() ?: 0L,
                        name = pending["NAME"].orEmpty(),
                    ))
                    pending = null
                }
            }
        }
        // Gleiche Auflösung mehrfach (z. B. andere Codecs) → nur die mit der höchsten Bitrate
        val variants = found.groupBy { if (it.height > 0) "h${it.height}" else it.url }.values
            .map { g -> g.maxByOrNull { it.bandwidth }!! }
            .sortedWith(compareByDescending<Variant> { it.height }.thenByDescending { it.bandwidth })
        return Info(variants, duration, media && !ended)
    }

    /** Playlist laden und auswerten; bei einer Master-Playlist die Länge aus der kleinsten Stufe bestimmen. */
    fun info(url: String, headers: Map<String, String>): Info? {
        val text = fetch(url, headers) ?: return null
        val info = parse(url, text)
        if (info.variants.isNotEmpty()) {
            val smallest = info.variants.last()
            val sub = fetch(smallest.url, headers)?.let { parse(smallest.url, it) }
            if (sub != null) return info.copy(durationSec = sub.durationSec, live = sub.live)
        }
        return info
    }

    /** Beste Stufe bis höchstens [maxHeight] Bildzeilen (0 = keine Grenze). */
    fun pick(variants: List<Variant>, maxHeight: Int): Variant? {
        if (variants.isEmpty()) return null
        if (maxHeight <= 0) return variants.first()
        return variants.firstOrNull { it.height in 1..maxHeight } ?: variants.last()
    }

    private fun attributes(s: String): Map<String, String> {
        val m = HashMap<String, String>()
        Regex("""([A-Z0-9-]+)=("[^"]*"|[^,]*)""").findAll(s).forEach { m[it.groupValues[1]] = it.groupValues[2].trim('"') }
        return m
    }

    private fun resolve(base: String, rel: String): String = try { URL(URL(base), rel).toString() } catch (e: Exception) { rel }
}
