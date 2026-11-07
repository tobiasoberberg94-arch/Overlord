package de.overlord.tv

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject

/** Eintrag der „Weiterschauen“-Reihe (aus dem eingebauten Browser oder dem nativen Player). */
data class ContinueEntry(
    val key: String,
    var title: String,
    var url: String,
    var position: Double,
    var duration: Double,
    var updated: Long,
    var color: Int,
    var mediaUrl: String = "",
    var referer: String = "",
) {
    val fraction get() = if (duration > 0) (position / duration).toFloat().coerceIn(0f, 1f) else 0f
    val remaining get() = duration - position

    fun toJson(): JSONObject = JSONObject()
        .put("key", key).put("title", title).put("url", url).put("position", position)
        .put("duration", duration).put("updated", updated).put("color", color)
        .put("mediaUrl", mediaUrl).put("referer", referer)

    companion object {
        fun fromJson(o: JSONObject) = ContinueEntry(
            o.getString("key"), o.optString("title"), o.optString("url"),
            o.optDouble("position", 0.0), o.optDouble("duration", 0.0),
            o.optLong("updated"), o.optInt("color", Brand.ACCENT),
            o.optString("mediaUrl"), o.optString("referer"),
        )
    }
}

object ContinueStore {
    private const val PREFS = "continue"
    private const val KEY = "entries"
    const val MIN_DURATION = 5 * 60.0   // kürzer = vermutlich Werbung
    const val DONE_FRACTION = 0.95
    private const val MAX_ENTRIES = 30

    fun keyFor(url: String): String = url.substringBefore('#').trimEnd('/')

    fun all(ctx: Context): MutableList<ContinueEntry> {
        val raw = ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getString(KEY, null) ?: return mutableListOf()
        return try {
            val arr = JSONArray(raw)
            MutableList(arr.length()) { ContinueEntry.fromJson(arr.getJSONObject(it)) }
                .sortedByDescending { it.updated }.toMutableList()
        } catch (e: Exception) {
            mutableListOf()
        }
    }

    private fun save(ctx: Context, list: List<ContinueEntry>) {
        val arr = JSONArray()
        list.sortedByDescending { it.updated }.take(MAX_ENTRIES).forEach { arr.put(it.toJson()) }
        ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().putString(KEY, arr.toString()).apply()
    }

    fun get(ctx: Context, url: String): ContinueEntry? = all(ctx).firstOrNull { it.key == keyFor(url) }

    /**
     * Fortschritt speichern. Videos unter 5 Minuten werden ignoriert,
     * ab 95 % gilt das Video als fertig und der Eintrag wird entfernt.
     */
    fun report(
        ctx: Context, url: String, title: String, position: Double, duration: Double, color: Int,
        mediaUrl: String = "", referer: String = "",
    ) {
        if (url.isBlank() || !duration.isFinite() || duration < MIN_DURATION) return
        val key = keyFor(url)
        val list = all(ctx)
        val existing = list.firstOrNull { it.key == key }
        if (position / duration >= DONE_FRACTION) {
            if (existing != null) {
                list.remove(existing)
                save(ctx, list)
            }
            return
        }
        if (existing == null && position < 15) return   // nur kurz reingeschaut
        val e = existing ?: ContinueEntry(key, title, url, position, duration, 0, color).also { list.add(it) }
        if (title.isNotBlank()) e.title = title
        e.url = url
        e.position = position
        e.duration = duration
        e.updated = System.currentTimeMillis()
        e.color = color
        if (mediaUrl.isNotBlank()) {
            e.mediaUrl = mediaUrl
            e.referer = referer
        }
        save(ctx, list)
    }

    fun remove(ctx: Context, key: String) = save(ctx, all(ctx).filterNot { it.key == key })

    fun clear(ctx: Context) = save(ctx, emptyList())
}
