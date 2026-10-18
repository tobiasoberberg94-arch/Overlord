# Blender: Katze-Ebene – verfluchtes Schlachtfeld im ewigen Nebel zwischen Re-Estize und dem Kaiserreich:
# Feldlager des Königreichs im Süden, Knochenfelder mit steckenden Speeren in der Mitte, die Ruine einer
# Grenzfestung im Norden. Hier steht Nazaricks Heer (Todesritter) beim großen Massaker.
#   blender -b -P build_katze.py -- <WorldKit-Ordner> <ziel.glb>
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from loc_kit import Kit  # noqa: E402

exp_dir, dst = [os.path.abspath(a) for a in sys.argv[sys.argv.index("--") + 1:][:2]]
kit = Kit(exp_dir, dst, seed=27)
kit.lod_names = {"SM_Tree05", "SM_Tree06", "SM_Tree13"}
put, empty, rng = kit.put, kit.empty, kit.rng
HALF = 120.0
CAMP = (26.0, -34.0)
FORT = (0.0, 62.0)

road = kit.spline([(0, -115), (4, -70), (-3, -30), (2, 10), (0, FORT[1] - 16)])
path_fn = kit.roads_mask([(road, 3.2)], HALF)
kit.terrain(HALF, flat_r=70.0, hill_h=8.0, tex="Textures_T_LandScapeLayer02_BC.png", normal="Textures_T_LandScapeLayer02_N.png",
            tile=6.0, edge_rise=16.0, res=380, inner_h=0.9, path_tex="Textures_T_LandScapeLayer04_BC.png",
            path_normal="Textures_T_LandScapeLayer04_N.png", path_fn=path_fn)
kit.occupy(CAMP[0], CAMP[1], 18)
kit.occupy(FORT[0], FORT[1], 22)
kit.occupy(0, -70, 7)
lamps = []

# --- Feldlager des Königreichs --------------------------------------------------------------------------------------
cx, cy = CAMP
for i in range(-2, 3):
    for j in range(-1, 2):
        x, y = cx + i * 5.5 + rng.uniform(-0.6, 0.6), cy + j * 6.5 + rng.uniform(-0.6, 0.6)
        put("SM_Tent_low", x, y, rot=rng.choice([0, 180]) + rng.uniform(-8, 8), s=2.4)
for k in range(28):
    a = k / 28 * math.tau
    if abs(math.degrees(a) - 180) < 14:
        continue                                        # Lagertor nach Westen
    put("SM_Fence01", cx + math.cos(a) * 19, cy + math.sin(a) * 15, rot=math.degrees(a) + 90, s=1.3, sink=0.2)
for k in range(5):
    put("SM_WoodenWagon01", cx + rng.uniform(-14, 14), cy + rng.uniform(-11, 11), rot=rng.uniform(0, 360), s=1.2)
for (x, y) in [(cx - 12, cy - 8), (cx + 12, cy - 8), (cx - 12, cy + 8), (cx + 12, cy + 8), (cx, cy)]:
    put("SM_StandLight", x, y, s=1.2)
    lamps.append((x, y, kit.ground_fn(x, y) + 2.9))
for k in range(6):                                      # Banner auf Speeren
    x, y = cx - 16 + k * 6.5, cy + 16
    put("SM_Spear_low", x, y, z=kit.ground_fn(x, y) - 0.1, s=2.6)
    put("SM_Cloth01", x + 0.35, y, z=kit.ground_fn(x, y) + 3.6, rot=90, s=3.5)
kit.clutter(cx, cy, ["SM_FireWoodSet01", "FV_barrel_group_01", "FV_crate_group_01", "SM_WoodenBox02", "SM_Hay"], n=(10, 14), r=(2, 14))

# --- Knochenfelder ---------------------------------------------------------------------------------------------------
BONES = ["SM_Skeleton_01", "SM_Skeleton_02", "SM_Skeleton_03", "SM_Skeleton_04", "SM_Skeleton_05", "SM_Skeleton_06", "SM_Skeleton_07", "SM_Skeleton_08"]
for _ in range(70):
    x, y = rng.uniform(-70, 70), rng.uniform(-50, 45)
    if path_fn(x, y) > 0.3 or not kit.free(x, y, 3):
        continue
    put(rng.choice(BONES), x, y, rot=rng.uniform(0, 360), s=rng.uniform(0.35, 0.6), sink=0.15)
    for _s in range(rng.randint(1, 4)):
        put("SM_Spear_low", x + rng.uniform(-3, 3), y + rng.uniform(-3, 3), z=None, rot=rng.uniform(0, 360),
            rx=rng.uniform(-35, 35), s=rng.uniform(1.5, 2.4), sink=0.6)
    kit.occupy(x, y, 2.5)
