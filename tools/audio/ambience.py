"""
Synthetisiert die Umgebungsklänge der Orte (assets/audio/ambience/<art>.ogg) – vollständig prozedural, nahtlos
geschleift (jeder Klang ist 24 s lang und endet, wie er beginnt):

  forest      Wind in Kronen, Vogelgezwitscher, Specht, Blätterrascheln
  jungle      dichtes Insektenzirpen, exotische Vögel, Tropfen
  village     leichter Wind, Hühner, Hammerschläge aus der Ferne, Stimmen, Vögel
  town        Stimmengewirr des Marktes, Karren, Hämmer, Glocke in der Ferne, Tauben
  cemetery    Nachtwind, Eule, Grillen, knarrende Äste
  swamp       Frösche, Wasser, Mücken, Blubbern
  lava        tiefes Grollen, Knistern, Zischen
  glacier     eisiger Wind, Knacken des Eises
  mountain    Höhenwind, ferne Dohlen
  battlefield Wind über der Ebene, Krähen, flatternde Banner
  interior    Kaminknistern, gedämpftes Stimmengemurmel, Klirren
  hall        tiefer Raumklang der Großen Grabes (Thronsaal, Bibliothek, Schatzkammer): Drone, Flackern, ferne Tropfen
  tombs       Tropfen, Hall, Flüstern der Gruft

Aufruf (Python mit numpy, ffmpeg im PATH):
  "C:/Tools/Blender/4.2/python/bin/python.exe" tools/audio/ambience.py
"""
import math
import os
import subprocess
import tempfile
import wave

import numpy as np

SR = 44100
DUR = 24.0
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "assets", "audio", "ambience")
rng = np.random.default_rng(606)
N = int(DUR * SR)
T = np.arange(N) / SR


# ------------------------------------------------------------------ Bausteine
def band(x, lo=None, hi=None, order=2):
    n = len(x)
    M = 1 << int(math.ceil(math.log2(max(n * 2, 64))))
    X = np.fft.rfft(x, M)
    f = np.fft.rfftfreq(M, 1.0 / SR)
    H = np.ones_like(f)
    if hi:
        H *= 1.0 / np.sqrt(1.0 + (f / hi) ** (2 * order))
    if lo:
        H *= 1.0 / np.sqrt(1.0 + (lo / np.maximum(f, 1e-3)) ** (2 * order))
    return np.fft.irfft(X * H, M)[:n]


def noise(lo=None, hi=None, order=2, n=N):
    return band(rng.standard_normal(n), lo, hi, order)


def loopable(x, fade=1.5):
    """Nahtlos: das Ende wird über das Startstück geblendet (Crossfade), danach ist Schluss = Anfang."""
    k = int(fade * SR)
    y = x.copy()
    w = np.linspace(0.0, 1.0, k)
    y[-k:] = x[-k:] * (1.0 - w) + x[:k] * w
    return y


def slow_lfo(rate, depth, offset=1.0, phase=None):
    """Langsame Schwankung (Böen, Wellen) – periodisch in DUR, damit die Schleife sauber bleibt."""
    cycles = max(1, round(rate * DUR))
    ph = rng.uniform(0, 6.28) if phase is None else phase
    return offset + depth * np.sin(2 * math.pi * cycles * T / DUR + ph)


def env_at(buf, sig, at, gain=1.0):
    i = int(at * SR) % len(buf)
    j = min(len(buf), i + len(sig))
    buf[i:j] += sig[: j - i] * gain
    rest = len(sig) - (j - i)
    if rest > 0:                         # über das Ende hinaus: vorn weiter (Schleife)
        buf[:rest] += sig[j - i:] * gain


