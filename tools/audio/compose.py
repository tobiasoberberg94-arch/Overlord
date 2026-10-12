"""
Komponiert und synthetisiert die Musik und Soundeffekte von „Overlord – Herrscher von Nazarick“.

Alles wird prozedural erzeugt (keine fremden Samples → keine Lizenzfragen):
  * Chor-/Streicherflächen aus verstimmten Sägezähnen mit Formantfiltern
  * Glocken (inharmonische Partialtöne), Harfe (Karplus-Strong), Pauken, Drone
  * Faltungshall mit synthetischer Impulsantwort
Die Musikstücke sind nahtlose Loops (Hallfahne wird an den Anfang gefaltet).

Aufruf:  python3 tools/audio/compose.py   → schreibt assets/audio/{music,sfx}/*.ogg
Benötigt: numpy, scipy, ffmpeg (libvorbis)
"""
import os
import subprocess
import tempfile

import numpy as np
from scipy.io import wavfile
from scipy.signal import butter, fftconvolve, sosfilt

SR = 44100
ROOT = os.path.join(os.path.dirname(__file__), "..", "..", "assets", "audio")
rng = np.random.default_rng(41)


# ------------------------------------------------------------------ Grundbausteine
def midi(n):
    return 440.0 * 2 ** ((n - 69) / 12)


def t_axis(dur):
    return np.arange(int(dur * SR)) / SR


def env_adsr(n, a, d, s, r):
    e = np.ones(n) * s
    A, D, R = int(a * SR), int(d * SR), int(r * SR)
    A = min(A, n)
    e[:A] = np.linspace(0, 1, A)
    D = min(D, n - A)
    e[A:A + D] = np.linspace(1, s, D)
    if R > 0 and R < n:
        e[-R:] *= np.linspace(1, 0, R)
    return e


def lowpass(x, f, order=2):
    return sosfilt(butter(order, f, "low", fs=SR, output="sos"), x)


def bandpass(x, lo, hi, order=2):
    return sosfilt(butter(order, [lo, hi], "band", fs=SR, output="sos"), x)


def saw(freq, t, phase=0.0):
    return 2.0 * ((freq * t + phase) % 1.0) - 1.0


def place(buf, sig, start):
    i = int(start * SR)
    if i >= len(buf):
        return
    end = min(len(buf), i + len(sig))
    buf[i:end] += sig[: end - i]


# ------------------------------------------------------------------ Instrumente
def choir(notes, dur, bright=0.5):
    """Chor-„Aah“: verstimmte Sägezähne mit Vibrato durch Formantfilter."""
    t = t_axis(dur)
    out = np.zeros(len(t))
    for n in notes:
        f = midi(n)
        for d in (-0.12, -0.04, 0.05, 0.11):
            vib = 1 + 0.004 * np.sin(2 * np.pi * (5.0 + rng.random()) * t + rng.random() * 6)
            out += saw(f * 2 ** (d / 12) * vib, t, rng.random())
    form = bandpass(out, 500, 900) * 1.0 + bandpass(out, 1000, 1400) * 0.6 * bright + lowpass(out, 400) * 0.5
    return form / (len(notes) * 4)


def strings(notes, dur, cutoff=1800):
    t = t_axis(dur)
    out = np.zeros(len(t))
    for n in notes:
        for d in (-0.08, 0.0, 0.09):
            out += saw(midi(n) * 2 ** (d / 12), t, rng.random())
    return lowpass(out, cutoff) / (len(notes) * 3)


def drone(note, dur):
    t = t_axis(dur)
    f = midi(note)
    x = np.sin(2 * np.pi * f * t) + 0.5 * np.sin(2 * np.pi * f * 2 * t + 1) + 0.25 * saw(f, t)
    x = lowpass(x, 300)
    return x * (0.8 + 0.2 * np.sin(2 * np.pi * 0.05 * t))


