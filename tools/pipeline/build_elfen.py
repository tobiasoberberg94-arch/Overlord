# Blender: Ewiger Wald der Elfen – Riesenbäume mit Baumhäusern auf Plattformen, Hängebrücken zwischen den
# Kronen, Laternen, alte Elfenruinen und der Baumpalast des Königs Decem Hougan im Norden.
#   blender -b -P build_elfen.py -- <TobKit-Ordner> <ziel.glb>
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from loc_kit import Kit  # noqa: E402

exp_dir, dst = [os.path.abspath(a) for a in sys.argv[sys.argv.index("--") + 1:][:2]]
kit = Kit(exp_dir, dst, seed=73)
kit.lod_names = {"SM_Tree02", "SM_Tree03", "SM_Tree4", "SM_Tree05", "SM_Tree06", "SM_Tree07", "SM_Tree08", "SM_Tree09",
                 "SM_Tree10", "SM_Tree13", "MW_tree_02", "MW_tree_03", "FV_tree_01", "FV_tree_02"}
put, empty, rng = kit.put, kit.empty, kit.rng
HALF = 110.0
C = (0.0, 22.0)               # Elfenhof
PALACE = (0.0, 52.0)

path = kit.spline([(0, -105), (6, -70), (-4, -40), (3, -12), (0, C[1] - 14)])
ring = kit.spline([(C[0] + math.cos(a) * 14, C[1] + math.sin(a) * 14) for a in [k / 24 * math.tau for k in range(25)]])
north = kit.spline([(0, C[1] + 14), (2, PALACE[1] - 10)])
path_fn = kit.roads_mask([(path, 3.0), (ring, 2.6), (north, 3.0)], HALF)
kit.terrain(HALF, flat_r=38.0, hill_h=9.0, tex="Texture_T_Mossy_ForesFloor_BC.png", tile=5.0, edge_rise=14.0, res=380,
            inner_h=0.8, path_tex="Textures_T_LandScapeLayer04_BC.png", path_normal="Textures_T_LandScapeLayer04_N.png",
            path_fn=path_fn)
kit.occupy(C[0], C[1], 30)
kit.occupy(PALACE[0], PALACE[1], 16)
kit.occupy(0, -60, 7)
lamps = []


def tree_house(x, y, a, h, house):
    """Riesenbaum mit Plattform auf Höhe h, Hütte darauf, Leiter am Stamm."""
    put("SM_Tree4", x, y, rot=rng.uniform(0, 360), s=1.55, sink=0.3)
    gz = kit.ground_fn(x, y)
    ca, sa = math.cos(a), math.sin(a)
    # Plattform: 2×2 Bohlenfelder um den Stamm, zur Hofmitte versetzt
    for i in range(2):
        for j in range(2):
            px = x + (i - 0.5) * 6.0 * ca - (j - 0.5) * 3.0 * sa - ca * 2.5
            py = y + (i - 0.5) * 6.0 * sa + (j - 0.5) * 3.0 * ca - sa * 2.5
            put("FV_floor_plank", px, py, z=gz + h, rot=math.degrees(a))
    for k in range(4):
        b = a + math.pi / 4 + k * math.pi / 2
        put("FV_pillar_01", x + math.cos(b) * 4.2 - ca * 2.5, y + math.sin(b) * 4.2 - sa * 2.5, z=gz, sz=h / 2.88)
    put(house, x - ca * 3.2, y - sa * 3.2, z=gz + h + 0.6, rot=math.degrees(a) + 90, s=0.32)
    for k in range(int(h / 2.4) + 1):
        put("SM_Ladder01", x - ca * 6.0, y - sa * 6.0, z=gz + k * 2.4, rot=math.degrees(a) + 90)
    lamps.append((x - ca * 6.5, y - sa * 6.5, gz + h + 2.2))
    return (x - ca * 5.5, y - sa * 5.5, gz + h)


# --- Elfenhof: fünf Baumhäuser im Kreis, Hängebrücken zwischen den Plattformen ---------------------------------
homes = []
houses = ["FV_house_02", "FV_house_03", "FV_house_05", "FV_house_02", "FV_house_03"]
for k in range(5):
    a = math.radians(-90 + 36 + k * 72)
    x, y = C[0] + math.cos(a) * 24, C[1] + math.sin(a) * 24
    homes.append(tree_house(x, y, a, rng.uniform(6.5, 8.0), houses[k]))
for k in range(5):
    p0, p1 = homes[k], homes[(k + 1) % 5]
    if k == 4:
        continue                               # Südseite offen (Zugang)
    dx, dy = p1[0] - p0[0], p1[1] - p0[1]
    ln = math.hypot(dx, dy)
    rot = math.degrees(math.atan2(dy, dx))
    n = max(1, int(ln / 16.5))
    for i in range(n):
        t = (i + 0.5) / n
        put("FV_bridge", p0[0] + dx * t, p0[1] + dy * t, z=(p0[2] + p1[2]) / 2 - 0.4, rot=rot, sz=0.8, s=ln / n / 17.0)
# Mitte: Brunnen aus Ruinen, Elfenstatue, Lagerfeuer
put("SM_firestone", C[0], C[1])
for k in range(6):
    a = k / 6 * math.tau
    put("SM_column_ruin_module_bottom", C[0] + math.cos(a) * 6, C[1] + math.sin(a) * 6, rot=math.degrees(a))
    put("SM_column_ruin_module_body", C[0] + math.cos(a) * 6, C[1] + math.sin(a) * 6,
        z=kit.ground_fn(C[0], C[1]) + 0.9, rot=math.degrees(a))