for _ in range(10):                                     # gefallene Ritter (Statuen, umgestürzt)
    x, y = rng.uniform(-50, 50), rng.uniform(-40, 40)
    if kit.free(x, y, 2) and path_fn(x, y) < 0.3:
        put("SM_Knight_posed", x, y, rot=rng.uniform(0, 360), rx=rng.choice([0, 0, 85]), sink=0.3)
for _ in range(8):
    x, y = rng.uniform(-60, 60), rng.uniform(-45, 40)
    if kit.free(x, y, 3):
        put("SM_WoodenWagon02", x, y, rot=rng.uniform(0, 360), rx=rng.uniform(-25, 25), sink=0.3)

# --- Ruine der Grenzfestung -------------------------------------------------------------------------------------------
fx, fy = FORT
for k in range(7):
    a = math.radians(-60 + k * 25 + rng.uniform(-6, 6))
    put("SM_CastleSep3", fx + math.cos(a) * 18, fy + math.sin(a) * 14, rot=math.degrees(a) + 90, s=rng.uniform(0.55, 0.75),
        sink=rng.uniform(2.5, 5.0))
put("SM_TowerSmall", fx - 16, fy + 6, s=0.6, sink=0.5)
put("SM_TowerSmall", fx + 15, fy + 4, rx=8, s=0.5, sink=3.0)
for _ in range(14):
    put(rng.choice(["SM_rock_01", "SM_rock_02", "SM_ground_rock_03", "SM_StoneDan01"]), fx + rng.uniform(-18, 18), fy + rng.uniform(-10, 8),
        rot=rng.uniform(0, 360), s=rng.uniform(0.4, 0.9), sink=0.3)

# --- tote Bäume, Felsen, dürres Gras ------------------------------------------------------------------------------------
for _ in range(120):
    x, y = rng.uniform(-HALF + 5, HALF - 5), rng.uniform(-HALF + 5, HALF - 5)
    if math.hypot(x, y) > 55 and kit.free(x, y, 5) and path_fn(x, y) < 0.3:
        put(rng.choice(["SM_Tree05", "SM_Tree06", "SM_Tree13"]), x, y, rot=rng.uniform(0, 360), s=rng.uniform(0.8, 1.3), sink=0.2)
        kit.occupy(x, y, 4)
for _ in range(60):
    x, y = rng.uniform(-HALF + 5, HALF - 5), rng.uniform(-HALF + 5, HALF - 5)
    if kit.free(x, y, 2):
        put(rng.choice(["SM_Rock01", "SM_Rock03", "SM_ground_rock_02", "SM_rock_03"]), x, y, rot=rng.uniform(0, 360), s=rng.uniform(0.3, 1.0), sink=0.4)
ALL = (-HALF + 2, -HALF + 2, HALF - 2, HALF - 2)
kit.grass(ALL, 12000, s=(0.6, 1.2))
kit.meadow(ALL, ["SM_Foliage_33", "SM_Foliage_81", "SM_WheatGrass03"], 1400, s=(0.7, 1.1))

# --- Anker ---------------------------------------------------------------------------------------------------------------
empty("Spawn", 0.0, -70.0, rot=0)
empty("Gate", 0.0, -76.0)
empty("Board", 4.0, -64.0)
empty("Keeper", fx, fy - 14, rot=180)
for i, a in enumerate([200, 235, 270, 305, 340, 20]):
    r = math.radians(a)
    empty("Slot%d" % (i + 1), math.cos(r) * 8, -10 + math.sin(r) * 6)
for i, (x, y, z) in enumerate(lamps):
    empty("Fire_%d" % (i + 1), x, y, z)
for i in range(6):
    a = i / 6 * math.tau
    empty("Violet_%d" % (i + 1), math.cos(a) * 35, math.sin(a) * 30, 2.0)
kit.finish_materials(metal_keys=("spear", "standlight", "knight"))
kit.export()
