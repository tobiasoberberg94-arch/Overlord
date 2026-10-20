"""
Erzeugt die Effekt-Texturen für Kampf und Zauber (assets/textures/fx/*.png) – vollständig prozedural,
ohne fremde Bilder:

  fx_dot          weicher Lichtpunkt (Funken, Glut, Magiepartikel)
  fx_streak       Leuchtspur mit hellem Kopf (Funken in Flugrichtung)
  fx_flare        Sternblitz (Parade, kritischer Treffer, Zauberauslösung)
  fx_smoke        2×2 Rauch-/Staubwolken mit eingebackener Beleuchtung
  fx_chips        2×2 Splitter (Knochen, Stein, Eis) als Partikelbild
  fx_rune_a/b/c   Magiekreise mit Runenbändern, Sternpolygonen und Skalenringen
  fx_noise        kachelbares Rauschen (R/G/B/A = vier Frequenzen) für Shader
  decal_scorch    Brandfleck (+ _emit Glutpunkte)
  decal_blood_0…3 Blutspritzer (+ _orm nass glänzend)
  decal_frost     Raureif-Kristalle
  decal_crack     Bodenrisse (+ _n Normalmap)

Aufruf (jede Python-Version mit numpy, z. B. die von Blender):
  "C:/Tools/Blender/4.2/python/bin/python.exe" tools/fx/make_fx_textures.py
"""
import math
import os
import struct
import zlib

import numpy as np

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "assets", "textures", "fx")


# ------------------------------------------------------------------ Grundlagen
def save_png(name, arr):
    a = np.asarray(arr)
    if a.dtype != np.uint8:
        a = (np.clip(a, 0.0, 1.0) * 255.0 + 0.5).astype(np.uint8)
    if a.ndim == 2:
        a = a[:, :, None]
    h, w, c = a.shape
    ctype = {1: 0, 2: 4, 3: 2, 4: 6}[c]
    raw = b"".join(b"\x00" + a[y].tobytes() for y in range(h))

    def chunk(t, d):
        return struct.pack(">I", len(d)) + t + d + struct.pack(">I", zlib.crc32(t + d) & 0xFFFFFFFF)

    png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, ctype, 0, 0, 0))
    png += chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b"")
    with open(os.path.join(OUT, name + ".png"), "wb") as f:
        f.write(png)
    print("  ", name, f"{w}x{h}")


def grid(w, h=None):
    h = h or w
    y, x = np.mgrid[0:h, 0:w].astype(np.float64)
    return (x + 0.5) / w * 2.0 - 1.0, (y + 0.5) / h * 2.0 - 1.0


