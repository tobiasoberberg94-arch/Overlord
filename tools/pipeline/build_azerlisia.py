# Blender: Azerlisia-Gebirge – Hochtal vor der Zwergenstadt Feo Jera (struct_kit, town_kit).
# Bergriesen ringsum, am Talende eine senkrechte Felswand; darin das monumentale Felsentor der Zwerge (gestuftes
# Portal, Säulen, Goldbänder, Treppe, Wächterstatuen, Feuerschalen), Wehrmauern links und rechts, daneben das
# Mundloch eines Erzstollens mit Schienen, Loren und Halden; ein Händlerlager an der Passstraße; Fichten, Felsen.
#   blender -b -P build_azerlisia.py -- <WorldKit-Ordner> <ziel.glb>
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from loc_kit import Kit  # noqa: E402
from town_kit import Town, ROAD, PLAZA, FREE, YARD, HOUSE, RESERVED  # noqa: E402
from struct_kit import Structs  # noqa: E402
from mathutils import noise, Vector  # noqa: E402

exp_dir, dst = [os.path.abspath(a) for a in sys.argv[sys.argv.index("--") + 1:][:2]]
kit = Kit(exp_dir, dst, seed=12)
put, empty, rng = kit.put, kit.empty, kit.rng
HALF = 230.0
PLAY = 120.0
town = Town(kit, 150.0)
sk = Structs(kit, town)


def cliff_y(x):
    return 74.0 + 5.0 * math.sin(x * 0.045) + 0.004 * x * x


def smooth(a, b, v):
    t = max(0.0, min(1.0, (v - a) / (b - a)))
    return t * t * (3 - 2 * t)


def shape(x, y, h):
    c = cliff_y(x)
    rough = 1.6 * noise.noise(Vector((x * 0.12, y * 0.12, 5.5)))
    return h + 30.0 * smooth(c - 1.0, c + 5.0 + rough, y)


TERRAIN = dict(half=HALF, flat_r=45.0, hill_h=30.0, edge_rise=34.0, inner_h=1.4, height_fn=shape)
kit.height_field(**TERRAIN)
GATE = (0.0, cliff_y(0.0) - 1.0)
MINE = (-42.0, cliff_y(-42.0) - 1.0)
CAMP = (24.0, 22.0)

# --- Wege --------------------------------------------------------------------------------------------------------
road = kit.spline([(0, -115), (8, -70), (-6, -30), (4, 10), (0, GATE[1] - 22)])
branch = kit.spline([(4, 10), (-18, 30), (MINE[0] + 4, MINE[1] - 10), (MINE[0], MINE[1] - 2)])
town.road(road, 4.5, paved=False)
town.road(branch, 3.2, paved=False)
town.plaza(GATE[0], GATE[1] - 16, 12.0, paved=True, ragged=0.8)
town.plaza(CAMP[0], CAMP[1], 10.0, paved=False, ragged=1.4)

# --- Felsentor von Feo Jera ----------------------------------------------------------------------------------------------
gate = sk.dwarf_gate(GATE[0], GATE[1], 0.0, W=28.0, H=26.0, depth=12.0)
gx, gy = GATE
pz = gate["platform"][2]
for s in (-1, 1):
    # Wächterstatuen auf Sockeln vor der Treppe
    M_x, M_y = s * 12.5, gy - 13.0
    sk.box(sk.frame(M_x, M_y, kit.ground_fn(M_x, M_y), 0.0), 3.4, 3.4, 3.0, "MI_DwarfStone", z0=-0.5)
    put("SM_Statue01", M_x, M_y, z=kit.ground_fn(M_x, M_y) + 2.5, rot=0, s=4.2)
    # Feuerschalen auf dem Podest
    put("SM_brizer", s * 6.5, gy - 3.0, z=pz, s=1.2)
