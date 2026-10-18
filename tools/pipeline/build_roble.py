# Blender: Heiliges Königreich Roble – die Große Mauer zieht sich quer durchs Land, Wehrtürme in festen Abständen,
# das Festungstor in der Mitte, dahinter das Feldlager der Verteidiger (Neia, Kapitel Jaldabaoth), davor Hügelland.
#   blender -b -P build_roble.py -- <WorldKit-Ordner> <ziel.glb>
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from loc_kit import Kit  # noqa: E402

exp_dir, dst = [os.path.abspath(a) for a in sys.argv[sys.argv.index("--") + 1:][:2]]
kit = Kit(exp_dir, dst, seed=51)
kit.lod_names = {"SM_Tree02", "SM_Tree10", "SM_Tree09", "MW_tree_02", "FV_tree_01"}
put, empty, rng = kit.put, kit.empty, kit.rng
HALF = 120.0
WALL_Y = 30.0
CAMP = (0.0, -12.0)

road = kit.spline([(0, -110), (-5, -60), (3, -30), (0, WALL_Y + 40)])
path_fn = kit.roads_mask([(road, 4.0)], HALF)
kit.terrain(HALF, flat_r=60.0, hill_h=12.0, tex="Textures_T_LandScapeLayer01_BC.png", normal="Textures_T_LandScapeLayer01_N.png",
            tile=5.0, edge_rise=16.0, res=360, inner_h=0.6, path_tex="Textures_T_LandScapeLayer04_BC.png",
            path_normal="Textures_T_LandScapeLayer04_N.png", path_fn=path_fn)
kit.occupy(0, WALL_Y, 14)
kit.occupy(CAMP[0], CAMP[1], 20)
kit.occupy(0, -70, 8)
lamps = []

# --- Große Mauer -------------------------------------------------------------------------------------------------------
x = -HALF
k = 0
while x < HALF:
    if abs(x) > 8:
        put("SM_CastleWallV1UvStack", x, WALL_Y, rot=90, s=1.45, sink=0.4)
    if k % 3 == 1 and abs(x) > 20:
        put("SM_TowerSmall", x, WALL_Y, s=0.55, sink=0.4)
    x += 12.5
    k += 1
for sx in (-1, 1):
    put("SM_CastleSep5", sx * 9.5, WALL_Y, s=0.9, sink=2.0)
    put("SM_StandLight", sx * 5.5, WALL_Y - 5, s=1.4)
    lamps.append((sx * 5.5, WALL_Y - 5, kit.ground_fn(sx * 5.5, WALL_Y - 5) + 3.3))
put("SM_TempleDoor", 0, WALL_Y, rot=90, s=2.4)

# --- Feldlager der Verteidiger ------------------------------------------------------------------------------------------
cx, cy = CAMP
for i in range(-3, 4):
    for j in range(-1, 2):
        if i == 0:
            continue
        put("SM_Tent_low", cx + i * 5.0, cy + j * 6.0, rot=rng.choice([0, 180]), s=2.3)
for k in range(8):
    x, y = cx - 21 + k * 6, cy + 13
    put("SM_Spear_low", x, y, z=kit.ground_fn(x, y) - 0.1, s=2.6)
    put("SM_Cloth01", x + 0.35, y, z=kit.ground_fn(x, y) + 3.6, rot=90, s=3.5)
for (x, y) in [(cx - 15, cy - 9), (cx + 15, cy - 9), (cx, cy + 6)]:
    put("SM_StandLight", x, y, s=1.2)
    lamps.append((x, y, kit.ground_fn(x, y) + 2.9))
kit.clutter(cx, cy, ["SM_FireWoodSet01", "FV_barrel_group_01", "FV_crate_group_01", "SM_WoodenWagon01", "SM_Hay"], n=(10, 14), r=(3, 16))

# --- Land: Bäume, Felsen ------------------------------------------------------------------------------------------------
BIG = ["SM_Tree02", "SM_Tree10", "SM_Tree09", "MW_tree_02", "FV_tree_01"]
kit.forest((-HALF + 4, -HALF + 4, HALF - 4, WALL_Y - 12), BIG, 110, min_d=6.0, s=(0.9, 1.4), threshold=0.2, density_scale=0.03,
           under=["SM_Bush07", "MW_bush"], under_n=2)
kit.forest((-HALF + 4, WALL_Y + 12, HALF - 4, HALF - 4), BIG, 120, min_d=5.0, s=(0.9, 1.4), threshold=0.0, density_scale=0.04)
for _ in range(40):
    x, y = rng.uniform(-HALF + 6, HALF - 6), rng.uniform(-HALF + 6, HALF - 6)
    if kit.free(x, y, 3) and path_fn(x, y) < 0.3:
        put(rng.choice(["SM_Rock01", "SM_Rock03", "SM_rock_03"]), x, y, rot=rng.uniform(0, 360), s=rng.uniform(0.4, 1.0), sink=0.4)
ALL = (-HALF + 2, -HALF + 2, HALF - 2, HALF - 2)
kit.grass(ALL, 24000, s=(0.8, 1.4))
kit.grass(ALL, 4000, kind="@flower", s=(0.8, 1.1))

# --- Anker -----------------------------------------------------------------------------------------------------------------
empty("Spawn", 0.0, -70.0, rot=0)
empty("Gate", 0.0, -76.0)
empty("Board", 5.0, -64.0)
empty("Keeper", 0.0, WALL_Y - 8, rot=180)
for i, a in enumerate([200, 235, 270, 305, 340, 20]):
    r = math.radians(a)
    empty("Slot%d" % (i + 1), cx + math.cos(r) * 7, cy - 12 + math.sin(r) * 5)
for i, (x, y, z) in enumerate(lamps):
    empty("Lamp_%d" % (i + 1), x, y, z)
kit.finish_materials(metal_keys=("standlight", "spear"))
kit.export()
