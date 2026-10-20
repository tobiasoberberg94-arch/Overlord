# Blender: Sümpfe der Echsenmenschen – nebliges Moor, das Dorf der Grünen Klaue auf einer Insel hinter einer
# Palisade: Rundhütten auf Pfählen mit Strohdächern (struct_kit.stilt_hut), Häuptlingshütte, Totempfähle,
# Trockengestelle, Feuerplatz; Pfahlhütten im Wasser mit Bohlenstegen, Anleger mit Booten, Dämme als Wege;
# Kampfplatz (Steinkreis) auf der Nordinsel, Schilf, tote Bäume.
#   blender -b -P build_sumpf.py -- <TobKit-Ordner> <ziel.glb>
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from loc_kit import Kit  # noqa: E402
from town_kit import Town, ROAD, PLAZA, FREE, YARD, HOUSE, RESERVED  # noqa: E402
from struct_kit import Structs  # noqa: E402
from mathutils import noise, Vector  # noqa: E402

exp_dir, dst = [os.path.abspath(a) for a in sys.argv[sys.argv.index("--") + 1:][:2]]
kit = Kit(exp_dir, dst, seed=91)
kit.lod_names = {"SM_Tree05", "SM_Tree06", "SM_Tree07", "SM_Tree08", "SM_Tree13", "MW_tree_02", "FV_tree_02"}
put, empty, rng = kit.put, kit.empty, kit.rng
HALF = 110.0
WATER = -0.35
VILLAGE = (0.0, 18.0)
ARENA = (0.0, 62.0)
R_ISLAND = 24.0
town = Town(kit, HALF)
sk = Structs(kit, town)

path = kit.spline([(0, -105), (-6, -70), (4, -40), (-2, -16), (0, VILLAGE[1] - R_ISLAND + 2)])
north = kit.spline([(0, VILLAGE[1] + R_ISLAND - 2), (5, 44), (0, ARENA[1] - 10)])


def seg_d(x, y, line):
    best = 1e9
    for (ax, ay), (bx, by) in zip(line[:-1], line[1:]):
        dx, dy = bx - ax, by - ay
        L = dx * dx + dy * dy or 1e-6
        t = max(0.0, min(1.0, ((x - ax) * dx + (y - ay) * dy) / L))
        best = min(best, math.hypot(x - (ax + t * dx), y - (ay + t * dy)))
    return best


def smooth(a, b, v):
    t = max(0.0, min(1.0, (v - a) / (b - a)))
    return t * t * (3 - 2 * t)


ISLES = [(rng.uniform(-80, 80), rng.uniform(-80, 90), rng.uniform(5, 12)) for _ in range(16)]


def shape(x, y, h):
    # Moor knapp unter dem Wasserspiegel; Inseln, Dorf und Dämme auf feste Höhen über dem Wasser angehoben
    base = WATER - 0.55 + 0.5 * noise.noise(Vector((x * 0.05, y * 0.05, 3.3)))
    out = base

    def lift(target, w):
        nonlocal out
        out = max(out, base * (1.0 - w) + target * w)
    d_v = math.hypot(x - VILLAGE[0], y - VILLAGE[1])
    lift(WATER + 0.95 + 0.1 * noise.noise(Vector((x * 0.2, y * 0.2, 1.0))), 1.0 - smooth(R_ISLAND - 4, R_ISLAND + 3, d_v))
    lift(WATER + 0.8, 1.0 - smooth(11, 17, math.hypot(x - ARENA[0], y - ARENA[1])))
    for (ix, iy, r) in ISLES:
        lift(WATER + 0.45, 1.0 - smooth(r * 0.6, r, math.hypot(x - ix, y - iy)))
    for line in (path, north):
        lift(WATER + 0.55, 1.0 - smooth(2.4, 4.8, seg_d(x, y, line)))
    edge = smooth(80.0, 108.0, max(abs(x), abs(y)))               # Kartenrand: Uferhügel
    return out + edge * 6.0 + h * 0.1


TERRAIN = dict(half=HALF, flat_r=100.0, hill_h=4.0, edge_rise=0.0, inner_h=0.0, height_fn=shape)
kit.height_field(**TERRAIN)
g0 = kit.ground_fn

# Wasserfläche über das ganze Moor
w = put("MW_water_plane", 0, 0, z=WATER, s=2.3, nocol=False)
if w is not None:
    w.name = "Water_Moor"
town.road(path, 3.2, paved=False)
town.road(north, 3.0, paved=False)
vx, vy = VILLAGE
town.plaza(vx, vy, 8.5, paved=False, ragged=1.0)

