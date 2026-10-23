"""
Synthetisiert die Kampf- und Zaubergeräusche (assets/audio/sfx/combat/*.ogg) – vollständig prozedural, ohne
fremde Aufnahmen (keine Lizenzfragen):

  Schwünge      gefiltertes Rauschen mit wandernder Mittenfrequenz (Klinge pfeift, Stab brummt)
  Treffer       Schichten aus Körperschlag (fallender Sinus), Klatschen (Bandrauschen), Knacken (Resonanzimpulse)
  Metall        Modalsynthese mit unharmonischen Teiltönen (Rüstung, Block, Parade), Kratzgeräusch
  Zauber        Glissandi, Glocken, Chorflächen, Explosionen (Tiefdruck + Rauschen + Knistern), Blitze
  Raum          Faltungshall mit synthetischer Impulsantwort (der Ortshall kommt zusätzlich im Spiel dazu)
Varianten (<name>_1…n) verhindern, dass sich Treffer wiederholt anhören.

Aufruf (jede Python-Version mit numpy, z. B. die von Blender; ffmpeg mit libvorbis im PATH):
  "C:/Tools/Blender/4.2/python/bin/python.exe" tools/audio/combat_sfx.py
"""
import math
import os
import subprocess
import tempfile
import wave

import numpy as np

SR = 44100
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "assets", "audio", "sfx", "combat")
rng = np.random.default_rng(1977)


# ------------------------------------------------------------------ Grundbausteine
def tt(dur):
    return np.arange(int(dur * SR)) / SR


def white(n):
    return rng.standard_normal(n)


def band(x, lo=None, hi=None, order=2):
    """Nullphasen-Filter im Frequenzbereich (für stationäres Rauschen; Hüllkurve danach)."""
    n = len(x)
    N = 1 << int(math.ceil(math.log2(max(n * 2, 64))))
    X = np.fft.rfft(x, N)
    f = np.fft.rfftfreq(N, 1.0 / SR)
    H = np.ones_like(f)
    if hi:
        H *= 1.0 / np.sqrt(1.0 + (f / hi) ** (2 * order))
    if lo:
        H *= 1.0 / np.sqrt(1.0 + (lo / np.maximum(f, 1e-3)) ** (2 * order))
    return np.fft.irfft(X * H, N)[:n]


def noise(dur, lo=None, hi=None, order=2):
    return band(white(int(dur * SR)), lo, hi, order)


def norm(x, peak=1.0):
    m = np.max(np.abs(x)) + 1e-12
    return x / m * peak


def exp_env(dur, decay, attack=0.002):
    t = tt(dur)
    e = np.exp(-t / decay)
    a = int(attack * SR)
    if a > 1:
        e[:a] *= np.linspace(0.0, 1.0, a)
    return e


def bell_env(dur, peak=0.4, sharp=2.0):
    """Anschwellen bis peak (Anteil der Dauer), dann Abklingen – Form eines Schwungs."""
    t = np.linspace(0.0, 1.0, int(dur * SR))
    up = (t / peak) ** sharp
    down = np.exp(-((t - peak) / (1.0 - peak)) * 4.0)
    return np.where(t < peak, up, down)


def sweep(dur, f_of_t, q=3.0, lo_cut=60.0):
    """Rauschen durch einen Bandpass, dessen Mitte f_of_t(t) wandert (STFT, Überlappung 75 %)."""
    n = int(dur * SR)
    frame, hop = 1024, 256
    x = white(n + frame)
    win = np.hanning(frame)
    out = np.zeros(n + frame)
    f = np.fft.rfftfreq(frame, 1.0 / SR)
    for start in range(0, n, hop):
        seg = x[start:start + frame] * win
        X = np.fft.rfft(seg)
        fc = max(80.0, f_of_t(start / SR))
        bw = fc / q
        H = 1.0 / (1.0 + ((f - fc) / bw) ** 2)
        H *= 1.0 / np.sqrt(1.0 + (lo_cut / np.maximum(f, 1e-3)) ** 4)
        out[start:start + frame] += np.fft.irfft(X * H, frame) * win
    return out[:n] / 1.5


def modes(dur, freqs, decays, amps, jitter=0.0):
    t = tt(dur)
    out = np.zeros_like(t)
    for f, d, a in zip(freqs, decays, amps):
        f = f * (1.0 + rng.uniform(-jitter, jitter))
        out += a * np.exp(-t / d) * np.sin(2 * math.pi * f * t + rng.uniform(0, math.tau))
    return out


def tone_sweep(dur, f0, f1, shape=1.0, kind="sin"):
    t = np.linspace(0.0, 1.0, int(dur * SR))
    f = f0 * (f1 / f0) ** (t ** shape) if f0 > 0 and f1 > 0 else f0 + (f1 - f0) * t
    ph = np.cumsum(2 * math.pi * f / SR)
    if kind == "saw":
        return 2.0 * ((ph / (2 * math.pi)) % 1.0) - 1.0
    return np.sin(ph)


def ks(freq, dur, decay=0.996, bright=0.5):
    """Karplus-Strong-Saite (Bogensehne, Zupfen)."""
    n = int(dur * SR)
    p = max(2, int(SR / freq))
    buf = list(rng.uniform(-1, 1, p))
    out = np.zeros(n)
    i = 0
    for k in range(n):
        a = buf[i]
        b = buf[(i + 1) % p]
        v = decay * (bright * a + (1.0 - bright) * (a + b) * 0.5)
        buf[i] = v
        out[k] = a
        i = (i + 1) % p
    return out


def pings(dur, count, f_lo, f_hi, decay_lo, decay_hi, spread, density_decay=0.25, amp=1.0):
    """Viele kurze Resonanzen (Splitter, Scherben, Knochenknacken), zeitlich gestreut."""
    out = np.zeros(int(dur * SR))
    for _ in range(count):
        at = rng.exponential(density_decay) * spread
        if at >= dur - 0.01:
            continue
        f = math.exp(rng.uniform(math.log(f_lo), math.log(f_hi)))
        d = rng.uniform(decay_lo, decay_hi)
        ln = min(int(d * 6 * SR), len(out) - int(at * SR))
        if ln <= 8:
            continue
        t = np.arange(ln) / SR
        s = np.exp(-t / d) * np.sin(2 * math.pi * f * t + rng.uniform(0, math.tau)) * rng.uniform(0.3, 1.0) * amp
        i = int(at * SR)
        out[i:i + ln] += s
    return out


