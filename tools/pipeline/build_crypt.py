# Blender: Grabkammern (1.–3. Ebene, Shalltears Reich) – Gruft und Katakomben aus Lost-Temple-Bauteilen
# und Dragon-Graveyard-Knochen.
#   blender -b -P build_crypt.py -- <CryptKit-Ordner> <ziel.glb>
# Blender-Y = im Spiel -Z. Eingangshalle im Süden (Gate), Säulengang mit Grabnischen nach Norden,
# Kuppelgruft mit Drachenkadaver und der vielarmigen Statue (Shalltears Altar) am Nordende.
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from loc_kit import Kit  # noqa: E402

exp_dir, dst = [os.path.abspath(a) for a in sys.argv[sys.argv.index("--") + 1:][:2]]
kit = Kit(exp_dir, dst, seed=13)
put, empty, rng = kit.put, kit.empty, kit.rng
T = 5.0            # Raster
H = 10.0           # Raumhöhe (zwei Wandreihen)

WALL = ["SM_wall02", "SM_wall02", "SM_brick", "SM_wall02"]


def wall_run(x0, y0, x1, y1, inward, gaps=(), rows=2):
    """Wandstücke entlang einer Raster-Linie; inward = Normale in den Raum (Zierseite)."""
    L = math.hypot(x1 - x0, y1 - y0)
    n = int(round(L / T))
    dx, dy = (x1 - x0) / n, (y1 - y0) / n
    # lokales -Y der Wand zeigt in den Raum
    rot = math.degrees(math.atan2(-inward[0], inward[1]))
    for i in range(n):
        cx, cy = x0 + dx * (i + 0.5), y0 + dy * (i + 0.5)
        if any(abs(cx - gx) < 0.1 and abs(cy - gy) < 0.1 for gx, gy in gaps):
            continue
        for r in range(rows):
            put("SM_wall02" if r == 0 else "SM_brick", cx, cy, z=r * T, rot=rot)   # Relief auf Augenhöhe
        put("SM_updan", cx + inward[0] * 0.35, cy + inward[1] * 0.35, z=rows * T - 0.62, rot=rot)


def floor(x0, x1, y0, y1, z=0.0):
    for i in range(int((x1 - x0) / T)):
        for j in range(int((y1 - y0) / T)):
            put(rng.choice(["SM_floor", "SM_floor02", "SM_floor"]), x0 + T * (i + 0.5), y0 + T * (j + 0.5), z=z - 0.22,
                rot=rng.choice([0, 90, 180, 270]))


def ceiling(x0, x1, y0, y1, z=H, skip=None):
    for i in range(int((x1 - x0) / T)):
        for j in range(int((y1 - y0) / T)):
            cx, cy = x0 + T * (i + 0.5), y0 + T * (j + 0.5)
            if skip and skip(cx, cy):
                continue
            put("SM_ceiling01", cx, cy, z=z, rot=rng.choice([0, 90, 180, 270]))


def gap_pts(x0, x1, y):
    return [(x0 + T * (i + 0.5), y) for i in range(int((x1 - x0) / T))]


# --- Grundriss -------------------------------------------------------------------------------------
# Eingangshalle  x -10..10, y -55..-35
# Säulengang     x  -7.5..7.5 (gerundet -10..10 mit Nischen), y -35..20
# Kuppelgruft    x -20..20, y 20..60
floor(-10, 10, -55, -35)
floor(-10, 10, -35, 20)
floor(-15, -10, -30, 15)          # Nischen West
floor(10, 15, -30, 15)            # Nischen Ost
floor(-20, 20, 20, 60)