def tone(dur, f0, f1=None, kind="sin", vib=0.0, vrate=5.0):
    t = np.arange(int(dur * SR)) / SR
    f1 = f0 if f1 is None else f1
    f = f0 + (f1 - f0) * (t / dur) + vib * f0 * np.sin(2 * math.pi * vrate * t)
    ph = np.cumsum(2 * math.pi * f / SR)
    if kind == "saw":
        return 2.0 * ((ph / (2 * math.pi)) % 1.0) - 1.0
    if kind == "tri":
        return 2.0 * np.abs(2.0 * ((ph / (2 * math.pi)) % 1.0) - 1.0) - 1.0
    return np.sin(ph)


def ad(dur, a=0.01, d=0.2, sustain=0.0, r=0.1):
    t = np.arange(int(dur * SR)) / SR
    e = np.ones_like(t)
    a_n = max(1, int(a * SR))
    r_n = max(1, int(r * SR))
    e[:a_n] = np.linspace(0, 1, a_n)
    mid = np.exp(-np.clip(t - a, 0, None) / max(d, 1e-3))
    e = e * np.maximum(mid, sustain)
    e[-r_n:] *= np.linspace(1, 0, r_n)
    return e


def reverb(x, secs=1.2, wet=0.25, dark=0.5):
    n_ir = int(secs * SR)
    t = np.arange(n_ir) / SR
    ir = rng.standard_normal(n_ir) * np.exp(-t * 6.9 / secs)
    ir = band(ir, None, 2500 * (1.0 - dark) + 600, 1)
    ir[: int(0.012 * SR)] = 0.0
    M = 1 << int(math.ceil(math.log2(len(x) + n_ir)))
    y = np.fft.irfft(np.fft.rfft(x, M) * np.fft.rfft(ir, M), M)[: len(x) + n_ir]
    y = y / (np.max(np.abs(y)) + 1e-9) * np.max(np.abs(x))
    out = x.copy()
    out += y[: len(x)] * wet
    out[: n_ir] += y[len(x):] * wet          # Hallfahne in den Anfang (Schleife)
    return out


def norm(x, peak=0.5):
    return x / (np.max(np.abs(x)) + 1e-9) * peak


def write_ogg(name, x, peak=0.5):
    x = norm(loopable(x), peak)
    pcm = (np.clip(x, -1.0, 1.0) * 32767.0).astype(np.int16)
    tmp = os.path.join(tempfile.gettempdir(), "overlord_amb_%s.wav" % name)
    with wave.open(tmp, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())
    out = os.path.join(OUT, name + ".ogg")
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", tmp, "-c:a", "libvorbis", "-q:a", "4", out], check=True)
    os.remove(tmp)
    print("  %-12s %.0f s" % (name, len(x) / SR))


# ------------------------------------------------------------------ Elemente
def wind(lo=80, hi=900, gust=0.5, base=0.5):
    x = noise(lo, hi, 2)
    g = slow_lfo(0.12, gust, base) * slow_lfo(0.31, 0.25, 1.0)
    return x * g


def bird(f0, f1, dur=0.12, chirps=3, gap=0.08, vib=0.02):
    out = np.zeros(int((dur + gap) * chirps * SR) + 10)
    for k in range(chirps):
        s = tone(dur, f0 * rng.uniform(0.95, 1.05), f1 * rng.uniform(0.95, 1.05), vib=vib, vrate=40) * ad(dur, 0.01, 0.08, 0.3, 0.03)
        i = int(k * (dur + gap) * SR)
        out[i:i + len(s)] += s
    return band(out, 800, 9000, 1)


def scatter(buf, maker, count, gain, spread=DUR):
    for _ in range(count):
        env_at(buf, maker(), rng.uniform(0, spread), gain * rng.uniform(0.6, 1.0))


def crackle(rate, lo=800, hi=7000):
    x = np.zeros(N)
    k = rng.random(N) < rate / SR
    x[k] = rng.standard_normal(k.sum()) * 3.0
    return band(x, lo, hi, 2)