def crackle(dur, rate, lo=800, hi=6000, decay=0.5):
    """Knistern: spärliche Impulse, gefiltert, abklingend."""
    n = int(dur * SR)
    x = np.zeros(n)
    k = rng.random(n) < rate / SR
    x[k] = rng.standard_normal(k.sum()) * 3.0
    x = band(x, lo, hi, 2)
    return x * np.exp(-tt(dur) / decay)


def thump(dur, f0, f1, decay, click=0.3):
    s = tone_sweep(dur, f0, f1, 0.35) * exp_env(dur, decay, 0.001)
    if click > 0:
        c = noise(min(dur, 0.02), 800, 5000) * exp_env(min(dur, 0.02), 0.004)
        s[:len(c)] += c * click
    return s


def place(buf, sig, at):
    i = int(at * SR)
    if i >= len(buf):
        return buf
    j = min(len(buf), i + len(sig))
    s = np.array(sig[:j - i], dtype=np.float64)
    k = min(len(s), int(0.008 * SR))
    if k > 1:
        s[-k:] *= np.linspace(1.0, 0.0, k)     # weiches Ende: kein Knacken beim Abschneiden
    buf[i:j] += s
    return buf


def mix(dur, *layers):
    out = np.zeros(int(dur * SR))
    for at, sig, gain in layers:
        place(out, sig * gain, at)
    k = int(0.015 * SR)
    out[-k:] *= np.linspace(1.0, 0.0, k)
    return out


def reverb(x, secs=1.2, wet=0.25, dark=0.5):
    n_ir = int(secs * SR)
    t = np.arange(n_ir) / SR
    ir = white(n_ir) * np.exp(-t * 6.9 / secs)
    late = band(ir, None, 2500 * (1.0 - dark) + 600, 1)
    early = band(ir, None, 9000, 1)
    mixw = np.clip(t / (secs * 0.3), 0.0, 1.0)
    ir = early * (1.0 - mixw) + late * mixw
    ir[: int(0.012 * SR)] = 0.0
    N = 1 << int(math.ceil(math.log2(len(x) + n_ir)))
    y = np.fft.irfft(np.fft.rfft(x, N) * np.fft.rfft(ir, N), N)[: len(x) + n_ir]
    y = y / (np.max(np.abs(y)) + 1e-9) * np.max(np.abs(x))
    out = np.zeros(len(x) + n_ir)
    out[: len(x)] += x
    return out + y * wet


def finish(x, peak=0.9, tail=0.02):
    x = np.asarray(x, dtype=np.float64)
    x = x - np.mean(x[: min(len(x), 64)]) * 0.0
    n = int(tail * SR)
    if len(x) > n:
        x[-n:] *= np.linspace(1.0, 0.0, n)
    # Stille am Ende kürzen
    a = np.abs(x)
    thr = np.max(a) * 0.0015
    last = len(x) - 1
    while last > 0 and a[last] < thr:
        last -= 1
    x = x[: min(len(x), last + int(0.03 * SR))]
    return norm(x, peak)


def write_ogg(name, x, peak=0.9):
    x = finish(x, peak)
    pcm = (np.clip(x, -1.0, 1.0) * 32767.0).astype(np.int16)
    tmp = os.path.join(tempfile.gettempdir(), "overlord_sfx_%s.wav" % name)
    with wave.open(tmp, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())
    out = os.path.join(OUT, name + ".ogg")
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", tmp, "-c:a", "libvorbis", "-q:a", "5", out], check=True)
    os.remove(tmp)
    print("  %-18s %.2f s" % (name, len(x) / SR))


# ------------------------------------------------------------------ Schwünge
def swing(dur, f0, f1, f2, q, body=0.0, whistle=0.0, peak=0.42):
    def fc(t):
        k = t / dur
        if k < peak:
            return f0 + (f1 - f0) * (k / peak) ** 1.5
        return f1 + (f2 - f1) * ((k - peak) / (1 - peak)) ** 0.7
    s = sweep(dur, fc, q) * bell_env(dur, peak, 2.2)
    if whistle > 0:
        s += sweep(dur, lambda t: fc(t) * 1.9, q * 6) * bell_env(dur, peak, 3.0) * whistle
    if body > 0:
        s += noise(dur, 60, 260) * bell_env(dur, peak + 0.05, 2.0) * body
    return s


def sfx_swings():
    for i in range(3):
        d = rng.uniform(0.24, 0.32)
        write_ogg("swing_light_%d" % (i + 1), swing(d, rng.uniform(500, 700), rng.uniform(2100, 2900), rng.uniform(800, 1100), 2.2, 0.15, 0.25), 0.75)
    for i in range(2):
        d = rng.uniform(0.42, 0.5)
        s = swing(d, rng.uniform(250, 340), rng.uniform(1100, 1400), rng.uniform(380, 480), 1.6, 0.55, 0.12, 0.48)
        write_ogg("swing_heavy_%d" % (i + 1), s, 0.85)
    for i in range(2):
        d = rng.uniform(0.28, 0.34)
        write_ogg("swing_staff_%d" % (i + 1), swing(d, rng.uniform(350, 450), rng.uniform(1300, 1700), rng.uniform(500, 650), 1.8, 0.35, 0.0), 0.7)


