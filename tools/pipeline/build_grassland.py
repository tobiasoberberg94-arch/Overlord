# Blender: Grasland um Nazarick (Kapitel 1) – sanfte Hügel, Wiesen, Baumgruppen, darin die Oberfläche des
# Großen Grabes: Friedhof hinter einer Ringmauer und das zentrale Mausoleum mit dem Abstieg.
#   blender -b -P build_grassland.py -- <WorldKit-Ordner> <ziel.glb>
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from loc_kit import Kit  # noqa: E402
from struct_kit import Structs  # noqa: E402

exp_dir, dst = [os.path.abspath(a) for a in sys.argv[sys.argv.index("--") + 1:][:2]]
kit = Kit(exp_dir, dst, seed=101)
kit.lod_names = {"SM_Tree02", "SM_Tree4", "SM_Tree05", "SM_Tree06", "SM_Tree07", "SM_Tree09", "SM_Tree10", "SM_Tree13",
                 "MW_tree_02", "MW_tree_03", "FV_tree_01", "FV_tree_02", "SM_ChurchTree01"}
put, empty, rng = kit.put, kit.empty, kit.rng
HALF = 140.0
C = (0.0, 30.0)                 # Mitte der Grabanlage
W = 38.0                        # halbe Kantenlänge der Ringmauer

road = kit.spline([(0, -138), (6, -100), (-4, -60), (2, -20), (0, C[1] - W - 2)])
ring = kit.spline([(C[0] - W + 4, C[1] - W + 4), (C[0] + W - 4, C[1] - W + 4), (C[0] + W - 4, C[1] + W - 4),
                   (C[0] - W + 4, C[1] + W - 4), (C[0] - W + 4, C[1] - W + 4)])
axis = kit.spline([(0, C[1] - W + 2), (0, C[1] - 6)])
path_fn = kit.roads_mask([(road, 3.0), (ring, 2.6), (axis, 4.0)], HALF)
kit.terrain(HALF, flat_r=W + 14, hill_h=14.0, tex="Textures_T_LandScapeLayer01_BC.png", normal="Textures_T_LandScapeLayer01_N.png",
            tile=5.0, edge_rise=12.0, res=420, inner_h=0.4, path_tex="Textures_T_LandScapeLayer04_BC.png",
            path_normal="Textures_T_LandScapeLayer04_N.png", path_fn=path_fn)
kit.occupy(0, -50, 8)

# --- Oberfläche des Großen Grabes: Ringmauer, Torbogen, Gräberfelder, Grüfte, großes Mausoleum ----------------
cx, cy = C
gz = kit.ground_fn(cx, cy)
sk = Structs(kit)
sk.plain_wall([(cx - W, cy - W), (cx + W, cy - W), (cx + W, cy + W), (cx - W, cy + W)], height=4.2, T=1.0,
              gaps=[(cx, cy - W)], gap_w=6.0, closed=True, buttress=7.0)
sk.gate_pillars(cx, cy - W, 0.0, width=5.2, h=4.8)
for sx in (-1, 1):                                        # Wächterstatuen am Tor
    put("SM_statuestair", cx + sx * 6.5, cy - W - 2.5, rot=0, s=0.35)
# Großes Mausoleum (Abstieg in die Tiefe)
big = sk.mausoleum(cx, cy + 4.0, 0.0, w=16.0, d=18.0, h=8.0, style="grand", mat="MI_Mausoleum", steps=5)
for sx in (-1, 1):
    for k in range(3):                                    # Engelsstatuen entlang der Achse
        put("SM_Statue01", cx + sx * 5.5, cy - W + 8 + k * 6.5, rot=-90 * sx, s=1.6)
    put("SM_smallbraizer01", cx + sx * 4.2, cy - 12.0, z=big["z"] + 0.35 + 0.22 * 5)
# eisernes Gitter um den Vorplatz des Mausoleums
fx0, fx1, fy0, fy1 = cx - 13.0, cx + 13.0, cy - 15.5, cy + 17.0
sk.iron_fence([(fx0, fy0), (fx1, fy0), (fx1, fy1), (fx0, fy1), (fx0, fy0)], h=1.8, gap_at=0, gap_w=6.0)
# vier Grüfte an den Ecken
for (dx, dy, st) in [(-23, -21, "dome"), (23, -21, "dome"), (-23, 23, "pyramid"), (23, 23, "pyramid")]:
    sk.mausoleum(cx + dx, cy + dy, 0.0 if dy < 0 else 180.0, w=6.0, d=7.0, h=4.6, style=st, mat="MI_MausoleumDark",
                 portico=True)
