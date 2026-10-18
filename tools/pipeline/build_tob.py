# Blender: Großer Wald von Tob – uralter, dichter Wald mit Pfad, Lichtungen, Ruinen und Hamsukes Bau.
#   blender -b -P build_tob.py -- <TobKit-Ordner> <ziel.glb>
# Blender-Y = im Spiel -Z. Pfad von Süden (Carne-Seite) nach Norden zur Lichtung mit Hamsukes Felsenbau (0, 62).
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from loc_kit import Kit  # noqa: E402

exp_dir, dst = [os.path.abspath(a) for a in sys.argv[sys.argv.index("--") + 1:][:2]]
kit = Kit(exp_dir, dst, seed=44)
kit.lod_names = {"SM_Tree02", "SM_Tree03", "SM_Tree4", "SM_Tree05", "SM_Tree06", "SM_Tree07", "SM_Tree08", "SM_Tree09",
                 "SM_Tree10", "SM_Tree13", "SM_ChurchTree01", "MW_tree_02", "MW_tree_03", "MW_pine_tree_Var_01",
                 "FV_tree_01", "FV_tree_02"}
put, empty, rng = kit.put, kit.empty, kit.rng
HALF = 110.0
DEN = (2.0, 64.0)
RUINS = (-34.0, 18.0)

path = kit.spline([(4, -110), (-6, -70), (6, -40), (-4, -12), (8, 14), (-2, 36), (2, DEN[1] - 10)])
side = kit.spline([(-4, -12), (-18, -2), (RUINS[0], RUINS[1])])
clear = kit.spline([(DEN[0] - 9, DEN[1] - 8), (DEN[0] + 9, DEN[1] - 8), (DEN[0] + 9, DEN[1] - 22), (DEN[0] - 9, DEN[1] - 22),
                    (DEN[0] - 9, DEN[1] - 8)])
path_fn = kit.roads_mask([(path, 3.2), (side, 2.4), (clear, 10.0)], HALF)
kit.terrain(HALF, flat_r=20.0, hill_h=10.0, tex="Texture_T_Mossy_ForesFloor_BC.png", tile=5.0, edge_rise=10.0, res=380,
            inner_h=1.6, path_tex="Textures_T_LandScapeLayer04_BC.png", path_normal="Textures_T_LandScapeLayer04_N.png",
            path_fn=path_fn)
kit.occupy(DEN[0], DEN[1], 12)
kit.occupy(DEN[0], DEN[1] - 15, 9)
kit.occupy(RUINS[0], RUINS[1], 10)
kit.occupy(0, -40, 6)

# --- Hamsukes Felsenbau: Felsbogen um eine Höhle, Knochen und Nest -------------------------------------
dx, dy = DEN
for k in range(9):
    a = math.radians(-20 + k * 25)
    put(rng.choice(["SM_rock_01", "SM_rock_02", "SM_rock_03"]), dx + math.cos(a) * 9.5, dy + 3 + math.sin(a) * 7.5,
        rot=rng.uniform(0, 360), s=rng.uniform(0.7, 1.0), sink=0.8)
put("SM_rock_02", dx, dy + 8, rot=90, s=1.3, sink=0.5)
kit.clutter(dx, dy - 3, ["SM_Hay", "SM_FireWoodSet02", "SM_WoodPlank02"], n=(3, 5), r=(1.0, 3.5), s=(0.4, 0.8))
for _ in range(14):
    put(rng.choice(["SM_ground_rock_01", "SM_ground_rock_03", "SM_ground_rock_05"]), dx + rng.uniform(-12, 12),
        dy - 12 + rng.uniform(-10, 10), rot=rng.uniform(0, 360), s=rng.uniform(0.25, 0.5), sink=0.3)

# --- Ruinen eines alten Elfenschreins am Seitenpfad ---------------------------------------------------
rx, ry = RUINS
for k in range(7):
    a = k / 7 * math.tau
    x, y = rx + math.cos(a) * 6.5, ry + math.sin(a) * 6.5
    put("SM_column_ruin_module_bottom", x, y, rot=rng.uniform(0, 360))
    if rng.random() < 0.6:
        put("SM_column_ruin_module_body", x, y, z=kit.ground_fn(x, y) + 0.9, rot=rng.uniform(0, 360))