# ------------------------------------------------------------------ Treffer
def sfx_hits():
    for i in range(3):
        d = 0.38
        s = mix(d,
                (0.0, thump(0.25, rng.uniform(120, 150), 52, 0.07, 0.0), 1.0),
                (0.0, noise(0.06, 500, 3200) * exp_env(0.06, 0.012), 0.9),
                (0.004, noise(0.2, 180, 900) * exp_env(0.2, 0.05) * (0.6 + 0.4 * np.sin(2 * math.pi * rng.uniform(25, 40) * tt(0.2))), 0.7),
                (0.0, pings(0.12, 6, 900, 2600, 0.004, 0.012, 0.03), 0.25))
        write_ogg("hit_flesh_%d" % (i + 1), reverb(s, 0.5, 0.12, 0.7), 0.9)
    for i in range(3):
        d = 0.45
        s = mix(d,
                (0.0, pings(0.25, rng.integers(4, 7), 1800, 4200, 0.006, 0.016, 0.08, 0.3), 1.0),
                (0.0, modes(0.2, [rng.uniform(480, 560), rng.uniform(1250, 1400), rng.uniform(2050, 2300)], [0.05, 0.035, 0.02], [1.0, 0.6, 0.35]), 0.7),
                (0.0, noise(0.3, 1500, 7000) * exp_env(0.3, 0.06), 0.25),
                (0.0, thump(0.15, 140, 70, 0.04, 0.0), 0.5))
        write_ogg("hit_bone_%d" % (i + 1), reverb(s, 0.5, 0.14, 0.6), 0.85)
    ratios = [1.0, 2.31, 3.93, 5.41, 7.12, 9.07]
    for i in range(3):
        f0 = rng.uniform(640, 920)
        s = mix(0.7,
                (0.0, noise(0.012, 1000, 12000) * exp_env(0.012, 0.002), 1.0),
                (0.0, modes(0.7, [f0 * r for r in ratios], [0.32, 0.22, 0.16, 0.11, 0.08, 0.05], [1.0, 0.7, 0.55, 0.4, 0.3, 0.2], 0.01), 0.8),
                (0.0, thump(0.2, 160, 80, 0.05, 0.0), 0.55),
                (0.0, noise(0.15, 3000, 9000) * exp_env(0.15, 0.03), 0.2))
        write_ogg("hit_armor_%d" % (i + 1), reverb(s, 0.7, 0.16, 0.5), 0.85)
    for i in range(2):
        s = mix(0.6,
                (0.0, thump(0.3, 110, 45, 0.09, 0.4), 1.0),
                (0.0, noise(0.35, 120, 1600) * exp_env(0.35, 0.07), 0.6),
                (0.01, pings(0.45, 18, 900, 3500, 0.004, 0.015, 0.4, 0.35), 0.35))
        write_ogg("hit_stone_%d" % (i + 1), reverb(s, 0.6, 0.15, 0.6), 0.85)
    for i in range(2):
        f0 = rng.uniform(1100, 1300)
        s = mix(0.9,
                (0.0, modes(0.9, [f0, f0 * 2.01, f0 * 2.98, f0 * 4.2], [0.4, 0.3, 0.2, 0.12], [1.0, 0.5, 0.35, 0.2]), 0.6),
                (0.0, pings(0.6, 14, 3000, 9000, 0.02, 0.08, 0.3, 0.3), 0.3),
                (0.0, noise(0.3, 2000, 8000) * bell_env(0.3, 0.15), 0.35),
                (0.0, thump(0.15, 180, 90, 0.04, 0.2), 0.5))
        write_ogg("hit_holy_%d" % (i + 1), reverb(s, 1.2, 0.3, 0.3), 0.8)
    for i in range(2):
        s = mix(0.6,
                (0.0, noise(0.02, 2000, 14000) * exp_env(0.02, 0.004), 0.8),
                (0.0, pings(0.5, 30, 2500, 9500, 0.006, 0.04, 0.25, 0.25), 0.8),
                (0.0, thump(0.18, 150, 70, 0.05, 0.0), 0.5))
        write_ogg("hit_ice_%d" % (i + 1), reverb(s, 0.8, 0.2, 0.3), 0.85)


# ------------------------------------------------------------------ Abwehr
def sfx_defense():
    ratios = [1.0, 2.13, 3.28, 4.9, 6.6]
    for i in range(3):
        f0 = rng.uniform(380, 520)
        s = mix(0.9,
                (0.0, noise(0.015, 800, 10000) * exp_env(0.015, 0.003), 1.0),
                (0.0, modes(0.9, [f0 * r for r in ratios], [0.5, 0.35, 0.25, 0.15, 0.1], [1.0, 0.75, 0.5, 0.35, 0.25], 0.01), 0.85),
                (0.0, thump(0.25, 130, 60, 0.07, 0.0), 0.7))
        write_ogg("block_%d" % (i + 1), reverb(s, 0.8, 0.2, 0.5), 0.9)
    for i in range(2):
        f0 = rng.uniform(1150, 1400)
        s = mix(1.6,
                (0.0, noise(0.01, 2000, 15000) * exp_env(0.01, 0.002), 1.0),
                (0.0, modes(1.6, [f0, f0 * 1.51, f0 * 2.4, f0 * 3.3, f0 * 4.7], [1.2, 0.8, 0.55, 0.35, 0.22], [1.0, 0.6, 0.45, 0.3, 0.2], 0.005), 0.75),
                (0.01, noise(0.35, 3000, 7500) * exp_env(0.35, 0.09), 0.35),
                (0.0, thump(0.35, 90, 45, 0.12, 0.0), 0.6))
        write_ogg("parry_%d" % (i + 1), reverb(s, 1.8, 0.35, 0.35), 0.9)
    s = mix(1.1,
            (0.0, modes(0.9, [430 * r for r in ratios], [0.4, 0.3, 0.2, 0.15, 0.1], [1.0, 0.7, 0.5, 0.35, 0.25]), 0.8),
            (0.0, noise(0.6, 200, 4000) * exp_env(0.6, 0.14), 0.8),
            (0.0, thump(0.6, 80, 32, 0.2, 0.3), 1.0),
            (0.04, pings(0.5, 20, 2000, 8000, 0.01, 0.05, 0.25), 0.3))
    write_ogg("guardbreak", reverb(s, 1.0, 0.25, 0.5), 0.92)
    s = mix(1.1,
            (0.0, pings(0.9, 70, 2200, 11000, 0.01, 0.07, 0.35, 0.22), 1.0),
            (0.0, tone_sweep(0.8, 2400, 700, 0.6) * exp_env(0.8, 0.25) * 0.25, 1.0),
            (0.0, noise(0.04, 3000, 14000) * exp_env(0.04, 0.008), 0.6))
    write_ogg("shield_break", reverb(s, 1.4, 0.3, 0.25), 0.85)
    s = mix(0.6,
            (0.0, noise(0.012, 1500, 14000) * exp_env(0.012, 0.002), 1.0),
            (0.005, tone_sweep(0.22, 900, 2600, 0.5) * exp_env(0.22, 0.09), 0.5),
            (0.0, thump(0.25, 70, 40, 0.08, 0.0), 0.9))
    write_ogg("crit", reverb(s, 0.6, 0.2, 0.4), 0.85)
    for i in range(2):
        d = rng.uniform(0.3, 0.36)
        s = swing(d, 220, rng.uniform(900, 1200), 400, 1.4, 0.25, 0.0, 0.35)
        s = place(s, noise(0.08, 150, 1200) * exp_env(0.08, 0.025), d * 0.75)
        write_ogg("dodge_%d" % (i + 1), s, 0.6)
    s = mix(0.3,
            (0.0, noise(0.006, 2000, 9000) * exp_env(0.006, 0.0015), 0.6),
            (0.01, modes(0.28, [1760, 2640], [0.08, 0.05], [1.0, 0.5]), 0.5))
    write_ogg("lock_on", s, 0.5)


