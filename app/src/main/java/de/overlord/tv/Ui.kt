package de.overlord.tv

import android.app.Activity
import android.app.AlertDialog
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.drawable.BitmapDrawable
import android.graphics.drawable.Drawable
import android.graphics.drawable.GradientDrawable
import android.graphics.drawable.StateListDrawable
import android.net.Uri
import android.speech.RecognizerIntent
import android.text.InputType
import android.text.SpannableString
import android.text.Spanned
import android.text.style.ForegroundColorSpan
import android.view.Gravity
import android.view.WindowManager
import android.widget.EditText
import android.widget.LinearLayout
import android.widget.TextView
import android.widget.Toast
import kotlin.math.max

/** Eigene Markenfarben – bewusst keine Netflix-Farben. */
object Brand {
    const val BG = 0xFF0B0B12.toInt()
    const val SURFACE = 0xFF1A1A26.toInt()
    const val ACCENT = 0xFF8B5CF6.toInt()   // Violett
    const val ACCENT2 = 0xFF22D3EE.toInt()  // Cyan
    const val TEXT = 0xFFF2F2F7.toInt()
    const val TEXT_DIM = 0xFFA6A6BD.toInt()
    const val FOCUS = 0xFFFFFFFF.toInt()
    const val HIGHLIGHT = 0xFFFFD54A.toInt()

    val PALETTE: List<Pair<String, Int>> = listOf(
        "Violett" to 0xFF7C3AED.toInt(),
        "Ozean" to 0xFF0EA5E9.toInt(),
        "Türkis" to 0xFF14B8A6.toInt(),
        "Smaragd" to 0xFF16A34A.toInt(),
        "Limette" to 0xFF84CC16.toInt(),
        "Bernstein" to 0xFFF59E0B.toInt(),
        "Orange" to 0xFFF47521.toInt(),
        "Koralle" to 0xFFEF4444.toInt(),
        "Magenta" to 0xFFDB2777.toInt(),
        "Indigo" to 0xFF4F46E5.toInt(),
        "Schiefer" to 0xFF475569.toInt(),
        "Mitternacht" to 0xFF1E293B.toInt(),
    )

    fun colorFor(seed: String): Int = PALETTE[(seed.hashCode() and 0x7fffffff) % PALETTE.size].second
}

fun Context.dp(v: Int): Int = (v * resources.displayMetrics.density + 0.5f).toInt()
fun Context.dpf(v: Float): Float = v * resources.displayMetrics.density

fun darken(color: Int, factor: Float): Int = Color.argb(
    Color.alpha(color),
    (Color.red(color) * factor).toInt().coerceIn(0, 255),
    (Color.green(color) * factor).toInt().coerceIn(0, 255),
    (Color.blue(color) * factor).toInt().coerceIn(0, 255),
)

fun blend(a: Int, b: Int, t: Float): Int {
    val u = 1f - t
    return Color.argb(
        255,
        (Color.red(a) * u + Color.red(b) * t).toInt(),
        (Color.green(a) * u + Color.green(b) * t).toInt(),
        (Color.blue(a) * u + Color.blue(b) * t).toInt(),
    )
}

fun withAlpha(color: Int, alpha: Int): Int = (color and 0x00FFFFFF) or (alpha shl 24)

fun hostOf(url: String?): String = try {
    Uri.parse(url ?: "").host?.removePrefix("www.") ?: ""
} catch (e: Exception) {
    ""
}

/** Grobe Ermittlung der registrierbaren Domain (example.co.uk → example.co.uk, a.b.example.com → example.com). */
fun baseDomain(host: String): String {
    val h = host.lowercase().removePrefix("www.")
    val p = h.split('.')
    if (p.size <= 2) return h
    val tld = p[p.size - 1]
    val sld = p[p.size - 2]
    return if (tld.length == 2 && sld.length <= 3) p.takeLast(3).joinToString(".") else p.takeLast(2).joinToString(".")
}

