package de.overlord.tv

import android.animation.ArgbEvaluator
import android.animation.ValueAnimator
import android.content.Context
import android.content.res.ColorStateList
import android.graphics.Bitmap
import android.graphics.Color
import android.graphics.drawable.Drawable
import android.graphics.drawable.GradientDrawable
import android.graphics.drawable.LayerDrawable
import android.os.Handler
import android.os.Looper
import android.text.format.DateFormat
import android.view.Gravity
import android.view.View
import android.view.ViewOutlineProvider
import android.widget.FrameLayout
import android.widget.HorizontalScrollView
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.TextView
import java.util.Date
import java.util.Locale

/** Eine Karte in einer Reihe. */
class CardItem(
    val id: String,
    val title: String,
    val subtitle: String = "",
    val eyebrow: String = "",
    val chips: List<String> = emptyList(),
    val description: String = "",
    val color: Int = Brand.ACCENT,
    val icon: Drawable? = null,
    val iconRes: Int? = null,
    val imageUrls: List<String> = emptyList(),
    val logoUrls: List<String> = emptyList(),
    val heroImageUrls: List<String> = emptyList(),
    val progress: Float = -1f,
    val progressText: String = "",
    val badge: String? = null,
    /** Referer für Bilder fremder Seiten (Hotlink-Schutz). */
    val imageReferer: String? = null,
    val okHint: String = "Öffnen",
    val dashed: Boolean = false,
    val onClick: () -> Unit,
    val onMenu: (() -> Unit)? = null,
)

class RowData(val title: String, val items: List<CardItem>)

/**
 * Startseite im Streaming-Stil: Kopfzeile mit Uhr, großer Bereich oben (Titel, Chips,
 * Beschreibung, Fortschritt, Tastenhinweise) und darunter horizontale Reihen mit 16:9-Karten.
 * Die gewählte Reihe rutscht nach oben, der Hintergrund färbt sich passend zur Karte.
 */
class RowsView(context: Context) : FrameLayout(context) {
    private val screenH = resources.displayMetrics.heightPixels
    private val screenW = resources.displayMetrics.widthPixels
    private val heroH = (screenH * 0.47f).toInt()
    private val rowsTop = (screenH * 0.555f).toInt()
    private val side = context.dp(56)
    private val cardW = context.dp(240)
    private val cardH = cardW * 9 / 16
    private val ui = Handler(Looper.getMainLooper())

    // Hintergrund: Verlauf + farbiger Lichtschein oben links
    private val bgBase = GradientDrawable(GradientDrawable.Orientation.TOP_BOTTOM, intArrayOf(Brand.BG, Brand.BG, Brand.BG))
    private val bgGlow = GradientDrawable().apply {
        gradientType = GradientDrawable.RADIAL_GRADIENT
        gradientRadius = screenW * 0.7f
        setGradientCenter(0.12f, 0.05f)
        colors = intArrayOf(Color.TRANSPARENT, Color.TRANSPARENT)
    }
    private var currentColor = Brand.SURFACE
    private var colorAnim: ValueAnimator? = null

    // Hero
    private val heroArt = FrameLayout(context)
    private val heroImage = FadeImageView(context).apply { scaleType = ImageView.ScaleType.CENTER_CROP }
    private val heroGlyph = ImageView(context).apply { scaleType = ImageView.ScaleType.FIT_CENTER }
    private val heroGlow = View(context)
    private val heroText = LinearLayout(context)
    private val heroEyebrow = context.label("", 13f, Fonts.bold, Brand.ACCENT2).apply { letterSpacing = 0.2f }
    private val heroTitle = context.label("", 42f, Fonts.display).apply { setShadowLayer(16f, 0f, 2f, 0xAA000000.toInt()) }
    private val heroChips = LinearLayout(context)
    private val heroDesc = context.label("", 16f, Fonts.regular, 0xFFD6D6E2.toInt(), lines = 2).apply {
        setLineSpacing(0f, 1.25f)
        setShadowLayer(10f, 0f, 1f, 0xAA000000.toInt())
    }
    private val heroProgressBox = LinearLayout(context)
    private val heroProgressFill = View(context)
    private val heroProgressTrack = FrameLayout(context)
    private val heroProgressText = context.label("", 13f, Fonts.semibold, Brand.TEXT_DIM)
    private val heroHints = LinearLayout(context)

