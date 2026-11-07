package de.overlord.tv

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.view.KeyEvent
import java.util.concurrent.Executors

/**
 * Globale Suche: durchsucht Kacheln, Weiterschauen und Jellyfin – und schickt den Begriff
 * auf Wunsch direkt an die Suche deiner Webseiten-Kacheln.
 */
class SearchActivity : Activity() {
    companion object {
        private const val K_Q = "q"

        fun open(ctx: Context, q: String? = null) {
            val i = Intent(ctx, SearchActivity::class.java)
            if (q != null) i.putExtra(K_Q, q)
            if (ctx !is Activity) i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            ctx.startActivity(i)
        }
    }

    private lateinit var rows: RowsView
    private val io = Executors.newSingleThreadExecutor()
    private var query = ""

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        rows = RowsView(this)
        setContentView(rows)
        val q = intent.getStringExtra(K_Q)
        if (q.isNullOrBlank()) ask(first = true) else search(q)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        intent.getStringExtra(K_Q)?.takeIf { it.isNotBlank() }?.let { search(it) }
    }

    private fun ask(first: Boolean = false) {
        val voice: (() -> Unit)? = if (Voice.available(this)) ({ if (!Voice.start(this, "Wonach suchen?")) tvToast("Spracheingabe nicht verfügbar", R.drawable.ic_mic) }) else null
        Tv.input(this, "Suchen", "Titel, Serie, Webseite …", query, icon = R.drawable.ic_search, okLabel = "Suchen", voice = voice,
            message = "Durchsucht Kacheln, Weiterschauen und Jellyfin – und auf Wunsch die Suche deiner Webseiten.") { q ->
            if (q.isBlank()) { if (first) finish() } else search(q)
        }
    }

    @Deprecated("startActivityForResult")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        @Suppress("DEPRECATION")
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == Voice.REQUEST && resultCode == RESULT_OK) Voice.result(data)?.let { search(it) }
    }

    private fun search(q: String) {
        query = q.trim()
        rows.setMessage("Suche nach „$query“ …")
        io.execute {
            val jf = if (Jellyfin.isConfigured()) try { Jellyfin.search(query) } catch (e: Exception) { emptyList() } else emptyList()
            runOnUiThread {
                if (isFinishing) return@runOnUiThread
                rows.setMessage(null)
                rows.setRows(buildRows(jf), null)
            }
        }
    }

    private fun matches(s: String) = s.contains(query, ignoreCase = true)

    private fun buildRows(jf: List<Jellyfin.Item>): List<RowData> {
        val out = ArrayList<RowData>()
        val tiles = TileStore.load(this)

        val actions = ArrayList<CardItem>()
        actions.add(CardItem(
            id = "new", title = "Neue Suche", iconRes = R.drawable.ic_search, color = Brand.ACCENT,
            eyebrow = "SUCHE", chips = listOf("„$query“"),
            description = "Einen anderen Begriff suchen – per Bildschirmtastatur, Mikrofon oder vom Handy.",
            okHint = "Neue Suche", onClick = { ask() },
        ))
        actions.add(CardItem(
            id = "web", title = "Im Web suchen", iconRes = R.drawable.ic_globe, color = 0xFF1F2937.toInt(),
            eyebrow = "SUCHE", chips = listOf("DuckDuckGo", "„$query“"),
            description = "Sucht „$query“ im Web – im eingebauten Browser mit Werbeblocker.",
            okHint = "Suchen", onClick = { BrowserActivity.open(this, "https://duckduckgo.com/?q=" + Uri.encode(query), "Suche") },
        ))
        out.add(RowData("Suche: „$query“", actions))

        val webTiles = tiles.filter { it.type == TileType.WEB }
        if (webTiles.isNotEmpty()) out.add(RowData("Auf deinen Seiten suchen", webTiles.map { t ->
            val meta = SiteMeta.get(t.url)
            CardItem(
                id = "site:" + t.id, title = "Auf ${t.name}", subtitle = "„$query“",
                eyebrow = "WEBSEITEN-SUCHE", chips = listOf(hostOf(t.url), "„$query“"),
                description = "Öffnet ${t.name} und schickt „$query“ an die Suche der Seite.",
                color = t.color, imageUrls = listOfNotNull(meta?.image?.takeIf { it.isNotBlank() }),
                logoUrls = SiteMeta.iconUrls(t.url), okHint = "Suchen",
                onClick = { BrowserActivity.open(this, t.url, t.name, t.color, search = query) },
            )
        }))

        val tileHits = tiles.filter { matches(it.name) || matches(it.url) || matches(it.description) }
        if (tileHits.isNotEmpty()) out.add(RowData("Kacheln", tileHits.map { t ->
            CardItem(
                id = "tile:" + t.id, title = t.name, subtitle = if (t.type == TileType.WEB) hostOf(t.url) else "App",
                eyebrow = "KACHEL", chips = listOf(if (t.type == TileType.WEB) hostOf(t.url) else "App"),
                description = t.description, color = t.color,
                logoUrls = if (t.type == TileType.WEB) SiteMeta.iconUrls(t.url) else emptyList(),
                icon = if (t.type != TileType.WEB) Launcher.installedPackage(this, t)?.let { Launcher.appIcon(this, it) } else null,
                iconRes = if (t.type != TileType.WEB) R.drawable.ic_tv else null,
                onClick = { Launcher.open(this, t) },
            )
        }))

        val cont = ContinueStore.all(this).filter { matches(it.title) || matches(it.url) }
        if (cont.isNotEmpty()) out.add(RowData("Weiterschauen", cont.map { e ->
            CardItem(
                id = "cont:" + e.key, title = e.title, subtitle = hostOf(e.url), eyebrow = "WEITERSCHAUEN",
                chips = listOf(hostOf(e.url), formatRemaining(e.remaining)), color = e.color,
                imageUrls = listOf(e.image).filter { it.isNotBlank() }, progress = e.fraction,
                progressText = formatRemaining(e.remaining), okHint = "Weiterschauen",
                onClick = { BrowserActivity.open(this, e.url, e.title, e.color, resume = e.position) },
            )
        }))

        if (jf.isNotEmpty()) out.add(RowData("Jellyfin", jf.map { i ->
            CardItem(
                id = "jf:" + i.id, title = i.displayTitle,
                subtitle = if (i.type == "Episode") i.seriesName else (if (i.year > 0) i.year.toString() else ""),
                eyebrow = when (i.type) { "Movie" -> "FILM"; "Series" -> "SERIE"; "Episode" -> "FOLGE"; else -> "JELLYFIN" },
                chips = i.infoLine.split(" · ").filter { it.isNotBlank() }, description = i.overview,
                color = Brand.colorFor(i.seriesId.ifBlank { i.id }),
                imageUrls = Jellyfin.cardImages(i), heroImageUrls = Jellyfin.heroImages(i),
                progress = if (i.playedPercent > 0) (i.playedPercent / 100).toFloat() else -1f,
                okHint = if (i.playable) "Abspielen" else "Öffnen",
                onClick = {
                    when {
                        i.playable -> PlayerActivity.startJellyfin(this, i.id, false)
                        i.type == "Series" -> LibraryActivity.openSeries(this, i.id, i.name)
                        else -> LibraryActivity.openFolder(this, i.id, i.name)
                    }
                },
            )
        }))
        return out
    }

    override fun dispatchKeyEvent(event: KeyEvent): Boolean {
        if (event.keyCode == KeyEvent.KEYCODE_SEARCH || event.keyCode == KeyEvent.KEYCODE_MENU) {
            if (event.action == KeyEvent.ACTION_UP) ask()
            return true
        }
        return super.dispatchKeyEvent(event)
    }

    override fun onDestroy() {
        io.shutdownNow()
        super.onDestroy()
    }
}