# ------------------------------------------------------------------ Warnungen, Gegner, Tod
def sfx_enemy():
    s = mix(0.5,
            (0.0, modes(0.45, [3150, 4720, 6900], [0.18, 0.1, 0.06], [1.0, 0.5, 0.25]), 0.7),
            (0.0, noise(0.12, 4000, 11000) * bell_env(0.12, 0.2), 0.25))
    write_ogg("telegraph", reverb(s, 0.8, 0.25, 0.3), 0.6)
    swell = noise(0.18, 100, 1500) * np.linspace(0, 1, int(0.18 * SR)) ** 2
    horn = tone_sweep(0.55, 82, 74, 1.0, "saw")
    horn = band(horn, 60, 700, 2) * exp_env(0.55, 0.3, 0.03)
    growl = noise(0.5, 70, 400) * exp_env(0.5, 0.25) * (0.6 + 0.4 * np.sin(2 * math.pi * 31 * tt(0.5)))
    s = mix(0.8, (0.0, swell, 0.5), (0.15, horn, 1.0), (0.15, growl, 0.6))
    write_ogg("telegraph_red", reverb(s, 1.0, 0.25, 0.6), 0.75)
    stab = band(tone_sweep(0.5, 110, 104, 1.0, "saw") + tone_sweep(0.5, 165, 160, 1.0, "saw") * 0.6, 80, 1200, 2) * exp_env(0.5, 0.22, 0.01)
    drum = mix(0.6, (0.0, thump(0.6, 95, 50, 0.18, 0.5), 1.0), (0.0, noise(0.4, 80, 900) * exp_env(0.4, 0.08), 0.4))
    write_ogg("enemy_alert", reverb(mix(0.8, (0.0, stab, 0.7), (0.0, drum, 1.0)), 1.0, 0.25, 0.5), 0.8)
    s = mix(1.4,
            (0.0, pings(1.0, 40, 450, 1700, 0.02, 0.07, 0.8, 0.35), 1.0),
            (0.0, noise(0.8, 200, 2500) * exp_env(0.8, 0.2), 0.3),
            (0.05, thump(0.3, 100, 50, 0.08, 0.0), 0.5))
    write_ogg("bone_collapse", reverb(s, 0.8, 0.18, 0.6), 0.8)
    s = mix(1.0,
            (0.0, thump(0.5, 85, 40, 0.14, 0.2), 1.0),
            (0.0, noise(0.4, 60, 450) * exp_env(0.4, 0.09), 0.7),
            (0.08, pings(0.4, 6, 700, 2500, 0.02, 0.06, 0.25), 0.25))
    write_ogg("death_body", reverb(s, 0.8, 0.15, 0.6), 0.8)
    boom = thump(1.4, 55, 28, 0.55, 0.3)
    rumble = noise(1.4, 30, 260) * exp_env(1.4, 0.45)
    chord = np.zeros(int(1.4 * SR))
    for f in (110, 165, 220, 277):
        chord += band(tone_sweep(1.4, f, f * 0.995, 1.0, "saw"), 80, 1500, 1) * exp_env(1.4, 0.5, 0.05) * 0.25
    write_ogg("kill_big", reverb(mix(1.6, (0.0, boom, 1.0), (0.0, rumble, 0.6), (0.02, chord, 0.45)), 1.8, 0.3, 0.6), 0.9)
    s = mix(1.4,
            (0.0, noise(0.9, 120, 1600) * bell_env(0.9, 0.6), 0.5),
            (0.2, tone_sweep(1.0, 140, 70, 0.8) * exp_env(1.0, 0.4, 0.2), 0.7),
            (0.25, pings(0.8, 18, 300, 1200, 0.05, 0.2, 0.5), 0.3))
    write_ogg("summon", reverb(s, 1.5, 0.35, 0.5), 0.8)


# ------------------------------------------------------------------ Zauber
def shimmer(dur, f_lo, f_hi, n=5, rise=True, decay=0.5):
    out = np.zeros(int(dur * SR))
    for k in range(n):
        f0 = f_lo * (1 + k * 0.25) * rng.uniform(0.98, 1.02)
        f1 = f_hi * (1 + k * 0.25) * rng.uniform(0.98, 1.02)
        a, b = (f0, f1) if rise else (f1, f0)
        out += tone_sweep(dur, a, b, 0.7) * (1.0 / (k + 1))
    return out * bell_env(dur, 0.55, 1.5) * 0.6


def explosion(dur, f_boom=70, bright=3000, crack=1.0, crackle_rate=60):
    boom = thump(dur, f_boom, f_boom * 0.45, dur * 0.35, 0.0)
    roar = sweep(dur, lambda t: bright * math.exp(-t * 4.0) + 180, 0.9) * exp_env(dur, dur * 0.3, 0.004)
    cr = noise(0.05, 500, 12000) * exp_env(0.05, 0.01)
    kn = crackle(dur, crackle_rate, 900, 7000, dur * 0.45)
    return mix(dur, (0.0, boom, 1.0), (0.0, roar, 0.8), (0.0, cr, crack), (0.03, kn, 0.4))


