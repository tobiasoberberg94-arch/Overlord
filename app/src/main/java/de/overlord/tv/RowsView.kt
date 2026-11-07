package de.overlord.tv

import android.animation.ArgbEvaluator
import android.animation.ValueAnimator
import android.content.Context
import android.graphics.Bitmap
import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.Drawable
import android.graphics.drawable.GradientDrawable
import android.text.TextUtils
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.view.ViewOutlineProvider
import android.widget.FrameLayout
import android.widget.HorizontalScrollView
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.TextView

/** Eine Karte in einer Reihe. */
class CardItem(
    val id: String,
    val title: String,
    val info: String = "",
    val description: String = "",
    val color: Int = Brand.ACCENT,
    val icon: Drawable? = null,
    val imageUrls: List<String> = emptyList(),
    val heroImageUrls: List<String> = emptyList(),
    val progress: Float = -1f,
    val badge: String? = null,
    val bigLabel: String? = null,
    val onClick: () -> Unit,
    val onMenu: (() -> Unit)? = null,
)

class RowData(val title: String, val items: List<CardItem>)

/**
 * Startseite im Streaming-Stil: großer Bereich oben (Titel, Infozeile, Beschreibung),
 * darunter horizontale Reihen mit 16:9-Karten. Die gewählte Reihe rutscht nach oben,
 * der Hintergrund färbt sich passend zur gewählten Karte.
 */
class RowsView(context: Context) : FrameLayout(context) {
    private val screenH = resources.displayMetrics.heightPixels
    private val screenW = resources.displayMetrics.widthPixels
    private val heroH = (screenH * 0.44f).toInt()
    private val side = context.dp(56)
    private val cardW = context.dp(232)
    private val cardH = cardW * 9 / 16

    private val bg = GradientDrawable(GradientDrawable.Orientation.TOP_BOTTOM, intArrayOf(Brand.BG, Brand.BG, Brand.BG))
    private val heroFadeLeft = GradientDrawable(GradientDrawable.Orientation.LEFT_RIGHT, intArrayOf(Brand.BG, Color.TRANSPARENT))
    private val heroFadeBottom = GradientDrawable(GradientDrawable.Orientation.TOP_BOTTOM, intArrayOf(Color.TRANSPARENT, Brand.BG))
    private var currentColor = Brand.SURFACE
    private var colorAnim: ValueAnimator? = null

    private val heroImage = ImageView(context).apply { scaleType = ImageView.ScaleType.CENTER_CROP; alpha = 0.9f }
    private val heroTitle = TextView(context)
    private val heroInfo = TextView(context)
    private val heroDesc = TextView(context)
    private val rowsClip = FrameLayout(context)
    private val rowsContainer = LinearLayout(context)
    private val emptyText = TextView(context)

    private val holders = ArrayList<RowHolder>()
    private var focusedRow = -1
    var focusedItem: CardItem? = null
        private set

    /** Wird z. B. im Verschiebe-Modus gesetzt und ersetzt den Hero-Text. */
    var heroOverride: Triple<String, String, String>? = null
        set(value) { field = value; focusedItem?.let { showHero(it) } }

    var onItemFocused: ((CardItem) -> Unit)? = null

    private class RowHolder(val view: LinearLayout, val scroll: HorizontalScrollView, val cards: List<CardView>)