def bell(note, dur=4.0, vol=1.0):
    t = t_axis(dur)
    f = midi(note)
    x = np.zeros(len(t))
    for ratio, amp, dec in ((1, 1, 1.4), (2.0, 0.6, 1.0), (2.76, 0.5, 0.8), (5.4, 0.25, 0.5), (8.93, 0.12, 0.3)):
        x += amp * np.sin(2 * np.pi * f * ratio * t) * np.exp(-t / dec)
    return x * vol * 0.35


def harp(note, dur=3.0, vol=1.0):
    """Karplus-Strong-Zupfton."""
    f = midi(note)
    n = int(dur * SR)
    period = max(2, int(SR / f))
    buf = rng.uniform(-1, 1, period)
    blocks = []
    # blockweise statt Sample für Sample (gleicher Klang, um Größenordnungen schneller)
    for _ in range(n // period + 1):
        blocks.append(buf)
        buf = 0.996 * 0.5 * (buf + np.roll(buf, -1))
    out = np.concatenate(blocks)[:n]
    return lowpass(out, 3500) * vol * 0.5


def timpani(note, dur=3.0, vol=1.0):
    t = t_axis(dur)
    f = midi(note) * (1 + 0.15 * np.exp(-t * 20))
    phase = 2 * np.pi * np.cumsum(f) / SR
    x = np.sin(phase) * np.exp(-t / 0.9)
    noise = lowpass(rng.uniform(-1, 1, len(t)), 600) * np.exp(-t / 0.08)
    return (x + 0.6 * noise) * vol * 0.8


def heartbeat(dur=1.0, vol=1.0):
    t = t_axis(dur)
    x = np.zeros(len(t))
    for off, a in ((0.0, 1.0), (0.22, 0.7)):
        tt = np.clip(t - off, 0, None)
        x += a * np.sin(2 * np.pi * 50 * tt) * np.exp(-tt / 0.09) * (t >= off)
    return x * vol


# ------------------------------------------------------------------ Hall & Ausgabe
def impulse(seconds=3.5, seed=0):
    r = np.random.default_rng(seed)
    t = t_axis(seconds)
    ir = r.uniform(-1, 1, len(t)) * np.exp(-t / (seconds / 5.5))
    ir = lowpass(ir, 5000)
    ir[0] = 1.0
    return ir / np.sqrt(np.sum(ir ** 2))


def reverb(mono, wet=0.35, seconds=3.5):
    l = fftconvolve(mono, impulse(seconds, 1))
    r = fftconvolve(mono, impulse(seconds, 2))
    n = len(l)
    dry = np.zeros(n)
    dry[: len(mono)] = mono
    return np.stack([dry * (1 - wet) + l * wet, dry * (1 - wet) + r * wet], axis=1)


def loopify(stereo, loop_len):
    """Hallfahne über das Loop-Ende hinaus wird auf den Anfang gefaltet → nahtloser Loop."""
    n = int(loop_len * SR)
    out = stereo[:n].copy()
    tail = stereo[n:]
    while len(tail):
        k = min(len(tail), n)
        out[:k] += tail[:k]
        tail = tail[k:]
    return out


def write_ogg(stereo, path, peak=0.85, quality=5):
    stereo = stereo / (np.max(np.abs(stereo)) + 1e-9) * peak
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as tmp:
        wavfile.write(tmp.name, SR, (stereo * 32767).astype(np.int16))
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", tmp.name, "-c:a", "libvorbis",
                        "-q:a", str(quality), path], check=True)
    os.unlink(tmp.name)
    print("geschrieben:", os.path.relpath(path, ROOT), f"{len(stereo) / SR:.1f}s")


# ------------------------------------------------------------------ Stücke
# Akkorde als MIDI-Noten (D-Moll-Welt)
Dm = [50, 57, 62, 65]
Bb = [46, 58, 62, 65]
Gm = [43, 55, 62, 67]
A_ = [45, 57, 61, 64]
F_ = [41, 57, 60, 65]
C_ = [48, 55, 60, 64]
Eb = [51, 58, 63, 67]