# --- Palisade um die Dorfinsel ------------------------------------------------------------------------------------------
PAL = [(vx + math.cos(a) * (R_ISLAND - 3.5), vy + math.sin(a) * (R_ISLAND - 3.5)) for a in [k / 72 * math.tau for k in range(72)]]
gates = [(vx, vy - R_ISLAND + 3.5), (vx, vy + R_ISLAND - 3.5), (vx + R_ISLAND - 3.5, vy)]
TW = [(vx + math.cos(math.radians(d)) * 17.0, vy + math.sin(math.radians(d)) * 17.0) for d in (145, 35)]
town.palisade(PAL, gates=gates, gate_w=4.5, height=3.6, towers=TW, tower_h=6.0)

# --- Hütten auf der Insel ------------------------------------------------------------------------------------------------------
huts = []
for k in range(7):
    a = math.radians(k * (360 / 7) + 18)
    x, y = vx + math.cos(a) * 13.0, vy + math.sin(a) * 13.0
    if any(math.hypot(x - gx, y - gy) < 6 for gx, gy in gates):
        a += math.radians(16)
        x, y = vx + math.cos(a) * 13.0, vy + math.sin(a) * 13.0
    rot = math.degrees(a) - 90                          # Tür (lokal -Y) zur Dorfmitte
    huts.append(sk.stilt_hut(x, y, rot, r=rng.uniform(2.4, 3.0), wall_h=2.1, roof_h=rng.uniform(2.6, 3.4)))
chief = sk.stilt_hut(vx, vy + 9.0, 0.0, r=3.8, wall_h=2.6, roof_h=4.4, chief=True)
for k in range(4):                                       # Totempfähle um den Feuerplatz
    a = math.radians(45 + k * 90)
    sk.totem(vx + math.cos(a) * 5.5, vy + math.sin(a) * 5.5, h=rng.uniform(3.5, 4.6))
put("SM_firestone", vx, vy)
for k in range(3):
    a = math.radians(200 + k * 50)
    sk.drying_rack(vx + math.cos(a) * 7.5, vy + math.sin(a) * 7.5, rot=math.degrees(a) + 90)
for _ in range(10):
    a, d = rng.uniform(0, math.tau), rng.uniform(4, 10)
    kit.ph(rng.choice(["wicker_basket_01", "wicker_basket_02", "wooden_bucket_02", "wooden_bowl_01", "barrel_03"]),
           vx + math.cos(a) * d, vy + math.sin(a) * d, rot=rng.uniform(0, 360))

# --- Pfahlhütten im Wasser mit Stegen ---------------------------------------------------------------------------------------
for k, deg in enumerate((150, 190, 230, 320, 20)):
    a = math.radians(deg)
    hx, hy = vx + math.cos(a) * (R_ISLAND + 11), vy + math.sin(a) * (R_ISLAND + 11)
    deck = WATER + 1.7
    sk.stilt_hut(hx, hy, math.degrees(a) - 90, r=2.6, deck_z=deck, wall_h=2.1, roof_h=3.0, stairs=False)
    sx_, sy_ = vx + math.cos(a) * (R_ISLAND - 1.5), vy + math.sin(a) * (R_ISLAND - 1.5)
    ex, ey = hx - math.cos(a) * 3.9, hy - math.sin(a) * 3.9
    sk.boardwalk([(sx_, sy_), (ex, ey)], deck, width=1.5)
# Anleger mit Booten (Süden)
for k in range(3):
    a = math.radians(245 + k * 22)
    sx_, sy_ = vx + math.cos(a) * (R_ISLAND - 1.0), vy + math.sin(a) * (R_ISLAND - 1.0)
    ex, ey = vx + math.cos(a) * (R_ISLAND + 9), vy + math.sin(a) * (R_ISLAND + 9)
    sk.boardwalk([(sx_, sy_), (ex, ey)], WATER + 0.55, width=1.8)
    put("MW_boat_01", ex + math.cos(a + 1.2) * 2.4, ey + math.sin(a + 1.2) * 2.4, z=WATER - 0.4,
        rot=math.degrees(a) + rng.uniform(-15, 15), s=0.9)

# --- Kampfplatz im Norden: Steinkreis auf der Insel ------------------------------------------------------------------------------
ax, ay = ARENA
for k in range(9):
    a = k / 9 * math.tau
    put(rng.choice(["SM_column_ruin_module_bottom", "SM_rock_02", "SM_column_ruin_module_body"]), ax + math.cos(a) * 11,
        ay + math.sin(a) * 11, rot=rng.uniform(0, 360), s=rng.uniform(0.8, 1.2), sink=0.3)
