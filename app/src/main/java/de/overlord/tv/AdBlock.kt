package de.overlord.tv

import android.app.job.JobInfo
import android.app.job.JobParameters
import android.app.job.JobScheduler
import android.app.job.JobService
import android.content.ComponentName
import android.content.Context
import java.io.File
import java.net.HttpURLConnection
import java.net.URL
import java.text.DateFormat
import java.util.Date

/**
 * Domain-Blocker für den eingebauten Browser:
 * eingebaute Liste + öffentliche Hosts-Liste (StevenBlack), wöchentlich aktualisiert.
 */
object AdBlock {
    const val HOSTS_URL = "https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts"
    private const val FILE = "hosts.txt"
    private const val PREFS = "adblock"
    private const val WEEK = 7L * 24 * 3600 * 1000

    val BUILTIN: Set<String> = hashSetOf(
        // Werbenetzwerke
        "doubleclick.net", "googlesyndication.com", "googleadservices.com", "adservice.google.com",
        "pagead2.googlesyndication.com", "amazon-adsystem.com", "adnxs.com",
        "adsrvr.org", "criteo.com", "criteo.net", "pubmatic.com", "rubiconproject.com", "openx.net",
        "smartadserver.com", "adform.net", "yieldmo.com", "taboola.com", "outbrain.com", "mgid.com",
        "revcontent.com", "zedo.com", "media.net", "adition.com", "teads.tv", "sharethrough.com",
        "33across.com", "indexww.com", "casalemedia.com", "bidswitch.net", "contextweb.com",
        "moatads.com", "adsafeprotected.com", "serving-sys.com", "spotxchange.com", "springserve.com",
        // Pop-up-/Pop-under-Netzwerke (typisch auf Streaming-Seiten)
        "popads.net", "popcash.net", "propellerads.com", "propellerclick.com", "exoclick.com",
        "exosrv.com", "juicyads.com", "adsterra.com", "adsterratech.com", "onclickads.net",
        "onclickalgo.com", "clickadu.com", "hilltopads.net", "hilltopads.com", "adcash.com",
        "a-ads.com", "trafficjunky.net", "trafficstars.com", "tsyndicate.com", "admaven.com",
        "ad-maven.com", "richpush.co", "pushame.com", "push-sdk.com", "realsrv.com", "galaksion.com",
        "monetag.com", "highperformanceformat.com", "profitablegatecpm.com", "displayvertising.com",
        "bebi.com", "acint.net", "adskeeper.com", "adskeeper.co.uk", "magsrv.com", "pemsrv.com",
        "dolohen.com", "go.oclasrv.com", "oclasrv.com", "onclkds.com", "clkrev.com", "zeroredirect1.com",
        "aclib.net", "mobiright.com", "adspyglass.com", "lijit.com", "yllix.com", "popmyads.com",
        // Tracking
        "google-analytics.com", "googletagservices.com", "scorecardresearch.com", "quantserve.com",
        "hotjar.com", "mixpanel.com", "branch.io", "app-measurement.com",
    )

    @Volatile
    private var hosts: Set<String> = BUILTIN

    val count: Int get() = hosts.size

    fun init(ctx: Context) {
        Thread {
            load(ctx)
            if (System.currentTimeMillis() - lastUpdate(ctx) > WEEK) update(ctx)
        }.apply { priority = Thread.MIN_PRIORITY }.start()
    }

    fun lastUpdate(ctx: Context): Long = ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getLong("last", 0)

    fun lastUpdateText(ctx: Context): String {
        val t = lastUpdate(ctx)
        return if (t == 0L) "noch nie aktualisiert" else "aktualisiert am " + DateFormat.getDateInstance(DateFormat.MEDIUM).format(Date(t))
    }

