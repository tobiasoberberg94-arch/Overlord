package de.overlord.tv

import android.content.Context

/**
 * Beispieldaten – nur für die automatischen Screenshots im CI (Intent-Extra „overlord_demo“).
 * Nutzt frei verfügbare Beispielvideos (Blender Foundation, CC-BY) aus Googles Testdaten.
 */
object Demo {
    private const val SAMPLE = "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/"

    fun seed(ctx: Context) {
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

        val now = System.currentTimeMillis()
        listOf(
            Triple("Sintel", "Sintel", 888.0) to 0.62,
            Triple("Tears of Steel", "TearsOfSteel", 734.0) to 0.31,
            Triple("Big Buck Bunny", "BigBuckBunny", 596.0) to 0.12,
            Triple("Elephants Dream", "ElephantsDream", 653.0) to 0.8,
        ).forEachIndexed { i, (t, frac) ->
            val (title, file, dur) = t
            ContinueStore.report(
                ctx, SAMPLE + "$file.mp4", title, dur * frac, dur, Brand.PALETTE[(i * 3) % Brand.PALETTE.size].second,
                image = SAMPLE + "images/$file.jpg",
            )
            ContinueStore.touch(ctx, SAMPLE + "$file.mp4", now - i * 60_000L)
        }

        Thread { Jellyfin.login("https://demo.jellyfin.org/stable", "demo", "") }.start()
    }
}