    // Kopfzeile
    private val clock = context.label("", 24f, Fonts.semibold)
    private val brandText = context.label("OVERLORD", 15f, Fonts.bold).apply { letterSpacing = 0.34f; setPadding(context.dp(12), 0, 0, 0) }
    private val topActions = LinearLayout(context)
    private val date = context.label("", 13f, Fonts.medium, Brand.TEXT_DIM)

    // Reihen-Container misst seine Kinder ohne Höhenbegrenzung – sonst werden untere Reihen abgeschnitten
    private val rowsClip = object : FrameLayout(context) {
        override fun onMeasure(widthMeasureSpec: Int, heightMeasureSpec: Int) {
            super.onMeasure(widthMeasureSpec, heightMeasureSpec)
            val w = MeasureSpec.makeMeasureSpec(measuredWidth, MeasureSpec.EXACTLY)
            val h = MeasureSpec.makeMeasureSpec(0, MeasureSpec.UNSPECIFIED)
            for (i in 0 until childCount) getChildAt(i).measure(w, h)
        }
    }
    private val rowsContainer = LinearLayout(context)
    private val emptyText = context.label("", 18f, Fonts.medium, Brand.TEXT_DIM, lines = 3)

    private val holders = ArrayList<RowHolder>()
    private var focusedRow = -1
    var focusedItem: CardItem? = null
        private set

    /** Ersetzt den Hero-Text (z. B. im Verschiebe-Modus). */
    var heroOverride: Triple<String, String, String>? = null
        set(value) { field = value; focusedItem?.let { showHero(it, animate = false) } }

    var onItemFocused: ((CardItem) -> Unit)? = null

    private class RowHolder(val view: LinearLayout, val scroll: HorizontalScrollView, val cards: List<CardView>)

    private val tick = object : Runnable {
        override fun run() {
            val now = Date()
            clock.text = DateFormat.getTimeFormat(context).format(now)
            date.text = java.text.SimpleDateFormat("EEE, d. MMMM", Locale.GERMAN).format(now)
            ui.postDelayed(this, 15_000)
        }
    }

