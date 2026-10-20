# Blender: Ewiger Wald der Elfen (struct_kit) – Riesenbäume mit mächtigen Stämmen (Rinde, Wurzelanläufe), um die
# Stämme Wendeltreppen hinauf zu Ringplattformen mit Pavillons (geschwungene Dächer), Hängebrücken zwischen den
# Plattformen, Laternen; in der Mitte des Elfenhofs ein alter Steinkreis mit Statue. Im Norden der Baumpalast von
# König Decem Hougan: der größte Baum auf einer Steinterrasse, Halle am Stammfuß, zwei Plattformen übereinander.
# Ringsum der Urwald mit weiteren Riesenbäumen, Unterholz und alten Ruinen.
#   blender -b -P build_elfen.py -- <TobKit-Ordner> <ziel.glb>
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from loc_kit import Kit  # noqa: E402
from town_kit import Town, ROAD, PLAZA, FREE, YARD, HOUSE, RESERVED  # noqa: E402
from struct_kit import Structs  # noqa: E402
from mathutils import noise, Vector, Matrix  # noqa: E402

exp_dir, dst = [os.path.abspath(a) for a in sys.argv[sys.argv.index("--") + 1:][:2]]
up = os.path.dirname(exp_dir)
kit = Kit(exp_dir, dst, seed=73, extra_dirs=[os.path.join(up, "AMRExport")])
kit.lod_names = {"SM_Tree02", "SM_Tree03", "SM_Tree4", "SM_Tree05", "SM_Tree06", "SM_Tree07", "SM_Tree08", "SM_Tree09",
                 "SM_Tree10", "SM_Tree13", "MW_tree_02", "MW_tree_03", "FV_tree_01", "FV_tree_02"}
put, empty, rng = kit.put, kit.empty, kit.rng
HALF = 110.0
C = (0.0, 22.0)                 # Elfenhof
PALACE = (0.0, 66.0)
town = Town(kit, HALF)
sk = Structs(kit, town)
TERRAIN = dict(half=HALF, flat_r=44.0, hill_h=9.0, edge_rise=14.0, inner_h=0.6)
kit.height_field(**TERRAIN)

path = kit.spline([(0, -105), (6, -70), (-4, -40), (3, -12), (0, C[1] - 16)])
ringp = kit.spline([(C[0] + math.cos(a) * 15, C[1] + math.sin(a) * 15) for a in [k / 28 * math.tau for k in range(29)]])
north = kit.spline([(0, C[1] + 15), (2, PALACE[1] - 18)])
town.road(path, 3.2, paved=False)
town.road(ringp, 2.6, paved=False)
town.road(north, 3.2, paved=False)
town.plaza(C[0], C[1], 9.0, paved=False, ragged=1.0)
lamps = []


def ang_to(ax, ay, bx, by):
    return math.degrees(math.atan2(by - ay, bx - ax))


def giant(x, y, h, r0, r1, crown="SM_Tree02", crown_s=2.6):
    g, r_fn = sk.giant_trunk(x, y, h, r0, r1)
    put(crown, x, y, z=g + h - 6.0, rot=rng.uniform(0, 360), s=crown_s)
    town.mark_rect(x, y, (r0 + 2) * 2, (r0 + 2) * 2, 0, HOUSE)
    return g, r_fn


# --- Elfenhof: fünf Riesenbäume im Kreis mit Plattformen, Pavillons, Wendeltreppen ------------------------------------
TREES = []
for k in range(5):
    a = math.radians(-54 + k * 72)
    x, y = C[0] + math.cos(a) * 27, C[1] + math.sin(a) * 27
    h = rng.uniform(14.0, 17.0)
    g, r_fn = giant(x, y, h, rng.uniform(2.3, 2.7), rng.uniform(1.4, 1.7), crown=rng.choice(["SM_Tree02", "SM_Tree03"]))
    z = g + 0.6 + rng.uniform(7.5, 8.6)
    TREES.append({"x": x, "y": y, "g": g, "r_fn": r_fn, "z": z})
for k, t in enumerate(TREES):
    x, y, z, r_fn = t["x"], t["y"], t["z"], t["r_fn"]
    rt = r_fn(z)
    t["r_in"], t["r_out"] = rt + 1.45, rt + 1.45 + 4.6
    toward = ang_to(x, y, C[0], C[1])
    bridges = []
    if k > 0:
        bridges.append(ang_to(x, y, TREES[k - 1]["x"], TREES[k - 1]["y"]))
    if k < 4:
        bridges.append(ang_to(x, y, TREES[k + 1]["x"], TREES[k + 1]["y"]))
    t["bridges"] = bridges
    top = sk.spiral_stair(x, y, t["g"] + 0.6, z, toward, r_fn, direction=1 if k % 2 else -1)
    sk.tree_platform(x, y, z, t["r_in"], t["r_out"], openings=bridges, inner_openings=[top], r_trunk=rt)
    sk.ring_pavilion(x, y, z, rt, t["r_out"], h=3.0, openings=bridges + [toward])
    for j in range(3):                                      # Laternen und Krüge auf der Plattform
        a = math.radians(toward + 60 + j * 100)
        p = sk._P(x, y, a, t["r_out"] - 1.0, z)
        kit.ph(rng.choice(["wooden_lantern_01", "Lantern_01"]), p.x, p.y, z=p.z, rot=rng.uniform(0, 360))
        lamps.append((p.x, p.y, p.z + 0.6))
    for j in range(2):
        a = math.radians(toward + 150 + j * 70)
        p = sk._P(x, y, a, t["r_out"] - 1.8, z)
        kit.ph(rng.choice(["wicker_basket_01", "ceramic_vase_01", "wooden_bowl_02", "painted_wooden_bench"]), p.x, p.y, z=p.z,
               rot=rng.uniform(0, 360))