def sfx_spells():
    write_ogg("cast_small", reverb(shimmer(0.55, 520, 1150, 5) + noise(0.55, 1500, 6000) * bell_env(0.55, 0.6) * 0.15, 1.0, 0.3, 0.3), 0.6)
    hum = band(tone_sweep(1.3, 98, 147, 1.2, "saw"), 60, 900, 2) * bell_env(1.3, 0.8, 1.2)
    write_ogg("cast_big", reverb(mix(1.3, (0.0, hum, 0.6), (0.2, shimmer(1.1, 400, 1300, 6), 0.8), (0.0, noise(1.3, 800, 5000) * bell_env(1.3, 0.85, 2.0), 0.2)), 1.4, 0.3, 0.4), 0.7)
    scrape = (noise(0.45, 2800, 7500) * bell_env(0.45, 0.3, 1.2)) + modes(0.45, [3900, 5300], [0.2, 0.12], [0.3, 0.2])
    write_ogg("tech_charge", reverb(scrape + swing(0.45, 200, 800, 300, 1.4, 0.3) * 0.6, 0.6, 0.2, 0.4), 0.6)
    # Feuer
    ign = sweep(0.6, lambda t: 400 + 2600 * (t / 0.6) ** 0.6, 1.2) * bell_env(0.6, 0.3, 1.0)
    write_ogg("fire_launch", reverb(mix(0.7, (0.0, ign, 1.0), (0.0, crackle(0.6, 80, 1200, 6000, 0.3), 0.4), (0.0, thump(0.2, 90, 60, 0.06, 0.0), 0.4)), 0.7, 0.2, 0.5), 0.8)
    for i in range(2):
        write_ogg("fire_explode_%d" % (i + 1), reverb(explosion(rng.uniform(1.4, 1.7), rng.uniform(62, 78), 3200, 1.0, 70), 1.6, 0.3, 0.55), 0.95)
    roar = noise(1.6, 80, 1400) * bell_env(1.6, 0.3, 1.0) * (0.75 + 0.25 * np.sin(2 * math.pi * 7 * tt(1.6)))
    write_ogg("fire_wall", reverb(mix(1.7, (0.0, roar, 1.0), (0.0, crackle(1.6, 140, 1000, 7000, 0.8), 0.45), (0.0, sweep(0.5, lambda t: 300 + 2500 * t / 0.5, 1.0) * bell_env(0.5, 0.5), 0.6)), 1.2, 0.25, 0.5), 0.9)
    # Eis
    write_ogg("ice_launch", reverb(mix(0.6, (0.0, sweep(0.5, lambda t: 2500 + 3500 * t, 4.0) * bell_env(0.5, 0.35), 0.8), (0.0, modes(0.5, [2637, 3951], [0.25, 0.15], [1.0, 0.5]), 0.3)), 0.9, 0.3, 0.2), 0.7)
    for i in range(2):
        s = mix(1.1,
                (0.0, noise(0.03, 2000, 15000) * exp_env(0.03, 0.006), 0.9),
                (0.0, pings(0.9, 80, 2000, 10500, 0.01, 0.08, 0.3, 0.25), 1.0),
                (0.0, thump(0.3, 120, 55, 0.09, 0.0), 0.7),
                (0.0, noise(0.6, 4000, 12000) * exp_env(0.6, 0.15), 0.2))
        write_ogg("ice_shatter_%d" % (i + 1), reverb(s, 1.2, 0.3, 0.25), 0.9)
    # Schatten / negative Energie
    vw = tone_sweep(0.7, 95, 55, 0.6) * (0.7 + 0.3 * np.sin(2 * math.pi * 11 * tt(0.7))) * bell_env(0.7, 0.3, 1.2)
    whisper = band(noise(0.7, 300, 3500) * (0.5 + 0.5 * np.sin(2 * math.pi * 5 * tt(0.7))), 600, 2400, 2) * bell_env(0.7, 0.5)
    write_ogg("dark_launch", reverb(mix(0.8, (0.0, vw, 1.0), (0.0, whisper, 0.35)), 1.2, 0.3, 0.6), 0.75)
    for i in range(2):
        rev = noise(0.18, 200, 4000) * np.linspace(0, 1, int(0.18 * SR)) ** 3
        s = mix(1.2, (0.0, rev, 0.6), (0.17, thump(0.6, 70, 32, 0.2, 0.2), 1.0), (0.17, noise(0.9, 40, 400) * exp_env(0.9, 0.3), 0.6),
                (0.2, whisper[: int(0.6 * SR)] * 0.6, 0.6))
        write_ogg("dark_impact_%d" % (i + 1), reverb(s, 1.4, 0.3, 0.65), 0.9)
    s = mix(1.3, (0.0, noise(0.6, 150, 3000) * np.linspace(0, 1, int(0.6 * SR)) ** 2, 0.6),
            (0.55, thump(0.7, 60, 30, 0.25, 0.3), 1.0), (0.55, sweep(0.7, lambda t: 2500 * math.exp(-t * 4) + 200, 1.0) * exp_env(0.7, 0.25), 0.7))
    write_ogg("shockwave", reverb(s, 1.2, 0.25, 0.6), 0.92)
    # Licht
    write_ogg("holy_launch", reverb(mix(0.6, (0.0, modes(0.6, [1568, 2349, 3136], [0.3, 0.2, 0.15], [1.0, 0.6, 0.4]), 0.6), (0.0, noise(0.5, 2500, 9000) * bell_env(0.5, 0.3), 0.3)), 1.2, 0.35, 0.25), 0.7)
    for i in range(2):
        bell = modes(1.6, [523, 659, 784, 1046, 1318], [1.0, 0.8, 0.7, 0.5, 0.35], [1.0, 0.7, 0.6, 0.45, 0.3], 0.004)
        s = mix(1.6, (0.0, bell, 0.7), (0.0, thump(0.5, 110, 55, 0.15, 0.4), 0.9), (0.0, pings(1.2, 30, 3000, 10000, 0.03, 0.1, 0.6), 0.25),
                (0.0, noise(0.6, 1500, 8000) * exp_env(0.6, 0.15), 0.3))
        write_ogg("holy_impact_%d" % (i + 1), reverb(s, 2.2, 0.4, 0.3), 0.9)
    # Blut
    gurgle = sweep(0.5, lambda t: 500 + 1500 * t / 0.5, 2.0) * bell_env(0.5, 0.35) * (0.6 + 0.4 * np.sin(2 * math.pi * 28 * tt(0.5)))
    write_ogg("blood_launch", reverb(gurgle, 0.6, 0.2, 0.6), 0.7)
    splat = noise(0.4, 150, 2500) * exp_env(0.4, 0.07) * (0.6 + 0.4 * np.sin(2 * math.pi * 45 * tt(0.4)))
    write_ogg("blood_impact", reverb(mix(0.6, (0.0, splat, 1.0), (0.0, thump(0.3, 110, 55, 0.08, 0.0), 0.7)), 0.6, 0.15, 0.6), 0.85)
    # Pfeile
    for i in range(2):
        tw = ks(rng.uniform(110, 150), 0.35, 0.993, 0.3) * exp_env(0.35, 0.09)
        wh = sweep(0.45, lambda t: 3000 - 1500 * t / 0.45, 3.0) * bell_env(0.45, 0.25, 1.0)
        write_ogg("arrow_shot_%d" % (i + 1), mix(0.5, (0.0, tw, 1.0), (0.02, wh, 0.4)), 0.7)
    for i in range(2):
        s = mix(0.35, (0.0, modes(0.3, [rng.uniform(260, 320), rng.uniform(680, 760), rng.uniform(1250, 1400)], [0.06, 0.04, 0.025], [1.0, 0.6, 0.35]), 1.0),
                (0.0, noise(0.04, 800, 6000) * exp_env(0.04, 0.008), 0.5))
        write_ogg("arrow_hit_%d" % (i + 1), reverb(s, 0.4, 0.12, 0.6), 0.8)
    # Techniken
    w = np.zeros(int(0.95 * SR))
    for k in range(4):
        place(w, swing(0.26, 400 + k * 80, 1800 + k * 250, 700, 1.8, 0.3, 0.2), k * 0.17)
    write_ogg("whirl", reverb(w, 0.6, 0.15, 0.5), 0.85)
    t = tt(1.4)
    f = 150 * np.exp(-t * 0.5) + 70
    ph = np.cumsum(2 * math.pi * f * (1 + 0.03 * np.sin(2 * math.pi * 6 * t)) / SR)
    src = (2.0 * ((ph / (2 * math.pi)) % 1.0) - 1.0) + noise(1.4, 100, 3000) * 0.5
    growl = band(src, 300, 900, 2) + band(src, 1100, 1700, 2) * 0.6 + band(src, 80, 300, 2) * 0.8
    growl *= bell_env(1.4, 0.25, 1.0) * (0.75 + 0.25 * np.sin(2 * math.pi * 19 * t))
    write_ogg("roar", reverb(growl, 1.4, 0.3, 0.6), 0.9)
    write_ogg("shield_up", reverb(mix(1.1, (0.0, shimmer(1.0, 300, 900, 6), 1.0), (0.0, pings(1.0, 25, 2500, 8000, 0.03, 0.1, 0.8), 0.2),
                                       (0.1, band(tone_sweep(0.9, 220, 330, 1.0, "saw"), 100, 1200, 2) * bell_env(0.9, 0.3), 0.15)), 1.6, 0.35, 0.3), 0.7)
    rattle = np.zeros(int(1.0 * SR))
    for k in range(14):
        place(rattle, modes(0.12, [rng.uniform(1800, 2600), rng.uniform(3500, 4800)], [0.03, 0.02], [1.0, 0.5]), 0.05 + k * 0.045 + rng.uniform(-0.01, 0.01))
    chime = shimmer(1.0, 1400, 600, 4, False)
    write_ogg("bind", reverb(mix(1.1, (0.0, chime, 0.8), (0.0, rattle, 0.5), (0.0, tone_sweep(1.0, 70, 65) * bell_env(1.0, 0.3) * 0.5, 1.0)), 1.4, 0.3, 0.4), 0.75)
    hb = mix(0.5, (0.0, thump(0.18, 62, 40, 0.05, 0.0), 1.0), (0.14, thump(0.2, 70, 42, 0.06, 0.0), 0.8),
             (0.0, noise(0.3, 40, 180) * exp_env(0.3, 0.06), 0.4))
    write_ogg("heart_beat", reverb(hb, 0.6, 0.18, 0.7), 0.95)
    sq = sweep(0.5, lambda t: 300 + 1800 * (t / 0.5), 3.0) * exp_env(0.5, 0.15) * (0.6 + 0.4 * np.sin(2 * math.pi * 55 * tt(0.5)))
    s = mix(1.3, (0.0, sq, 0.9), (0.0, pings(0.3, 12, 800, 2800, 0.004, 0.012, 0.08, 0.3), 0.5), (0.02, thump(0.8, 60, 28, 0.3, 0.3), 1.0),
            (0.0, noise(0.6, 100, 1500) * exp_env(0.6, 0.12), 0.4))
    write_ogg("heart_crush", reverb(s, 1.6, 0.3, 0.6), 0.95)
    s = mix(1.1, (0.0, thump(0.9, 72, 30, 0.3, 0.5), 1.0), (0.0, noise(0.8, 60, 2200) * exp_env(0.8, 0.18), 0.7),
            (0.02, pings(0.9, 35, 700, 3200, 0.005, 0.02, 0.5, 0.3), 0.35), (0.05, noise(0.7, 200, 1500) * bell_env(0.7, 0.2), 0.3))
    write_ogg("leap_land", reverb(s, 1.0, 0.22, 0.6), 0.95)
    for i in range(3):
        crack = noise(0.03, 300, 16000) * exp_env(0.03, 0.006)
        sizzle = noise(0.4, 2500, 12000) * (rng.random(int(0.4 * SR)) < 0.08) * 4.0
        sizzle = band(sizzle, 1500, 9000, 2) * exp_env(0.4, 0.12)
        thunder = noise(1.0, 30, 320) * exp_env(1.0, 0.35, 0.03) * (0.7 + 0.3 * np.sin(2 * math.pi * rng.uniform(5, 9) * tt(1.0)))
        s = mix(1.0, (0.0, crack, 1.0), (0.0, sizzle, 0.6), (0.02, thunder, 0.9), (0.0, noise(0.15, 1000, 8000) * exp_env(0.15, 0.03), 0.6))
        write_ogg("lightning_%d" % (i + 1), reverb(s, 1.2, 0.25, 0.5), 0.92)
    # Superrang: Aufbau und Entladung
    dur = 4.2
    t = tt(dur)
    pad = np.zeros_like(t)
    for f in (110, 138.6, 164.8, 220, 277.2):
        for det in (-0.1, 0.0, 0.1):
            fr = f * 2 ** (det / 12)
            ph = np.cumsum(2 * math.pi * fr * (1 + 0.004 * np.sin(2 * math.pi * rng.uniform(4, 6) * t + rng.uniform(0, 6))) / SR)
            pad += (2.0 * ((ph / (2 * math.pi)) % 1.0) - 1.0)
    pad = band(pad, 400, 1000, 2) + band(pad, 1100, 1500, 2) * 0.5 + band(pad, 80, 350, 2) * 0.5
    pad *= (t / dur) ** 1.6 * 0.12
    rise = sweep(dur, lambda x: 200 + 4000 * (x / dur) ** 2, 1.2) * (t / dur) ** 2.2 * 0.6
    sup = mix(dur + 0.2, (0.0, pad, 1.0), (0.0, rise, 1.0))
    for k, at in enumerate([0.8, 1.8, 2.6, 3.2, 3.6, 3.9]):
        place(sup, thump(0.4, 55, 35, 0.12, 0.0) * (0.4 + 0.12 * k), at)
    for at in (1.0, 2.0, 3.0):
        place(sup, modes(1.2, [392, 588, 784, 1176], [0.9, 0.6, 0.45, 0.3], [1.0, 0.6, 0.5, 0.3]) * 0.25, at)
    write_ogg("super_charge", reverb(sup, 2.0, 0.35, 0.4), 0.85)
    dur = 4.0
    blast = explosion(2.5, 45, 6000, 1.0, 50)
    choir = np.zeros(int(dur * SR))
    t = tt(dur)
    for f in (130.8, 164.8, 196, 261.6, 329.6, 392):
        ph = np.cumsum(2 * math.pi * f * (1 + 0.004 * np.sin(2 * math.pi * 5 * t)) / SR)
        choir += 2.0 * ((ph / (2 * math.pi)) % 1.0) - 1.0
    choir = (band(choir, 450, 950, 2) + band(choir, 1000, 1400, 2) * 0.6) * exp_env(dur, 1.4, 0.05) * 0.15
    bells = modes(dur, [523, 784, 1046, 1568], [2.0, 1.5, 1.1, 0.8], [1.0, 0.7, 0.5, 0.35]) * 0.25
    s = mix(dur, (0.0, blast, 1.0), (0.0, choir, 0.8), (0.0, bells, 0.6), (0.0, noise(dur, 25, 120) * exp_env(dur, 1.2), 0.5))
    write_ogg("super_blast", reverb(s, 3.0, 0.4, 0.5), 0.95)


