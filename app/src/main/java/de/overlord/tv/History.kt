package de.overlord.tv

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject

/** Zuletzt besuchte Seiten des eingebauten Browsers (eine Zeile pro Domain). */
object History {
    private const val PREFS = "history"
    private const val KEY = "items"
    private const val MAX = 24

    class Entry(val url: String, val title: String, val time: Long) {
        val host get() = hostOf(url)
    }

    private fun prefs() = App.instance.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    fun all(): List<Entry> = try {
        val arr = JSONArray(prefs().getString(KEY, "[]"))
        List(arr.length()) { i -> arr.getJSONObject(i).let { Entry(it.optString("url"), it.optString("title"), it.optLong("time")) } }
    } catch (e: Exception) {
        emptyList()
    }

    fun add(url: String, title: String) {
        if (!url.startsWith("http") || hostOf(url).isBlank()) return
        if (hostOf(url).contains("duckduckgo") && url.contains("q=")) return
        val list = all().filterNot { baseDomain(it.host) == baseDomain(hostOf(url)) }.toMutableList()
        list.add(0, Entry(url, title.ifBlank { hostOf(url) }, System.currentTimeMillis()))
        val arr = JSONArray()
        list.take(MAX).forEach { arr.put(JSONObject().put("url", it.url).put("title", it.title).put("time", it.time)) }
        prefs().edit().putString(KEY, arr.toString()).apply()
    }

    fun remove(url: String) {
        val arr = JSONArray()
        all().filterNot { it.url == url }.forEach { arr.put(JSONObject().put("url", it.url).put("title", it.title).put("time", it.time)) }
        prefs().edit().putString(KEY, arr.toString()).apply()
    }

    fun clear() = prefs().edit().remove(KEY).apply()
}
