package de.overlord.tv

import android.app.Activity
import android.app.Dialog
import android.content.res.ColorStateList
import android.graphics.Color
import android.graphics.drawable.ColorDrawable
import android.graphics.drawable.GradientDrawable
import android.graphics.drawable.StateListDrawable
import android.text.InputType
import android.view.Gravity
import android.view.KeyEvent
import android.view.View
import android.view.ViewGroup
import android.view.WindowManager
import android.view.inputmethod.EditorInfo
import android.widget.EditText
import android.widget.FrameLayout
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.ScrollView

/** Ein Eintrag im Seitenmenü. */
class MenuEntry(
    val label: String,
    val icon: Int? = null,
    val sub: String? = null,
    val danger: Boolean = false,
    val action: () -> Unit,
)

/**
 * Dialoge im Overlord-Stil, komplett mit dem Steuerkreuz bedienbar:
 * Seitenmenü (gleitet von rechts herein), Eingabe, Bestätigung, Farbwahl, App-Raster, Infotext.
 */
object Tv {
    private var activeInput: java.lang.ref.WeakReference<EditText>? = null
    private var activeSubmit: (() -> Unit)? = null

    /** Text vom Handy in den offenen Eingabe-Dialog schreiben. */
    fun typeIntoActiveInput(text: String, submit: Boolean): Boolean {
        val e = activeInput?.get() ?: return false
        if (!e.isAttachedToWindow) return false
        e.setText(text)
        e.setSelection(e.text.length)
        if (submit) activeSubmit?.invoke()
        return true
    }

    /** Grundgerüst: Vollbild-Fenster mit abgedunkeltem Hintergrund. */
    private open class Overlay(val activity: Activity) : Dialog(activity, android.R.style.Theme_Translucent_NoTitleBar) {
        val root = FrameLayout(activity)
        private var menuDown = false

        init {
            root.setBackgroundColor(0xC0000000.toInt())
            setContentView(root)
            window?.setLayout(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT)
            window?.setBackgroundDrawable(ColorDrawable(Color.TRANSPARENT))
            setCanceledOnTouchOutside(true)
        }

        override fun dispatchKeyEvent(event: KeyEvent): Boolean {
            // ☰ schließt – aber nur, wenn ☰ auch in diesem Dialog gedrückt wurde
            // (sonst würde das Loslassen nach einem Lang-Druck den Dialog sofort schließen).
            if (event.keyCode == KeyEvent.KEYCODE_MENU) {
                if (event.action == KeyEvent.ACTION_DOWN && event.repeatCount == 0) menuDown = true
                if (event.action == KeyEvent.ACTION_UP && menuDown) dismiss()
                return true
            }
            return super.dispatchKeyEvent(event)
        }

        override fun show() {
            if (activity.isFinishing) return
            root.alpha = 0f
            super.show()
            root.animate().alpha(1f).setDuration(160).start()
        }
    }

    // ------------------------------------------------------------------ Bausteine