for k in range(4):                                          # Hängebrücken zwischen den Plattformen
    t0, t1 = TREES[k], TREES[k + 1]
    a01 = math.radians(ang_to(t0["x"], t0["y"], t1["x"], t1["y"]))
    a10 = math.radians(ang_to(t1["x"], t1["y"], t0["x"], t0["y"]))
    p0 = sk._P(t0["x"], t0["y"], a01, t0["r_out"] - 0.15, t0["z"])
    p1 = sk._P(t1["x"], t1["y"], a10, t1["r_out"] - 0.15, t1["z"])
    sk.rope_bridge(p0, p1, width=1.5)

# Mitte: alter Steinkreis, Statue, Feuer
put("SM_firestone", C[0], C[1])
for k in range(6):
    a = k / 6 * math.tau
    put("SM_column_ruin_module_bottom", C[0] + math.cos(a) * 6, C[1] + math.sin(a) * 6, rot=math.degrees(a))
    put("SM_column_ruin_module_body", C[0] + math.cos(a) * 6, C[1] + math.sin(a) * 6,
        z=kit.ground_fn(C[0], C[1]) + 0.9, rot=math.degrees(a))
put("SM_Statue01", C[0], C[1] + 9.5, rot=180, s=1.6)

# --- Baumpalast -------------------------------------------------------------------------------------------------------------
px, py = PALACE
g, r_fn = giant(px, py, 24.0, 4.3, 2.4, crown="SM_Tree03", crown_s=3.4)
# Steinterrasse mit Treppe nach Süden
T_H = 1.2
for (rr, zz) in ((15.5, 0.0), (14.0, T_H * 0.5)):
    sk.cyl(Matrix.Translation((px, py, g + 0.4 - 1.0)), rr, 0.0, 1.0 + zz + T_H * 0.5, "MI_ElfStone", sides=36)
for s_ in range(4):
    d_ = 15.5 + (4 - s_) * 0.45
    sk.box(sk.frame(px, py - d_ + 0.2, g + 0.4 - 1.0, 0.0), 8.0, 0.9, 1.0 + T_H * (s_ + 1) / 4, "MI_ElfStone", z0=0.0)
terrace = g + 0.4 + T_H
sk.ring_pavilion(px, py, terrace, r_fn(terrace), 12.5, h=4.6, openings=[-90, 0, 180, 90], wall_mat="MI_Planks")
for sx in (-1, 1):
    put("SM_Statue01", px + sx * 5.0, py - 17.5, rot=0, s=2.0)
    kit.ph("Lantern_01", px + sx * 3.2, py - 16.0, z=terrace)
    lamps.append((px + sx * 3.2, py - 16.0, terrace + 1.2))
z1 = g + 10.5
z2 = g + 17.5
rt1, rt2 = r_fn(z1), r_fn(z2)
a_mid = sk.spiral_stair(px, py, terrace, z1, -90.0, r_fn, width=1.5, direction=1)
a_top = sk.spiral_stair(px, py, z1, z2, a_mid, r_fn, width=1.5, direction=1)
sk.tree_platform(px, py, z1, rt1 + 1.6, rt1 + 1.6 + 6.0, inner_openings=[a_mid], r_trunk=rt1, braces=9)
sk.tree_platform(px, py, z2, rt2 + 1.6, rt2 + 1.6 + 4.6, inner_openings=[a_top], r_trunk=rt2, braces=8)
sk.ring_pavilion(px, py, z2, rt2, rt2 + 1.6 + 4.6, h=3.4, openings=[a_top, -90])
for j in range(6):
    a = math.radians(j * 60 + 15)
    p = sk._P(px, py, a, rt1 + 1.6 + 5.0, z1)
    kit.ph("wooden_lantern_01", p.x, p.y, z=p.z, rot=rng.uniform(0, 360))
    lamps.append((p.x, p.y, p.z + 0.6))
p = sk._P(px, py, math.radians(-90), rt2 + 4.0, z2)
kit.ph("GothicCabinet_01", p.x, p.y, z=p.z, rot=0)
town.mark_rect(px, py, 34, 34, 0, RESERVED)