    private fun load(ctx: Context) {
        val f = File(ctx.filesDir, FILE)
        if (!f.exists()) return
        try {
            val set = HashSet<String>(120_000)
            set.addAll(BUILTIN)
            f.forEachLine { line -> if (line.isNotEmpty()) set.add(line) }
            hosts = set
        } catch (e: Throwable) {
            // OutOfMemory o. Ä.: eingebaute Liste behalten
        }
    }

    /** Lädt die öffentliche Hosts-Liste herunter. Läuft im Hintergrund-Thread. */
    fun update(ctx: Context): Boolean {
        return try {
            val conn = URL(HOSTS_URL).openConnection() as HttpURLConnection
            conn.connectTimeout = 15000
            conn.readTimeout = 30000
            if (conn.responseCode != 200) return false
            val set = HashSet<String>(120_000)
            conn.inputStream.bufferedReader().useLines { lines ->
                for (raw in lines) {
                    val line = raw.substringBefore('#').trim()
                    if (line.isEmpty()) continue
                    val parts = line.split(Regex("\\s+"))
                    if (parts.size < 2) continue
                    if (parts[0] != "0.0.0.0" && parts[0] != "127.0.0.1") continue
                    val h = parts[1].lowercase()
                    if (h == "0.0.0.0" || h == "localhost" || h.endsWith(".localdomain") || !h.contains('.')) continue
                    set.add(h)
                }
            }
            if (set.size < 1000) return false
            val tmp = File(ctx.filesDir, "$FILE.tmp")
            tmp.bufferedWriter().use { w -> set.forEach { w.write(it); w.write("\n") } }
            tmp.renameTo(File(ctx.filesDir, FILE))
            set.addAll(BUILTIN)
            hosts = set
            ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().putLong("last", System.currentTimeMillis()).apply()
            true
        } catch (e: Throwable) {
            false
        }
    }

    /** Domains (Hauptseite), auf denen der Schutz abgeschaltet ist. */
    fun isAllowed(ctx: Context, host: String?): Boolean {
        if (host.isNullOrBlank()) return false
        return ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getStringSet("allow", emptySet())!!.contains(baseDomain(host))
    }

    fun setAllowed(ctx: Context, host: String, allowed: Boolean) {
        val prefs = ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val set = HashSet(prefs.getStringSet("allow", emptySet())!!)
        if (allowed) set.add(baseDomain(host)) else set.remove(baseDomain(host))
        prefs.edit().putStringSet("allow", set).apply()
    }

    /** Prüft den Host und alle übergeordneten Domains. */
    fun isBlocked(host: String?): Boolean {
        if (host.isNullOrEmpty()) return false
        var h = host.lowercase()
        val set = hosts
        while (true) {
            if (set.contains(h)) return true
            val i = h.indexOf('.')
            if (i < 0) return false
            h = h.substring(i + 1)
            if (!h.contains('.')) return false
        }
    }
}

/** Wöchentliche Aktualisierung der Hosts-Liste über den JobScheduler (ohne WorkManager). */
class HostsUpdateJob : JobService() {
    override fun onStartJob(params: JobParameters): Boolean {
        Thread {
            val ok = AdBlock.update(applicationContext)
            jobFinished(params, !ok)
        }.start()
        return true
    }

    override fun onStopJob(params: JobParameters): Boolean = true

    companion object {
        private const val JOB_ID = 7001

        fun schedule(ctx: Context) {
            try {
                val js = ctx.getSystemService(Context.JOB_SCHEDULER_SERVICE) as JobScheduler
                if (js.allPendingJobs.any { it.id == JOB_ID }) return
                val job = JobInfo.Builder(JOB_ID, ComponentName(ctx, HostsUpdateJob::class.java))
                    .setPeriodic(7L * 24 * 3600 * 1000)
                    .setRequiredNetworkType(JobInfo.NETWORK_TYPE_ANY)
                    .setPersisted(true)
                    .build()
                js.schedule(job)
            } catch (e: Exception) {
                // Nicht kritisch: App aktualisiert beim Start, wenn die Liste älter als 7 Tage ist.
            }
        }
    }
}
