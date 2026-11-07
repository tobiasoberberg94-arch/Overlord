package de.overlord.tv

import android.content.Context

/**
 * Beispieldaten – nur für die automatischen Screenshots im CI (Intent-Extra „overlord_demo“).
 * Videos und Poster liefert ein lokaler Demo-Server des CI-Rechners (Extra „demo_base“).
 */
object Demo {
    fun seed(ctx: Context, base: String?) {
        val prefs = ctx.getSharedPreferences("demo", Context.MODE_PRIVATE)
        if (prefs.getBoolean("seeded", false)) return
        prefs.edit().putBoolean("seeded", true).apply()

        val tiles = TileStore.load(ctx)
        listOf(
            "Arte" to "https://www.arte.tv/de/",
            "ARD Mediathek" to "https://www.ardmediathek.de/",
            "ZDF" to "https://www.zdf.de/",
            "Wikipedia" to "https://de.wikipedia.org/",
        ).forEach { (name, url) -> if (tiles.none { it.url == url }) tiles.add(TileStore.newWeb(name, url)) }
        TileStore.save(ctx, tiles)

        if (!base.isNullOrBlank()) {
            val b = base.trimEnd('/') + "/"
            val now = System.currentTimeMillis()
            listOf(
                Triple("Die Expedition – Folge 3", "watch.html?ep=3", 0.62),
                Triple("Nachtzug – Folge 1", "watch.html?ep=1&s=2", 0.31),
                Triple("Küsten der Welt", "watch.html?ep=5&s=3", 0.12),
                Triple("Stadt der Lichter", "watch.html?ep=2&s=4", 0.8),
            ).forEachIndexed { i, (title, page, frac) ->
                val dur = 420.0
                ContinueStore.report(
                    ctx, b + page, title, dur * frac, dur, Brand.PALETTE[(i * 3) % Brand.PALETTE.size].second,
                    image = b + "poster${i + 1}.jpg",
                )
                ContinueStore.touch(ctx, b + page, now - i * 60_000L)
            }
        }

        Thread { Jellyfin.login("https://demo.jellyfin.org/stable", "demo", "") }.start()
    }
}
