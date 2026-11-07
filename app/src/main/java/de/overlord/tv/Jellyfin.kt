package de.overlord.tv

import android.content.Context
import android.net.Uri
import org.json.JSONArray
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL
import java.util.UUID

/** Schlanker Client für die offizielle Jellyfin-REST-API. */
object Jellyfin {
    private const val PREFS = "jellyfin"
    private val prefs get() = App.instance.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    val server: String get() = prefs.getString("server", "") ?: ""
    val token: String get() = prefs.getString("token", "") ?: ""
    val userId: String get() = prefs.getString("userId", "") ?: ""
    val userName: String get() = prefs.getString("userName", "") ?: ""
    private val deviceId: String
        get() = prefs.getString("deviceId", null) ?: UUID.randomUUID().toString().also { prefs.edit().putString("deviceId", it).apply() }

    fun isConfigured() = server.isNotBlank() && token.isNotBlank() && userId.isNotBlank()

    fun logout() {
        prefs.edit().remove("token").remove("userId").apply()
    }

    private fun authHeader(withToken: Boolean): String {
        val base = "MediaBrowser Client=\"Overlord TV\", Device=\"Fire TV\", DeviceId=\"$deviceId\", Version=\"${BuildConfig.VERSION_NAME}\""
        return if (withToken && token.isNotBlank()) "$base, Token=\"$token\"" else base
    }

    private fun request(method: String, base: String, path: String, body: JSONObject? = null, withToken: Boolean = true): Any? {
        val conn = URL(base.trimEnd('/') + path).openConnection() as HttpURLConnection
        conn.requestMethod = method
        conn.connectTimeout = 10000
        conn.readTimeout = 20000
        conn.setRequestProperty("Authorization", authHeader(withToken))
        conn.setRequestProperty("X-Emby-Authorization", authHeader(withToken))
        conn.setRequestProperty("Accept", "application/json")
        if (body != null) {
            conn.doOutput = true
            conn.setRequestProperty("Content-Type", "application/json")
            conn.outputStream.use { it.write(body.toString().toByteArray()) }
        }
        val code = conn.responseCode
        if (code !in 200..299) throw RuntimeException("HTTP $code")
        val text = conn.inputStream.bufferedReader().use { it.readText() }.trim()
        if (text.isEmpty()) return null
        return if (text.startsWith("[")) JSONArray(text) else JSONObject(text)
    }

    private fun get(path: String): Any? = request("GET", server, path)

    /** Liefert null bei Erfolg, sonst eine Fehlermeldung. */
    fun login(srv: String, user: String, pass: String): String? {
        var s = srv.trim().trimEnd('/')
        if (!s.startsWith("http")) s = "http://$s"
        return try {
            val body = JSONObject().put("Username", user).put("Pw", pass)
            val res = request("POST", s, "/Users/AuthenticateByName", body, withToken = false) as JSONObject
            prefs.edit()
                .putString("server", s)
                .putString("token", res.getString("AccessToken"))
                .putString("userId", res.getJSONObject("User").getString("Id"))
                .putString("userName", res.getJSONObject("User").optString("Name", user))
                .apply()
            null
        } catch (e: Exception) {
            "Server: $s\nFehler: ${e.message ?: e.javaClass.simpleName}\n\nPrüfe Adresse (inkl. Port, meist 8096), Benutzername und Passwort."
        }
    }