# Gräberfelder in den Vierteln
for qx0, qx1 in ((cx - W + 4, cx - 15), (cx + 15, cx + W - 4)):
    y = cy - W + 6
    while y < cy + W - 6:
        x = qx0 + rng.uniform(0, 1.0)
        while x < qx1:
            if kit.free(x, y, 1.3):
                r = rng.random()
                if r < 0.35:
                    sk.cross(x, y + 0.9, rng.uniform(-4, 4), h=rng.uniform(1.0, 1.5),
                             tilt=rng.uniform(-10, 10) if rng.random() < 0.2 else 0.0)
                elif r < 0.6:
                    sk.slab(x, y, rng.uniform(-3, 3))
                elif r < 0.66:
                    sk.obelisk(x, y, h=rng.uniform(2.0, 3.2))
                else:
                    put(rng.choice(["SM_tombStone01", "SM_tombstone02"]), x, y + 0.9, rot=180 + rng.uniform(-8, 8),
                        s=rng.uniform(0.9, 1.15), sink=rng.uniform(0.0, 0.2))
                    kit.occupy(x, y, 1.1)
            x += rng.uniform(2.2, 3.0)
        y += rng.uniform(3.6, 4.2)
for _ in range(14):                                       # tote Bäume zwischen den Gräbern
    x, y = rng.uniform(cx - W + 5, cx + W - 5), rng.uniform(cy - W + 5, cy + W - 5)
    if kit.free(x, y, 2.5) and abs(x - cx) > 14:
        kit.ph(rng.choice(["dead_tree_trunk_02", "dead_tree_trunk"]), x, y, rot=rng.uniform(0, 360))
        kit.occupy(x, y, 2.0)
for (x, y) in [(cx - 30, cy + 30), (cx + 30, cy + 30), (cx - 30, cy - 30), (cx + 30, cy - 30)]:
    put("SM_ChurchTree01", x, y, rot=rng.uniform(0, 360), s=1.0)
sk.flush("SM_NazarickSurface")
kit.occupy(C[0], C[1], W + 4)                             # Wald, Wiese und Felsen bleiben draußen

# --- Grasland ringsum ----------------------------------------------------------------------------------
BIG = ["SM_Tree4", "SM_Tree10", "SM_Tree02", "SM_Tree09", "SM_Tree13", "MW_tree_02", "MW_tree_03", "FV_tree_01"]
kit.forest((-HALF + 4, -HALF + 4, HALF - 4, HALF - 4), BIG, 160, min_d=6.0, s=(0.9, 1.4), threshold=0.25,
           density_scale=0.03, under=["SM_Bush07", "SM_Foliage_6", "MW_bush"], under_n=3)
# Waldgürtel als natürliche Grenze: ab ~75 m rings um die Anlage immer dichter, Lücke nur für die Straße
RING = BIG + ["SM_Tree05", "SM_Tree06", "FV_tree_02", "SM_ChurchTree01"]
placed_ring = 0
for _ in range(9000):
    x, y = rng.uniform(-HALF + 3, HALF - 3), rng.uniform(-HALF + 3, HALF - 3)
    d = math.hypot(x - C[0], y - C[1] + 10)
    if d < 72 or (abs(x) < 7 and y < -60):
        continue
    if rng.random() > min(1.0, (d - 72) / 30.0):
        continue
    if not kit.free(x, y, 3.2):
        continue
    put(rng.choice(RING), x, y, rot=rng.uniform(0, 360), s=rng.uniform(0.9, 1.6), sink=0.2)
    kit.occupy(x, y, 2.6)
    placed_ring += 1
    if rng.random() < 0.6:
        put(rng.choice(["SM_Bush07", "SM_Foliage_6", "MW_bush", "SM_Bush01"]), x + rng.uniform(-2.5, 2.5), y + rng.uniform(-2.5, 2.5),
            rot=rng.uniform(0, 360), s=rng.uniform(0.9, 1.5), nocol=True)
print("OVERLORD waldguertel", placed_ring)
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
empty("Gate", big["door"][0], big["door"][1] - 1.5, big["door"][2])
for i, a in enumerate([200, 235, 270, 305, 340, 20]):
    r = math.radians(a)
    empty("Slot%d" % (i + 1), cx + math.cos(r) * 6.0, cy - W - 14 + math.sin(r) * 4.0)
empty("Board", 4.0, cy - W - 10.0)
for i, sx in enumerate((-1, 1)):
    empty("Fire_%d" % (i + 1), cx + sx * 4.2, cy - 12.0, big["z"] + 0.35 + 0.22 * 5 + 1.2)
    empty("Violet_%d" % (i + 1), cx + sx * 6.0, cy - 13.5, big["z"] + 3.0)
kit.finish_materials(metal_keys=("braizer",))
kit.export()
