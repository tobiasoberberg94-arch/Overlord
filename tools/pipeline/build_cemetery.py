# Blender: Friedhof von E-Rantel (Kapitel 3, Nacht der Untoten) – ummauerter Gräberacker vor der Stadt,
# Mausoleen, kahle Bäume, Laternen und Khajits Mausoleum mit dem Abgang zum unterirdischen Tempel.
#   blender -b -P build_cemetery.py -- <WorldKit-Ordner> <ziel.glb>
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from loc_kit import Kit  # noqa: E402

exp_dir, dst = [os.path.abspath(a) for a in sys.argv[sys.argv.index("--") + 1:][:2]]
kit = Kit(exp_dir, dst, seed=66)
put, empty, rng = kit.put, kit.empty, kit.rng
HALF = 100.0
X0, X1, Y0, Y1 = -45.0, 45.0, -40.0, 50.0
KH = (0.0, 36.0)                      # Khajits Mausoleum

paths = [kit.spline([(0, -60), (0, Y0), (2, -10), (-2, 14), (0, KH[1] - 8)]),
         kit.spline([(X0 + 4, 4), (-20, 2), (0, 0), (22, 6), (X1 - 4, 2)]),
         kit.spline([(-28, -30), (-30, 0), (-26, 34)]), kit.spline([(28, -30), (30, 0), (26, 34)])]
path_fn = kit.roads_mask([(paths[0], 3.6)] + [(p, 2.4) for p in paths[1:]], HALF)
kit.terrain(HALF, flat_r=52.0, hill_h=7.0, tex="Textures_T_LandScapeLayer02_BC.png", normal="Textures_T_LandScapeLayer02_N.png",
            tile=5.0, edge_rise=8.0, res=360, inner_h=0.5, path_tex="Textures_T_LandScapeLayer04_BC.png",
            path_normal="Textures_T_LandScapeLayer04_N.png", path_fn=path_fn)
kit.occupy(KH[0], KH[1], 11)
kit.occupy(0, -30, 7)

# --- Friedhofsmauer (Stadtmauer-Steine) und Tor ---------------------------------------------------------
for (xa, ya, xb, yb, inward) in [(X0, Y0, X1, Y0, (0, 1)), (X1, Y0, X1, Y1, (-1, 0)), (X1, Y1, X0, Y1, (0, -1)), (X0, Y1, X0, Y0, (1, 0))]:
    n = int(math.hypot(xb - xa, yb - ya) / 5)
    rot = math.degrees(math.atan2(yb - ya, xb - xa))
    for k in range(n):
        x, y = xa + (xb - xa) * (k + 0.5) / n, ya + (yb - ya) * (k + 0.5) / n
        if ya == Y0 and yb == Y0 and abs(x) < 4:
            continue
        put("SM_StoneWall01", x, y, rot=rot, s=1.2, sink=0.2)
        if rng.random() < 0.3:
            put("SM_Foliage_33", x + inward[0] * 1.2, y + inward[1] * 1.2, nocol=True)
for sx in (-1, 1):
    put("SM_TowerSmall", sx * 6.5, Y0, s=0.35)
    put("SM_StandLight", sx * 3.5, Y0 + 3)

# --- Gräberfelder ----------------------------------------------------------------------------------------
lamps = []
for _ in range(520):
    x, y = rng.uniform(X0 + 3, X1 - 3), rng.uniform(Y0 + 4, Y1 - 3)
    if path_fn(x, y) > 0.3 or not kit.free(x, y, 1.1):
        continue
    put(rng.choice(["SM_tombStone01", "SM_tombstone02", "SM_tombStone01"]), x, y, rot=180 + rng.uniform(-18, 18),
        s=rng.uniform(0.85, 1.2), sink=rng.uniform(0.0, 0.35))
    kit.occupy(x, y, 1.0)
    if rng.random() < 0.08:
        kit.clutter(x, y - 1.0, ["SM_small_bone_01", "SM_small_bone_02", "SM_skull_07"], n=(1, 2), r=(0.3, 1.0), s=(0.08, 0.15), nocol=True)
# Mausoleen (Familiengrüfte)
for (x, y, r) in [(-34, -22, 90), (34, -24, -90), (-36, 22, 90), (36, 24, -90), (-14, 28, 0), (14, 28, 0)]:
    put("SM_wall02", x, y, rot=r, s=0.7)
    put("SM_ceiling01", x, y, z=kit.ground_fn(x, y) + 3.5, s=0.75)
    for sx in (-1, 1):
        put("SM_middlepillar04", x + math.cos(math.radians(r)) * sx * 1.8, y + math.sin(math.radians(r)) * sx * 1.8)
    lamps.append((x, y, kit.ground_fn(x, y) + 2.0))