    class Item(val json: JSONObject) {
        val id: String = json.optString("Id")
        val name: String = json.optString("Name")
        val type: String = json.optString("Type")
        val seriesName: String = json.optString("SeriesName")
        val seriesId: String = json.optString("SeriesId")
        val seasonId: String = json.optString("SeasonId")
        val index: Int = json.optInt("IndexNumber", -1)
        val season: Int = json.optInt("ParentIndexNumber", -1)
        val overview: String = json.optString("Overview")
        val year: Int = json.optInt("ProductionYear", 0)
        val rating: String = json.optString("OfficialRating")
        val community: Double = json.optDouble("CommunityRating", 0.0)
        val collectionType: String = json.optString("CollectionType")
        val runtimeSec: Double = json.optLong("RunTimeTicks", 0) / 10_000_000.0
        val positionSec: Double get() = (json.optJSONObject("UserData")?.optLong("PlaybackPositionTicks", 0) ?: 0) / 10_000_000.0
        val playedPercent: Double get() = json.optJSONObject("UserData")?.optDouble("PlayedPercentage", 0.0) ?: 0.0
        val played: Boolean get() = json.optJSONObject("UserData")?.optBoolean("Played", false) ?: false
        /** Zeitpunkt der letzten Wiedergabe (ms seit 1970) oder 0. */
        val lastPlayed: Long
            get() = try {
                val s = json.optJSONObject("UserData")?.optString("LastPlayedDate").orEmpty()
                if (s.length < 19) 0L else java.text.SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss", java.util.Locale.US)
                    .apply { timeZone = java.util.TimeZone.getTimeZone("UTC") }.parse(s.substring(0, 19))?.time ?: 0L
            } catch (e: Exception) {
                0L
            }
        val playable get() = type == "Movie" || type == "Episode" || type == "Video" || type == "MusicVideo"

        fun hasImage(kind: String) = json.optJSONObject("ImageTags")?.has(kind) == true
        fun hasBackdrop() = (json.optJSONArray("BackdropImageTags")?.length() ?: 0) > 0

        val displayTitle: String
            get() = when (type) {
                "Episode" -> buildString {
                    if (season >= 0) append("S$season")
                    if (index >= 0) append(":F$index ")
                    append(name)
                }.trim()
                else -> name
            }

        val infoLine: String
            get() {
                val parts = ArrayList<String>()
                if (type == "Episode" && seriesName.isNotBlank()) parts.add(seriesName)
                if (year > 0) parts.add(year.toString())
                if (rating.isNotBlank()) parts.add(rating)
                if (runtimeSec > 0) parts.add("${(runtimeSec / 60).toInt()} Min.")
                if (community > 0) parts.add("★ " + String.format("%.1f", community))
                if (positionSec > 0 && runtimeSec > 0) parts.add(formatRemaining(runtimeSec - positionSec))
                return parts.joinToString(" · ")
            }
    }

    private fun items(res: Any?): List<Item> = when (res) {
        is JSONArray -> List(res.length()) { Item(res.getJSONObject(it)) }
        is JSONObject -> res.optJSONArray("Items")?.let { arr -> List(arr.length()) { Item(arr.getJSONObject(it)) } } ?: emptyList()
        else -> emptyList()
    }

    private const val FIELDS = "Fields=Overview,PrimaryImageAspectRatio,ParentId&EnableImageTypes=Primary,Backdrop,Thumb"

    fun views() = items(get("/Users/$userId/Views"))
    fun resume() = items(get("/Users/$userId/Items/Resume?Limit=16&MediaTypes=Video&$FIELDS"))
    fun nextUp() = items(get("/Shows/NextUp?UserId=$userId&Limit=16&$FIELDS"))
    fun latest(parentId: String) = items(get("/Users/$userId/Items/Latest?ParentId=$parentId&Limit=16&$FIELDS"))
    fun all(parentId: String) = items(get("/Users/$userId/Items?ParentId=$parentId&Recursive=true&IncludeItemTypes=Movie,Series,Video&SortBy=SortName&SortOrder=Ascending&Limit=800&$FIELDS"))
    fun seasons(seriesId: String) = items(get("/Shows/$seriesId/Seasons?UserId=$userId&$FIELDS"))
    fun episodes(seriesId: String, seasonId: String) = items(get("/Shows/$seriesId/Episodes?UserId=$userId&SeasonId=$seasonId&$FIELDS"))
    fun item(id: String): Item = Item(get("/Users/$userId/Items/$id") as JSONObject)
    fun search(term: String) = items(get("/Users/$userId/Items?searchTerm=${Uri.encode(term)}&Recursive=true&IncludeItemTypes=Movie,Series,Episode&Limit=30&$FIELDS"))

