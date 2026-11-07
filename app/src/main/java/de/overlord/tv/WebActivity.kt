package de.overlord.tv

import android.annotation.SuppressLint
import android.app.Activity
import android.graphics.Color
import android.graphics.drawable.GradientDrawable
import android.os.Bundle
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
import android.webkit.WebChromeClient
import android.webkit.WebResourceRequest
import android.webkit.WebSettings
import android.webkit.WebView
import android.webkit.WebViewClient
import android.widget.FrameLayout
import android.widget.ProgressBar
import android.widget.TextView

/**
 * Einfacher TV-Browser für Web-Kacheln.
 *
 * Steuerung mit der Fire-TV-Fernbedienung:
 *  - Steuerkreuz bewegt einen Maus-Cursor (am Rand wird die Seite gescrollt)
 *  - OK klickt an der Cursor-Position
 *  - Menü-Taste schaltet zwischen Cursor- und normaler Fokus-Navigation um
 *  - Zurück geht eine Seite zurück, verlässt Vollbild oder schließt den Browser
 *  - Zurückspulen / Vorspulen scrollt seitenweise hoch/runter
 */
class WebActivity : Activity() {

    companion object {
        const val EXTRA_URL = "url"
        const val EXTRA_TITLE = "title"
    }

    private lateinit var root: FrameLayout
    private lateinit var webView: WebView
    private lateinit var cursor: View
    private lateinit var progress: ProgressBar
    private lateinit var hint: TextView

    private var customView: View? = null
    private var customCallback: WebChromeClient.CustomViewCallback? = null

    private var cursorMode = true
    private var cx = 0f
    private var cy = 0f
    private var downTime = 0L

    private fun dp(v: Float) = TypedValue.applyDimension(
        TypedValue.COMPLEX_UNIT_DIP, v, resources.displayMetrics
    )