# kahle, tote Bäume
for _ in range(36):
    x, y = rng.uniform(X0 - 30, X1 + 30), rng.uniform(Y0 - 25, Y1 + 30)
    if kit.free(x, y, 3) and path_fn(x, y) < 0.3:
        put(rng.choice(["SM_Tree05", "SM_Tree13", "SM_Tree06"]), x, y, rot=rng.uniform(0, 360), s=rng.uniform(0.7, 1.1))
# Laternen am Hauptweg
for k in range(8, len(paths[0]) - 5, 14):
    x, y = paths[0][k]
    put("SM_StandLight", x + 2.6, y)
    lamps.append((x + 2.6, y, kit.ground_fn(x, y) + 3.0))

# --- Khajits Mausoleum (Eingang zum unterirdischen Tempel der Zurrernon) ------------------------------------
kx, ky = KH
gz = kit.ground_fn(kx, ky)
for i in range(-1, 2):
    for j in range(-1, 2):
        put("SM_floor", kx + i * 5, ky + j * 5, z=gz + 0.6)
put("SM_understair02", kx, ky - 8.8, z=gz - 0.9, rot=0, s=0.7)
# Sockel unter der Plattform
for k in (-5.0, 0.0, 5.0):
    for sx in (-1, 1):
        put("SM_middlewall02", kx + sx * 7.8, ky + k, z=gz + 0.6 - 4.2, rot=90 * sx)
    put("SM_middlewall02", kx + k, ky + 7.8, z=gz + 0.6 - 4.2, rot=180)
for sx in (-1, 1):
    put("SM_middlewall02", kx + sx * 5.0, ky - 7.8, z=gz + 0.6 - 4.2, rot=0)
for k in range(6):
    a = math.radians(k * 60 + 30)
    put("SM_middle_pillar", kx + math.cos(a) * 6.2, ky + math.sin(a) * 6.2, z=gz + 0.6, s=0.7)
for sx in (-1, 1):
    put("SM_wall02", kx + sx * 7.5, ky + 2, z=gz + 0.6, rot=90 * sx)
put("SM_wall02", kx, ky + 7.5, z=gz + 0.6, rot=180)
for i in range(-1, 2):
    for j in range(-1, 2):
        put("SM_ceiling01", kx + i * 5, ky + j * 5, z=gz + 5.6)
for sx in (-1, 1):
    put("SM_wall02", kx + sx * 7.5, ky - 3, z=gz + 0.6, rot=90 * sx)
put("SM_GateWall01", kx, ky + 3.5, z=gz + 0.6, s=0.8)
put("SM_statuestair", kx, ky + 6.3, z=gz + 0.6, rot=180, s=0.4)
for sx in (-1, 1):
    put("SM_smallbraizer02", kx + sx * 3.2, ky - 2, z=gz + 0.6)

# --- Bodennebel-Gras, Unkraut ---------------------------------------------------------------------------------
ALL = (-HALF + 2, -HALF + 2, HALF - 2, HALF - 2)
kit.grass(ALL, 16000, s=(0.7, 1.4))
kit.meadow(ALL, ["SM_Foliage_81", "SM_Foliage_82", "SM_Foliage_90", "SM_Foliage_91", "SM_Foliage_99", "SM_Bush07"], 1600, s=(0.8, 1.3))

# --- Anker ------------------------------------------------------------------------------------------------------
empty("Spawn", 0.0, Y0 - 8.0, rot=0)
empty("Gate", 0.0, Y0 - 14.0)
empty("Keeper", kx, ky - 1, gz + 0.6, rot=180)
for i, a in enumerate([200, 235, 270, 305, 340, 20]):
    r = math.radians(a)
    empty("Slot%d" % (i + 1), math.cos(r) * 5, -18 + math.sin(r) * 4)
for i, (x, y, z) in enumerate(lamps):
    empty("Lamp_%d" % (i + 1), x, y, z)
for i, sx in enumerate((-1, 1)):
    empty("Fire_%d" % (i + 1), kx + sx * 3.2, ky - 2, gz + 2.0)
    empty("Violet_%d" % (i + 1), kx + sx * 2.0, ky + 3.0, gz + 3.0)
kit.finish_materials(metal_keys=("standlight", "braizer"))
kit.export()
