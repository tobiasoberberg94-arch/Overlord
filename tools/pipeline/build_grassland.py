# Blender: Grasland um Nazarick (Kapitel 1) – sanfte Hügel, Wiesen, Baumgruppen, darin die Oberfläche des
# Großen Grabes: Friedhof hinter einer Ringmauer und das zentrale Mausoleum mit dem Abstieg.
#   blender -b -P build_grassland.py -- <WorldKit-Ordner> <ziel.glb>
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from loc_kit import Kit  # noqa: E402

exp_dir, dst = [os.path.abspath(a) for a in sys.argv[sys.argv.index("--") + 1:][:2]]
kit = Kit(exp_dir, dst, seed=101)
kit.lod_names = {"SM_Tree02", "SM_Tree4", "SM_Tree05", "SM_Tree06", "SM_Tree07", "SM_Tree09", "SM_Tree10", "SM_Tree13",
                 "MW_tree_02", "MW_tree_03", "FV_tree_01", "FV_tree_02", "SM_ChurchTree01"}
put, empty, rng = kit.put, kit.empty, kit.rng
HALF = 140.0
C = (0.0, 30.0)                 # Mitte der Grabanlage
W = 32.0                        # halbe Kantenlänge der Ringmauer

road = kit.spline([(0, -138), (6, -100), (-4, -60), (2, -20), (0, C[1] - W - 2)])
ring = kit.spline([(C[0] - W + 4, C[1] - W + 4), (C[0] + W - 4, C[1] - W + 4), (C[0] + W - 4, C[1] + W - 4),
                   (C[0] - W + 4, C[1] + W - 4), (C[0] - W + 4, C[1] - W + 4)])
axis = kit.spline([(0, C[1] - W + 2), (0, C[1] - 6)])
path_fn = kit.roads_mask([(road, 3.0), (ring, 2.6), (axis, 4.0)], HALF)
kit.terrain(HALF, flat_r=W + 14, hill_h=14.0, tex="Textures_T_LandScapeLayer01_BC.png", normal="Textures_T_LandScapeLayer01_N.png",
            tile=5.0, edge_rise=12.0, res=420, inner_h=0.4, path_tex="Textures_T_LandScapeLayer04_BC.png",
            path_normal="Textures_T_LandScapeLayer04_N.png", path_fn=path_fn)
kit.occupy(C[0], C[1], W + 4)
kit.occupy(0, -50, 8)

# --- Ringmauer mit Tor -------------------------------------------------------------------------
cx, cy = C
gz = kit.ground_fn(cx, cy)
for side, (x0, y0, x1, y1, inward) in enumerate([(-W, -W, W, -W, (0, 1)), (W, -W, W, W, (-1, 0)), (W, W, -W, W, (0, -1)),
                                                 (-W, W, -W, -W, (1, 0))]):
    n = int(2 * W / 5)
    rot = math.degrees(math.atan2(-inward[0], inward[1]))
    for k in range(n):
        x = cx + x0 + (x1 - x0) * (k + 0.5) / n
        y = cy + y0 + (y1 - y0) * (k + 0.5) / n
        if side == 0 and abs(x - cx) < 4:
            continue                                      # Tor
        put("SM_StoneWall01", x, y, rot=rot + 90, s=1.3, sink=0.2)
        if rng.random() < 0.25:
            put(rng.choice(["SM_Foliage_33", "SM_Bush07"]), x + inward[0] * 1.5, y + inward[1] * 1.5, nocol=True)
for sx in (-1, 1):
    put("SM_middle_pillar2", cx + sx * 4.5, cy - W, s=0.75)
    put("SM_statuestair", cx + sx * 7.5, cy - W + 2.5, rot=0, s=0.35)

# --- Friedhof innerhalb der Mauer ----------------------------------------------------------------
for i in range(-6, 7):
    for j in range(-5, 6):
        x, y = cx + i * 4.4 + rng.uniform(-0.6, 0.6), cy + j * 4.8 + rng.uniform(-0.6, 0.6)
        if abs(x - cx) < 6 or (abs(x - cx) < 15 and abs(y - cy) < 13) or abs(i) > 6:
            continue
        put(rng.choice(["SM_tombStone01", "SM_tombstone02"]), x, y, rot=180 + rng.uniform(-10, 10), s=rng.uniform(0.9, 1.15),
            sink=rng.uniform(0.0, 0.15))
        if rng.random() < 0.3:
            put(rng.choice(["SM_Foliage_33", "SM_FlowerPot02", "SM_Foliage_12"]), x + 0.6, y - 0.8, nocol=True)
for (x, y) in [(cx - 24, cy + 22), (cx + 24, cy + 22), (cx - 24, cy - 20), (cx + 24, cy - 20)]:
    put("SM_ChurchTree01", x, y, rot=rng.uniform(0, 360), s=1.1)