put("SM_Statue01", C[0], C[1] + 9.5, rot=180, s=1.6)

# --- Baumpalast des Königs ---------------------------------------------------------------------------------------
px, py = PALACE
put("SM_Tree4", px, py + 4, rot=20, s=2.3, sink=0.5)
for sx in (-1, 1):
    put("SM_Tree4", px + sx * 11, py + 2, rot=rng.uniform(0, 360), s=1.8, sink=0.4)
gz = kit.ground_fn(px, py)
for i in range(-1, 2):
    for j in range(-1, 1):
        put("FV_floor_plank", px + i * 6.0, py + j * 3.0 - 3, z=gz + 0.2)
put("FV_house_01", px, py - 2, z=gz + 0.8, rot=90, s=0.42)
for sx in (-1, 1):
    put("SM_column_ruin_module_bottom", px + sx * 6.5, py - 9)
    put("SM_column_ruin_module_body", px + sx * 6.5, py - 9, z=gz + 0.9)
    put("SM_column_ruin_module_top", px + sx * 6.5, py - 9, z=gz + 3.5)
    lamps.append((px + sx * 6.5, py - 9, gz + 4.5))
# alte Ruinen im Wald
for _ in range(10):
    a = rng.uniform(0, math.tau)
    d = rng.uniform(42, 80)
    x, y = math.cos(a) * d, C[1] + math.sin(a) * d
    if kit.free(x, y, 6):
        for k in range(rng.randint(2, 4)):
            put(rng.choice(["SM_column_ruin_module_bottom", "SM_old_stone_wall", "SM_Mossy_Stone_Wall01"]), x + rng.uniform(-4, 4),
                y + rng.uniform(-4, 4), rot=rng.uniform(0, 360), s=rng.uniform(0.6, 1.0), sink=0.3)
        kit.occupy(x, y, 6)

# --- Wald: Riesen am Rand, Unterholz, Farne -------------------------------------------------------------------------
for _ in range(60):
    a = rng.uniform(0, math.tau)
    d = rng.uniform(40, 100)
    x, y = math.cos(a) * d, C[1] + math.sin(a) * d
    if abs(x) < 8 and y < -20:
        continue
    if kit.free(x, y, 7) and path_fn(x, y) < 0.3:
        put("SM_Tree4", x, y, rot=rng.uniform(0, 360), s=rng.uniform(1.3, 2.0), sink=0.3)
        kit.occupy(x, y, 5)
BIG = ["SM_Tree10", "SM_Tree02", "SM_Tree09", "SM_Tree13", "SM_Tree03", "MW_tree_02", "MW_tree_03", "FV_tree_02", "FV_tree_01"]
UNDER = ["SM_Bush07", "SM_Foliage_56", "SM_Bush01", "SM_Foliage_59", "SM_Foliage_22", "SM_Foliage_24", "SM_Foliage_27",
         "SM_Foliage_12", "MW_bush", "FV_bush_05", "SM_Bush03"]
kit.forest((-HALF + 3, -HALF + 3, HALF - 3, HALF - 3), BIG, 700, min_d=3.6, s=(1.0, 1.5), under=UNDER, under_n=3,
           threshold=-0.4, density_scale=0.05)
ALL = (-HALF + 2, -HALF + 2, HALF - 2, HALF - 2)
kit.grass(ALL, 20000, s=(0.8, 1.4))
kit.grass(ALL, 2600, kind="@flower", s=(0.7, 1.1))
kit.meadow(ALL, UNDER + ["SM_Foliage_33", "SM_Foliage_34", "MW_plant_ground", "MW_flower_clump_01", "MW_flower_clump_03"], 2400,
           s=(0.8, 1.4))
for _ in range(60):
    x, y = rng.uniform(-HALF + 5, HALF - 5), rng.uniform(-HALF + 5, HALF - 5)
    if path_fn(x, y) < 0.5 and kit.free(x, y, 2):
        put(rng.choice(["SM_Rock01", "SM_Rock03", "SM_MossyGround01", "SM_ground_rock_02", "SM_rock_03"]), x, y,
            rot=rng.uniform(0, 360), s=rng.uniform(0.3, 0.9), sink=0.4)

# --- Anker -----------------------------------------------------------------------------------------------------------
empty("Spawn", 0.0, -60.0, rot=0)
empty("Gate", 0.0, -66.0)
empty("Keeper", px, py - 6, rot=180)
for i, a in enumerate([200, 235, 270, 305, 340, 20]):
    r = math.radians(a)
    empty("Slot%d" % (i + 1), C[0] + math.cos(r) * 9, C[1] - 4 + math.sin(r) * 6)
for i, (x, y, z) in enumerate(lamps):
    empty("Lamp_%d" % (i + 1), x, y, z)
for i in range(8):
    a = i / 8 * math.tau
    empty("Violet_%d" % (i + 1), C[0] + math.cos(a) * 36, C[1] + math.sin(a) * 36, kit.ground_fn(C[0], C[1]) + 2.5)
empty("Fire_1", C[0], C[1], kit.ground_fn(C[0], C[1]) + 0.6)
n = 1
for k in range(0, len(path), 10):
    empty("Walk_%d" % n, path[k][0], path[k][1])
    n += 1
kit.finish_materials(metal_keys=("lamp",))
kit.export()
