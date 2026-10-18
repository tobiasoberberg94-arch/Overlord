# Blender: Argland & die Drachenlande – Hochplateau im Felsenkessel, gewaltige Drachenknochen, die verfallene
# Drachenburg des Platin-Drachenkönigs Tsaindorcus Vaision im Norden, kaum Bäume, kalter Wind.
#   blender -b -P build_drachen.py -- <WorldKit-Ordner> <ziel.glb>
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from loc_kit import Kit  # noqa: E402

exp_dir, dst = [os.path.abspath(a) for a in sys.argv[sys.argv.index("--") + 1:][:2]]
kit = Kit(exp_dir, dst, seed=144)
put, empty, rng = kit.put, kit.empty, kit.rng
HALF = 230.0
PLAY = 120.0
GATE = (0.0, 70.0)
MINE = (-48.0, 28.0)

road = kit.spline([(0, -110), (8, -70), (-6, -30), (4, 10), (0, GATE[1] - 14)])
branch = kit.spline([(4, 10), (-20, 18), (MINE[0] + 8, MINE[1])])
path_fn = kit.roads_mask([(road, 3.5), (branch, 2.6)], HALF)
kit.terrain(HALF, flat_r=45.0, hill_h=30.0, tex="Texture_T_Smooth_Layered_Rock_BC.png", normal="Texture_T_Smooth_Layered_Rock_N.png",
            tile=6.0, edge_rise=34.0, res=360, inner_h=1.4, path_tex="Texture_T_GroundPace4_BC.png", path_normal="Texture_T_GroundPace4_N.png",
            path_fn=path_fn)
kit.occupy(GATE[0], GATE[1], 26)
kit.occupy(MINE[0], MINE[1], 14)
kit.occupy(0, -70, 8)
lamps = []

# --- Bergriesen als Kulisse ---------------------------------------------------------------------------------------
for k in range(26):
    a = k / 26 * math.tau + rng.uniform(-0.05, 0.05)
    d = rng.uniform(150, 210)
    put(rng.choice(["SM_rock_02", "SM_rock_01"]), math.cos(a) * d, math.sin(a) * d, z=-12.0, rot=rng.uniform(0, 360),
        s=rng.uniform(9.0, 15.0), sz=rng.uniform(10.0, 18.0), nocol=True)
# Felswände am Talrand
for k in range(60):
    a = k / 60 * math.tau + rng.uniform(-0.03, 0.03)
    d = rng.uniform(78, 104)
    x, y = math.cos(a) * d, math.sin(a) * d
    if abs(x) < 10 and y < 0:
        continue
    put(rng.choice(["SM_rock_02", "SM_rock_01", "SM_Rock01"]), x, y, rot=rng.uniform(0, 360), s=rng.uniform(2.2, 3.6), sink=2.0)

# --- Drachenburg (Ruine) -------------------------------------------------------------------------------------------
gx, gy = GATE
gz = kit.ground_fn(gx, gy)
for k in range(8):
    a = math.radians(-70 + k * 20)
    put(rng.choice(["SM_CastleSep2", "SM_CastleSep5", "SM_CastleSep3"]), gx + math.cos(a) * 22, gy + 6 + math.sin(a) * 12,
        z=gz - rng.uniform(4, 9), rot=math.degrees(a) + 90, s=rng.uniform(0.6, 0.9))
put("SM_CastleSep4", gx, gy + 14, z=gz - 6.0, s=0.7)
for sx in (-1, 1):
    put("SM_StandLight", gx + sx * 6, gy - 6, s=1.4)
    lamps.append((gx + sx * 6, gy - 6, gz + 3.4))
# --- Drachenknochen ------------------------------------------------------------------------------------------------
BONES = ["SM_Skeleton_01", "SM_Skeleton_02", "SM_Skeleton_04", "SM_Skeleton_06", "SM_Skeleton_08"]
mx, my = MINE
for k in range(5):
    put(rng.choice(BONES), mx + rng.uniform(-12, 12), my + rng.uniform(-10, 10), rot=rng.uniform(0, 360), s=rng.uniform(2.6, 3.6), sink=1.0)
for _ in range(18):
    x, y = rng.uniform(-70, 70), rng.uniform(-60, 50)
    if kit.free(x, y, 6) and path_fn(x, y) < 0.3:
        put(rng.choice(BONES), x, y, rot=rng.uniform(0, 360), s=rng.uniform(1.4, 2.6), sink=0.6)
        kit.occupy(x, y, 5)

# --- Fichten, Felsen, Bergwiese -----------------------------------------------------------------------------------------
for _ in range(60):
    a = rng.uniform(0, math.tau)
    d = rng.uniform(40, 85)
    x, y = math.cos(a) * d, math.sin(a) * d
    if path_fn(x, y) < 0.3 and kit.free(x, y, 4):
        put("SM_Spruce1", x, y, rot=rng.uniform(0, 360), s=rng.uniform(0.6, 1.1), sink=0.3)
        kit.occupy(x, y, 3)
for _ in range(90):
    x, y = rng.uniform(-90, 90), rng.uniform(-90, 90)
    if kit.free(x, y, 2.5) and path_fn(x, y) < 0.3:
        put(rng.choice(["SM_Rock01", "SM_rock_01", "SM_ground_rock_03", "SM_rock_03"]), x, y, rot=rng.uniform(0, 360), s=rng.uniform(0.4, 1.4), sink=0.4)
ALL = (-PLAY, -PLAY, PLAY, PLAY)
kit.grass(ALL, 5000, s=(0.5, 0.9))

# --- Anker ---------------------------------------------------------------------------------------------------------------
empty("Spawn", 0.0, -70.0, rot=0)
empty("Gate", 0.0, -76.0)
empty("Board", 5.0, -64.0)
empty("Keeper", gx, gy - 8, rot=180)
for i, a in enumerate([200, 235, 270, 305, 340, 20]):
    r = math.radians(a)
    empty("Slot%d" % (i + 1), math.cos(r) * 8, 10 + math.sin(r) * 6)
for i, (x, y, z) in enumerate(lamps):
    empty("Fire_%d" % (i + 1), x, y, z)
kit.finish_materials(metal_keys=("standlight",))
kit.export()