# Wände
wall_run(-10, -55, 10, -55, (0, 1), gaps=[(0 - 2.5, -55), (2.5, -55)])          # Süd (Tor)
wall_run(-10, -55, -10, -35, (1, 0))
wall_run(10, -55, 10, -35, (-1, 0))
wall_run(-10, -35, -10, -30, (1, 0)); wall_run(10, -35, 10, -30, (-1, 0))
wall_run(-15, -30, -15, 15, (1, 0)); wall_run(15, -30, 15, 15, (-1, 0))          # Nischen-Rückwände
wall_run(-15, -30, -10, -30, (0, 1)); wall_run(10, -30, 15, -30, (0, 1))
wall_run(-15, 15, -10, 15, (0, -1)); wall_run(10, 15, 15, 15, (0, -1))
wall_run(-10, 15, -10, 20, (1, 0)); wall_run(10, 15, 10, 20, (-1, 0))
wall_run(-20, 20, -10, 20, (0, 1)); wall_run(10, 20, 20, 20, (0, 1))
wall_run(-20, 20, -20, 60, (1, 0)); wall_run(20, 20, 20, 60, (-1, 0))
wall_run(-20, 60, 20, 60, (0, -1))
# Trennwände zwischen den Nischen (halbhoch, mit Durchblick)
for y in range(-25, 15, 10):
    for sx in (-1, 1):
        put("SM_middlewall02", sx * 12.5, y, rot=90, s=0.96)

# Decken: flach im Gang, Kuppel in der Gruft (vier Viertelstücke) um die Mitte (0, 40)
ceiling(-10, 10, -55, -35)
ceiling(-15, 15, -35, 20, skip=lambda x, y: abs(x) > 10 and False)
DOME = (0.0, 40.0)
ceiling(-20, 20, 20, 60, skip=lambda x, y: abs(x - DOME[0]) < 12.5 and abs(y - DOME[1]) < 12.5)
for k, (sx, sy) in enumerate([(1, 1), (-1, 1), (-1, -1), (1, -1)]):
    put("SM_ceiling02", DOME[0] + sx * 6.33, DOME[1] + sy * 6.33, z=H - 0.1, rot=90 * k)

# Säulen im Gang und um die Kuppel, Balken darüber
for y in range(-30, 20, 5):
    for sx in (-1, 1):
        put("SM_middle_pillar", sx * 8.6, y, rot=0)
        put("SM_ceilngpillar", sx * 8.6, y, z=6.6, rot=0)
for a in range(0, 360, 30):
    r = math.radians(a)
    put("SM_middle_pillar2", DOME[0] + math.cos(r) * 13.5, DOME[1] + math.sin(r) * 13.5)
for y in range(-30, 20, 5):
    put("SM_ceilingdan02_02", 8.6, y + 2.5, z=H - 0.56); put("SM_ceilingdan02_02", -8.6, y + 2.5, z=H - 0.56)

# --- Ausstattung -----------------------------------------------------------------------------------
fires, violets, lamps = [], [], []
# Eingangshalle: Treppe, zwei große Kohlebecken, zerbrochene Säulen
put("SM_understair02", 0, -49, rot=0)
for sx in (-1, 1):
    put("SM_smallbraizer01", sx * 6.5, -40)
    fires.append((sx * 6.5, -40, 3.9))
    put("SM_brokenpillar", sx * 8.0, -52, rot=rng.uniform(0, 360))
    put("SM_statuestair", sx * 6.5, -52.5, rot=0, s=0.45)

# Grabnischen: je Nische ein Grabmal, Urnen, Knochen, Kerzen
BONES = ["SM_small_bone_01", "SM_small_bone_02"]
for y in range(-25, 15, 5):
    for sx in (-1, 1):
        cx = sx * 12.6
        put(rng.choice(["SM_tombStone01", "SM_tombstone02"]), cx + sx * 1.2, y, rot=-90 * sx, s=1.3)
        put(rng.choice(["SM_longp", "SM_longpot02", "SM_longpot03", "SM_pot", "SM_pot02"]), cx - sx * 1.0, y + rng.uniform(-1.5, 1.5),
            rot=rng.uniform(0, 360))
        kit.clutter(cx, y, BONES, n=(2, 5), r=(0.5, 1.8), nocol=True)
        put("SM_smallbraizer03", cx + sx * 1.8, y + 1.6)
        lamps.append((cx + sx * 1.8, y + 1.6, 1.0))
# Moos, Ranken und Schutt im Gang
for _ in range(90):
    x, y = rng.uniform(-9, 9), rng.uniform(-34, 19)
    put(rng.choice(["SM_foliage01", "SM_foliage02", "SM_foliage08", "SM_foliage36", "SM_foliage58", "SM_foliage59"]), x, y,
        rot=rng.uniform(0, 360), nocol=True)
