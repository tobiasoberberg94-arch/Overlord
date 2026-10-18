# Blender: Sümpfe der Echsenmenschen – nebliges Moor, Inseln zwischen trübem Wasser, Pfahlhütten der fünf Stämme,
# Bohlenstege, Anleger mit Booten, Schilf und tote Bäume. Kampfplatz der Echsen (Cocytus-Einsatz) im Norden.
#   blender -b -P build_sumpf.py -- <TobKit-Ordner> <ziel.glb>
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from loc_kit import Kit  # noqa: E402

exp_dir, dst = [os.path.abspath(a) for a in sys.argv[sys.argv.index("--") + 1:][:2]]
kit = Kit(exp_dir, dst, seed=91)
kit.lod_names = {"SM_Tree05", "SM_Tree06", "SM_Tree07", "SM_Tree08", "SM_Tree13", "MW_tree_02", "FV_tree_02"}
put, empty, rng = kit.put, kit.empty, kit.rng
HALF = 100.0
WATER = -0.35
VILLAGE = (0.0, 18.0)
ARENA = (0.0, 52.0)

path = kit.spline([(0, -95), (-6, -60), (4, -30), (-2, -6), (0, VILLAGE[1] - 6)])
north = kit.spline([(0, VILLAGE[1] + 8), (4, 34), (0, ARENA[1] - 6)])
path_fn = kit.roads_mask([(path, 2.6), (north, 2.6)], HALF)
kit.terrain(HALF, flat_r=60.0, hill_h=6.0, tex="Texture_T_Mossy_ForesFloor_BC.png", tile=5.0, edge_rise=10.0, res=360,
            inner_h=1.5, path_tex="Textures_T_LandScapeLayer04_BC.png", path_normal="Textures_T_LandScapeLayer04_N.png",
            path_fn=path_fn)
g0 = kit.ground_fn


def ground(x, y):
    # Wege und Dorf liegen erhöht (Dämme), sonst darf das Wasser die Senken füllen
    return g0(x, y)


def dry(x, y):
    return g0(x, y) > WATER + 0.15


# Wasserfläche über das ganze Moor
w = put("MW_water_plane", 0, 0, z=WATER, s=2.0, nocol=False)
if w is not None:
    w.name = "Water_Moor"
kit.occupy(VILLAGE[0], VILLAGE[1], 18)
kit.occupy(ARENA[0], ARENA[1], 12)
kit.occupy(0, -60, 6)
lamps = []

# --- Dorf der Echsenmenschen: Pfahlhütten im Kreis, Stege zur Mitte ------------------------------------------------
vx, vy = VILLAGE
for k in range(7):
    a = math.radians(k * (360 / 7) + 10)
    x, y = vx + math.cos(a) * 13, vy + math.sin(a) * 13
    gz = max(g0(x, y), WATER)
    h = 1.6
    for i in range(4):
        b = a + math.pi / 4 + i * math.pi / 2
        put("FV_pillar_01", x + math.cos(b) * 2.6, y + math.sin(b) * 2.6, z=gz - 0.6, sz=(h + 0.6) / 2.88)
    put("FV_floor_plank", x, y, z=gz + h, rot=math.degrees(a))
    put("FV_house_05", x, y, z=gz + h + 0.55, rot=math.degrees(a) + 90, s=0.28)
    # Steg zur Mitte
    for d in (8.0, 5.0):
        put("MW_wood_planks", vx + math.cos(a) * d, vy + math.sin(a) * d, z=max(g0(vx + math.cos(a) * d, vy + math.sin(a) * d), WATER) + 0.05,
            rot=math.degrees(a) + 90)
    lamps.append((x - math.cos(a) * 3.0, y - math.sin(a) * 3.0, gz + h + 2.2))
put("SM_firestone", vx, vy)
put("SM_Totem" if False else "SM_Statue01", vx, vy + 4.0, rot=180, s=1.4)
for _ in range(14):
    kit.clutter(vx + rng.uniform(-9, 9), vy + rng.uniform(-9, 9), ["SM_Hay", "SM_FireWoodSet02", "FV_barrel_01", "FV_crate_01", "SM_WoodenBucket01"],
                n=(1, 2), r=(0.5, 1.5), s=(0.7, 1.0))