def smooth(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def vnoise(n, freq, seed):
    """Kachelbares Wertrauschen n×n mit freq Zellen je Seite (kubisch geglättet)."""
    r = np.random.default_rng(seed)
    lat = r.random((freq, freq))
    t = np.arange(n) / n * freq
    i0 = np.floor(t).astype(int)
    f = t - i0
    i1 = (i0 + 1) % freq
    i0 %= freq
    u = f * f * (3.0 - 2.0 * f)
    a = lat[np.ix_(i0, i0)]
    b = lat[np.ix_(i0, i1)]
    c = lat[np.ix_(i1, i0)]
    d = lat[np.ix_(i1, i1)]
    uy = u[:, None]
    ux = u[None, :]
    return (a * (1 - ux) + b * ux) * (1 - uy) + (c * (1 - ux) + d * ux) * uy


def fbm(n, base, octaves, seed, gain=0.5):
    s = np.zeros((n, n))
    amp, tot = 1.0, 0.0
    for o in range(octaves):
        s += vnoise(n, base * 2 ** o, seed + o * 17) * amp
        tot += amp
        amp *= gain
    return s / tot


def ridged(n, base, octaves, seed):
    s = np.zeros((n, n))
    amp, tot = 1.0, 0.0
    for o in range(octaves):
        v = 1.0 - np.abs(vnoise(n, base * 2 ** o, seed + o * 31) * 2.0 - 1.0)
        s += v * v * amp
        tot += amp
        amp *= 0.55
    return s / tot


def blur(a, k=2):
    """Einfacher Kastenfilter (mehrfach ≈ Gauß), Ränder umlaufend."""
    out = a.copy()
    for _ in range(k):
        out = (out + np.roll(out, 1, 0) + np.roll(out, -1, 0) + np.roll(out, 1, 1) + np.roll(out, -1, 1)) / 5.0
    return out


class Canvas:
    """Zeichenfläche in Koordinaten [-1, 1]² mit kantengeglätteten Linien, Ringen und Kreisen."""

    def __init__(self, n):
        self.n = n
        self.px = 2.0 / n
        self.a = np.zeros((n, n))
        self.x, self.y = grid(n)
        self.r = np.hypot(self.x, self.y)
        self.ang = np.arctan2(self.y, self.x)

    def ring(self, r0, w, val=1.0):
        cov = np.clip((w * 0.5 - np.abs(self.r - r0)) / self.px + 0.5, 0.0, 1.0) * val
        np.maximum(self.a, cov, out=self.a)

    def disc(self, cx, cy, rad, val=1.0):
        self._region(cx - rad, cy - rad, cx + rad, cy + rad, lambda X, Y: np.clip((rad - np.hypot(X - cx, Y - cy)) / self.px + 0.5, 0, 1) * val)

    def circle(self, cx, cy, rad, w, val=1.0):
        e = rad + w
        self._region(cx - e, cy - e, cx + e, cy + e,
                     lambda X, Y: np.clip((w * 0.5 - np.abs(np.hypot(X - cx, Y - cy) - rad)) / self.px + 0.5, 0, 1) * val)

    def seg(self, p0, p1, w, val=1.0):
        (x0, y0), (x1, y1) = p0, p1
        e = w + self.px * 2

        def f(X, Y):
            dx, dy = x1 - x0, y1 - y0
            t = np.clip(((X - x0) * dx + (Y - y0) * dy) / (dx * dx + dy * dy + 1e-12), 0.0, 1.0)
            d = np.hypot(X - (x0 + t * dx), Y - (y0 + t * dy))
            return np.clip((w * 0.5 - d) / self.px + 0.5, 0.0, 1.0) * val

        self._region(min(x0, x1) - e, min(y0, y1) - e, max(x0, x1) + e, max(y0, y1) + e, f)

    def _region(self, xa, ya, xb, yb, fn):
        n, px = self.n, self.px
        i0 = max(0, int((xa + 1.0) / px))
        i1 = min(n, int((xb + 1.0) / px) + 2)
        j0 = max(0, int((ya + 1.0) / px))
        j1 = min(n, int((yb + 1.0) / px) + 2)
        if i1 <= i0 or j1 <= j0:
            return
        X = self.x[j0:j1, i0:i1]
        Y = self.y[j0:j1, i0:i1]
        np.maximum(self.a[j0:j1, i0:i1], fn(X, Y), out=self.a[j0:j1, i0:i1])

    # --- Ornamente ------------------------------------------------------------------------------------------------
    def polygram(self, r0, k, step, w, rot=0.0):
        pts = [(math.cos(rot + math.tau * i / k) * r0, math.sin(rot + math.tau * i / k) * r0) for i in range(k)]
        for i in range(k):
            self.seg(pts[i], pts[(i + step) % k], w)
        return pts

    def ticks(self, r_in, r_out, count, w, long_every=0, r_long=None):
        for i in range(count):
            a = math.tau * i / count
            ro = r_long if long_every and i % long_every == 0 and r_long else r_out
            self.seg((math.cos(a) * r_in, math.sin(a) * r_in), (math.cos(a) * ro, math.sin(a) * ro), w)

    def rune_band(self, r_in, r_out, count, w, rng, rot=0.0):
        """Runen auf einem Ring: Striche zwischen Rasterpunkten (3 Spalten × 5 Zeilen), oft mit Mittelstab."""
        h = (r_out - r_in) * 0.78
        rc = (r_in + r_out) * 0.5
        cell = h / 4.0
        for i in range(count):
            th = rot + math.tau * (i + 0.5) / count
            n = (math.cos(th), math.sin(th))
            t = (-math.sin(th), math.cos(th))

            def P(u, v):
                return (n[0] * (rc + v * cell) + t[0] * u * cell * 0.8, n[1] * (rc + v * cell) + t[1] * u * cell * 0.8)

            strokes = []
            if rng.random() < 0.75:
                strokes.append(((0, -2), (0, 2)))
            for _ in range(rng.integers(2, 5)):
                u0, v0 = int(rng.integers(-1, 2)), int(rng.integers(-2, 3))
                du, dv = [(1, 1), (1, -1), (-1, 1), (-1, -1), (1, 0), (0, 1), (2, 1), (1, 2)][rng.integers(0, 8)]
                u1, v1 = max(-1, min(1, u0 + du)), max(-2, min(2, v0 + dv))
                if (u0, v0) != (u1, v1):
                    strokes.append(((u0, v0), (u1, v1)))
            if rng.random() < 0.25:
                c = P(0, float(rng.integers(-1, 2)))
                self.circle(c[0], c[1], cell * 0.45, w)
            for (a, b) in strokes:
                self.seg(P(*a), P(*b), w)


# ------------------------------------------------------------------ Partikelbilder
def tex_dot():
    x, y = grid(128)
    r = np.hypot(x, y)
    a = np.exp(-((r / 0.45) ** 2) * 2.4) * 0.8 + np.exp(-((r / 0.12) ** 2)) * 0.5
    a *= np.clip((1.0 - r) / 0.12, 0, 1)
    save_png("fx_dot", np.dstack([np.ones_like(a)] * 3 + [np.clip(a, 0, 1)]))


def tex_streak():
    x, y = grid(64, 256)
    t = (y + 1.0) * 0.5                     # 0 = Kopf (oben) … 1 = Schweifende
    wid = 0.42 * (1.0 - 0.55 * t)
    body = np.exp(-((x / wid) ** 2) * 3.0) * (1.0 - t) ** 1.4 * smooth(0.0, 0.07, t)
    core = np.exp(-((x / 0.1) ** 2)) * (1.0 - t) ** 3 * smooth(0.0, 0.05, t)
    a = np.clip(body * 0.75 + core * 0.7, 0, 1)
    save_png("fx_streak", np.dstack([np.ones_like(a)] * 3 + [a]))


def tex_flare():
    x, y = grid(256)
    r = np.hypot(x, y)
    glow = np.exp(-((r / 0.32) ** 2) * 2.0)
    core = np.exp(-((r / 0.07) ** 2))
    rays = np.exp(-np.abs(x) * 55) * np.exp(-np.abs(y) * 2.0) + np.exp(-np.abs(y) * 55) * np.exp(-np.abs(x) * 2.0)
    u, v = (x + y) / math.sqrt(2), (x - y) / math.sqrt(2)
    diag = np.exp(-np.abs(u) * 80) * np.exp(-np.abs(v) * 4.0) + np.exp(-np.abs(v) * 80) * np.exp(-np.abs(u) * 4.0)
    a = np.clip(glow * 0.55 + rays * 0.9 + diag * 0.4 + core * 0.8, 0, 1) * np.clip((1.0 - r) / 0.1, 0, 1)
    save_png("fx_flare", np.dstack([np.ones_like(a)] * 3 + [a]))


def tex_smoke():
    n = 512
    out = np.zeros((2 * n, 2 * n, 4))
    x, y = grid(n)
    r = np.hypot(x, y)
    for k in range(4):
        big = fbm(n, 3, 5, 100 + k * 9)
        fine = fbm(n, 10, 4, 300 + k * 7)
        rr = r + (big - 0.5) * 0.55 + (fine - 0.5) * 0.12
        dens = np.clip((0.86 - rr) / 0.42, 0, 1) ** 1.25 * (0.55 + 0.45 * big)
        dens = blur(dens, 1)
        # Licht von oben links: Helligkeit aus dem Dichtegradienten
        gy, gx = np.gradient(blur(dens, 3))
        light = np.clip(0.78 - (gx * -0.6 + gy * -0.8) * 9.0, 0.45, 1.0)
        shade = light * (0.82 + 0.18 * fine)
        tile = np.dstack([shade, shade, shade, np.clip(dens * 1.15, 0, 1)])
        oy, ox = (k // 2) * n, (k % 2) * n
        out[oy:oy + n, ox:ox + n] = tile
    save_png("fx_smoke", out)


def tex_chips():
    """Splitter als Partikelbild: kantige Polygone mit Licht-/Schattenkante (für ferne Trümmer)."""
    n = 256
    out = np.zeros((2 * n, 2 * n, 4))
    rng = np.random.default_rng(5)
    for k in range(4):
        c = Canvas(n)
        k_pts = int(rng.integers(5, 8))
        ang = np.sort(rng.random(k_pts) * math.tau)
        rad = 0.55 + rng.random(k_pts) * 0.35
        px = np.cos(ang) * rad
        py = np.sin(ang) * rad * (0.6 + rng.random() * 0.4)
        inside = np.ones((n, n), bool)
        for i in range(k_pts):
            x0, y0, x1, y1 = px[i], py[i], px[(i + 1) % k_pts], py[(i + 1) % k_pts]
            inside &= ((x1 - x0) * (c.y - y0) - (y1 - y0) * (c.x - x0)) >= 0
        a = blur(inside.astype(float), 1)
        shade = np.clip(0.7 + (c.x * -0.3 + c.y * -0.4), 0.35, 1.0)
        out[(k // 2) * n:(k // 2) * n + n, (k % 2) * n:(k % 2) * n + n] = np.dstack([shade, shade, shade, a])
    save_png("fx_chips", out)


# ------------------------------------------------------------------ Magiekreise
def tex_runes():
    n = 1024
    w = 0.0065
    # A – Ainz: Doppelring, Runenband, Skala, Siebenstern mit Knotenkreisen, inneres Runenband, Hexagramm
    rng = np.random.default_rng(11)
    c = Canvas(n)
    c.ring(0.975, w * 1.6)
    c.ring(0.935, w)
    c.rune_band(0.80, 0.935, 40, w * 0.9, rng)
    c.ring(0.80, w * 1.3)
    c.ring(0.775, w * 0.7)
    c.ticks(0.715, 0.765, 144, w * 0.5, 6, 0.775)
    c.ring(0.705, w)
    pts = c.polygram(0.705, 7, 3, w * 1.1, rot=-math.pi / 2)
    c.polygram(0.705, 7, 2, w * 0.6, rot=-math.pi / 2)
    for (px, py) in pts:
        c.circle(px, py, 0.055, w)
        c.disc(px, py, 0.018)
    c.ring(0.44, w * 1.2)
    c.ring(0.415, w * 0.6)
    c.rune_band(0.30, 0.415, 18, w * 0.85, rng, rot=0.1)
    c.ring(0.295, w)
    c.polygram(0.295, 6, 2, w * 0.9, rot=math.pi / 2)
    c.ring(0.12, w)
    c.disc(0, 0, 0.035)
    save_png("fx_rune_a", np.dstack([np.ones_like(c.a)] * 3 + [c.a]))

    # B – Gegner/Priester: kantiger Achtstern, schmales Runenband, gestrichelte Ringe
    rng = np.random.default_rng(23)
    c = Canvas(n)
    c.ring(0.96, w * 2.0)
    dash = (np.sin(c.ang * 48) > 0.2).astype(float)
    cov = np.clip((w * 0.5 - np.abs(c.r - 0.915)) / c.px + 0.5, 0, 1) * dash
    np.maximum(c.a, cov, out=c.a)
    c.rune_band(0.78, 0.9, 28, w, rng)
    c.ring(0.775, w)
    c.polygram(0.775, 8, 3, w, rot=math.pi / 8)
    c.polygram(0.775, 4, 1, w * 1.4, rot=0.0)
    c.polygram(0.775, 4, 1, w * 1.4, rot=math.pi / 4)
    c.ring(0.36, w * 1.4)
    c.rune_band(0.24, 0.355, 12, w, rng)
    c.ring(0.235, w)
    c.circle(0, 0, 0.09, w)
    save_png("fx_rune_b", np.dstack([np.ones_like(c.a)] * 3 + [c.a]))

    # C – Superrang: viele schmale Bänder, Zwölfstern, Skalen, innere Sonne
    rng = np.random.default_rng(37)
    c = Canvas(n)
    for r0 in (0.985, 0.955):
        c.ring(r0, w * 0.8)
    c.rune_band(0.86, 0.955, 60, w * 0.75, rng)
    c.ring(0.86, w)
    c.ticks(0.815, 0.85, 240, w * 0.4, 10, 0.86)
    c.ring(0.81, w * 0.8)
    c.rune_band(0.72, 0.81, 44, w * 0.7, rng, rot=0.04)
    c.ring(0.715, w * 1.2)
    pts = c.polygram(0.715, 12, 5, w * 0.8)
    c.polygram(0.715, 12, 3, w * 0.5)
    for (px, py) in pts:
        c.circle(px, py, 0.035, w * 0.8)
    c.ring(0.5, w)
    c.ring(0.475, w * 0.6)
    c.rune_band(0.38, 0.475, 26, w * 0.7, rng, rot=0.2)
    c.ring(0.375, w)
    c.ticks(0.12, 0.33, 24, w * 0.7)
    c.ring(0.12, w * 1.2)
    c.disc(0, 0, 0.05)
    save_png("fx_rune_c", np.dstack([np.ones_like(c.a)] * 3 + [c.a]))


# ------------------------------------------------------------------ Shader-Rauschen
def tex_noise():
    n = 256
    r = fbm(n, 4, 5, 1)
    g = fbm(n, 8, 4, 2)
    b = ridged(n, 6, 4, 3)
    a = fbm(n, 16, 3, 4)
    norm = lambda v: (v - v.min()) / (v.max() - v.min() + 1e-9)
    save_png("fx_noise", np.dstack([norm(r), norm(g), norm(b), norm(a)]))


# ------------------------------------------------------------------ Bodenmarken (Decals)
def tex_scorch():
    n = 512
    x, y = grid(n)
    r = np.hypot(x, y)
    big = fbm(n, 4, 5, 51)
    fine = fbm(n, 16, 3, 52)
    ang = np.arctan2(y, x)
    streak = 0.5 + 0.5 * np.sin(ang * 23 + big * 6.0) * np.sin(ang * 7 - fine * 3)
    rr = r + (big - 0.5) * 0.5 - streak * 0.08 * r
    a = np.clip((0.9 - rr) / 0.45, 0, 1) ** 1.2
    char = 0.03 + 0.07 * fine + 0.05 * smooth(0.2, 0.8, rr)
    col = np.dstack([char * 1.05, char * 0.92, char * 0.82])
    save_png("decal_scorch", np.dstack([col, np.clip(a * 0.95, 0, 1)]))
    ember = smooth(0.62, 0.8, fbm(n, 20, 3, 53)) * smooth(0.55, 0.15, r)
    save_png("decal_scorch_emit", np.dstack([ember, ember * 0.35, ember * 0.06, np.ones_like(ember)]))


def tex_blood():
    n = 512
    rng = np.random.default_rng(61)
    for k in range(4):
        c = Canvas(n)
        big = fbm(n, 5, 4, 70 + k)
        rr = c.r / (0.42 + 0.12 * rng.random()) + (big - 0.5) * 0.9
        main = np.clip((1.0 - rr) / 0.08, 0, 1)
        drops = Canvas(n)
        for _ in range(int(rng.integers(16, 30))):
            a = rng.random() * math.tau
            d = 0.38 + rng.random() * 0.52
            s = 0.01 + rng.random() * 0.035 * (1.15 - d)
            # Tropfen als Komet: rund am äußeren Ende, zur Mitte hin spitz auslaufend
            tail = 0.04 + rng.random() * 0.16
            steps = 9
            for i in range(steps):
                t = i / (steps - 1)
                dd = d - tail * t
                drops.disc(math.cos(a) * dd, math.sin(a) * dd, s * (1.0 - 0.85 * t))
        a = np.clip(np.maximum(main, drops.a), 0, 1)
        dark = 0.55 + 0.45 * fbm(n, 12, 3, 80 + k)
        col = np.dstack([0.32 * dark, 0.012 * dark, 0.01 * dark])
        # Decals nutzen immer die ganze Textur → vier Einzelbilder (gleiche ORM-Karte: nass glänzend)
        save_png("decal_blood_%d" % k, np.dstack([col, a]))
        if k == 0:
            save_png("decal_blood_orm", np.dstack([np.ones_like(a), np.full_like(a, 0.18), np.zeros_like(a)]))


def tex_frost():
    n = 512
    x, y = grid(n)
    r = np.hypot(x, y)
    veins = ridged(n, 6, 5, 91)
    fine = ridged(n, 18, 3, 92)
    big = fbm(n, 4, 4, 93)
    rr = r + (big - 0.5) * 0.45
    mask = np.clip((0.92 - rr) / 0.35, 0, 1)
    crystal = np.clip(smooth(0.45, 0.85, veins) * 0.8 + smooth(0.6, 0.95, fine) * 0.5, 0, 1)
    a = np.clip(mask * (0.25 + crystal * 0.75), 0, 1)
    tint = 0.78 + 0.22 * crystal
    save_png("decal_frost", np.dstack([tint * 0.86, tint * 0.93, tint, a]))


def tex_crack():
    n = 512
    rng = np.random.default_rng(101)
    c = Canvas(n)
    depth = np.zeros((n, n))

    def crack(p, ang, length, w, depth_lvl):
        steps = int(length / 0.03)
        for _ in range(steps):
            ang += rng.normal(0, 0.28)
            q = (p[0] + math.cos(ang) * 0.03, p[1] + math.sin(ang) * 0.03)
            c.seg(p, q, w)
            p = q
            w *= 0.985
            if depth_lvl < 2 and rng.random() < 0.07:
                crack(p, ang + rng.choice([-1, 1]) * rng.uniform(0.5, 1.1), length * 0.45, w * 0.7, depth_lvl + 1)

    for i in range(9):
        a = math.tau * i / 9 + rng.uniform(-0.25, 0.25)
        crack((math.cos(a) * 0.06, math.sin(a) * 0.06), a, rng.uniform(0.55, 0.9), 0.014, 0)
    crater = np.clip(1.0 - c.r / 0.22, 0, 1) ** 1.5
    depth = np.maximum(c.a, crater * 0.6)
    noise = fbm(n, 12, 3, 102)
    a = np.clip(np.maximum(c.a, crater * 0.9) + smooth(0.75, 0.2, c.r) * 0.35 * noise, 0, 1) * np.clip((0.98 - c.r) / 0.1, 0, 1)
    col = 0.08 + 0.1 * (1.0 - depth) * noise
    save_png("decal_crack", np.dstack([col * 1.05, col, col * 0.92, a]))
    h = blur(1.0 - depth, 1)
    gy, gx = np.gradient(h)
    nx, ny = -gx * 18.0, gy * 18.0           # OpenGL-Konvention (Grün = oben)
    nz = np.ones_like(nx)
    ln = np.sqrt(nx * nx + ny * ny + nz * nz)
    save_png("decal_crack_n", np.dstack([nx / ln * 0.5 + 0.5, ny / ln * 0.5 + 0.5, nz / ln * 0.5 + 0.5]))


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    print("Effekt-Texturen ->", os.path.normpath(OUT))
    tex_dot()
    tex_streak()
    tex_flare()
    tex_smoke()
    tex_chips()
    tex_runes()
    tex_noise()
    tex_scorch()
    tex_blood()
    tex_frost()
    tex_crack()
