package de.overlord.tv

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.provider.Settings

/** Startet Overlord TV nach dem Einschalten des Geräts (wenn in den Einstellungen aktiviert). */
class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Intent.ACTION_BOOT_COMPLETED) return
        if (!context.getSharedPreferences("settings", Context.MODE_PRIVATE).getBoolean("autostart", false)) return
        if (Build.VERSION.SDK_INT >= 29 && !Settings.canDrawOverlays(context)) return
        try {
            context.startActivity(Intent(context, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
        } catch (e: Exception) { }
    }
}
