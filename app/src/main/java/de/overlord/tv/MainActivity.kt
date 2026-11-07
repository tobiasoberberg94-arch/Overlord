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
import android.util.TypedValue
import android.view.Gravity
import android.view.KeyEvent
import android.view.View
import android.widget.EditText
import android.widget.GridLayout
import android.widget.LinearLayout
import android.widget.TextView
import android.widget.Toast
import java.util.UUID

class MainActivity : Activity() {

    private lateinit var grid: GridLayout
    private lateinit var store: TileStore
    private lateinit var tiles: MutableList<Tile>
    private var focusIndex = 0

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)
        grid = findViewById(R.id.grid)
        store = TileStore(this)
        tiles = store.load()
        render()
    }

    // ---------------------------------------------------------------- UI

    private fun dp(v: Int) = TypedValue.applyDimension(
        TypedValue.COMPLEX_UNIT_DIP, v.toFloat(), resources.displayMetrics
    ).toInt()

    private fun render() {
        grid.removeAllViews()
        tiles.forEachIndexed { i, tile -> grid.addView(makeTileView(tile, i)) }
        grid.addView(makeAddView())
        val count = grid.childCount
        grid.getChildAt(focusIndex.coerceIn(0, count - 1))?.requestFocus()
    }

    private fun baseTile(title: String, subtitle: String, color: Int): TextView {
        val tv = TextView(this)
        tv.text = if (subtitle.isEmpty()) title else "$title\n$subtitle"
        tv.setTextColor(Color.WHITE)
        tv.setTextSize(TypedValue.COMPLEX_UNIT_SP, 22f)
        tv.typeface = Typeface.DEFAULT_BOLD
        tv.gravity = Gravity.CENTER
        tv.isFocusable = true
        tv.isFocusableInTouchMode = true
        tv.isClickable = true
        tv.background = GradientDrawable().apply {
            cornerRadius = dp(16).toFloat()
            setColor(color)
            setStroke(dp(4), Color.TRANSPARENT)
        }
        val lp = GridLayout.LayoutParams().apply {
            width = dp(200)
            height = dp(120)
            setMargins(dp(12), dp(12), dp(12), dp(12))
        }
        tv.layoutParams = lp
        tv.setOnFocusChangeListener { v, hasFocus ->
            val bg = v.background as GradientDrawable
            bg.setStroke(dp(4), if (hasFocus) Color.WHITE else Color.TRANSPARENT)
            v.animate().scaleX(if (hasFocus) 1.08f else 1f)
                .scaleY(if (hasFocus) 1.08f else 1f)
                .setDuration(120).start()
            v.elevation = if (hasFocus) dp(8).toFloat() else 0f
        }
        return tv
    }

    private fun makeTileView(tile: Tile, index: Int): View {
        val subtitle = when (tile.type) {
            Tile.Type.APP -> "App"
            Tile.Type.WEB -> Uri.parse(tile.target).host ?: "Web"
        }
        val tv = baseTile(tile.name, subtitle, tile.color)
        tv.setOnClickListener { focusIndex = index; open(tile) }
        tv.setOnLongClickListener { focusIndex = index; showTileMenu(index); true }
        tv.setOnKeyListener { _, keyCode, event ->
            if (keyCode == KeyEvent.KEYCODE_MENU && event.action == KeyEvent.ACTION_UP) {
                focusIndex = index; showTileMenu(index); true
            } else false
        }
        return tv
    }

    private fun makeAddView(): View {
        val tv = baseTile("+", "Hinzufügen", 0xFF2A2A38.toInt())
        tv.setOnClickListener { focusIndex = tiles.size; showAddMenu() }
        return tv
    }

    // ---------------------------------------------------------------- Öffnen

    private fun open(tile: Tile) {
        when (tile.type) {
            Tile.Type.WEB -> startActivity(
                Intent(this, WebActivity::class.java)
                    .putExtra(WebActivity.EXTRA_URL, tile.target)
                    .putExtra(WebActivity.EXTRA_TITLE, tile.name)
            )
            Tile.Type.APP -> launchApp(tile)
        }
    }

    private fun launchApp(tile: Tile) {
        val pm = packageManager
        for (pkg in tile.packages) {
            val intent = pm.getLeanbackLaunchIntentForPackage(pkg)
                ?: pm.getLaunchIntentForPackage(pkg)
            if (intent != null) {
                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                try {
                    startActivity(intent)
                    return
                } catch (_: Exception) {
                    // nächsten Kandidaten versuchen
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

    // ---------------------------------------------------------------- Bearbeiten

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
        focusIndex = target
        persist()
    }

    private fun cycleColor(index: Int) {
        val t = tiles[index]
        val pos = TileStore.PALETTE.indexOf(t.color)
        val next = TileStore.PALETTE[(pos + 1) % TileStore.PALETTE.size]
        tiles[index] = t.copy(color = next)
        persist()
    }

    private fun confirmRemove(index: Int) {
        AlertDialog.Builder(this)
            .setTitle("${tiles[index].name} entfernen?")
            .setPositiveButton("Entfernen") { _, _ ->
                tiles.removeAt(index)
                focusIndex = index.coerceAtMost(tiles.size)
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
        for (d in TileStore.defaults()) {
            if (tiles.none { it.id == d.id }) tiles.add(d)
        }
        persist()
    }

    private fun editTile(index: Int) {
        val t = tiles[index]
        if (t.type == Tile.Type.WEB) webDialog(index) else renameDialog(index)
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
                    focusIndex = tiles.size - 1
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
            addView(name, LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT))
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
        val found = linkedMapOf<String, String>() // package -> label
        for (category in listOf(Intent.CATEGORY_LEANBACK_LAUNCHER, Intent.CATEGORY_LAUNCHER)) {
            val query = Intent(Intent.ACTION_MAIN).addCategory(category)
            val list = pm.queryIntentActivities(query, 0)
            for (ri in list) {
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
                focusIndex = tiles.size - 1
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