# Wehrmauern links und rechts der Fassade, am Fuß der Felswand (Zinnen zum Tal)
for s in (-1, 1):
    xs = [s * (14.5 + k * 3.0) for k in range(8)]
    line = [(x, cliff_y(x) - 3.0) for x in xs]
    town.great_wall(kit.spline(line, step=3.0), height=10.0, T=4.0, gaps=[], stairs_every=999.0, outer_side=-s,
                    name="SM_Bastion")
    put("SM_TowerrType2", xs[-1], cliff_y(xs[-1]) - 3.0, s=0.3, rot=0)

# --- Erzstollen ------------------------------------------------------------------------------------------------------------
mine = sk.mine_adit(MINE[0], MINE[1], 0.0, w=3.6, h=3.3, depth=10.0)
mx, my = MINE
for k in range(9):                                       # Schienen aus dem Stollen
    put("SM_RailsV1", mx, my - 1.0 - k * 2.0, rot=90, s=1.2)
for k in range(3):
    put("SM_WoodenWagon01", mx + rng.uniform(-1.5, 1.5) + (3.5 if k else 0.0), my - 8 - k * 5.0, rot=rng.uniform(80, 100), s=0.9)
for _ in range(18):                                      # Abraumhalden und Erz
    a, d = rng.uniform(math.pi * 1.05, math.pi * 1.95), rng.uniform(5, 14)
    kit.ph(rng.choice(["rock_moss_set_02", "namaqualand_boulder_05", "stone_01", "boulder_01"]), mx + math.cos(a) * d,
           my + math.sin(a) * d * 0.6 - 4, rot=rng.uniform(0, 360), s=rng.uniform(0.5, 1.3))
for _ in range(6):
    kit.ph(rng.choice(["wooden_crate_01", "wooden_barrels_01", "wooden_bucket_01", "rusted_spade_01", "wooden_ladder"]),
           mx + rng.uniform(4, 9), my - rng.uniform(2, 9), rot=rng.uniform(0, 360))
put("SM_StandLight", mx + 3.0, my - 1.5)

# --- Händlerlager an der Passstraße -----------------------------------------------------------------------------------------
cx, cy = CAMP
for k in range(5):
    a = math.radians(k * 72 + 20)
    put("SM_Tent_low", cx + math.cos(a) * 7.0, cy + math.sin(a) * 6.0, rot=math.degrees(a) + 90, s=2.3)
for k in range(3):
    put(rng.choice(["SM_WoodenWagon01", "SM_WoodenWagon02"]), cx - 12 + k * 4.5, cy + 9, rot=rng.uniform(-20, 20), s=1.1)
kit.ph("stone_fire_pit", cx, cy)
for _ in range(10):
    a, d = rng.uniform(0, math.tau), rng.uniform(2.5, 9)
    kit.ph(rng.choice(["wooden_crate_01", "wooden_crate_02", "wine_barrel_01", "wicker_basket_01", "wooden_barrels_01"]),
           cx + math.cos(a) * d, cy + math.sin(a) * d, rot=rng.uniform(0, 360))

# --- Bergriesen als Kulisse, Felswände ------------------------------------------------------------------------------------------
for k in range(26):
    a = k / 26 * math.tau + rng.uniform(-0.05, 0.05)
    d = rng.uniform(150, 210)
    put(rng.choice(["SM_rock_02", "SM_rock_01"]), math.cos(a) * d, math.sin(a) * d, z=-12.0, rot=rng.uniform(0, 360),
        s=rng.uniform(7.0, 10.0), sz=rng.uniform(8.0, 11.0), nocol=True)
for k in range(60):
    a = k / 60 * math.tau + rng.uniform(-0.03, 0.03)
    d = rng.uniform(78, 104)
    x, y = math.cos(a) * d, math.sin(a) * d
    if (abs(x) < 26 and y < 0) or y > 50:
        continue
    put(rng.choice(["SM_rock_02", "SM_rock_01", "SM_Rock01"]), x, y, rot=rng.uniform(0, 360), s=rng.uniform(2.2, 3.6), sink=2.0)
