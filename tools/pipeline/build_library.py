# Blender: Bibliothek von Ashurbanipal (10. Ebene) – Lost-Temple-Halle mit viktorianischen Regalen voller Bücher.
#   blender -b -P build_library.py -- <LibKit-Ordner> <ziel.glb>
# Grundriss (Blender-Y = im Spiel -Z): Eingang im Süden (y=-34), Lesesaal in der Mitte mit langen Tischen,
# Regalgassen links und rechts, Galerie mit Statue und großem Leuchter im Norden (y=30).
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from loc_kit import Kit  # noqa: E402
from mathutils import Matrix, Vector  # noqa: E402

exp_dir, dst = [os.path.abspath(a) for a in sys.argv[sys.argv.index("--") + 1:][:2]]
kit = Kit(exp_dir, dst, seed=17)
put, empty, rng = kit.put, kit.empty, kit.rng
T, H = 5.0, 10.0
X0, X1, Y0, Y1 = -25.0, 25.0, -35.0, 35.0

# --- Hülle: Boden, Wände, Decke, Säulen ---------------------------------------------------------
for i in range(int((X1 - X0) / T)):
    for j in range(int((Y1 - Y0) / T)):
        put("SM_floor02", X0 + T * (i + 0.5), Y0 + T * (j + 0.5), z=-0.23, rot=rng.choice([0, 90, 180, 270]))
        put("SM_ceiling01", X0 + T * (i + 0.5), Y0 + T * (j + 0.5), z=H, rot=rng.choice([0, 90, 180, 270]))


def wall(xa, ya, xb, yb, inward, gaps=()):
    n = int(round(math.hypot(xb - xa, yb - ya) / T))
    rot = math.degrees(math.atan2(-inward[0], inward[1]))
    for k in range(n):
        cx, cy = xa + (xb - xa) * (k + 0.5) / n, ya + (yb - ya) * (k + 0.5) / n
        if any(abs(cx - gx) < 0.1 and abs(cy - gy) < 0.1 for gx, gy in gaps):
            continue
        put("SM_wall02", cx, cy, z=0, rot=rot)
        put("SM_brick", cx, cy, z=T, rot=rot)
        put("SM_updan", cx + inward[0] * 0.35, cy + inward[1] * 0.35, z=H - 0.62, rot=rot)


wall(X0, Y0, X1, Y0, (0, 1), gaps=[(-2.5, Y0), (2.5, Y0)])
wall(X0, Y1, X1, Y1, (0, -1))
wall(X0, Y0, X0, Y1, (1, 0))
wall(X1, Y0, X1, Y1, (-1, 0))
for y in range(-30, 35, 10):
    for sx in (-1, 1):
        put("SM_middle_pillar", sx * 8.5, y)
        put("SM_ceilngpillar", sx * 8.5, y, z=6.6)

# --- Regale mit Büchern ---------------------------------------------------------------------------
BOOKS = ["SM_Book01", "SM_Book02", "SM_Book03", "SM_Book04"]
SHELF_Z = [-2.2, -1.1, 0.1, 1.3, 2.5]          # Fachböden im Regal-Mesh (lokal, unskaliert)
R_BOOK = Matrix(((0, 0, 1), (1, 0, 0), (0, 1, 0))).to_4x4()   # liegendes Buch → stehend, Rücken nach vorn
bb = kit.tpl("SM_Book01").bound_box
b_lo = Vector((min(v[0] for v in bb), min(v[1] for v in bb), min(v[2] for v in bb)))
b_hi = Vector((max(v[0] for v in bb), max(v[1] for v in bb), max(v[2] for v in bb)))
b_c = (b_lo + b_hi) / 2
books = 0


def bookcase(x, y, rot, s=0.62):
    """Großes Regal (SM_Cabinet03) + Bücher auf allen Fachböden."""
    global books
    o = put("SM_Cabinet03", x, y, rot=rot, s=s)
    W = o.matrix_world
    for sz in SHELF_Z:
        bx = -1.38
        while bx < 1.38:
            if rng.random() < 0.06:           # Lücke
                bx += rng.uniform(0.1, 0.3)
                continue
            sc = rng.uniform(0.38, 0.5)
            th = (b_hi.z - b_lo.z) * sc        # Buchdicke entlang des Fachs
            tilt = Matrix.Rotation(rng.uniform(-0.05, 0.05) if rng.random() < 0.85 else rng.uniform(0.15, 0.35), 4, "Y")
            # Buch-Unterkante (lokales y nach R_BOOK = z) auf den Fachboden, Mitte in die Regaltiefe
            local = Matrix.Translation((bx + th / 2, 0.85, sz + 0.02)) @ tilt @ Matrix.Diagonal((sc, sc, sc, 1)) @ R_BOOK @ \
                Matrix.Translation((-b_c.x, -b_lo.y, -b_c.z))
            kit._nocol.append((rng.choice(BOOKS), W @ local))
            books += 1
            bx += th + rng.uniform(0.0, 0.02)


