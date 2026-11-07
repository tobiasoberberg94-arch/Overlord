package de.overlord.tv

import android.app.Activity
import android.content.Intent
import android.os.Bundle
import android.view.Gravity
import android.view.KeyEvent
import android.widget.FrameLayout
import android.widget.ImageView
import android.widget.LinearLayout

class MainActivity : Activity() {
    private lateinit var rows: RowsView
    private var movingId: String? = null
    private var refreshPending = false
    private var jfResume: List<Jellyfin.Item> = emptyList()
    private val io = java.util.concurrent.Executors.newSingleThreadExecutor()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        rows = RowsView(this)
        rows.addTopAction(R.drawable.ic_search, "Suchen") { SearchActivity.open(this) }
        rows.addTopAction(R.drawable.ic_phone, "Handy") { showCompanion() }
        val root = FrameLayout(this)
        root.addView(rows)
        setContentView(root)
        if (savedInstanceState == null) showSplash(root)
        handleIntent(intent)
    }

    /** Kurzes Logo-Intro beim Kaltstart. */
    private fun showSplash(root: FrameLayout) {
        val splash = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setBackgroundColor(Brand.BG)
            isClickable = true
        }
        val logo = ImageView(this).apply { setImageResource(R.drawable.ic_logo); scaleX = 0.7f; scaleY = 0.7f; alpha = 0f }
        val word = label("OVERLORD", 30f, Fonts.bold).apply { letterSpacing = 0.45f; alpha = 0f }
        splash.addView(logo, LinearLayout.LayoutParams(dp(120), dp(120)))
        splash.addView(word, LinearLayout.LayoutParams(-2, -2).apply { topMargin = dp(18) })
        root.addView(splash, FrameLayout.LayoutParams(-1, -1))
        logo.animate().alpha(1f).scaleX(1f).scaleY(1f).setDuration(420).start()
        word.animate().alpha(1f).setStartDelay(160).setDuration(380).start()
        splash.postDelayed({
            splash.animate().alpha(0f).setDuration(300).withEndAction { root.removeView(splash) }.start()
        }, 900)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleIntent(intent)
    }

    /** Direkt-Links: „open_url“ öffnet eine Adresse, „open_library“ die Jellyfin-Bibliothek. */
    private fun handleIntent(i: Intent?) {
        if (i == null) return
        if (i.getBooleanExtra("overlord_demo", false)) Demo.seed(this, i.getStringExtra("demo_base"))
        i.getStringExtra("open_url")?.takeIf { it.isNotBlank() }?.let { BrowserActivity.open(this, normalizeUrl(it), hostOf(it)) }
        if (i.getBooleanExtra("open_library", false)) startActivity(Intent(this, LibraryActivity::class.java))
        i.removeExtra("open_url"); i.removeExtra("open_library"); i.removeExtra("overlord_demo")
    }

    private val onDataChanged: () -> Unit = { scheduleRefresh() }

    override fun onResume() {
        super.onResume()
        Events.listen(onDataChanged)
        refresh()
        // Alle 6 Stunden nach Updates sehen
        if (System.currentTimeMillis() - Updater.lastCheck > 6 * 3600_000L) io.execute {
            val u = Updater.check()
            if (u != null) runOnUiThread { if (!isFinishing) { tvToast("Update verfügbar: Version ${u.name} – siehe Einstellungen", R.drawable.ic_refresh); scheduleRefresh() } }
        }
        // Jellyfin-„Weiterschauen“ im Hintergrund nachladen
        if (Jellyfin.isConfigured()) io.execute {
            val r = try { Jellyfin.resume() } catch (e: Exception) { null }
            if (r != null) runOnUiThread { if (!isFinishing && r.map { it.id } != jfResume.map { it.id }) { jfResume = r; scheduleRefresh() } }
        } else jfResume = emptyList()
    }

    override fun onPause() {
        Events.unlisten(onDataChanged)
        super.onPause()
    }

    /** Handy-Fernbedienung einschalten und QR-Code zeigen. */
    private fun showCompanion() {
        PhoneRemote.enabled = true
        PhoneRemote.start()
        rows.postDelayed({
            val url = PhoneRemote.url()
            if (url == null) {
                Tv.info(this, "Kein Netzwerk", "Der Fernseher ist mit keinem WLAN/LAN verbunden. Die Handy-Fernbedienung braucht dasselbe Heimnetz wie dein Handy.", R.drawable.ic_warning)
            } else {
                Tv.qr(this, url, PhoneRemote.pin,
                    onNewPin = { PhoneRemote.newPin(); showCompanion() },
                    onDisable = { PhoneRemote.enabled = false; PhoneRemote.stop(); tvToast("Handy-Fernbedienung ausgeschaltet", R.drawable.ic_phone); refresh() })
            }
            refresh()
        }, 300)
    }

    /** Mehrere Aktualisierungen kurz hintereinander zusammenfassen (z. B. wenn Artwork eintrifft). */
    private fun scheduleRefresh() {
        if (refreshPending) return
        refreshPending = true
        rows.postDelayed({ refreshPending = false; if (movingId == null) refresh() }, 400)
    }

    private fun refresh(focusId: String? = rows.focusedItem?.id) {
        val list = ArrayList<RowData>()

        // 1. Weiterschauen (Web-Videos und Jellyfin, nach Zeit sortiert)
        val cont = ContinueStore.all(this)
        val mixed = (cont.map { it.updated to continueCard(it) } + jfResume.map { it.lastPlayed to jellyfinResumeCard(it) })
            .sortedByDescending { it.first }.map { it.second }
        if (mixed.isNotEmpty()) list.add(RowData("Weiterschauen", mixed))

        // 2. Anbieter & eigene Kacheln
        val tiles = TileStore.load(this)
        val tileCards = tiles.map { tileCard(it) }.toMutableList()
        tileCards.add(CardItem(
            id = "add", title = "Hinzufügen", iconRes = R.drawable.ic_add, dashed = true, color = Brand.SURFACE2,
            eyebrow = "NEU", chips = listOf("Webseite", "App"),
            description = "Füge eine beliebige Webseite (öffnet im eingebauten Browser mit Werbeblocker) oder eine installierte App als Kachel hinzu.",
            okHint = "Hinzufügen",
            onClick = { addTile() },
        ))
        tileCards.add(CardItem(
            id = "url", title = "Webseite öffnen", iconRes = R.drawable.ic_globe, color = 0xFF1F2937.toInt(),
            eyebrow = "BROWSER", chips = listOf("Adresse", "Suchbegriff"),
            description = "Öffnet eine Adresse im eingebauten Browser – mit Werbe- und Pop-up-Blocker, Link-Steuerung, Player-Leiste und Weiterschauen.",
            okHint = "Adresse eingeben",
            onClick = { openUrlDialog() },
        ))
        list.add(RowData("Meine Anbieter", tileCards))

        // 3. Zuletzt besucht (ohne Seiten, die schon Kacheln sind)
        val tileHosts = tiles.filter { it.type == TileType.WEB }.map { baseDomain(hostOf(it.url)) }.toSet()
        val recent = History.all().filter { baseDomain(it.host) !in tileHosts }.take(12)
        if (recent.isNotEmpty()) list.add(RowData("Zuletzt besucht", recent.map { historyCard(it) }))

        // 3. Medienbibliothek
        list.add(RowData("Medienbibliothek", listOf(jellyfinCard())))

        // 4. Einstellungen
        list.add(RowData("Einstellungen", settingsCards()))

        rows.setRows(list, focusId)

        // Artwork der Webseiten im Hintergrund nachladen
        tiles.filter { it.type == TileType.WEB }.forEach { t ->
            SiteMeta.ensure(t.url) { meta ->
                val c = meta.themeColor
                if (t.colorAuto && c != null) {
                    t.color = tameColor(c)
                    TileStore.update(this, t)
                }
                scheduleRefresh()
            }
        }
        cont.forEach { e -> if (e.image.isBlank()) SiteMeta.ensure(e.url) { scheduleRefresh() } }
        recent.forEach { h -> SiteMeta.ensure(h.url) { scheduleRefresh() } }
    }

    // ---------------------------------------------------------------- Karten

    private fun continueCard(e: ContinueEntry): CardItem {
        val meta = SiteMeta.get(e.url)
        val image = e.image.ifBlank { meta?.image ?: "" }
        val pct = (e.fraction * 100).toInt()
        return CardItem(
            id = "cont:" + e.key,
            title = e.title.ifBlank { hostOf(e.url) },
            subtitle = hostOf(e.url),
            eyebrow = "WEITERSCHAUEN",
            chips = listOf(hostOf(e.url), "${formatTime(e.position)} von ${formatTime(e.duration)}") + (if (e.mediaUrl.isNotBlank()) listOf("Nativer Player") else emptyList()),
            description = "Setzt das Video an der letzten Stelle fort – auch wenn der Player in einem eingebetteten Fenster (iframe) steckt.",
            color = e.color,
            imageUrls = listOf(image).filter { it.isNotBlank() },
            logoUrls = if (image.isNotBlank()) SiteMeta.iconUrls(e.url) else emptyList(),
            progress = e.fraction,
            progressText = "${formatRemaining(e.remaining)} · $pct %",
            badge = formatRemaining(e.remaining),
            okHint = "Weiterschauen",
            onClick = { resume(e, false) },
            onMenu = {
                Tv.menu(this, e.title.ifBlank { hostOf(e.url) }, listOf(
                    MenuEntry("Weiterschauen", R.drawable.ic_play, "Ab ${formatTime(e.position)}") { resume(e, false) },
                    MenuEntry("Von vorne beginnen", R.drawable.ic_replay) { resume(e, true) },
                    MenuEntry("Webseite öffnen", R.drawable.ic_globe, hostOf(e.url)) { BrowserActivity.open(this, e.url, e.title, e.color) },
                    MenuEntry("Aus der Liste entfernen", R.drawable.ic_delete, danger = true) { ContinueStore.remove(this, e.key); refresh() },
                ), subtitle = "${formatRemaining(e.remaining)} · $pct % gesehen", eyebrow = "WEITERSCHAUEN")
            },
        )
    }

    private fun jellyfinResumeCard(i: Jellyfin.Item): CardItem {
        val frac = if (i.runtimeSec > 0) (i.positionSec / i.runtimeSec).toFloat() else (i.playedPercent / 100).toFloat()
        return CardItem(
            id = "jfr:" + i.id, title = i.displayTitle,
            subtitle = if (i.type == "Episode") i.seriesName else "Jellyfin",
            eyebrow = "WEITERSCHAUEN · JELLYFIN",
            chips = listOf("Jellyfin") + i.infoLine.split(" · ").filter { it.isNotBlank() }.take(3),
            description = i.overview,
            color = Brand.colorFor(i.seriesId.ifBlank { i.id }),
            imageUrls = Jellyfin.cardImages(i), heroImageUrls = Jellyfin.heroImages(i),
            progress = frac.coerceIn(0f, 1f),
            progressText = if (i.runtimeSec > 0) "${formatRemaining(i.runtimeSec - i.positionSec)} · ${(frac * 100).toInt()} %" else "",
            badge = if (i.runtimeSec > 0) formatRemaining(i.runtimeSec - i.positionSec) else null,
            okHint = "Weiterschauen",
            onClick = { PlayerActivity.startJellyfin(this, i.id, false) },
            onMenu = {
                Tv.menu(this, i.displayTitle, listOfNotNull(
                    MenuEntry("Weiterschauen", R.drawable.ic_play, "Ab ${formatTime(i.positionSec)}") { PlayerActivity.startJellyfin(this, i.id, false) },
                    MenuEntry("Von vorne beginnen", R.drawable.ic_replay) { PlayerActivity.startJellyfin(this, i.id, true) },
                    if (i.type == "Episode" && i.seriesId.isNotBlank()) MenuEntry("Zur Serie", R.drawable.ic_library, i.seriesName) { LibraryActivity.openSeries(this, i.seriesId, i.seriesName) } else null,
                ), subtitle = i.infoLine, eyebrow = "JELLYFIN")
            },
        )
    }

    private fun historyCard(h: History.Entry): CardItem {
        val meta = SiteMeta.get(h.url)
        val image = meta?.image ?: ""
        val color = meta?.themeColor?.let { tameColor(it) } ?: Brand.colorFor(h.host)
        return CardItem(
            id = "hist:" + h.url, title = h.title.take(60), subtitle = h.host,
            eyebrow = "ZULETZT BESUCHT",
            chips = listOf(h.host, android.text.format.DateUtils.getRelativeTimeSpanString(h.time).toString()),
            description = meta?.description?.takeIf { it.isNotBlank() } ?: "Zuletzt geöffnete Seite im eingebauten Browser.",
            color = color,
            imageUrls = listOf(image).filter { it.isNotBlank() },
            logoUrls = SiteMeta.iconUrls(h.url),
            heroImageUrls = listOf(image).filter { it.isNotBlank() },
            okHint = "Öffnen",
            onClick = { BrowserActivity.open(this, h.url, h.title, color) },
            onMenu = {
                Tv.menu(this, h.title, listOf(
                    MenuEntry("Öffnen", R.drawable.ic_globe) { BrowserActivity.open(this, h.url, h.title, color) },
                    MenuEntry("Als Kachel speichern", R.drawable.ic_bookmark) {
                        val t = TileStore.newWeb(h.title.take(30).ifBlank { h.host }, h.url)
                        TileStore.add(this, t); refresh(t.id)
                    },
                    MenuEntry("Im externen Browser öffnen", R.drawable.ic_open_external) { Launcher.openExternal(this, h.url) },
                    MenuEntry("Aus dem Verlauf entfernen", R.drawable.ic_delete, danger = true) { History.remove(h.url); refresh() },
                ), subtitle = h.host, eyebrow = "ZULETZT BESUCHT")
            },
        )
    }

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
        if (t.type == TileType.WEB) {
            val meta = SiteMeta.get(t.url)
            val image = meta?.image ?: ""
            val protected = !AdBlock.isAllowed(this, hostOf(t.url))
            return CardItem(
                id = t.id, title = t.name, subtitle = hostOf(t.url),
                eyebrow = "WEBSEITE",
                chips = listOf(hostOf(t.url), if (protected) "Werbeblocker aktiv" else "Schutz aus"),
                description = t.description.ifBlank { meta?.description?.takeIf { it.isNotBlank() } ?: "Öffnet ${hostOf(t.url)} im eingebauten Browser mit Werbe- und Pop-up-Blocker." },
                color = t.color,
                imageUrls = listOf(image).filter { it.isNotBlank() },
                logoUrls = SiteMeta.iconUrls(t.url),
                heroImageUrls = listOf(image).filter { it.isNotBlank() },
                okHint = "Öffnen",
                onClick = { if (movingId == null) Launcher.open(this, t) },
                onMenu = { editTile(t) },
            )
        }
        val pkg = Launcher.installedPackage(this, t)
        val icon = pkg?.let { Launcher.appIcon(this, it) }
        return CardItem(
            id = t.id, title = t.name,
            eyebrow = if (t.builtin) "STREAMING-APP" else "APP",
            chips = listOf(if (pkg != null) "Installiert" else "Nicht installiert") + (if (t.builtin) listOf("Feste Kachel") else emptyList()),
            description = t.description.ifBlank { "Startet die App ${t.name}." },
            color = t.color, icon = icon,
            iconRes = if (icon == null) R.drawable.ic_tv else null,
            okHint = if (pkg != null) "Starten" else "Im Appstore öffnen",
            onClick = { if (movingId == null) Launcher.open(this, t) },
            onMenu = { editTile(t) },
        )
    }

    private fun jellyfinCard(): CardItem {
        val configured = Jellyfin.isConfigured()
        return CardItem(
            id = "jellyfin",
            title = if (configured) "Jellyfin" else "Jellyfin verbinden",
            subtitle = if (configured) hostOf(Jellyfin.server) else "",
            iconRes = R.drawable.ic_library,
            color = 0xFF5B21B6.toInt(),
            eyebrow = "MEDIENBIBLIOTHEK",
            chips = if (configured) listOf("Angemeldet als ${Jellyfin.userName}", hostOf(Jellyfin.server)) else listOf("Eigene Filme & Serien"),
            description = if (configured)
                "Deine Bibliothek mit Covern, Staffeln, Folgen, Weiterschauen und automatischer nächster Folge."
            else
                "Verbinde deinen Jellyfin-Server, um eigene Filme und Serien mit Covern, Staffeln und Folgen zu sehen.",
            okHint = if (configured) "Bibliothek öffnen" else "Verbinden",
            onClick = { if (configured) startActivity(Intent(this, LibraryActivity::class.java)) else jellyfinSetup() },
            onMenu = {
                Tv.menu(this, "Jellyfin", listOfNotNull(
                    MenuEntry("Bibliothek öffnen", R.drawable.ic_library) { if (Jellyfin.isConfigured()) startActivity(Intent(this, LibraryActivity::class.java)) else jellyfinSetup() },
                    MenuEntry("Server / Anmeldung ändern", R.drawable.ic_edit) { jellyfinSetup() },
                    if (configured) MenuEntry("Abmelden", R.drawable.ic_close, danger = true) { Jellyfin.logout(); refresh() } else null,
                ), subtitle = if (configured) "${Jellyfin.userName} · ${hostOf(Jellyfin.server)}" else null)
            },
        )
    }

    private fun settingsCards(): List<CardItem> = listOfNotNull(
        Updater.available?.let { u ->
            CardItem(
                id = "update", title = "Update ${u.name}", iconRes = R.drawable.ic_refresh, color = Brand.ACCENT,
                eyebrow = "UPDATE VERFÜGBAR", chips = listOf("Installiert: ${BuildConfig.VERSION_NAME}", "Neu: ${u.name}"),
                description = u.notes.ifBlank { "Eine neue Version von Overlord TV ist verfügbar." },
                okHint = "Jetzt installieren",
                onClick = { Updater.runInteractive(this, u) },
            )
        },
        CardItem(
            id = "companion", title = "Handy-Fernbedienung", iconRes = R.drawable.ic_phone, color = 0xFF6D28D9.toInt(),
            eyebrow = "EINSTELLUNGEN",
            chips = if (PhoneRemote.running) listOfNotNull("Aktiv", PhoneRemote.ipAddress()?.let { "$it:${PhoneRemote.port}" }) else listOf("Aus"),
            description = "Mit dem Handy tippen, Links an den Fernseher schicken, Kacheln anlegen und steuern – per QR-Code, ohne App-Installation.",
            okHint = "QR-Code zeigen",
            onClick = { showCompanion() },
        ),
        CardItem(
            id = "adblock", title = "Werbeblocker", iconRes = R.drawable.ic_shield, color = 0xFF0F766E.toInt(),
            eyebrow = "EINSTELLUNGEN",
            chips = listOf("${AdBlock.count} Domains", AdBlock.lastUpdateText(this)),
            description = "Eingebaute Liste plus StevenBlack-Hosts-Liste, wöchentlich im Hintergrund aktualisiert. Pop-ups, Umleitungen und unsichtbare Klickflächen werden ebenfalls blockiert.",
            okHint = "Jetzt aktualisieren",
            onClick = {
                tvToast("Aktualisiere Hosts-Liste …", R.drawable.ic_refresh)
                Thread {
                    val ok = AdBlock.update(applicationContext)
                    runOnUiThread { tvToast(if (ok) "Werbeblocker aktualisiert: ${AdBlock.count} Domains" else "Aktualisierung fehlgeschlagen", R.drawable.ic_shield); refresh() }
                }.start()
            },
        ),
        CardItem(
            id = "keys", title = "Tastenbelegung", iconRes = R.drawable.ic_keyboard, color = 0xFF334155.toInt(),
            eyebrow = "HILFE", chips = listOf("Fernbedienung", "Browser", "Player"),
            description = "Alle Tasten für Startseite, Browser und Player auf einen Blick.",
            onClick = { Tv.info(this, "Tastenbelegung", HELP, R.drawable.ic_keyboard) },
        ),
        CardItem(
            id = "restore", title = "Feste Kacheln", iconRes = R.drawable.ic_replay, color = 0xFF475569.toInt(),
            eyebrow = "EINSTELLUNGEN", chips = listOf("Crunchyroll", "Prime Video"),
            description = "Stellt entfernte feste Kacheln wieder her.",
            okHint = "Wiederherstellen",
            onClick = { TileStore.restoreBuiltins(this); tvToast("Feste Kacheln wiederhergestellt", R.drawable.ic_check); refresh() },
        ),
        CardItem(
            id = "clearcont", title = "Weiterschauen leeren", iconRes = R.drawable.ic_delete, color = 0xFF7F1D1D.toInt(),
            eyebrow = "EINSTELLUNGEN", chips = listOf("${ContinueStore.all(this).size} Einträge"),
            description = "Entfernt alle Einträge aus der Reihe „Weiterschauen“.",
            okHint = "Leeren",
            onClick = {
                Tv.confirm(this, "Weiterschauen leeren?", "Alle Einträge werden entfernt.", "Leeren", danger = true) {
                    ContinueStore.clear(this); refresh()
                }
            },
        ),
        CardItem(
            id = "clearhist", title = "Verlauf leeren", iconRes = R.drawable.ic_history, color = 0xFF3F3F46.toInt(),
            eyebrow = "EINSTELLUNGEN", chips = listOf("${History.all().size} Seiten"),
            description = "Entfernt die Reihe „Zuletzt besucht“ (Cookies und Anmeldungen bleiben erhalten).",
            okHint = "Leeren",
            onClick = { Tv.confirm(this, "Verlauf leeren?", null, "Leeren", danger = true) { History.clear(); refresh() } },
        ),
        CardItem(
            id = "about", title = "Info", iconRes = R.drawable.ic_info, color = 0xFF1E1B4B.toInt(),
            eyebrow = "OVERLORD TV", chips = listOf("Version ${BuildConfig.VERSION_NAME}", if (Updater.available == null) "Aktuell" else "Update verfügbar"),
            description = "Streaming-Startseite für Fire TV mit eigenem Browser, Werbeblocker, Weiterschauen und Jellyfin. OK zeigt Infos, ☰ sucht nach Updates.",
            onMenu = {
                tvToast("Suche nach Updates …", R.drawable.ic_refresh)
                io.execute {
                    val u = Updater.check()
                    runOnUiThread { if (u == null) tvToast("Overlord TV ist aktuell (${BuildConfig.VERSION_NAME})", R.drawable.ic_check) else Updater.runInteractive(this, u); refresh() }
                }
            },
            onClick = {
                Tv.info(this, "Overlord TV ${BuildConfig.VERSION_NAME}",
                    "Bündelt Streaming-Apps, Webseiten und deine Jellyfin-Bibliothek auf einer Startseite.\n\n" +
                        "Werbeblocker: ${AdBlock.count} Domains, ${AdBlock.lastUpdateText(this)}.\n\n" +
                        "Schrift: Inter (SIL Open Font License 1.1). Symbole: Material Icons (Apache 2.0).", R.drawable.ic_info)
            },
        ),
    )

    // ---------------------------------------------------------------- Kacheln bearbeiten

    private fun addTile() {
        Tv.menu(this, "Kachel hinzufügen", listOf(
            MenuEntry("Webseite", R.drawable.ic_globe, "Öffnet im eingebauten Browser") { addWebTile() },
            MenuEntry("Installierte App", R.drawable.ic_apps, "Startet eine App auf diesem Gerät") { addAppTile() },
        ), eyebrow = "NEU")
    }

    private fun addWebTile() {
        Tv.input(this, "Webseite hinzufügen", "z. B. arte.tv", url = true, icon = R.drawable.ic_globe,
            message = "Adresse der Webseite. Vorschaubild, Symbol und Farbe werden automatisch geladen.", okLabel = "Weiter") { raw ->
            if (raw.isBlank()) return@input
            val url = normalizeUrl(raw)
            val suggested = hostOf(url).substringBefore('.').replaceFirstChar { it.uppercase() }
            Tv.input(this, "Name der Kachel", "Name", suggested, icon = R.drawable.ic_edit, okLabel = "Hinzufügen") { name ->
                val t = TileStore.newWeb(name.ifBlank { suggested }, url)
                TileStore.add(this, t)
                refresh(t.id)
            }
        }
    }

    private fun addAppTile() {
        val apps = Launcher.installedApps(this)
        if (apps.isEmpty()) { tvToast("Keine Apps gefunden", R.drawable.ic_warning); return }
        Tv.apps(this, apps) { a ->
            val color = dominantColor(a.icon)?.let { tameColor(darken(it, 0.85f)) } ?: Brand.colorFor(a.pkg)
            val t = TileStore.newApp(a.label, a.pkg, color)
            TileStore.add(this, t)
            refresh(t.id)
        }
    }

    private fun editTile(t: Tile) {
        val e = ArrayList<MenuEntry>()
        e.add(MenuEntry("Öffnen", R.drawable.ic_play) { Launcher.open(this, t) })
        e.add(MenuEntry("Umbenennen", R.drawable.ic_edit, t.name) {
            Tv.input(this, "Umbenennen", "Name", t.name, icon = R.drawable.ic_edit) { n -> if (n.isNotBlank()) { t.name = n; TileStore.update(this, t); refresh(t.id) } }
        })
        if (t.type == TileType.WEB) e.add(MenuEntry("URL ändern", R.drawable.ic_link, t.url) {
            Tv.input(this, "URL ändern", "https://…", t.url, url = true, icon = R.drawable.ic_link) { u -> if (u.isNotBlank()) { t.url = normalizeUrl(u); TileStore.update(this, t); refresh(t.id) } }
        })
        e.add(MenuEntry("Beschreibung ändern", R.drawable.ic_info) {
            Tv.input(this, "Beschreibung", "Kurzer Text", t.description, icon = R.drawable.ic_info) { d -> t.description = d; TileStore.update(this, t); refresh(t.id) }
        })
        e.add(MenuEntry("Verschieben", R.drawable.ic_move, "Mit ◀ ▶ an die gewünschte Stelle") { startMove(t) })
        e.add(MenuEntry("Farbe ändern", R.drawable.ic_palette) {
            Tv.colors(this, "Farbe für „${t.name}“", t.color) { c -> t.color = c; t.colorAuto = false; TileStore.update(this, t); refresh(t.id) }
        })
        if (t.type == TileType.WEB) e.add(MenuEntry("Im externen Browser öffnen", R.drawable.ic_open_external) { Launcher.openExternal(this, t.url) })
        else e.add(MenuEntry("Im Appstore anzeigen", R.drawable.ic_store) { Launcher.openStore(this, Launcher.storePackage(this, t)) })
        e.add(MenuEntry("Entfernen", R.drawable.ic_delete, if (t.builtin) "Wiederherstellbar in den Einstellungen" else null, danger = true) {
            Tv.confirm(this, "„${t.name}“ entfernen?", if (t.builtin) "Feste Kacheln lassen sich unter Einstellungen → Feste Kacheln wiederherstellen." else null, "Entfernen", danger = true) {
                TileStore.remove(this, t.id); refresh()
            }
        })
        Tv.menu(this, t.name, e, subtitle = if (t.type == TileType.WEB) hostOf(t.url) else "App", eyebrow = "KACHEL BEARBEITEN")
    }

    private fun startMove(t: Tile) {
        movingId = t.id
        rows.heroOverride = Triple("„${t.name}“ verschieben", "◀ ▶ verschieben · OK oder Zurück beendet", "Bewege die Kachel mit dem Steuerkreuz an die gewünschte Stelle in der Reihe.")
        rows.focusItem(t.id)
    }

    private fun stopMove() {
        val id = movingId
        movingId = null
        rows.heroOverride = null
        refresh(id)
    }

    private fun openUrlDialog() {
        Tv.input(this, "Webseite öffnen", "Adresse oder Suchbegriff", url = true, icon = R.drawable.ic_globe, okLabel = "Öffnen") { raw ->
            if (raw.isNotBlank()) BrowserActivity.open(this, normalizeUrl(raw), hostOf(normalizeUrl(raw)), Brand.ACCENT)
        }
    }

    private fun jellyfinSetup() {
        Tv.input(this, "Jellyfin-Server", "z. B. http://192.168.1.10:8096", Jellyfin.server.ifBlank { "http://" }, url = true,
            icon = R.drawable.ic_library, message = "Adresse deines Jellyfin-Servers inklusive Port.", okLabel = "Weiter") { srv ->
            if (srv.isBlank()) return@input
            Tv.input(this, "Benutzername", "Benutzer", Jellyfin.userName, icon = R.drawable.ic_edit, okLabel = "Weiter") { user ->
                Tv.input(this, "Passwort", "Passwort (leer lassen, falls keins)", password = true, icon = R.drawable.ic_shield, okLabel = "Anmelden") { pass ->
                    tvToast("Melde an …", R.drawable.ic_library)
                    Thread {
                        val err = Jellyfin.login(srv, user, pass)
                        runOnUiThread {
                            if (err == null) {
                                tvToast("Verbunden mit Jellyfin", R.drawable.ic_check)
                                refresh("jellyfin")
                            } else Tv.info(this, "Anmeldung fehlgeschlagen", err, R.drawable.ic_warning)
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
                        val keep = rows.heroOverride
                        refresh(id)
                        rows.heroOverride = keep
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
        if (event.keyCode == KeyEvent.KEYCODE_MENU) {
            if (event.action == KeyEvent.ACTION_UP) (currentFocus as? CardView)?.item?.onMenu?.invoke()
            return true
        }
        if (event.keyCode == KeyEvent.KEYCODE_SEARCH) {
            if (event.action == KeyEvent.ACTION_UP) SearchActivity.open(this)
            return true
        }
        return super.dispatchKeyEvent(event)
    }

    companion object {
        val HELP = """
            STARTSEITE
            Steuerkreuz – Karte wählen
            OK – öffnen / starten
            ☰ oder OK lange – Optionen (umbenennen, URL, verschieben, Farbe, entfernen, extern öffnen)

            EINGEBAUTER BROWSER
            ☰ kurz – Modus wechseln: Links → Zeiger → Normal
            ☰ lang (oder OK lang) – Browser-Menü (Schnellsuche, Adresse, Video nativ abspielen, Schutz, …)
            Link-Modus: Steuerkreuz springt zum nächsten Link, OK klickt
            Zeiger-Modus: Steuerkreuz bewegt den Zeiger (halten = schneller), am Rand wird gescrollt
            ⏯ – Play/Pause (auch im iframe-Player)
            ⏪ / ⏩ – 10 s spulen; ohne Video: Seite scrollen
            Zurück – Vollbild verlassen → vorherige Seite → Startseite

            PLAYER-LEISTE (erscheint, sobald ein Video läuft)
            ◀ ▶ – Knopf wählen, OK – ausführen, ▲ oder Zurück – ausblenden
            Knöpfe: −10 s · Play/Pause · +10 s · Nächste Folge · Intro +85 s · Tempo · Vollbild · Nativ

            NATIVER PLAYER / JELLYFIN
            OK oder ⏯ – Play/Pause
            ◀ ▶ oder ⏪ ⏩ – spulen (halten = schneller)
            ▲ ▼ – Infoleiste
            Zurück – beenden (Position wird gespeichert)
        """.trimIndent()
    }
}