put("SM_firestone", ax, ay)
town.plaza(ax, ay, 9.0, paved=False, ragged=1.2)
for k in range(6):
    a = k / 6 * math.tau + 0.3
    sk.totem(ax + math.cos(a) * 14.5, ay + math.sin(a) * 14.5, h=rng.uniform(3.0, 4.2), skulls=2)

# --- Moor: Schilf am Wasser, tote Bäume, Felsen -------------------------------------------------------------------------------------
reeds = 0
for _ in range(9000):
    x, y = rng.uniform(-HALF + 3, HALF - 3), rng.uniform(-HALF + 3, HALF - 3)
    gz = g0(x, y)
    if abs(gz - WATER) < 0.4 and town.at(x, y) == FREE and kit.free(x, y, 0.8):
        put(rng.choice(["SM_WheatGrass01", "SM_WheatGrass03", "SM_Foliage_33"]), x, y, rot=rng.uniform(0, 360), s=rng.uniform(0.8, 1.5),
            nocol=True)
        reeds += 1
print("OVERLORD schilf", reeds)
for _ in range(500):
    x, y = rng.uniform(-HALF + 5, HALF - 5), rng.uniform(-HALF + 5, HALF - 5)
    if town.at(x, y) == FREE and kit.free(x, y, 4) and g0(x, y) > WATER - 0.3:
        put(rng.choice(["SM_Tree05", "SM_Tree06", "SM_Tree13", "SM_Tree07", "MW_tree_02"]), x, y, rot=rng.uniform(0, 360),
            s=rng.uniform(0.8, 1.4), sink=0.3)
        kit.occupy(x, y, 3)
for _ in range(40):
    x, y = rng.uniform(-HALF + 5, HALF - 5), rng.uniform(-HALF + 5, HALF - 5)
    if town.at(x, y) == FREE and kit.free(x, y, 3):
        kit.ph(rng.choice(["dead_tree_trunk", "dead_tree_trunk_02", "root_cluster_01", "tree_stump_02"]), x, y, z=max(g0(x, y), WATER - 0.2),
               rot=rng.uniform(0, 360))
        kit.occupy(x, y, 2.5)

sk.flush("SM_EchsenDorf")
kit.terrain(HALF, flat_r=TERRAIN["flat_r"], hill_h=TERRAIN["hill_h"], tex="Texture_T_Mossy_ForesFloor_BC.png", tile=5.0,
            edge_rise=0.0, res=400, inner_h=0.0, path_tex="Textures_T_LandScapeLayer04_BC.png",
            path_normal="Textures_T_LandScapeLayer04_N.png", path_fn=town.path_fn, dirt_fn=town.dirt_fn, height_fn=shape)
ALL = (-HALF + 2, -HALF + 2, HALF - 2, HALF - 2)
kit.grass(ALL, 14000, s=(0.8, 1.5))
kit.meadow(ALL, ["SM_Foliage_22", "SM_Foliage_24", "SM_Foliage_56", "SM_Bush07", "MW_plant_ground"], 1600, s=(0.8, 1.3))

# --- Anker ---------------------------------------------------------------------------------------------------------------------------
empty("Spawn", 0.0, -60.0, rot=0)
empty("Gate", 0.0, -66.0)
empty("Keeper", ax, ay - 2, rot=180)
empty("Board", 4.5, -54.0)
for i, a in enumerate([200, 235, 270, 305, 340, 20]):
    r = math.radians(a)
    empty("Slot%d" % (i + 1), ax + math.cos(r) * 6, ay - 2 + math.sin(r) * 5)
fires = [(vx, vy, g0(vx, vy) + 0.8)] + [(h["door"][0], h["door"][1], h["deck"] + 2.0) for h in huts[:4]]
for i, (x, y, z) in enumerate(fires):
    empty("Fire_%d" % (i + 1), x, y, z)
for i in range(6):
    a = i / 6 * math.tau
    empty("Violet_%d" % (i + 1), math.cos(a) * 45, 10 + math.sin(a) * 45, WATER + 1.5)
n = 1
for line, step in [(path, 8), (north, 6)]:
    for k in range(0, len(line), step):
        x, y = line[k]
        empty("Walk_%d" % n, x, y)
        n += 1
town.save_map(os.path.splitext(dst)[0] + "_map.png")
kit.finish_materials()
kit.export()