def murmur(voices=24, lo=180, hi=900):
    """Stimmengewirr: viele schmale Rauschbänder mit silbenartigem Rhythmus."""
    out = np.zeros(N)
    for _ in range(voices):
        fc = rng.uniform(lo, hi)
        v = noise(fc * 0.8, fc * 1.25, 2)
        syl = np.clip(np.sin(2 * math.pi * rng.uniform(3.5, 6.0) * T + rng.uniform(0, 6.28)), 0, 1) ** 1.5
        phrase = np.clip(np.sin(2 * math.pi * rng.uniform(0.08, 0.2) * T + rng.uniform(0, 6.28)), 0, 1)
        out += v * syl * phrase * rng.uniform(0.4, 1.0)
    return out


def hammer():
    d = 0.5
    t = np.arange(int(d * SR)) / SR
    body = np.sin(2 * math.pi * 1900 * t) * np.exp(-t / 0.05) + np.sin(2 * math.pi * 3300 * t) * np.exp(-t / 0.03) * 0.5
    hit = band(rng.standard_normal(len(t)), 1500, 8000) * np.exp(-t / 0.012)
    return (body + hit) * 0.5


def bell(f=620.0, dur=3.0):
    t = np.arange(int(dur * SR)) / SR
    return (np.sin(2 * math.pi * f * t) * np.exp(-t / 1.4) + np.sin(2 * math.pi * f * 2.76 * t) * np.exp(-t / 0.5) * 0.4) * 0.5


def crow():
    d = rng.uniform(0.25, 0.4)
    s = tone(d, 520, 380, kind="saw", vib=0.06, vrate=28) * ad(d, 0.02, 0.4, 0.5, 0.08)
    return band(s, 300, 2500, 1) * 0.6


def owl():
    out = np.zeros(int(1.2 * SR))
    for k, (f, d) in enumerate([(330, 0.25), (330, 0.2), (300, 0.5)]):
        s = tone(d, f, f * 0.96) * ad(d, 0.04, 0.3, 0.5, 0.08)
        i = int((0.0 + k * 0.32) * SR)
        out[i:i + len(s)] += s
    return band(out, 150, 1500, 1) * 0.6


def frog():
    d = rng.uniform(0.15, 0.3)
    s = tone(d, 160, 120, kind="saw", vib=0.05, vrate=22) * ad(d, 0.02, 0.2, 0.4, 0.05)
    return band(s, 90, 1200, 1) * 0.5


def drip():
    d = 0.25
    t = np.arange(int(d * SR)) / SR
    f = rng.uniform(1800, 3200)
    return np.sin(2 * math.pi * f * t * (1 + 0.3 * np.exp(-t / 0.02))) * np.exp(-t / 0.06) * 0.6


def creak():
    d = rng.uniform(0.6, 1.4)
    s = tone(d, rng.uniform(120, 240), rng.uniform(90, 200), kind="saw", vib=0.04, vrate=3.0) * ad(d, 0.15, 0.5, 0.5, 0.2)
    return band(s, 80, 1800, 1) * 0.35


def chicken():
    out = np.zeros(int(1.0 * SR))
    for k in range(rng.integers(3, 6)):
        d = 0.09
        s = tone(d, 700, 520, kind="saw", vib=0.1, vrate=30) * ad(d, 0.01, 0.06, 0.3, 0.02)
        i = int(k * 0.14 * SR)
        out[i:i + len(s)] += s
    return band(out, 400, 3500, 1) * 0.4


def insects(n=14, lo=3000, hi=6500):
    out = np.zeros(N)
    for _ in range(n):
        f = rng.uniform(lo, hi)
        rate = rng.uniform(12, 30)
        carrier = np.sin(2 * math.pi * f * T)
        gate = (np.sin(2 * math.pi * rate * T + rng.uniform(0, 6.28)) > 0.6).astype(float)
        phrase = np.clip(np.sin(2 * math.pi * rng.uniform(0.05, 0.15) * T + rng.uniform(0, 6.28)), 0, 1)
        out += carrier * gate * phrase * rng.uniform(0.2, 0.6)
    return out


