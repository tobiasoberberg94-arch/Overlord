package de.overlord.tv

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.view.KeyEvent
import java.util.concurrent.Executors

/** Jellyfin-Bibliothek im gleichen Reihen-Layout wie die Startseite. */
class LibraryActivity : Activity() {
    companion object {
        private const val K_MODE = "mode"
        private const val K_ID = "id"
        private const val K_NAME = "name"

        fun openFolder(ctx: Context, id: String, name: String) =
            ctx.startActivity(Intent(ctx, LibraryActivity::class.java).putExtra(K_MODE, "folder").putExtra(K_ID, id).putExtra(K_NAME, name))

        fun openSeries(ctx: Context, id: String, name: String) =
            ctx.startActivity(Intent(ctx, LibraryActivity::class.java).putExtra(K_MODE, "series").putExtra(K_ID, id).putExtra(K_NAME, name))
    }

    private lateinit var rows: RowsView
    private val io = Executors.newSingleThreadExecutor()
    private var mode = "home"
    private var targetId = ""
    private var name = ""
    private var loadedOnce = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        rows = RowsView(this)
        setContentView(rows)
        mode = intent.getStringExtra(K_MODE) ?: "home"
        targetId = intent.getStringExtra(K_ID) ?: ""
        name = intent.getStringExtra(K_NAME) ?: "Jellyfin"
        rows.setMessage("Lade …")
    }

    override fun onResume() {
        super.onResume()
        // Fortschritt kann sich im Player geändert haben → neu laden
        load()
    }

    private fun load() {
        io.execute {
            val result = try {
                when (mode) {
                    "folder" -> loadFolder()
                    "series" -> loadSeries()
                    else -> loadHome()
                }
            } catch (e: Exception) {
                null
            }
            runOnUiThread {
                if (isFinishing) return@runOnUiThread
                if (result == null) {
                    rows.setMessage("Jellyfin nicht erreichbar (${hostOf(Jellyfin.server)}). Zurück drücken.")
                    return@runOnUiThread
                }
                rows.setMessage(if (result.isEmpty()) "Keine Inhalte gefunden." else null)
                rows.setRows(result, if (loadedOnce) rows.focusedItem?.id else null)
                loadedOnce = true
            }
        }
    }

    private fun loadHome(): List<RowData> {
        val out = ArrayList<RowData>()
        val resume = Jellyfin.resume()
        if (resume.isNotEmpty()) out.add(RowData("Weiterschauen", resume.map { card(it, "r") }))
        val next = Jellyfin.nextUp()
        if (next.isNotEmpty()) out.add(RowData("Als Nächstes", next.map { card(it, "n") }))
        val views = Jellyfin.views()
        out.add(RowData("Bibliotheken", views.map { v ->
            CardItem(
                id = "view:" + v.id, title = v.name, color = Brand.colorFor(v.id),
                info = "Bibliothek",
                description = "Alle Titel in „${v.name}“ anzeigen.",
                imageUrls = listOf(Jellyfin.image(v.id, "Primary")),
                onClick = { openFolder(this, v.id, v.name) },
            )
        }))
        for (v in views) {
            if (v.collectionType != "" && v.collectionType != "movies" && v.collectionType != "tvshows" && v.collectionType != "homevideos" && v.collectionType != "mixed") continue
            val latest = try { Jellyfin.latest(v.id) } catch (e: Exception) { emptyList() }
            if (latest.isEmpty()) continue
            val cards = latest.map { card(it, "l" + v.id) }.toMutableList()
            cards.add(CardItem(
                id = "all:" + v.id, title = "Alle anzeigen", bigLabel = "→", color = Brand.SURFACE,
                info = v.name, description = "Alle Titel in „${v.name}“.",
                onClick = { openFolder(this, v.id, v.name) },
            ))
            out.add(RowData("Neu in ${v.name}", cards))
        }
        return out
    }

    private fun loadFolder(): List<RowData> {
        val all = Jellyfin.all(targetId)
        if (all.isEmpty()) return emptyList()
        return all.chunked(12).map { chunk ->
            val a = chunk.first().name.take(1).uppercase()
            val b = chunk.last().name.take(1).uppercase()
            RowData(if (a == b) "$name · $a" else "$name · $a – $b", chunk.map { card(it, "f") })
        }
    }

    private fun loadSeries(): List<RowData> {
        val seasons = Jellyfin.seasons(targetId)
        return seasons.map { s ->
            val eps = Jellyfin.episodes(targetId, s.id)
            RowData("$name · ${s.name}", eps.map { card(it, "s") })
        }
    }

    private fun card(i: Jellyfin.Item, prefix: String): CardItem {
        val progress = when {
            i.playedPercent > 0 -> (i.playedPercent / 100).toFloat()
            i.positionSec > 0 && i.runtimeSec > 0 -> (i.positionSec / i.runtimeSec).toFloat()
            else -> -1f
        }
        val badge = when {
            i.played -> "✓ gesehen"
            i.positionSec > 0 && i.runtimeSec > 0 -> formatRemaining(i.runtimeSec - i.positionSec)
            else -> null
        }
        return CardItem(
            id = "$prefix:${i.id}",
            title = i.displayTitle,
            info = i.infoLine,
            description = i.overview.ifBlank { if (i.type == "Series") "Serie" else "" },
            color = Brand.colorFor(i.seriesId.ifBlank { i.id }),
            imageUrls = Jellyfin.cardImages(i),
            heroImageUrls = Jellyfin.heroImages(i),
            progress = progress,
            badge = badge,
            onClick = { open(i, false) },
            onMenu = { menu(i) },
        )
    }

    private fun open(i: Jellyfin.Item, fromStart: Boolean) {
        when {
            i.playable -> PlayerActivity.startJellyfin(this, i.id, fromStart)
            i.type == "Series" -> openSeries(this, i.id, i.name)
            i.type == "Season" -> openSeries(this, i.seriesId, i.seriesName)
            else -> openFolder(this, i.id, i.name)
        }
    }

    private fun menu(i: Jellyfin.Item) {
        val actions = ArrayList<Pair<String, () -> Unit>>()
        if (i.playable) {
            actions.add((if (i.positionSec > 0) "Weiterschauen" else "Abspielen") to { open(i, false) })
            actions.add("Von vorne beginnen" to { open(i, true) })
        } else actions.add("Öffnen" to { open(i, false) })
        if (i.type == "Episode" && i.seriesId.isNotBlank()) actions.add("Zur Serie" to { openSeries(this, i.seriesId, i.seriesName) })
        Dialogs.list(this, i.displayTitle, actions.map { it.first }) { actions[it].second() }
    }

    override fun dispatchKeyEvent(event: KeyEvent): Boolean {
        if (event.keyCode == KeyEvent.KEYCODE_MENU) {
            if (event.action == KeyEvent.ACTION_UP) (currentFocus as? CardView)?.item?.onMenu?.invoke()
            return true
        }
        return super.dispatchKeyEvent(event)
    }

    override fun onDestroy() {
        io.shutdownNow()
        super.onDestroy()
    }
}
