package de.overlord.tv

import android.app.Activity
import android.app.Instrumentation
import android.content.Context
import android.content.Intent
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.view.KeyEvent
import org.json.JSONArray
import org.json.JSONObject
import java.io.BufferedInputStream
import java.io.ByteArrayOutputStream
import java.net.Inet4Address
import java.net.NetworkInterface
import java.net.ServerSocket
import java.net.Socket
import java.net.URLDecoder
import java.util.concurrent.Executors
import kotlin.random.Random

/**
 * Handy-Begleiter: kleiner Webserver im Heimnetz. Das Handy öffnet die Seite (QR-Code auf dem TV),
 * und kann dann tippen, Links öffnen, Kacheln anlegen und die App wie eine Fernbedienung steuern.
 * Geschützt durch eine 4-stellige PIN.
 */
object Companion {
    const val PORT = 8765
    private const val PREFS = "companion"
    private val main = Handler(Looper.getMainLooper())
    private val pool = Executors.newFixedThreadPool(3)
    @Volatile private var server: ServerSocket? = null
    @Volatile var port = PORT
        private set
    private var failedAttempts = 0
    private var blockedUntil = 0L

    private val prefs get() = App.instance.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    val running get() = server?.isClosed == false

    var enabled: Boolean
        get() = prefs.getBoolean("enabled", false)
        set(v) { prefs.edit().putBoolean("enabled", v).apply() }

    val pin: String
        get() = prefs.getString("pin", null) ?: String.format("%04d", Random.nextInt(10000)).also { prefs.edit().putString("pin", it).apply() }

    fun newPin() { prefs.edit().putString("pin", String.format("%04d", Random.nextInt(10000))).apply() }

    fun start() {
        if (running) return
        Thread {
            for (p in PORT until PORT + 10) {
                try {
                    val s = ServerSocket(p)
                    server = s
                    port = p
                    break
                } catch (e: Exception) { }
            }
            val s = server ?: return@Thread
            while (!s.isClosed) {
                try {
                    val sock = s.accept()
                    pool.execute { handle(sock) }
                } catch (e: Exception) {
                    if (s.isClosed) break
                }
            }
        }.apply { isDaemon = true; name = "overlord-companion" }.start()
    }

    fun stop() {
        try { server?.close() } catch (e: Exception) { }
        server = null
    }

    /** IPv4-Adresse im Heimnetz (WLAN oder LAN). */
    fun ipAddress(): String? = try {
        NetworkInterface.getNetworkInterfaces().toList()
            .filter { it.isUp && !it.isLoopback }
            .sortedBy { if (it.name.startsWith("wlan") || it.name.startsWith("eth")) 0 else 1 }
            .flatMap { it.inetAddresses.toList() }
            .filterIsInstance<Inet4Address>()
            .firstOrNull { !it.isLoopbackAddress && it.isSiteLocalAddress }
            ?.hostAddress
    } catch (e: Exception) {
        null
    }

    fun url(): String? = ipAddress()?.let { "http://$it:$port/?pin=$pin" }

    // ------------------------------------------------------------------ HTTP

    private class Request(val method: String, val path: String, val query: Map<String, String>, val headers: Map<String, String>, val body: String)

    private fun handle(sock: Socket) {
        sock.use { s ->
            try {
                s.soTimeout = 10_000
                val req = read(BufferedInputStream(s.getInputStream())) ?: return
                val (status, type, body) = route(req)
                val bytes = body.toByteArray(Charsets.UTF_8)
                val head = "HTTP/1.1 $status\r\nContent-Type: $type\r\nContent-Length: ${bytes.size}\r\n" +
                    "Cache-Control: no-store\r\nConnection: close\r\n\r\n"
                s.getOutputStream().apply { write(head.toByteArray(Charsets.ISO_8859_1)); write(bytes); flush() }
            } catch (e: Exception) { }
        }
    }