    init {
        background = bg
        clipChildren = false

        val imgW = (screenW * 0.62f).toInt()
        val imgH = heroH + context.dp(40)
        addView(heroImage, LayoutParams(imgW, imgH, Gravity.END or Gravity.TOP))
        addView(View(context).apply { background = heroFadeLeft }, LayoutParams(imgW / 2, imgH, Gravity.END or Gravity.TOP).apply { rightMargin = imgW / 2 })
        addView(View(context).apply { background = heroFadeBottom }, LayoutParams(imgW, context.dp(90), Gravity.END or Gravity.TOP).apply { topMargin = imgH - context.dp(90) })

        val hero = LinearLayout(context).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(side, context.dp(22), side, 0)
        }
        val brand = LinearLayout(context).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            addView(ImageView(context).apply { setImageResource(R.drawable.ic_logo) }, LinearLayout.LayoutParams(context.dp(28), context.dp(28)))
            addView(TextView(context).apply {
                text = "OVERLORD"
                setTextColor(Brand.TEXT)
                textSize = 15f
                typeface = Typeface.DEFAULT_BOLD
                letterSpacing = 0.32f
                setPadding(context.dp(10), 0, 0, 0)
            })
        }
        hero.addView(brand)
        heroTitle.apply {
            setTextColor(Brand.TEXT)
            textSize = 38f
            typeface = Typeface.DEFAULT_BOLD
            maxLines = 1
            ellipsize = TextUtils.TruncateAt.END
            setShadowLayer(12f, 0f, 2f, 0xCC000000.toInt())
        }
        heroInfo.apply {
            setTextColor(Brand.ACCENT2)
            textSize = 15f
            typeface = Typeface.DEFAULT_BOLD
            maxLines = 1
            ellipsize = TextUtils.TruncateAt.END
        }
        heroDesc.apply {
            setTextColor(0xFFD4D4E0.toInt())
            textSize = 15f
            maxLines = 3
            ellipsize = TextUtils.TruncateAt.END
            setLineSpacing(0f, 1.15f)
            setShadowLayer(8f, 0f, 1f, 0xCC000000.toInt())
        }
        val textW = (screenW * 0.5f).toInt()
        hero.addView(heroTitle, LinearLayout.LayoutParams(textW, ViewGroup.LayoutParams.WRAP_CONTENT).apply { topMargin = context.dp(16) })
        hero.addView(heroInfo, LinearLayout.LayoutParams(textW, ViewGroup.LayoutParams.WRAP_CONTENT).apply { topMargin = context.dp(4) })
        hero.addView(heroDesc, LinearLayout.LayoutParams(textW, ViewGroup.LayoutParams.WRAP_CONTENT).apply { topMargin = context.dp(10) })
        addView(hero, LayoutParams(LayoutParams.MATCH_PARENT, heroH))

        rowsContainer.orientation = LinearLayout.VERTICAL
        rowsContainer.clipChildren = false
        rowsContainer.clipToPadding = false
        rowsClip.clipChildren = true
        rowsClip.addView(rowsContainer, LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.WRAP_CONTENT))
        addView(rowsClip, LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.MATCH_PARENT).apply { topMargin = heroH })

        emptyText.apply {
            setTextColor(Brand.TEXT_DIM)
            textSize = 18f
            setPadding(side, context.dp(20), side, 0)
            visibility = View.GONE
        }
        rowsClip.addView(emptyText)
        applyColor(Brand.SURFACE)
    }

    fun setMessage(msg: String?) {
        emptyText.text = msg ?: ""
        emptyText.visibility = if (msg == null) View.GONE else View.VISIBLE
    }

    fun setRows(rows: List<RowData>, focusId: String? = focusedItem?.id) {
        rowsContainer.removeAllViews()
        holders.clear()
        val visibleRows = rows.filter { it.items.isNotEmpty() }
        visibleRows.forEachIndexed { rowIndex, row ->
            val rowView = LinearLayout(context).apply {
                orientation = LinearLayout.VERTICAL
                clipChildren = false
                clipToPadding = false
                setPadding(0, 0, 0, context.dp(4))
            }
            rowView.addView(TextView(context).apply {
                text = row.title
                setTextColor(Brand.TEXT)
                textSize = 18f
                typeface = Typeface.DEFAULT_BOLD
                setPadding(side, context.dp(4), side, 0)
            })
            val scroll = HorizontalScrollView(context).apply {
                isHorizontalScrollBarEnabled = false
                overScrollMode = View.OVER_SCROLL_NEVER
                clipChildren = false
                clipToPadding = false
                isFocusable = false
                isSmoothScrollingEnabled = true
                setPadding(side, context.dp(14), side, context.dp(16))
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
                    strip.addView(card, LinearLayout.LayoutParams(cardW, cardH).apply { rightMargin = context.dp(18) })
                }
            }
            scroll.addView(strip)
            rowView.addView(scroll)
            rowsContainer.addView(rowView)
            holders.add(RowHolder(rowView, scroll, cards))
        }
        focusedRow = -1
        val target = holders.flatMap { it.cards }.firstOrNull { it.item.id == focusId }
            ?: holders.firstOrNull()?.cards?.firstOrNull()
        post { target?.requestFocus() }
        if (target == null) focusedItem = null
    }

    fun focusItem(id: String) {
        holders.flatMap { it.cards }.firstOrNull { it.item.id == id }?.requestFocus()
    }

    private fun onCardFocused(rowIndex: Int, card: CardView, scroll: HorizontalScrollView, v: View) {
        focusedItem = card.item
        showHero(card.item)
        onItemFocused?.invoke(card.item)
        // Gewählte Karte links ausrichten
        scroll.post { scroll.smoothScrollTo((v.left - context.dp(4)).coerceAtLeast(0), 0) }
        if (rowIndex != focusedRow) {
            focusedRow = rowIndex
            val holder = holders.getOrNull(rowIndex) ?: return
            holder.view.post {
                rowsContainer.animate().translationY(-holder.view.top.toFloat()).setDuration(240).start()
            }
            holders.forEachIndexed { i, h -> h.view.animate().alpha(if (i < rowIndex) 0f else 1f).setDuration(200).start() }
        }
    }

    private fun showHero(item: CardItem) {
        val o = heroOverride
        heroTitle.text = o?.first ?: item.title
        heroInfo.text = o?.second ?: item.info
        heroDesc.text = o?.third ?: item.description
        if (item.heroImageUrls.isNotEmpty()) {
            heroImage.visibility = View.VISIBLE
            ImageLoader.load(heroImage, item.heroImageUrls, 960) { bmp: Bitmap ->
                if (focusedItem === item) animateColor(dominantColor(bmp) ?: item.color)
            }
            animateColor(item.color)
        } else {
            heroImage.tag = null
            heroImage.setImageDrawable(null)
            heroImage.visibility = View.INVISIBLE
            animateColor(item.color)
        }
    }

    private fun animateColor(target: Int) {
        colorAnim?.cancel()
        val from = currentColor
        colorAnim = ValueAnimator.ofObject(ArgbEvaluator(), from, target).apply {
            duration = 450
            addUpdateListener { applyColor(it.animatedValue as Int) }
            start()
        }
    }

    private fun applyColor(c: Int) {
        currentColor = c
        val top = blend(Brand.BG, c, 0.42f)
        val mid = blend(Brand.BG, c, 0.14f)
        bg.colors = intArrayOf(top, mid, Brand.BG)
        heroFadeLeft.colors = intArrayOf(blend(Brand.BG, c, 0.36f), Color.TRANSPARENT)
        heroFadeBottom.colors = intArrayOf(Color.TRANSPARENT, blend(Brand.BG, c, 0.2f))
    }
}