    init {
        background = LayerDrawable(arrayOf<Drawable>(bgBase, bgGlow))
        clipChildren = false

        // Hero-Bild rechts mit weichen Kanten
        val imgW = (screenW * 0.64f).toInt()
        val imgH = heroH + context.dp(56)
        heroArt.addView(heroGlow, LayoutParams(context.dp(420), context.dp(420), Gravity.CENTER))
        heroArt.addView(heroImage, LayoutParams(-1, -1))
        heroArt.addView(heroGlyph, LayoutParams(context.dp(170), context.dp(170), Gravity.CENTER))
        addView(heroArt, LayoutParams(imgW, imgH, Gravity.END or Gravity.TOP))
        addView(View(context).apply {
            background = GradientDrawable(GradientDrawable.Orientation.TOP_BOTTOM, intArrayOf(0x8C000000.toInt(), Color.TRANSPARENT))
        }, LayoutParams(-1, context.dp(130), Gravity.TOP))

        // Kopfzeile: Logo links, Uhr rechts
        val top = FrameLayout(context).apply { setPadding(side, context.dp(26), side, 0) }
        val brand = LinearLayout(context).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            addView(ImageView(context).apply { setImageResource(R.drawable.ic_logo) }, LinearLayout.LayoutParams(context.dp(30), context.dp(30)))
            addView(brandText, LinearLayout.LayoutParams(-2, -2))
        }
        top.addView(brand, LayoutParams(-2, -2, Gravity.START or Gravity.CENTER_VERTICAL))
        val time = LinearLayout(context).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.END
            addView(clock)
            addView(date, LinearLayout.LayoutParams(-2, -2).apply { topMargin = context.dp(2) })
        }
        topActions.orientation = LinearLayout.HORIZONTAL
        topActions.gravity = Gravity.CENTER_VERTICAL
        val right = LinearLayout(context).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            addView(topActions)
            addView(time, LinearLayout.LayoutParams(-2, -2).apply { leftMargin = context.dp(26) })
        }
        top.addView(right, LayoutParams(-2, -2, Gravity.END or Gravity.CENTER_VERTICAL))
        addView(top, LayoutParams(-1, -2, Gravity.TOP))

        // Hero-Text links
        heroText.orientation = LinearLayout.VERTICAL
        heroText.setPadding(side, 0, 0, 0)
        val textW = (screenW * 0.52f).toInt()
        heroText.addView(heroEyebrow)
        heroText.addView(heroTitle, LinearLayout.LayoutParams(textW, -2).apply { topMargin = context.dp(6) })
        heroChips.orientation = LinearLayout.HORIZONTAL
        heroText.addView(heroChips, LinearLayout.LayoutParams(textW, -2).apply { topMargin = context.dp(10) })
        heroText.addView(heroDesc, LinearLayout.LayoutParams(textW, -2).apply { topMargin = context.dp(12) })
        heroProgressBox.orientation = LinearLayout.HORIZONTAL
        heroProgressBox.gravity = Gravity.CENTER_VERTICAL
        heroProgressTrack.background = rounded(0x33FFFFFF, context.dpf(3f))
        heroProgressFill.background = rounded(Brand.ACCENT2, context.dpf(3f))
        heroProgressTrack.addView(heroProgressFill, LayoutParams(0, -1))
        heroProgressBox.addView(heroProgressTrack, LinearLayout.LayoutParams(context.dp(200), context.dp(5)))
        heroProgressBox.addView(heroProgressText, LinearLayout.LayoutParams(-2, -2).apply { leftMargin = context.dp(14) })
        heroHints.orientation = LinearLayout.HORIZONTAL
        val bottomRow = LinearLayout(context).apply { orientation = LinearLayout.HORIZONTAL; gravity = Gravity.CENTER_VERTICAL }
        bottomRow.addView(heroProgressBox, LinearLayout.LayoutParams(-2, -2).apply { rightMargin = context.dp(28) })
        bottomRow.addView(heroHints)
        heroText.addView(bottomRow, LinearLayout.LayoutParams(-2, -2).apply { topMargin = context.dp(14) })
        addView(heroText, LayoutParams(-1, rowsTop - context.dp(84), Gravity.TOP).apply { topMargin = context.dp(84) })

        // Reihen
        rowsContainer.orientation = LinearLayout.VERTICAL
        rowsContainer.clipChildren = false
        rowsContainer.clipToPadding = false
        rowsClip.clipChildren = true
        rowsClip.addView(rowsContainer, LayoutParams(-1, -2))
        emptyText.setPadding(side, context.dp(24), side, 0)
        emptyText.visibility = View.GONE
        rowsClip.addView(emptyText)
        addView(rowsClip, LayoutParams(-1, -1).apply { topMargin = rowsTop })

        applyColor(Brand.SURFACE)
    }

    override fun onAttachedToWindow() {
        super.onAttachedToWindow()
        ui.post(tick)
    }

    override fun onDetachedFromWindow() {
        ui.removeCallbacks(tick)
        super.onDetachedFromWindow()
    }

    /** Text neben dem Logo (Standard „OVERLORD“, in der Video-Ansicht der Seitenname). */
    fun setBrandText(text: String) { brandText.text = text.uppercase() }

    /** Hero-Bereich ohne Karte füllen (z. B. „Lade …“). */
    fun showInfo(eyebrow: String, title: String, description: String, color: Int = Brand.SURFACE) {
        heroEyebrow.text = eyebrow
        heroEyebrow.visibility = if (eyebrow.isBlank()) View.GONE else View.VISIBLE
        heroTitle.text = title
        heroTitle.textSize = if (title.length <= 18) 42f else if (title.length <= 26) 36f else 30f
        heroDesc.text = description
        heroDesc.visibility = if (description.isBlank()) View.GONE else View.VISIBLE
        heroChips.removeAllViews(); heroChips.visibility = View.GONE
        heroProgressBox.visibility = View.GONE
        heroHints.removeAllViews()
        heroImage.tag = null; heroImage.setImageDrawable(null); heroImage.visibility = View.GONE
        heroGlyph.visibility = View.GONE; heroGlow.visibility = View.GONE
        animateColor(color)
    }

    /** Fokus wieder auf die zuletzt gewählte Karte (oder die erste) setzen. */
    fun refocus() {
        val all = holders.flatMap { it.cards }
        (all.firstOrNull { it.item.id == focusedItem?.id } ?: all.firstOrNull())?.requestFocus()
    }

    /** Knopf in der Kopfzeile (z. B. „Suchen“) – erreichbar mit ▲ aus der ersten Reihe. */
    fun addTopAction(iconRes: Int, text: String, onClick: () -> Unit) {
        val colors = ColorStateList(arrayOf(intArrayOf(android.R.attr.state_focused), intArrayOf()), intArrayOf(Brand.BG, Brand.TEXT))
        val pill = LinearLayout(context).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            isFocusable = true
            isClickable = true
            setPadding(context.dp(16), context.dp(9), context.dp(20), context.dp(9))
            background = android.graphics.drawable.StateListDrawable().apply {
                addState(intArrayOf(android.R.attr.state_focused), rounded(Brand.FOCUS, context.dpf(24f)))
                addState(intArrayOf(), rounded(0x1FFFFFFF, context.dpf(24f), context.dp(1), 0x33FFFFFF))
            }
            addView(context.icon(iconRes).apply { imageTintList = colors; isDuplicateParentStateEnabled = true }, LinearLayout.LayoutParams(context.dp(20), context.dp(20)).apply { rightMargin = context.dp(10) })
            addView(context.label(text, 15f, Fonts.semibold).apply { setTextColor(colors); isDuplicateParentStateEnabled = true })
            setOnClickListener { onClick() }
            setOnFocusChangeListener { v, f -> v.animate().scaleX(if (f) 1.06f else 1f).scaleY(if (f) 1.06f else 1f).setDuration(120).start() }
        }
        topActions.addView(pill, LinearLayout.LayoutParams(-2, -2).apply { if (topActions.childCount > 0) leftMargin = context.dp(12) })
    }

    fun setMessage(msg: String?) {
        emptyText.text = msg ?: ""
        emptyText.visibility = if (msg == null) View.GONE else View.VISIBLE
    }

    fun setRows(rows: List<RowData>, focusId: String? = focusedItem?.id) {
        rowsContainer.removeAllViews()
        rowsContainer.translationY = 0f
        holders.clear()
        val visibleRows = rows.filter { it.items.isNotEmpty() }
        visibleRows.forEachIndexed { rowIndex, row ->
            val rowView = LinearLayout(context).apply {
                orientation = LinearLayout.VERTICAL
                clipChildren = false
                clipToPadding = false
            }
            val header = LinearLayout(context).apply {
                orientation = LinearLayout.HORIZONTAL
                gravity = Gravity.CENTER_VERTICAL
                setPadding(side, 0, side, 0)
            }
            header.addView(context.label(row.title, 20f, Fonts.bold))
            if (row.items.size > 1) header.addView(context.label("${row.items.size}", 14f, Fonts.semibold, Brand.TEXT_MUTED).apply {
                setPadding(context.dp(10), 0, 0, 0)
            })
            rowView.addView(header)
            val scroll = HorizontalScrollView(context).apply {
                isHorizontalScrollBarEnabled = false
                overScrollMode = View.OVER_SCROLL_NEVER
                clipChildren = false
                clipToPadding = false
                isFocusable = false
                isSmoothScrollingEnabled = true
                setPadding(side, context.dp(16), side, context.dp(22))
            }
            val strip = LinearLayout(context).apply {
                orientation = LinearLayout.HORIZONTAL
                clipChildren = false
                clipToPadding = false
            }
            val cards = row.items.map { item ->
                CardView(context, item).also { card ->
                    card.setOnFocusChangeListener { v, hasFocus ->
                        card.applyFocus(hasFocus)
                        if (hasFocus) onCardFocused(rowIndex, card, scroll, v)
                    }
                    strip.addView(card, LinearLayout.LayoutParams(cardW, cardH).apply { rightMargin = context.dp(20) })
                }
            }
            scroll.addView(strip)
            rowView.addView(scroll)
            rowView.alpha = 0.5f
            rowsContainer.addView(rowView)
            holders.add(RowHolder(rowView, scroll, cards))
        }
        focusedRow = -1
        val target = holders.flatMap { it.cards }.firstOrNull { it.item.id == focusId }
            ?: holders.firstOrNull()?.cards?.firstOrNull()
        if (target == null) focusedItem = null
        post { target?.requestFocus() }
    }

    fun focusItem(id: String) {
        holders.flatMap { it.cards }.firstOrNull { it.item.id == id }?.requestFocus()
    }

    private fun onCardFocused(rowIndex: Int, card: CardView, scroll: HorizontalScrollView, v: View) {
        val changed = focusedItem?.id != card.item.id
        focusedItem = card.item
        showHero(card.item, animate = changed)
        onItemFocused?.invoke(card.item)
        // Gewählte Karte möglichst links ausrichten
        scroll.post { scroll.smoothScrollTo((v.left - context.dp(2)).coerceAtLeast(0), 0) }
        if (rowIndex != focusedRow) {
            focusedRow = rowIndex
            val holder = holders.getOrNull(rowIndex) ?: return
            holder.view.post {
                rowsContainer.animate().translationY(-holder.view.top.toFloat()).setDuration(260).start()
            }
            holders.forEachIndexed { i, h ->
                h.view.animate().alpha(when { i < rowIndex -> 0f; i == rowIndex -> 1f; else -> 0.5f }).setDuration(220).start()
            }
        }
    }

    private fun chip(text: String, accent: Boolean): TextView = context.label(text, 13f, Fonts.semibold, if (accent) Brand.BG else Brand.TEXT).apply {
        setPadding(context.dp(10), context.dp(5), context.dp(10), context.dp(5))
        background = if (accent) rounded(Brand.ACCENT2, context.dpf(6f)) else rounded(0x1FFFFFFF, context.dpf(6f), context.dp(1), 0x33FFFFFF)
    }

    private fun showHero(item: CardItem, animate: Boolean) {
        val o = heroOverride
        heroEyebrow.text = if (o != null) "VERSCHIEBEN" else item.eyebrow
        heroEyebrow.visibility = if (heroEyebrow.text.isNullOrBlank()) View.GONE else View.VISIBLE
        val title = o?.first ?: item.title
        heroTitle.text = title
        heroTitle.textSize = when { title.length <= 18 -> 42f; title.length <= 26 -> 36f; else -> 30f }
        heroDesc.text = o?.third ?: item.description
        heroDesc.visibility = if (heroDesc.text.isNullOrBlank()) View.GONE else View.VISIBLE

        heroChips.removeAllViews()
        val chips = if (o != null) listOf(o.second) else item.chips
        chips.filter { it.isNotBlank() }.take(5).forEachIndexed { i, c ->
            heroChips.addView(chip(c, false), LinearLayout.LayoutParams(-2, -2).apply { if (i > 0) leftMargin = context.dp(8) })
        }
        heroChips.visibility = if (heroChips.childCount == 0) View.GONE else View.VISIBLE

        if (item.progress >= 0f && o == null) {
            heroProgressBox.visibility = View.VISIBLE
            heroProgressText.text = item.progressText
            heroProgressTrack.post {
                heroProgressFill.layoutParams = LayoutParams((heroProgressTrack.width * item.progress.coerceIn(0f, 1f)).toInt(), -1)
            }
        } else heroProgressBox.visibility = View.GONE

        heroHints.removeAllViews()
        if (o == null) {
            heroHints.addView(Tv.keyHint(context, "OK", item.okHint))
            if (item.onMenu != null) heroHints.addView(Tv.keyHint(context, "☰", "Optionen"), LinearLayout.LayoutParams(-2, -2).apply { leftMargin = context.dp(20) })
        } else {
            heroHints.addView(Tv.keyHint(context, "◀ ▶", "verschieben"))
            heroHints.addView(Tv.keyHint(context, "OK", "fertig"), LinearLayout.LayoutParams(-2, -2).apply { leftMargin = context.dp(20) })
        }

        if (animate) {
            heroText.alpha = 0.25f
            heroText.translationX = context.dpf(14f)
            heroText.animate().alpha(1f).translationX(0f).setDuration(220).start()
        }

        // Artwork rechts
        when {
            item.heroImageUrls.isNotEmpty() || item.imageUrls.isNotEmpty() -> {
                heroGlyph.visibility = View.GONE
                heroGlow.visibility = View.GONE
                heroImage.visibility = View.VISIBLE
                val urls = item.heroImageUrls.ifEmpty { item.imageUrls }
                if (animate) { heroImage.alpha = 0f }
                ImageLoader.load(heroImage, urls, 1280, item.imageReferer) { bmp: Bitmap ->
                    heroImage.animate().alpha(0.92f).setDuration(260).start()
                    if (focusedItem === item) animateColor(tameColor(dominantColor(bmp) ?: item.color))
                }
                animateColor(item.color)
            }
            item.icon != null || item.iconRes != null || item.logoUrls.isNotEmpty() -> {
                heroImage.tag = null
                heroImage.setImageDrawable(null)
                heroImage.visibility = View.GONE
                heroGlow.visibility = View.VISIBLE
                heroGlow.background = GradientDrawable().apply {
                    gradientType = GradientDrawable.RADIAL_GRADIENT
                    gradientRadius = context.dpf(210f)
                    colors = intArrayOf(withAlpha(item.color, 0x99), Color.TRANSPARENT)
                }
                heroGlyph.visibility = View.VISIBLE
                heroGlyph.imageTintList = null
                heroGlyph.alpha = 1f
                when {
                    item.icon != null -> { heroGlyph.tag = null; heroGlyph.setImageDrawable(item.icon) }
                    item.logoUrls.isNotEmpty() -> ImageLoader.load(heroGlyph, item.logoUrls, 256)
                    else -> {
                        heroGlyph.tag = null
                        heroGlyph.setImageResource(item.iconRes!!)
                        heroGlyph.imageTintList = ColorStateList.valueOf(Color.WHITE)
                        heroGlyph.alpha = 0.22f
                    }
                }
                if (animate) { heroGlyph.scaleX = 0.85f; heroGlyph.scaleY = 0.85f; heroGlyph.animate().scaleX(1f).scaleY(1f).setDuration(260).start() }
                animateColor(item.color)
            }
            else -> {
                heroImage.tag = null
                heroImage.setImageDrawable(null)
                heroImage.visibility = View.GONE
                heroGlyph.visibility = View.GONE
                heroGlow.visibility = View.GONE
                animateColor(item.color)
            }
        }
    }

    private fun animateColor(target: Int) {
        colorAnim?.cancel()
        val from = currentColor
        colorAnim = ValueAnimator.ofObject(ArgbEvaluator(), from, target).apply {
            duration = 500
            addUpdateListener { applyColor(it.animatedValue as Int) }
            start()
        }
    }

    private fun applyColor(c: Int) {
        currentColor = c
        bgBase.colors = intArrayOf(blend(Brand.BG, c, 0.30f), blend(Brand.BG, c, 0.10f), Brand.BG)
        bgGlow.colors = intArrayOf(withAlpha(c, 0x70), Color.TRANSPARENT)
    }
}

