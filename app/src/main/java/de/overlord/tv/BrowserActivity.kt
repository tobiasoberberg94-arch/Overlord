package de.overlord.tv

import android.annotation.SuppressLint
import android.app.Activity
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
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
import android.widget.Button
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

    enum class Mode(val label: String) { LINKS("🔗  Link-Modus"), POINTER("🖱  Zeiger-Modus"), NORMAL("⌨  Normaler Modus") }

    private data class MediaHit(val url: String, val referer: String, var duration: Double = 0.0)

    private val ui = Handler(Looper.getMainLooper())
    private lateinit var root: FrameLayout
    private lateinit var web: WebView
    private lateinit var cursor: ImageView
    private lateinit var modeLabel: TextView
    private lateinit var chip: TextView
    private lateinit var loadBar: ProgressBar
    private lateinit var fullscreenHolder: FrameLayout
    private lateinit var playerBar: LinearLayout
    private lateinit var barTitle: TextView
    private lateinit var barTime: TextView
    private lateinit var barProgress: ProgressBar
    private lateinit var btnPlay: Button

    private val chrome by lazy { Chrome() }
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
    private var desktopMode = false

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

    // Navigation / Blocker
    private var lastActivate = 0L
    private var lastBlockedUrl: String? = null
    private val detected = LinkedHashMap<String, MediaHit>()
    private var mediaChipShown = false

    // Tasten
    private var menuLongFired = false
    private var okLongFired = false

    private val hideChip = Runnable { chip.animate().alpha(0f).setDuration(250).start() }
    private val hideMode = Runnable { modeLabel.animate().alpha(0f).setDuration(250).start() }
    private val hideBar = Runnable { hidePlayerBar() }

    companion object {
        private const val EXTRA_URL = "url"
        private const val EXTRA_TITLE = "title"
        private const val EXTRA_COLOR = "color"
        private const val EXTRA_RESUME = "resume"
        private const val PREFS = "browser"
        private val MEDIA_RE = Regex("""\.(m3u8|mp4|webm|mkv|mov)(\?|$)""", RegexOption.IGNORE_CASE)
        private const val DESKTOP_UA = "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36"

        fun open(ctx: Context, url: String, title: String = "", color: Int = Brand.ACCENT, resume: Double = -1.0) {
            ctx.startActivity(
                Intent(ctx, BrowserActivity::class.java)
                    .putExtra(EXTRA_URL, url).putExtra(EXTRA_TITLE, title)
                    .putExtra(EXTRA_COLOR, color).putExtra(EXTRA_RESUME, resume)
            )
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
        script = assets.open("overlord.js").bufferedReader().use { it.readText() }
        desktopMode = getSharedPreferences(PREFS, MODE_PRIVATE).getBoolean("desktop", false)

        root = FrameLayout(this).apply { setBackgroundColor(Brand.BG) }
        web = WebView(this)
        root.addView(web, FrameLayout.LayoutParams(-1, -1))

        fullscreenHolder = FrameLayout(this).apply { setBackgroundColor(0xFF000000.toInt()); visibility = View.GONE }
        root.addView(fullscreenHolder, FrameLayout.LayoutParams(-1, -1))

        loadBar = ProgressBar(this, null, android.R.attr.progressBarStyleHorizontal).apply {
            max = 100
            progressTintList = android.content.res.ColorStateList.valueOf(Brand.ACCENT2)
        }
        root.addView(loadBar, FrameLayout.LayoutParams(-1, dp(4), Gravity.TOP))

        cursor = ImageView(this).apply { setImageResource(R.drawable.cursor); visibility = View.GONE; elevation = dpf(20f) }
        root.addView(cursor, FrameLayout.LayoutParams(dp(32), dp(32)))

        modeLabel = pill(18f).apply { alpha = 0f }
        root.addView(modeLabel, FrameLayout.LayoutParams(-2, -2, Gravity.TOP or Gravity.END).apply { topMargin = dp(20); rightMargin = dp(28) })

        chip = pill(15f).apply { alpha = 0f; maxWidth = (resources.displayMetrics.widthPixels * 0.7f).toInt() }
        root.addView(chip, FrameLayout.LayoutParams(-2, -2, Gravity.TOP or Gravity.CENTER_HORIZONTAL).apply { topMargin = dp(20) })

        buildPlayerBar()
        setContentView(root)
        setupWeb()

        // Auch über einen normalen Link (VIEW-Intent) aus anderen Apps aufrufbar
        val url = intent.getStringExtra(EXTRA_URL) ?: intent.dataString ?: "https://duckduckgo.com"
        if (tileTitle.isBlank()) tileTitle = hostOf(url)
        web.loadUrl(url)
        web.requestFocus()
        showMode()
    }

    private fun pill(size: Float) = TextView(this).apply {
        setTextColor(Brand.TEXT)
        textSize = size
        typeface = Typeface.DEFAULT_BOLD
        setPadding(dp(18), dp(10), dp(18), dp(10))
        background = GradientDrawable().apply { cornerRadius = dpf(30f); setColor(0xE6141420.toInt()); setStroke(dp(1), withAlpha(Brand.ACCENT, 0xAA)) }
        elevation = dpf(24f)
    }

    private fun buildPlayerBar() {
        playerBar = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(40), dp(20), dp(40), dp(24))
            background = GradientDrawable(GradientDrawable.Orientation.BOTTOM_TOP, intArrayOf(0xF0000000.toInt(), 0x00000000))
            visibility = View.GONE
            elevation = dpf(30f)
        }
        barTitle = TextView(this).apply { setTextColor(Brand.TEXT); textSize = 20f; typeface = Typeface.DEFAULT_BOLD; maxLines = 1 }
        barTime = TextView(this).apply { setTextColor(Brand.TEXT_DIM); textSize = 15f }
        barProgress = ProgressBar(this, null, android.R.attr.progressBarStyleHorizontal).apply {
            max = 1000
            progressTintList = android.content.res.ColorStateList.valueOf(Brand.ACCENT2)
        }
        val head = LinearLayout(this).apply { orientation = LinearLayout.HORIZONTAL; gravity = Gravity.BOTTOM }
        head.addView(barTitle, LinearLayout.LayoutParams(0, -2, 1f))
        head.addView(barTime)
        playerBar.addView(head)
        playerBar.addView(barProgress, LinearLayout.LayoutParams(-1, dp(8)).apply { topMargin = dp(8); bottomMargin = dp(14) })

        val buttons = LinearLayout(this).apply { orientation = LinearLayout.HORIZONTAL; gravity = Gravity.CENTER }
        fun btn(label: String, action: () -> Unit) = Button(this).apply {
            text = label
            isAllCaps = false
            textSize = 18f
            setTextColor(Brand.TEXT)
            background = buttonBackground(14)
            setPadding(dp(22), dp(12), dp(22), dp(12))
            setOnClickListener { action(); scheduleBarHide() }
            buttons.addView(this, LinearLayout.LayoutParams(-2, dp(60)).apply { marginStart = dp(8); marginEnd = dp(8) })
        }
        btn("⏪  10 s") { seek(-10.0) }
        btnPlay = btn("⏯  Play/Pause") { cmd("toggle") }
        btn("10 s  ⏩") { seek(10.0) }
        btn("⏭  Nächste Folge") { nextEpisode() }
        btn("⛶  Vollbild") { toggleMaximize() }
        btn("▶  Nativ") { playNative() }
        playerBar.addView(buttons)
        root.addView(playerBar, FrameLayout.LayoutParams(-1, -2, Gravity.BOTTOM))
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

    private fun applyUserAgent() {
        val s = web.settings
        if (desktopMode) {
            s.userAgentString = DESKTOP_UA
        } else {
            // WebView-Kennung entfernen – manche Seiten sperren sonst „eingebettete Browser“.
            val def = WebSettings.getDefaultUserAgent(this)
            s.userAgentString = def.replace("; wv", "").replace(Regex("""Version/\d+\.\d+\s"""), "")
        }
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

        if (!wasPlaying && videoPlaying) showPlayerBar(focus = true)

        if (d >= ContinueStore.MIN_DURATION) {
            pendingResume?.let { target ->
                if (abs(t - target) > 5) {
                    resumeAttempts++
                    cmd("seekTo", target)
                    toast(if (target < 1) "Starte von vorne" else "Setze fort bei ${formatTime(target)}")
                    if (resumeAttempts >= 4) pendingResume = null
                } else pendingResume = null
            }
            val now = SystemClock.uptimeMillis()
            if (pendingResume == null && (now - lastSave > 5000 || (wasPlaying && paused))) {
                lastSave = now
                val pageUrl = web.url ?: return
                ContinueStore.report(this, pageUrl, pageTitle(), t, d, tileColor)
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
            hidePlayerBar()
        }

        override fun onPageFinished(view: WebView, url: String) {
            loadBar.visibility = View.GONE
            injectFallback()
            if (mode != Mode.LINKS) js("window.__ovl && __ovl.showHl(false)")
            if (pendingResume != null) startAutoplay()
        }

        override fun shouldInterceptRequest(view: WebView, request: WebResourceRequest): WebResourceResponse? {
            val url = request.url
            val host = url.host
            if (request.isForMainFrame) topUrl = url.toString()
            if (!request.isForMainFrame && protectionOn() && AdBlock.isBlocked(host)) {
                return WebResourceResponse("text/plain", "utf-8", ByteArrayInputStream(ByteArray(0)))
            }
            val s = url.toString()
            if (MEDIA_RE.containsMatchIn(url.path ?: "") && !s.contains(".ts?")) {
                val referer = request.requestHeaders["Referer"] ?: ""
                ui.post { onMediaDetected(s, referer) }
            }
            return null
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

    private fun onBlocked(url: String, what: String) {
        if (url.isBlank() || url == "about:blank") { showChip("$what"); return }
        lastBlockedUrl = url
        showChip("$what: ${hostOf(url)}  ·  ☰ lang → trotzdem öffnen")
    }

    private fun onMediaDetected(url: String, referer: String) {
        if (AdBlock.isBlocked(Uri.parse(url).host)) return
        if (detected.size > 30) return
        if (!detected.containsKey(url)) detected[url] = MediaHit(url, referer.ifBlank { web.url ?: "" })
        if (!mediaChipShown) {
            mediaChipShown = true
            showChip("🎬 Video erkannt  ·  ☰ lang → „Video nativ abspielen“")
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
            ui.postDelayed({ if (!handled) { handled = true; showChip("Pop-up blockiert"); try { temp.destroy() } catch (e: Exception) { } } }, 3000)
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
                if (down && e.repeatCount == 0) {
                    cmd(when (code) { KeyEvent.KEYCODE_MEDIA_PLAY -> "play"; KeyEvent.KEYCODE_MEDIA_PAUSE -> "pause"; else -> "toggle" })
                    showPlayerBar(focus = true)
                }
                return true
            }
            KeyEvent.KEYCODE_MEDIA_REWIND, KeyEvent.KEYCODE_MEDIA_FAST_FORWARD -> {
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

    /** ☰ kurz = Modus wechseln, ☰ lang = Browser-Menü. */
    private fun handleMenuKey(e: KeyEvent) {
        if (e.action == KeyEvent.ACTION_DOWN) {
            if (e.repeatCount == 0) menuLongFired = false
            else if (!menuLongFired && (e.isLongPress || e.eventTime - e.downTime >= 550)) {
                menuLongFired = true
                showBrowserMenu()
            }
        } else if (e.action == KeyEvent.ACTION_UP) {
            if (!menuLongFired) cycleMode()
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

    private fun setMode(m: Mode) {
        mode = m
        when (m) {
            Mode.LINKS -> {
                cursor.visibility = View.GONE
                js("window.__ovl && __ovl.showHl(true)")
            }
            Mode.POINTER -> {
                if (cursorX == 0f && cursorY == 0f) { cursorX = web.width / 2f; cursorY = web.height / 2f }
                placeCursor()
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
        modeLabel.text = mode.label
        modeLabel.animate().alpha(1f).setDuration(150).start()
        ui.removeCallbacks(hideMode)
        ui.postDelayed(hideMode, 1800)
    }

    private fun showChip(msg: String) {
        chip.text = msg
        chip.animate().alpha(1f).setDuration(150).start()
        ui.removeCallbacks(hideChip)
        ui.postDelayed(hideChip, 3500)
    }

    /** Zurück: Leiste ausblenden → Vollbild verlassen → vorherige Seite → Startseite. */
    private fun handleBack() {
        when {
            playerBar.visibility == View.VISIBLE && playerBar.hasFocus() -> hidePlayerBar()
            customView != null -> chrome.onHideCustomView()
            maximized -> { maximized = false; cmd("unmaximize") }
            playerBar.visibility == View.VISIBLE -> hidePlayerBar()
            web.canGoBack() -> web.goBack()
            else -> finish()
        }
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
        maximized = !maximized
        cmd(if (maximized) "maximize" else "unmaximize")
        if (maximized) showChip("Vollbild · Zurück zum Verlassen")
    }

    private fun nextEpisode() {
        nextDone = false
        showChip("Suche nächste Folge …")
        js("window.__ovl ? __ovl.nextLocal() : false") { r ->
            if (r == "true") return@js
            cmd("next")
            ui.postDelayed({
                if (nextDone) return@postDelayed
                js("window.__ovl ? __ovl.nextByUrl() : false") { r2 ->
                    if (r2 != "true") showChip("Keine nächste Folge gefunden")
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
        if (videoDur > 0) {
            barTime.text = "${formatTime(videoPos)} / ${formatTime(videoDur)}  ·  ${formatRemaining(videoDur - videoPos)}"
            barProgress.progress = ((videoPos / videoDur) * 1000).toInt()
        } else {
            barTime.text = if (videoActive()) "LIVE" else ""
            barProgress.progress = 0
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
        if (hit == null) { showChip("Kein Video-Stream erkannt – Video zuerst auf der Seite starten"); return }
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
        val labels = hits.map { h ->
            val name = Uri.parse(h.url).lastPathSegment ?: h.url
            val dur = if (h.duration > 0) " · ${formatTime(h.duration)}" else ""
            "${hostOf(h.url)} · $name$dur"
        }
        Dialogs.list(this, "Erkannte Videos", labels) { i -> playNative(hits[i]) }
    }

    // ===================================================================== Menü

    private fun showBrowserMenu() {
        val items = ArrayList<Pair<String, () -> Unit>>()
        items.add("🔍  Schnellsuche auf dieser Seite" to { quickSearch() })
        items.add("🌐  Adresse eingeben" to {
            Dialogs.input(this, "Adresse", "Adresse oder Suchbegriff", web.url ?: "", url = true) { u -> if (u.isNotBlank()) web.loadUrl(normalizeUrl(u)) }
        })
        if (detected.isNotEmpty()) items.add("🎬  Video nativ abspielen (${detected.size} erkannt)" to { chooseMedia() })
        if (videoActive()) items.add("⏯  Player-Leiste zeigen" to { showPlayerBar(true) })
        lastBlockedUrl?.let { b -> items.add("⚠  Blockiert – trotzdem öffnen: ${hostOf(b)}" to { lastActivate = SystemClock.uptimeMillis(); web.loadUrl(b) }) }
        val site = hostOf(web.url)
        if (site.isNotBlank()) {
            val on = !AdBlock.isAllowed(this, site)
            items.add((if (on) "🛡  Schutz auf ${baseDomain(site)} ausschalten (falls Videos nicht starten)" else "🛡  Schutz auf ${baseDomain(site)} wieder einschalten") to {
                AdBlock.setAllowed(this, site, on)
                showChip(if (on) "Werbe-/Pop-up-Schutz für ${baseDomain(site)} aus" else "Schutz für ${baseDomain(site)} an")
                web.reload()
            })
        }
        items.add("🔗  Link-Modus" to { setMode(Mode.LINKS) })
        items.add("🖱  Zeiger-Modus" to { setMode(Mode.POINTER) })
        items.add("⌨  Normaler Modus" to { setMode(Mode.NORMAL) })
        items.add("➕  Als Kachel zur Startseite hinzufügen" to {
            val url = web.url ?: return@to
            val t = TileStore.newWeb(pageTitle().take(30), url)
            TileStore.add(this, t)
            toast("Kachel „${t.name}“ hinzugefügt")
        })
        items.add("↗  Im externen Browser öffnen" to { web.url?.let { Launcher.openExternal(this, it) } })
        items.add((if (desktopMode) "📱  Mobile Ansicht" else "🖥  Desktop-Ansicht") to {
            desktopMode = !desktopMode
            getSharedPreferences(PREFS, MODE_PRIVATE).edit().putBoolean("desktop", desktopMode).apply()
            applyUserAgent()
            web.reload()
        })
        items.add("⟳  Neu laden" to { web.reload() })
        items.add("⌂  Zur Startseite" to { finish() })
        Dialogs.list(this, pageTitle(), items.map { it.first }) { i -> items[i].second() }
    }

    private fun quickSearch() {
        val neutral = if (Voice.available(this)) "🎤 Sprache" to { if (!Voice.start(this, "Wonach suchen?")) toast("Spracheingabe nicht verfügbar") } else null
        Dialogs.input(this, "Schnellsuche auf ${hostOf(web.url)}", "Suchbegriff (Tastatur oder Mikrofon der Tastatur)", neutral = neutral) { term ->
            if (term.isNotBlank()) runSearch(term)
        }
    }

    private fun runSearch(term: String, second: Boolean = false) {
        js("window.__ovl ? __ovl.search(${JSONObject.quote(term)}, $second) : 'none'") { r ->
            val res = r?.trim('"') ?: "none"
            when {
                res == "ok" -> showChip("Suche nach „$term“ …")
                res == "opened" && !second -> ui.postDelayed({ runSearch(term, true) }, 700)
                else -> {
                    val host = hostOf(web.url)
                    showChip("Kein Suchfeld gefunden – suche über DuckDuckGo auf $host")
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
