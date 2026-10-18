# Blender: Slane-Theokratie – heilige Hauptstadt: gepflasterter Domplatz mit Säulenalleen und Statuen der
# Sechs Götter, die große Kathedrale im Norden, Glockentürme, Bürgerhäuser ringsum, Treppe zum Dom.
#   blender -b -P build_theokratie.py -- <WorldKit-Ordner> <ziel.glb>
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from loc_kit import Kit  # noqa: E402

exp_dir, dst = [os.path.abspath(a) for a in sys.argv[sys.argv.index("--") + 1:][:2]]
kit = Kit(exp_dir, dst, seed=6)
put, empty, rng = kit.put, kit.empty, kit.rng
HALF = 110.0
PLAZA = (0.0, 10.0)
DOME = (0.0, 58.0)

avenue = kit.spline([(0, -105), (0, -40), (0, PLAZA[1] - 22)])
cross = kit.spline([(-60, PLAZA[1]), (60, PLAZA[1])])
square = kit.spline([(PLAZA[0] + math.cos(a) * 18, PLAZA[1] + math.sin(a) * 18) for a in [k / 32 * math.tau for k in range(33)]])
path_fn = kit.roads_mask([(avenue, 5.0), (cross, 4.0), (square, 18.0), (kit.spline([(0, PLAZA[1] + 18), (0, DOME[1] - 14)]), 6.0)], HALF)
kit.terrain(HALF, flat_r=80.0, hill_h=6.0, tex="Textures_T_LandScapeLayer01_BC.png", normal="Textures_T_LandScapeLayer01_N.png",
            tile=5.0, edge_rise=14.0, res=320, inner_h=0.0, path_tex="Texture_T_Cobblestone_BC.png", path_normal="Texture_T_Cobblestone_N.png",
            path_fn=path_fn)
kit.occupy(PLAZA[0], PLAZA[1], 22)
kit.occupy(DOME[0], DOME[1], 30)
kit.occupy(0, -78, 8)
lamps = []

# --- Domplatz: Brunnenring, Statuen der Sechs Götter, Säulen -----------------------------------------------------
px, py = PLAZA
put("SM_RoundOrn", px, py, s=1.2)
for k in range(6):
    a = math.radians(k * 60 + 30)
    put("SM_Statue01", px + math.cos(a) * 11, py + math.sin(a) * 11, rot=math.degrees(a) + 90, s=1.9)
    put("SM_StandLight", px + math.cos(a) * 14, py + math.sin(a) * 14, s=1.3)
    lamps.append((px + math.cos(a) * 14, py + math.sin(a) * 14, 3.2))
for y in range(-50, int(py) - 22, 7):
    for sx in (-1, 1):
        put("SM_Collum", sx * 7.0, y, z=kit.ground_fn(sx * 7.0, y), s=1.1)
        if (y // 7) % 2 == 0:
            put("SM_StandLight", sx * 7.0, y + 3.5, s=1.2)
            lamps.append((sx * 7.0, y + 3.5, 3.0))

# --- Kathedrale und Glockentürme ------------------------------------------------------------------------------------
dx, dy = DOME
put("SM_Build2", dx, dy, rot=180, s=0.7)
for sx in (-1, 1):
    put("SM_Build5", dx + sx * 24, dy - 4, rot=180, s=0.55)
    put("SM_ChurchSet", dx + sx * 38, dy - 10, rot=180 + sx * 20, s=0.9)

# --- Bürgerhäuser an den Straßen ---------------------------------------------------------------------------------------
HOUSES = ["SM_Build1", "SM_Build3", "SM_Build4", "SM_House", "SM_House3", "SM_Build3"]
for side in (-1, 1):
    for k in range(5):                                        # Prachtstraße
        y = -95 + k * 15
        put(rng.choice(HOUSES[:3]), side * 22, y, rot=90 * side, s=rng.uniform(0.45, 0.6))
    for k in range(4):                                        # Querstraße
        x = side * (32 + k * 16)
        put(rng.choice(HOUSES), x, py - 12, rot=0, s=rng.uniform(0.45, 0.65))
        put(rng.choice(HOUSES), x, py + 14, rot=180, s=rng.uniform(0.45, 0.65))
for side in (-1, 1):                                          # zweite Häuserreihe
    for k in range(5):
        y = -92 + k * 15
        put(rng.choice(HOUSES), side * 40, y, rot=90 * side, s=rng.uniform(0.45, 0.6))
# Stadtmauer rings um die heilige Stadt (Tor im Süden)
for k in range(44):
    a = k / 44 * math.tau
    x, y = math.cos(a) * 92, math.sin(a) * 92
    if abs(x) < 9 and y < 0:
        continue
    put("SM_CastleWallV1UvStack", x, y, rot=math.degrees(a) + 90, s=1.25, sink=0.3)
for sx in (-1, 1):
    put("SM_TowerSmall", sx * 11, -92, s=0.45)
for _ in range(16):
    x, y = rng.uniform(-80, 80), rng.uniform(-80, 80)
    if kit.free(x, y, 14) and path_fn(x, y) < 0.2 and abs(x) > 30:
        put(rng.choice(HOUSES), x, y, rot=rng.choice([0, 90, 180, 270]), s=rng.uniform(0.45, 0.65))
        kit.occupy(x, y, 12)
for _ in range(30):
    x, y = rng.uniform(-60, 60), rng.uniform(-90, 40)
    if path_fn(x, y) > 0.5 and kit.free(x, y, 1.5):
        kit.clutter(x, y, ["FV_barrel_01", "FV_crate_01", "SM_FlowerPot01", "SM_WoodenBucket01", "FV_bag"], n=(1, 3), r=(0.5, 1.5))
for _ in range(50):
    x, y = rng.uniform(-HALF + 5, HALF - 5), rng.uniform(-HALF + 5, HALF - 5)
    if path_fn(x, y) < 0.2 and kit.free(x, y, 4):
        put(rng.choice(["SM_ChurchTree01", "SM_Tree02", "SM_Spruce1"]), x, y, rot=rng.uniform(0, 360), s=rng.uniform(1.0, 1.5))
        kit.occupy(x, y, 3)
ALL = (-HALF + 2, -HALF + 2, HALF - 2, HALF - 2)
kit.grass(ALL, 14000, s=(0.8, 1.3))
kit.grass(ALL, 3000, kind="@flower", s=(0.8, 1.1))

# --- Anker -------------------------------------------------------------------------------------------------------------
empty("Spawn", 0.0, -78.0, rot=0)
empty("Gate", 0.0, -84.0)
empty("Board", 5.0, -72.0)
empty("Keeper", dx, dy - 24, rot=180)
for i, a in enumerate([200, 235, 270, 305, 340, 20]):
    r = math.radians(a)
    empty("Slot%d" % (i + 1), px + math.cos(r) * 7, py - 6 + math.sin(r) * 5)
for i, (x, y, z) in enumerate(lamps):
    empty("Lamp_%d" % (i + 1), x, y, z)
n = 1
for k in range(0, len(avenue), 12):
    empty("Walk_%d" % n, avenue[k][0] + 2.5, avenue[k][1])
    n += 1
kit.finish_materials(metal_keys=("standlight",))
kit.export()
