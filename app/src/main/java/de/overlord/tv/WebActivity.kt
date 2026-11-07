package de.overlord.tv

import android.annotation.SuppressLint
import android.app.Activity
import android.graphics.Color
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.os.Bundle
import android.os.Message
import android.os.SystemClock
import android.util.TypedValue
import android.view.Gravity
import android.view.InputDevice
import android.view.KeyEvent
import android.view.MotionEvent
import android.view.View
import android.view.ViewGroup
import android.view.WindowManager
import android.webkit.CookieManager
import android.webkit.JavascriptInterface
import android.webkit.WebChromeClient
import android.webkit.WebResourceRequest
import android.webkit.WebResourceResponse
import android.webkit.WebSettings
import android.webkit.WebView
import android.webkit.WebViewClient
import android.widget.FrameLayout
import android.widget.ProgressBar
import android.widget.TextView
import androidx.webkit.WebViewCompat
import androidx.webkit.WebViewFeature
import org.json.JSONObject
import java.io.ByteArrayInputStream

/**
 * TV-Browser für Web-Kacheln – werbefrei und mit der Fernbedienung bedienbar.
 *
 * Steuerung:
 *  - Steuerkreuz: springt von Link zu Link (Link-Modus) bzw. bewegt den Cursor (Cursor-Modus)
 *  - OK: klicken
 *  - Menü (☰): Modus wechseln  Links → Cursor → Normal
 *  - Play/Pause: Video starten/pausieren
 *  - ⏪ / ⏩: 10 s spulen (läuft ein Video) bzw. seitenweise scrollen
 *  - Zurück: Vollbild verlassen / vorherige Seite / zurück zum Startbildschirm
 */
class WebActivity : Activity() {

    companion object {
        const val EXTRA_URL = "url"
        const val EXTRA_TITLE = "title"
        const val EXTRA_COLOR = "color"
        const val EXTRA_RESUME = "resume"
    }

    private enum class Mode { LINKS, CURSOR, NORMAL }

    private lateinit var root: FrameLayout
    private lateinit var webView: WebView
    private lateinit var cursor: View
    private lateinit var progress: ProgressBar
    private lateinit var hint: TextView
    private lateinit var history: HistoryStore

    private var customView: View? = null
    private var customCallback: WebChromeClient.CustomViewCallback? = null

    private var mode = Mode.LINKS
    private var cx = 0f
    private var cy = 0f
    private var downTime = 0L

    private var tileName = ""
    private var tileColor = 0
    private var injectScript = ""
    private var documentStartSupported = false

    // Werte, auf die die JS-Bridge (anderer Thread) zugreift
    @Volatile private var currentUrl: String = ""
    @Volatile private var currentTitle: String = ""
    @Volatile private var resumePosition: Double = 0.0
    @Volatile private var lastVideoReport = 0L