# ------------------------------------------------------------------ Orte
def amb_forest():
    x = wind(90, 700, 0.5, 0.45) * 0.7
    leaves = noise(2500, 7000, 2) * slow_lfo(0.14, 0.6, 0.5) * slow_lfo(0.9, 0.4, 0.6) * 0.18
    b = np.zeros(N)
    scatter(b, lambda: bird(2600, 3400, 0.09, rng.integers(2, 5), 0.07), 16, 0.35)
    scatter(b, lambda: bird(1900, 2300, 0.18, 1, 0.1, 0.03), 7, 0.3)
    scatter(b, lambda: bird(4200, 3100, 0.06, rng.integers(5, 9), 0.05), 5, 0.22)
    scatter(b, lambda: np.tile(band(rng.standard_normal(int(0.02 * SR)), 1200, 4000) * np.exp(-np.arange(int(0.02 * SR)) / (0.004 * SR)), 9), 4, 0.5)  # Specht
    return reverb(x + leaves + b, 1.5, 0.2, 0.6)


def amb_jungle():
    x = wind(100, 500, 0.3, 0.3) * 0.4
    ins = insects(18, 2800, 7000) * 0.5
    b = np.zeros(N)
    scatter(b, lambda: bird(1500, 2600, 0.25, 2, 0.2, 0.06), 10, 0.4)
    scatter(b, lambda: bird(900, 700, 0.4, 1, 0.1, 0.1), 5, 0.35)
    scatter(b, drip, 18, 0.3)
    return reverb(x + ins + b, 1.8, 0.3, 0.6)


def amb_village():
    x = wind(90, 600, 0.4, 0.4) * 0.45
    b = np.zeros(N)
    scatter(b, lambda: bird(2600, 3400, 0.09, rng.integers(2, 5), 0.07), 8, 0.3)
    scatter(b, chicken, 6, 0.35)
    scatter(b, hammer, 9, 0.3)
    m = band(murmur(10, 160, 700), 150, 1200) * 0.12
    return reverb(x + b + m, 1.0, 0.15, 0.6)


def amb_town():
    x = wind(90, 500, 0.3, 0.3) * 0.3
    m = band(murmur(32, 160, 900), 150, 1600) * 0.3
    b = np.zeros(N)
    scatter(b, hammer, 10, 0.25)
    scatter(b, lambda: bird(1100, 900, 0.2, 2, 0.15, 0.04), 8, 0.2)     # Tauben
    scatter(b, lambda: band(rng.standard_normal(int(2.2 * SR)), 60, 400) * ad(2.2, 0.5, 1.0, 0.6, 0.5) * 0.5, 4, 0.3)  # Karren
    env_at(b, bell(620, 4.0), 5.0, 0.35)
    env_at(b, bell(620, 4.0), 7.2, 0.3)
    return reverb(x + m + b, 1.4, 0.25, 0.55)


def amb_cemetery():
    x = wind(60, 400, 0.6, 0.4) * 0.6
    cr = insects(6, 3800, 4800) * 0.12
    b = np.zeros(N)
    scatter(b, owl, 3, 0.45)
    scatter(b, creak, 6, 0.4)
    return reverb(x + cr + b, 2.2, 0.3, 0.7)


def amb_swamp():
    x = wind(80, 400, 0.3, 0.3) * 0.3
    water = noise(400, 2200, 2) * slow_lfo(0.25, 0.4, 0.5) * 0.12
    b = np.zeros(N)
    scatter(b, frog, 26, 0.35)
    scatter(b, drip, 10, 0.25)
    scatter(b, lambda: tone(0.5, 55, 40) * ad(0.5, 0.05, 0.2, 0.2, 0.1) * 0.5, 6, 0.5)   # Blubbern
    mos = insects(4, 600, 900) * 0.05
    return reverb(x + water + b + mos, 1.6, 0.25, 0.7)


