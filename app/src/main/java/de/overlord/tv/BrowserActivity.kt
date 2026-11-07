package de.overlord.tv

import android.annotation.SuppressLint
import android.app.Activity
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.graphics.drawable.StateListDrawable
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.os.Message
import android.os.SystemClock
import android.view.Gravity
import android.view.InputDevice
import android.view.KeyEvent
import android.view.MotionEvent
import android.view.View
import android.view.ViewGroup
import android.webkit.CookieManager
import android.webkit.JavascriptInterface
import android.webkit.WebChromeClient
import android.webkit.WebResourceRequest
import android.webkit.WebResourceResponse
import android.webkit.WebSettings
import android.webkit.WebView
import android.webkit.WebViewClient
import android.widget.FrameLayout
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.ProgressBar
import android.widget.TextView
import androidx.webkit.WebViewCompat
import androidx.webkit.WebViewFeature
import org.json.JSONObject
import java.io.ByteArrayInputStream
import kotlin.math.abs
import kotlin.math.min

/**
 * Eingebauter Browser für die Fernbedienung:
 * Werbe-/Pop-up-Blocker, Link- und Zeiger-Modus, Mediensteuerung über iframes hinweg,
 * Weiterschauen, Player-Leiste, Schnellsuche und Video-Erkennung („Scraper“) für den nativen Player.
 */
class BrowserActivity : Activity() {

    enum class Mode(val label: String, val icon: Int) {
        LINKS("Link-Modus", R.drawable.ic_link),
        POINTER("Zeiger-Modus", R.drawable.ic_mouse),
        NORMAL("Normaler Modus", R.drawable.ic_keyboard),
    }

    private data class MediaHit(val url: String, val referer: String, var duration: Double = 0.0)

    private val ui = Handler(Looper.getMainLooper())
    private lateinit var root: FrameLayout
    private lateinit var web: WebView
    private lateinit var cursor: ImageView
    private lateinit var modePill: LinearLayout
    private lateinit var modeIcon: ImageView
    private lateinit var modeText: TextView
    private lateinit var chipPill: LinearLayout
    private lateinit var chipIcon: ImageView
    private lateinit var chipText: TextView
    private lateinit var loadBar: ProgressBar
    private lateinit var fullscreenHolder: FrameLayout
    private lateinit var playerBar: LinearLayout
    private lateinit var barHost: TextView
    private lateinit var barTitle: TextView
    private lateinit var barTimeLeft: TextView
    private lateinit var barTimeRight: TextView
    private lateinit var barTrack: FrameLayout
    private lateinit var barFill: View
    private lateinit var barSpeedChip: TextView
    private lateinit var btnPlay: View
    private lateinit var btnPlayIcon: ImageView
    private lateinit var btnPlayLabel: TextView
    private lateinit var btnSpeedLabel: TextView
    private lateinit var nextBox: LinearLayout
    private lateinit var nextCount: TextView
    private lateinit var nextNow: View

    private val chrome by lazy { Chrome() }

    // Video-Ansicht: Seite unsichtbar laden, nur Videos als eigene Oberfläche zeigen
    private lateinit var vview: RowsView
    private var videoMode = false
    private var overlayVisible = false
    /** Nutzer hat bewusst „Webseite anzeigen“ gewählt → beim Weiterklicken nicht zurück in die Video-Ansicht. */
    private var websiteChosen = false
    private var cinema = false
    /** Zählt Seitenwechsel – laufende Kino-Versuche einer alten Seite brechen damit ab. */
    private var pageSerial = 0
    private var autoCinema = false
    private var extractToken = 0
    private val lastFocus = HashMap<String, String>()
    private val extractCache = object : LinkedHashMap<String, JSONObject>(16, 0.75f, true) {
        override fun removeEldestEntry(eldest: MutableMap.MutableEntry<String, JSONObject>?) = size > 30
    }
    private var customView: View? = null
    private var customCallback: WebChromeClient.CustomViewCallback? = null

    private var mode = Mode.LINKS
    private var cursorX = 0f
    private var cursorY = 0f
    private var textFocus = false

    private var tileColor = Brand.ACCENT
    private var tileTitle = ""
    private lateinit var script: String
    private var docStartScript = false
    enum class UaMode(val label: String) { MOBILE("Mobil"), DESKTOP("Desktop"), TV("Smart-TV") }

    // Video-Zustand (aus allen Frames gemeldet)
    private var lastVideoReport = 0L
    private var videoPos = 0.0
    private var videoDur = 0.0
    private var videoPlaying = false
    private var videoSrc = ""
    private var lastSave = 0L
    private var pendingResume: Double? = null
    private var resumeAttempts = 0
    private var autoplayTries = 0
    private var maximized = false
    private var nextDone = false
    private var speed = 1.0
    private var videoPoster = ""
    private var pageImage = ""
    private var endHandled = false
    private var countdown = 0
    private var pendingSearch: String? = null
    /** Blockierte Werbe-Anfragen der aktuellen Seite (Zähler aus dem Netzwerk-Thread). */
    private val blockedCount = java.util.concurrent.atomic.AtomicInteger(0)
    private var currentSite = ""

    // Navigation / Blocker
    private var lastActivate = 0L
    private var lastBlockedUrl: String? = null
    private val detected = LinkedHashMap<String, MediaHit>()
    private var mediaChipShown = false

    // Tasten
    private var menuLongFired = false
    private var okLongFired = false

    private val hideChip = Runnable { chipPill.animate().alpha(0f).translationY(-dpf(10f)).setDuration(250).start() }
    private val hideMode = Runnable { modePill.animate().alpha(0f).setDuration(250).start() }
    private val hideBar = Runnable { hidePlayerBar() }

    companion object {
        private const val EXTRA_URL = "url"
        private const val EXTRA_TITLE = "title"
        private const val EXTRA_COLOR = "color"
        private const val EXTRA_RESUME = "resume"
        private const val PREFS = "browser"
        private val SPEEDS = listOf(1.0, 1.25, 1.5, 2.0, 0.75)
        private val MEDIA_RE = Regex("""\.(m3u8|mp4|webm|mkv|mov)(\?|$)""", RegexOption.IGNORE_CASE)
        private const val DESKTOP_UA = "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36"
        private const val TV_UA = "Mozilla/5.0 (SMART-TV; Linux; Tizen 6.0) AppleWebKit/537.36 (KHTML, like Gecko) Version/4.0 Chrome/94.0.4606.31 TV Safari/537.36"

        private const val EXTRA_SEARCH = "search"

        fun open(ctx: Context, url: String, title: String = "", color: Int = Brand.ACCENT, resume: Double = -1.0, search: String? = null) {
            val i = Intent(ctx, BrowserActivity::class.java)
                .putExtra(EXTRA_URL, url).putExtra(EXTRA_TITLE, title)
                .putExtra(EXTRA_COLOR, color).putExtra(EXTRA_RESUME, resume)
            if (search != null) i.putExtra(EXTRA_SEARCH, search)
            if (ctx !is Activity) i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            ctx.startActivity(i)
        }
    }

    // ===================================================================== Aufbau

    @SuppressLint("SetJavaScriptEnabled", "JavascriptInterface")
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        tileColor = intent.getIntExtra(EXTRA_COLOR, Brand.ACCENT)
        tileTitle = intent.getStringExtra(EXTRA_TITLE) ?: ""
        val resume = intent.getDoubleExtra(EXTRA_RESUME, -1.0)
        if (resume >= 0) pendingResume = resume
        pendingSearch = intent.getStringExtra(EXTRA_SEARCH)
        // Direkt-Schalter (z. B. aus anderen Apps/adb): Video-Ansicht für diese Domain einschalten
        if (intent.getBooleanExtra("video", false)) Prefs.setVideoView(intent.getStringExtra(EXTRA_URL) ?: intent.dataString, true)
        script = assets.open("overlord.js").bufferedReader().use { it.readText() }

        root = FrameLayout(this).apply { setBackgroundColor(Brand.BG) }
        web = WebView(this)
        root.addView(web, FrameLayout.LayoutParams(-1, -1))

        fullscreenHolder = FrameLayout(this).apply { setBackgroundColor(0xFF000000.toInt()); visibility = View.GONE }
        root.addView(fullscreenHolder, FrameLayout.LayoutParams(-1, -1))

        vview = RowsView(this).apply { visibility = View.GONE }
        vview.addTopAction(R.drawable.ic_search, "Suchen") { quickSearch() }
        vview.addTopAction(R.drawable.ic_globe, "Webseite") { showWebsite() }
        root.addView(vview, FrameLayout.LayoutParams(-1, -1))

        loadBar = ProgressBar(this, null, android.R.attr.progressBarStyleHorizontal).apply {
            max = 100
            progressTintList = android.content.res.ColorStateList.valueOf(Brand.ACCENT2)
            progressBackgroundTintList = android.content.res.ColorStateList.valueOf(0x22FFFFFF)
        }
        root.addView(loadBar, FrameLayout.LayoutParams(-1, dp(4), Gravity.TOP))

        cursor = ImageView(this).apply { setImageResource(R.drawable.cursor); visibility = View.GONE; elevation = dpf(20f) }
        root.addView(cursor, FrameLayout.LayoutParams(dp(32), dp(32)))

        pill().let { (p, i, t) -> modePill = p; modeIcon = i; modeText = t }
        modePill.alpha = 0f
        root.addView(modePill, FrameLayout.LayoutParams(-2, -2, Gravity.TOP or Gravity.END).apply { topMargin = dp(22); rightMargin = dp(28) })

        pill().let { (p, i, t) -> chipPill = p; chipIcon = i; chipText = t }
        chipPill.alpha = 0f
        chipText.maxWidth = (resources.displayMetrics.widthPixels * 0.62f).toInt()
        root.addView(chipPill, FrameLayout.LayoutParams(-2, -2, Gravity.TOP or Gravity.CENTER_HORIZONTAL).apply { topMargin = dp(22) })

        buildPlayerBar()
        buildNextBox()
        setContentView(root)
        setupWeb()

