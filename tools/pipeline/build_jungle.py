# Blender: 6. Ebene – Dschungel & Amphitheater (Maya-Ruinen + Bäume aus Medieval Lake Village)
#   blender -b -P build_jungle.py -- <JungleKit-Ordner> <ziel.glb>
# Blender-Y = im Spiel -Z.  Ankunft im Süden (Spawn y=-30), Arena in der Mitte (Golem bei y=+10),
# Tor im Süden (y=-23), Ränge + Säulen + Mauer ringsum, Pyramide im Norden, Dschungel rundherum.
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from loc_kit import Kit  # noqa: E402

exp_dir, dst = [os.path.abspath(a) for a in sys.argv[sys.argv.index("--") + 1:][:2]]
kit = Kit(exp_dir, dst, seed=11, tri_cap={
    "SM_pyramid_circle": 12000, "SM_mayan_tower": 20000, "SM_mayan_altar_001": 8000,
    "SM_rock_cliff_A_001": 8000, "SM_center_altar": 8000, "SM_Foliage_35": 2500,
    "SM_top_pattern_wall": 6000, "SM_ChurchTree01": 8000, "SM_Tree03": 9000, "SM_Tree02": 9000,
    "SM_Tree09": 9000, "SM_Foliage_56": 2500, "SM_Foliage_59": 2500, "SM_Foliage_22": 1500, "SM_Foliage_24": 1500,
    "SM_Foliage_12": 1200, "SM_Foliage_33": 1500, "SM_Foliage_34": 1500, "SM_Foliage_5": 1500, "SM_Foliage_27": 2000,
})
put, empty = kit.put, kit.empty
R_FLOOR, R_STAIR, R_COL, R_WALL = 12.6, 17.0, 21.6, 23.6
GATE_A = -90.0                       # Süden (Richtung Spawn)


def path_fn(x, y):
    if abs(x + math.sin(y * 0.2) * 0.6) < 2.6 and -60 < y < -20:
        return 1.0
    if math.hypot(x, y) < R_FLOOR + 2.5:
        return 1.0                   # Sandring um den Arenaboden
    return 0.0


kit.terrain(95.0, flat_r=34.0, hill_h=11.0, tex="Textures_T_LandScapeLayer01_BC.png",
            normal="Textures_T_LandScapeLayer01_N.png", tile=5.0, edge_rise=16.0, res=300,
            path_tex="Textures_T_LandScapeLayer05_BC.png", path_normal="Textures_T_LandScapeLayer04_N.png",
            path_fn=path_fn)


def gap(a_deg, half=14.0):
    d = (a_deg - GATE_A + 180) % 360 - 180
    return abs(d) < half


# --- Arena ------------------------------------------------------------------------------
put("SM_pyramid_circle", 0, 0, z=-0.15, s=2.5, sz=0.45)
put("SM_brick_circle", 0, 0, z=0.02, s=3.2, sz=1.0)            # Steinring um die Arena

# Ränge: Stufenblöcke im Kreis (aufsteigend nach außen)
N = 16
for i in range(N):
    a = i * 360.0 / N
    if gap(a, 16):
        continue
    r = math.radians(a)
    put("SM_stair_brick" if i % 3 else "SM_stiar_crack", math.cos(r) * R_STAIR, math.sin(r) * R_STAIR,
        z=0.0, rot=a + 90.0, s=1.0)
# Säulenring
for i in range(28):
    a = i * 360.0 / 28
    if gap(a, 12):
        continue
    r = math.radians(a)
    put("SM_colum_module_001" if i % 2 else "SM_column_ruin_module_body", math.cos(r) * R_COL,
        math.sin(r) * R_COL, rot=a, s=1.0 if i % 2 else 0.85)
# Außenmauer
for i in range(12):
    a = i * 30.0 + 15.0
    if gap(a, 20):
        continue
    r = math.radians(a)
    put("SM_top_pattern_wall", math.cos(r) * R_WALL, math.sin(r) * R_WALL, rot=a + 90.0, s=1.05)
# Tor im Süden: Drachensäulen und Tortürme
gr = math.radians(GATE_A)
gx, gy = math.cos(gr) * R_WALL, math.sin(gr) * R_WALL
for sx in (-1, 1):
    put("SM_dragon_pillar", gx + sx * 6.0, gy, rot=0 if sx < 0 else 180, s=0.9)
    put("SM_stone_door_module_2", gx + sx * 9.8, gy + 0.5, rot=0, s=0.75)
    put("SM_prop_pillar_a001", sx * 3.2, -30.0, s=0.8)          # Säulen am Weg vor dem Tor
    put("SM_prop_pillar_a001", sx * 3.2, -38.0, s=0.8)
# Ehrenloge im Norden (Auras Platz) mit Altar
put("SM_mayan_altar_001", 0, R_FLOOR + 1.0, z=0.0, rot=180, s=1.1)
put("SM_ruin_face_module_001", 0, R_WALL + 2.0, rot=0, s=1.0)