    /** Nächste Folge nach [item] (gleiche Serie, auch über Staffelgrenzen). */
    fun nextEpisode(item: Item): Item? {
        if (item.type != "Episode" || item.seriesId.isBlank()) return null
        val list = items(get("/Shows/${item.seriesId}/Episodes?UserId=$userId&StartItemId=${item.id}&Limit=2&$FIELDS"))
        return list.getOrNull(1)
    }

    fun image(id: String, kind: String, width: Int = 480) = "$server/Items/$id/Images/$kind?maxWidth=$width&quality=85"

    /** Bilder für 16:9-Karten mit Ausweichreihenfolge. */
    fun cardImages(i: Item): List<String> {
        val out = ArrayList<String>()
        when (i.type) {
            "Episode" -> {
                if (i.hasImage("Primary")) out.add(image(i.id, "Primary"))
                if (i.seriesId.isNotBlank()) { out.add(image(i.seriesId, "Thumb")); out.add(image(i.seriesId, "Backdrop")) }
            }
            "Season" -> {
                if (i.seriesId.isNotBlank()) { out.add(image(i.seriesId, "Thumb")); out.add(image(i.seriesId, "Backdrop")) }
                out.add(image(i.id, "Primary"))
            }
            else -> {
                if (i.hasImage("Thumb")) out.add(image(i.id, "Thumb"))
                if (i.hasBackdrop()) out.add(image(i.id, "Backdrop"))
                out.add(image(i.id, "Primary"))
            }
        }
        return out
    }

    fun heroImages(i: Item): List<String> {
        val out = ArrayList<String>()
        if (i.hasBackdrop()) out.add(image(i.id, "Backdrop", 1280))
        if (i.seriesId.isNotBlank()) out.add(image(i.seriesId, "Backdrop", 1280))
        if (i.type == "Episode" && i.hasImage("Primary")) out.add(image(i.id, "Primary", 1280))
        return out
    }

    /** Direktwiedergabe (Originaldatei). */
    fun directUrl(id: String) = "$server/Videos/$id/stream?static=true&MediaSourceId=$id&api_key=$token&DeviceId=${Uri.encode(deviceId)}"

    /** Ausweich-URL: HLS, Server kopiert oder transkodiert nach H.264/AAC. */
    fun hlsUrl(id: String) = "$server/Videos/$id/master.m3u8?MediaSourceId=$id&api_key=$token&DeviceId=${Uri.encode(deviceId)}" +
        "&VideoCodec=h264&AudioCodec=aac,mp3&TranscodingMaxAudioChannels=2&SegmentContainer=ts&MaxStreamingBitrate=20000000&PlaySessionId=${UUID.randomUUID()}"

    private fun ticks(sec: Double) = (sec * 10_000_000).toLong()

    private fun report(path: String, id: String, posSec: Double, paused: Boolean, method: String) {
        try {
            request("POST", server, path, JSONObject()
                .put("ItemId", id).put("MediaSourceId", id).put("PositionTicks", ticks(posSec))
                .put("IsPaused", paused).put("CanSeek", true).put("PlayMethod", method))
        } catch (e: Exception) { }
    }

    fun reportStart(id: String, posSec: Double, method: String) = report("/Sessions/Playing", id, posSec, false, method)
    fun reportProgress(id: String, posSec: Double, paused: Boolean, method: String) = report("/Sessions/Playing/Progress", id, posSec, paused, method)
    fun reportStopped(id: String, posSec: Double, method: String) = report("/Sessions/Playing/Stopped", id, posSec, false, method)
}
