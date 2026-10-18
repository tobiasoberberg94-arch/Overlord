# Blender: Azerlisia-Gebirge – felsiges Hochtal vor der Zwergenstadt Feo Jera: Bergriesen ringsum, Felswände,
# das befestigte Zwergentor im Norden mit Wehrtürmen, ein Minenstollen mit Loren und Erzhalden, Fichten.
#   blender -b -P build_azerlisia.py -- <WorldKit-Ordner> <ziel.glb>
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from loc_kit import Kit  # noqa: E402

exp_dir, dst = [os.path.abspath(a) for a in sys.argv[sys.argv.index("--") + 1:][:2]]
kit = Kit(exp_dir, dst, seed=12)
put, empty, rng = kit.put, kit.empty, kit.rng
HALF = 230.0
PLAY = 120.0
GATE = (0.0, 70.0)
MINE = (-48.0, 28.0)

road = kit.spline([(0, -110), (8, -70), (-6, -30), (4, 10), (0, GATE[1] - 14)])
branch = kit.spline([(4, 10), (-20, 18), (MINE[0] + 8, MINE[1])])
path_fn = kit.roads_mask([(road, 3.5), (branch, 2.6)], HALF)
kit.terrain(HALF, flat_r=45.0, hill_h=30.0, tex="Textures_T_LandScapeLayer03_BC.png", normal="Textures_T_LandScapeLayer03_N.png",
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

# --- Zwergentor von Feo Jera ---------------------------------------------------------------------------------------
gx, gy = GATE
gz = kit.ground_fn(gx, gy)
for sx in (-1, 1):
    put("SM_CastleSep4", gx + sx * 16, gy + 4, z=gz - 2.0, s=0.5)
    for k in range(3):
        put("SM_CastleSep2", gx + sx * (26 + k * 11), gy + 6 + k * 2, z=gz - 6.0, rot=sx * 8, s=0.75)
put("SM_CastleSep2", gx, gy + 8, z=gz - 4.0, s=0.9)
put("SM_TempleDoor", gx, gy + 1.2, z=gz, rot=90, s=2.8)
for sx in (-1, 1):
    put("SM_StandLight", gx + sx * 6, gy - 3, s=1.4)
    lamps.append((gx + sx * 6, gy - 3, gz + 3.4))
    put("SM_Statue01", gx + sx * 9.5, gy - 1, rot=180, s=3.2)

# --- Mine mit Loren und Erzhalden ------------------------------------------------------------------------------------
mx, my = MINE
put("MW_Mill_tunnel", mx, my, rot=90, s=0.45)
for k in range(6):
    put("SM_RailsV1", mx + 6 + k * 2.0, my, rot=90, s=1.2)
for k in range(3):
    put("SM_WoodenWagon01", mx + 9 + k * 4, my + rng.uniform(-3, 3), rot=rng.uniform(0, 360), s=1.0)
for _ in range(16):
    put(rng.choice(["SM_rock_03", "SM_ground_rock_02", "SM_ground_rock_05", "SM_StoneDan01"]), mx + rng.uniform(4, 22),
        my + rng.uniform(-9, 9), rot=rng.uniform(0, 360), s=rng.uniform(0.4, 1.1), sink=0.2)
kit.clutter(mx + 12, my + 6, ["FV_crate_group_01", "FV_barrel_group_01", "SM_WoodenBox03", "SM_FireWoodSet01"], n=(5, 8), r=(1.5, 6))
put("SM_StandLight", mx + 6, my - 4)
lamps.append((mx + 6, my - 4, kit.ground_fn(mx + 6, my - 4) + 2.6))

# --- Fichten, Felsen, Bergwiese -----------------------------------------------------------------------------------------
for _ in range(240):
    a = rng.uniform(0, math.tau)
    d = rng.uniform(30, 85)
    x, y = math.cos(a) * d, math.sin(a) * d
    if path_fn(x, y) < 0.3 and kit.free(x, y, 4):
        put("SM_Spruce1", x, y, rot=rng.uniform(0, 360), s=rng.uniform(0.6, 1.1), sink=0.3)
        kit.occupy(x, y, 3)
for _ in range(90):
    x, y = rng.uniform(-90, 90), rng.uniform(-90, 90)
    if kit.free(x, y, 2.5) and path_fn(x, y) < 0.3:
        put(rng.choice(["SM_Rock01", "SM_rock_01", "SM_ground_rock_03", "SM_rock_03"]), x, y, rot=rng.uniform(0, 360), s=rng.uniform(0.4, 1.4), sink=0.4)
ALL = (-PLAY, -PLAY, PLAY, PLAY)
kit.grass(ALL, 10000, s=(0.6, 1.1))
kit.grass(ALL, 1500, kind="@flower", s=(0.6, 1.0))

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
kit.finish_materials(metal_keys=("standlight", "rails"))
kit.export()
