package de.overlord.tv

import android.app.Activity
import android.content.Intent
import android.os.Bundle
import android.view.Gravity
import android.view.KeyEvent
import android.view.View
import android.view.ViewGroup
import android.widget.BaseAdapter
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.TextView

class MainActivity : Activity() {
    private lateinit var rows: RowsView
    private var movingId: String? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        rows = RowsView(this)
        setContentView(rows)
        handleIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleIntent(intent)
    }

    /** Direkt-Links: „open_url“ öffnet eine Adresse, „open_library“ die Jellyfin-Bibliothek. */
    private fun handleIntent(i: Intent?) {
        if (i == null) return
        if (i.getBooleanExtra("overlord_demo", false)) Demo.seed(this)
        i.getStringExtra("open_url")?.takeIf { it.isNotBlank() }?.let { BrowserActivity.open(this, normalizeUrl(it), hostOf(it)) }
        if (i.getBooleanExtra("open_library", false)) startActivity(Intent(this, LibraryActivity::class.java))
        i.removeExtra("open_url"); i.removeExtra("open_library"); i.removeExtra("overlord_demo")
    }

    override fun onResume() {
        super.onResume()
        refresh()
    }

    private fun refresh(focusId: String? = rows.focusedItem?.id) {
        val list = ArrayList<RowData>()

        // 1. Weiterschauen
        val cont = ContinueStore.all(this)
        if (cont.isNotEmpty()) {
            list.add(RowData("Weiterschauen", cont.map { e -> continueCard(e) }))
        }

        // 2. Anbieter & eigene Kacheln
        val tiles = TileStore.load(this)
        val tileCards = tiles.map { tileCard(it) }.toMutableList()
        tileCards.add(CardItem(
            id = "add", title = "Hinzufügen", bigLabel = "+", color = Brand.SURFACE,
            info = "Eigene Kachel",
            description = "Füge eine beliebige Webseite (öffnet im eingebauten Browser) oder eine installierte App als Kachel hinzu.",
            onClick = { addTile() },
        ))
        tileCards.add(CardItem(
            id = "url", title = "Webseite öffnen", bigLabel = "🌐", color = 0xFF1F2937.toInt(),
            info = "Adresse oder Suchbegriff eingeben",
            description = "Öffnet eine Adresse im eingebauten Browser mit Werbeblocker, Link-Steuerung und Weiterschauen.",
            onClick = { openUrlDialog() },
        ))
        list.add(RowData("Meine Anbieter", tileCards))

        // 3. Medienbibliothek (Jellyfin)
        list.add(RowData("Medienbibliothek", listOf(jellyfinCard())))

        // 4. Einstellungen
        list.add(RowData("Einstellungen", settingsCards()))

        rows.setRows(list, focusId)
    }

    // ---------------------------------------------------------------- Karten

    private fun continueCard(e: ContinueEntry) = CardItem(
        id = "cont:" + e.key,
        title = e.title.ifBlank { hostOf(e.url) },
        info = "${hostOf(e.url)} · ${formatTime(e.position)} von ${formatTime(e.duration)} · ${formatRemaining(e.remaining)}",
        description = "OK: an der letzten Stelle weiterschauen. ☰ oder OK lange drücken: weitere Optionen.",
        color = e.color,
        progress = e.fraction,
        badge = formatRemaining(e.remaining),
        onClick = { resume(e, false) },
        onMenu = {
            Dialogs.list(this, e.title.ifBlank { hostOf(e.url) }, listOf("Weiterschauen", "Von vorne beginnen", "Aus der Liste entfernen")) { which ->
                when (which) {
                    0 -> resume(e, false)
                    1 -> resume(e, true)
                    2 -> { ContinueStore.remove(this, e.key); refresh() }
                }
            }
        },
    )

    private fun resume(e: ContinueEntry, fromStart: Boolean) {
        val pos = if (fromStart) 0.0 else e.position
        if (e.mediaUrl.isNotBlank()) {
            // Zuvor im nativen Player gesehen: direkt dort fortsetzen (Fallback: Webseite)
            PlayerActivity.startWeb(this, e.mediaUrl, e.title, e.url, e.referer, pos, e.color)
        } else {
            BrowserActivity.open(this, e.url, e.title, e.color, resume = pos)
        }
    }

    private fun tileCard(t: Tile): CardItem {
        val icon = when (t.type) {
            TileType.WEB -> null
            else -> Launcher.installedPackage(this, t)?.let { Launcher.appIcon(this, it) }
        }
        val info = when (t.type) {
            TileType.WEB -> "Webseite · ${hostOf(t.url)}"
            else -> if (Launcher.installedPackage(this, t) != null) "App · installiert" else "App · nicht installiert – OK öffnet den Appstore"
        }
        val desc = t.description.ifBlank {
            when (t.type) {
                TileType.WEB -> "Öffnet ${hostOf(t.url)} im eingebauten Browser mit Werbe- und Pop-up-Blocker."
                else -> "Startet die App ${t.name}."
            }
        } + "\n☰ oder OK lange drücken: bearbeiten."
        return CardItem(
            id = t.id, title = t.name, info = info, description = desc, color = t.color, icon = icon,
            onClick = { if (movingId == null) Launcher.open(this, t) },
            onMenu = { editTile(t) },
        )
    }

    private fun jellyfinCard(): CardItem {
        val configured = Jellyfin.isConfigured()
        return CardItem(
            id = "jellyfin",
            title = if (configured) "Jellyfin" else "Jellyfin verbinden",
            bigLabel = "▤",
            color = 0xFF6D28D9.toInt(),
            info = if (configured) "Angemeldet als ${Jellyfin.userName} · ${hostOf(Jellyfin.server)}" else "Eigene Filme und Serien",
            description = if (configured)
                "Deine Bibliothek mit Covern, Staffeln, Folgen, Weiterschauen und automatischer nächster Folge."
            else
                "Verbinde deinen Jellyfin-Server, um eigene Mediendateien mit Covern, Staffeln und Folgen anzusehen.",
            onClick = { if (configured) startActivity(Intent(this, LibraryActivity::class.java)) else jellyfinSetup() },
            onMenu = {
                Dialogs.list(this, "Jellyfin", listOf("Bibliothek öffnen", "Server/Anmeldung ändern", "Abmelden")) { w ->
                    when (w) {
                        0 -> if (Jellyfin.isConfigured()) startActivity(Intent(this, LibraryActivity::class.java)) else jellyfinSetup()
                        1 -> jellyfinSetup()
                        2 -> { Jellyfin.logout(); refresh() }
                    }
                }
            },
        )
    }

    private fun settingsCards(): List<CardItem> = listOf(
        CardItem(
            id = "adblock", title = "Werbeblocker", bigLabel = "🛡", color = 0xFF0F766E.toInt(),
            info = "${AdBlock.count} blockierte Domains · ${AdBlock.lastUpdateText(this)}",
            description = "Eingebaute Liste plus StevenBlack-Hosts-Liste, wird wöchentlich im Hintergrund aktualisiert. OK: jetzt aktualisieren.",
            onClick = {
                toast("Aktualisiere Hosts-Liste …")
                Thread {
                    val ok = AdBlock.update(applicationContext)
                    runOnUiThread { toast(if (ok) "Werbeblocker aktualisiert: ${AdBlock.count} Domains" else "Aktualisierung fehlgeschlagen"); refresh() }
                }.start()
            },
        ),
        CardItem(
            id = "keys", title = "Tastenbelegung", bigLabel = "⌨", color = 0xFF334155.toInt(),
            info = "Bedienung mit der Fire-TV-Fernbedienung",
            description = "Zeigt alle Tasten für Startseite, Browser und Player.",
            onClick = { Dialogs.info(this, "Tastenbelegung", HELP) },
        ),
        CardItem(
            id = "restore", title = "Feste Kacheln", bigLabel = "↺", color = 0xFF475569.toInt(),
            info = "Crunchyroll und Prime Video wiederherstellen",
            description = "Stellt entfernte feste Kacheln wieder her.",
            onClick = { TileStore.restoreBuiltins(this); toast("Wiederhergestellt"); refresh() },
        ),
        CardItem(
            id = "clearcont", title = "Weiterschauen leeren", bigLabel = "✕", color = 0xFF7F1D1D.toInt(),
            info = "Alle Einträge entfernen",
            description = "Entfernt alle Einträge aus der Reihe „Weiterschauen“.",
            onClick = {
                Dialogs.builder(this).setTitle("Weiterschauen leeren?")
                    .setPositiveButton("Leeren") { _, _ -> ContinueStore.clear(this); refresh() }
                    .setNegativeButton("Abbrechen", null).show()
            },
        ),
        CardItem(
            id = "about", title = "Info", bigLabel = "ℹ", color = 0xFF1E1B4B.toInt(),
            info = "Overlord TV ${BuildConfig.VERSION_NAME}",
            description = "Streaming-Startseite für Fire TV. Eigene Marke, eigene Farben.",
            onClick = { Dialogs.info(this, "Overlord TV ${BuildConfig.VERSION_NAME}", "Bündelt Streaming-Anbieter, Webseiten und deine Jellyfin-Bibliothek auf einer Startseite.\n\nWerbeblocker: ${AdBlock.count} Domains, ${AdBlock.lastUpdateText(this)}.") },
        ),
    )

    // ---------------------------------------------------------------- Kacheln bearbeiten

    private fun addTile() {
        Dialogs.list(this, "Kachel hinzufügen", listOf("Webseite", "Installierte App")) { w ->
            if (w == 0) addWebTile() else addAppTile()
        }
    }

    private fun addWebTile() {
        Dialogs.input(this, "Adresse der Webseite", "z. B. example.com", url = true) { raw ->
            if (raw.isBlank()) return@input
            val url = normalizeUrl(raw)
            val suggested = hostOf(url).substringBefore('.').replaceFirstChar { it.uppercase() }
            Dialogs.input(this, "Name der Kachel", "Name", suggested) { name ->
                val t = TileStore.newWeb(name.ifBlank { suggested }, url)
                TileStore.add(this, t)
                refresh(t.id)
            }
        }
    }

    private fun addAppTile() {
        val apps = Launcher.installedApps(this)
        if (apps.isEmpty()) { toast("Keine Apps gefunden"); return }
        val adapter = object : BaseAdapter() {
            override fun getCount() = apps.size
            override fun getItem(p: Int) = apps[p]
            override fun getItemId(p: Int) = p.toLong()
            override fun getView(p: Int, convert: View?, parent: ViewGroup?): View {
                val row = (convert as? LinearLayout) ?: LinearLayout(this@MainActivity).apply {
                    orientation = LinearLayout.HORIZONTAL
                    gravity = Gravity.CENTER_VERTICAL
                    setPadding(dp(20), dp(10), dp(20), dp(10))
                    addView(ImageView(context), LinearLayout.LayoutParams(dp(40), dp(40)))
                    addView(TextView(context).apply { textSize = 17f; setTextColor(Brand.TEXT); setPadding(dp(16), 0, 0, 0) })
                }
                (row.getChildAt(0) as ImageView).setImageDrawable(apps[p].icon)
                (row.getChildAt(1) as TextView).text = apps[p].label
                return row
            }
        }
        Dialogs.builder(this).setTitle("App auswählen")
            .setAdapter(adapter) { _, which ->
                val a = apps[which]
                val color = dominantColor(a.icon)?.let { darken(it, 0.85f) } ?: Brand.colorFor(a.pkg)
                val t = TileStore.newApp(a.label, a.pkg, color)
                TileStore.add(this, t)
                refresh(t.id)
            }
            .setNegativeButton("Abbrechen", null).show()
    }

    private fun editTile(t: Tile) {
        val actions = ArrayList<Pair<String, () -> Unit>>()
        actions.add("Öffnen" to { Launcher.open(this, t) })
        actions.add("Umbenennen" to {
            Dialogs.input(this, "Umbenennen", "Name", t.name) { n -> if (n.isNotBlank()) { t.name = n; TileStore.update(this, t); refresh(t.id) } }
        })
        if (t.type == TileType.WEB) actions.add("URL ändern" to {
            Dialogs.input(this, "URL ändern", "https://…", t.url, url = true) { u -> if (u.isNotBlank()) { t.url = normalizeUrl(u); TileStore.update(this, t); refresh(t.id) } }
        })
        actions.add("Beschreibung ändern" to {
            Dialogs.input(this, "Beschreibung", "Kurzer Text", t.description) { d -> t.description = d; TileStore.update(this, t); refresh(t.id) }
        })
        actions.add("Verschieben" to { startMove(t) })
        actions.add("Farbe ändern" to {
            Dialogs.list(this, "Farbe", Dialogs.colorItems()) { i -> t.color = Brand.PALETTE[i].second; TileStore.update(this, t); refresh(t.id) }
        })
        if (t.type == TileType.WEB) actions.add("Im externen Browser öffnen" to { Launcher.openExternal(this, t.url) })
        if (t.type != TileType.WEB) actions.add("Im Appstore anzeigen" to { Launcher.openStore(this, Launcher.storePackage(this, t)) })
        actions.add("Entfernen" to {
            Dialogs.builder(this).setTitle("„${t.name}“ entfernen?")
                .setMessage(if (t.builtin) "Feste Kacheln lassen sich unter Einstellungen → Feste Kacheln wiederherstellen." else null)
                .setPositiveButton("Entfernen") { _, _ -> TileStore.remove(this, t.id); refresh() }
                .setNegativeButton("Abbrechen", null).show()
        })
        Dialogs.list(this, t.name, actions.map { it.first }) { i -> actions[i].second() }
    }

    private fun startMove(t: Tile) {
        movingId = t.id
        rows.heroOverride = Triple("Verschieben: ${t.name}", "◀ ▶ verschieben · OK oder Zurück zum Beenden", "Bewege die Kachel mit dem Steuerkreuz an die gewünschte Stelle.")
        rows.focusItem(t.id)
    }

    private fun stopMove() {
        val id = movingId
        movingId = null
        rows.heroOverride = null
        refresh(id)
    }

    private fun openUrlDialog() {
        Dialogs.input(this, "Webseite öffnen", "Adresse oder Suchbegriff", url = true) { raw ->
            if (raw.isNotBlank()) BrowserActivity.open(this, normalizeUrl(raw), hostOf(normalizeUrl(raw)), Brand.ACCENT)
        }
    }

    private fun jellyfinSetup() {
        Dialogs.input(this, "Jellyfin-Server", "z. B. http://192.168.1.10:8096", Jellyfin.server.ifBlank { "http://" }, url = true) { srv ->
            if (srv.isBlank()) return@input
            Dialogs.input(this, "Benutzername", "Benutzer", Jellyfin.userName) { user ->
                Dialogs.input(this, "Passwort", "Passwort (leer lassen, falls keins)", password = true) { pass ->
                    toast("Melde an …")
                    Thread {
                        val err = Jellyfin.login(srv, user, pass)
                        runOnUiThread {
                            if (err == null) {
                                toast("Verbunden mit Jellyfin")
                                refresh("jellyfin")
                            } else Dialogs.info(this, "Anmeldung fehlgeschlagen", err)
                        }
                    }.start()
                }
            }
        }
    }

    // ---------------------------------------------------------------- Tasten

    override fun dispatchKeyEvent(event: KeyEvent): Boolean {
        val id = movingId
        if (id != null && event.action == KeyEvent.ACTION_DOWN) {
            when (event.keyCode) {
                KeyEvent.KEYCODE_DPAD_LEFT, KeyEvent.KEYCODE_DPAD_RIGHT -> {
                    val delta = if (event.keyCode == KeyEvent.KEYCODE_DPAD_LEFT) -1 else 1
                    if (TileStore.move(this, id, delta)) {
                        refresh(id)
                        rows.heroOverride = rows.heroOverride
                    }
                    return true
                }
                KeyEvent.KEYCODE_DPAD_CENTER, KeyEvent.KEYCODE_ENTER, KeyEvent.KEYCODE_BACK, KeyEvent.KEYCODE_MENU,
                KeyEvent.KEYCODE_DPAD_UP, KeyEvent.KEYCODE_DPAD_DOWN -> return true
            }
        }
        if (id != null && event.action == KeyEvent.ACTION_UP) {
            when (event.keyCode) {
                KeyEvent.KEYCODE_DPAD_CENTER, KeyEvent.KEYCODE_ENTER, KeyEvent.KEYCODE_BACK, KeyEvent.KEYCODE_MENU -> stopMove()
            }
            return true
        }
        if (event.keyCode == KeyEvent.KEYCODE_MENU && event.action == KeyEvent.ACTION_UP) {
            val card = currentFocus as? CardView
            card?.item?.onMenu?.invoke()
            return true
        }
        return super.dispatchKeyEvent(event)
    }

    companion object {
        val HELP = """
            STARTSEITE
            Steuerkreuz – Karte wählen
            OK – öffnen / starten
            ☰ oder OK lange – Kachel bearbeiten (umbenennen, URL, verschieben, Farbe, entfernen, extern öffnen)

            EINGEBAUTER BROWSER
            ☰ kurz – Modus wechseln: Links → Zeiger → Normal
            ☰ lang (oder OK lang) – Browser-Menü (Schnellsuche, Adresse, Video nativ abspielen, blockierte Seite öffnen …)
            Link-Modus: Steuerkreuz springt zum nächsten Link, OK klickt
            Zeiger-Modus: Steuerkreuz bewegt den Zeiger (halten = schneller), am Rand wird gescrollt
            ⏯ – Play/Pause (auch im iframe-Player)
            ⏪ / ⏩ – 10 s spulen; ohne Video: Seite scrollen
            Zurück – Vollbild verlassen → vorherige Seite → Startseite

            PLAYER-LEISTE (erscheint, sobald ein Video läuft)
            ◀ ▶ – Knopf wählen, OK – ausführen, ▲ oder Zurück – ausblenden

            NATIVER PLAYER / JELLYFIN
            OK oder ⏯ – Play/Pause
            ◀ ▶ oder ⏪ ⏩ – spulen (halten = schneller)
            ▲ ▼ – Infoleiste
            Zurück – beenden (Position wird gespeichert)
        """.trimIndent()
    }
}