/** 16:9-Karte: wird bei Fokus größer und bekommt einen Rahmen. */
class CardView(context: Context, val item: CardItem) : FrameLayout(context) {
    private val border = View(context)

    init {
        isFocusable = true
        isClickable = true
        val r = context.dpf(14f)
        background = if (item.dashed) {
            GradientDrawable().apply {
                cornerRadius = r
                setColor(0x14FFFFFF)
                setStroke(context.dp(2), 0x55FFFFFF, context.dpf(10f), context.dpf(7f))
            }
        } else GradientDrawable(GradientDrawable.Orientation.TL_BR, intArrayOf(blend(item.color, Color.WHITE, 0.08f), darken(item.color, 0.42f))).apply { cornerRadius = r }
        outlineProvider = ViewOutlineProvider.BACKGROUND
        clipToOutline = true

        val icon = item.icon
        val iconIsBanner = icon != null && icon.intrinsicHeight > 0 && icon.intrinsicWidth.toFloat() / icon.intrinsicHeight > 1.4f
        var bottomTitle = true
        var scrim = false

        when {
            item.imageUrls.isNotEmpty() -> {
                val img = ImageView(context).apply { scaleType = ImageView.ScaleType.CENTER_CROP }
                addView(img, LayoutParams(-1, -1))
                ImageLoader.load(img, item.imageUrls, 480, item.imageReferer)
                scrim = true
                if (item.logoUrls.isNotEmpty()) {
                    val logo = ImageView(context).apply {
                        scaleType = ImageView.ScaleType.CENTER_CROP
                        outlineProvider = ViewOutlineProvider.BACKGROUND
                        clipToOutline = true
                        visibility = View.INVISIBLE
                    }
                    addView(logo, LayoutParams(context.dp(30), context.dp(30), Gravity.TOP or Gravity.START).apply { topMargin = context.dp(10); leftMargin = context.dp(10) })
                    ImageLoader.load(logo, item.logoUrls, 96) {
                        logo.background = rounded(Color.WHITE, context.dpf(8f))
                        logo.visibility = View.VISIBLE
                    }
                }
            }
            icon != null && iconIsBanner -> {
                addView(ImageView(context).apply { scaleType = ImageView.ScaleType.CENTER_CROP; setImageDrawable(icon) }, LayoutParams(-1, -1))
                bottomTitle = false
            }
            icon != null -> {
                addView(ImageView(context).apply { setImageDrawable(icon) }, LayoutParams(context.dp(62), context.dp(62), Gravity.CENTER).apply { bottomMargin = context.dp(16) })
            }
            item.logoUrls.isNotEmpty() -> {
                val logo = ImageView(context).apply {
                    scaleType = ImageView.ScaleType.CENTER_CROP
                    background = rounded(0x22FFFFFF, context.dpf(14f))
                    outlineProvider = ViewOutlineProvider.BACKGROUND
                    clipToOutline = true
                }
                addView(logo, LayoutParams(context.dp(58), context.dp(58), Gravity.CENTER).apply { bottomMargin = context.dp(18) })
                // Kein Symbol ladbar → Anfangsbuchstabe als Ersatz
                val letter = context.label(item.title.take(1).uppercase(), 30f, Fonts.bold).apply { gravity = Gravity.CENTER }
                addView(letter, LayoutParams(context.dp(58), context.dp(58), Gravity.CENTER).apply { bottomMargin = context.dp(18) })
                ImageLoader.load(logo, item.logoUrls, 192) { letter.visibility = View.GONE }
            }
            item.iconRes != null -> {
                addView(context.icon(item.iconRes, if (item.dashed) Brand.TEXT_DIM else Brand.TEXT), LayoutParams(context.dp(40), context.dp(40), Gravity.CENTER).apply { bottomMargin = context.dp(18) })
            }
            else -> {
                addView(context.label(item.title, 22f, Fonts.bold, lines = 2).apply {
                    gravity = Gravity.CENTER
                    setPadding(context.dp(14), 0, context.dp(14), if (item.progress >= 0) context.dp(8) else 0)
                    setShadowLayer(10f, 0f, 2f, 0x99000000.toInt())
                }, LayoutParams(-1, -1))
                bottomTitle = false
            }
        }

        if (scrim) {
            addView(View(context).apply {
                background = GradientDrawable(GradientDrawable.Orientation.TOP_BOTTOM, intArrayOf(Color.TRANSPARENT, 0xE6000000.toInt()))
            }, LayoutParams(-1, context.dp(72), Gravity.BOTTOM))
        }
        if (bottomTitle) {
            val texts = LinearLayout(context).apply { orientation = LinearLayout.VERTICAL }
            texts.addView(context.label(item.title, 15f, Fonts.semibold).apply { setShadowLayer(6f, 0f, 1f, 0x99000000.toInt()) })
            if (item.subtitle.isNotBlank()) texts.addView(context.label(item.subtitle, 12f, Fonts.medium, 0xCCFFFFFF.toInt()), LinearLayout.LayoutParams(-2, -2).apply { topMargin = context.dp(2) })
            addView(texts, LayoutParams(-1, -2, Gravity.BOTTOM).apply {
                leftMargin = context.dp(12); rightMargin = context.dp(12)
                bottomMargin = if (item.progress >= 0) context.dp(13) else context.dp(10)
            })
        }

        item.badge?.let { b ->
            addView(context.label(b, 11f, Fonts.bold).apply {
                setPadding(context.dp(8), context.dp(4), context.dp(8), context.dp(4))
                background = rounded(0xCC000000.toInt(), context.dpf(20f))
            }, LayoutParams(-2, -2, Gravity.TOP or Gravity.END).apply { topMargin = context.dp(9); rightMargin = context.dp(9) })
        }

        if (item.progress >= 0f) {
            val track = FrameLayout(context).apply { setBackgroundColor(0x55FFFFFF) }
            val fill = View(context).apply { setBackgroundColor(Brand.ACCENT2) }
            track.addView(fill, LayoutParams(0, -1))
            addView(track, LayoutParams(-1, context.dp(5), Gravity.BOTTOM))
            track.post { fill.layoutParams = LayoutParams((track.width * item.progress.coerceIn(0f, 1f)).toInt(), -1) }
        }

        border.background = GradientDrawable().apply {
            cornerRadius = r
            setColor(Color.TRANSPARENT)
            setStroke(context.dp(3), Brand.FOCUS)
        }
        border.visibility = View.INVISIBLE
        addView(border, LayoutParams(-1, -1))

        setOnClickListener { item.onClick() }
        item.onMenu?.let { menu -> setOnLongClickListener { menu(); true } }
    }

