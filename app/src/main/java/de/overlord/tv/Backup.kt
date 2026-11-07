package de.overlord.tv

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject

/** Sicherung aller Benutzerdaten als JSON (Kacheln, Weiterschauen, Verlauf, Einstellungen). */
object Backup {
    private fun prefs(name: String) = App.instance.getSharedPreferences(name, Context.MODE_PRIVATE)

    private fun mapToJson(m: Map<String, *>): JSONObject {
        val o = JSONObject()
        m.forEach { (k, v) -> if (v is Boolean || v is Int || v is Long || v is String || v is Float) o.put(k, v) }
        return o
    }

    fun export(): JSONObject = JSONObject()
        .put("format", 1)
        .put("app", "Overlord TV")
        .put("version", BuildConfig.VERSION_NAME)
        .put("created", System.currentTimeMillis())
        .put("tiles", JSONArray(prefs("tiles").getString("list", null) ?: TileStore.load(App.instance).let { list -> JSONArray().also { a -> list.forEach { a.put(it.toJson()) } }.toString() }))
        .put("continue", JSONArray(prefs("continue").getString("entries", "[]")))
        .put("history", JSONArray(prefs("history").getString("items", "[]")))
        .put("settings", mapToJson(prefs("settings").all))
        .put("zoom", mapToJson(prefs("zoom").all))
        .put("mode", mapToJson(prefs("mode").all))
        .put("allow", JSONArray(prefs("adblock").getStringSet("allow", emptySet())!!.toList()))
        .put("jellyfin", JSONObject().put("server", Jellyfin.server).put("user", Jellyfin.userName))

    /** Spielt eine Sicherung ein; liefert eine kurze Zusammenfassung. */
    fun import(o: JSONObject): String {
        require(o.optString("app") == "Overlord TV") { "Keine Overlord-Sicherung" }
        val parts = ArrayList<String>()
        o.optJSONArray("tiles")?.let { prefs("tiles").edit().putString("list", it.toString()).apply(); parts.add("${it.length()} Kacheln") }
        o.optJSONArray("continue")?.let { prefs("continue").edit().putString("entries", it.toString()).apply(); parts.add("${it.length()} × Weiterschauen") }
        o.optJSONArray("history")?.let { prefs("history").edit().putString("items", it.toString()).apply() }
        fun restore(name: String, j: JSONObject?) {
            if (j == null) return
            val e = prefs(name).edit()
            j.keys().forEach { k ->
                when (val v = j.get(k)) {
                    is Boolean -> e.putBoolean(k, v)
                    is Int -> e.putInt(k, v)
                    is Long -> e.putLong(k, v)
                    is Double -> e.putFloat(k, v.toFloat())
                    is String -> e.putString(k, v)
                }
            }
            e.apply()
        }
        restore("settings", o.optJSONObject("settings"))
        restore("zoom", o.optJSONObject("zoom"))
        restore("mode", o.optJSONObject("mode"))
        o.optJSONArray("allow")?.let { a -> prefs("adblock").edit().putStringSet("allow", (0 until a.length()).map { a.getString(it) }.toSet()).apply() }
        Brand.applyTheme(Prefs.theme)
        return parts.joinToString(", ").ifBlank { "Sicherung eingespielt" }
    }
}