# --- Urwald: weitere Riesenbäume, Ruinen -------------------------------------------------------------------------------
for _ in range(40):
    a = rng.uniform(0, math.tau)
    d = rng.uniform(48, 98)
    x, y = math.cos(a) * d, C[1] + math.sin(a) * d
    if abs(x) < 10 and y < -15 or abs(x) > HALF - 8 or abs(y) > HALF - 8:
        continue
    if town.rect_free(x, y, 12, 12, 0, (FREE,)) and kit.free(x, y, 8):
        giant(x, y, rng.uniform(12, 18), rng.uniform(1.8, 2.6), rng.uniform(1.1, 1.5), crown=rng.choice(["SM_Tree02", "SM_Tree03"]),
              crown_s=rng.uniform(2.2, 2.8))
        kit.occupy(x, y, 6)
for _ in range(10):
    a = rng.uniform(0, math.tau)
    d = rng.uniform(42, 80)
    x, y = math.cos(a) * d, C[1] + math.sin(a) * d
    if kit.free(x, y, 6) and town.at(x, y) == FREE:
        for k in range(rng.randint(2, 4)):
            put(rng.choice(["SM_column_ruin_module_bottom", "SM_old_stone_wall", "SM_Mossy_Stone_Wall01"]), x + rng.uniform(-4, 4),
                y + rng.uniform(-4, 4), rot=rng.uniform(0, 360), s=rng.uniform(0.6, 1.0), sink=0.3)
        kit.occupy(x, y, 6)

BIG = ["SM_Tree10", "SM_Tree02", "SM_Tree09", "SM_Tree13", "SM_Tree03", "MW_tree_02", "MW_tree_03", "FV_tree_02", "FV_tree_01"]
UNDER = ["SM_Bush07", "SM_Foliage_56", "SM_Bush01", "SM_Foliage_59", "SM_Foliage_22", "SM_Foliage_24", "SM_Foliage_27",
         "SM_Foliage_12", "MW_bush", "FV_bush_05", "SM_Bush03"]
for (x, y, *_r) in [(t["x"], t["y"]) for t in TREES] + [(px, py)]:
    kit.occupy(x, y, 9)
kit.occupy(C[0], C[1], 20)
kit.occupy(px, py, 18)
kit.forest((-HALF + 3, -HALF + 3, HALF - 3, HALF - 3), BIG, 620, min_d=3.6, s=(1.0, 1.5), under=UNDER, under_n=3,
           threshold=-0.4, density_scale=0.05, avoid=[(-6, -HALF, 6, C[1] - 12)])

sk.flush("SM_Elfenwald")
kit.terrain(HALF, flat_r=TERRAIN["flat_r"], hill_h=TERRAIN["hill_h"], tex="Texture_T_Mossy_ForesFloor_BC.png", tile=5.0,
            edge_rise=TERRAIN["edge_rise"], res=400, inner_h=TERRAIN["inner_h"], path_tex="Textures_T_LandScapeLayer04_BC.png",
            path_normal="Textures_T_LandScapeLayer04_N.png", path_fn=town.path_fn, dirt_fn=town.dirt_fn)
ALL = (-HALF + 2, -HALF + 2, HALF - 2, HALF - 2)
kit.grass(ALL, 20000, s=(0.8, 1.4))
kit.grass(ALL, 2600, kind="@flower", s=(0.7, 1.1))
kit.meadow(ALL, UNDER + ["SM_Foliage_33", "SM_Foliage_34", "MW_plant_ground", "MW_flower_clump_01", "MW_flower_clump_03"], 2400,
           s=(0.8, 1.4))

# --- Anker -------------------------------------------------------------------------------------------------------------------
empty("Spawn", 0.0, -60.0, rot=0)
empty("Gate", 0.0, -66.0)
empty("Keeper", px, py - 15.0, z=terrace, rot=180)
empty("Board", 4.5, -54.0)
for i, a in enumerate([200, 235, 270, 305, 340, 20]):
    r = math.radians(a)
    empty("Slot%d" % (i + 1), C[0] + math.cos(r) * 10, C[1] - 4 + math.sin(r) * 6)
for i, (x, y, z) in enumerate(lamps[:48]):
    empty("Lamp_%d" % (i + 1), x, y, z)
for i in range(8):
    a = i / 8 * math.tau
    empty("Violet_%d" % (i + 1), C[0] + math.cos(a) * 40, C[1] + math.sin(a) * 40, kit.ground_fn(C[0], C[1]) + 2.5)
empty("Fire_1", C[0], C[1], kit.ground_fn(C[0], C[1]) + 0.6)
n = 1
for line, step in [(path, 10), (ringp, 4), (north, 6)]:
    for k in range(0, len(line), step):
        empty("Walk_%d" % n, line[k][0], line[k][1])
        n += 1
town.save_map(os.path.splitext(dst)[0] + "_map.png")
kit.finish_materials(metal_keys=("lamp",))
kit.export()
