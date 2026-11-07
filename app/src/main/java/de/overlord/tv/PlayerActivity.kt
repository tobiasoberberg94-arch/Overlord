package de.overlord.tv

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.media.MediaPlayer
import android.net.Uri
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.view.Gravity
import android.view.KeyEvent
import android.view.View
import android.view.WindowManager
import android.widget.FrameLayout
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.ProgressBar
import android.widget.TextView
import android.widget.VideoView
import java.util.concurrent.Executors

/**
 * Eigener, schlanker Player (Android-VideoView, keine Zusatzbibliothek).
 * Spielt erkannte Web-Streams (HLS/MP4) und Jellyfin-Medien ab,
 * speichert den Fortschritt und startet bei Jellyfin automatisch die nächste Folge.
 */
class PlayerActivity : Activity() {

    companion object {
        private const val K_KIND = "kind"
        private const val K_URL = "url"
        private const val K_TITLE = "title"
        private const val K_PAGE = "page"
        private const val K_REFERER = "referer"
        private const val K_UA = "ua"
        private const val K_COOKIES = "cookies"
        private const val K_START = "start"
        private const val K_COLOR = "color"
        private const val K_JF_ID = "jfId"
        private const val K_FROM_START = "fromStart"

        fun startWeb(
            ctx: Context, mediaUrl: String, title: String, pageUrl: String, referer: String,
            startSec: Double, color: Int, userAgent: String = "", cookies: String = "",
        ) {
            ctx.startActivity(Intent(ctx, PlayerActivity::class.java)
                .putExtra(K_KIND, "web").putExtra(K_URL, mediaUrl).putExtra(K_TITLE, title)
                .putExtra(K_PAGE, pageUrl).putExtra(K_REFERER, referer).putExtra(K_UA, userAgent)
                .putExtra(K_COOKIES, cookies).putExtra(K_START, startSec).putExtra(K_COLOR, color))
        }

        fun startJellyfin(ctx: Context, itemId: String, fromStart: Boolean) {
            ctx.startActivity(Intent(ctx, PlayerActivity::class.java)
                .putExtra(K_KIND, "jellyfin").putExtra(K_JF_ID, itemId).putExtra(K_FROM_START, fromStart))
        }
    }

    private val ui = Handler(Looper.getMainLooper())
    private val io = Executors.newSingleThreadExecutor()

    private lateinit var video: VideoView
    private lateinit var overlay: LinearLayout
    private lateinit var title: TextView
    private lateinit var info: TextView
    private lateinit var timeLeft: TextView
    private lateinit var timeRight: TextView
    private lateinit var track: FrameLayout
    private lateinit var fill: View
    private lateinit var center: LinearLayout
    private lateinit var centerIcon: ImageView
    private lateinit var centerText: TextView
    private lateinit var spinner: ProgressBar
    private lateinit var nextBox: TextView

    private var kind = "web"
    private var mediaUrl = ""
    private var pageUrl = ""
    private var referer = ""
    private var color = Brand.ACCENT
    private var headers = HashMap<String, String>()
    private var startMs = 0

    private var jfItem: Jellyfin.Item? = null
    private var jfMethod = "DirectPlay"
    private var triedHls = false
    private var nextItem: Jellyfin.Item? = null
    private var countdown = 0

    private var prepared = false
    private var pendingSeekMs: Int? = null
    private var lastSave = 0L