# Felswand: große Fotoscan-Felsen (Gesicht zum Tal) brechen die glatte Wand auf, Blöcke am Fuß
x = -128.0
while x < 128.0:
    if abs(x) > 42 and abs(x - mx) > 9:
        y = cliff_y(x) + rng.uniform(0.5, 2.5)
        big = rng.random() < 0.6
        kit.ph("mountainside" if big else rng.choice(["rock_face_01", "rock_face_02"]), x, y,
               z=kit.ground_fn(x, cliff_y(x) - 3.0) - rng.uniform(1.5, 3.0), rot=rng.uniform(-18, 18),
               s=rng.uniform(2.4, 3.2) if big else rng.uniform(4.0, 5.5))
    x += rng.uniform(16.0, 24.0)
for _ in range(50):                                       # Felsblöcke und Geröll am Fuß der Wand
    x = rng.uniform(-110, 110)
    if abs(x) < 40 or abs(x - mx) < 10:
        continue
    y = cliff_y(x) - rng.uniform(2, 7)
    kit.ph(rng.choice(["boulder_01", "namaqualand_boulder_02", "rock_moss_set_02", "namaqualand_boulder_05"]), x, y,
           rot=rng.uniform(0, 360), s=rng.uniform(0.8, 2.0))

# --- Fichten, Felsen, Bergwiese --------------------------------------------------------------------------------------------------
for _ in range(260):
    a = rng.uniform(0, math.tau)
    d = rng.uniform(30, 85)
    x, y = math.cos(a) * d, math.sin(a) * d
    if town.at(x, y) == FREE and kit.free(x, y, 4) and y < cliff_y(x) - 6:
        put("SM_Spruce1", x, y, rot=rng.uniform(0, 360), s=rng.uniform(0.6, 1.1), sink=0.3)
        kit.occupy(x, y, 3)
for _ in range(90):
    x, y = rng.uniform(-90, 90), rng.uniform(-90, 60)
    if kit.free(x, y, 2.5) and town.at(x, y) == FREE:
        put(rng.choice(["SM_Rock01", "SM_rock_01", "SM_ground_rock_03", "SM_rock_03"]), x, y, rot=rng.uniform(0, 360),
            s=rng.uniform(0.4, 1.4), sink=0.4)

sk.flush("SM_FeoJera")
kit.terrain(HALF, flat_r=TERRAIN["flat_r"], hill_h=TERRAIN["hill_h"], tex="Textures_T_LandScapeLayer03_BC.png",
            normal="Textures_T_LandScapeLayer03_N.png", tile=6.0, edge_rise=TERRAIN["edge_rise"], res=420,
            inner_h=TERRAIN["inner_h"], path_tex="Texture_T_GroundPace4_BC.png", path_normal="Texture_T_GroundPace4_N.png",
            path_fn=town.path_fn, dirt_fn=town.dirt_fn, height_fn=shape)
ALL = (-PLAY, -PLAY, PLAY, PLAY)
kit.grass(ALL, 10000, s=(0.6, 1.1))
kit.grass(ALL, 1500, kind="@flower", s=(0.6, 1.0))

# --- Anker -------------------------------------------------------------------------------------------------------------------------
empty("Spawn", 0.0, -70.0, rot=0)
empty("Gate", 0.0, -76.0)
empty("Board", 5.0, -64.0)
empty("Keeper", gx, gy - 9, z=pz, rot=180)
for i, a in enumerate([200, 235, 270, 305, 340, 20]):
    r = math.radians(a)
    empty("Slot%d" % (i + 1), math.cos(r) * 8, 10 + math.sin(r) * 6)
fires = [(s * 6.5, gy - 3.0, pz + 2.2) for s in (-1, 1)] + [(mx + 3.0, my - 1.5, kit.ground_fn(mx, my) + 2.6), (cx, cy, kit.ground_fn(cx, cy) + 0.8)]
for i, (x, y, z) in enumerate(fires):
    empty("Fire_%d" % (i + 1), x, y, z)
town.save_map(os.path.splitext(dst)[0] + "_map.png")
kit.finish_materials(metal_keys=("standlight", "rails"))
kit.export()