def title_theme():
    """Erhaben und düster: Chor, Pauken, Glockenmotiv. ~96 s Loop."""
    chords = [Dm, Bb, Gm, A_, Dm, Eb, Gm, A_]
    seg = 12.0
    total = seg * len(chords)
    mix = np.zeros(int((total + 6) * SR))
    for i, ch in enumerate(chords):
        start = i * seg
        c = choir([n + 12 for n in ch[1:]], seg + 3) * env_adsr(int((seg + 3) * SR), 2.5, 1, 0.9, 3)
        place(mix, c * 0.9, start)
        s = strings(ch, seg + 3, 1200) * env_adsr(int((seg + 3) * SR), 3, 1, 0.8, 3)
        place(mix, s * 0.6, start)
        place(mix, drone(ch[0] - 12, seg + 2) * env_adsr(int((seg + 2) * SR), 1, 1, 1, 2) * 0.5, start)
        place(mix, timpani(38, 3, 1.0), start)
        place(mix, timpani(38, 3, 0.5), start + 6)
    # Glockenmotiv (das „Nazarick-Thema“)
    motif = [74, 72, 69, 70, 69, 65, 67, 69]
    for rep in range(4):
        for j, n in enumerate(motif):
            place(mix, bell(n, 5, 0.8), rep * 24 + 3 + j * 1.5)
    return loopify(reverb(mix, 0.4, 4.5), total)


def throne_theme():
    """Ruhig und majestätisch: Flächen, Harfen-Arpeggien, Celesta-Glocken. ~128 s Loop."""
    chords = [Dm, F_, Bb, C_, Dm, Gm, Bb, A_]
    seg = 16.0
    total = seg * len(chords)
    mix = np.zeros(int((total + 6) * SR))
    for i, ch in enumerate(chords):
        start = i * seg
        pad = strings(ch, seg + 4, 900) * env_adsr(int((seg + 4) * SR), 4, 1, 0.85, 4)
        place(mix, pad * 0.55, start)
        place(mix, choir([n + 12 for n in ch[1:3]], seg + 4, 0.3) * env_adsr(int((seg + 4) * SR), 5, 1, 0.7, 4) * 0.35, start)
        place(mix, drone(ch[0] - 12, seg + 2) * env_adsr(int((seg + 2) * SR), 2, 1, 1, 2) * 0.35, start)
        arp = [ch[0] + 12, ch[1] + 12, ch[2] + 12, ch[3] + 12, ch[2] + 24, ch[3] + 12, ch[2] + 12, ch[1] + 12]
        for k in range(16):
            place(mix, harp(arp[k % len(arp)], 2.5, 0.45 if k % 4 else 0.6), start + k * 1.0)
        if i % 2 == 1:
            place(mix, bell(ch[3] + 24, 5, 0.35), start + 8)
    return loopify(reverb(mix, 0.42, 4.0), total)


def tension_theme():
    """Spannung (Story-Ereignisse, Rivalität): Herzschlag, Ostinato, dissonante Streicher. ~64 s Loop."""
    total = 64.0
    mix = np.zeros(int((total + 6) * SR))
    beat = 60 / 70
    tt = 0.0
    while tt < total:
        place(mix, heartbeat(1.0, 0.9), tt)
        tt += beat
    ost = [38, 38, 45, 38, 39, 38, 45, 44]
    for k in range(int(total / 0.5)):
        n = ost[k % len(ost)]
        place(mix, strings([n], 0.45, 700) * env_adsr(int(0.45 * SR), 0.01, 0.1, 0.6, 0.15) * 0.8, k * 0.5)
    for i, ch in enumerate([[50, 56, 62], [49, 55, 61], [50, 57, 63], [48, 54, 60]]):
        s = strings([n + 12 for n in ch], 18, 2200) * env_adsr(int(18 * SR), 4, 1, 0.8, 4)
        place(mix, s * 0.5, i * 16)
        place(mix, timpani(38, 3, 0.8), i * 16)
    return loopify(reverb(mix, 0.3, 3.0), total)


