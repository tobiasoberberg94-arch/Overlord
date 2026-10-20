# Blender: 6. Ebene – Dschungel & Amphitheater (Maya-Ruinen + Bäume aus Medieval Lake Village)
#   blender -b -P build_jungle.py -- <JungleKit-Ordner> <ziel.glb>
# Blender-Y = im Spiel -Z.  Ankunft im Süden vor dem Haupttor, in der Mitte das große Amphitheater (Kolosseum,
# town_kit.colosseum: Arkaden in drei Geschossen, begehbare Ränge, Sandarena), Pyramide im Norden, Dschungel rundherum.
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from loc_kit import Kit  # noqa: E402
from town_kit import Town  # noqa: E402

exp_dir, dst = [os.path.abspath(a) for a in sys.argv[sys.argv.index("--") + 1:][:2]]
kit = Kit(exp_dir, dst, seed=11)   # volle Originalqualität, Godot erzeugt LOD-Stufen
kit.lod_names = {"SM_Tree02", "SM_Tree03", "SM_Tree4", "SM_Tree05", "SM_Tree06", "SM_Tree07", "SM_Tree08", "SM_Tree09",
                 "SM_Tree10", "SM_Tree13", "SM_ChurchTree01", "SM_Spruce1", "SM_TreeType1", "SM_type2Tree",
                 "MW_tree_02", "MW_tree_03", "MW_pine_tree_Var_01", "FV_tree_01", "FV_tree_02"}   # Bäume: Instancing + Detailstufen
put, empty = kit.put, kit.empty
HALF = 95.0
R_ARENA, R_OUT = 18.0, 36.0
town = Town(kit, HALF)
TERRAIN = dict(half=HALF, flat_r=46.0, hill_h=11.0, edge_rise=16.0, inner_h=0.0)
kit.height_field(**TERRAIN)
approach = kit.spline([(0, -92), (2, -70), (-1, -52), (0, -R_OUT - 2)])
town.road(approach, 5.0, paved=False)

# --- Amphitheater ---------------------------------------------------------------------------------
town.colosseum(0.0, 0.0, R=R_OUT, r_arena=R_ARENA, tiers=3, tier_h=5.6, segs=64, gates=(270.0, 90.0))
for sx in (-1, 1):                                          # Drachensäulen und Wächtersäulen am Weg vor dem Tor
    put("SM_dragon_pillar", sx * 6.5, -R_OUT - 5.0, rot=0 if sx < 0 else 180, s=0.85)
    put("SM_prop_pillar_a001", sx * 4.0, -R_OUT - 14.0, s=0.8)
    put("SM_prop_pillar_a001", sx * 4.0, -R_OUT - 24.0, s=0.8)

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
arena = [(-R_OUT - 4, -R_OUT - 4, R_OUT + 4, R_OUT + 4)]
road = [(-6, -92, 6, -R_OUT)]
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
kit.grass((-90, -90, 90, 90), 24000, avoid=arena + road, s=(1.0, 1.8))
kit.grass((-90, -90, 90, 90), 3000, kind="@flower", avoid=arena + road)
kit.meadow((-90, -90, 90, 90), ["SM_Bush06", "SM_Foliage_12", "SM_Foliage_27"], 600, avoid=arena + road, s=(1.0, 1.6),
           patch=(["SM_Foliage_33", "SM_Foliage_34", "SM_Foliage_12", "SM_Foliage_27"], 60, 3.0))
kit.meadow((-90, -90, 90, 90), UNDER, 900, avoid=arena + road, s=(0.9, 1.5))
for _ in range(40):                                         # Moosfelsen im Unterholz
    a = kit.rng.uniform(0, math.tau)
    r = kit.rng.uniform(30, 88)
    x, y = math.cos(a) * r, math.sin(a) * r
    if not any(b[0] <= x <= b[2] and b[1] <= y <= b[3] for b in avoid):
        put(kit.rng.choice(["SM_Rock01", "SM_Rock03", "SM_MossyGround01"]), x, y, rot=kit.rng.uniform(0, 360),
            s=kit.rng.uniform(0.6, 1.3), sink=0.3)

# --- Gelände ------------------------------------------------------------------------------------
kit.terrain(HALF, flat_r=TERRAIN["flat_r"], hill_h=TERRAIN["hill_h"], tex="Textures_T_LandScapeLayer01_BC.png",
            normal="Textures_T_LandScapeLayer01_N.png", tile=5.0, edge_rise=TERRAIN["edge_rise"], res=320,
            path_tex="Textures_T_LandScapeLayer05_BC.png", path_normal="Textures_T_LandScapeLayer04_N.png",
            path_fn=town.path_fn, dirt_fn=town.dirt_fn)

# --- Anker --------------------------------------------------------------------------------------
empty("Spawn", 0, -R_OUT - 12.0, rot=0)
empty("Gate", 0, -R_OUT - 20.0)
empty("Keeper", -2.0, 4.0)
for i, a in enumerate([120, 145, 170, 190, 215, 240]):
    r = math.radians(a + 90)
    empty("Slot%d" % (i + 1), math.cos(r) * 6.0, 6.0 + math.sin(r) * 6.0)
n = 1
for i in range(8):
    a = math.radians(i * 45 + 22.5)
    empty("Fire_%d" % n, math.cos(a) * (R_ARENA - 1.2), math.sin(a) * (R_ARENA - 1.2), 1.4)
    n += 1

kit.finish_materials(metal_keys=("altar", "dragon"))
kit.export()
