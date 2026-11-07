package de.overlord.tv

import android.content.Context

/** Allgemeine Einstellungen der App. */
object Prefs {
    private val p get() = App.instance.getSharedPreferences("settings", Context.MODE_PRIVATE)

    /** Intro-/Werbung-überspringen-Knöpfe auf Webseiten automatisch drücken. */
    var autoSkip: Boolean
        get() = p.getBoolean("autoSkip", true)
        set(v) { p.edit().putBoolean("autoSkip", v).apply() }

    /** Video-Ansicht (nur Videos statt ganzer Seite) für die Domain dieser Adresse? */
    fun videoView(url: String?): Boolean =
        App.instance.getSharedPreferences("videoview", Context.MODE_PRIVATE).getBoolean(baseDomain(hostOf(url)), false)

    fun setVideoView(url: String?, on: Boolean) {
        val host = hostOf(url)
        if (host.isBlank()) return
        App.instance.getSharedPreferences("videoview", Context.MODE_PRIVATE).edit().putBoolean(baseDomain(host), on).apply()
    }

    /** Overlord nach dem Einschalten des Geräts automatisch starten. */
    var autostart: Boolean
        get() = p.getBoolean("autostart", false)
        set(v) { p.edit().putBoolean("autostart", v).apply() }

    /** Gewähltes Farbthema (Index in Brand.THEMES). */
    var theme: Int
        get() = p.getInt("theme", 0)
        set(v) { p.edit().putInt("theme", v).apply() }

    /** Cookie-Hinweise auf Webseiten automatisch beantworten: "reject" (ablehnen), "accept" (zustimmen) oder "off". */
    var consent: String
        get() = p.getString("consent", "reject") ?: "reject"
        set(v) { p.edit().putString("consent", v).apply() }

    fun consentLabel(v: String = consent) = when (v) {
        "accept" -> "Automatisch zustimmen"
        "off" -> "Nicht anfassen"
        else -> "Automatisch ablehnen"
    }

    /** Am Ende eines Videos automatisch die nächste Folge starten (mit Countdown). */
    var autoNext: Boolean
        get() = p.getBoolean("autoNext", true)
        set(v) { p.edit().putBoolean("autoNext", v).apply() }
}