def amb_lava():
    rumble = noise(25, 110, 2) * slow_lfo(0.1, 0.5, 0.8) * 2.5
    cr = crackle(70, 600, 5000) * 0.25
    hiss = noise(2000, 8000, 2) * slow_lfo(0.2, 0.5, 0.5) * 0.08
    b = np.zeros(N)
    scatter(b, lambda: tone(0.8, 70, 45) * ad(0.8, 0.1, 0.4, 0.2, 0.2) * 0.8, 5, 0.6)
    return reverb(rumble + cr + hiss + b, 2.5, 0.3, 0.8)


def amb_glacier():
    x = wind(120, 1600, 0.6, 0.5) * 0.7
    whistle = tone(DUR, 900, 900, vib=0.08, vrate=0.3) * slow_lfo(0.18, 0.5, 0.5) * 0.04
    b = np.zeros(N)
    scatter(b, lambda: band(rng.standard_normal(int(0.6 * SR)), 200, 2500) * ad(0.6, 0.005, 0.15, 0.2, 0.3) * 0.7, 6, 0.4)  # Eis knackt
    return reverb(x + whistle + b, 2.0, 0.3, 0.6)


def amb_mountain():
    x = wind(100, 1200, 0.6, 0.5) * 0.6
    b = np.zeros(N)
    scatter(b, lambda: bird(1300, 1100, 0.15, 2, 0.12, 0.05), 6, 0.2)
    return reverb(x + b, 2.4, 0.3, 0.6)


def amb_battlefield():
    x = wind(70, 500, 0.6, 0.45) * 0.65
    flap = crackle(14, 200, 1500) * slow_lfo(0.12, 0.6, 0.5) * 0.3
    b = np.zeros(N)
    scatter(b, crow, 12, 0.4)
    return reverb(x + flap + b, 2.0, 0.3, 0.7)


def amb_interior():
    fire = crackle(45, 500, 6000) * 0.2 + noise(60, 300, 2) * slow_lfo(0.3, 0.4, 0.5) * 0.25
    m = band(murmur(16, 150, 800), 140, 1400) * 0.22
    b = np.zeros(N)
    scatter(b, lambda: tone(0.4, rng.uniform(2200, 3200)) * ad(0.4, 0.002, 0.12, 0.1, 0.1) * 0.3, 6, 0.3)   # Klirren
    scatter(b, creak, 3, 0.2)
    return reverb(fire + m + b, 0.9, 0.2, 0.6)


def amb_hall():
    drone = (tone(DUR, 55) + tone(DUR, 82.5) * 0.5 + tone(DUR, 110.5, vib=0.003, vrate=0.2) * 0.3) * slow_lfo(0.08, 0.2, 0.8) * 0.25
    air = noise(200, 1200, 2) * slow_lfo(0.1, 0.4, 0.5) * 0.08
    flame = crackle(20, 400, 4000) * 0.08
    b = np.zeros(N)
    scatter(b, drip, 6, 0.15)
    return reverb(drone + air + flame + b, 3.0, 0.4, 0.5)


def amb_tombs():
    air = noise(80, 500, 2) * slow_lfo(0.09, 0.5, 0.5) * 0.3
    b = np.zeros(N)
    scatter(b, drip, 16, 0.3)
    scatter(b, creak, 4, 0.25)
    whisper = band(murmur(6, 1200, 3000), 1000, 5000) * 0.05
    return reverb(air + b + whisper, 3.5, 0.45, 0.6)


def amb_meadow():
    """Grasland: Wind im Gras, Lerche, Grillen – offen und weit."""
    x = wind(90, 900, 0.5, 0.45) * 0.6
    grass = noise(1500, 5000, 2) * slow_lfo(0.14, 0.6, 0.5) * slow_lfo(1.1, 0.4, 0.6) * 0.1
    b = np.zeros(N)
    scatter(b, lambda: bird(3200, 4200, 0.07, rng.integers(6, 12), 0.04, 0.03), 5, 0.25)   # Lerche
    scatter(b, lambda: bird(2600, 3400, 0.09, rng.integers(2, 4), 0.07), 6, 0.2)
    cr = insects(5, 3800, 4600) * 0.06
    return reverb(x + grass + b + cr, 1.8, 0.2, 0.6)