        // Auch über einen normalen Link (VIEW-Intent) aus anderen Apps aufrufbar
        val url = intent.getStringExtra(EXTRA_URL) ?: intent.dataString ?: "https://duckduckgo.com"
        if (tileTitle.isBlank()) tileTitle = hostOf(url)
        applyUserAgent(url)
        web.loadUrl(url)
        web.requestFocus()
        showMode()
        showKeyHelpOnce()
    }

    /** Kurze Tastenhilfe bei den ersten drei Browser-Starts. */
    private fun showKeyHelpOnce() {
        val prefs = getSharedPreferences(PREFS, MODE_PRIVATE)
        val shown = prefs.getInt("help_shown", 0)
        if (shown >= 3) return
        prefs.edit().putInt("help_shown", shown + 1).apply()
        val panel = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(24), dp(20), dp(26), dp(20))
            background = rounded(0xF0161622.toInt(), dpf(20f), dp(1), withAlpha(Brand.ACCENT, 0x99))
            elevation = dpf(28f)
            alpha = 0f
        }
        panel.addView(label("SO STEUERST DU WEBSEITEN", 12f, Fonts.bold, Brand.ACCENT2).apply { letterSpacing = 0.2f })
        listOf("◀ ▲ ▼ ▶" to "zum nächsten Link springen", "OK" to "anklicken", "☰" to "Modus: Links → Zeiger → Normal",
            "☰ lang" to "Menü: Suche, Video nativ, Schutz …", "⏯ ⏪ ⏩" to "Video steuern – auch im eingebetteten Player",
            "Zurück" to "vorherige Seite / Startseite").forEach { (k, t) ->
            panel.addView(Tv.keyHint(this, k, t), LinearLayout.LayoutParams(-2, -2).apply { topMargin = dp(10) })
        }
        root.addView(panel, FrameLayout.LayoutParams(-2, -2, Gravity.BOTTOM or Gravity.START).apply { leftMargin = dp(40); bottomMargin = dp(40) })
        panel.animate().alpha(1f).setStartDelay(600).setDuration(250).start()
        ui.postDelayed({ panel.animate().alpha(0f).setDuration(400).withEndAction { root.removeView(panel) }.start() }, 9000)
    }

    /** Glas-Pille mit Symbol und Text (Modus-Anzeige, Hinweise). */
    private fun pill(): Triple<LinearLayout, ImageView, TextView> {
        val icon = icon(R.drawable.ic_info, Brand.ACCENT2)
        val text = label("", 16f, Fonts.semibold, lines = 2)
        val p = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            setPadding(dp(18), dp(11), dp(22), dp(11))
            background = rounded(0xEE16161F.toInt(), dpf(30f), dp(1), withAlpha(Brand.ACCENT, 0x99))
            elevation = dpf(24f)
            addView(icon, LinearLayout.LayoutParams(dp(22), dp(22)).apply { rightMargin = dp(12) })
            addView(text)
        }
        return Triple(p, icon, text)
    }

    /** Runder Symbol-Knopf mit Beschriftung darunter. */
    private fun roundButton(row: LinearLayout, iconRes: Int, text: String, big: Boolean = false, action: () -> Unit): Triple<View, ImageView, TextView> {
        val size = dp(if (big) 76 else 62)
        val col = LinearLayout(this).apply { orientation = LinearLayout.VERTICAL; gravity = Gravity.CENTER_HORIZONTAL; clipChildren = false }
        val circle = FrameLayout(this).apply {
            isFocusable = true
            isClickable = true
            background = StateListDrawable().apply {
                addState(intArrayOf(android.R.attr.state_focused), GradientDrawable().apply { shape = GradientDrawable.OVAL; setColor(Brand.FOCUS) })
                addState(intArrayOf(), GradientDrawable().apply { shape = GradientDrawable.OVAL; setColor(if (big) Brand.ACCENT else 0x33FFFFFF) })
            }
        }
        val ic = icon(iconRes).apply {
            imageTintList = android.content.res.ColorStateList(
                arrayOf(intArrayOf(android.R.attr.state_focused), intArrayOf()), intArrayOf(Brand.BG, Brand.TEXT))
            isDuplicateParentStateEnabled = true
        }
        circle.addView(ic, FrameLayout.LayoutParams(dp(if (big) 36 else 28), dp(if (big) 36 else 28), Gravity.CENTER))
        val lbl = label(text, 13f, Fonts.semibold, Brand.TEXT_DIM).apply { gravity = Gravity.CENTER }
        col.addView(circle, LinearLayout.LayoutParams(size, size))
        col.addView(lbl, LinearLayout.LayoutParams(-2, -2).apply { topMargin = dp(9) })
        circle.setOnClickListener { action(); scheduleBarHide() }
        circle.setOnFocusChangeListener { v, f ->
            v.animate().scaleX(if (f) 1.12f else 1f).scaleY(if (f) 1.12f else 1f).setDuration(120).start()
            lbl.setTextColor(if (f) Brand.TEXT else Brand.TEXT_DIM)
        }
        row.addView(col, LinearLayout.LayoutParams(dp(100), -2))
        return Triple(circle, ic, lbl)
    }

    private fun buildPlayerBar() {
        playerBar = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(56), dp(70), dp(56), dp(28))
            background = GradientDrawable(GradientDrawable.Orientation.BOTTOM_TOP, intArrayOf(0xF2000000.toInt(), 0xB0000000.toInt(), 0x00000000))
            visibility = View.GONE
            elevation = dpf(30f)
            clipChildren = false
        }
        barHost = label("", 13f, Fonts.bold, Brand.ACCENT2).apply { letterSpacing = 0.18f }
        barTitle = label("", 28f, Fonts.bold)
        barSpeedChip = label("", 14f, Fonts.bold, Brand.BG).apply {
            setPadding(dp(10), dp(4), dp(10), dp(4))
            background = rounded(Brand.ACCENT2, dpf(6f))
            visibility = View.GONE
        }
        val head = LinearLayout(this).apply { orientation = LinearLayout.HORIZONTAL; gravity = Gravity.BOTTOM }
        val titles = LinearLayout(this).apply { orientation = LinearLayout.VERTICAL }
        titles.addView(barHost)
        titles.addView(barTitle, LinearLayout.LayoutParams(-1, -2).apply { topMargin = dp(6) })
        head.addView(titles, LinearLayout.LayoutParams(0, -2, 1f))
        head.addView(barSpeedChip)
        playerBar.addView(head)

        val prog = LinearLayout(this).apply { orientation = LinearLayout.HORIZONTAL; gravity = Gravity.CENTER_VERTICAL }
        barTimeLeft = label("0:00", 15f, Fonts.semibold)
        barTimeRight = label("", 15f, Fonts.semibold, Brand.TEXT_DIM)
        barTrack = FrameLayout(this).apply { background = rounded(0x40FFFFFF, dpf(4f)) }
        barFill = View(this).apply { background = rounded(Brand.ACCENT2, dpf(4f)) }
        barTrack.addView(barFill, FrameLayout.LayoutParams(0, -1))
        prog.addView(barTimeLeft, LinearLayout.LayoutParams(dp(84), -2))
        prog.addView(barTrack, LinearLayout.LayoutParams(0, dp(7), 1f))
        prog.addView(barTimeRight, LinearLayout.LayoutParams(dp(84), -2).apply { leftMargin = dp(4) })
        barTimeRight.gravity = Gravity.END
        playerBar.addView(prog, LinearLayout.LayoutParams(-1, -2).apply { topMargin = dp(16); bottomMargin = dp(22) })

        val buttons = LinearLayout(this).apply { orientation = LinearLayout.HORIZONTAL; gravity = Gravity.CENTER; clipChildren = false }
        roundButton(buttons, R.drawable.ic_rewind, "−10 s") { seek(-10.0) }
        roundButton(buttons, R.drawable.ic_play, "Pause", big = true) { cmd("toggle") }.let { (v, i, l) -> btnPlay = v; btnPlayIcon = i; btnPlayLabel = l }
        roundButton(buttons, R.drawable.ic_forward, "+10 s") { seek(10.0) }
        roundButton(buttons, R.drawable.ic_next, "Nächste") { nextEpisode() }
        roundButton(buttons, R.drawable.ic_skip_intro, "Intro +85 s") { seek(85.0); showChip("Intro übersprungen (+85 s)", R.drawable.ic_skip_intro) }
        roundButton(buttons, R.drawable.ic_speed, "Tempo 1,0×") { cycleSpeed() }.let { (_, _, l) -> btnSpeedLabel = l }
        roundButton(buttons, R.drawable.ic_fullscreen, "Vollbild") { toggleMaximize() }
        roundButton(buttons, R.drawable.ic_tv, "Nativ") { playNative() }
        playerBar.addView(buttons)
        root.addView(playerBar, FrameLayout.LayoutParams(-1, -2, Gravity.BOTTOM))
    }

    /** Hinweis-Karte „Nächste Folge in … s“ am Ende eines Videos. */
    private fun buildNextBox() {
        nextBox = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(26), dp(22), dp(26), dp(22))
            background = rounded(0xF2161622.toInt(), dpf(20f), dp(1), withAlpha(Brand.ACCENT, 0xAA))
            elevation = dpf(32f)
            visibility = View.GONE
        }
        nextBox.addView(label("NÄCHSTE FOLGE", 12f, Fonts.bold, Brand.ACCENT2).apply { letterSpacing = 0.2f })
        nextCount = label("", 24f, Fonts.bold)
        nextBox.addView(nextCount, LinearLayout.LayoutParams(-2, -2).apply { topMargin = dp(6) })
        val row = LinearLayout(this).apply { orientation = LinearLayout.HORIZONTAL }
        fun b(text: String, primary: Boolean, action: () -> Unit) = label(text, 16f, Fonts.semibold).apply {
            setPadding(dp(20), dp(12), dp(20), dp(12))
            isFocusable = true
            isClickable = true
            background = StateListDrawable().apply {
                addState(intArrayOf(android.R.attr.state_focused), rounded(Brand.FOCUS, dpf(24f)))
                addState(intArrayOf(), if (primary) rounded(Brand.ACCENT, dpf(24f)) else rounded(0x26FFFFFF, dpf(24f)))
            }
            setTextColor(android.content.res.ColorStateList(arrayOf(intArrayOf(android.R.attr.state_focused), intArrayOf()), intArrayOf(Brand.BG, Brand.TEXT)))
            setOnClickListener { action() }
        }
        nextNow = b("Jetzt abspielen", true) { cancelCountdown(); nextEpisode() }
        row.addView(nextNow)
        row.addView(b("Abbrechen", false) { cancelCountdown() }, LinearLayout.LayoutParams(-2, -2).apply { leftMargin = dp(12) })
        nextBox.addView(row, LinearLayout.LayoutParams(-2, -2).apply { topMargin = dp(16) })
        root.addView(nextBox, FrameLayout.LayoutParams(-2, -2, Gravity.END or Gravity.BOTTOM).apply { rightMargin = dp(56); bottomMargin = dp(60) })
    }

    @SuppressLint("SetJavaScriptEnabled", "JavascriptInterface", "AddJavascriptInterface")
    private fun setupWeb() {
        val s = web.settings
        s.javaScriptEnabled = true
        s.domStorageEnabled = true
        @Suppress("DEPRECATION")
        s.databaseEnabled = true
        s.mediaPlaybackRequiresUserGesture = false
        s.setSupportMultipleWindows(true)
        s.javaScriptCanOpenWindowsAutomatically = false
        s.loadWithOverviewMode = true
        s.useWideViewPort = true
        s.builtInZoomControls = false
        s.displayZoomControls = false
        s.mixedContentMode = WebSettings.MIXED_CONTENT_COMPATIBILITY_MODE
        applyUserAgent()

        CookieManager.getInstance().setAcceptCookie(true)
        CookieManager.getInstance().setAcceptThirdPartyCookies(web, true)

        web.isFocusable = true
        web.isFocusableInTouchMode = true
        web.setBackgroundColor(Brand.BG)
        web.addJavascriptInterface(Bridge(), "OverlordBridge")

        // Skript schon beim Dokumentstart in ALLE Frames (auch iframes) einschleusen
        if (WebViewFeature.isFeatureSupported(WebViewFeature.DOCUMENT_START_SCRIPT)) {
            try {
                WebViewCompat.addDocumentStartJavaScript(web, script, setOf("*"))
                docStartScript = true
            } catch (e: Exception) {
                docStartScript = false
            }
        }

        web.webViewClient = Client()
        web.webChromeClient = chrome
    }

    /** Gewünschte Ansicht (User-Agent) für die Domain – Standard: Mobil. */
    private fun uaModeFor(url: String?): UaMode = try {
        UaMode.valueOf(getSharedPreferences("ua", MODE_PRIVATE).getString(baseDomain(hostOf(url)), UaMode.MOBILE.name) ?: UaMode.MOBILE.name)
    } catch (e: Exception) {
        UaMode.MOBILE
    }

    private fun userAgentFor(mode: UaMode): String = when (mode) {
        UaMode.DESKTOP -> DESKTOP_UA
        UaMode.TV -> TV_UA
        // WebView-Kennung entfernen – manche Seiten sperren sonst „eingebettete Browser“.
        UaMode.MOBILE -> WebSettings.getDefaultUserAgent(this).replace("; wv", "").replace(Regex("""Version/\d+\.\d+\s"""), "")
    }

    /** Setzt den User-Agent passend zur Domain; liefert true, wenn er sich geändert hat. */
    private fun applyUserAgent(url: String? = web.url): Boolean {
        val ua = userAgentFor(uaModeFor(url))
        if (web.settings.userAgentString == ua) return false
        web.settings.userAgentString = ua
        return true
    }

    private fun injectFallback() {
        if (!docStartScript) web.evaluateJavascript(script, null)
    }

    // ===================================================================== JS-Brücke

    inner class Bridge {
        @JavascriptInterface
        fun video(json: String) { ui.post { onVideoState(json) } }

        @JavascriptInterface
        fun popup(url: String) { ui.post { onBlocked(url, "Pop-up blockiert") } }

        @JavascriptInterface
        fun textFocus(focused: Boolean) { ui.post { textFocus = focused } }

        /** Synchron aus dem Skript: Schutz für die Hauptseite [topHost] aktiv? */
        @JavascriptInterface
        fun protect(topHost: String): Boolean = !AdBlock.isAllowed(applicationContext, topHost.ifBlank { hostOf(topUrl) })

        @JavascriptInterface
        fun nextDone() { ui.post { this@BrowserActivity.nextDone = true } }

        /** Synchron: Akzentfarbe für die Link-Markierung. */
        @JavascriptInterface
        fun accent(): String = String.format("#%06X", Brand.ACCENT and 0xFFFFFF)

        /** Synchron: Intro/Werbung automatisch überspringen? */
        @JavascriptInterface
        fun autoSkip(): Boolean = Prefs.autoSkip

        @JavascriptInterface
        fun skipped(text: String) { ui.post { showChip("Automatisch übersprungen: ${text.take(30)}", R.drawable.ic_skip_intro) } }

        /** Synchron: Wie sollen Cookie-Hinweise beantwortet werden? */
        @JavascriptInterface
        fun consentMode(): String = Prefs.consent

        @JavascriptInterface
        fun consentHandled(label: String) { ui.post { onConsentHandled(label) } }
    }

    /** Cookie-Hinweis wurde automatisch beantwortet: Hinweis zeigen, Video-Ansicht neu auslesen (Inhalte erscheinen oft erst danach). */
    private fun onConsentHandled(label: String) {
        android.util.Log.i("OverlordVV", "COOKIE url=${web.url} | knopf=$label")
        if (!overlayVisible && !cinema) showChip("Cookie-Hinweis: „${label.take(24)}“", R.drawable.ic_shield)
        if (videoMode && !cinema && (!websiteChosen || autoCinema)) scheduleExtract(web.url ?: "", prefetch = !autoCinema)
    }

    private fun js(code: String, cb: ((String?) -> Unit)? = null) {
        web.evaluateJavascript("(function(){try{return ($code);}catch(e){return null;}})()") { v -> cb?.invoke(v) }
    }

    /** Befehl an das Video im Hauptframe UND in allen iframes. */
    private fun cmd(name: String, arg: Any? = null) {
        val a = when (arg) {
            null -> "null"
            is Number -> arg.toString()
            else -> JSONObject.quote(arg.toString())
        }
        js("window.__ovl ? __ovl.cmd(${JSONObject.quote(name)}, $a) : false") { r ->
            if (r == "null" || r == "false") {
                // Skript fehlt (z. B. alte WebView) – nachladen und erneut versuchen
                web.evaluateJavascript(script) { js("window.__ovl && __ovl.cmd(${JSONObject.quote(name)}, $a)") }
            }
        }
    }

    private fun videoActive() = SystemClock.uptimeMillis() - lastVideoReport < 6000

    private fun onVideoState(json: String) {
        val o = try { JSONObject(json) } catch (e: Exception) { return }
        val t = o.optDouble("t", 0.0)
        val d = o.optDouble("d", -1.0)
        val paused = o.optBoolean("p", true)
        val src = o.optString("src")
        val ended = o.optBoolean("e", false)
        o.optString("poster").takeIf { it.isNotBlank() }?.let { videoPoster = it }
        val live = d == -2.0
        if (d < 60 && !live) return   // kurze Clips (Werbung) ignorieren
        lastVideoReport = SystemClock.uptimeMillis()

        val wasPlaying = videoPlaying
        videoPos = t
        videoDur = if (live) 0.0 else d
        videoPlaying = !paused
        if (src.isNotBlank()) {
            videoSrc = src
            val hit = detected.getOrPut(src) { MediaHit(src, web.url ?: "") }
            hit.duration = videoDur
        }
        updateBar()

        if (!wasPlaying && videoPlaying) {
            if (overlayVisible) cmd("pause")   // z. B. Trailer hinter der Video-Ansicht
            else showPlayerBar(focus = true)
        }
        if (ended && !endHandled && d >= ContinueStore.MIN_DURATION) {
            endHandled = true
            web.url?.let { ContinueStore.report(this, it, pageTitle(), d, d, tileColor) }
            if (Prefs.autoNext) startCountdown()
        }

        if (d >= ContinueStore.MIN_DURATION) {
            pendingResume?.let { target ->
                if (abs(t - target) > 5) {
                    resumeAttempts++
                    cmd("seekTo", target)
                    showChip(if (target < 1) "Starte von vorne" else "Setze fort bei ${formatTime(target)}", R.drawable.ic_play)
                    if (resumeAttempts >= 4) pendingResume = null
                } else pendingResume = null
            }
            val now = SystemClock.uptimeMillis()
            if (pendingResume == null && (now - lastSave > 5000 || (wasPlaying && paused))) {
                lastSave = now
                val pageUrl = web.url ?: return
                ContinueStore.report(this, pageUrl, pageTitle(), t, d, tileColor, image = videoPoster.ifBlank { pageImage })
            }
        }
    }

    private fun pageTitle(): String {
        val t = web.title ?: ""
        return if (t.isBlank() || t.startsWith("http")) tileTitle.ifBlank { hostOf(web.url) } else t
    }

    // ===================================================================== Clients

    private inner class Client : WebViewClient() {
        override fun onPageStarted(view: WebView, url: String, favicon: Bitmap?) {
            topUrl = url
            // Andere Ansicht für diese Domain gewünscht → mit passendem User-Agent neu laden
            if (url.startsWith("http") && applyUserAgent(url)) {
                view.stopLoading()
                view.loadUrl(url)
                return
            }
            val zoom = zoomFor(url)
            if (web.settings.textZoom != zoom) web.settings.textZoom = zoom
            val site = baseDomain(hostOf(url))
            if (site != currentSite) {
                currentSite = site
                blockedCount.set(0)
                val saved = savedModeFor(url)
                if (saved != mode) setMode(saved, remember = false)
            }
            loadBar.visibility = View.VISIBLE
            textFocus = false
            maximized = false
            nextDone = false
            if (!sameSite(url, videoPageUrl)) {
                detected.clear()
                mediaChipShown = false
            }
            videoPageUrl = url
            lastVideoReport = 0
            videoPlaying = false
            videoPoster = ""
            pageImage = ""
            endHandled = false
            cancelCountdown()
            hidePlayerBar()
            onVideoModePageStarted(url)
        }

        override fun onPageFinished(view: WebView, url: String) {
            loadBar.visibility = View.GONE
            if (url.startsWith("http")) History.add(url, view.title ?: "")
            injectFallback()
            if (mode != Mode.LINKS) js("window.__ovl && __ovl.showHl(false)")
            if (pendingResume != null) startAutoplay()
            if (speed != 1.0) cmd("rate", speed)
            pendingSearch?.let { term -> pendingSearch = null; ui.postDelayed({ runSearch(term) }, 600) }
            js("window.__ovl ? __ovl.pageMeta() : null") { r -> parseObj(r)?.optString("og")?.takeIf { it.isNotBlank() }?.let { pageImage = it } }
            onVideoModePageFinished(url)
        }

        override fun shouldInterceptRequest(view: WebView, request: WebResourceRequest): WebResourceResponse? {
            val url = request.url
            val host = url.host
            if (request.isForMainFrame) topUrl = url.toString()
            if (!request.isForMainFrame && protectionOn() && AdBlock.isBlocked(host)) {
                blockedCount.incrementAndGet()
                AdBlock.recordBlocked()
                return WebResourceResponse("text/plain", "utf-8", ByteArrayInputStream(ByteArray(0)))
            }
            val s = url.toString()
            if (MEDIA_RE.containsMatchIn(url.path ?: "") && !s.contains(".ts?")) {
                val referer = request.requestHeaders["Referer"] ?: ""
                ui.post { onMediaDetected(s, referer) }
            }
            return null
        }

        override fun onReceivedError(view: WebView, request: WebResourceRequest, error: android.webkit.WebResourceError) {
            if (Build.VERSION.SDK_INT >= 23 && request.isForMainFrame) showErrorPage(request.url.toString(), error.description?.toString() ?: "")
        }

        @Deprecated("API < 23")
        override fun onReceivedError(view: WebView, errorCode: Int, description: String?, failingUrl: String?) {
            if (Build.VERSION.SDK_INT < 23 && failingUrl != null) showErrorPage(failingUrl, description ?: "")
        }

        override fun shouldOverrideUrlLoading(view: WebView, request: WebResourceRequest): Boolean {
            if (!request.isForMainFrame) return false
            val gesture = if (Build.VERSION.SDK_INT >= 24) request.hasGesture() else false
            val redirect = if (Build.VERSION.SDK_INT >= 24) request.isRedirect else false
            return decideNavigation(request.url.toString(), gesture || recentActivate(), redirect)
        }

        @Deprecated("API < 24")
        override fun shouldOverrideUrlLoading(view: WebView, url: String): Boolean =
            decideNavigation(url, recentActivate(), false)
    }

    private var videoPageUrl: String? = null

    /** Aktuelle Hauptseite (auch aus Hintergrund-Threads lesbar). */
    @Volatile
    private var topUrl: String? = null

    private fun protectionOn() = !AdBlock.isAllowed(applicationContext, hostOf(topUrl))

    private fun recentActivate() = SystemClock.uptimeMillis() - lastActivate < 2000

    /** Gespeicherte Textgröße für die Domain (Standard 100 %). */
    private fun zoomFor(url: String): Int = getSharedPreferences("zoom", MODE_PRIVATE).getInt(baseDomain(hostOf(url)), 100)

    /** true = Navigation verhindern. */
    private fun decideNavigation(url: String, gesture: Boolean, redirect: Boolean): Boolean {
        val uri = Uri.parse(url)
        when (uri.scheme?.lowercase()) {
            "http", "https" -> {
                if (!protectionOn()) { topUrl = url; return false }
                if (AdBlock.isBlocked(uri.host)) { onBlocked(url, "Werbeseite blockiert"); return true }
                if (redirect || gesture) { topUrl = url; return false }
                val cur = web.url
                if (cur == null || cur == "about:blank" || sameSite(url, cur)) { topUrl = url; return false }
                // Automatische Umleitung ohne Klick auf eine fremde Domain
                onBlocked(url, "Umleitung blockiert")
                return true
            }
            "intent" -> {
                if (!gesture) return true
                try {
                    val i = Intent.parseUri(url, Intent.URI_INTENT_SCHEME)
                    if (i.resolveActivity(packageManager) != null) { startActivity(i); return true }
                    val fb = i.getStringExtra("browser_fallback_url")
                    if (fb != null && !AdBlock.isBlocked(Uri.parse(fb).host)) web.loadUrl(fb)
                } catch (e: Exception) { }
                return true
            }
            "market", "amzn" -> {
                if (gesture) try { startActivity(Intent(Intent.ACTION_VIEW, uri)) } catch (e: Exception) { }
                return true
            }
            "about", "javascript", "data", "blob" -> return false
            else -> return true
        }
    }

    /** Fehlerseite im Overlord-Stil (statt der grauen Standardseite). */
    private fun showErrorPage(url: String, description: String) {
        val acc = String.format("#%06X", Brand.ACCENT and 0xFFFFFF)
        val esc = { t: String -> t.replace("&", "&amp;").replace("<", "&lt;").replace("\"", "&quot;") }
        val offline = description.contains("INTERNET_DISCONNECTED", true) || description.contains("NAME_NOT_RESOLVED", true)
        val html = """<!doctype html><html lang="de"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width">
<style>body{margin:0;height:100vh;display:flex;align-items:center;justify-content:center;background:#0B0B12;color:#F2F2F7;font-family:sans-serif}
.c{max-width:640px;padding:40px;text-align:left}.e{color:#22D3EE;font-weight:800;letter-spacing:.2em;font-size:13px}
h1{font-size:34px;margin:10px 0 12px}p{color:#B4B4C8;font-size:18px;line-height:1.45}code{color:#7A7A92;font-size:14px}
a{display:inline-block;margin:22px 14px 0 0;padding:14px 26px;border-radius:30px;background:$acc;color:#fff;text-decoration:none;font-weight:700;font-size:18px}
a.s{background:rgba(255,255,255,.12)}</style></head><body><div class="c"><div class="e">SEITE NICHT ERREICHBAR</div>
<h1>${if (offline) "Keine Verbindung" else "Das hat nicht geklappt"}</h1>
<p>${if (offline) "Der Fernseher scheint gerade nicht mit dem Internet verbunden zu sein." else "Die Seite <b>${esc(hostOf(url))}</b> konnte nicht geladen werden."}</p>
<code>${esc(description)}</code><br><a href="${esc(url)}">Erneut versuchen</a><a class="s" href="https://duckduckgo.com/?q=${Uri.encode(hostOf(url))}">Im Web suchen</a></div></body></html>"""
        web.loadDataWithBaseURL(url, html, "text/html", "utf-8", url)
    }

    private fun onBlocked(url: String, what: String) {
        if (url.isBlank() || url == "about:blank") { showChip(what, R.drawable.ic_shield); return }
        lastBlockedUrl = url
        showChip("$what: ${hostOf(url)}  ·  ☰ lang → trotzdem öffnen", R.drawable.ic_shield)
    }

    private fun onMediaDetected(url: String, referer: String) {
        if (AdBlock.isBlocked(Uri.parse(url).host)) return
        if (detected.size > 30) return
        if (!detected.containsKey(url)) detected[url] = MediaHit(url, referer.ifBlank { web.url ?: "" })
        if (!mediaChipShown) {
            mediaChipShown = true
            showChip("Video erkannt  ·  ☰ lang → „Video nativ abspielen“", R.drawable.ic_movie)
        }
    }

    private inner class Chrome : WebChromeClient() {
        override fun onProgressChanged(view: WebView, newProgress: Int) {
            loadBar.progress = newProgress
            if (newProgress >= 30) injectFallback()
        }

        override fun onShowCustomView(view: View, callback: CustomViewCallback) {
            customView?.let { onHideCustomView() }
            customView = view
            customCallback = callback
            fullscreenHolder.addView(view, FrameLayout.LayoutParams(-1, -1))
            fullscreenHolder.visibility = View.VISIBLE
            cursor.visibility = View.GONE
            showPlayerBar(focus = false)
        }

        override fun onHideCustomView() {
            val v = customView ?: return
            fullscreenHolder.removeView(v)
            fullscreenHolder.visibility = View.GONE
            customView = null
            try { customCallback?.onCustomViewHidden() } catch (e: Exception) { }
            customCallback = null
            if (mode == Mode.POINTER) cursor.visibility = View.VISIBLE
            web.requestFocus()
        }

        /** DRM-geschützte Videos (Widevine) brauchen diese Freigabe, sonst bleiben sie schwarz. */
        override fun onPermissionRequest(request: android.webkit.PermissionRequest) {
            val wanted = request.resources.filter { it == android.webkit.PermissionRequest.RESOURCE_PROTECTED_MEDIA_ID }
            if (wanted.isNotEmpty()) request.grant(wanted.toTypedArray()) else request.deny()
        }

        override fun getDefaultVideoPoster(): Bitmap? = Bitmap.createBitmap(2, 2, Bitmap.Config.ARGB_8888)

        override fun onCreateWindow(view: WebView, isDialog: Boolean, isUserGesture: Boolean, resultMsg: Message): Boolean {
            // Neues Fenster abfangen: Ziel ermitteln, dann entscheiden (fremde Domains = blockieren)
            val temp = WebView(this@BrowserActivity)
            var handled = false
            fun handle(url: String) {
                if (handled || url.isBlank() || url == "about:blank") return
                handled = true
                if (!protectionOn() && isUserGesture) web.loadUrl(url)
                else if (isUserGesture && sameSite(url, web.url) && !AdBlock.isBlocked(Uri.parse(url).host)) web.loadUrl(url)
                else onBlocked(url, "Neues Fenster blockiert")
                ui.postDelayed({ try { temp.destroy() } catch (e: Exception) { } }, 500)
            }
            temp.webViewClient = object : WebViewClient() {
                @Deprecated("API < 24")
                override fun shouldOverrideUrlLoading(v: WebView, url: String): Boolean { handle(url); return true }
                override fun shouldOverrideUrlLoading(v: WebView, r: WebResourceRequest): Boolean { handle(r.url.toString()); return true }
                override fun onPageStarted(v: WebView, url: String, favicon: Bitmap?) { handle(url); v.stopLoading() }
            }
            (resultMsg.obj as WebView.WebViewTransport).webView = temp
            resultMsg.sendToTarget()
            ui.postDelayed({ if (!handled) { handled = true; showChip("Pop-up blockiert", R.drawable.ic_shield); try { temp.destroy() } catch (e: Exception) { } } }, 3000)
            return true
        }
    }

    // ===================================================================== Tasten

    private fun isFullscreenVideo() = customView != null || maximized

    override fun dispatchKeyEvent(e: KeyEvent): Boolean {
        val code = e.keyCode
        val down = e.action == KeyEvent.ACTION_DOWN

        when (code) {
            KeyEvent.KEYCODE_MEDIA_PLAY_PAUSE, KeyEvent.KEYCODE_MEDIA_PLAY, KeyEvent.KEYCODE_MEDIA_PAUSE -> {
                if (overlayVisible) {
                    // ⏯ in der Video-Ansicht = gewählte Karte abspielen
                    if (down && e.repeatCount == 0) (currentFocus as? CardView)?.performClick()
                    return true
                }
                if (down && e.repeatCount == 0) {
                    cmd(when (code) { KeyEvent.KEYCODE_MEDIA_PLAY -> "play"; KeyEvent.KEYCODE_MEDIA_PAUSE -> "pause"; else -> "toggle" })
                    showPlayerBar(focus = true)
                }
                return true
            }
            KeyEvent.KEYCODE_MEDIA_REWIND, KeyEvent.KEYCODE_MEDIA_FAST_FORWARD -> {
                if (overlayVisible) return true
                if (down) {
                    val fwd = code == KeyEvent.KEYCODE_MEDIA_FAST_FORWARD
                    if (videoActive()) {
                        val step = if (e.repeatCount > 4) 30.0 else 10.0
                        seek(if (fwd) step else -step)
                        showPlayerBar(focus = false)
                    } else {
                        js("window.__ovl && __ovl.scrollPage(${if (fwd) 1 else -1})")
                    }
                }
                return true
            }
            KeyEvent.KEYCODE_MEDIA_NEXT -> { if (down && e.repeatCount == 0) nextEpisode(); return true }
            KeyEvent.KEYCODE_MENU -> { handleMenuKey(e); return true }
            KeyEvent.KEYCODE_BACK, KeyEvent.KEYCODE_ESCAPE -> {
                if (!down) handleBack()
                return true
            }
        }

        // Countdown-Karte „Nächste Folge“
        if (nextBox.visibility == View.VISIBLE && nextBox.hasFocus()) return super.dispatchKeyEvent(e)

        // Video-Ansicht: Steuerkreuz bedient die Karten
        if (overlayVisible && !playerBar.hasFocus()) {
            if (down && !vview.hasFocus()) vview.refocus()
            return super.dispatchKeyEvent(e)
        }

        // Player-Leiste hat den Fokus
        if (playerBar.visibility == View.VISIBLE && playerBar.hasFocus()) {
            if (down && code == KeyEvent.KEYCODE_DPAD_UP) { hidePlayerBar(); return true }
            if (down && code == KeyEvent.KEYCODE_DPAD_DOWN) return true
            scheduleBarHide()
            return super.dispatchKeyEvent(e)
        }

        // Video im Vollbild: Steuerkreuz steuert das Video
        if (isFullscreenVideo() && isDpad(code)) {
            if (down) when (code) {
                KeyEvent.KEYCODE_DPAD_LEFT -> { seek(if (e.repeatCount > 4) -30.0 else -10.0); showPlayerBar(false) }
                KeyEvent.KEYCODE_DPAD_RIGHT -> { seek(if (e.repeatCount > 4) 30.0 else 10.0); showPlayerBar(false) }
                KeyEvent.KEYCODE_DPAD_CENTER, KeyEvent.KEYCODE_ENTER -> if (e.repeatCount == 0) { cmd("toggle"); showPlayerBar(false) }
                else -> showPlayerBar(focus = true)
            }
            return true
        }

        if (isDpad(code)) {
            return when (mode) {
                Mode.LINKS -> handleLinkKey(e)
                Mode.POINTER -> handlePointerKey(e)
                Mode.NORMAL -> {
                    if (down && (code == KeyEvent.KEYCODE_DPAD_CENTER || code == KeyEvent.KEYCODE_ENTER)) lastActivate = SystemClock.uptimeMillis()
                    super.dispatchKeyEvent(e)
                }
            }
        }
        return super.dispatchKeyEvent(e)
    }

    private fun isDpad(code: Int) = code == KeyEvent.KEYCODE_DPAD_UP || code == KeyEvent.KEYCODE_DPAD_DOWN ||
        code == KeyEvent.KEYCODE_DPAD_LEFT || code == KeyEvent.KEYCODE_DPAD_RIGHT ||
        code == KeyEvent.KEYCODE_DPAD_CENTER || code == KeyEvent.KEYCODE_ENTER || code == KeyEvent.KEYCODE_NUMPAD_ENTER

    private fun isOk(code: Int) = code == KeyEvent.KEYCODE_DPAD_CENTER || code == KeyEvent.KEYCODE_ENTER || code == KeyEvent.KEYCODE_NUMPAD_ENTER

    /** ☰ kurz = Modus wechseln (in der Video-Ansicht: Optionen der Karte), ☰ lang = Browser-Menü. */
    private fun handleMenuKey(e: KeyEvent) {
        if (e.action == KeyEvent.ACTION_DOWN) {
            if (e.repeatCount == 0) menuLongFired = false
            else if (!menuLongFired && (e.isLongPress || e.eventTime - e.downTime >= 550)) {
                menuLongFired = true
                showBrowserMenu()
            }
        } else if (e.action == KeyEvent.ACTION_UP) {
            if (!menuLongFired) {
                if (overlayVisible) ((currentFocus as? CardView)?.item?.onMenu ?: { showBrowserMenu() }).invoke()
                else cycleMode()
            }
            menuLongFired = false
        }
    }

    /** OK mit Lang-Druck-Erkennung: lang = Browser-Menü. */
    private fun handleOk(e: KeyEvent, onShort: () -> Unit): Boolean {
        if (e.action == KeyEvent.ACTION_DOWN) {
            if (e.repeatCount == 0) okLongFired = false
            else if (!okLongFired && (e.isLongPress || e.eventTime - e.downTime >= 650)) {
                okLongFired = true
                showBrowserMenu()
            }
        } else if (e.action == KeyEvent.ACTION_UP) {
            if (!okLongFired) onShort()
            okLongFired = false
        }
        return true
    }

    private fun handleLinkKey(e: KeyEvent): Boolean {
        val code = e.keyCode
        if (textFocus && (code == KeyEvent.KEYCODE_DPAD_LEFT || code == KeyEvent.KEYCODE_DPAD_RIGHT)) return super.dispatchKeyEvent(e)
        if (isOk(code)) return handleOk(e) { activateLink() }
        if (e.action != KeyEvent.ACTION_DOWN) return true
        val dir = when (code) {
            KeyEvent.KEYCODE_DPAD_UP -> "up"
            KeyEvent.KEYCODE_DPAD_DOWN -> "down"
            KeyEvent.KEYCODE_DPAD_LEFT -> "left"
            else -> "right"
        }
        js("window.__ovl && __ovl.nav('$dir')") { r ->
            if (r == null || r == "null") { injectFallback(); }
        }
        return true
    }

    private fun activateLink() {
        js("window.__ovl ? __ovl.activate() : null") { r ->
            val o = parseObj(r)
            if (o == null) {
                js("window.__ovl && __ovl.nav('down')")
                return@js
            }
            val iw = o.optDouble("iw", 0.0)
            val scale = if (iw > 0) web.width / iw else resources.displayMetrics.density.toDouble()
            tap((o.optDouble("x") * scale).toFloat(), (o.optDouble("y") * scale).toFloat())
            if (o.optBoolean("media")) ensurePlayback()
        }
    }

    private fun parseObj(r: String?): JSONObject? {
        if (r == null || !r.startsWith("{")) return null
        return try { JSONObject(r) } catch (e: Exception) { null }
    }

    /** Echter Tipp (Touch-Ereignis) – damit reagieren auch Player in iframes. */
    private fun tap(x: Float, y: Float) {
        lastActivate = SystemClock.uptimeMillis()
        val t = SystemClock.uptimeMillis()
        val downEv = MotionEvent.obtain(t, t, MotionEvent.ACTION_DOWN, x, y, 0).apply { source = InputDevice.SOURCE_TOUCHSCREEN }
        web.dispatchTouchEvent(downEv)
        downEv.recycle()
        ui.postDelayed({
            val t2 = SystemClock.uptimeMillis()
            val upEv = MotionEvent.obtain(t, t2, MotionEvent.ACTION_UP, x, y, 0).apply { source = InputDevice.SOURCE_TOUCHSCREEN }
            web.dispatchTouchEvent(upEv)
            upEv.recycle()
        }, 60)
    }

    private fun hover(x: Float, y: Float) {
        val t = SystemClock.uptimeMillis()
        val ev = MotionEvent.obtain(t, t, MotionEvent.ACTION_HOVER_MOVE, x, y, 0).apply { source = InputDevice.SOURCE_MOUSE }
        web.dispatchGenericMotionEvent(ev)
        ev.recycle()
    }

    private fun handlePointerKey(e: KeyEvent): Boolean {
        val code = e.keyCode
        if (isOk(code)) return handleOk(e) { tap(cursorX + dp(4), cursorY + dp(3)) }
        if (e.action != KeyEvent.ACTION_DOWN) return true
        val accel = 1f + min(e.repeatCount, 24) * 0.45f
        val step = dpf(9f) * accel
        var dx = 0f
        var dy = 0f
        when (code) {
            KeyEvent.KEYCODE_DPAD_UP -> dy = -step
            KeyEvent.KEYCODE_DPAD_DOWN -> dy = step
            KeyEvent.KEYCODE_DPAD_LEFT -> dx = -step
            KeyEvent.KEYCODE_DPAD_RIGHT -> dx = step
        }
        val maxX = (web.width - dp(8)).toFloat()
        val maxY = (web.height - dp(8)).toFloat()
        val nx = (cursorX + dx).coerceIn(0f, maxX)
        val ny = (cursorY + dy).coerceIn(0f, maxY)
        // Am Rand: Seite scrollen
        val edge = dpf(24f)
        val scrollX = if ((dx < 0 && nx <= edge) || (dx > 0 && nx >= maxX - edge)) dx * 2.5f else 0f
        val scrollY = if ((dy < 0 && ny <= edge) || (dy > 0 && ny >= maxY - edge)) dy * 2.5f else 0f
        cursorX = nx
        cursorY = ny
        placeCursor()
        if (scrollX != 0f || scrollY != 0f) {
            js("window.__ovl ? __ovl.viewport() : null") { r ->
                val iw = parseObj(r)?.optDouble("iw", 0.0) ?: 0.0
                val s = if (iw > 0) web.width / iw else resources.displayMetrics.density.toDouble()
                js("window.__ovl ? __ovl.scrollAt(${cursorX / s}, ${cursorY / s}, ${scrollX / s}, ${scrollY / s}) : window.scrollBy(${scrollX / s}, ${scrollY / s})")
            }
        }
        hover(cursorX + dp(4), cursorY + dp(3))
        return true
    }

    private fun placeCursor() {
        cursor.translationX = cursorX
        cursor.translationY = cursorY
    }

    private fun cycleMode() {
        setMode(when (mode) { Mode.LINKS -> Mode.POINTER; Mode.POINTER -> Mode.NORMAL; Mode.NORMAL -> Mode.LINKS })
    }

    /** Zuletzt genutzter Steuerungsmodus für diese Domain (Standard: Link-Modus). */
    private fun savedModeFor(url: String): Mode = try {
        Mode.valueOf(getSharedPreferences("mode", MODE_PRIVATE).getString(baseDomain(hostOf(url)), Mode.LINKS.name) ?: Mode.LINKS.name)
    } catch (e: Exception) {
        Mode.LINKS
    }

    private fun setMode(m: Mode, remember: Boolean = true) {
        mode = m
        if (remember) hostOf(web.url).takeIf { it.isNotBlank() }?.let { getSharedPreferences("mode", MODE_PRIVATE).edit().putString(baseDomain(it), m.name).apply() }
        when (m) {
            Mode.LINKS -> {
                cursor.visibility = View.GONE
                js("window.__ovl && __ovl.showHl(true)")
            }
            Mode.POINTER -> {
                web.post {
                    if (cursorX == 0f && cursorY == 0f) { cursorX = web.width / 2f; cursorY = web.height / 2f }
                    placeCursor()
                }
                cursor.visibility = View.VISIBLE
                js("window.__ovl && __ovl.showHl(false)")
            }
            Mode.NORMAL -> {
                cursor.visibility = View.GONE
                js("window.__ovl && __ovl.showHl(false)")
                web.requestFocus()
            }
        }
        showMode()
    }

    private fun showMode() {
        modeText.text = mode.label
        modeIcon.setImageResource(mode.icon)
        modePill.animate().alpha(1f).setDuration(150).start()
        ui.removeCallbacks(hideMode)
        ui.postDelayed(hideMode, 1800)
    }

    private fun showChip(msg: String, iconRes: Int = R.drawable.ic_info) {
        chipText.text = msg
        chipIcon.setImageResource(iconRes)
        chipPill.translationY = -dpf(10f)
        chipPill.animate().alpha(1f).translationY(0f).setDuration(180).start()
        ui.removeCallbacks(hideChip)
        ui.postDelayed(hideChip, 3500)
    }

    /** Zurück: Leiste ausblenden → Vollbild verlassen → vorherige Seite → Startseite. */
    private fun handleBack() {
        when {
            nextBox.visibility == View.VISIBLE -> cancelCountdown()
            playerBar.visibility == View.VISIBLE && playerBar.hasFocus() -> hidePlayerBar()
            customView != null -> chrome.onHideCustomView()
            cinema -> exitCinema()
            videoMode && !overlayVisible -> showOverlayFromCache()
            videoMode && overlayVisible -> videoBack()
            maximized -> { maximized = false; cmd("unmaximize") }
            playerBar.visibility == View.VISIBLE -> hidePlayerBar()
            web.canGoBack() -> web.goBack()
            else -> finish()
        }
    }

    // ===================================================================== Video-Ansicht

    private fun cacheKey(url: String?) = ContinueStore.keyFor(url ?: "")

    private fun setVideoMode(on: Boolean) {
        Prefs.setVideoView(web.url, on)
        videoMode = on
        if (on) {
            showChip("Video-Ansicht für ${baseDomain(hostOf(web.url))} an", R.drawable.ic_movie)
            showOverlayFromCache()
            scheduleExtract(web.url ?: "", prefetch = true)
        } else {
            if (cinema) exitCinema(showList = false)
            hideOverlay()
            showChip("Video-Ansicht aus – ganze Webseite", R.drawable.ic_globe)
        }
    }

    private fun onVideoModePageStarted(url: String) {
        videoMode = Prefs.videoView(url)
        extractToken++
        pageSerial++
        if (!videoMode) { if (overlayVisible) hideOverlay(); if (cinema) { cinema = false; maximized = false }; return }
        if (cinema) { cinema = false; maximized = false }
        if (websiteChosen && !autoCinema) return
        val cached = extractCache[cacheKey(url)]
        if (cached != null && !autoCinema) renderOverlay(cached)
        else if (autoCinema) {
            // Folge wurde gewählt: schwarzer Ladebildschirm statt Übersicht, Player startet gleich
            vview.setRows(emptyList(), null)
            vview.showInfo("WIRD GELADEN", tileTitle.ifBlank { hostOf(url) }, "Der Player startet gleich …", tileColor)
            showOverlay()
        } else {
            vview.setRows(emptyList(), null)
            vview.setBrandText(hostOf(url))
            vview.showInfo("VIDEO-ANSICHT", hostOf(url), "Suche Videos auf der Seite …", tileColor)
            showOverlay()
        }
    }

    private fun onVideoModePageFinished(url: String) {
        if (!videoMode || (websiteChosen && !autoCinema)) return
        scheduleExtract(url, prefetch = extractCache[cacheKey(url)] == null && !autoCinema)
    }

    /** Seite (nach dem Nachladen) auslesen – zweimal, weil viele Seiten Inhalte erst später einfügen. */
    private fun scheduleExtract(url: String, prefetch: Boolean) {
        val token = ++extractToken
        if (prefetch) js("window.__ovl && __ovl.prefetch()")
        ui.postDelayed({ runExtract(token, url, final = false) }, if (prefetch) 2000 else 900)
        ui.postDelayed({ runExtract(token, url, final = false) }, if (prefetch) 5000 else 3000)
        ui.postDelayed({ runExtract(token, url, final = true) }, if (prefetch) 8500 else 5500)
    }

    /** Kurzes Protokoll der Erkennung (adb logcat -s OverlordVV) – hilft beim Verbessern für neue Seiten. */
    private fun logExtract(url: String, o: JSONObject, final: Boolean) {
        try {
            val secs = jsonItems(o.optJSONArray("sections")).joinToString(" | ") { s -> "${s.optString("title").ifBlank { "–" }} (${s.optJSONArray("items")?.length() ?: 0})" }
            val eps = o.optJSONArray("episodes")?.length() ?: 0
            val firstEp = jsonItems(o.optJSONArray("episodes")).firstOrNull()?.optString("title") ?: ""
            val seasons = jsonItems(o.optJSONArray("seasons")).joinToString(", ") { it.optString("title") + (if (it.optBoolean("active")) "*" else "") }
            val srcs = jsonItems(o.optJSONArray("sources")).joinToString(", ") { it.optString("label") }
            val player = o.optJSONObject("player")?.optString("tag") ?: "-"
            android.util.Log.i("OverlordVV", "${if (final) "FINAL" else "zwischen"} url=$url | titel=${o.optString("title")} | player=$player | " +
                "next=${o.optString("next").isNotBlank()} | reihen=[$secs] | folgen=$eps ($firstEp) | staffeln=[$seasons] | versionen=[$srcs]")
            // Beim letzten Durchlauf zusätzlich einen Kurzbefund der Seite (Videos, iframes, Cookie-Dialog, Player-Bereiche)
            if (final) js("window.__ovl && __ovl.diag ? __ovl.diag() : null") { d ->
                if (d != null && d != "null") android.util.Log.i("OverlordVV", "DIAG url=$url | $d")
            }
        } catch (e: Exception) { }
    }

    /** Reihen-Inhalte einer Auslese: Bildreihen, Folgen, Staffeln. */
    private fun contentCount(o: JSONObject?): Int {
        if (o == null) return 0
        val seasons = o.optJSONArray("seasons")?.length() ?: 0
        return (o.optJSONArray("sections")?.length() ?: 0) + (o.optJSONArray("episodes")?.length() ?: 0) + (if (seasons >= 2) seasons else 0)
    }

    /** Anzahl der Karten einer Auslese (um unnötiges Neuzeichnen zu vermeiden). */
    private fun itemCount(o: JSONObject): Int {
        val secs = o.optJSONArray("sections") ?: return 0
        var n = 0
        for (i in 0 until secs.length()) n += secs.optJSONObject(i)?.optJSONArray("items")?.length() ?: 0
        n += (o.optJSONArray("episodes")?.length() ?: 0) + (o.optJSONArray("seasons")?.length() ?: 0) + (o.optJSONArray("sources")?.length() ?: 0)
        return n + (if (o.optJSONObject("player") != null) 1000 else 0)
    }
    private val renderedCount = HashMap<String, Int>()

    private fun runExtract(token: Int, url: String, final: Boolean) {
        if (token != extractToken || !videoMode || isFinishing) return
        js("window.__ovl ? __ovl.extract() : null") { r ->
            if (token != extractToken || !videoMode) return@js
            val o = parseObj(r) ?: return@js
            val key = cacheKey(url)
            val count = itemCount(o)
            // Nichts Neues gefunden → nicht neu zeichnen (verhindert Flackern)
            val prevRendered = renderedCount[key]
            if (final) logExtract(url, o, true)
            if (prevRendered != null && count <= prevRendered && overlayVisible && !cinema) return@js
            if (count < (extractCache[key]?.let { itemCount(it) } ?: 0)) return@js
            extractCache[key] = o
            if (!final) logExtract(url, o, false)
            val sections = contentCount(o)
            val hasPlayer = o.optJSONObject("player") != null
            when {
                cinema -> {}
                hasPlayer && (autoCinema || pendingResume != null) -> { autoCinema = false; enterCinema() }
                sections == 0 && !hasPlayer && final -> {
                    if (autoCinema) { autoCinema = false; ensurePlayback() }
                    showWebsite("Keine Videos erkannt – die Webseite wird angezeigt", userChoice = false)
                }
                sections > 0 || hasPlayer -> renderOverlay(o)
                // sonst: auf den zweiten (finalen) Durchlauf warten
            }
        }
    }

    private fun jsonItems(arr: org.json.JSONArray?): List<JSONObject> =
        if (arr == null) emptyList() else List(arr.length()) { arr.getJSONObject(it) }

    /** Ausgelesene Seite als eigene TV-Oberfläche darstellen. */
    private fun renderOverlay(o: JSONObject) {
        val pageUrl = o.optString("url").ifBlank { web.url ?: "" }
        val site = o.optString("site").ifBlank { hostOf(pageUrl) }
        val pageTitle = o.optString("title").ifBlank { site }
        val desc = o.optString("description")
        val image = o.optString("image")
        val player = o.optJSONObject("player")
        val next = o.optString("next")
        vview.setBrandText(site)

        val actions = ArrayList<CardItem>()
        if (player != null) actions.add(CardItem(
            id = "v:play", title = "Video abspielen", subtitle = pageTitle.take(40), eyebrow = "DIESE SEITE",
            chips = listOf(site, "Kino-Modus"), description = desc.ifBlank { "Startet den Player dieser Seite bildschirmfüllend – ohne den Rest der Webseite." },
            color = tileColor, iconRes = R.drawable.ic_play,
            imageUrls = listOf(player.optString("poster").ifBlank { image }).filter { it.isNotBlank() },
            heroImageUrls = listOf(image).filter { it.isNotBlank() }, imageReferer = pageUrl,
            okHint = "Abspielen", onClick = { enterCinema() },
        ))
        if (next.isNotBlank()) actions.add(CardItem(
            id = "v:next", title = "Nächste Folge", iconRes = R.drawable.ic_next, color = darken(tileColor, 0.8f),
            eyebrow = "DIESE SEITE", chips = listOf(hostOf(next)), description = "Öffnet die nächste Folge und startet sie direkt.",
            okHint = "Abspielen", onClick = { openItem(next) },
        ))
        actions.add(CardItem(
            id = "v:web", title = "Webseite anzeigen", iconRes = R.drawable.ic_globe, color = 0xFF1F2937.toInt(),
            eyebrow = "VIDEO-ANSICHT", chips = listOf(site),
            description = "Die ganze Seite anzeigen – z. B. für Anmeldung, Cookie-Hinweise oder Menüs. Zurück führt wieder hierher.",
            onClick = { showWebsite() },
        ))
        actions.add(CardItem(
            id = "v:search", title = "Suchen", iconRes = R.drawable.ic_search, color = 0xFF312E81.toInt(),
            eyebrow = "VIDEO-ANSICHT", chips = listOf(site), description = "Einen Begriff an die Suche der Seite schicken – die Treffer erscheinen hier als Karten.",
            okHint = "Suchen", onClick = { quickSearch() },
        ))

        // Staffeln, Folgen, Versionen (Serien-Aufbau)
        val activeSeason = o.optString("activeSeason")
        val episodeCards = jsonItems(o.optJSONArray("episodes")).map { ep ->
            val url = ep.optString("url")
            val num = ep.optInt("num")
            val active = ep.optBoolean("active")
            val img = ep.optString("image")
            val season = ep.optInt("season")
            val seasonLabel = activeSeason.ifBlank { if (season > 0) "Staffel $season" else "" }
            // „Folge 3: Titel“ → „Titel“ (die Nummer steht schon im Untertitel)
            val epTitle = ep.optString("title").replace(Regex("^(Folge|Episode|Ep\\.?)\\s*$num\\s*[–:|.\\-]\\s*", RegexOption.IGNORE_CASE), "")
            CardItem(
                id = "v:ep:$season:$num:$url", title = epTitle.ifBlank { "Folge $num" },
                subtitle = (if (seasonLabel.isNotBlank()) "$seasonLabel · " else "") + "Folge $num" + (if (active) " · läuft" else ""),
                eyebrow = (seasonLabel.ifBlank { "Folgen" } + " · Folge $num").uppercase(),
                chips = listOfNotNull(site, seasonLabel.takeIf { it.isNotBlank() }, if (active) "Aktuelle Folge" else null),
                description = desc.ifBlank { pageTitle },
                color = if (active) Brand.ACCENT else tileColor,
                imageUrls = listOf(img).filter { it.isNotBlank() },
                heroImageUrls = listOf(img.ifBlank { image }).filter { it.isNotBlank() },
                imageReferer = pageUrl, number = if (img.isBlank()) "$num" else null,
                okHint = "Abspielen", onClick = { openItem(url) },
            )
        }
        val seasonCards = jsonItems(o.optJSONArray("seasons")).map { se ->
            val title = se.optString("title")
            val url = se.optString("url")
            val idx = se.optInt("index")
            val active = se.optBoolean("active")
            CardItem(
                id = "v:season:$idx:$title", title = title, subtitle = if (active) "Aktuell" else site,
                eyebrow = "STAFFELN", chips = listOfNotNull(site, if (active) "Aktuell" else null),
                description = desc.ifBlank { pageTitle }, color = if (active) Brand.ACCENT else darken(tileColor, 0.75f),
                iconRes = R.drawable.ic_library, heroImageUrls = listOf(image).filter { it.isNotBlank() }, imageReferer = pageUrl,
                okHint = "Folgen zeigen",
                onClick = {
                    if (url.isNotBlank()) { autoCinema = false; lastActivate = SystemClock.uptimeMillis(); web.loadUrl(url) }
                    else js("window.__ovl ? __ovl.clickSeason($idx) : false") { scheduleExtract(web.url ?: pageUrl, prefetch = false) }
                },
            )
        }
        val sourceCards = jsonItems(o.optJSONArray("sources")).map { so ->
            val label = so.optString("label")
            val idx = so.optInt("index")
            val active = so.optBoolean("active")
            val subs = Regex("untertitel|omu|subs?\\b|sub(bed|titled)", RegexOption.IGNORE_CASE).containsMatchIn(label)
            CardItem(
                id = "v:src:$idx:$label", title = label, subtitle = if (active) "Aktiv" else "Version ${idx + 1}",
                eyebrow = "VERSIONEN & QUELLEN", chips = listOfNotNull(site, if (active) "Aktiv" else null),
                description = "Spielt das Video in dieser Version ab (z. B. Sprache, Untertitel oder Quelle).",
                color = if (active) Brand.ACCENT else 0xFF334155.toInt(),
                iconRes = if (subs) R.drawable.ic_subtitles else R.drawable.ic_tune,
                okHint = "Abspielen", onClick = { pickSource(idx) },
            )
        }

        val rows = ArrayList<RowData>()
        val content = jsonItems(o.optJSONArray("sections")).mapIndexedNotNull { si, sec ->
            val title = sec.optString("title").ifBlank { if (si == 0) "Videos" else "Mehr" }
            val cards = jsonItems(sec.optJSONArray("items")).mapIndexed { ii, it ->
                val url = it.optString("url")
                val img = it.optString("image")
                val sub = it.optString("sub")
                CardItem(
                    id = "v:$si:$ii:$url", title = it.optString("title"), subtitle = sub,
                    eyebrow = title.uppercase().take(40), chips = listOf(site) + sub.split(" · ").filter { s -> s.isNotBlank() },
                    description = "", color = Brand.colorFor(url),
                    imageUrls = listOf(img).filter { s -> s.isNotBlank() }, heroImageUrls = listOf(img).filter { s -> s.isNotBlank() },
                    imageReferer = pageUrl, okHint = "Öffnen",
                    onClick = { openItem(url) },
                    onMenu = {
                        Tv.menu(this, it.optString("title"), listOf(
                            MenuEntry("Öffnen und abspielen", R.drawable.ic_play) { openItem(url) },
                            MenuEntry("Als Webseite öffnen", R.drawable.ic_globe) { autoCinema = false; lastActivate = SystemClock.uptimeMillis(); web.loadUrl(url); showWebsite() },
                            MenuEntry("Als Kachel speichern", R.drawable.ic_bookmark) {
                                TileStore.add(this, TileStore.newWeb(it.optString("title").take(30), url))
                                tvToast("Kachel gespeichert", R.drawable.ic_check)
                            },
                        ), subtitle = hostOf(url), eyebrow = "VIDEO-ANSICHT")
                    },
                )
            }
            if (cards.isEmpty()) null else RowData(title, cards)
        }
        val epRowTitle = if (activeSeason.isNotBlank()) "$activeSeason · Folgen" else "Folgen"
        // Auf Seiten mit Player stehen die Aktionen oben, sonst unter den Inhalten
        if (player != null) {
            rows.add(RowData(pageTitle.take(50), actions))
            if (sourceCards.size >= 2) rows.add(RowData("Versionen & Quellen", sourceCards))
            if (episodeCards.isNotEmpty()) rows.add(RowData(epRowTitle, episodeCards))
            if (seasonCards.size >= 2) rows.add(RowData("Staffeln", seasonCards))
            rows.addAll(content)
        } else {
            if (episodeCards.isNotEmpty()) rows.add(RowData(epRowTitle, episodeCards))
            if (seasonCards.size >= 2) rows.add(RowData("Staffeln", seasonCards))
            rows.addAll(content)
            rows.add(RowData("Diese Seite", actions))
        }
        cmd("pause")
        renderedCount[cacheKey(pageUrl)] = itemCount(o)
        vview.setRows(rows, lastFocus[cacheKey(pageUrl)] ?: vview.focusedItem?.id)
        showOverlay()
    }

    private fun showOverlay() {
        if (!overlayVisible) {
            overlayVisible = true
            vview.alpha = 0f
            vview.visibility = View.VISIBLE
            vview.animate().alpha(1f).setDuration(200).start()
            cursor.visibility = View.GONE
            js("window.__ovl && __ovl.showHl(false)")
        }
        hidePlayerBar()
        vview.post { if (!vview.hasFocus()) vview.refocus() }
    }

    private fun hideOverlay() {
        if (!overlayVisible) return
        overlayVisible = false
        vview.visibility = View.GONE
        web.requestFocus()
        if (mode == Mode.LINKS) js("window.__ovl && __ovl.showHl(true)")
        if (mode == Mode.POINTER) cursor.visibility = View.VISIBLE
    }

    private fun showOverlayFromCache() {
        websiteChosen = false
        val cached = extractCache[cacheKey(web.url)]
        if (cached != null) renderOverlay(cached) else { showOverlay(); scheduleExtract(web.url ?: "", prefetch = true) }
    }

    private fun showWebsite(hint: String = "Ganze Webseite · Zurück führt zur Video-Ansicht", userChoice: Boolean = true) {
        websiteChosen = userChoice
        hideOverlay()
        showChip(hint, R.drawable.ic_globe)
    }

    /** Version/Quelle am Player umschalten und danach (wieder) im Kino-Modus abspielen. */
    private fun pickSource(i: Int) {
        autoCinema = true
        lastActivate = SystemClock.uptimeMillis()
        val before = web.url
        if (cinema) exitCinema(showList = false)
        js("window.__ovl ? __ovl.pickSource($i) : false")
        showChip("Version wird gewechselt …", R.drawable.ic_tune)
        ui.postDelayed({ if (!cinema && web.url == before && !isFinishing) { autoCinema = false; enterCinema() } }, 1600)
    }

    /** Karte gewählt: Seite laden; hat sie einen Player, startet er direkt im Kino-Modus. */
    private fun openItem(url: String) {
        websiteChosen = false
        vview.focusedItem?.id?.let { lastFocus[cacheKey(web.url)] = it }
        autoCinema = true
        lastActivate = SystemClock.uptimeMillis()
        tileTitle = ""
        web.loadUrl(url)
    }

    /**
     * Kino-Modus starten. Gibt es noch keinen Player, aber ein Vorschaubild mit Play-Knopf, wird der Knopf
     * echt angetippt (wie mit dem Finger) und danach mehrmals nach dem entstehenden Player gesucht.
     */
    private fun enterCinema(attempt: Int = 0) {
        val serial = pageSerial
        js("window.__ovl ? __ovl.cinema(true) : null") { r ->
            if (cinema || isFinishing || serial != pageSerial || (attempt > 0 && websiteChosen)) return@js
            val o = parseObj(r)
            if (r == null || r == "null" || o != null) {
                if (o != null && o.optInt("tap") == 1 && (attempt == 0 || attempt == 3)) {
                    val iw = o.optDouble("iw", 0.0)
                    val scale = if (iw > 0) web.width / iw else resources.displayMetrics.density.toDouble()
                    tap((o.optDouble("x") * scale).toFloat(), (o.optDouble("y") * scale).toFloat())
                } else if (attempt == 0) cmd("autoplay")   // Play-Knopf per Skript drücken
                if (attempt < 6) {
                    ui.postDelayed({ if (!cinema && !isFinishing && serial == pageSerial) enterCinema(attempt + 1) }, if (attempt == 0) 1500L else 1000L)
                } else showWebsite("Kein Player gefunden – die Webseite wird angezeigt", userChoice = false)
                return@js
            }
            cinema = true
            maximized = true
            hideOverlay()
            js("window.__ovl && __ovl.showHl(false)")
            cursor.visibility = View.GONE
            ensurePlayback()
            showPlayerBar(focus = false)
        }
    }

    private fun exitCinema(showList: Boolean = true) {
        cinema = false
        maximized = false
        js("window.__ovl && __ovl.cinema(false)")
        cmd("pause")
        hidePlayerBar()
        if (!showList) return
        val cached = extractCache[cacheKey(web.url)]
        val extras = (cached?.optJSONArray("sources")?.length() ?: 0)
        // Nur ein Player auf der Seite: zurück zur vorherigen Seite – gibt es keine, die Übersicht dieser Seite zeigen
        if (cached != null && (contentCount(cached) > 0 || extras >= 2 || !web.canGoBack())) renderOverlay(cached) else videoBack()
    }

    /** Zurück in der Video-Ansicht: vorherige Seite (sofort aus dem Zwischenspeicher) oder Startseite. */
    private fun videoBack() {
        autoCinema = false
        if (!web.canGoBack()) { finish(); return }
        val list = web.copyBackForwardList()
        val prev = list.getItemAtIndex(list.currentIndex - 1)?.url
        web.goBack()
        extractCache[cacheKey(prev)]?.let { renderOverlay(it) }
    }

    // ===================================================================== Video-Steuerung

    private fun seek(delta: Double) {
        cmd("seek", delta)
        if (videoDur > 0) {
            videoPos = (videoPos + delta).coerceIn(0.0, videoDur)
            updateBar()
        }
    }

    private fun toggleMaximize() {
        if (customView != null) { chrome.onHideCustomView(); return }
        if (cinema) { showChip("Kino-Modus · Zurück führt zur Übersicht", R.drawable.ic_movie); return }
        maximized = !maximized
        cmd(if (maximized) "maximize" else "unmaximize")
        if (maximized) showChip("Vollbild · Zurück zum Verlassen", R.drawable.ic_fullscreen)
    }

    private fun nextEpisode() {
        nextDone = false
        if (videoMode) {
            autoCinema = true
            extractCache[cacheKey(web.url)]?.optString("next")?.takeIf { it.isNotBlank() }?.let { next ->
                showChip("Nächste Folge …", R.drawable.ic_next)
                if (cinema) { cinema = false; maximized = false }
                openItem(next)
                return
            }
        }
        showChip("Suche nächste Folge …", R.drawable.ic_next)
        js("window.__ovl ? __ovl.nextLocal() : false") { r ->
            if (r == "true") return@js
            cmd("next")
            ui.postDelayed({
                if (nextDone) return@postDelayed
                js("window.__ovl ? __ovl.nextByUrl() : false") { r2 ->
                    if (r2 != "true") showChip("Keine nächste Folge gefunden", R.drawable.ic_warning)
                }
            }, 900)
        }
    }

    /**
     * OK auf einen Player: Reagiert der Player nicht auf den Tipp (z. B. weil eine Klickfläche
     * ein Pop-up statt des Videos öffnet), wird das Video per Skript gestartet – auch im iframe.
     */
    private fun ensurePlayback() {
        var tries = 0
        val tick = object : Runnable {
            override fun run() {
                if (isFinishing || (videoActive() && videoPlaying)) return
                cmd("autoplay")
                if (++tries < 4) ui.postDelayed(this, 1200)
            }
        }
        ui.postDelayed(tick, 900)
    }

    /** Beim Fortsetzen: Video automatisch starten (auch Player in iframes). */
    private fun startAutoplay() {
        autoplayTries = 0
        val tick = object : Runnable {
            override fun run() {
                if (pendingResume == null || isFinishing) return
                if (videoActive() && videoPlaying) return
                cmd("autoplay")
                if (++autoplayTries < 8) ui.postDelayed(this, 2000)
            }
        }
        ui.postDelayed(tick, 1500)
    }

    private fun showPlayerBar(focus: Boolean) {
        updateBar()
        playerBar.visibility = View.VISIBLE
        playerBar.alpha = 1f
        if (focus && !playerBar.hasFocus()) btnPlay.requestFocus()
        scheduleBarHide()
    }

    private fun scheduleBarHide() {
        ui.removeCallbacks(hideBar)
        ui.postDelayed(hideBar, 5000)
    }

    private fun hidePlayerBar() {
        if (playerBar.visibility != View.VISIBLE) return
        val hadFocus = playerBar.hasFocus()
        playerBar.visibility = View.GONE
        if (hadFocus) web.requestFocus()
    }

    private fun updateBar() {
        barTitle.text = pageTitle()
        barHost.text = hostOf(web.url).uppercase()
        btnPlayIcon.setImageResource(if (videoPlaying) R.drawable.ic_pause else R.drawable.ic_play)
        btnPlayLabel.text = if (videoPlaying) "Pause" else "Abspielen"
        if (videoDur > 0) {
            barTimeLeft.text = formatTime(videoPos)
            barTimeRight.text = "−" + formatTime(videoDur - videoPos)
            val frac = (videoPos / videoDur).coerceIn(0.0, 1.0)
            barTrack.post { barFill.layoutParams = FrameLayout.LayoutParams((barTrack.width * frac).toInt(), -1) }
        } else {
            barTimeLeft.text = if (videoActive()) "LIVE" else ""
            barTimeRight.text = ""
            barFill.layoutParams = FrameLayout.LayoutParams(0, -1)
        }
        barSpeedChip.text = speedText(speed)
        barSpeedChip.visibility = if (speed != 1.0) View.VISIBLE else View.GONE
    }

    private fun speedText(v: Double) = (if (v % 1.0 == 0.0) String.format("%.1f", v) else v.toString()).replace('.', ',') + "×"

    private fun cycleSpeed() {
        speed = SPEEDS[(SPEEDS.indexOf(speed) + 1) % SPEEDS.size]
        cmd("rate", speed)
        btnSpeedLabel.text = "Tempo " + speedText(speed)
        showChip("Wiedergabe-Tempo ${speedText(speed)}", R.drawable.ic_speed)
        updateBar()
    }

    private val countdownTick = object : Runnable {
        override fun run() {
            if (nextBox.visibility != View.VISIBLE) return
            if (countdown <= 0) { cancelCountdown(); nextEpisode(); return }
            nextCount.text = "Startet in $countdown s"
            countdown--
            ui.postDelayed(this, 1000)
        }
    }

    private fun startCountdown() {
        hidePlayerBar()
        countdown = 10
        nextBox.visibility = View.VISIBLE
        nextBox.alpha = 0f
        nextBox.animate().alpha(1f).setDuration(200).start()
        nextNow.requestFocus()
        ui.removeCallbacks(countdownTick)
        ui.post(countdownTick)
    }

    private fun cancelCountdown() {
        ui.removeCallbacks(countdownTick)
        if (nextBox.visibility == View.VISIBLE) {
            val hadFocus = nextBox.hasFocus()
            nextBox.visibility = View.GONE
            if (hadFocus) web.requestFocus()
        }
    }

    // ===================================================================== „Scraper“: nativ abspielen

    private fun bestMedia(): MediaHit? {
        if (videoSrc.isNotBlank()) detected[videoSrc]?.let { return it }
        return detected.values.sortedWith(
            compareByDescending<MediaHit> { it.duration }
                .thenByDescending { it.url.contains("master", true) || it.url.contains("index", true) }
                .thenByDescending { it.url.contains(".m3u8", true) }
        ).firstOrNull()
    }

    private fun playNative(hit: MediaHit? = bestMedia()) {
        if (hit == null) { showChip("Kein Video-Stream erkannt – Video zuerst auf der Seite starten", R.drawable.ic_movie); return }
        cmd("pause")
        val pageUrl = web.url ?: hit.referer
        val start = if (videoActive() && videoDur > 0) videoPos else (ContinueStore.get(this, pageUrl)?.position ?: 0.0)
        PlayerActivity.startWeb(
            this, hit.url, pageTitle(), pageUrl, hit.referer.ifBlank { pageUrl }, start, tileColor,
            userAgent = web.settings.userAgentString,
            cookies = CookieManager.getInstance().getCookie(hit.url) ?: "",
        )
    }

    private fun chooseMedia() {
        val hits = detected.values.toList().asReversed()
        if (hits.isEmpty()) { playNative(null); return }
        if (hits.size == 1) { playNative(hits[0]); return }
        Tv.menu(this, "Erkannte Videos", hits.map { h ->
            val name = Uri.parse(h.url).lastPathSegment ?: h.url
            val dur = if (h.duration > 0) formatTime(h.duration) else "Länge unbekannt"
            MenuEntry(name.take(48), if (h.url.contains(".m3u8", true)) R.drawable.ic_tv else R.drawable.ic_movie, "${hostOf(h.url)} · $dur") { playNative(h) }
        }, subtitle = "Im eigenen Player abspielen – ohne Seiten-Werbung", eyebrow = "VIDEO NATIV")
    }

    // ===================================================================== Menü

    private fun showBrowserMenu() {
        val e = ArrayList<MenuEntry>()
        e.add(MenuEntry(if (videoMode) "Video-Ansicht ausschalten" else "Video-Ansicht einschalten", R.drawable.ic_movie,
            if (videoMode) "Wieder die ganze Webseite anzeigen" else "Nur die Videos dieser Seite – als TV-Oberfläche, für ${baseDomain(hostOf(web.url))} merken") {
            setVideoMode(!videoMode)
        })
        if (videoMode && !overlayVisible) e.add(MenuEntry("Zur Video-Ansicht", R.drawable.ic_movie) { showOverlayFromCache() })
        val srcs = jsonItems(extractCache[cacheKey(web.url)]?.optJSONArray("sources"))
        if (srcs.size >= 2) e.add(MenuEntry("Version wählen", R.drawable.ic_tune, srcs.firstOrNull { it.optBoolean("active") }?.optString("label") ?: "${srcs.size} verfügbar") {
            Tv.menu(this, "Version wählen", srcs.map { so ->
                MenuEntry(so.optString("label"), R.drawable.ic_tune, if (so.optBoolean("active")) "Aktiv" else null) { pickSource(so.optInt("index")) }
            }, eyebrow = "VERSIONEN & QUELLEN")
        })
        e.add(MenuEntry("Schnellsuche auf dieser Seite", R.drawable.ic_search, "Begriff an die Suche von ${hostOf(web.url)} senden") { quickSearch() })
        e.add(MenuEntry("Adresse eingeben", R.drawable.ic_globe, hostOf(web.url)) {
            Tv.input(this, "Adresse", "Adresse oder Suchbegriff", web.url ?: "", url = true, icon = R.drawable.ic_globe, okLabel = "Öffnen") { u ->
                if (u.isNotBlank()) { lastActivate = SystemClock.uptimeMillis(); web.loadUrl(normalizeUrl(u)) }
            }
        })
        if (detected.isNotEmpty()) e.add(MenuEntry("Video nativ abspielen", R.drawable.ic_tv, "${detected.size} Stream(s) erkannt – ohne Werbung, schnelles Spulen") { chooseMedia() })
        if (videoActive()) e.add(MenuEntry("Player-Leiste zeigen", R.drawable.ic_play, "Tempo ${speedText(speed)}") { showPlayerBar(true) })
        lastBlockedUrl?.let { b -> e.add(MenuEntry("Blockiertes trotzdem öffnen", R.drawable.ic_warning, hostOf(b)) { lastActivate = SystemClock.uptimeMillis(); web.loadUrl(b) }) }
        val site = hostOf(web.url)
        if (site.isNotBlank()) {
            val on = !AdBlock.isAllowed(this, site)
            e.add(MenuEntry(if (on) "Schutz auf ${baseDomain(site)} ausschalten" else "Schutz auf ${baseDomain(site)} einschalten", R.drawable.ic_shield,
                if (on) "Falls Videos auf dieser Seite nicht starten" else "Werbe- und Pop-up-Blocker ist hier aus") {
                AdBlock.setAllowed(this, site, on)
                showChip(if (on) "Werbe-/Pop-up-Schutz für ${baseDomain(site)} aus" else "Schutz für ${baseDomain(site)} an", R.drawable.ic_shield)
                web.reload()
            })
        }
        e.add(MenuEntry("Steuerung: ${mode.label}", mode.icon, "Wechseln: Link → Zeiger → Normal (☰ kurz)") {
            Tv.menu(this, "Steuerung", Mode.values().map { m -> MenuEntry(m.label, m.icon, if (m == mode) "Aktiv" else null) { setMode(m) } }, eyebrow = "MODUS")
        })
        e.add(MenuEntry("Intro & Werbung automatisch überspringen", R.drawable.ic_skip_intro, if (Prefs.autoSkip) "An" else "Aus") {
            Prefs.autoSkip = !Prefs.autoSkip
            showChip("Automatisch überspringen: ${if (Prefs.autoSkip) "an" else "aus"}", R.drawable.ic_skip_intro)
            web.reload()
        })
        e.add(MenuEntry("Nächste Folge automatisch", R.drawable.ic_next, if (Prefs.autoNext) "An – Countdown am Ende eines Videos" else "Aus") {
            Prefs.autoNext = !Prefs.autoNext
            showChip("Nächste Folge automatisch: ${if (Prefs.autoNext) "an" else "aus"}", R.drawable.ic_next)
        })
        e.add(MenuEntry("Als Kachel zur Startseite hinzufügen", R.drawable.ic_bookmark, pageTitle().take(40)) {
            web.url?.let { url ->
                val t = TileStore.newWeb(pageTitle().take(30), url)
                TileStore.add(this, t)
                tvToast("Kachel „${t.name}“ hinzugefügt", R.drawable.ic_check)
            }
        })
        e.add(MenuEntry("Im externen Browser öffnen", R.drawable.ic_open_external) { web.url?.let { Launcher.openExternal(this, it) } })
        e.add(MenuEntry("Ansicht: ${uaModeFor(web.url).label}", R.drawable.ic_desktop, "Mobil, Desktop oder Smart-TV – für ${baseDomain(site)} merken") {
            Tv.menu(this, "Ansicht", UaMode.values().map { m ->
                MenuEntry(m.label, if (m == UaMode.TV) R.drawable.ic_tv else if (m == UaMode.DESKTOP) R.drawable.ic_desktop else R.drawable.ic_phone,
                    when (m) {
                        UaMode.MOBILE -> "Standard – kompakte Seiten"
                        UaMode.DESKTOP -> "Volle PC-Seite, oft besser auf großen Bildschirmen"
                        UaMode.TV -> "Manche Seiten haben eine eigene TV-Oberfläche"
                    } + (if (m == uaModeFor(web.url)) " · aktuell" else "")) {
                    getSharedPreferences("ua", MODE_PRIVATE).edit().putString(baseDomain(site), m.name).apply()
                    applyUserAgent()
                    web.reload()
                    showChip("Ansicht „${m.label}“ für ${baseDomain(site)}", R.drawable.ic_desktop)
                }
            }, eyebrow = "ANSICHT", subtitle = baseDomain(site))
        })
        e.add(MenuEntry("Textgröße: ${zoomFor(web.url ?: "")} %", R.drawable.ic_zoom, "Für ${baseDomain(site)} merken") {
            val opts = listOf(80, 90, 100, 115, 130, 150, 175, 200)
            Tv.menu(this, "Textgröße", opts.map { z ->
                MenuEntry("$z %", R.drawable.ic_zoom, if (z == zoomFor(web.url ?: "")) "Aktuell" else null) {
                    getSharedPreferences("zoom", MODE_PRIVATE).edit().putInt(baseDomain(site), z).apply()
                    web.settings.textZoom = z
                    showChip("Textgröße $z % für ${baseDomain(site)}", R.drawable.ic_zoom)
                }
            }, subtitle = baseDomain(site), eyebrow = "ANSICHT")
        })
        e.add(MenuEntry("Neu laden", R.drawable.ic_refresh) { web.reload() })
        e.add(MenuEntry("Zur Startseite", R.drawable.ic_home) { finish() })
        val blocked = blockedCount.get()
        Tv.menu(this, pageTitle(), e,
            subtitle = hostOf(web.url) + (if (blocked > 0) "  ·  $blocked Werbe-Anfragen blockiert" else ""), eyebrow = "BROWSER")
    }

    private fun quickSearch() {
        val voice: (() -> Unit)? = if (Voice.available(this)) ({ if (!Voice.start(this, "Wonach suchen?")) tvToast("Spracheingabe nicht verfügbar", R.drawable.ic_mic) }) else null
        Tv.input(this, "Schnellsuche", "Suchbegriff", icon = R.drawable.ic_search, okLabel = "Suchen", voice = voice,
            message = "Der Begriff wird an das Suchfeld von ${hostOf(web.url)} geschickt. Tipp: Das Mikrofon der Bildschirmtastatur funktioniert auch.") { term ->
            if (term.isNotBlank()) runSearch(term)
        }
    }

    /**
     * Text vom Handy in das aktive Feld der Webseite schreiben (auch React-Formulare).
     * Klappt das nicht (z. B. Feld in fremdem iframe), wird der Text als Tastendrücke eingespeist.
     */
    fun insertText(text: String, submit: Boolean): Boolean {
        js("window.__ovl ? __ovl.insertText(${JSONObject.quote(text)}, $submit) : false") { r ->
            if (r != "true") Thread {
                try {
                    val inst = android.app.Instrumentation()
                    inst.sendStringSync(text)
                    if (submit) inst.sendKeyDownUpSync(KeyEvent.KEYCODE_ENTER)
                } catch (e: Exception) { }
            }.start()
        }
        showChip("Text vom Handy empfangen", R.drawable.ic_phone)
        return true
    }

    private fun runSearch(term: String, second: Boolean = false) {
        js("window.__ovl ? __ovl.search(${JSONObject.quote(term)}, $second) : 'none'") { r ->
            val res = r?.trim('"') ?: "none"
            when {
                res == "ok" -> showChip("Suche nach „$term“ …", R.drawable.ic_search)
                res == "opened" && !second -> ui.postDelayed({ runSearch(term, true) }, 700)
                else -> {
                    val host = hostOf(web.url)
                    showChip("Kein Suchfeld gefunden – suche über DuckDuckGo auf $host", R.drawable.ic_search)
                    web.loadUrl("https://duckduckgo.com/?q=" + Uri.encode("site:$host $term"))
                }
            }
        }
    }

    @Deprecated("startActivityForResult")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        @Suppress("DEPRECATION")
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == Voice.REQUEST && resultCode == RESULT_OK) {
            Voice.result(data)?.let { runSearch(it) }
        }
    }

    // ===================================================================== Lebenszyklus

    override fun onPause() {
        super.onPause()
        // Position sichern
        if (videoActive() && videoDur >= ContinueStore.MIN_DURATION) {
            web.url?.let { ContinueStore.report(this, it, pageTitle(), videoPos, videoDur, tileColor) }
        }
        web.onPause()
    }

    override fun onResume() {
        super.onResume()
        web.onResume()
    }

    override fun onDestroy() {
        ui.removeCallbacksAndMessages(null)
        (web.parent as? ViewGroup)?.removeView(web)
        web.destroy()
        super.onDestroy()
    }
}
