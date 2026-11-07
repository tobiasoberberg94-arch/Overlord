package de.overlord.tv

import android.content.Context

/** Allgemeine Einstellungen der App. */
object Prefs {
    private val p get() = App.instance.getSharedPreferences("settings", Context.MODE_PRIVATE)

    /** Intro-/Werbung-überspringen-Knöpfe auf Webseiten automatisch drücken. */
    var autoSkip: Boolean
        get() = p.getBoolean("autoSkip", true)
        set(v) { p.edit().putBoolean("autoSkip", v).apply() }

    /** Overlord nach dem Einschalten des Geräts automatisch starten. */
    var autostart: Boolean
        get() = p.getBoolean("autostart", false)
        set(v) { p.edit().putBoolean("autostart", v).apply() }

    /** Gewähltes Farbthema (Index in Brand.THEMES). */
    var theme: Int
        get() = p.getInt("theme", 0)
        set(v) { p.edit().putInt("theme", v).apply() }

    /** Am Ende eines Videos automatisch die nächste Folge starten (mit Countdown). */
    var autoNext: Boolean
        get() = p.getBoolean("autoNext", true)
        set(v) { p.edit().putBoolean("autoNext", v).apply() }
}
