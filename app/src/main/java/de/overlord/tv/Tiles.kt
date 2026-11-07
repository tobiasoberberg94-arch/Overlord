package de.overlord.tv

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.drawable.Drawable
import android.net.Uri
import org.json.JSONArray
import org.json.JSONObject
import java.util.UUID

enum class TileType { CRUNCHYROLL, PRIME, WEB, APP }

data class Tile(
    val id: String,
    val type: TileType,
    var name: String,
    var url: String = "",
    var pkg: String = "",
    var color: Int,
    var description: String = "",
) {
    val builtin get() = type == TileType.CRUNCHYROLL || type == TileType.PRIME

    fun toJson(): JSONObject = JSONObject()
        .put("id", id).put("type", type.name).put("name", name).put("url", url)
        .put("pkg", pkg).put("color", color).put("description", description)

    companion object {
        fun fromJson(o: JSONObject) = Tile(
            id = o.optString("id", UUID.randomUUID().toString()),
            type = try { TileType.valueOf(o.optString("type", "WEB")) } catch (e: Exception) { TileType.WEB },
            name = o.optString("name"),
            url = o.optString("url"),
            pkg = o.optString("pkg"),
            color = o.optInt("color", Brand.ACCENT),
            description = o.optString("description"),
        )
    }
}

object TileStore {
    private const val PREFS = "tiles"
    private const val KEY = "list"

    fun crunchyroll() = Tile(
        "builtin-crunchyroll", TileType.CRUNCHYROLL, "Crunchyroll",
        color = 0xFFF47521.toInt(),
        description = "Anime-Simulcasts kurz nach Japan-Ausstrahlung, Klassiker und Filme – startet die offizielle Crunchyroll-App.",
    )

    fun prime() = Tile(
        "builtin-prime", TileType.PRIME, "Prime Video",
        color = 0xFF00A8E1.toInt(),
        description = "Filme, Serien und Originals – startet die offizielle Prime-Video-App.",
    )

    fun load(ctx: Context): MutableList<Tile> {
        val raw = ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getString(KEY, null)
            ?: return mutableListOf(crunchyroll(), prime())
        return try {
            val arr = JSONArray(raw)
            MutableList(arr.length()) { Tile.fromJson(arr.getJSONObject(it)) }
        } catch (e: Exception) {
            mutableListOf(crunchyroll(), prime())
        }
    }

    fun save(ctx: Context, list: List<Tile>) {
        val arr = JSONArray()
        list.forEach { arr.put(it.toJson()) }
        ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().putString(KEY, arr.toString()).apply()
    }

    fun add(ctx: Context, tile: Tile) {
        val list = load(ctx)
        list.add(tile)
        save(ctx, list)
    }

    fun update(ctx: Context, tile: Tile) {
        val list = load(ctx)
        val i = list.indexOfFirst { it.id == tile.id }
        if (i >= 0) list[i] = tile
        save(ctx, list)
    }

    fun remove(ctx: Context, id: String) {
        save(ctx, load(ctx).filterNot { it.id == id })
    }

    /** Verschiebt eine Kachel um [delta] Plätze; liefert true bei Erfolg. */
    fun move(ctx: Context, id: String, delta: Int): Boolean {
        val list = load(ctx)
        val i = list.indexOfFirst { it.id == id }
        val j = i + delta
        if (i < 0 || j < 0 || j >= list.size) return false
        val t = list.removeAt(i)
        list.add(j, t)
        save(ctx, list)
        return true
    }

    fun restoreBuiltins(ctx: Context) {
        val list = load(ctx)
        if (list.none { it.type == TileType.CRUNCHYROLL }) list.add(0, crunchyroll())
        if (list.none { it.type == TileType.PRIME }) list.add(1.coerceAtMost(list.size), prime())
        save(ctx, list)
    }

    fun newWeb(name: String, url: String) =
        Tile(UUID.randomUUID().toString(), TileType.WEB, name, url = url, color = Brand.colorFor(url))

    fun newApp(name: String, pkg: String, color: Int) =
        Tile(UUID.randomUUID().toString(), TileType.APP, name, pkg = pkg, color = color)
}

data class AppEntry(val label: String, val pkg: String, val icon: Drawable?)

object Launcher {
    val CRUNCHYROLL_PKGS = listOf("com.crunchyroll.crunchyroid")

