package de.overlord.tv

import android.content.Context
import android.net.Uri
import java.io.File
import java.net.HttpURLConnection
import java.net.URL
import java.util.concurrent.atomic.AtomicBoolean

/**
 * Domain-basierter Werbeblocker.
 *
 * Eingebaute Liste bekannter Werbe-/Pop-under-Netzwerke plus eine öffentliche Hosts-Liste
 * (StevenBlack, Werbung + Malware), die im Hintergrund geladen und 7 Tage gecacht wird.
 */
object AdBlocker {

    private val builtIn = setOf(
        // Google / große Netzwerke
        "doubleclick.net", "googlesyndication.com", "googleadservices.com", "google-analytics.com",
        "googletagmanager.com", "googletagservices.com", "adservice.google.com", "pagead2.googlesyndication.com",
        "amazon-adsystem.com", "adnxs.com", "criteo.com", "criteo.net", "taboola.com", "outbrain.com",
        "rubiconproject.com", "pubmatic.com", "openx.net", "casalemedia.com", "smartadserver.com",
        "adform.net", "yieldlove.com", "media.net", "scorecardresearch.com", "quantserve.com",
        // Pop-under / Redirect-Netzwerke, die typisch auf Streaming-Seiten laufen
        "popads.net", "popcash.net", "propellerads.com", "propellerclick.com", "adsterra.com",
        "adsterratech.com", "exoclick.com", "exosrv.com", "juicyads.com", "trafficjunky.net",
        "hilltopads.net", "hilltopads.com", "clickadu.com", "onclickads.net", "onclkds.com",
        "popmyads.com", "adcash.com", "admaven.com", "ad-maven.com", "richpush.co", "pushame.com",
        "monetag.com", "galaksion.com", "a-ads.com", "bidvertiser.com", "revcontent.com",
        "mgid.com", "zeropark.com", "clickaine.com", "trafficstars.com", "tsyndicate.com",
        "realsrv.com", "dolohen.com", "bebi.com", "acint.net", "adspyglass.com", "pemsrv.com",
        "notifpushing.com", "pushnest.com", "evadav.com", "dtscout.com", "s.ad.smaato.net",
        "highperformanceformat.com", "highperformancecpm.com", "profitablecpmrate.com",
        "profitablegatecpm.com", "effectiveratecpm.com", "displayvertising.com",
    )

    @Volatile
    private var hosts: Set<String> = emptySet()
    private val loading = AtomicBoolean(false)

    private const val LIST_URL = "https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts"
    private const val MAX_AGE_MS = 7L * 24 * 3600 * 1000

    /** Lädt (gecachte) Hosts-Liste im Hintergrund. Mehrfaches Aufrufen ist harmlos. */
    fun init(context: Context) {
        if (!loading.compareAndSet(false, true)) return
        val file = File(context.applicationContext.filesDir, "hosts.txt")
        Thread {
            try {
                if (file.exists()) hosts = parse(file.readText())
                if (!file.exists() || System.currentTimeMillis() - file.lastModified() > MAX_AGE_MS) {
                    val conn = URL(LIST_URL).openConnection() as HttpURLConnection
                    conn.connectTimeout = 15000
                    conn.readTimeout = 30000
                    if (conn.responseCode == 200) {
                        val text = conn.inputStream.bufferedReader().use { it.readText() }
                        val parsed = parse(text)
                        if (parsed.size > 1000) {
                            file.writeText(text)
                            hosts = parsed
                        }
                    }
                    conn.disconnect()
                }
            } catch (_: Exception) {
                // offline o. Ä. – eingebaute Liste reicht dann
            }
        }.start()
    }

    private fun parse(text: String): Set<String> {
        val out = HashSet<String>(200_000)
        text.lineSequence().forEach { line ->
            if (line.startsWith("0.0.0.0 ") || line.startsWith("127.0.0.1 ")) {
                val host = line.substringAfter(' ').substringBefore('#').trim()
                if (host.isNotEmpty() && host != "0.0.0.0" && host != "localhost") out.add(host)
            }
        }
        return out
    }

    fun isBlocked(url: String): Boolean {
        val host = try { Uri.parse(url).host } catch (_: Exception) { null } ?: return false
        return isBlockedHost(host.lowercase())
    }

    fun isBlockedHost(host: String): Boolean {
        var h = host
        val list = hosts
        while (true) {
            if (h in builtIn || h in list) return true
            val dot = h.indexOf('.')
            if (dot < 0 || h.indexOf('.', dot + 1) < 0) return false
            h = h.substring(dot + 1)
        }
    }

    /** Grobe „Haupt-Domain“ (letzte zwei Labels), um fremde Weiterleitungen zu erkennen. */
    fun baseDomain(url: String?): String? {
        val host = try { Uri.parse(url ?: return null).host } catch (_: Exception) { null } ?: return null
        val parts = host.lowercase().removePrefix("www.").split('.')
        return if (parts.size <= 2) parts.joinToString(".") else parts.takeLast(2).joinToString(".")
    }
}