    private fun dp(v: Float) = TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_DIP, v, resources.displayMetrics)

    @SuppressLint("SetJavaScriptEnabled")
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        AdBlocker.init(this)
        history = HistoryStore(this)

        tileName = intent.getStringExtra(EXTRA_TITLE) ?: ""
        tileColor = intent.getIntExtra(EXTRA_COLOR, 0xFFE50914.toInt())
        resumePosition = intent.getDoubleExtra(EXTRA_RESUME, 0.0)
        injectScript = assets.open("inject.js").bufferedReader().use { it.readText() }

        root = FrameLayout(this)
        root.setBackgroundColor(Color.BLACK)

        webView = WebView(this)
        root.addView(webView, FrameLayout.LayoutParams(MATCH, MATCH))

        progress = ProgressBar(this, null, android.R.attr.progressBarStyleHorizontal).apply { max = 100 }
        root.addView(progress, FrameLayout.LayoutParams(MATCH, dp(4f).toInt(), Gravity.TOP))

        val size = dp(22f).toInt()
        cursor = View(this).apply {
            background = GradientDrawable().apply {
                shape = GradientDrawable.OVAL
                setColor(0xCCFFFFFF.toInt())
                setStroke(dp(3f).toInt(), 0xFF000000.toInt())
            }
            elevation = dp(16f)
        }
        root.addView(cursor, FrameLayout.LayoutParams(size, size))

        hint = TextView(this).apply {
            setTextColor(Color.WHITE)
            background = GradientDrawable().apply {
                cornerRadius = dp(24f)
                setColor(0xDD141414.toInt())
            }
            setPadding(dp(20f).toInt(), dp(10f).toInt(), dp(20f).toInt(), dp(10f).toInt())
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 15f)
            elevation = dp(16f)
        }
        root.addView(hint, FrameLayout.LayoutParams(WRAP, WRAP, Gravity.BOTTOM or Gravity.CENTER_HORIZONTAL).apply {
            bottomMargin = dp(28f).toInt()
        })

        setContentView(root)
        setupWebView()

        root.post {
            cx = root.width / 2f
            cy = root.height / 2f
            updateCursor()
        }
        showHint("◀▶▲▼ Links wählen · OK klicken · ☰ Modus · ⏯ Play/Pause")

        val url = intent.getStringExtra(EXTRA_URL) ?: "about:blank"
        currentUrl = url
        if (savedInstanceState != null) webView.restoreState(savedInstanceState) else webView.loadUrl(url)
    }

    // ---------------------------------------------------------------- WebView

    @SuppressLint("SetJavaScriptEnabled", "RequiresFeature")
    private fun setupWebView() {
        with(webView.settings) {
            javaScriptEnabled = true
            domStorageEnabled = true
            databaseEnabled = true
            mediaPlaybackRequiresUserGesture = false
            loadWithOverviewMode = true
            useWideViewPort = true
            builtInZoomControls = false
            javaScriptCanOpenWindowsAutomatically = false
            setSupportMultipleWindows(true) // neue Fenster landen in onCreateWindow und werden gefiltert
            mixedContentMode = WebSettings.MIXED_CONTENT_COMPATIBILITY_MODE
        }
        CookieManager.getInstance().setAcceptCookie(true)
        CookieManager.getInstance().setAcceptThirdPartyCookies(webView, true)

        webView.addJavascriptInterface(Bridge(), "OverlordBridge")

        // Skript in ALLE Frames (auch Player-iframes) schon vor dem Laden der Seite einschleusen
        documentStartSupported = WebViewFeature.isFeatureSupported(WebViewFeature.DOCUMENT_START_SCRIPT)
        if (documentStartSupported) {
            WebViewCompat.addDocumentStartJavaScript(webView, injectScript, setOf("*"))
        }

        webView.webViewClient = object : WebViewClient() {

            override fun shouldInterceptRequest(view: WebView, request: WebResourceRequest): WebResourceResponse? {
                return if (AdBlocker.isBlocked(request.url.toString())) emptyResponse() else null
            }

            override fun shouldOverrideUrlLoading(view: WebView, request: WebResourceRequest): Boolean {
                if (!request.isForMainFrame) return false
                val url = request.url.toString()
                val gesture = if (Build.VERSION.SDK_INT >= 24) request.hasGesture() else true
                val redirect = if (Build.VERSION.SDK_INT >= 24) request.isRedirect else false
                return blockNavigation(url, gesture, redirect)
            }

            @Deprecated("Deprecated in Java")
            override fun shouldOverrideUrlLoading(view: WebView, url: String): Boolean {
                return blockNavigation(url, gesture = true, redirect = false)
            }

            override fun onPageStarted(view: WebView, url: String, favicon: android.graphics.Bitmap?) {
                currentUrl = url
                if (!documentStartSupported) view.evaluateJavascript(injectScript, null)
            }

            override fun onPageFinished(view: WebView, url: String) {
                currentUrl = url
                if (!documentStartSupported) view.evaluateJavascript(injectScript, null)
            }
        }

        webView.webChromeClient = object : WebChromeClient() {
            override fun onProgressChanged(view: WebView, newProgress: Int) {
                progress.progress = newProgress
                progress.visibility = if (newProgress >= 100) View.GONE else View.VISIBLE
            }

            override fun onReceivedTitle(view: WebView, title: String?) {
                currentTitle = title ?: ""
            }

            override fun onCreateWindow(view: WebView, isDialog: Boolean, isUserGesture: Boolean, resultMsg: Message): Boolean {
                // Pop-up abfangen: Ziel-URL ermitteln und nur gleich-domainige, vom Nutzer
                // ausgelöste Links im Hauptfenster öffnen. Alles andere (Werbung) verwerfen.
                val temp = WebView(this@WebActivity)
                temp.webViewClient = object : WebViewClient() {
                    private var handled = false
                    private fun handle(url: String) {
                        if (handled) return
                        handled = true
                        val sameSite = AdBlocker.baseDomain(url) == AdBlocker.baseDomain(currentUrl)
                        if (isUserGesture && sameSite && !AdBlocker.isBlocked(url)) {
                            webView.loadUrl(url)
                        } else {
                            showHint("Pop-up blockiert")
                        }
                        temp.post { temp.destroy() }
                    }

                    override fun shouldOverrideUrlLoading(v: WebView, request: WebResourceRequest): Boolean {
                        handle(request.url.toString()); return true
                    }

                    @Deprecated("Deprecated in Java")
                    override fun shouldOverrideUrlLoading(v: WebView, url: String): Boolean {
                        handle(url); return true
                    }

                    override fun onPageStarted(v: WebView, url: String, favicon: android.graphics.Bitmap?) {
                        if (url == "about:blank") return
                        v.stopLoading(); handle(url)
                    }
                }
                val transport = resultMsg.obj as WebView.WebViewTransport
                transport.webView = temp
                resultMsg.sendToTarget()
                return true
            }

            override fun onShowCustomView(view: View, callback: CustomViewCallback) {
                if (customView != null) {
                    callback.onCustomViewHidden()
                    return
                }
                customView = view
                customCallback = callback
                root.addView(view, FrameLayout.LayoutParams(MATCH, MATCH))
                webView.visibility = View.INVISIBLE
                cursor.bringToFront()
                hint.bringToFront()
                updateCursor()
            }

            override fun onHideCustomView() {
                exitFullscreen()
            }
        }
    }

    private fun emptyResponse() = WebResourceResponse("text/plain", "utf-8", ByteArrayInputStream(ByteArray(0)))

    /** true = Navigation verhindern. */
    private fun blockNavigation(url: String, gesture: Boolean, redirect: Boolean): Boolean {
        if (!url.startsWith("http://") && !url.startsWith("https://")) return true // intent://, market:// …
        if (AdBlocker.isBlocked(url)) {
            showHint("Werbung blockiert")
            return true
        }
        // Weiterleitung auf eine fremde Domain ohne Klick = typische Werbe-Umleitung
        val foreign = AdBlocker.baseDomain(url) != AdBlocker.baseDomain(currentUrl)
        if (foreign && !gesture && !redirect) {
            showHint("Umleitung blockiert")
            return true
        }
        return false
    }

    private fun exitFullscreen() {
        val v = customView ?: return
        root.removeView(v)
        customView = null
        webView.visibility = View.VISIBLE
        customCallback?.onCustomViewHidden()
        customCallback = null
        updateCursor()
    }

    /** Wird aus inject.js aufgerufen (läuft auf einem Hintergrund-Thread). */
    inner class Bridge {
        @JavascriptInterface
        fun progress(position: Double, duration: Double) {
            lastVideoReport = SystemClock.uptimeMillis()
            if (duration <= 0 || position.isNaN()) return
            val title = currentTitle.ifBlank { tileName }
            history.updateProgress(currentUrl, title, tileName, tileColor, position, duration)
        }

        @JavascriptInterface
        fun resume(duration: Double): Double {
            var p = resumePosition
            if (p <= 0) p = history.find(currentUrl)?.position ?: 0.0
            resumePosition = 0.0
            return if (p > 10 && p < duration - 30) p - 3 else 0.0
        }
    }

    private val videoActive: Boolean
        get() = SystemClock.uptimeMillis() - lastVideoReport < 15000

    // ---------------------------------------------------------------- Cursor / Hinweise

    private fun updateCursor() {
        val show = mode == Mode.CURSOR || customView != null && mode != Mode.NORMAL
        cursor.visibility = if (show) View.VISIBLE else View.GONE
        cursor.translationX = cx - cursor.width / 2f
        cursor.translationY = cy - cursor.height / 2f
    }

    private val hideHint = Runnable { hint.visibility = View.GONE }

    private fun showHint(text: String) {
        runOnUiThread {
            hint.text = text
            hint.visibility = View.VISIBLE
            hint.removeCallbacks(hideHint)
            hint.postDelayed(hideHint, 3000)
        }
    }

    private fun moveCursor(dx: Float, dy: Float) {
        val w = root.width.toFloat()
        val h = root.height.toFloat()
        val edge = dp(4f)
        var nx = cx + dx
        var ny = cy + dy
        val canScroll = customView == null
        if (nx < edge) { if (canScroll) webView.scrollBy((nx - edge).toInt(), 0); nx = edge }
        if (nx > w - edge) { if (canScroll) webView.scrollBy((nx - (w - edge)).toInt(), 0); nx = w - edge }
        if (ny < edge) { if (canScroll) webView.scrollBy(0, (ny - edge).toInt()); ny = edge }
        if (ny > h - edge) { if (canScroll) webView.scrollBy(0, (ny - (h - edge)).toInt()); ny = h - edge }
        cx = nx
        cy = ny
        updateCursor()
    }

    private fun touchAt(x: Float, y: Float, action: Int) {
        val target = customView ?: webView
        val now = SystemClock.uptimeMillis()
        if (action == MotionEvent.ACTION_DOWN) downTime = now
        val ev = MotionEvent.obtain(downTime, now, action, x, y, 0)
        ev.source = InputDevice.SOURCE_TOUCHSCREEN
        target.dispatchTouchEvent(ev)
        ev.recycle()
    }

    private fun tap(x: Float, y: Float) {
        touchAt(x, y, MotionEvent.ACTION_DOWN)
        root.postDelayed({ touchAt(x, y, MotionEvent.ACTION_UP) }, 60)
    }

    private fun js(code: String, cb: ((String) -> Unit)? = null) {
        webView.evaluateJavascript(code) { r -> cb?.invoke(r ?: "null") }
    }

    private fun linkClick() {
        js("window.__ovFocusPoint ? window.__ovFocusPoint() : null") { r ->
            if (r == "null") {
                showHint("Erst mit dem Steuerkreuz einen Link wählen")
                return@js
            }
            try {
                val o = JSONObject(r)
                tap(o.getDouble("x").toFloat(), o.getDouble("y").toFloat())
            } catch (_: Exception) {
            }
        }
    }

    private fun cycleMode() {
        mode = when (mode) {
            Mode.LINKS -> Mode.CURSOR
            Mode.CURSOR -> Mode.NORMAL
            Mode.NORMAL -> Mode.LINKS
        }
        if (mode != Mode.LINKS) js("window.__ovClearFocus && window.__ovClearFocus()")
        if (mode == Mode.NORMAL) webView.requestFocus()
        updateCursor()
        showHint(
            when (mode) {
                Mode.LINKS -> "Link-Modus: Steuerkreuz springt zwischen Links"
                Mode.CURSOR -> "Cursor-Modus: Steuerkreuz bewegt den Zeiger"
                Mode.NORMAL -> "Normaler Modus: Tasten gehen direkt an die Webseite"
            }
        )
    }

    // ---------------------------------------------------------------- Tasten

    override fun dispatchKeyEvent(event: KeyEvent): Boolean {
        val code = event.keyCode
        val down = event.action == KeyEvent.ACTION_DOWN

        when (code) {
            KeyEvent.KEYCODE_MENU -> {
                if (!down) cycleMode()
                return true
            }
            KeyEvent.KEYCODE_MEDIA_PLAY_PAUSE, KeyEvent.KEYCODE_MEDIA_PLAY, KeyEvent.KEYCODE_MEDIA_PAUSE -> {
                if (down) js("window.__ovCmd && window.__ovCmd('toggle')")
                return true
            }
            KeyEvent.KEYCODE_MEDIA_REWIND, KeyEvent.KEYCODE_MEDIA_FAST_FORWARD -> {
                if (down) {
                    val back = code == KeyEvent.KEYCODE_MEDIA_REWIND
                    if (videoActive || customView != null) {
                        js("window.__ovCmd && window.__ovCmd('${if (back) "back" else "fwd"}')")
                        showHint(if (back) "⏪ 10 s" else "10 s ⏩")
                    } else {
                        val page = (root.height * 0.8f).toInt()
                        webView.scrollBy(0, if (back) -page else page)
                    }
                }
                return true
            }
        }

        // Im Vollbild-Video: Cursor (für Player-Bedienelemente)
        val effective = if (customView != null && mode == Mode.LINKS) Mode.CURSOR else mode

        if (effective == Mode.LINKS) {
            val dir = when (code) {
                KeyEvent.KEYCODE_DPAD_LEFT -> "left"
                KeyEvent.KEYCODE_DPAD_RIGHT -> "right"
                KeyEvent.KEYCODE_DPAD_UP -> "up"
                KeyEvent.KEYCODE_DPAD_DOWN -> "down"
                else -> null
            }
            if (dir != null) {
                if (down) js("window.__ovNav ? window.__ovNav('$dir') : 'none'") { r ->
                    // Skript noch nicht geladen -> wenigstens scrollen
                    if (r == "null" || r == "\"none\"") {
                        val step = (root.height * 0.5f).toInt()
                        when (dir) {
                            "up" -> webView.scrollBy(0, -step)
                            "down" -> webView.scrollBy(0, step)
                        }
                    }
                }
                return true
            }
            if (code == KeyEvent.KEYCODE_DPAD_CENTER || code == KeyEvent.KEYCODE_ENTER || code == KeyEvent.KEYCODE_NUMPAD_ENTER) {
                if (!down && (event.flags and KeyEvent.FLAG_CANCELED) == 0) linkClick()
                return true
            }
        }

        if (effective == Mode.CURSOR) {
            val step = dp(12f) * (1f + (event.repeatCount.coerceAtMost(20) * 0.35f))
            when (code) {
                KeyEvent.KEYCODE_DPAD_LEFT -> { if (down) moveCursor(-step, 0f); return true }
                KeyEvent.KEYCODE_DPAD_RIGHT -> { if (down) moveCursor(step, 0f); return true }
                KeyEvent.KEYCODE_DPAD_UP -> { if (down) moveCursor(0f, -step); return true }
                KeyEvent.KEYCODE_DPAD_DOWN -> { if (down) moveCursor(0f, step); return true }
                KeyEvent.KEYCODE_DPAD_CENTER, KeyEvent.KEYCODE_ENTER, KeyEvent.KEYCODE_NUMPAD_ENTER -> {
                    if (down && event.repeatCount == 0) touchAt(cx, cy, MotionEvent.ACTION_DOWN)
                    if (!down) touchAt(cx, cy, MotionEvent.ACTION_UP)
                    return true
                }
            }
        }
        return super.dispatchKeyEvent(event)
    }

    @Deprecated("Deprecated in Java")
    override fun onBackPressed() {
        when {
            customView != null -> exitFullscreen()
            webView.canGoBack() -> webView.goBack()
            else -> @Suppress("DEPRECATION") super.onBackPressed()
        }
    }

    override fun onSaveInstanceState(outState: Bundle) {
        super.onSaveInstanceState(outState)
        webView.saveState(outState)
    }

    override fun onPause() {
        super.onPause()
        // Video pausieren (meldet dabei den letzten Fortschritt) und WebView anhalten
        js("window.__ovCmd && window.__ovCmd('pause')")
        webView.onPause()
    }

    override fun onResume() {
        super.onResume()
        webView.onResume()
    }

    override fun onDestroy() {
        (webView.parent as? ViewGroup)?.removeView(webView)
        webView.destroy()
        super.onDestroy()
    }
}

private const val MATCH = ViewGroup.LayoutParams.MATCH_PARENT
private const val WRAP = ViewGroup.LayoutParams.WRAP_CONTENT