def sfx_rewards():
    """Belohnungen: Seelen (gläsernes Klingen), Beute (Funkeln), Aufwertung (Akkord), Ring (Metallklang)."""
    global rng
    rng = np.random.default_rng(2024)        # eigene Folge: die übrigen Klänge bleiben unverändert
    penta = [523.3, 587.3, 659.3, 784.0, 880.0, 1046.5, 1174.7]
    for i in range(4):
        f = penta[i + 1]
        bell = modes(0.7, [f, f * 2.01, f * 2.98, f * 4.1], [0.35, 0.22, 0.14, 0.08], [1.0, 0.45, 0.25, 0.12], 0.003)
        air = sweep(0.5, lambda x: 2500 + 3500 * (x / 0.5), 2.0) * bell_env(0.5, 0.35, 2.0) * 0.18
        write_ogg("soul_%d" % (i + 1), reverb(mix(0.7, (0.0, bell, 0.5), (0.0, air, 1.0)), 1.1, 0.35, 0.3), 0.42)
    # Seelen lösen sich aus dem Körper: Hauch, der aufsteigt
    rise = sweep(1.0, lambda x: 300 + 2200 * (x / 1.0) ** 1.4, 1.5) * bell_env(1.0, 0.6, 1.5)
    ghost = shimmer(1.0, 330, 990, 4, True) * 0.5
    write_ogg("soul_burst", reverb(mix(1.0, (0.0, rise, 0.7), (0.05, ghost, 0.6)), 1.4, 0.35, 0.4), 0.55)
    # Beute fällt: dumpfer Aufschlag + Funkeln
    sparkle = pings(0.9, 14, 2600, 7000, 0.05, 0.18, 0.7, 0.4, 0.5)
    drop = mix(1.0, (0.0, thump(0.3, 140, 70, 0.08, 0.2), 0.7), (0.05, sparkle, 0.9), (0.1, shimmer(0.8, 700, 1500, 4), 0.5))
    write_ogg("loot_drop", reverb(drop, 1.2, 0.3, 0.4), 0.7)
    for i in range(2):
        base = penta[i * 2]
        arp = np.zeros(int(0.9 * SR))
        for k, m in enumerate([1.0, 1.25, 1.5, 2.0]):
            place(arp, modes(0.5, [base * m, base * m * 2.0], [0.25, 0.12], [1.0, 0.3]), 0.055 * k)
        glit = pings(0.9, 10, 3000, 8000, 0.04, 0.12, 0.5, 0.5, 0.4)
        write_ogg("loot_pickup_%d" % (i + 1), reverb(mix(0.9, (0.0, arp, 0.8), (0.0, glit, 0.5)), 1.2, 0.3, 0.3), 0.7)
    # Aufwertung im Zauberbuch: aufsteigender Akkord mit Glocken und Hauch
    dur = 2.4
    t = tt(dur)
    chord = np.zeros_like(t)
    for k, f in enumerate([261.6, 329.6, 392.0, 523.3, 659.3]):
        env = np.clip((t - k * 0.08) / 0.05, 0.0, 1.0) * np.exp(-np.clip(t - k * 0.08, 0.0, None) / 1.1)
        ph = np.cumsum(2 * math.pi * f * (1 + 0.003 * np.sin(2 * math.pi * 5.0 * t)) / SR)
        chord += (2.0 * ((ph / (2 * math.pi)) % 1.0) - 1.0) * env
    chord = band(chord, 200, 2400, 2) * 0.22
    bells = modes(dur, [1046.5, 1568.0, 2093.0], [1.2, 0.9, 0.6], [1.0, 0.6, 0.4]) * 0.2
    whoosh = sweep(dur, lambda x: 400 + 5000 * min(1.0, x / 0.8), 1.4) * bell_env(dur, 0.3, 2.0) * 0.25
    write_ogg("rank_up", reverb(mix(dur, (0.0, chord, 1.0), (0.12, bells, 0.8), (0.0, whoosh, 0.6)), 2.2, 0.38, 0.4), 0.8)
    # Ring anlegen: heller Metallklang mit Schimmer
    clink = modes(0.9, [2350, 3620, 5180, 6900], [0.45, 0.3, 0.2, 0.12], [1.0, 0.6, 0.4, 0.25], 0.004)
    write_ogg("ring_equip", reverb(mix(0.9, (0.0, clink, 0.6), (0.02, shimmer(0.8, 900, 1800, 4), 0.4)), 1.0, 0.3, 0.3), 0.6)


