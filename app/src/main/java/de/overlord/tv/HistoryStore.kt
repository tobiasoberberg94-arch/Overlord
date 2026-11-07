package de.overlord.tv

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject

/** Ein Eintrag in „Weiterschauen“ – eine Seite, auf der ein Video angeschaut wurde. */
data class HistoryEntry(
    val url: String,
    val title: String,
    val tileName: String,
    val color: Int,
    val position: Double,
    val duration: Double,
    val time: Long,
) {
    val progress: Float
        get() = if (duration > 0) (position / duration).toFloat().coerceIn(0f, 1f) else 0f

    fun toJson(): JSONObject = JSONObject()
        .put("url", url).put("title", title).put("tileName", tileName)
        .put("color", color).put("position", position).put("duration", duration)
        .put("time", time)

    companion object {
        fun fromJson(o: JSONObject) = HistoryEntry(
            url = o.getString("url"),
            title = o.optString("title"),
            tileName = o.optString("tileName"),
            color = o.optInt("color"),
            position = o.optDouble("position", 0.0),
            duration = o.optDouble("duration", 0.0),
            time = o.optLong("time"),
        )
    }
}

class HistoryStore(context: Context) {
    private val prefs = context.applicationContext.getSharedPreferences("history", Context.MODE_PRIVATE)

    @Synchronized
    fun list(): List<HistoryEntry> {
        val raw = prefs.getString(KEY, null) ?: return emptyList()
        return try {
            val arr = JSONArray(raw)
            List(arr.length()) { HistoryEntry.fromJson(arr.getJSONObject(it)) }
                .sortedByDescending { it.time }
        } catch (e: Exception) {
            emptyList()
        }
    }

    @Synchronized
    fun find(url: String): HistoryEntry? = list().firstOrNull { it.url == url }

    /** Speichert den Fortschritt; fast fertig geschaute Folgen fliegen aus der Liste. */
    @Synchronized
    fun updateProgress(url: String, title: String, tileName: String, color: Int, position: Double, duration: Double) {
        val items = list().filter { it.url != url }.toMutableList()
        val finished = duration > 0 && position >= duration * 0.95
        if (!finished) {
            items.add(0, HistoryEntry(url, title, tileName, color, position, duration, System.currentTimeMillis()))
        }
        save(items.take(MAX))
    }

    @Synchronized
    fun remove(url: String) = save(list().filter { it.url != url })

    private fun save(items: List<HistoryEntry>) {
        val arr = JSONArray()
        items.forEach { arr.put(it.toJson()) }
        prefs.edit().putString(KEY, arr.toString()).apply()
    }

    companion object {
        private const val KEY = "history_v1"
        private const val MAX = 20

        fun formatTime(seconds: Double): String {
            val s = seconds.toLong()
            val h = s / 3600
            val m = (s % 3600) / 60
            val sec = s % 60
            return if (h > 0) "%d:%02d:%02d".format(h, m, sec) else "%d:%02d".format(m, sec)
        }
    }
}