/** 16:9-Karte: wird bei Fokus größer und bekommt einen Rahmen. */
class CardView(context: Context, val item: CardItem) : FrameLayout(context) {
    private val border = View(context)

    init {
        isFocusable = true
        isClickable = true
        val r = context.dpf(10f)
        background = GradientDrawable(GradientDrawable.Orientation.TL_BR, intArrayOf(item.color, darken(item.color, 0.5f))).apply { cornerRadius = r }
        outlineProvider = ViewOutlineProvider.BACKGROUND
        clipToOutline = true

        val icon = item.icon
        val iconIsBanner = icon != null && icon.intrinsicHeight > 0 && icon.intrinsicWidth.toFloat() / icon.intrinsicHeight > 1.4f
        var showBottomTitle = false

        when {
            item.imageUrls.isNotEmpty() -> {
                val img = ImageView(context).apply { scaleType = ImageView.ScaleType.CENTER_CROP }
                addView(img, LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.MATCH_PARENT))
                ImageLoader.load(img, item.imageUrls, 480)
                showBottomTitle = true
            }
            icon != null && iconIsBanner -> {
                addView(ImageView(context).apply { scaleType = ImageView.ScaleType.CENTER_CROP; setImageDrawable(icon) },
                    LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.MATCH_PARENT))
            }
            icon != null -> {
                addView(ImageView(context).apply { setImageDrawable(icon) },
                    LayoutParams(context.dp(60), context.dp(60), Gravity.CENTER).apply { bottomMargin = context.dp(18) })
                showBottomTitle = true
            }
            item.bigLabel != null -> {
                addView(TextView(context).apply {
                    text = item.bigLabel
                    setTextColor(Brand.TEXT)
                    textSize = 40f
                    gravity = Gravity.CENTER
                    typeface = Typeface.DEFAULT_BOLD
                }, LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.MATCH_PARENT).apply { bottomMargin = context.dp(20) })
                showBottomTitle = true
            }
            else -> {
                addView(TextView(context).apply {
                    text = item.title
                    setTextColor(Brand.TEXT)
                    textSize = 22f
                    typeface = Typeface.DEFAULT_BOLD
                    gravity = Gravity.CENTER
                    maxLines = 2
                    ellipsize = TextUtils.TruncateAt.END
                    setPadding(context.dp(12), 0, context.dp(12), if (item.progress >= 0) context.dp(8) else 0)
                    setShadowLayer(10f, 0f, 2f, 0xAA000000.toInt())
                }, LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.MATCH_PARENT))
            }
        }

        if (showBottomTitle) {
            addView(View(context).apply {
                background = GradientDrawable(GradientDrawable.Orientation.TOP_BOTTOM, intArrayOf(Color.TRANSPARENT, 0xDD000000.toInt()))
            }, LayoutParams(LayoutParams.MATCH_PARENT, context.dp(56), Gravity.BOTTOM))
            addView(TextView(context).apply {
                text = item.title
                setTextColor(Brand.TEXT)
                textSize = 14f
                typeface = Typeface.DEFAULT_BOLD
                maxLines = 1
                ellipsize = TextUtils.TruncateAt.END
            }, LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.WRAP_CONTENT, Gravity.BOTTOM).apply {
                leftMargin = context.dp(10); rightMargin = context.dp(10)
                bottomMargin = if (item.progress >= 0) context.dp(12) else context.dp(8)
            })
        }

        item.badge?.let { b ->
            addView(TextView(context).apply {
                text = b
                setTextColor(Brand.TEXT)
                textSize = 11f
                typeface = Typeface.DEFAULT_BOLD
                setPadding(context.dp(8), context.dp(3), context.dp(8), context.dp(3))
                background = GradientDrawable().apply { cornerRadius = context.dpf(20f); setColor(0xCC000000.toInt()) }
            }, LayoutParams(LayoutParams.WRAP_CONTENT, LayoutParams.WRAP_CONTENT, Gravity.TOP or Gravity.END).apply {
                topMargin = context.dp(8); rightMargin = context.dp(8)
            })
        }

        if (item.progress >= 0f) {
            val track = FrameLayout(context).apply { setBackgroundColor(0x66FFFFFF) }
            val fill = View(context).apply { setBackgroundColor(Brand.ACCENT2) }
            track.addView(fill, LayoutParams(0, LayoutParams.MATCH_PARENT))
            addView(track, LayoutParams(LayoutParams.MATCH_PARENT, context.dp(5), Gravity.BOTTOM))
            track.post {
                fill.layoutParams = LayoutParams((track.width * item.progress.coerceIn(0f, 1f)).toInt(), LayoutParams.MATCH_PARENT)
            }
        }

        border.background = GradientDrawable().apply {
            cornerRadius = r
            setColor(Color.TRANSPARENT)
            setStroke(context.dp(3), Brand.FOCUS)
        }
        border.visibility = View.INVISIBLE
        addView(border, LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.MATCH_PARENT))

        setOnClickListener { item.onClick() }
        item.onMenu?.let { menu -> setOnLongClickListener { menu(); true } }
    }

    fun applyFocus(focused: Boolean) {
        border.visibility = if (focused) View.VISIBLE else View.INVISIBLE
        animate().scaleX(if (focused) 1.12f else 1f).scaleY(if (focused) 1.12f else 1f)
            .translationZ(if (focused) context.dpf(12f) else 0f).setDuration(160).start()
    }
}