def sfx_story2():
    """Große Story-Momente: gefrierender See, Sanduhr, schwarzer Wind, Hufe und Gebrüll der Dunklen Jungen,
    Kriegshorn, Schlachtruf und Jubel einer Menge."""
    global rng
    rng = np.random.default_rng(1010)        # eigene Folge: die übrigen Klänge bleiben unverändert
    # Eis breitet sich aus: Knistern, das anschwillt und weiterwandert, tiefes Ächzen, gläserne Splitter
    dur = 5.0
    t = tt(dur)
    rate_env = np.clip(t / 0.6, 0.0, 1.0) * np.exp(-np.clip(t - 1.2, 0.0, None) / 1.8)
    cr = np.zeros_like(t)
    for lo, hi, gain in ((900, 5000, 1.0), (2500, 9000, 0.6)):
        n = len(t)
        x = np.zeros(n)
        k = rng.random(n) < (420.0 * rate_env) / SR
        x[k] = rng.standard_normal(k.sum()) * 3.0
        cr += band(x, lo, hi, 2) * gain
    groan = sweep(dur, lambda x: 260 - 170 * min(1.0, x / 3.5), 6.0, 40.0) * bell_env(dur, 0.25, 1.5) * 0.9
    glass = pings(dur, 40, 2200, 7500, 0.05, 0.25, 2.2, 0.5, 0.5)
    boom = thump(1.2, 90, 38, 0.35, 0.2)
    write_ogg("freeze_spread", reverb(mix(dur, (0.0, boom, 0.8), (0.0, cr, 0.7), (0.0, groan, 0.6), (0.2, glass, 0.5)), 2.4, 0.4, 0.4), 0.85)
    # Sanduhr zerspringt: Glasregen und ein goldener Glockenton
    shards = pings(1.4, 34, 2600, 9000, 0.03, 0.16, 0.6, 0.3, 0.8)
    chime = modes(1.6, [1568.0, 2349.3, 3136.0, 4186.0], [0.9, 0.7, 0.45, 0.3], [1.0, 0.6, 0.45, 0.25]) * 0.5
    burst = noise(0.12, 3000, 12000) * exp_env(0.12, 0.03)
    write_ogg("hourglass", reverb(mix(1.6, (0.0, burst, 0.6), (0.0, shards, 0.8), (0.02, chime, 0.7)), 1.8, 0.35, 0.3), 0.75)
    # Schwarzer Wind: heulender Sturm, der heranrollt, tiefes Grollen, flüsternde Fläche
    dur = 7.0
    howl = sweep(dur, lambda x: 320 + 520 * math.sin(math.pi * min(1.0, x / 6.0)) + 90 * math.sin(x * 5.0), 5.0, 80.0)
    howl *= bell_env(dur, 0.35, 1.3)
    rumble = noise(dur, 25, 120, 2) * bell_env(dur, 0.3, 1.2) * 2.5
    whisper = sweep(dur, lambda x: 2400 + 900 * math.sin(x * 2.3), 3.0, 600.0) * bell_env(dur, 0.45, 1.5) * 0.35
    write_ogg("black_wind", reverb(mix(dur, (0.0, rumble, 1.0), (0.0, howl, 0.9), (0.3, whisper, 0.6)), 3.0, 0.4, 0.6), 0.9)
    # Huftritt eines Dunklen Jungen: tiefer Schlag, Erde knirscht
    crunch = noise(0.4, 150, 1800) * exp_env(0.4, 0.08) * 0.8
    write_ogg("stomp", reverb(mix(1.0, (0.0, thump(1.0, 55, 26, 0.28, 0.5), 1.0), (0.0, crunch, 0.7)), 1.2, 0.3, 0.6), 0.9)
    # Gebrüll eines Dunklen Jungen: tiefes, gurgelndes Blöken, darüber ein schrilles Meckern, Atem
    dur = 3.4
    t = np.linspace(0.0, 1.0, int(dur * SR))
    f = 78 * (1.0 + 0.25 * np.sin(math.pi * t)) * (1.0 + 0.04 * np.sin(2 * math.pi * 6.5 * t * dur))
    ph = np.cumsum(2 * math.pi * f / SR)
    saw = 2.0 * ((ph / (2 * math.pi)) % 1.0) - 1.0
    growl = saw * (0.6 + 0.4 * np.sin(2 * math.pi * 31.0 * t * dur)) * np.sin(math.pi * np.clip(t * 1.05, 0.0, 1.0)) ** 0.6
    growl = band(growl, 90, 1100, 2)
    fb = 330 * (1.0 + 0.3 * np.sin(math.pi * t)) * (1.0 + 0.06 * np.sin(2 * math.pi * 8.0 * t * dur))
    phb = np.cumsum(2 * math.pi * fb / SR)
    bleat = band(2.0 * ((phb / (2 * math.pi)) % 1.0) - 1.0, 400, 2600, 2) * np.clip(np.sin(math.pi * np.clip((t - 0.15) / 0.6, 0.0, 1.0)), 0.0, 1.0) * 0.35
    breath = noise(dur, 200, 3000) * bell_env(dur, 0.3, 1.2) * 0.25
    write_ogg("dark_young_roar", reverb(mix(dur, (0.0, growl, 1.0), (0.0, bleat, 1.0), (0.0, breath, 1.0)), 3.2, 0.45, 0.55), 0.9)
    # Kriegshorn: tiefer, leicht schwankender Ton mit Obertönen
    dur = 3.0
    t = np.linspace(0.0, 1.0, int(dur * SR))
    f = 98.0 * (1.0 + 0.05 * np.clip(t * 8, 0, 1)) * (1.0 + 0.006 * np.sin(2 * math.pi * 5.0 * t * dur))
    ph = np.cumsum(2 * math.pi * f / SR)
    horn = band(2.0 * ((ph / (2 * math.pi)) % 1.0) - 1.0, 70, 1400, 2)
    env = np.clip(t / 0.08, 0, 1) * np.clip((1.0 - t) / 0.25, 0, 1)
    write_ogg("war_horn", reverb(horn * env, 3.5, 0.5, 0.5), 0.8)
    # Schlachtruf / Jubel einer Menge: viele Stimmen als schmale Rauschbänder mit eigenem Auf und Ab
    for name, dur, bright, claps in (("crowd_roar", 3.5, 0.0, 0), ("crowd_cheer", 4.0, 1.0, 1)):
        t = tt(dur)
        out = np.zeros_like(t)
        for v in range(36):
            fc = rng.uniform(260, 900 + 600 * bright)
            vo = band(white(len(t)), fc * 0.85, fc * 1.18, 2)
            a0 = rng.uniform(0.0, 0.6)
            env = np.clip((t - a0) / 0.3, 0, 1) * np.exp(-np.clip(t - a0 - rng.uniform(0.8, 2.4), 0, None) / 0.6)
            env *= 0.7 + 0.3 * np.sin(2 * math.pi * rng.uniform(2.0, 5.0) * t + rng.uniform(0, 6.28))
            out += vo * env
        if claps:
            out += crackle(dur, 90, 1200, 6000, 3.0) * 1.2
        write_ogg(name, reverb(out, 2.0, 0.35, 0.5), 0.75)


if __name__ == "__main__":
    import sys
    os.makedirs(OUT, exist_ok=True)
    print("Kampfgeräusche ->", os.path.normpath(OUT))
    if len(sys.argv) > 1 and sys.argv[1] == "rewards":
        sfx_rewards()
        sys.exit(0)
    if len(sys.argv) > 1 and sys.argv[1] == "story2":
        sfx_story2()
        sys.exit(0)
    sfx_swings()
    sfx_hits()
    sfx_defense()
    sfx_enemy()
    sfx_spells()
    sfx_rewards()
    sfx_story2()