fun sameSite(a: String?, b: String?): Boolean {
    val ha = hostOf(a)
    val hb = hostOf(b)
    if (ha.isEmpty() || hb.isEmpty()) return false
    return baseDomain(ha) == baseDomain(hb)
}

fun normalizeUrl(input: String): String {
    val s = input.trim()
    if (s.isEmpty()) return s
    if (s.startsWith("http://") || s.startsWith("https://")) return s
    if (!s.contains('.') || s.contains(' ')) {
        return "https://duckduckgo.com/?q=" + Uri.encode(s)
    }
    return "https://$s"
}

fun formatTime(seconds: Double): String {
    val s = max(0.0, seconds).toLong()
    val h = s / 3600
    val m = (s % 3600) / 60
    val sec = s % 60
    return if (h > 0) String.format("%d:%02d:%02d", h, m, sec) else String.format("%d:%02d", m, sec)
}

fun formatRemaining(seconds: Double): String {
    val min = (max(0.0, seconds) / 60).toInt()
    return when {
        min < 1 -> "noch < 1 Min."
        min < 60 -> "noch $min Min."
        else -> "noch ${min / 60} Std. ${min % 60} Min."
    }
}

fun Context.toast(msg: String) = Toast.makeText(this, msg, Toast.LENGTH_SHORT).show()

/** Durchschnittliche, „lebendige“ Farbe einer Grafik – für passende Hintergründe. */
fun dominantColor(d: Drawable?): Int? {
    if (d == null) return null
    return try {
        val bmp = Bitmap.createBitmap(24, 24, Bitmap.Config.ARGB_8888)
        val c = Canvas(bmp)
        d.setBounds(0, 0, 24, 24)
        d.draw(c)
        dominantColor(bmp).also { bmp.recycle() }
    } catch (e: Exception) {
        null
    }
}

fun dominantColor(bmp: Bitmap): Int? {
    val small = if (bmp.width > 32) Bitmap.createScaledBitmap(bmp, 32, max(1, 32 * bmp.height / max(1, bmp.width)), true) else bmp
    var r = 0L; var g = 0L; var b = 0L; var n = 0L
    var rAll = 0L; var gAll = 0L; var bAll = 0L; var nAll = 0L
    val hsv = FloatArray(3)
    for (y in 0 until small.height) for (x in 0 until small.width) {
        val p = small.getPixel(x, y)
        if (Color.alpha(p) < 128) continue
        rAll += Color.red(p); gAll += Color.green(p); bAll += Color.blue(p); nAll++
        Color.colorToHSV(p, hsv)
        if (hsv[1] > 0.35f && hsv[2] > 0.25f) {
            r += Color.red(p); g += Color.green(p); b += Color.blue(p); n++
        }
    }
    if (small !== bmp) small.recycle()
    if (n > 4) return Color.rgb((r / n).toInt(), (g / n).toInt(), (b / n).toInt())
    if (nAll > 0) return Color.rgb((rAll / nAll).toInt(), (gAll / nAll).toInt(), (bAll / nAll).toInt())
    return null
}

fun drawableToBitmap(d: Drawable): Bitmap {
    if (d is BitmapDrawable && d.bitmap != null) return d.bitmap
    val w = if (d.intrinsicWidth > 0) d.intrinsicWidth else 96
    val h = if (d.intrinsicHeight > 0) d.intrinsicHeight else 96
    val bmp = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
    val c = Canvas(bmp)
    d.setBounds(0, 0, w, h)
    d.draw(c)
    return bmp
}

/** Knopf-Hintergrund mit deutlichem Fokus-Zustand (für Fernbedienung). */
fun Context.buttonBackground(radiusDp: Int = 10): StateListDrawable {
    val r = dpf(radiusDp.toFloat())
    val focused = GradientDrawable().apply { cornerRadius = r; setColor(Brand.ACCENT); setStroke(dp(3), Brand.FOCUS) }
    val normal = GradientDrawable().apply { cornerRadius = r; setColor(0x33FFFFFF) }
    return StateListDrawable().apply {
        addState(intArrayOf(android.R.attr.state_focused), focused)
        addState(intArrayOf(android.R.attr.state_pressed), focused)
        addState(intArrayOf(), normal)
    }
}

