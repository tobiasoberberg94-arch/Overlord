# Blender: Arwintar, Hauptstadt des Baharuth-Kaiserreichs – kaiserliche Prachtallee, großer Platz mit Statuen,
# der Palastkomplex von Kaiser Jircniv im Norden, Bürgerhäuser und Türme, Stadtmauer mit Tor im Süden.
#   blender -b -P build_baharuth.py -- <WorldKit-Ordner> <ziel.glb>
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from loc_kit import Kit  # noqa: E402

exp_dir, dst = [os.path.abspath(a) for a in sys.argv[sys.argv.index("--") + 1:][:2]]
kit = Kit(exp_dir, dst, seed=33)
put, empty, rng = kit.put, kit.empty, kit.rng
HALF = 120.0
PALACE = (0.0, 60.0)

ave = kit.spline([(0, -110), (0, -16)])
pal = kit.spline([(0, 16), (0, PALACE[1] - 20)])
ring = kit.spline([(math.cos(a) * 16, math.sin(a) * 16) for a in [k / 32 * math.tau for k in range(33)]])
cross = kit.spline([(-90, 0), (90, 0)])
path_fn = kit.roads_mask([(ave, 6.0), (pal, 6.0), (ring, 16.0), (cross, 4.5)], HALF)
kit.terrain(HALF, flat_r=95.0, hill_h=6.0, tex="Textures_T_LandScapeLayer01_BC.png", normal="Textures_T_LandScapeLayer01_N.png",
            tile=5.0, edge_rise=10.0, res=320, inner_h=0.0, path_tex="Texture_T_Cobblestone_BC.png", path_normal="Texture_T_Cobblestone_N.png",
            path_fn=path_fn)
kit.occupy(0, 0, 20)
kit.occupy(PALACE[0], PALACE[1], 40)
kit.occupy(0, -78, 8)
lamps = []

# --- Kaiserplatz -------------------------------------------------------------------------------------------------------
put("SM_RoundOrn", 0, 0, s=1.4)
for k in range(8):
    a = k / 8 * math.tau
    put("SM_Statue01", math.cos(a) * 12, math.sin(a) * 12, rot=math.degrees(a) + 90, s=1.7)
    put("SM_StandLight", math.cos(a + 0.2) * 15, math.sin(a + 0.2) * 15, s=1.3)
    lamps.append((math.cos(a + 0.2) * 15, math.sin(a + 0.2) * 15, 3.1))
for y in range(-100, -16, 8):
    for sx in (-1, 1):
        if (y // 8) % 2 == 0:
            put("SM_StandLight", sx * 7.5, y, s=1.4)
            lamps.append((sx * 7.5, y, 3.3))
        else:
            put("SM_ChurchTree01", sx * 8.5, y, rot=rng.uniform(0, 360), s=1.2)

# --- Palast Jircnivs ---------------------------------------------------------------------------------------------------
put("SM_Build6", PALACE[0], PALACE[1] + 20, rot=180, s=0.45)
for sx in (-1, 1):
    put("SM_Build5", sx * 30, PALACE[1] - 10, rot=180, s=0.5)

# --- Stadt ----------------------------------------------------------------------------------------------------------------
HOUSES = ["SM_Build1", "SM_Build3", "SM_Build4", "SM_House", "SM_House3", "SM_Build1"]
for side in (-1, 1):
    for k in range(6):
        put(rng.choice(HOUSES), side * 24, -98 + k * 14, rot=90 * side, s=rng.uniform(0.45, 0.6))
        put(rng.choice(HOUSES), side * 42, -96 + k * 14, rot=90 * side, s=rng.uniform(0.45, 0.6))
    for k in range(4):
        put(rng.choice(HOUSES), side * (30 + k * 15), -13, rot=0, s=rng.uniform(0.45, 0.6))
        put(rng.choice(HOUSES), side * (30 + k * 15), 13, rot=180, s=rng.uniform(0.45, 0.6))
for k in range(48):
    a = k / 48 * math.tau
    x, y = math.cos(a) * 104, math.sin(a) * 104
    if abs(x) < 10 and y < 0:
        continue
    put("SM_CastleWallV1UvStack", x, y, rot=math.degrees(a) + 90, s=1.3, sink=0.3)
for sx in (-1, 1):
    put("SM_TowerSmall", sx * 12, -104, s=0.5)
for _ in range(40):
    x, y = rng.uniform(-80, 80), rng.uniform(-95, 40)
    if path_fn(x, y) > 0.5 and kit.free(x, y, 1.5):
        kit.clutter(x, y, ["FV_barrel_01", "FV_crate_01", "SM_FlowerPot01", "SM_WoodenBucket01", "FV_bag", "SM_WoodenWagon01"], n=(1, 2), r=(0.5, 1.5))
for _ in range(40):
    x, y = rng.uniform(-95, 95), rng.uniform(-95, 95)
    if path_fn(x, y) < 0.2 and kit.free(x, y, 4):
        put(rng.choice(["SM_ChurchTree01", "SM_Tree02", "SM_Spruce1"]), x, y, rot=rng.uniform(0, 360), s=rng.uniform(1.0, 1.5))
        kit.occupy(x, y, 3)
ALL = (-HALF + 2, -HALF + 2, HALF - 2, HALF - 2)
kit.grass(ALL, 12000, s=(0.8, 1.3))
kit.grass(ALL, 2500, kind="@flower", s=(0.8, 1.1))

# --- Anker ---------------------------------------------------------------------------------------------------------------
empty("Spawn", 0.0, -78.0, rot=0)
empty("Gate", 0.0, -84.0)
empty("Board", 6.0, -72.0)
empty("Keeper", 0.0, PALACE[1] - 24, rot=180)
for i, a in enumerate([200, 235, 270, 305, 340, 20]):
    r = math.radians(a)
    empty("Slot%d" % (i + 1), math.cos(r) * 7, -6 + math.sin(r) * 5)
for i, (x, y, z) in enumerate(lamps):
    empty("Lamp_%d" % (i + 1), x, y, z)
n = 1
for k in range(0, len(ave), 12):
    empty("Walk_%d" % n, ave[k][0] + 3, ave[k][1])
    n += 1
kit.finish_materials(metal_keys=("standlight",))
kit.export()