    private fun read(input: BufferedInputStream): Request? {
        val headerBuf = ByteArrayOutputStream()
        var last4 = 0
        while (true) {
            val b = input.read()
            if (b < 0) return null
            headerBuf.write(b)
            last4 = (last4 shl 8) or b
            if (last4 == 0x0D0A0D0A) break
            if (headerBuf.size() > 16_384) return null
        }
        val lines = headerBuf.toString("ISO-8859-1").split("\r\n")
        val parts = lines.firstOrNull()?.split(' ') ?: return null
        if (parts.size < 2) return null
        val headers = HashMap<String, String>()
        lines.drop(1).forEach { l -> val i = l.indexOf(':'); if (i > 0) headers[l.substring(0, i).trim().lowercase()] = l.substring(i + 1).trim() }
        val len = headers["content-length"]?.toIntOrNull()?.coerceIn(0, 65_536) ?: 0
        val body = ByteArray(len)
        var off = 0
        while (off < len) { val n = input.read(body, off, len - off); if (n < 0) break; off += n }
        val full = parts[1]
        val path = full.substringBefore('?')
        val query = full.substringAfter('?', "").split('&').filter { it.contains('=') }.associate {
            URLDecoder.decode(it.substringBefore('='), "UTF-8") to URLDecoder.decode(it.substringAfter('='), "UTF-8")
        }
        return Request(parts[0], path, query, headers, String(body, 0, off, Charsets.UTF_8))
    }

    private fun json(o: Any) = Triple("200 OK", "application/json; charset=utf-8", o.toString())

    private fun route(r: Request): Triple<String, String, String> {
        if (r.method == "GET" && (r.path == "/" || r.path == "/index.html")) {
            val html = App.instance.assets.open("companion.html").bufferedReader().use { it.readText() }
            return Triple("200 OK", "text/html; charset=utf-8", html)
        }
        if (!r.path.startsWith("/api/")) return Triple("404 Not Found", "text/plain", "Nicht gefunden")

        // PIN prüfen (mit Sperre gegen Durchprobieren)
        val now = SystemClock.elapsedRealtime()
        if (now < blockedUntil) return Triple("429 Too Many Requests", "application/json", JSONObject().put("error", "Zu viele Versuche – bitte kurz warten").toString())
        if ((r.headers["x-pin"] ?: r.query["pin"]) != pin) {
            if (++failedAttempts >= 5) { blockedUntil = now + 60_000; failedAttempts = 0 }
            return Triple("401 Unauthorized", "application/json", JSONObject().put("error", "Falsche PIN").toString())
        }
        failedAttempts = 0

        val body = try { if (r.body.isBlank()) JSONObject() else JSONObject(r.body) } catch (e: Exception) { JSONObject() }
        return when (r.path) {
            "/api/info" -> json(info())
            "/api/key" -> { key(body.optString("key")); json(JSONObject().put("ok", true)) }
            "/api/text" -> { val ok = text(body.optString("text"), body.optBoolean("submit")); json(JSONObject().put("ok", ok)) }
            "/api/open" -> {
                val url = normalizeUrl(body.optString("url"))
                if (url.isNotBlank()) onMain { ctx -> BrowserActivity.open(ctx, url, hostOf(url)) }
                json(JSONObject().put("ok", url.isNotBlank()))
            }
            "/api/tile" -> {
                val url = normalizeUrl(body.optString("url"))
                val name = body.optString("name").ifBlank { hostOf(url).substringBefore('.').replaceFirstChar { it.uppercase() } }
                if (url.isNotBlank()) {
                    TileStore.add(App.instance, TileStore.newWeb(name, url))
                    onMain { Events.changed() }
                }
                json(JSONObject().put("ok", url.isNotBlank()).put("name", name))
            }
            "/api/launch" -> {
                val id = body.optString("id")
                onMain { ctx -> TileStore.load(ctx).firstOrNull { it.id == id }?.let { t -> (ctx as? Activity)?.let { Launcher.open(it, t) } } }
                json(JSONObject().put("ok", true))
            }
            "/api/resume" -> {
                val key = body.optString("key")
                onMain { ctx ->
                    ContinueStore.all(ctx).firstOrNull { it.key == key }?.let { e -> BrowserActivity.open(ctx, e.url, e.title, e.color, resume = e.position) }
                }
                json(JSONObject().put("ok", true))
            }
            "/api/search" -> {
                val q = body.optString("q").trim()
                if (q.isNotBlank()) onMain { ctx -> SearchActivity.open(ctx, q) }
                json(JSONObject().put("ok", q.isNotBlank()))
            }
            else -> Triple("404 Not Found", "application/json", JSONObject().put("error", "Unbekannt").toString())
        }
    }

