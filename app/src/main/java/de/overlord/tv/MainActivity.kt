package de.overlord.tv

import android.app.Activity
import android.app.AlertDialog
import android.content.ActivityNotFoundException
import android.content.Intent
import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.net.Uri
import android.os.Bundle
import android.text.InputType
import android.text.TextUtils
import android.util.TypedValue
import android.view.Gravity
import android.view.KeyEvent
import android.view.View
import android.view.ViewGroup
import android.widget.EditText
import android.widget.FrameLayout
import android.widget.HorizontalScrollView
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView
import android.widget.Toast
import java.util.UUID

/** Startbildschirm im Stil gängiger Streaming-Apps: großer Hero-Bereich + horizontale Reihen. */
class MainActivity : Activity() {

    private lateinit var store: TileStore
    private lateinit var history: HistoryStore
    private lateinit var tiles: MutableList<Tile>

    private lateinit var heroBg: View
    private lateinit var heroTitle: TextView
    private lateinit var heroMeta: TextView
    private lateinit var heroDesc: TextView
    private lateinit var scroll: ScrollView
    private lateinit var rows: LinearLayout

    /** Zuletzt fokussierte Karte als "zeile:index", damit der Fokus nach dem Neuaufbau bleibt. */
    private var focusKey = "tiles:0"