    // Fire TV: com.amazon.firebat; danach Android-TV- und Smartphone-Varianten.
    val PRIME_PKGS = listOf(
        "com.amazon.firebat",
        "com.amazon.amazonvideo.livingroom",
        "com.amazon.avod.thirdpartyclient",
        "com.amazon.avod",
    )

    fun isFireTv(ctx: Context): Boolean =
        ctx.packageManager.hasSystemFeature("amazon.hardware.fire_tv") ||
            android.os.Build.MANUFACTURER.equals("Amazon", ignoreCase = true)

    fun isInstalled(ctx: Context, pkg: String): Boolean = try {
        ctx.packageManager.getPackageInfo(pkg, 0)
        true
    } catch (e: PackageManager.NameNotFoundException) {
        false
    }

    fun launchIntent(ctx: Context, pkg: String): Intent? {
        val pm = ctx.packageManager
        return pm.getLeanbackLaunchIntentForPackage(pkg) ?: pm.getLaunchIntentForPackage(pkg)
    }

    fun packagesFor(tile: Tile): List<String> = when (tile.type) {
        TileType.CRUNCHYROLL -> CRUNCHYROLL_PKGS
        TileType.PRIME -> PRIME_PKGS
        TileType.APP -> listOf(tile.pkg)
        TileType.WEB -> emptyList()
    }

    fun installedPackage(ctx: Context, tile: Tile): String? =
        packagesFor(tile).firstOrNull { isInstalled(ctx, it) && launchIntent(ctx, it) != null }

    fun storePackage(ctx: Context, tile: Tile): String = when (tile.type) {
        TileType.PRIME -> if (isFireTv(ctx)) "com.amazon.firebat" else "com.amazon.amazonvideo.livingroom"
        else -> packagesFor(tile).firstOrNull() ?: ""
    }

    fun open(activity: Activity, tile: Tile) {
        when (tile.type) {
            TileType.WEB -> BrowserActivity.open(activity, tile.url, tile.name, tile.color)
            else -> {
                val pkg = installedPackage(activity, tile)
                val intent = pkg?.let { launchIntent(activity, it) }
                if (intent != null) {
                    try {
                        activity.startActivity(intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                        return
                    } catch (e: Exception) { /* weiter zum Appstore */ }
                }
                activity.toast("${tile.name} ist nicht installiert – öffne den Appstore …")
                openStore(activity, storePackage(activity, tile))
            }
        }
    }

    fun openStore(activity: Activity, pkg: String) {
        val candidates = listOf(
            "amzn://apps/android?p=$pkg",
            "market://details?id=$pkg",
            "https://www.amazon.de/gp/mas/dl/android?p=$pkg",
        )
        for (u in candidates) {
            try {
                activity.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(u)).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                return
            } catch (e: ActivityNotFoundException) {
            } catch (e: Exception) {
            }
        }
        activity.toast("Kein App-Store gefunden.")
    }

    fun openExternal(activity: Activity, url: String) {
        try {
            activity.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(url)).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
        } catch (e: Exception) {
            activity.toast("Kein externer Browser installiert (z. B. Silk oder Firefox).")
        }
    }

    /** Alle startbaren Apps (Leanback- und normale Launcher-Einträge). */
    fun installedApps(ctx: Context): List<AppEntry> {
        val pm = ctx.packageManager
        val seen = HashSet<String>()
        val out = ArrayList<AppEntry>()
        for (cat in listOf(Intent.CATEGORY_LEANBACK_LAUNCHER, Intent.CATEGORY_LAUNCHER)) {
            val q = Intent(Intent.ACTION_MAIN).addCategory(cat)
            for (ri in pm.queryIntentActivities(q, 0)) {
                val pkg = ri.activityInfo.packageName
                if (pkg == ctx.packageName || !seen.add(pkg)) continue
                out.add(AppEntry(ri.loadLabel(pm).toString(), pkg, try { ri.loadIcon(pm) } catch (e: Exception) { null }))
            }
        }
        return out.sortedBy { it.label.lowercase() }
    }

    fun appIcon(ctx: Context, pkg: String): Drawable? = try {
        val pm = ctx.packageManager
        val info = pm.getApplicationInfo(pkg, 0)
        (if (android.os.Build.VERSION.SDK_INT >= 22) info.loadBanner(pm) else null) ?: info.loadIcon(pm)
    } catch (e: Exception) {
        null
    }
}