for _ in range(14):
    x, y = rng.choice([-1, 1]) * rng.uniform(5.5, 8.0), rng.uniform(-33, 18)
    put(rng.choice(["SM_ground_rock_01", "SM_ground_rock_03", "SM_ground_rock_05", "SM_brokenpillar"]), x, y,
        rot=rng.uniform(0, 360), s=rng.uniform(0.3, 0.6), sink=0.2)

# Kuppelgruft: Drachenkadaver von Süd nach Nord, Schädel am Kopfende
ribs = ["SM_Skeleton_08", "SM_Skeleton_05", "SM_Skeleton_07", "SM_Skeleton_01", "SM_Skeleton_04", "SM_Skeleton_06",
        "SM_Skeleton_03", "SM_Skeleton_02", "SM_Skeleton_03", "SM_Skeleton_06"]
y = 27.0
for i, rb in enumerate(ribs):
    put(rb, -3.0, y, rot=90 + rng.uniform(-4, 4), sink=0.3)
    if i % 2 == 0:
        put(rng.choice(["SM_back_bone_01", "SM_back_bone_02"]), -3.0, y, z=kit.size(rb).z * 0.85, rot=90)
    y += 2.4
put("SM_skull_03", -3.0, y + 2.5, rot=180 + 15, sink=0.4)
for k in range(6):
    put(rng.choice(["SM_horn_01", "SM_horn_02", "SM_horn_03"]), rng.uniform(-12, 8), rng.uniform(24, 56), rot=rng.uniform(0, 360), sink=0.2)
kit.clutter(-3.0, 38.0, BONES, n=(12, 20), r=(2.0, 9.0), nocol=True)
for _ in range(10):
    put(rng.choice(["SM_ground_rock_02", "SM_ground_rock_04", "SM_ground_rock_06", "SM_ground_rock_07"]), rng.uniform(-18, 18),
        rng.uniform(22, 58), rot=rng.uniform(0, 360), s=rng.uniform(0.5, 0.9), sink=0.25)
# Drachenschädel als Trophäen an den Seitenwänden
for i, (x, y_, r) in enumerate([(-17.0, 30, 90), (17.0, 30, -90), (-17.0, 50, 90), (17.0, 50, -90)]):
    put(["SM_skull_01", "SM_skull_02", "SM_skull_04", "SM_skull_06"][i], x, y_, rot=r, s=0.7, z=1.2)
    put("SM_shortfloordan02", x, y_, rot=0)
    violets.append((x, y_, 3.0))
# Altar: Statue am Nordende, Treppe davor, Kohlebecken
put("SM_understair", 0, 52.5, rot=180)
put("SM_statuehuman", 0, 56.5, z=1.59, rot=180)
for sx in (-1, 1):
    put("SM_smallbraizer01", sx * 7.0, 50.0)
    fires.append((sx * 7.0, 50.0, 3.9))
    put("SM_smallbraizer02", sx * 4.0, 46.5)
    fires.append((sx * 4.0, 46.5, 1.4))
violets.append((0, 55.0, 6.0))

# Geisterlichter (blassblau) entlang des Gangs und in der Gruft
for y_ in range(-30, 20, 10):
    lamps.append((0.0, y_, 5.0))
for (x, y_) in [(-10, 30), (10, 30), (-10, 48), (10, 48), (0, 40)]:
    violets.append((x, y_, 7.0))

# --- Anker -----------------------------------------------------------------------------------------
empty("Spawn", 0, -44.0, rot=0)
empty("Gate", 0, -51.5)
empty("Keeper", 0, 47.5)
for i, a in enumerate([200, 235, 270, 305, 340, 20]):
    r = math.radians(a)
    empty("Slot%d" % (i + 1), 0 + math.cos(r) * 7.0, 38.0 + math.sin(r) * 7.0)
for i, (x, y_, z) in enumerate(fires):
    empty("Fire_%d" % (i + 1), x, y_, z)
for i, (x, y_, z) in enumerate(violets):
    empty("Violet_%d" % (i + 1), x, y_, z)
for i, (x, y_, z) in enumerate(lamps):
    empty("Lamp_%d" % (i + 1), x, y_, z)

kit.finish_materials(metal_keys=("braizer", "brizer"))
kit.export()