# Anleger mit Booten
for k in range(4):
    a = math.radians(200 + k * 40)
    x, y = vx + math.cos(a) * 24, vy + math.sin(a) * 24
    for d in range(3):
        put("FV_floor_plank", x + math.cos(a) * d * 3.0, y + math.sin(a) * d * 3.0, z=WATER + 0.3, rot=math.degrees(a) + 90)
        put("FV_pillar_01", x + math.cos(a) * d * 3.0, y + math.sin(a) * d * 3.0, z=WATER - 1.5, sz=0.65)
    put("MW_boat_01", x + math.cos(a) * 10 + 2, y + math.sin(a) * 10, z=WATER - 0.4, rot=math.degrees(a) + rng.uniform(-20, 20), s=0.9)

# --- Kampfplatz im Norden: Steinkreis auf einer Insel ---------------------------------------------------------------
ax, ay = ARENA
for k in range(9):
    a = k / 9 * math.tau
    put(rng.choice(["SM_column_ruin_module_bottom", "SM_rock_02", "SM_column_ruin_module_body"]), ax + math.cos(a) * 11, ay + math.sin(a) * 11,
        rot=rng.uniform(0, 360), s=rng.uniform(0.8, 1.2), sink=0.3)
put("SM_firestone", ax, ay)

# --- Moor: Schilf am Wasser, tote Bäume, Felsen ------------------------------------------------------------------------
reeds = 0
for _ in range(7000):
    x, y = rng.uniform(-HALF + 3, HALF - 3), rng.uniform(-HALF + 3, HALF - 3)
    gz = g0(x, y)
    if abs(gz - WATER) < 0.35 and kit.free(x, y, 0.8) and path_fn(x, y) < 0.3:
        put(rng.choice(["SM_WheatGrass01", "SM_WheatGrass03", "SM_Foliage_33"]), x, y, rot=rng.uniform(0, 360), s=rng.uniform(0.8, 1.5), nocol=True)
        reeds += 1
print("OVERLORD schilf", reeds)
for _ in range(400):
    x, y = rng.uniform(-HALF + 5, HALF - 5), rng.uniform(-HALF + 5, HALF - 5)
    if kit.free(x, y, 4) and path_fn(x, y) < 0.3:
        put(rng.choice(["SM_Tree05", "SM_Tree06", "SM_Tree13", "SM_Tree07", "MW_tree_02"]), x, y, rot=rng.uniform(0, 360),
            s=rng.uniform(0.8, 1.4), sink=0.3)
        kit.occupy(x, y, 3)
for _ in range(50):
    x, y = rng.uniform(-HALF + 5, HALF - 5), rng.uniform(-HALF + 5, HALF - 5)
    if kit.free(x, y, 2):
        put(rng.choice(["SM_MossyGround01", "SM_ground_rock_02", "SM_rock_03", "SM_Rock01"]), x, y, rot=rng.uniform(0, 360),
            s=rng.uniform(0.3, 0.9), sink=0.4)
ALL = (-HALF + 2, -HALF + 2, HALF - 2, HALF - 2)
kit.grass(ALL, 14000, s=(0.8, 1.5))
kit.meadow(ALL, ["SM_Foliage_22", "SM_Foliage_24", "SM_Foliage_56", "SM_Bush07", "MW_plant_ground"], 1600, s=(0.8, 1.3))

# --- Anker -----------------------------------------------------------------------------------------------------------------
empty("Spawn", 0.0, -60.0, rot=0)
empty("Gate", 0.0, -66.0)
empty("Keeper", ax, ay - 2, rot=180)
empty("Board", 4.0, -54.0)
for i, a in enumerate([200, 235, 270, 305, 340, 20]):
    r = math.radians(a)
    empty("Slot%d" % (i + 1), ax + math.cos(r) * 6, ay - 2 + math.sin(r) * 5)
for i, (x, y, z) in enumerate(lamps):
    empty("Fire_%d" % (i + 1), x, y, z)
for i in range(6):
    a = i / 6 * math.tau
    empty("Violet_%d" % (i + 1), math.cos(a) * 45, 10 + math.sin(a) * 45, WATER + 1.5)
kit.finish_materials()
kit.export()