    fun applyFocus(focused: Boolean) {
        border.visibility = if (focused) View.VISIBLE else View.INVISIBLE
        animate().scaleX(if (focused) 1.1f else 1f).scaleY(if (focused) 1.1f else 1f)
            .translationZ(if (focused) context.dpf(16f) else 0f).setDuration(170).start()
    }
}

/** Bild mit weich auslaufenden Kanten (links und unten) – echte Transparenz statt farbiger Verlaufsflächen. */
class FadeImageView(context: Context) : ImageView(context) {
    // Zwei getrennte Masken (ComposeShader aus zwei Verläufen wird vor Android 9 nicht hardwarebeschleunigt)
    private val leftPaint = android.graphics.Paint(android.graphics.Paint.ANTI_ALIAS_FLAG).apply {
        xfermode = android.graphics.PorterDuffXfermode(android.graphics.PorterDuff.Mode.DST_IN)
    }
    private val bottomPaint = android.graphics.Paint(android.graphics.Paint.ANTI_ALIAS_FLAG).apply {
        xfermode = android.graphics.PorterDuffXfermode(android.graphics.PorterDuff.Mode.DST_IN)
    }
    private var shaderW = -1
    private var shaderH = -1

    override fun onDraw(canvas: android.graphics.Canvas) {
        val w = width.toFloat()
        val h = height.toFloat()
        if (w <= 0f || h <= 0f) return
        if (shaderW != width || shaderH != height) {
            shaderW = width
            shaderH = height
            leftPaint.shader = android.graphics.LinearGradient(0f, 0f, w * 0.55f, 0f,
                intArrayOf(Color.TRANSPARENT, 0x80000000.toInt(), Color.BLACK), floatArrayOf(0f, 0.45f, 1f), android.graphics.Shader.TileMode.CLAMP)
            bottomPaint.shader = android.graphics.LinearGradient(0f, h, 0f, h * 0.45f,
                intArrayOf(Color.TRANSPARENT, Color.BLACK), null, android.graphics.Shader.TileMode.CLAMP)
        }
        val save = canvas.saveLayer(0f, 0f, w, h, null)
        super.onDraw(canvas)
        canvas.drawRect(0f, 0f, w, h, leftPaint)
        canvas.drawRect(0f, 0f, w, h, bottomPaint)
        canvas.restoreToCount(save)
    }
}