    private fun Activity.pillButton(text: String, iconRes: Int?, primary: Boolean, onClick: () -> Unit): LinearLayout {
        val r = dpf(28f)
        val bg = StateListDrawable().apply {
            addState(intArrayOf(android.R.attr.state_focused), rounded(Brand.FOCUS, r))
            addState(intArrayOf(), if (primary) rounded(Brand.ACCENT, r) else rounded(Color.TRANSPARENT, r, dp(2), 0x66FFFFFF))
        }
        val textColors = ColorStateList(
            arrayOf(intArrayOf(android.R.attr.state_focused), intArrayOf()),
            intArrayOf(Brand.BG, Brand.TEXT),
        )
        return LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER
            isFocusable = true
            isClickable = true
            background = bg
            setPadding(dp(26), 0, dp(26), 0)
            minimumHeight = dp(54)
            if (iconRes != null) {
                addView(ImageView(context).apply {
                    setImageResource(iconRes)
                    imageTintList = textColors
                    isDuplicateParentStateEnabled = true
                }, LinearLayout.LayoutParams(dp(22), dp(22)).apply { rightMargin = if (text.isEmpty()) 0 else dp(10) })
            }
            if (text.isNotEmpty()) addView(label(text, 17f, Fonts.semibold).apply {
                setTextColor(textColors)
                isDuplicateParentStateEnabled = true
            })
            setOnClickListener { onClick() }
            setOnFocusChangeListener { v, f -> v.animate().scaleX(if (f) 1.06f else 1f).scaleY(if (f) 1.06f else 1f).setDuration(120).start() }
        }
    }

    private fun Activity.card(widthDp: Int): LinearLayout = LinearLayout(this).apply {
        orientation = LinearLayout.VERTICAL
        background = rounded(Brand.SURFACE, dpf(26f), dp(1), Brand.STROKE)
        setPadding(dp(36), dp(32), dp(36), dp(30))
        elevation = dpf(24f)
        layoutParams = FrameLayout.LayoutParams(dp(widthDp), ViewGroup.LayoutParams.WRAP_CONTENT, Gravity.CENTER)
    }

    private fun Activity.cardHeader(card: LinearLayout, title: String, message: String?, iconRes: Int?) {
        if (iconRes != null) {
            val circle = FrameLayout(this).apply {
                background = GradientDrawable().apply { shape = GradientDrawable.OVAL; setColor(withAlpha(Brand.ACCENT, 0x40)) }
            }
            circle.addView(icon(iconRes, Brand.ACCENT), FrameLayout.LayoutParams(dp(26), dp(26), Gravity.CENTER))
            card.addView(circle, LinearLayout.LayoutParams(dp(52), dp(52)).apply { bottomMargin = dp(18) })
        }
        card.addView(label(title, 26f, Fonts.bold, lines = 2))
        if (!message.isNullOrBlank()) {
            card.addView(label(message, 16f, Fonts.regular, Brand.TEXT_DIM, lines = 0).apply {
                setLineSpacing(0f, 1.2f)
            }, LinearLayout.LayoutParams(-1, -2).apply { topMargin = dp(10) })
        }
    }

    private fun Activity.buttonRow(card: LinearLayout, vararg buttons: View) {
        val row = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.END
            clipChildren = false
        }
        buttons.forEach { b -> row.addView(b, LinearLayout.LayoutParams(-2, dp(54)).apply { leftMargin = dp(14) }) }
        card.clipChildren = false
        card.addView(row, LinearLayout.LayoutParams(-1, -2).apply { topMargin = dp(28) })
    }

    // ------------------------------------------------------------------ Seitenmenü

    fun menu(activity: Activity, title: String, entries: List<MenuEntry>, subtitle: String? = null, eyebrow: String = "OPTIONEN") {
        if (entries.isEmpty()) return
        val d = Overlay(activity)
        val ctx = activity
        val panelW = ctx.dp(470)
        val panel = LinearLayout(ctx).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(ctx.dp(30), ctx.dp(40), ctx.dp(30), ctx.dp(24))
            background = GradientDrawable(GradientDrawable.Orientation.LEFT_RIGHT, intArrayOf(0xF71A1A28.toInt(), 0xFA12121C.toInt()))
            elevation = ctx.dpf(30f)
        }
        panel.addView(ctx.label(eyebrow, 12f, Fonts.bold, Brand.ACCENT2).apply { letterSpacing = 0.22f })
        panel.addView(ctx.label(title, 26f, Fonts.bold, lines = 2), LinearLayout.LayoutParams(-1, -2).apply { topMargin = ctx.dp(8) })
        if (!subtitle.isNullOrBlank()) {
            panel.addView(ctx.label(subtitle, 14f, Fonts.regular, Brand.TEXT_DIM, lines = 2), LinearLayout.LayoutParams(-1, -2).apply { topMargin = ctx.dp(6) })
        }
        val list = LinearLayout(ctx).apply { orientation = LinearLayout.VERTICAL }
        val scroll = ScrollView(ctx).apply {
            isVerticalScrollBarEnabled = false
            isFocusable = false
            overScrollMode = View.OVER_SCROLL_NEVER
            clipToPadding = false
            setPadding(0, ctx.dp(6), 0, ctx.dp(6))
            addView(list)
        }
        panel.addView(scroll, LinearLayout.LayoutParams(-1, 0, 1f).apply { topMargin = ctx.dp(20) })
        panel.addView(ctx.label("OK auswählen  ·  Zurück schließen", 12f, Fonts.medium, Brand.TEXT_MUTED), LinearLayout.LayoutParams(-1, -2).apply { topMargin = ctx.dp(12) })

        entries.forEachIndexed { i, e -> list.addView(menuRow(ctx, e) { d.dismiss(); ctx.window.decorView.post { e.action() } }, LinearLayout.LayoutParams(-1, -2).apply { if (i > 0) topMargin = ctx.dp(4) }) }

        d.root.addView(panel, FrameLayout.LayoutParams(panelW, -1, Gravity.END))
        panel.translationX = panelW.toFloat()
        d.show()
        panel.animate().translationX(0f).setDuration(220).start()
        list.getChildAt(0)?.requestFocus()
    }

    private fun menuRow(ctx: Activity, e: MenuEntry, onClick: () -> Unit): View {
        val r = ctx.dpf(14f)
        val focusColor = if (e.danger) Brand.DANGER else Brand.ACCENT
        val row = LinearLayout(ctx).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            isFocusable = true
            isClickable = true
            minimumHeight = ctx.dp(58)
            setPadding(ctx.dp(16), ctx.dp(10), ctx.dp(16), ctx.dp(10))
            background = StateListDrawable().apply {
                addState(intArrayOf(android.R.attr.state_focused), rounded(focusColor, r))
                addState(intArrayOf(), rounded(Color.TRANSPARENT, r))
            }
        }
        val normalText = if (e.danger) 0xFFFCA5A5.toInt() else Brand.TEXT
        val ic = e.icon?.let { res -> ctx.icon(res, Brand.TEXT_DIM).also { row.addView(it, LinearLayout.LayoutParams(ctx.dp(24), ctx.dp(24)).apply { rightMargin = ctx.dp(16) }) } }
        val texts = LinearLayout(ctx).apply { orientation = LinearLayout.VERTICAL }
        val title = ctx.label(e.label, 18f, Fonts.medium, normalText, lines = 2)
        texts.addView(title)
        val sub = e.sub?.let { s -> ctx.label(s, 13f, Fonts.regular, Brand.TEXT_MUTED, lines = 2).also { texts.addView(it, LinearLayout.LayoutParams(-1, -2).apply { topMargin = ctx.dp(3) }) } }
        row.addView(texts, LinearLayout.LayoutParams(0, -2, 1f))
        row.setOnFocusChangeListener { _, f ->
            title.setTextColor(if (f) Brand.TEXT else normalText)
            ic?.imageTintList = ColorStateList.valueOf(if (f) Brand.TEXT else Brand.TEXT_DIM)
            sub?.setTextColor(if (f) 0xDDFFFFFF.toInt() else Brand.TEXT_MUTED)
        }
        row.setOnClickListener { onClick() }
        return row
    }

    /** Einfache Auswahl aus Texten. */
    fun choose(activity: Activity, title: String, options: List<String>, icon: Int? = null, onPick: (Int) -> Unit) =
        menu(activity, title, options.mapIndexed { i, o -> MenuEntry(o, icon) { onPick(i) } }, eyebrow = "AUSWAHL")

    // ------------------------------------------------------------------ Eingabe

    fun input(
        activity: Activity,
        title: String,
        hint: String,
        initial: String = "",
        message: String? = null,
        icon: Int? = null,
        url: Boolean = false,
        password: Boolean = false,
        okLabel: String = "OK",
        voice: (() -> Unit)? = null,
        onOk: (String) -> Unit,
    ) {
        val d = Overlay(activity)
        val ctx = activity
        val card = ctx.card(660)
        ctx.cardHeader(card, title, message, icon)
        val edit = EditText(ctx).apply {
            setText(initial)
            setSelection(text.length)
            this.hint = hint
            setSingleLine(true)
            textSize = 20f
            typeface = Fonts.medium
            setTextColor(Brand.TEXT)
            setHintTextColor(Brand.TEXT_MUTED)
            setPadding(ctx.dp(20), ctx.dp(16), ctx.dp(20), ctx.dp(16))
            val r = ctx.dpf(16f)
            background = StateListDrawable().apply {
                addState(intArrayOf(android.R.attr.state_focused), rounded(Brand.SURFACE2, r, ctx.dp(2), Brand.ACCENT))
                addState(intArrayOf(), rounded(Brand.SURFACE2, r, ctx.dp(1), Brand.STROKE))
            }
            inputType = when {
                password -> InputType.TYPE_CLASS_TEXT or InputType.TYPE_TEXT_VARIATION_PASSWORD
                url -> InputType.TYPE_CLASS_TEXT or InputType.TYPE_TEXT_VARIATION_URI
                else -> InputType.TYPE_CLASS_TEXT
            }
            imeOptions = EditorInfo.IME_ACTION_DONE
        }
        card.addView(edit, LinearLayout.LayoutParams(-1, -2).apply { topMargin = ctx.dp(22) })
        fun submit() { d.dismiss(); val v = edit.text.toString().trim(); ctx.window.decorView.post { onOk(v) } }
        edit.setOnEditorActionListener { _, _, _ -> submit(); true }
        activeInput = java.lang.ref.WeakReference(edit)
        activeSubmit = { submit() }
        d.setOnDismissListener { if (activeInput?.get() === edit) { activeInput = null; activeSubmit = null } }
        val buttons = ArrayList<View>()
        if (voice != null) buttons.add(ctx.pillButton("Sprache", R.drawable.ic_mic, false) { d.dismiss(); voice() })
        buttons.add(ctx.pillButton("Abbrechen", null, false) { d.dismiss() })
        buttons.add(ctx.pillButton(okLabel, R.drawable.ic_check, true) { submit() })
        ctx.buttonRow(card, *buttons.toTypedArray())
        d.root.addView(card)
        d.window?.setSoftInputMode(WindowManager.LayoutParams.SOFT_INPUT_STATE_VISIBLE or WindowManager.LayoutParams.SOFT_INPUT_ADJUST_PAN)
        d.show()
        edit.requestFocus()
    }

    // ------------------------------------------------------------------ Bestätigung / Info

    fun confirm(activity: Activity, title: String, message: String? = null, okLabel: String = "OK", danger: Boolean = false, icon: Int? = null, onOk: () -> Unit) {
        val d = Overlay(activity)
        val ctx = activity
        val card = ctx.card(600)
        ctx.cardHeader(card, title, message, icon ?: if (danger) R.drawable.ic_warning else null)
        val cancel = ctx.pillButton("Abbrechen", null, false) { d.dismiss() }
        val ok = ctx.pillButton(okLabel, if (danger) R.drawable.ic_delete else R.drawable.ic_check, true) { d.dismiss(); ctx.window.decorView.post(onOk) }
        ctx.buttonRow(card, cancel, ok)
        d.root.addView(card)
        d.show()
        cancel.requestFocus()
    }

    fun info(activity: Activity, title: String, text: CharSequence, icon: Int? = R.drawable.ic_info) {
        val d = Overlay(activity)
        val ctx = activity
        val card = ctx.card(760)
        ctx.cardHeader(card, title, null, icon)
        val body = ctx.label(text, 16f, Fonts.regular, Brand.TEXT_DIM, lines = 0).apply { setLineSpacing(0f, 1.25f) }
        val scroll = ScrollView(ctx).apply {
            isFocusable = true
            isVerticalScrollBarEnabled = true
            addView(body)
        }
        val maxH = (ctx.resources.displayMetrics.heightPixels * 0.5f).toInt()
        card.addView(scroll, LinearLayout.LayoutParams(-1, maxH).apply { topMargin = ctx.dp(16) })
        val ok = ctx.pillButton("Schließen", R.drawable.ic_check, true) { d.dismiss() }
        ctx.buttonRow(card, ok)
        d.root.addView(card)
        d.show()
        scroll.post { if (body.height <= scroll.height) { scroll.layoutParams.height = -2; scroll.requestLayout(); ok.requestFocus() } else scroll.requestFocus() }
    }

    // ------------------------------------------------------------------ Farbwahl

    fun colors(activity: Activity, title: String, current: Int, onPick: (Int) -> Unit) {
        val d = Overlay(activity)
        val ctx = activity
        val card = ctx.card(640)
        ctx.cardHeader(card, title, null, R.drawable.ic_palette)
        val grid = LinearLayout(ctx).apply { orientation = LinearLayout.VERTICAL; clipChildren = false }
        var focusTarget: View? = null
        Brand.PALETTE.chunked(6).forEach { chunk ->
            val row = LinearLayout(ctx).apply { orientation = LinearLayout.HORIZONTAL; clipChildren = false }
            chunk.forEach { (name, color) ->
                val sw = FrameLayout(ctx).apply {
                    isFocusable = true
                    isClickable = true
                    contentDescription = name
                    background = StateListDrawable().apply {
                        addState(intArrayOf(android.R.attr.state_focused), GradientDrawable().apply { shape = GradientDrawable.OVAL; setColor(color); setStroke(ctx.dp(4), Brand.FOCUS) })
                        addState(intArrayOf(), GradientDrawable().apply { shape = GradientDrawable.OVAL; setColor(color) })
                    }
                    if (color == current) addView(ctx.icon(R.drawable.ic_check), FrameLayout.LayoutParams(ctx.dp(28), ctx.dp(28), Gravity.CENTER))
                    setOnClickListener { d.dismiss(); ctx.window.decorView.post { onPick(color) } }
                    setOnFocusChangeListener { v, f -> v.animate().scaleX(if (f) 1.15f else 1f).scaleY(if (f) 1.15f else 1f).setDuration(120).start() }
                }
                if (color == current) focusTarget = sw else if (focusTarget == null) focusTarget = sw
                row.addView(sw, LinearLayout.LayoutParams(ctx.dp(64), ctx.dp(64)).apply { rightMargin = ctx.dp(20); bottomMargin = ctx.dp(18) })
            }
            grid.addView(row)
        }
        card.addView(grid, LinearLayout.LayoutParams(-2, -2).apply { topMargin = ctx.dp(24); gravity = Gravity.CENTER_HORIZONTAL })
        d.root.addView(card)
        d.show()
        focusTarget?.requestFocus()
    }

    // ------------------------------------------------------------------ App-Raster

    fun apps(activity: Activity, apps: List<AppEntry>, onPick: (AppEntry) -> Unit) {
        val d = Overlay(activity)
        val ctx = activity
        val card = ctx.card(900)
        ctx.cardHeader(card, "App auswählen", "Wähle eine installierte App für eine neue Kachel.", R.drawable.ic_apps)
        val grid = LinearLayout(ctx).apply { orientation = LinearLayout.VERTICAL; clipChildren = false; clipToPadding = false; setPadding(ctx.dp(8), ctx.dp(8), ctx.dp(8), ctx.dp(8)) }
        val r = ctx.dpf(16f)
        apps.chunked(5).forEach { chunk ->
            val row = LinearLayout(ctx).apply { orientation = LinearLayout.HORIZONTAL; clipChildren = false }
            chunk.forEach { a ->
                val item = LinearLayout(ctx).apply {
                    orientation = LinearLayout.VERTICAL
                    gravity = Gravity.CENTER
                    isFocusable = true
                    isClickable = true
                    setPadding(ctx.dp(8), ctx.dp(12), ctx.dp(8), ctx.dp(10))
                    background = StateListDrawable().apply {
                        addState(intArrayOf(android.R.attr.state_focused), rounded(Brand.ACCENT, r, ctx.dp(2), Brand.FOCUS))
                        addState(intArrayOf(), rounded(Brand.SURFACE2, r))
                    }
                    addView(ImageView(ctx).apply { setImageDrawable(a.icon) }, LinearLayout.LayoutParams(ctx.dp(52), ctx.dp(52)))
                    addView(ctx.label(a.label, 13f, Fonts.medium, lines = 2).apply { gravity = Gravity.CENTER }, LinearLayout.LayoutParams(-1, -2).apply { topMargin = ctx.dp(8) })
                    setOnClickListener { d.dismiss(); ctx.window.decorView.post { onPick(a) } }
                    setOnFocusChangeListener { v, f -> v.animate().scaleX(if (f) 1.07f else 1f).scaleY(if (f) 1.07f else 1f).setDuration(120).start() }
                }
                row.addView(item, LinearLayout.LayoutParams(ctx.dp(150), ctx.dp(118)).apply { rightMargin = ctx.dp(12); bottomMargin = ctx.dp(12) })
            }
            grid.addView(row)
        }
        val scroll = ScrollView(ctx).apply { isVerticalScrollBarEnabled = false; clipChildren = false; addView(grid) }
        val maxH = (ctx.resources.displayMetrics.heightPixels * 0.55f).toInt()
        card.addView(scroll, LinearLayout.LayoutParams(-1, maxH).apply { topMargin = ctx.dp(18) })
        d.root.addView(card)
        d.show()
        (grid.getChildAt(0) as? ViewGroup)?.getChildAt(0)?.requestFocus()
    }

    // ------------------------------------------------------------------ Handy-Begleiter (QR-Code)

    fun qr(activity: Activity, url: String, pin: String, onNewPin: () -> Unit, onDisable: () -> Unit) {
        val d = Overlay(activity)
        val ctx = activity
        val card = LinearLayout(ctx).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            background = rounded(Brand.SURFACE, ctx.dpf(26f), ctx.dp(1), Brand.STROKE)
            setPadding(ctx.dp(36), ctx.dp(32), ctx.dp(36), ctx.dp(32))
            elevation = ctx.dpf(24f)
            clipChildren = false
        }
        val img = ImageView(ctx).apply {
            setImageBitmap(qrBitmap(url, ctx.dp(260)))
            background = rounded(Color.WHITE, ctx.dpf(16f))
            setPadding(ctx.dp(10), ctx.dp(10), ctx.dp(10), ctx.dp(10))
        }
        card.addView(img, LinearLayout.LayoutParams(ctx.dp(280), ctx.dp(280)))
        val col = LinearLayout(ctx).apply { orientation = LinearLayout.VERTICAL; clipChildren = false }
        col.addView(ctx.label("HANDY-FERNBEDIENUNG", 12f, Fonts.bold, Brand.ACCENT2).apply { letterSpacing = 0.22f })
        col.addView(ctx.label("Mit dem Handy steuern", 28f, Fonts.bold, lines = 2), LinearLayout.LayoutParams(-1, -2).apply { topMargin = ctx.dp(8) })
        col.addView(ctx.label("QR-Code mit der Handy-Kamera scannen – oder die Adresse im Handy-Browser öffnen (gleiches WLAN). Dann kannst du tippen, Links schicken, Kacheln anlegen und wie mit der Fernbedienung steuern.", 15f, Fonts.regular, Brand.TEXT_DIM, lines = 0).apply { setLineSpacing(0f, 1.25f) },
            LinearLayout.LayoutParams(-1, -2).apply { topMargin = ctx.dp(10) })
        col.addView(ctx.label(url.substringBefore("?pin="), 18f, Fonts.semibold, Brand.TEXT), LinearLayout.LayoutParams(-1, -2).apply { topMargin = ctx.dp(16) })
        val pinRow = LinearLayout(ctx).apply { orientation = LinearLayout.HORIZONTAL; gravity = Gravity.CENTER_VERTICAL }
        pinRow.addView(ctx.label("PIN", 14f, Fonts.bold, Brand.TEXT_MUTED))
        pinRow.addView(ctx.label(pin.toCharArray().joinToString(" "), 30f, Fonts.display, Brand.ACCENT2), LinearLayout.LayoutParams(-2, -2).apply { leftMargin = ctx.dp(14) })
        col.addView(pinRow, LinearLayout.LayoutParams(-2, -2).apply { topMargin = ctx.dp(8) })
        val close = ctx.pillButton("Fertig", R.drawable.ic_check, true) { d.dismiss() }
        val renew = ctx.pillButton("Neue PIN", R.drawable.ic_refresh, false) { d.dismiss(); onNewPin() }
        val off = ctx.pillButton("Aus", R.drawable.ic_close, false) { d.dismiss(); onDisable() }
        val row = LinearLayout(ctx).apply { orientation = LinearLayout.HORIZONTAL; clipChildren = false }
        row.addView(close, LinearLayout.LayoutParams(-2, ctx.dp(54)))
        row.addView(renew, LinearLayout.LayoutParams(-2, ctx.dp(54)).apply { leftMargin = ctx.dp(12) })
        row.addView(off, LinearLayout.LayoutParams(-2, ctx.dp(54)).apply { leftMargin = ctx.dp(12) })
        col.addView(row, LinearLayout.LayoutParams(-2, -2).apply { topMargin = ctx.dp(22) })
        card.addView(col, LinearLayout.LayoutParams(ctx.dp(500), -2).apply { leftMargin = ctx.dp(34) })
        d.root.addView(card, FrameLayout.LayoutParams(-2, -2, Gravity.CENTER))
        d.show()
        close.requestFocus()
    }

    private fun qrBitmap(text: String, sizePx: Int): android.graphics.Bitmap {
        val q = QrCode.encode(text)
        val quiet = 2
        val n = q.size + quiet * 2
        val scale = maxOf(1, sizePx / n)
        val bmp = android.graphics.Bitmap.createBitmap(n * scale, n * scale, android.graphics.Bitmap.Config.ARGB_8888)
        bmp.eraseColor(Color.WHITE)
        val c = android.graphics.Canvas(bmp)
        val p = android.graphics.Paint().apply { color = 0xFF0B0B12.toInt() }
        for (y in 0 until q.size) for (x in 0 until q.size) {
            if (q.isDark(x, y)) c.drawRect(((x + quiet) * scale).toFloat(), ((y + quiet) * scale).toFloat(), ((x + quiet + 1) * scale).toFloat(), ((y + quiet + 1) * scale).toFloat(), p)
        }
        return bmp
    }

    // ------------------------------------------------------------------ Hinweis-Leiste

    /** Kleine „Tastenkappe“ mit Beschriftung, z. B. [OK] Öffnen. */
    fun keyHint(ctx: android.content.Context, key: String, text: String): View = LinearLayout(ctx).apply {
        orientation = LinearLayout.HORIZONTAL
        gravity = Gravity.CENTER_VERTICAL
        addView(ctx.label(key, 12f, Fonts.bold, Brand.TEXT).apply {
            setPadding(ctx.dp(8), ctx.dp(3), ctx.dp(8), ctx.dp(3))
            background = rounded(0x22FFFFFF, ctx.dpf(6f), ctx.dp(1), 0x55FFFFFF)
        })
        addView(ctx.label(text, 13f, Fonts.medium, Brand.TEXT_DIM), LinearLayout.LayoutParams(-2, -2).apply { leftMargin = ctx.dp(8) })
    }

    /** Toast im Overlord-Stil (Fallback: Standard-Toast). */
    fun toast(activity: Activity, msg: String, iconRes: Int = R.drawable.ic_info) {
        try {
            val v = LinearLayout(activity).apply {
                orientation = LinearLayout.HORIZONTAL
                gravity = Gravity.CENTER_VERTICAL
                setPadding(activity.dp(20), activity.dp(14), activity.dp(24), activity.dp(14))
                background = rounded(0xF01A1A28.toInt(), activity.dpf(30f), activity.dp(1), withAlpha(Brand.ACCENT, 0xAA))
                addView(activity.icon(iconRes, Brand.ACCENT2), LinearLayout.LayoutParams(activity.dp(22), activity.dp(22)).apply { rightMargin = activity.dp(12) })
                addView(activity.label(msg, 16f, Fonts.medium, lines = 2))
            }
            @Suppress("DEPRECATION")
            android.widget.Toast(activity).apply {
                view = v
                duration = android.widget.Toast.LENGTH_SHORT
                setGravity(Gravity.BOTTOM or Gravity.CENTER_HORIZONTAL, 0, activity.dp(48))
            }.show()
        } catch (e: Exception) {
            activity.toast(msg)
        }
    }
}

/** Kurzform für Activities. */
fun Activity.tvToast(msg: String, iconRes: Int = R.drawable.ic_info) = Tv.toast(this, msg, iconRes)