# --- Zentrales Mausoleum ------------------------------------------------------------------------------
put("SM_understair02", cx, cy - 9.5, z=gz, rot=0, s=0.9)
for i in range(-2, 2):
    for j in range(-2, 2):
        put("SM_floor", cx + i * 5 + 2.5, cy + j * 5 + 2.5, z=gz + 1.4)
# Sockel: Mauerblöcke rings um die Plattform, Oberkante = Plattform (nichts schwebt)
TOP = gz + 1.4
for k in (-7.5, -2.5, 2.5, 7.5):
    for sx in (-1, 1):
        put("SM_middlewall02", cx + sx * 10.3, cy + k, z=TOP - 4.2, rot=90 * sx)
    put("SM_middlewall02", cx + k, cy + 10.3, z=TOP - 4.2, rot=180)
for sx in (-1, 1):
    put("SM_middlewall02", cx + sx * 7.5, cy - 10.3, z=TOP - 4.2, rot=0)
    put("SM_middlewall02", cx + sx * 4.4, cy - 10.3, z=TOP - 4.2, rot=0)
# Säulenhalle, Seiten- und Rückwand, flaches Dach mit Gesims
for sx in (-1, 1):
    for k in range(4):
        put("SM_middle_pillar", cx + sx * 9.0, cy - 7 + k * 5, z=TOP, s=0.85)
    for k in (2.5, 7.5):
        put("SM_wall02", cx + sx * 10.0, cy + k, z=TOP, rot=90 * sx, sz=1.12)
    put("SM_smallbraizer01", cx + sx * 4.5, cy - 4.5, z=TOP)
for k in range(-1, 2):
    put("SM_wall02", cx + k * 5, cy + 10.0, z=TOP, rot=180, sz=1.12)
ROOF = TOP + 5.6
for i in range(-2, 2):
    for j in range(-2, 2):
        put("SM_ceiling01", cx + i * 5 + 2.5, cy + j * 5 + 2.5, z=ROOF)
for k in (-7.5, -2.5, 2.5, 7.5):
    for sx in (-1, 1):
        put("SM_updan", cx + sx * 10.2, cy + k, z=ROOF + 0.5, rot=90 * sx)
        put("SM_updan", cx + k, cy + sx * 10.2, z=ROOF + 0.5, rot=0 if sx < 0 else 180)
put("SM_statuehuman", cx, cy + 7.5, z=gz + 1.4, rot=180, s=0.5)
put("SM_GateWall01", cx, cy + 2.0, z=gz + 1.4, rot=0, s=0.9)       # Eingang in die Tiefe (Gate-Portal)

# --- Grasland ringsum ----------------------------------------------------------------------------------
BIG = ["SM_Tree4", "SM_Tree10", "SM_Tree02", "SM_Tree09", "SM_Tree13", "MW_tree_02", "MW_tree_03", "FV_tree_01"]
kit.forest((-HALF + 4, -HALF + 4, HALF - 4, HALF - 4), BIG, 160, min_d=6.0, s=(0.9, 1.4), threshold=0.25,
           density_scale=0.03, under=["SM_Bush07", "SM_Foliage_6", "MW_bush"], under_n=3)
ALL = (-HALF + 2, -HALF + 2, HALF - 2, HALF - 2)
kit.grass(ALL, 42000, s=(0.9, 1.7))
kit.grass(ALL, 6000, kind="@flower", s=(0.8, 1.2))
kit.meadow(ALL, ["MW_flower_clump_01", "MW_flower_clump_02", "MW_flower_clump_03", "MW_flower_04", "SM_Foliage_81",
                 "SM_Foliage_90", "SM_Foliage_99"], 2400, s=(0.8, 1.3), patch=(["MW_flower_01", "MW_flower_02", "MW_flower_03"], 90, 4.0))
for _ in range(40):
    x, y = rng.uniform(-HALF + 10, HALF - 10), rng.uniform(-HALF + 10, HALF - 10)
    if kit.free(x, y, 3):
        put(rng.choice(["SM_Rock01", "SM_Rock03", "SM_StoneDan01", "SM_rock_03"]), x, y, rot=rng.uniform(0, 360),
            s=rng.uniform(0.4, 1.1), sink=0.4)

# --- Anker ------------------------------------------------------------------------------------------------
empty("Spawn", 0.0, cy - W - 8.0, rot=0)
empty("Gate", cx, cy + 2.0, gz + 1.4)
for i, a in enumerate([200, 235, 270, 305, 340, 20]):
    r = math.radians(a)
    empty("Slot%d" % (i + 1), cx + math.cos(r) * 6.0, cy - W - 14 + math.sin(r) * 4.0)
empty("Board", 4.0, cy - W - 10.0)
for i, sx in enumerate((-1, 1)):
    empty("Fire_%d" % (i + 1), cx + sx * 4.5, cy - 4.5, gz + 1.4 + 3.9)
kit.finish_materials(metal_keys=("braizer",))
kit.export()