def battle_theme():
    """Schlacht: treibende Pauken-Ostinati, Blechbläser-Stöße, Chor. ~48 s Loop, 132 BPM."""
    bpm = 132
    beat = 60 / bpm
    bars = 26
    total = bars * 4 * beat
    mix = np.zeros(int((total + 6) * SR))
    prog = [Dm, Dm, Bb, A_, Dm, Gm, Bb, A_]
    pattern = [1.0, 0, 0.6, 0.6, 1.0, 0, 0.6, 0.8]
    k = 0
    tt = 0.0
    while tt < total:
        a = pattern[k % len(pattern)]
        if a:
            place(mix, timpani(38 if k % 8 < 4 else 33, 1.2, a), tt)
        place(mix, heartbeat(0.4, 0.25), tt)
        tt += beat / 2
        k += 1
    for b in range(bars):
        ch = prog[b % len(prog)]
        start = b * 4 * beat
        stab = strings([n + 12 for n in ch], 4 * beat + 1, 2600) * env_adsr(int((4 * beat + 1) * SR), 0.02, 0.4, 0.55, 0.6)
        place(mix, stab * 0.8, start)
        place(mix, strings([ch[0] - 12, ch[0]], 0.6, 900) * env_adsr(int(0.6 * SR), 0.005, 0.2, 0.4, 0.2) * 1.2, start + 2 * beat)
        if b % 2 == 0:
            place(mix, choir([n + 12 for n in ch[1:]], 8 * beat + 1, 0.8) * env_adsr(int((8 * beat + 1) * SR), 0.6, 0.5, 0.8, 1.0) * 0.7, start)
    return loopify(reverb(mix, 0.25, 2.2), total)


# ------------------------------------------------------------------ Soundeffekte
def sfx_click():
    t = t_axis(0.09)
    x = np.sin(2 * np.pi * 1800 * t) * np.exp(-t / 0.012) + 0.3 * lowpass(rng.uniform(-1, 1, len(t)), 4000) * np.exp(-t / 0.006)
    return reverb(x, 0.15, 0.4)


def sfx_hover():
    t = t_axis(0.06)
    return reverb(np.sin(2 * np.pi * 2600 * t) * np.exp(-t / 0.01) * 0.3, 0.1, 0.3)


def sfx_page():
    t = t_axis(0.5)
    n = bandpass(rng.uniform(-1, 1, len(t)), 800, 5000) * np.sin(np.pi * t / 0.5) ** 2
    return reverb(n * 0.7, 0.2, 0.8)


def sfx_dispatch():
    x = np.zeros(int(3 * SR))
    for k, n in enumerate([81, 86, 93]):
        place(x, bell(n, 2.5, 0.8), k * 0.12)
    return reverb(x, 0.35, 2.0)


def sfx_gong():
    t = t_axis(5.0)
    x = np.zeros(len(t))
    for ratio, amp in ((1, 1), (1.47, 0.6), (2.09, 0.45), (2.56, 0.3), (3.2, 0.2)):
        x += amp * np.sin(2 * np.pi * 73 * ratio * t + rng.random()) * np.exp(-t / (2.5 / ratio))
    x *= np.minimum(1, t / 0.02)
    return reverb(x * 0.6, 0.4, 3.0)


def sfx_order():
    x = np.zeros(int(3 * SR))
    place(x, strings([50, 57, 62], 1.2, 1500) * env_adsr(int(1.2 * SR), 0.05, 0.2, 0.7, 0.5), 0)
    place(x, timpani(38, 2, 0.8), 0)
    place(x, bell(86, 2, 0.6), 0.15)
    return reverb(x, 0.3, 2.0)


def sfx_love():
    x = np.zeros(int(3 * SR))
    for k, n in enumerate([77, 81, 84, 89]):
        place(x, bell(n, 2, 0.6), k * 0.09)
        place(x, harp(n - 12, 1.5, 0.5), k * 0.09)
    return reverb(x, 0.4, 2.0)


def sfx_rebuke():
    x = np.zeros(int(2 * SR))
    place(x, strings([38, 44], 1.0, 600) * env_adsr(int(SR), 0.02, 0.3, 0.6, 0.4), 0)
    place(x, timpani(33, 1.8, 1.0), 0)
    return reverb(x, 0.25, 1.5)