    private val hideOverlay = Runnable { overlay.animate().alpha(0f).setDuration(300).start(); center.animate().alpha(0f).setDuration(300).start() }
    private val doSeek = Runnable {
        pendingSeekMs?.let { if (prepared) video.seekTo(it) }
        pendingSeekMs = null
    }
    private val ticker = object : Runnable {
        override fun run() {
            updateUi()
            val now = System.currentTimeMillis()
            if (prepared && now - lastSave > 10_000) { lastSave = now; saveProgress(video.isPlaying.not()) }
            ui.postDelayed(this, 1000)
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        buildUi()
        kind = intent.getStringExtra(K_KIND) ?: "web"
        if (kind == "jellyfin") {
            val id = intent.getStringExtra(K_JF_ID) ?: run { finish(); return }
            loadJellyfin(id, intent.getBooleanExtra(K_FROM_START, false))
        } else {
            mediaUrl = intent.getStringExtra(K_URL) ?: run { finish(); return }
            pageUrl = intent.getStringExtra(K_PAGE) ?: ""
            referer = intent.getStringExtra(K_REFERER) ?: ""
            color = intent.getIntExtra(K_COLOR, Brand.ACCENT)
            title.text = intent.getStringExtra(K_TITLE) ?: hostOf(pageUrl)
            info.text = ("NATIVER PLAYER · " + hostOf(pageUrl.ifBlank { mediaUrl })).uppercase()
            intent.getStringExtra(K_UA)?.takeIf { it.isNotBlank() }?.let { headers["User-Agent"] = it }
            intent.getStringExtra(K_COOKIES)?.takeIf { it.isNotBlank() }?.let { headers["Cookie"] = it }
            if (referer.isNotBlank()) {
                headers["Referer"] = referer
                Uri.parse(referer).let { u -> if (u.scheme != null && u.host != null) headers["Origin"] = "${u.scheme}://${u.host}" }
            }
            startMs = (intent.getDoubleExtra(K_START, 0.0) * 1000).toInt()
            play(mediaUrl)
        }
        ui.post(ticker)
    }

    private fun buildUi() {
        val root = FrameLayout(this).apply { setBackgroundColor(0xFF000000.toInt()) }
        video = VideoView(this)
        root.addView(video, FrameLayout.LayoutParams(-1, -1, Gravity.CENTER))

        spinner = ProgressBar(this).apply { isIndeterminate = true }
        root.addView(spinner, FrameLayout.LayoutParams(dp(64), dp(64), Gravity.CENTER))

        center = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER_HORIZONTAL
            alpha = 0f
        }
        val circle = FrameLayout(this).apply { background = GradientDrawable().apply { shape = GradientDrawable.OVAL; setColor(0xB3000000.toInt()) } }
        centerIcon = icon(R.drawable.ic_play)
        circle.addView(centerIcon, FrameLayout.LayoutParams(dp(48), dp(48), Gravity.CENTER))
        center.addView(circle, LinearLayout.LayoutParams(dp(104), dp(104)))
        centerText = label("", 22f, Fonts.bold).apply {
            setPadding(dp(16), dp(6), dp(16), dp(6))
            background = rounded(0xB3000000.toInt(), dpf(18f))
        }
        center.addView(centerText, LinearLayout.LayoutParams(-2, -2).apply { topMargin = dp(14) })
        root.addView(center, FrameLayout.LayoutParams(-2, -2, Gravity.CENTER))

        overlay = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(56), dp(80), dp(56), dp(34))
            background = GradientDrawable(GradientDrawable.Orientation.BOTTOM_TOP, intArrayOf(0xF2000000.toInt(), 0xA0000000.toInt(), 0x00000000))
        }
        info = label("", 13f, Fonts.bold, Brand.ACCENT2).apply { letterSpacing = 0.18f }
        title = label("", 30f, Fonts.bold)
        overlay.addView(info)
        overlay.addView(title, LinearLayout.LayoutParams(-1, -2).apply { topMargin = dp(6) })
        val prog = LinearLayout(this).apply { orientation = LinearLayout.HORIZONTAL; gravity = Gravity.CENTER_VERTICAL }
        timeLeft = label("0:00", 15f, Fonts.semibold)
        timeRight = label("", 15f, Fonts.semibold, Brand.TEXT_DIM).apply { gravity = Gravity.END }
        track = FrameLayout(this).apply { background = rounded(0x40FFFFFF, dpf(4f)) }
        fill = View(this).apply { background = rounded(Brand.ACCENT2, dpf(4f)) }
        track.addView(fill, FrameLayout.LayoutParams(0, -1))
        prog.addView(timeLeft, LinearLayout.LayoutParams(dp(90), -2))
        prog.addView(track, LinearLayout.LayoutParams(0, dp(7), 1f))
        prog.addView(timeRight, LinearLayout.LayoutParams(dp(90), -2))
        overlay.addView(prog, LinearLayout.LayoutParams(-1, -2).apply { topMargin = dp(18) })
        val hints = LinearLayout(this).apply { orientation = LinearLayout.HORIZONTAL }
        hints.addView(Tv.keyHint(this, "OK", "Pause"))
        hints.addView(Tv.keyHint(this, "◀ ▶", "spulen (halten = schneller)"), LinearLayout.LayoutParams(-2, -2).apply { leftMargin = dp(22) })
        hints.addView(Tv.keyHint(this, "Zurück", "beenden"), LinearLayout.LayoutParams(-2, -2).apply { leftMargin = dp(22) })
        overlay.addView(hints, LinearLayout.LayoutParams(-2, -2).apply { topMargin = dp(18) })
        root.addView(overlay, FrameLayout.LayoutParams(-1, -2, Gravity.BOTTOM))

        nextBox = label("", 18f, Fonts.semibold, lines = 4).apply {
            setPadding(dp(26), dp(20), dp(26), dp(20))
            setLineSpacing(0f, 1.25f)
            background = rounded(0xF2161622.toInt(), dpf(20f), dp(1), withAlpha(Brand.ACCENT, 0xAA))
            elevation = dpf(30f)
            visibility = View.GONE
        }
        root.addView(nextBox, FrameLayout.LayoutParams(-2, -2, Gravity.END or Gravity.BOTTOM).apply { rightMargin = dp(48); bottomMargin = dp(150) })

        setContentView(root)

        video.setOnPreparedListener { mp ->
            prepared = true
            spinner.visibility = View.GONE
            mp.setOnInfoListener { _, what, _ ->
                when (what) {
                    MediaPlayer.MEDIA_INFO_BUFFERING_START -> spinner.visibility = View.VISIBLE
                    MediaPlayer.MEDIA_INFO_BUFFERING_END, MediaPlayer.MEDIA_INFO_VIDEO_RENDERING_START -> spinner.visibility = View.GONE
                }
                false
            }
            if (startMs > 0) video.seekTo(startMs)
            video.start()
            showOverlay()
            jfItem?.let { item -> io.execute { Jellyfin.reportStart(item.id, startMs / 1000.0, jfMethod) } }
        }
        video.setOnCompletionListener { onCompleted() }
        video.setOnErrorListener { _, what, extra -> onError(what, extra); true }
    }

    private fun play(url: String) {
        prepared = false
        spinner.visibility = View.VISIBLE
        nextBox.visibility = View.GONE
        video.setVideoURI(Uri.parse(url), headers)
    }

    // ------------------------------------------------------------------ Jellyfin

    private fun loadJellyfin(id: String, fromStart: Boolean) {
        spinner.visibility = View.VISIBLE
        io.execute {
            val item = try { Jellyfin.item(id) } catch (e: Exception) { null }
            ui.post {
                if (item == null) { toast("Titel konnte nicht geladen werden"); finish(); return@post }
                startJellyfinItem(item, fromStart)
            }
        }
    }

    private fun startJellyfinItem(item: Jellyfin.Item, fromStart: Boolean) {
        jfItem = item
        nextItem = null
        triedHls = false
        jfMethod = "DirectPlay"
        title.text = item.displayTitle
        info.text = ("JELLYFIN · " + item.infoLine).uppercase()
        startMs = if (fromStart) 0 else (item.positionSec * 1000).toInt()
        play(Jellyfin.directUrl(item.id))
    }

    // ------------------------------------------------------------------ Ereignisse

    private fun onError(what: Int, extra: Int) {
        val item = jfItem
        val pos = if (prepared) video.currentPosition else startMs
        if (item != null && !triedHls) {
            // Direktwiedergabe nicht möglich → HLS (Server kopiert/transkodiert)
            triedHls = true
            jfMethod = "Transcode"
            startMs = pos
            toast("Format nicht direkt abspielbar – nutze Server-Stream")
            play(Jellyfin.hlsUrl(item.id))
            return
        }
        if (kind == "web" && pageUrl.isNotBlank()) {
            toast("Stream nicht abspielbar – öffne die Webseite")
            BrowserActivity.open(this, pageUrl, title.text.toString(), color, resume = pos / 1000.0)
            finish()
            return
        }
        toast("Wiedergabefehler ($what/$extra)")
        finish()
    }

    private fun onCompleted() {
        val item = jfItem
        if (item == null) {
            if (pageUrl.isNotBlank()) ContinueStore.remove(this, ContinueStore.keyFor(pageUrl))
            finish()
            return
        }
        val dur = video.duration / 1000.0
        io.execute {
            Jellyfin.reportStopped(item.id, dur, jfMethod)
            val next = try { Jellyfin.nextEpisode(item) } catch (e: Exception) { null }
            ui.post {
                if (next == null) { toast("Fertig angesehen"); finish() } else startCountdown(next)
            }
        }
    }

    private val countdownTick = object : Runnable {
        override fun run() {
            val n = nextItem ?: return
            if (countdown <= 0) { startJellyfinItem(n, true); return }
            nextBox.text = "Nächste Folge in $countdown s\n${n.displayTitle}\nOK: jetzt  ·  Zurück: beenden"
            countdown--
            ui.postDelayed(this, 1000)
        }
    }

    private fun startCountdown(next: Jellyfin.Item) {
        nextItem = next
        countdown = 10
        nextBox.visibility = View.VISIBLE
        ui.post(countdownTick)
    }

    private fun saveProgress(paused: Boolean) {
        if (!prepared) return
        val pos = video.currentPosition / 1000.0
        val dur = video.duration / 1000.0
        val item = jfItem
        if (item != null) {
            io.execute { Jellyfin.reportProgress(item.id, pos, paused, jfMethod) }
        } else if (pageUrl.isNotBlank() && dur > 0) {
            ContinueStore.report(this, pageUrl, title.text.toString(), pos, dur, color, mediaUrl, referer)
        }
    }

    // ------------------------------------------------------------------ Anzeige

    private fun updateUi() {
        if (!prepared) return
        val dur = video.duration
        val pos = pendingSeekMs ?: video.currentPosition
        if (dur > 0) {
            val frac = pos.toDouble() / dur
            track.post { fill.layoutParams = FrameLayout.LayoutParams((track.width * frac).toInt(), -1) }
            timeLeft.text = formatTime(pos / 1000.0)
            timeRight.text = "−" + formatTime((dur - pos) / 1000.0)
        } else {
            timeLeft.text = "LIVE"
            timeRight.text = formatTime(pos / 1000.0)
        }
    }

    private fun showOverlay(text: String? = null, iconRes: Int = R.drawable.ic_play) {
        updateUi()
        overlay.animate().alpha(1f).setDuration(150).start()
        if (text != null) {
            centerIcon.setImageResource(iconRes)
            centerText.text = text
            centerText.visibility = if (text.isEmpty()) View.GONE else View.VISIBLE
            center.animate().alpha(1f).setDuration(120).start()
        }
        ui.removeCallbacks(hideOverlay)
        ui.postDelayed(hideOverlay, if (video.isPlaying) 3500 else 8000)
    }

    private fun togglePlay() {
        if (!prepared) return
        if (video.isPlaying) { video.pause(); showOverlay("", R.drawable.ic_pause); saveProgress(true) } else { video.start(); showOverlay("", R.drawable.ic_play) }
    }

    private fun seekBy(sec: Int) {
        if (!prepared) return
        val dur = video.duration
        val base = pendingSeekMs ?: video.currentPosition
        var target = base + sec * 1000
        target = if (dur > 0) target.coerceIn(0, dur - 1000) else target.coerceAtLeast(0)
        pendingSeekMs = target
        showOverlay(formatTime(target / 1000.0), if (sec < 0) R.drawable.ic_rewind else R.drawable.ic_forward)
        ui.removeCallbacks(doSeek)
        ui.postDelayed(doSeek, 650)
    }

    override fun dispatchKeyEvent(e: KeyEvent): Boolean {
        val down = e.action == KeyEvent.ACTION_DOWN
        if (nextBox.visibility == View.VISIBLE && nextItem != null) {
            when (e.keyCode) {
                KeyEvent.KEYCODE_DPAD_CENTER, KeyEvent.KEYCODE_ENTER, KeyEvent.KEYCODE_MEDIA_PLAY_PAUSE, KeyEvent.KEYCODE_MEDIA_PLAY -> {
                    if (!down) { ui.removeCallbacks(countdownTick); nextItem?.let { startJellyfinItem(it, true) } }
                    return true
                }
                KeyEvent.KEYCODE_BACK -> { if (!down) { ui.removeCallbacks(countdownTick); finish() }; return true }
            }
        }
        when (e.keyCode) {
            KeyEvent.KEYCODE_DPAD_CENTER, KeyEvent.KEYCODE_ENTER, KeyEvent.KEYCODE_MEDIA_PLAY_PAUSE,
            KeyEvent.KEYCODE_SPACE, KeyEvent.KEYCODE_HEADSETHOOK -> {
                if (down && e.repeatCount == 0) togglePlay(); return true
            }
            KeyEvent.KEYCODE_MEDIA_PLAY -> { if (down && prepared) { video.start(); showOverlay("", R.drawable.ic_play) }; return true }
            KeyEvent.KEYCODE_MEDIA_PAUSE -> { if (down && prepared) { video.pause(); showOverlay("", R.drawable.ic_pause) }; return true }
            KeyEvent.KEYCODE_DPAD_LEFT, KeyEvent.KEYCODE_MEDIA_REWIND,
            KeyEvent.KEYCODE_DPAD_RIGHT, KeyEvent.KEYCODE_MEDIA_FAST_FORWARD -> {
                if (down) {
                    val step = when { e.repeatCount > 10 -> 60; e.repeatCount > 3 -> 30; else -> 10 }
                    val back = e.keyCode == KeyEvent.KEYCODE_DPAD_LEFT || e.keyCode == KeyEvent.KEYCODE_MEDIA_REWIND
                    seekBy(if (back) -step else step)
                }
                return true
            }
            KeyEvent.KEYCODE_DPAD_UP, KeyEvent.KEYCODE_DPAD_DOWN, KeyEvent.KEYCODE_MENU -> { if (down) showOverlay(); return true }
            KeyEvent.KEYCODE_MEDIA_NEXT -> {
                if (down && jfItem != null) {
                    val item = jfItem!!
                    io.execute { val n = try { Jellyfin.nextEpisode(item) } catch (ex: Exception) { null }; ui.post { if (n != null) startJellyfinItem(n, true) else toast("Keine weitere Folge") } }
                }
                return true
            }
            KeyEvent.KEYCODE_BACK -> { if (!down) finish(); return true }
        }
        return super.dispatchKeyEvent(e)
    }

    override fun onPause() {
        super.onPause()
        if (prepared) {
            saveProgress(true)
            if (isFinishing) {
                val item = jfItem
                val pos = video.currentPosition / 1000.0
                if (item != null) io.execute { Jellyfin.reportStopped(item.id, pos, jfMethod) }
            }
            video.pause()
        }
    }

    override fun onDestroy() {
        ui.removeCallbacksAndMessages(null)
        try { video.stopPlayback() } catch (e: Exception) { }
        io.shutdown()
        super.onDestroy()
    }
}
