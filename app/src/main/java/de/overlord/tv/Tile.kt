package de.overlord.tv

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject

/**
 * Eine Kachel auf dem Startbildschirm.
 *
 * - [Type.APP]: startet eine installierte App. [target] enthält eine oder mehrere
 *   Paketnamen (durch Komma getrennt) – der erste installierte wird gestartet.
 * - [Type.WEB]: öffnet [target] (URL) im eingebauten TV-Browser.
 */
data class Tile(
    val id: String,
    val name: String,
    val type: Type,
    val target: String,
    val color: Int,
) {
    enum class Type { APP, WEB }

    val packages: List<String>
        get() = target.split(',').map { it.trim() }.filter { it.isNotEmpty() }

    fun toJson(): JSONObject = JSONObject()
        .put("id", id)
        .put("name", name)
        .put("type", type.name)
        .put("target", target)
        .put("color", color)

    companion object {
        fun fromJson(o: JSONObject) = Tile(
            id = o.getString("id"),
            name = o.getString("name"),
            type = Type.valueOf(o.getString("type")),
            target = o.getString("target"),
            color = o.getInt("color"),
        )
    }
}

/** Speichert die Kacheln in den SharedPreferences. */
class TileStore(context: Context) {
    private val prefs = context.getSharedPreferences("tiles", Context.MODE_PRIVATE)

    fun load(): MutableList<Tile> {
        val raw = prefs.getString(KEY, null) ?: return defaults().toMutableList()
        return try {
            val arr = JSONArray(raw)
            MutableList(arr.length()) { Tile.fromJson(arr.getJSONObject(it)) }
        } catch (e: Exception) {
            defaults().toMutableList()
        }
    }

    fun save(tiles: List<Tile>) {
        val arr = JSONArray()
        tiles.forEach { arr.put(it.toJson()) }
        prefs.edit().putString(KEY, arr.toString()).apply()
    }

    companion object {
        private const val KEY = "tiles_v1"

        val PALETTE = intArrayOf(
            0xFFF47521.toInt(), // orange
            0xFF00A8E1.toInt(), // blau
            0xFF7B4DFF.toInt(), // lila
            0xFF2EC27E.toInt(), // grün
            0xFFE01B24.toInt(), // rot
            0xFFF5C211.toInt(), // gelb
            0xFF3D3846.toInt(), // grau
        )

        fun defaults() = listOf(
            Tile(
                id = "crunchyroll",
                name = "Crunchyroll",
                type = Tile.Type.APP,
                target = "com.crunchyroll.crunchyroid",
                color = PALETTE[0],
            ),
            Tile(
                id = "primevideo",
                name = "Prime Video",
                type = Tile.Type.APP,
                // Fire TV, ältere Fire TV, Android TV, Android-Handy
                target = "com.amazon.firebat,com.amazon.avod,com.amazon.amazonvideo.livingroom,com.amazon.avod.thirdpartyclient",
                color = PALETTE[1],
            ),
        )
    }
}