def sfx_levelup():
    """Aufsteigende Fanfare: Harfen-Arpeggio + Glocken + Chor-Akkord."""
    x = np.zeros(int(4 * SR))
    for k, n in enumerate([62, 66, 69, 74, 78, 81]):
        place(x, harp(n, 2.0, 0.7), k * 0.07)
    place(x, timpani(38, 2.5, 0.7), 0.0)
    place(x, choir([62, 69, 74, 78], 2.4, 0.9) * env_adsr(int(2.4 * SR), 0.05, 0.4, 0.6, 1.2) * 1.4, 0.4)
    for k, n in enumerate([86, 90, 93]):
        place(x, bell(n, 2.5, 0.7), 0.42 + k * 0.05)
    return reverb(x, 0.4, 2.5)


def sfx_loot():
    """Funkelnder Fund: schnelle Glockenkaskade."""
    x = np.zeros(int(3 * SR))
    for k, n in enumerate([84, 88, 91, 96]):
        place(x, bell(n, 2.0, 0.6), k * 0.05)
    t = t_axis(0.6)
    sparkle = bandpass(rng.uniform(-1, 1, len(t)), 6000, 12000) * np.exp(-t / 0.15) * 0.15
    place(x, sparkle, 0.0)
    return reverb(x, 0.4, 2.0)


def sfx_loot_legendary():
    """Legendärer Fund: tiefer Gong, Chor und hohe Glocken."""
    x = np.zeros(int(5 * SR))
    place(x, timpani(33, 3, 1.0), 0)
    place(x, choir([57, 64, 69, 73, 76], 3.5, 1.0) * env_adsr(int(3.5 * SR), 0.3, 0.5, 0.7, 1.5) * 1.6, 0.1)
    for k, n in enumerate([81, 85, 88, 93, 97]):
        place(x, bell(n, 3.0, 0.7), 0.25 + k * 0.08)
    return reverb(x, 0.45, 3.0)


def sfx_achievement():
    x = np.zeros(int(3.5 * SR))
    place(x, strings([62, 69, 74, 78], 1.6, 2200) * env_adsr(int(1.6 * SR), 0.03, 0.3, 0.7, 0.8), 0)
    for k, n in enumerate([86, 81, 86, 90]):
        place(x, bell(n, 2.2, 0.7), 0.05 + k * 0.11)
    place(x, timpani(38, 2, 0.6), 0)
    return reverb(x, 0.35, 2.2)


def sfx_build():
    """Hammerschläge auf Stein, dann ein feierlicher Akkord."""
    x = np.zeros(int(3.5 * SR))
    for k in range(3):
        t = t_axis(0.3)
        hit = lowpass(rng.uniform(-1, 1, len(t)), 1800) * np.exp(-t / 0.03) + np.sin(2 * np.pi * 180 * t) * np.exp(-t / 0.06)
        place(x, hit * 0.8, k * 0.18)
    place(x, strings([50, 57, 62, 66], 1.8, 1600) * env_adsr(int(1.8 * SR), 0.05, 0.3, 0.7, 0.9), 0.6)
    place(x, bell(86, 2.0, 0.6), 0.62)
    return reverb(x, 0.35, 2.0)


if __name__ == "__main__":
    music = os.path.join(ROOT, "music")
    sfx = os.path.join(ROOT, "sfx")
    for name, fn in [("click", sfx_click), ("hover", sfx_hover), ("page", sfx_page), ("dispatch", sfx_dispatch),
                     ("gong", sfx_gong), ("order", sfx_order), ("love", sfx_love), ("rebuke", sfx_rebuke),
                     ("levelup", sfx_levelup), ("loot", sfx_loot), ("loot_legendary", sfx_loot_legendary),
                     ("achievement", sfx_achievement), ("build_done", sfx_build)]:
        write_ogg(fn(), os.path.join(sfx, name + ".ogg"), peak=0.8, quality=4)
    write_ogg(title_theme(), os.path.join(music, "title.ogg"))
    write_ogg(throne_theme(), os.path.join(music, "throne.ogg"))
    write_ogg(tension_theme(), os.path.join(music, "tension.ogg"))
    write_ogg(battle_theme(), os.path.join(music, "battle.ogg"))