def amb_home():
    """Stube/Laden: Herdfeuer, Holz, das arbeitet, draußen leiser Wind – kein Stimmengewirr."""
    fire = crackle(35, 500, 6000) * 0.18 + noise(60, 300, 2) * slow_lfo(0.3, 0.4, 0.5) * 0.22
    outside = wind(80, 500, 0.5, 0.4) * 0.08
    b = np.zeros(N)
    scatter(b, creak, 5, 0.2)
    scatter(b, lambda: tone(0.3, rng.uniform(1800, 2600)) * ad(0.3, 0.002, 0.1, 0.1, 0.1) * 0.25, 3, 0.25)
    return reverb(fire + outside + b, 0.7, 0.18, 0.6)


def amb_church():
    """Tempel: leiser Chor-Teppich (Quinten), Kerzenflackern, ferne Glocke, Schritte im Hall."""
    chord = np.zeros(N)
    for f, g in [(110.0, 0.5), (164.8, 0.35), (220.0, 0.3), (329.6, 0.18), (440.0, 0.1)]:
        chord += tone(DUR, f, vib=0.004, vrate=0.17) * g + tone(DUR, f * 1.003) * g * 0.5
    chord *= slow_lfo(0.06, 0.3, 0.6) * 0.09
    breath = noise(300, 1800, 2) * slow_lfo(0.11, 0.5, 0.5) * 0.04
    flame = crackle(12, 400, 3000) * 0.05
    b = np.zeros(N)
    env_at(b, bell(520, 5.0), 9.0, 0.18)
    scatter(b, lambda: band(rng.standard_normal(int(0.12 * SR)), 150, 900) * ad(0.12, 0.004, 0.05, 0.1, 0.03) * 0.5, 6, 0.18)   # Schritte
    return reverb(chord + breath + flame + b, 4.5, 0.5, 0.45)


def amb_forge():
    """Schmiede: Blasebalg, Glut, Hammerschläge im Takt, Zischen im Löschtrog, Kettenklirren."""
    glow = crackle(60, 500, 6000) * 0.22 + noise(50, 250, 2) * slow_lfo(0.35, 0.5, 0.5) * 0.3
    bellows = noise(200, 1200, 2) * np.clip(np.sin(2 * math.pi * 0.5 * T), 0, 1) ** 2 * 0.12
    b = np.zeros(N)
    for start in (2.0, 11.5, 17.0):
        for k in range(rng.integers(5, 9)):
            env_at(b, hammer(), start + k * rng.uniform(0.42, 0.5), 0.55)
    scatter(b, lambda: noise(2000, 9000, 2, int(1.2 * SR)) * ad(1.2, 0.01, 0.4, 0.2, 0.3) * 0.5, 2, 0.4)   # Zischen
    scatter(b, lambda: tone(0.35, rng.uniform(1800, 2600)) * ad(0.35, 0.002, 0.1, 0.1, 0.1) * 0.3, 5, 0.25)  # Ketten
    return reverb(glow + bellows + b, 1.1, 0.22, 0.6)


if __name__ == "__main__":
    import sys
    os.makedirs(OUT, exist_ok=True)
    print("Umgebungsklaenge ->", os.path.normpath(OUT))
    only = set(sys.argv[1:])
    for name, fn in [("forest", amb_forest), ("jungle", amb_jungle), ("village", amb_village), ("town", amb_town),
                     ("cemetery", amb_cemetery), ("swamp", amb_swamp), ("lava", amb_lava), ("glacier", amb_glacier),
                     ("mountain", amb_mountain), ("battlefield", amb_battlefield), ("interior", amb_interior),
                     ("hall", amb_hall), ("tombs", amb_tombs), ("meadow", amb_meadow), ("home", amb_home),
                     ("church", amb_church), ("forge", amb_forge)]:
        if only and name not in only:
            continue
        write_ogg(name, fn())