    private val accent = 0xFFE50914.toInt()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        AdBlocker.init(this) // Werbe-Liste schon mal im Hintergrund laden
        store = TileStore(this)
        history = HistoryStore(this)
        tiles = store.load()
        buildLayout()
    }

    override fun onResume() {
        super.onResume()
        render() // Weiterschauen kann sich geändert haben
    }

    private fun dp(v: Int) = TypedValue.applyDimension(
        TypedValue.COMPLEX_UNIT_DIP, v.toFloat(), resources.displayMetrics
    ).toInt()

    // ---------------------------------------------------------------- Grundgerüst

    private fun buildLayout() {
        val root = FrameLayout(this)
        root.setBackgroundColor(0xFF0A0A0A.toInt())

        heroBg = View(this)
        root.addView(heroBg, FrameLayout.LayoutParams(MATCH, (resources.displayMetrics.heightPixels * 0.7f).toInt()))

        // Abdunkelung nach unten, damit die Reihen gut lesbar sind
        val fade = View(this).apply {
            background = GradientDrawable(
                GradientDrawable.Orientation.TOP_BOTTOM,
                intArrayOf(0x00000000, 0x660A0A0A, 0xFF0A0A0A.toInt())
            )
        }
        root.addView(fade, FrameLayout.LayoutParams(MATCH, (resources.displayMetrics.heightPixels * 0.7f).toInt()))

        val column = LinearLayout(this).apply { orientation = LinearLayout.VERTICAL }
        root.addView(column, FrameLayout.LayoutParams(MATCH, MATCH))

        val logo = TextView(this).apply {
            text = "OVERLORD"
            setTextColor(accent)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 26f)
            typeface = Typeface.create("sans-serif-condensed", Typeface.BOLD)
            letterSpacing = 0.12f
            setPadding(dp(56), dp(28), dp(56), 0)
        }
        column.addView(logo)

        val hero = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(56), dp(28), dp(56), dp(12))
        }
        heroTitle = TextView(this).apply {
            setTextColor(Color.WHITE)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 46f)
            typeface = Typeface.DEFAULT_BOLD
            maxLines = 1
            ellipsize = TextUtils.TruncateAt.END
            setShadowLayer(12f, 0f, 2f, Color.BLACK)
        }
        heroMeta = TextView(this).apply {
            setTextColor(0xFF46D369.toInt())
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 18f)
            typeface = Typeface.DEFAULT_BOLD
            setPadding(0, dp(6), 0, dp(6))
        }
        heroDesc = TextView(this).apply {
            setTextColor(0xDDFFFFFF.toInt())
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 18f)
            maxLines = 2
            ellipsize = TextUtils.TruncateAt.END
            maxWidth = (resources.displayMetrics.widthPixels * 0.55f).toInt()
        }
        hero.addView(heroTitle)
        hero.addView(heroMeta)
        hero.addView(heroDesc)
        column.addView(hero, LinearLayout.LayoutParams(MATCH, dp(190)))

        scroll = ScrollView(this).apply {
            isVerticalScrollBarEnabled = false
            clipChildren = false
            clipToPadding = false
            isSmoothScrollingEnabled = true
        }
        rows = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            clipChildren = false
            clipToPadding = false
            setPadding(0, 0, 0, dp(200))
        }
        scroll.addView(rows, ViewGroup.LayoutParams(MATCH, WRAP))
        column.addView(scroll, LinearLayout.LayoutParams(MATCH, 0, 1f))

        setContentView(root)
    }

    // ---------------------------------------------------------------- Reihen & Karten

    private fun render() {
        rows.removeAllViews()
        val keyed = HashMap<String, View>()

        val continueItems = history.list()
        if (continueItems.isNotEmpty()) {
            val row = addRow("Weiterschauen")
            continueItems.forEachIndexed { i, e ->
                val card = historyCard(e, "continue:$i")
                row.addView(card)
                keyed["continue:$i"] = card
            }
        }

        val row = addRow("Meine Anbieter")
        tiles.forEachIndexed { i, t ->
            val card = tileCard(t, i, "tiles:$i")
            row.addView(card)
            keyed["tiles:$i"] = card
        }
        val add = addCard("tiles:${tiles.size}")
        row.addView(add)
        keyed["tiles:${tiles.size}"] = add

        val target = keyed[focusKey] ?: keyed["tiles:0"] ?: add
        target.post { target.requestFocus() }
    }

    private fun addRow(title: String): LinearLayout {
        val label = TextView(this).apply {
            text = title
            setTextColor(0xFFE5E5E5.toInt())
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 22f)
            typeface = Typeface.DEFAULT_BOLD
            setPadding(dp(56), dp(8), dp(56), dp(4))
        }
        rows.addView(label)

        val hs = HorizontalScrollView(this).apply {
            isHorizontalScrollBarEnabled = false
            clipChildren = false
            clipToPadding = false
            isSmoothScrollingEnabled = true
        }
        val line = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            clipChildren = false
            clipToPadding = false
            setPadding(dp(48), dp(14), dp(48), dp(22))
        }
        hs.addView(line)
        rows.addView(hs)
        return line
    }

    /** Basis-Karte (16:9) mit Fokus-Animation. */
    private fun card(key: String, color: Int, label: String, title: String, sub: String, progress: Float?): FrameLayout {
        val f = FrameLayout(this)
        f.isFocusable = true
        f.isFocusableInTouchMode = true
        f.isClickable = true
        f.layoutParams = LinearLayout.LayoutParams(dp(272), dp(153)).apply { setMargins(dp(8), 0, dp(8), 0) }

        val bg = GradientDrawable(
            GradientDrawable.Orientation.TL_BR,
            intArrayOf(color, darken(color, 0.45f))
        ).apply { cornerRadius = dp(6).toFloat() }
        f.background = bg

        // großer, blasser Anfangsbuchstabe als "Cover"
        f.addView(TextView(this).apply {
            text = title.trim().take(1).uppercase()
            setTextColor(0x33FFFFFF)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 110f)
            typeface = Typeface.DEFAULT_BOLD
            gravity = Gravity.END or Gravity.CENTER_VERTICAL
            setPadding(0, 0, dp(14), 0)
            includeFontPadding = false
        }, FrameLayout.LayoutParams(MATCH, MATCH))

        f.addView(TextView(this).apply {
            text = label.uppercase()
            setTextColor(Color.WHITE)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 11f)
            typeface = Typeface.DEFAULT_BOLD
            letterSpacing = 0.15f
            background = GradientDrawable().apply { cornerRadius = dp(3).toFloat(); setColor(0x55000000) }
            setPadding(dp(6), dp(2), dp(6), dp(2))
        }, FrameLayout.LayoutParams(WRAP, WRAP, Gravity.TOP or Gravity.START).apply { setMargins(dp(12), dp(12), 0, 0) })

        val texts = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(14), 0, dp(14), dp(if (progress != null) 16 else 12))
        }
        texts.addView(TextView(this).apply {
            text = title
            setTextColor(Color.WHITE)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 20f)
            typeface = Typeface.DEFAULT_BOLD
            maxLines = 2
            ellipsize = TextUtils.TruncateAt.END
            setShadowLayer(6f, 0f, 1f, Color.BLACK)
        })
        if (sub.isNotEmpty()) texts.addView(TextView(this).apply {
            text = sub
            setTextColor(0xCCFFFFFF.toInt())
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 13f)
            maxLines = 1
            ellipsize = TextUtils.TruncateAt.END
        })
        f.addView(texts, FrameLayout.LayoutParams(MATCH, WRAP, Gravity.BOTTOM))

        if (progress != null) {
            val track = LinearLayout(this).apply { setBackgroundColor(0x66FFFFFF) }
            track.addView(View(this).apply { setBackgroundColor(accent) },
                LinearLayout.LayoutParams(0, MATCH, progress.coerceAtLeast(0.02f)))
            track.addView(View(this), LinearLayout.LayoutParams(0, MATCH, 1f - progress.coerceAtLeast(0.02f)))
            f.addView(track, FrameLayout.LayoutParams(MATCH, dp(4), Gravity.BOTTOM).apply {
                setMargins(dp(14), 0, dp(14), dp(8))
            })
        }

        f.setOnFocusChangeListener { v, has ->
            bg.setStroke(dp(3), if (has) Color.WHITE else Color.TRANSPARENT)
            v.animate().scaleX(if (has) 1.12f else 1f).scaleY(if (has) 1.12f else 1f).setDuration(150).start()
            v.elevation = if (has) dp(12).toFloat() else 0f
            if (has) {
                focusKey = key
                scrollRowIntoView(v)
            }
        }
        return f
    }

    /** Fokussierte Reihe nach oben holen (wie bei Netflix & Co.). */
    private fun scrollRowIntoView(card: View) {
        val hs = card.parent?.parent as? View ?: return
        val idx = rows.indexOfChild(hs)
        val label = if (idx > 0) rows.getChildAt(idx - 1) else hs
        scroll.post { scroll.smoothScrollTo(0, label.top) }
    }

    private fun setHero(title: String, meta: String, desc: String, color: Int) {
        heroTitle.text = title
        heroMeta.text = meta
        heroDesc.text = desc
        heroBg.background = GradientDrawable(
            GradientDrawable.Orientation.TR_BL,
            intArrayOf(darken(color, 0.85f), darken(color, 0.35f), 0xFF0A0A0A.toInt())
        )
    }

    private fun darken(c: Int, f: Float): Int = Color.rgb(
        (Color.red(c) * f).toInt(), (Color.green(c) * f).toInt(), (Color.blue(c) * f).toInt()
    )

    private fun historyCard(e: HistoryEntry, key: String): View {
        val remaining = HistoryStore.formatTime((e.duration - e.position).coerceAtLeast(0.0))
        val c = card(key, e.color, e.tileName.ifEmpty { "Web" }, e.title, "Noch $remaining", e.progress)
        c.setOnFocusChangeListener(chain(c.onFocusChangeListener) { has ->
            if (has) setHero(
                e.title,
                "Weiter bei ${HistoryStore.formatTime(e.position)} von ${HistoryStore.formatTime(e.duration)}",
                "${e.tileName} · OK zum Weiterschauen · ☰ für Optionen",
                e.color
            )
        })
        c.setOnClickListener { openHistory(e, resume = true) }
        c.setOnLongClickListener { historyMenu(e); true }
        c.setOnKeyListener(menuKey { historyMenu(e) })
        return c
    }

    private fun tileCard(t: Tile, index: Int, key: String): View {
        val host = Uri.parse(t.target).host?.removePrefix("www.") ?: ""
        val label = if (t.type == Tile.Type.APP) "App" else "Web"
        val c = card(key, t.color, label, t.name, if (t.type == Tile.Type.WEB) host else "", null)
        c.setOnFocusChangeListener(chain(c.onFocusChangeListener) { has ->
            if (has) setHero(
                t.name,
                if (t.type == Tile.Type.APP) "App" else "Web · werbefrei · Fernbedienungs-Steuerung",
                if (t.type == Tile.Type.APP) "Startet die ${t.name}-App. ☰ für Optionen."
                else "$host – Steuerkreuz springt von Link zu Link, Pop-ups und Werbung werden blockiert. ☰ für Optionen.",
                t.color
            )
        })
        c.setOnClickListener { open(t) }
        c.setOnLongClickListener { showTileMenu(index); true }
        c.setOnKeyListener(menuKey { showTileMenu(index) })
        return c
    }

    private fun addCard(key: String): View {
        val c = card(key, 0xFF2B2B2B.toInt(), "Neu", "+ Hinzufügen", "Webseite oder App", null)
        c.setOnFocusChangeListener(chain(c.onFocusChangeListener) { has ->
            if (has) setHero("Hinzufügen", "Neue Kachel", "Füge eine Webseite oder eine installierte App hinzu.", 0xFF444444.toInt())
        })
        c.setOnClickListener { showAddMenu() }
        return c
    }

    private fun chain(first: View.OnFocusChangeListener, then: (Boolean) -> Unit) =
        View.OnFocusChangeListener { v, has -> first.onFocusChange(v, has); then(has) }

    private fun menuKey(action: () -> Unit) = View.OnKeyListener { _, code, ev ->
        if (code == KeyEvent.KEYCODE_MENU) {
            if (ev.action == KeyEvent.ACTION_UP) action()
            true
        } else false
    }

    // ---------------------------------------------------------------- Öffnen

    private fun open(tile: Tile) {
        when (tile.type) {
            Tile.Type.WEB -> startActivity(
                Intent(this, WebActivity::class.java)
                    .putExtra(WebActivity.EXTRA_URL, tile.target)
                    .putExtra(WebActivity.EXTRA_TITLE, tile.name)
                    .putExtra(WebActivity.EXTRA_COLOR, tile.color)
            )
            Tile.Type.APP -> launchApp(tile)
        }
    }

    private fun openHistory(e: HistoryEntry, resume: Boolean) {
        startActivity(
            Intent(this, WebActivity::class.java)
                .putExtra(WebActivity.EXTRA_URL, e.url)
                .putExtra(WebActivity.EXTRA_TITLE, e.tileName)
                .putExtra(WebActivity.EXTRA_COLOR, e.color)
                .putExtra(WebActivity.EXTRA_RESUME, if (resume) e.position else 0.0)
        )
        if (!resume) history.remove(e.url)
    }

    private fun launchApp(tile: Tile) {
        val pm = packageManager
        for (pkg in tile.packages) {
            val intent = pm.getLeanbackLaunchIntentForPackage(pkg) ?: pm.getLaunchIntentForPackage(pkg)
            if (intent != null) {
                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                try {
                    startActivity(intent)
                    return
                } catch (_: Exception) {
                }
            }
        }
        val first = tile.packages.firstOrNull() ?: return
        Toast.makeText(this, "${tile.name} ist nicht installiert – öffne App-Store …", Toast.LENGTH_LONG).show()
        openStore(first)
    }

    private fun openStore(pkg: String) {
        val candidates = listOf(
            "amzn://apps/android?p=$pkg",
            "market://details?id=$pkg",
            "https://www.amazon.de/gp/mas/dl/android?p=$pkg",
        )
        for (uri in candidates) {
            try {
                startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(uri)).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                return
            } catch (_: ActivityNotFoundException) {
            }
        }
        Toast.makeText(this, "Kein App-Store gefunden.", Toast.LENGTH_LONG).show()
    }

    // ---------------------------------------------------------------- Menüs

    private fun historyMenu(e: HistoryEntry) {
        val items = arrayOf("Weiterschauen", "Von vorne beginnen", "Aus „Weiterschauen“ entfernen")
        AlertDialog.Builder(this)
            .setTitle(e.title)
            .setItems(items) { _, which ->
                when (which) {
                    0 -> openHistory(e, resume = true)
                    1 -> openHistory(e, resume = false)
                    2 -> { history.remove(e.url); render() }
                }
            }
            .show()
    }

    private fun showTileMenu(index: Int) {
        val tile = tiles[index]
        val items = mutableListOf("Öffnen", "Bearbeiten", "Nach links", "Nach rechts", "Farbe ändern", "Entfernen")
        if (tile.type == Tile.Type.WEB) items.add(1, "Im externen Browser öffnen")
        AlertDialog.Builder(this)
            .setTitle(tile.name)
            .setItems(items.toTypedArray()) { _, which ->
                when (items[which]) {
                    "Öffnen" -> open(tile)
                    "Im externen Browser öffnen" -> openExternal(tile.target)
                    "Bearbeiten" -> editTile(index)
                    "Nach links" -> move(index, -1)
                    "Nach rechts" -> move(index, +1)
                    "Farbe ändern" -> cycleColor(index)
                    "Entfernen" -> confirmRemove(index)
                }
            }
            .show()
    }

    private fun openExternal(url: String) {
        try {
            startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(url)))
        } catch (_: ActivityNotFoundException) {
            Toast.makeText(this, "Kein Browser installiert (z. B. Silk oder Firefox).", Toast.LENGTH_LONG).show()
        }
    }

    private fun move(index: Int, delta: Int) {
        val target = index + delta
        if (target !in tiles.indices) return
        val t = tiles.removeAt(index)
        tiles.add(target, t)
        focusKey = "tiles:$target"
        persist()
    }

    private fun cycleColor(index: Int) {
        val t = tiles[index]
        val pos = TileStore.PALETTE.indexOf(t.color)
        tiles[index] = t.copy(color = TileStore.PALETTE[(pos + 1) % TileStore.PALETTE.size])
        persist()
    }

    private fun confirmRemove(index: Int) {
        AlertDialog.Builder(this)
            .setTitle("${tiles[index].name} entfernen?")
            .setPositiveButton("Entfernen") { _, _ ->
                tiles.removeAt(index)
                focusKey = "tiles:${index.coerceAtMost(tiles.size)}"
                persist()
            }
            .setNegativeButton("Abbrechen", null)
            .show()
    }

    private fun showAddMenu() {
        val items = arrayOf("Webseite hinzufügen", "Installierte App hinzufügen", "Standard-Kacheln wiederherstellen")
        AlertDialog.Builder(this)
            .setTitle("Hinzufügen")
            .setItems(items) { _, which ->
                when (which) {
                    0 -> webDialog(null)
                    1 -> pickInstalledApp()
                    2 -> restoreDefaults()
                }
            }
            .show()
    }

    private fun restoreDefaults() {
        for (d in TileStore.defaults()) if (tiles.none { it.id == d.id }) tiles.add(d)
        persist()
    }

    private fun editTile(index: Int) {
        if (tiles[index].type == Tile.Type.WEB) webDialog(index) else renameDialog(index)
    }

    private fun input(hint: String, value: String, type: Int): EditText = EditText(this).apply {
        this.hint = hint
        setText(value)
        inputType = type
        setSingleLine()
    }

    private fun webDialog(index: Int?) {
        val existing = index?.let { tiles[it] }
        val name = input("Name", existing?.name ?: "", InputType.TYPE_CLASS_TEXT)
        val url = input("https://…", existing?.target ?: "https://", InputType.TYPE_CLASS_TEXT or InputType.TYPE_TEXT_VARIATION_URI)
        val box = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(24), dp(8), dp(24), 0)
            addView(name)
            addView(url)
        }
        AlertDialog.Builder(this)
            .setTitle(if (existing == null) "Webseite hinzufügen" else "Webseite bearbeiten")
            .setView(box)
            .setPositiveButton("Speichern") { _, _ ->
                var u = url.text.toString().trim()
                if (u.isEmpty() || u == "https://") return@setPositiveButton
                if (!u.startsWith("http://") && !u.startsWith("https://")) u = "https://$u"
                val n = name.text.toString().trim().ifEmpty { Uri.parse(u).host ?: u }
                if (existing == null) {
                    tiles.add(Tile(UUID.randomUUID().toString(), n, Tile.Type.WEB, u, nextColor()))
                    focusKey = "tiles:${tiles.size - 1}"
                } else {
                    tiles[index] = existing.copy(name = n, target = u)
                }
                persist()
            }
            .setNegativeButton("Abbrechen", null)
            .show()
    }

    private fun renameDialog(index: Int) {
        val t = tiles[index]
        val name = input("Name", t.name, InputType.TYPE_CLASS_TEXT)
        val box = LinearLayout(this).apply {
            setPadding(dp(24), dp(8), dp(24), 0)
            addView(name, LinearLayout.LayoutParams(MATCH, WRAP))
        }
        AlertDialog.Builder(this)
            .setTitle("Umbenennen")
            .setView(box)
            .setPositiveButton("Speichern") { _, _ ->
                val n = name.text.toString().trim()
                if (n.isNotEmpty()) {
                    tiles[index] = t.copy(name = n)
                    persist()
                }
            }
            .setNegativeButton("Abbrechen", null)
            .show()
    }

    private fun pickInstalledApp() {
        val pm = packageManager
        val found = linkedMapOf<String, String>()
        for (category in listOf(Intent.CATEGORY_LEANBACK_LAUNCHER, Intent.CATEGORY_LAUNCHER)) {
            val query = Intent(Intent.ACTION_MAIN).addCategory(category)
            for (ri in pm.queryIntentActivities(query, 0)) {
                val pkg = ri.activityInfo.packageName
                if (pkg == packageName || found.containsKey(pkg)) continue
                found[pkg] = ri.loadLabel(pm).toString()
            }
        }
        val apps = found.entries.sortedBy { it.value.lowercase() }
        if (apps.isEmpty()) {
            Toast.makeText(this, "Keine Apps gefunden.", Toast.LENGTH_SHORT).show()
            return
        }
        AlertDialog.Builder(this)
            .setTitle("App auswählen")
            .setItems(apps.map { it.value }.toTypedArray()) { _, which ->
                val e = apps[which]
                tiles.add(Tile(UUID.randomUUID().toString(), e.value, Tile.Type.APP, e.key, nextColor()))
                focusKey = "tiles:${tiles.size - 1}"
                persist()
            }
            .show()
    }

    private fun nextColor() = TileStore.PALETTE[tiles.size % TileStore.PALETTE.size]

    private fun persist() {
        store.save(tiles)
        render()
    }
}

private const val MATCH = ViewGroup.LayoutParams.MATCH_PARENT
private const val WRAP = ViewGroup.LayoutParams.WRAP_CONTENT