# Seitengassen: Regalreihen quer zur Halle, Front zur Gasse
for y in range(-26, 30, 6):
    for sx in (-1, 1):
        for xx in (14.0, 18.5):
            bookcase(sx * xx, y + 1.1, 180)
            bookcase(sx * xx, y - 1.1, 0)
# Wandregale im Lesesaal
for y in range(-24, 26, 4):
    for sx in (-1, 1):
        bookcase(sx * 23.6, y, -90 * sx)
print("OVERLORD buecher", books)

# --- Lesesaal ---------------------------------------------------------------------------------
for y in (-16, -4, 8):
    put("SM_Table01", 0, y, rot=0, s=0.55)
    for k in range(4):
        for sx in (-1, 1):
            put("SM_Chair03", sx * 1.25, y - 1.4 + k * 0.95, rot=90 * sx, s=1.0)
    for k in range(3):
        put("SM_CandleStick01", rng.uniform(-0.3, 0.3), y - 1.2 + k * 1.2, z=1.15, s=0.55)
        put(rng.choice(BOOKS), rng.uniform(-0.4, 0.4), y - 1.3 + k * 1.3, z=1.15, rot=rng.uniform(0, 360), s=0.22, nocol=True)
for (x, y) in [(-4.5, 20), (4.5, 20), (-4.5, -26), (4.5, -26)]:
    put("SM_Chair01", x, y, rot=180 if y > 0 else 0, s=0.6)
    put("SM_Table02", x * 1.6, y, s=0.45)
for y in range(-28, 32, 7):
    put("SM_Carpet01", 0, y, rot=0, s=1.2, nocol=True)
for y in (-20, -2, 16):
    put("SM_Chandelier01", 0, y, z=H - 3.2, s=1.1)
for y in range(-30, 32, 6):
    for sx in (-1, 1):
        put("SM_Light03", sx * 6.0, y, s=0.42)

# Nordende: Galerie mit Statue des Wissens und Leuchtern
put("SM_understair", 0, 31.0, rot=180, s=0.9)
put("SM_statuehuman", 0, 33.5, z=1.4, rot=180, s=0.62)
for sx in (-1, 1):
    put("SM_smallbraizer01", sx * 5.0, 30.0)
    put("SM_Vase02", sx * 3.2, 28.5, s=0.6)
    put("SM_Flowerpot01", sx * 7.0, -32.0, s=0.8)

# --- Anker -------------------------------------------------------------------------------------
empty("Spawn", 0, -31.0, rot=0)
empty("Gate", 0, -33.5)
empty("Keeper", 0, 26.0, rot=180)
for i, (x, y) in enumerate([(-2.6, -10), (2.6, -10), (-2.6, 2), (2.6, 2), (-2.6, 14), (2.6, 14)]):
    empty("Slot%d" % (i + 1), x, y)
for i, y in enumerate((-16, -4, 8)):
    empty("Lamp_%d" % (i + 1), 0, y, 2.2)
for i, y in enumerate((-20, -2, 16)):
    empty("Lamp_%d" % (i + 4), 0, y, H - 3.6)
n = 7
for y in range(-26, 30, 6):                      # warmes Licht in jeder Regalgasse
    for sx in (-1, 1):
        empty("Lamp_%d" % n, sx * 16.2, y + 3.0, 3.6)
        n += 1
for y in range(-30, 32, 12):                     # Stehleuchter
    for sx in (-1, 1):
        empty("Lamp_%d" % n, sx * 6.0, y, 4.0)
        n += 1
for i, sx in enumerate((-1, 1)):
    empty("Fire_%d" % (i + 1), sx * 5.0, 30.0, 4.0)
empty("Violet_1", 0, 33.0, 6.0)

kit.finish_materials(metal_keys=("candle", "chandelier", "light0", "braizer"))
kit.export()