    private fun info(): JSONObject {
        val ctx = App.instance
        val tiles = JSONArray()
        TileStore.load(ctx).forEach { t ->
            tiles.put(JSONObject().put("id", t.id).put("name", t.name).put("type", t.type.name).put("url", t.url)
                .put("color", String.format("#%06X", t.color and 0xFFFFFF)))
        }
        val cont = JSONArray()
        ContinueStore.all(ctx).forEach { e ->
            cont.put(JSONObject().put("key", e.key).put("title", e.title).put("host", hostOf(e.url))
                .put("progress", e.fraction.toDouble()).put("remaining", formatRemaining(e.remaining)).put("image", e.image))
        }
        return JSONObject().put("app", "Overlord TV").put("version", BuildConfig.VERSION_NAME)
            .put("screen", App.current?.javaClass?.simpleName ?: "").put("tiles", tiles).put("continue", cont)
    }

    /** Auf dem UI-Thread mit der aktuellen Activity (oder dem App-Kontext) ausführen. */
    private fun onMain(block: (Context) -> Unit) {
        main.post {
            val ctx: Context = App.current ?: App.instance
            try {
                if (ctx === App.instance) {
                    // Keine sichtbare Activity: App nach vorne holen
                    App.instance.startActivity(Intent(App.instance, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                }
                block(ctx)
            } catch (e: Exception) { }
        }
    }

    // ------------------------------------------------------------------ Fernbedienung

    private val KEYS = mapOf(
        "up" to KeyEvent.KEYCODE_DPAD_UP, "down" to KeyEvent.KEYCODE_DPAD_DOWN,
        "left" to KeyEvent.KEYCODE_DPAD_LEFT, "right" to KeyEvent.KEYCODE_DPAD_RIGHT,
        "ok" to KeyEvent.KEYCODE_DPAD_CENTER, "back" to KeyEvent.KEYCODE_BACK,
        "menu" to KeyEvent.KEYCODE_MENU, "playpause" to KeyEvent.KEYCODE_MEDIA_PLAY_PAUSE,
        "rew" to KeyEvent.KEYCODE_MEDIA_REWIND, "ff" to KeyEvent.KEYCODE_MEDIA_FAST_FORWARD,
    )

    private fun key(name: String) {
        if (name == "home") {
            onMain { ctx -> ctx.startActivity(Intent(ctx, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)) }
            return
        }
        val inst = Instrumentation()
        try {
            if (name == "menu_long" || name == "ok_long") {
                val code = if (name == "menu_long") KeyEvent.KEYCODE_MENU else KeyEvent.KEYCODE_DPAD_CENTER
                val t = SystemClock.uptimeMillis()
                inst.sendKeySync(KeyEvent(t, t, KeyEvent.ACTION_DOWN, code, 0))
                Thread.sleep(650)
                inst.sendKeySync(KeyEvent(t, SystemClock.uptimeMillis(), KeyEvent.ACTION_DOWN, code, 1, 0, -1, 0, KeyEvent.FLAG_LONG_PRESS))
                inst.sendKeySync(KeyEvent(t, SystemClock.uptimeMillis(), KeyEvent.ACTION_UP, code, 0))
                return
            }
            val code = KEYS[name] ?: return
            inst.sendKeyDownUpSync(code)
        } catch (e: Exception) {
            // Eine andere App ist im Vordergrund – Tasten lassen sich nur in Overlord einspeisen.
        }
    }

    /** Text in das aktive Eingabefeld (TV-Dialog oder Webseite) schreiben. */
    private fun text(t: String, submit: Boolean): Boolean {
        if (t.isEmpty()) return false
        var handled = false
        val latch = java.util.concurrent.CountDownLatch(1)
        main.post {
            try {
                handled = Tv.typeIntoActiveInput(t, submit) ||
                    (App.current as? BrowserActivity)?.insertText(t, submit) == true
                if (!handled && App.current is MainActivity) {
                    // Auf der Startseite: als Suche bzw. Adresse behandeln
                    val c = App.current!!
                    if (t.contains('.') && !t.contains(' ')) BrowserActivity.open(c, normalizeUrl(t), hostOf(normalizeUrl(t))) else SearchActivity.open(c, t)
                    handled = true
                }
            } finally {
                latch.countDown()
            }
        }
        latch.await(1500, java.util.concurrent.TimeUnit.MILLISECONDS)
        return handled
    }
}

/** Einfache App-weite Benachrichtigung („Daten geändert“). */
object Events {
    private val listeners = ArrayList<() -> Unit>()
    fun listen(l: () -> Unit) { listeners.add(l) }
    fun unlisten(l: () -> Unit) { listeners.remove(l) }
    fun changed() { listeners.toList().forEach { it() } }
}