put("SM_stone_door_staute", rx, ry + 8.5, rot=180, s=0.7)
for k in range(5):
    put(rng.choice(["SM_old_stone_wall", "SM_Mossy_Stone_Wall01"]), rx + rng.uniform(-9, 9), ry + rng.uniform(-9, 9),
        rot=rng.uniform(0, 360), s=rng.uniform(0.5, 0.8), sink=0.4)
put("SM_firestone", rx, ry)

# --- Wald: alte Riesen, Unterholz, Farne, Pilzfelsen ----------------------------------------------------
BIG = ["SM_Tree4", "SM_Tree10", "SM_Tree02", "SM_Tree09", "SM_Tree13", "SM_Tree03", "MW_tree_02", "MW_tree_03",
       "FV_tree_02", "FV_tree_01", "MW_pine_tree_Var_01", "SM_ChurchTree01"]
UNDER = ["SM_Bush07", "SM_Foliage_56", "SM_Bush01", "SM_Foliage_59", "SM_Foliage_22", "SM_Foliage_24", "SM_Foliage_27",
         "SM_Foliage_12", "MW_bush", "FV_bush_05", "SM_Bush03"]
kit.forest((-HALF + 3, -HALF + 3, HALF - 3, HALF - 3), BIG, 900, min_d=3.6, s=(1.0, 1.6), under=UNDER, under_n=4,
           threshold=-0.45, density_scale=0.05)
kit.forest((-HALF + 3, -HALF + 3, HALF - 3, HALF - 3), ["SM_Tree05", "SM_Tree06", "SM_Tree07", "SM_Tree08"], 160,
           min_d=4.0, s=(0.8, 1.2), threshold=-0.2)
ALL = (-HALF + 2, -HALF + 2, HALF - 2, HALF - 2)
kit.grass(ALL, 26000, s=(0.8, 1.5))
kit.grass(ALL, 2600, kind="@flower", s=(0.7, 1.1))
kit.meadow(ALL, UNDER + ["SM_Foliage_33", "SM_Foliage_34", "MW_plant_ground", "MW_flower_clump_01"], 2600, s=(0.8, 1.4))
for _ in range(70):
    x, y = rng.uniform(-HALF + 5, HALF - 5), rng.uniform(-HALF + 5, HALF - 5)
    if path_fn(x, y) < 0.5 and kit.free(x, y, 2):
        put(rng.choice(["SM_Rock01", "SM_Rock03", "SM_MossyGround01", "SM_ground_rock_02", "SM_rock_03"]), x, y,
            rot=rng.uniform(0, 360), s=rng.uniform(0.3, 0.9), sink=0.4)
# umgestürzte Stämme quer neben dem Pfad
for k in range(0, len(path), 28):
    x, y = path[k]
    put(rng.choice(["SM_WoodPlank02", "SM_FireWoodSet01"]), x + rng.choice([-1, 1]) * rng.uniform(5, 9), y,
        rot=rng.uniform(0, 360), s=rng.uniform(1.5, 2.5))

# --- Anker ---------------------------------------------------------------------------------------------
empty("Spawn", -6.0, -66.0, rot=-15)
empty("Gate", -5.0, -74.0)
empty("Keeper", dx, dy - 2, rot=180)
for i, a in enumerate([200, 235, 270, 305, 340, 20]):
    r = math.radians(a)
    empty("Slot%d" % (i + 1), dx + math.cos(r) * 6, dy - 15 + math.sin(r) * 5)
empty("Fire_1", rx, ry, kit.ground_fn(rx, ry) + 0.6)
n = 1
for k in range(0, len(path), 10):
    empty("Walk_%d" % n, path[k][0], path[k][1])
    n += 1
kit.finish_materials()
kit.export()