# --- Kulisse --------------------------------------------------------------------------------
put("SM_pyramid_D_001", 0, 78.0, s=1.15, sink=1.0)
put("SM_mayan_tower", 52.0, 46.0, s=0.8, sink=2.0)
put("SM_mayan_tower", -58.0, 52.0, s=0.7, sink=2.0)
put("SM_center_altar", -40.0, -18.0, rot=30, s=0.8)
put("SM_old_stone_wall", 38.0, -30.0, rot=-40, s=0.9, sink=0.5)
put("SM_ruin_face_module_001", -36.0, 20.0, rot=70, s=0.9, sink=0.5)
for (x, y, r, s, n) in [(46, -6, 20, 1.4, "SM_cave_cliff_003"), (-50, -36, 120, 1.6, "SM_cave_cliff_001"),
                        (30, 58, 0, 1.3, "SM_rock_cliff_A_001"), (-30, 64, 200, 1.5, "SM_cave_cliff_003"),
                        (62, -48, 60, 1.8, "SM_cave_cliff_001"), (-70, 6, 90, 1.7, "SM_rock_cliff_A_001")]:
    put(n, x, y, rot=r, s=s, sink=1.5)
for (x, y) in [(10, -46), (-12, -52), (24, -20), (-26, -6), (20, 30), (-22, 34)]:
    put("SM_prop_stone_006", x, y, rot=kit.rng.uniform(0, 360), s=kit.rng.uniform(0.6, 1.0), sink=0.4)

# --- Dschungel ------------------------------------------------------------------------------
arena = [(-27, -27, 27, 27)]
road = [(-4, -62, 4, -20)]
backdrop = [(-34, 50, 34, 110)]
avoid = arena + road + backdrop
trees = ["SM_Tree02", "SM_Tree09", "SM_Tree13", "SM_Tree03", "SM_Tree02"]
n = 0
for _ in range(400):
    if n >= 120:
        break
    a = kit.rng.uniform(0, math.tau)
    r = kit.rng.uniform(30, 88)
    x, y = math.cos(a) * r, math.sin(a) * r
    if any(b[0] <= x <= b[2] and b[1] <= y <= b[3] for b in avoid):
        continue
    put(kit.rng.choice(trees), x, y, rot=kit.rng.uniform(0, 360), s=kit.rng.uniform(1.2, 1.7))
    n += 1
for (x, y) in [(-8, -44), (9, -40), (-14, -28), (15, -30)]:
    put("SM_ChurchTree01", x, y, rot=kit.rng.uniform(0, 360), s=1.3)
# Dichter Dschungel: Baumgruppen mit Unterholz, Farne und Blattpflanzen, Gras zwischen den Rängen
JUNGLE = ["SM_Tree4", "SM_Tree10", "SM_Tree02", "SM_Tree09", "SM_Tree13", "SM_Tree03", "SM_Tree10"]
UNDER = ["SM_Foliage_56", "SM_Foliage_59", "SM_Foliage_22", "SM_Foliage_24", "SM_Foliage_27", "SM_Foliage_12",
         "SM_Bush07", "SM_Foliage_35", "SM_Bush03"]
kit.forest((-90, -90, 90, 90), JUNGLE, 260, avoid=avoid, min_d=4.0, s=(1.1, 1.6), under=UNDER, under_n=4,
           threshold=-0.35, density_scale=0.05)
kit.meadow((-90, -90, 90, 90), ["SM_Foliage_1", "SM_Foliage_2", "SM_Foliage_3", "SM_Foliage_4", "SM_Foliage_6",
                                "SM_Foliage_5", "SM_Bush06"], 4200, avoid=arena + road, s=(1.0, 1.8),
           patch=(["SM_Foliage_33", "SM_Foliage_34", "SM_Foliage_12", "SM_Foliage_27"], 60, 3.0))
kit.meadow((-90, -90, 90, 90), UNDER, 900, avoid=arena + road, s=(0.9, 1.5))
kit.meadow((-26, -26, 26, 26), ["SM_Foliage_5", "SM_Foliage_6", "SM_Foliage_3"], 260, avoid=[(-16, -16, 16, 16)],
           s=(0.8, 1.2))   # Gras zwischen den Rängen
for _ in range(40):                                         # Moosfelsen im Unterholz
    a = kit.rng.uniform(0, math.tau)
    r = kit.rng.uniform(30, 88)
    x, y = math.cos(a) * r, math.sin(a) * r
    if not any(b[0] <= x <= b[2] and b[1] <= y <= b[3] for b in avoid):
        put(kit.rng.choice(["SM_Rock01", "SM_Rock03", "SM_MossyGround01"]), x, y, rot=kit.rng.uniform(0, 360),
            s=kit.rng.uniform(0.6, 1.3), sink=0.3)

# --- Anker --------------------------------------------------------------------------------------
empty("Spawn", 0, -32.0, rot=0)
empty("Gate", 0, -40.0)
empty("Keeper", -2.0, 4.0)
for i, a in enumerate([120, 145, 170, 190, 215, 240]):
    r = math.radians(a + 90)
    empty("Slot%d" % (i + 1), math.cos(r) * 6.0, 6.0 + math.sin(r) * 6.0)
n = 1
for i in range(8):
    a = math.radians(i * 45 + 22.5)
    empty("Fire_%d" % n, math.cos(a) * (R_FLOOR + 1.5), math.sin(a) * (R_FLOOR + 1.5), 1.2)
    n += 1

kit.finish_materials(metal_keys=("altar", "dragon"))
kit.export()