    @SuppressLint("SetJavaScriptEnabled")
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)

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
            setBackgroundColor(0xAA000000.toInt())
            setPadding(dp(16f).toInt(), dp(8f).toInt(), dp(16f).toInt(), dp(8f).toInt())
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 14f)
            elevation = dp(16f)
        }
        root.addView(hint, FrameLayout.LayoutParams(WRAP, WRAP, Gravity.BOTTOM or Gravity.CENTER_HORIZONTAL).apply {
            bottomMargin = dp(24f).toInt()
        })

        setContentView(root)

        setupWebView()

        root.post {
            cx = root.width / 2f
            cy = root.height / 2f
            updateCursor()
        }
        showHint("Steuerkreuz = Cursor · OK = Klick · Menü = Cursor an/aus")

        val url = intent.getStringExtra(EXTRA_URL) ?: "about:blank"
        if (savedInstanceState != null) webView.restoreState(savedInstanceState) else webView.loadUrl(url)
    }

    @SuppressLint("SetJavaScriptEnabled")
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
            setSupportMultipleWindows(false) // target=_blank im selben Fenster, Pop-ups unterdrückt
            mixedContentMode = WebSettings.MIXED_CONTENT_COMPATIBILITY_MODE
        }
        CookieManager.getInstance().setAcceptCookie(true)
        CookieManager.getInstance().setAcceptThirdPartyCookies(webView, true)

        webView.webViewClient = object : WebViewClient() {
            override fun shouldOverrideUrlLoading(view: WebView, request: WebResourceRequest): Boolean {
                val scheme = request.url.scheme ?: return true
                // Nur http(s) im Browser laden; intent://, market:// usw. blockieren (meist Werbung)
                return scheme != "http" && scheme != "https"
            }

            @Deprecated("Deprecated in Java")
            override fun shouldOverrideUrlLoading(view: WebView, url: String): Boolean {
                return !(url.startsWith("http://") || url.startsWith("https://"))
            }
        }

        webView.webChromeClient = object : WebChromeClient() {
            override fun onProgressChanged(view: WebView, newProgress: Int) {
                progress.progress = newProgress
                progress.visibility = if (newProgress >= 100) View.GONE else View.VISIBLE
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
            }

            override fun onHideCustomView() {
                exitFullscreen()
            }
        }
    }

    private fun exitFullscreen() {
        val v = customView ?: return
        root.removeView(v)
        customView = null
        webView.visibility = View.VISIBLE
        customCallback?.onCustomViewHidden()
        customCallback = null
    }

    // ---------------------------------------------------------------- Cursor

    private fun updateCursor() {
        cursor.visibility = if (cursorMode) View.VISIBLE else View.GONE
        cursor.translationX = cx - cursor.width / 2f
        cursor.translationY = cy - cursor.height / 2f
    }

    private fun showHint(text: String) {
        hint.text = text
        hint.visibility = View.VISIBLE
        hint.removeCallbacks(hideHint)
        hint.postDelayed(hideHint, 3500)
    }

    private val hideHint = Runnable { hint.visibility = View.GONE }

    private fun moveCursor(dx: Float, dy: Float) {
        val w = root.width.toFloat()
        val h = root.height.toFloat()
        var nx = cx + dx
        var ny = cy + dy
        val scrollTarget = customView ?: webView
        val edge = dp(4f)
        if (nx < edge) { if (customView == null) scrollTarget.scrollBy(nx.toInt() - edge.toInt(), 0); nx = edge }
        if (nx > w - edge) { if (customView == null) scrollTarget.scrollBy((nx - (w - edge)).toInt(), 0); nx = w - edge }
        if (ny < edge) { if (customView == null) scrollTarget.scrollBy(0, ny.toInt() - edge.toInt()); ny = edge }
        if (ny > h - edge) { if (customView == null) scrollTarget.scrollBy(0, (ny - (h - edge)).toInt()); ny = h - edge }
        cx = nx
        cy = ny
        updateCursor()
    }

    private fun touch(action: Int) {
        val target = customView ?: webView
        val now = SystemClock.uptimeMillis()
        if (action == MotionEvent.ACTION_DOWN) downTime = now
        val ev = MotionEvent.obtain(downTime, now, action, cx, cy, 0)
        ev.source = InputDevice.SOURCE_TOUCHSCREEN
        target.dispatchTouchEvent(ev)
        ev.recycle()
    }

    override fun dispatchKeyEvent(event: KeyEvent): Boolean {
        val code = event.keyCode
        val down = event.action == KeyEvent.ACTION_DOWN

        if (code == KeyEvent.KEYCODE_MENU) {
            if (!down) {
                cursorMode = !cursorMode
                updateCursor()
                if (!cursorMode) webView.requestFocus()
                showHint(if (cursorMode) "Cursor-Modus an" else "Cursor-Modus aus – Steuerkreuz springt zwischen Links")
            }
            return true
        }

        if (code == KeyEvent.KEYCODE_MEDIA_REWIND || code == KeyEvent.KEYCODE_MEDIA_FAST_FORWARD) {
            if (down && customView == null) {
                val page = (root.height * 0.8f).toInt()
                webView.scrollBy(0, if (code == KeyEvent.KEYCODE_MEDIA_REWIND) -page else page)
            }
            return true
        }

        if (cursorMode) {
            // Beschleunigung, wenn die Taste gehalten wird
            val step = dp(12f) * (1f + (event.repeatCount.coerceAtMost(20) * 0.35f))
            when (code) {
                KeyEvent.KEYCODE_DPAD_LEFT -> { if (down) moveCursor(-step, 0f); return true }
                KeyEvent.KEYCODE_DPAD_RIGHT -> { if (down) moveCursor(step, 0f); return true }
                KeyEvent.KEYCODE_DPAD_UP -> { if (down) moveCursor(0f, -step); return true }
                KeyEvent.KEYCODE_DPAD_DOWN -> { if (down) moveCursor(0f, step); return true }
                KeyEvent.KEYCODE_DPAD_CENTER, KeyEvent.KEYCODE_ENTER, KeyEvent.KEYCODE_NUMPAD_ENTER -> {
                    if (down && event.repeatCount == 0) touch(MotionEvent.ACTION_DOWN)
                    if (!down) touch(MotionEvent.ACTION_UP)
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