object Dialogs {
    fun builder(ctx: Context): AlertDialog.Builder = AlertDialog.Builder(ctx, android.R.style.Theme_Material_Dialog_Alert)

    fun list(ctx: Context, title: String, items: List<CharSequence>, onPick: (Int) -> Unit): AlertDialog =
        builder(ctx).setTitle(title)
            .setItems(items.toTypedArray()) { _, which -> onPick(which) }
            .setNegativeButton("Abbrechen", null)
            .show()

    fun colorItems(): List<CharSequence> = Brand.PALETTE.map { (name, color) ->
        SpannableString("■  $name").apply { setSpan(ForegroundColorSpan(color), 0, 1, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE) }
    }

    fun input(
        ctx: Context,
        title: String,
        hint: String,
        initial: String = "",
        url: Boolean = false,
        password: Boolean = false,
        neutral: Pair<String, () -> Unit>? = null,
        onOk: (String) -> Unit,
    ): AlertDialog {
        val edit = EditText(ctx).apply {
            setText(initial)
            setSelection(text.length)
            this.hint = hint
            setSingleLine(true)
            setTextColor(Brand.TEXT)
            setHintTextColor(Brand.TEXT_DIM)
            inputType = when {
                password -> InputType.TYPE_CLASS_TEXT or InputType.TYPE_TEXT_VARIATION_PASSWORD
                url -> InputType.TYPE_CLASS_TEXT or InputType.TYPE_TEXT_VARIATION_URI
                else -> InputType.TYPE_CLASS_TEXT
            }
        }
        val wrap = LinearLayout(ctx).apply {
            setPadding(ctx.dp(24), ctx.dp(8), ctx.dp(24), 0)
            addView(edit, LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT))
        }
        val b = builder(ctx).setTitle(title).setView(wrap)
            .setPositiveButton("OK") { _, _ -> onOk(edit.text.toString().trim()) }
            .setNegativeButton("Abbrechen", null)
        if (neutral != null) b.setNeutralButton(neutral.first) { _, _ -> neutral.second() }
        val dlg = b.create()
        edit.setOnEditorActionListener { _, _, _ ->
            dlg.dismiss(); onOk(edit.text.toString().trim()); true
        }
        dlg.window?.setSoftInputMode(WindowManager.LayoutParams.SOFT_INPUT_STATE_VISIBLE)
        dlg.show()
        edit.requestFocus()
        return dlg
    }

    fun info(ctx: Context, title: String, text: String) {
        val tv = TextView(ctx).apply {
            this.text = text
            setTextColor(Brand.TEXT)
            textSize = 15f
            setPadding(ctx.dp(24), ctx.dp(12), ctx.dp(24), ctx.dp(12))
            gravity = Gravity.START
            isFocusable = true
        }
        val sv = android.widget.ScrollView(ctx).apply { addView(tv); isFocusable = false }
        builder(ctx).setTitle(title).setView(sv).setPositiveButton("OK", null).show()
    }
}

/** Spracheingabe, falls auf dem Gerät verfügbar (auf vielen Fire-TV-Geräten nur über die Tastatur). */
object Voice {
    const val REQUEST = 4711

    fun available(ctx: Context): Boolean = try {
        Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).resolveActivity(ctx.packageManager) != null
    } catch (e: Exception) {
        false
    }

    fun start(activity: Activity, prompt: String): Boolean = try {
        val i = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH)
            .putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
            .putExtra(RecognizerIntent.EXTRA_LANGUAGE, "de-DE")
            .putExtra(RecognizerIntent.EXTRA_PROMPT, prompt)
        activity.startActivityForResult(i, REQUEST)
        true
    } catch (e: Exception) {
        false
    }

    fun result(data: Intent?): String? =
        data?.getStringArrayListExtra(RecognizerIntent.EXTRA_RESULTS)?.firstOrNull()
}
