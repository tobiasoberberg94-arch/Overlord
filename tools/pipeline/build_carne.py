# Blender: Dorf Carne – natürlich gewachsenes Dorf am Wald von Tob (Medieval Lake Village + Extras)
#   blender -b -P build_carne.py -- <VillageKit-Ordner> <ziel.glb>
# Blender-Y = im Spiel -Z.  Waldweg aus dem Süden, gewundene Dorfstraße zum Dorfplatz (3, 5),
# weiter zur Kirche im Norden; Abzweige zur Mühle (Westen) und zu den Feldern (Osten).
# Wiese nördlich des Platzes bleibt frei für den Überfall (Soldaten y≈18, Engel y≈26).
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from loc_kit import Kit  # noqa: E402

exp_dir, dst = [os.path.abspath(a) for a in sys.argv[sys.argv.index("--") + 1:][:2]]
kit = Kit(exp_dir, dst, seed=21)   # volle Originalqualität, Godot erzeugt LOD-Stufen
kit.lod_names = {"SM_Tree02", "SM_Tree03", "SM_Tree4", "SM_Tree05", "SM_Tree06", "SM_Tree07", "SM_Tree08", "SM_Tree09",
                 "SM_Tree10", "SM_Tree13", "SM_ChurchTree01", "SM_Spruce1", "SM_TreeType1", "SM_type2Tree",
                 "MW_tree_02", "MW_tree_03", "MW_pine_tree_Var_01", "FV_tree_01", "FV_tree_02"}   # Bäume: Instancing + Detailstufen
put, empty, rng = kit.put, kit.empty, kit.rng
HALF = 115.0
PLAZA = (3.0, 5.0)

# --- Wege -----------------------------------------------------------------------------------
main = kit.spline([(-10, -112), (-6, -80), (-2, -58), (5, -38), (-2, -17), PLAZA, (9, 21), (4, 36), (1, 46)])
west = kit.spline([PLAZA, (-12, 9), (-27, 5), (-40, -3), (-52, -9)])
east = kit.spline([(-1, -15), (14, -21), (29, -15), (45, -24), (62, -20)])
north = kit.spline([(9, 21), (23, 28), (33, 43), (40, 60)])
south_w = kit.spline([(-2, -58), (-20, -66), (-38, -62)])
plaza = kit.spline([(PLAZA[0] - 7, PLAZA[1] - 1), (PLAZA[0] - 2, PLAZA[1] + 6), (PLAZA[0] + 6, PLAZA[1] + 4),
                    (PLAZA[0] + 7, PLAZA[1] - 4), (PLAZA[0] - 1, PLAZA[1] - 6), (PLAZA[0] - 7, PLAZA[1] - 1)])
mill_road = kit.spline([(29, -15), (40, -30), (46, -44), (53, -51)])      # Feldweg zur Windmühle
path_fn = kit.roads_mask([(main, 4.2), (west, 3.2), (east, 3.0), (north, 2.4), (south_w, 2.4), (plaza, 9.0),
                          (mill_road, 2.2)], HALF)
kit.terrain(HALF, flat_r=55.0, hill_h=8.0, tex="Textures_T_LandScapeLayer01_BC.png",
            normal="Textures_T_LandScapeLayer01_N.png", tile=5.0, edge_rise=14.0, res=420, inner_h=1.1,
            path_tex="Textures_T_LandScapeLayer04_BC.png", path_normal="Textures_T_LandScapeLayer04_N.png",
            path_fn=path_fn)

# Freiflächen reservieren: Überfallwiese, Kirche, Felder, Mühle, Dorfeingang
kit.occupy(2, 22, 7)
kit.occupy(0, 54, 13)
kit.occupy(-1, -44, 6)
FIELDS = [(26, -48, 18, 11, 12), (48, -42, 14, 10, -8), (36, -2, 12, 8, 25)]
for (fx, fy, fw, fh, fr) in FIELDS:
    kit.occupy(fx, fy, max(fw, fh) * 0.8)
kit.occupy(-54, -10, 7)

# --- Höfe -----------------------------------------------------------------------------------
smoke = []
YARD = ["SM_WoodenBarrel01", "SM_FireWoodSet02", "SM_FireWoodSet01", "SM_WoodenBucket01", "SM_WoodenBucket02",
        "SM_WoodenBox01", "SM_WoodenBox03", "SM_Chair"]


def yard(hx, hy, rot, rad, name):
    r = math.radians(rot)
    fx, fy = math.sin(r), -math.cos(r)          # Hausfront (zur Straße)
    sx, sy = math.cos(r), math.sin(r)           # seitlich
    # Krempel neben der Tür
    kit.clutter(hx + fx * (rad * 0.8) + sx * rad * 0.6, hy + fy * (rad * 0.8) + sy * rad * 0.6, YARD, n=(2, 4), r=(0.4, 1.6))
    if rng.random() < 0.6:
        put(rng.choice(["SM_FlowerPot01", "SM_FlowerPot02"]), hx + fx * rad * 0.75 - sx * 1.0,
            hy + fy * rad * 0.75 - sy * 1.0, nocol=True)
    # Garten hinter dem Haus mit Zaun (teils offen)
    gx, gy = hx - fx * (rad + 5), hy - fy * (rad + 5)
    if rng.random() < 0.75:
        for k in range(rng.randint(3, 6)):
            a = r + k * math.pi / 3 + rng.uniform(-0.2, 0.2)
            put(rng.choice(["SM_Fence01", "SM_Fence02"]), gx + math.cos(a) * 5.5, gy + math.sin(a) * 5.5,
                rot=math.degrees(a) + 90 + rng.uniform(-8, 8))
        kit.clutter(gx, gy, ["SM_WheatGrass01", "SM_Foliage_12", "SM_WheatGrass03", "SM_Foliage_33"], n=(6, 12),
                    r=(0.5, 4.0), nocol=True)
    # Wäsche an der Seite
    if rng.random() < 0.5:
        cx, cy = hx + sx * (rad + 2.0), hy + sy * (rad + 2.0)
        for k in range(3):
            put(rng.choice(["SM_Cloth01", "SM_Cloth02", "SM_Cloth03"]), cx + fx * (k - 1) * 0.7, cy + fy * (k - 1) * 0.7,
                z=kit.ground_fn(cx, cy) + 1.0, rot=rot + 90, nocol=True)
    if rng.random() < 0.5:
        put(rng.choice(["SM_Tree05", "SM_Tree06", "SM_Tree07"]), gx + sx * 3, gy + sy * 3, rot=rng.uniform(0, 360),
            s=rng.uniform(0.8, 1.1))
    smoke.append((hx, hy, kit.ground_fn(hx, hy) + 7.5))


FV = 0.8      # Medieval-Fantasy-Village-Häuser auf Menschenmaß (Tür ~2,2 m)
H = ["SM_HouseSet01", "SM_HouseSet02", "SM_HouseSet01", "SM_StorageSet",
     ("FV_house_02", FV), ("FV_house_03", FV), ("FV_house_05", FV), ("FV_house_01", FV)]
kit.along(main, H, spacing=(16, 24), gap=(3.5, 6.5), jitter=14, skip=0.1, on_place=yard, start=70, end=170)
kit.along(west, H, spacing=(15, 22), gap=(3.5, 6.5), jitter=16, skip=0.15, on_place=yard, start=6)
kit.along(east, ["SM_StorageSet", "SM_HouseSet01", ("FV_house_05", FV)], spacing=(18, 26), gap=(3.5, 6.5), jitter=12, skip=0.2,
          on_place=yard, start=6, end=55)
kit.along(north, ["SM_HouseSet02", "SM_HouseSet01", ("FV_house_04", FV), ("FV_house_02", FV)], spacing=(18, 26), gap=(3.5, 6.5), jitter=15, skip=0.3,
          on_place=yard, start=6)

# Dorfeingang: alter Torbogen am Waldweg
put("SM_GateWall01", -1.5, -46.0, rot=-12)

# Dorfplatz: Feuerstelle, Marktwagen, Bänke, Dorfbaum
px, py = PLAZA
put("SM_firestone", px + 1.5, py + 1.0)
kit.clutter(px + 2.5, py + 2.5, ["SM_FireWoodSet02", "SM_FireWood01"], n=(1, 2), r=(0.5, 1.2))
put("SM_WoodenWagon01", px - 5.0, py + 3.0, rot=35)
put("SM_WoodenWagon02", px + 5.5, py - 3.5, rot=-60)
kit.clutter(px - 5.5, py - 3.5, ["SM_WoodenBarrel01", "SM_WoodenBox01", "SM_WoodenBox03", "SM_WoodenBucket02"],
            n=(4, 6), r=(0.4, 1.8))
put("SM_WoodenChair01", px - 1.0, py + 4.6, rot=170)
put("SM_WoodenChair01", px + 4.5, py + 1.5, rot=100)
put("SM_ChurchTree01", px - 8.5, py + 7.5, rot=40, s=1.2)
put("SM_Sign01", px + 6.5, py + 5.0, rot=200)
for (dx, dy) in [(-4, -8), (6, 7), (-9, 2), (8, -7)]:
    put("SM_StandLight", px + dx, py + dy)

# Kirche + Friedhof (unregelmäßig)
put("SM_ChurchSet", 0.0, 57.0, rot=4)
for i in range(14):
    a = rng.uniform(0.2, 1.6)
    d = rng.uniform(9, 16)
    gx, gy = math.cos(a) * d + 6, 50.0 + math.sin(a) * d * 0.6
    put(rng.choice(["SM_tombStone01", "SM_tombstone02"]), gx, gy, rot=180 + rng.uniform(-14, 14),
        sink=rng.uniform(0.0, 0.15))
put("SM_Statue01", 18.0, 52.0, rot=210)
for k in range(5):
    put("SM_StoneWall01", 6 + k * 4.4 + rng.uniform(-0.4, 0.4), 41.5 + rng.uniform(-0.6, 0.6), rot=rng.uniform(-6, 6))
put("SM_ChurchTree01", 24.0, 46.0, rot=120, s=1.3)

# Mühle am Westende
put("SM_WaterWheel01", -55.0, -9.0, rot=80)
put("SM_StorageSet", -60.0, -2.0, rot=100)
kit.clutter(-50.0, -14.0, ["SM_WoodenBox01", "SM_WoodenBarrel01", "SM_WoodenBox03"], n=(4, 7), r=(0.5, 2.5))
put("SM_Boat", -47.0, -18.0, rot=30)

# Windmühle auf der Anhöhe hinter den Feldern – Flügel drehen sich im Spiel (spin_…, scripts/world3d/spinner.gd)
MX, MY = 62.0, -60.0
MR = 42.0
mz = kit.ground_fn(MX, MY) - 0.3
put("MW_mill_body_02", MX, MY, z=mz, rot=MR, origin=True)
r_ = math.radians(MR)
ox, oy = 8.7 * math.sin(r_), -8.7 * math.cos(r_)          # Nabe vor dem Rumpf (lokal -Y 8,7 m)
prop = put("MW_mill_propeller", MX + ox, MY + oy, z=mz + 26.1, rot=MR, origin=True)
prop.name = "spin_mill"
kit.occupy(MX, MY, 17)
kit.clutter(MX - 10, MY + 6, ["MW_barrel_group_01", "MW_crate_group_02", "MW_bag_02", "MW_bag_03", "MW_crate_03"],
            n=(4, 7), r=(1.0, 4.0))
put("MW_millstone_bottom", MX - 7, MY + 12, rot=20)
put("SM_WoodenWagon02", MX - 14, MY + 2, rot=-30)

# Felder (schräg, unregelmäßig) mit lückenhaften Zäunen und Heu
for (fx, fy, fw, fh, fr) in FIELDS:
    r = math.radians(fr)
    for _ in range(int(fw * fh * 1.1)):
        u, v = rng.uniform(-fw / 2, fw / 2), rng.uniform(-fh / 2, fh / 2)
        x, y = fx + u * math.cos(r) - v * math.sin(r), fy + u * math.sin(r) + v * math.cos(r)
        if path_fn(x, y) < 0.5:
            put(rng.choice(["SM_WheatGrass01", "SM_WheatGrass03"]), x, y, rot=rng.uniform(0, 360),
                s=rng.uniform(0.85, 1.2), nocol=True)
    for k in range(int(fw / 3.8)):
        if rng.random() < 0.25:
            continue
        u = -fw / 2 + k * 3.8 + 1.9
        for v in (-fh / 2 - 0.6, fh / 2 + 0.6):
            x, y = fx + u * math.cos(r) - v * math.sin(r), fy + u * math.sin(r) + v * math.cos(r)
            put("SM_Fence01", x, y, rot=fr + rng.uniform(-6, 6))
put("SM_Hay", 58.0, -6.0, rot=60, s=0.45)
put("SM_WoodenWagon01", 40.0, -30.0, rot=10)

# --- Wald von Tob ------------------------------------------------------------------------------
village = [(-62, -72, 66, 70)]
BIG = ["SM_Tree4", "SM_Tree10", "SM_Tree02", "SM_Tree09", "SM_Tree13", "SM_Tree4", "SM_Tree10", "SM_Tree03",
       "MW_pine_tree_Var_01", "MW_pine_tree_Var_01", "MW_tree_03"]
UNDER = ["SM_Bush07", "SM_Foliage_33", "SM_Foliage_56", "SM_Bush01", "SM_Foliage_59", "SM_Foliage_22", "SM_Foliage_24"]
kit.forest((-HALF + 4, -HALF + 4, HALF - 4, HALF - 4), BIG, 460, avoid=village, min_d=4.0, s=(0.9, 1.35),
           under=UNDER, under_n=3, threshold=-0.2)
# lichte Baumgruppen im Dorf
kit.forest((-62, -72, 66, 70), ["SM_Tree02", "SM_Tree13", "SM_Tree05", "SM_Tree06", "SM_Tree09", "MW_tree_02", "MW_tree_03"], 60, min_d=7.0,
           density_scale=0.06, threshold=0.25, s=(0.8, 1.2), under=["SM_Bush07", "SM_Foliage_33"], under_n=2)
kit.forest((-30, -110, 30, -60), BIG, 70, min_d=3.5, under=UNDER, under_n=3, threshold=-0.4)   # Waldweg im Süden

# --- Wiese ------------------------------------------------------------------------------------------
ALL = (-HALF + 2, -HALF + 2, HALF - 2, HALF - 2)
kit.grass(ALL, 30000, s=(0.8, 1.5))
kit.grass(ALL, 5000, kind="@flower", s=(0.8, 1.2))
kit.grass((-60, -70, 64, 66), 9000, s=(0.6, 1.0))                     # kürzeres Gras im Dorf
kit.meadow(ALL, ["SM_Foliage_33", "SM_Foliage_34", "SM_Foliage_12"], 260, s=(0.7, 1.1))
FLOWERS = ["MW_flower_clump_01", "MW_flower_clump_02", "MW_flower_clump_03", "MW_flower_clump_04",
           "MW_flower_01", "MW_flower_02", "MW_flower_03", "MW_flower_04"]
kit.meadow(ALL, FLOWERS + ["MW_grass_02", "MW_plant_ground"], 2600, s=(0.8, 1.3),
           patch=(FLOWERS, 120, 4.0))
kit.meadow((-60, -70, 64, 66), ["MW_flower_clump_01", "MW_flower_clump_03", "MW_plant_ground", "MW_bush"], 500, s=(0.7, 1.1))
kit.meadow((-HALF + 2, -HALF + 2, HALF - 2, HALF - 2),
           ["SM_Foliage_81", "SM_Foliage_82", "SM_Foliage_90", "SM_Foliage_91", "SM_Foliage_99"],
           900, avoid=[(-40, -40, 40, 50)])
for _ in range(26):
    x, y = rng.uniform(-90, 90), rng.uniform(-90, 90)
    if path_fn(x, y) < 0.5:
        put(rng.choice(["SM_Rock01", "SM_Rock03", "SM_RockPlane02", "SM_StoneDan01"]), x, y, rot=rng.uniform(0, 360),
            s=rng.uniform(0.5, 1.1), sink=0.4)

# --- Anker ------------------------------------------------------------------------------------------
empty("Spawn", -1.0, -38.0, rot=-8)
empty("Gate", -2.5, -50.0)
empty("Board", px + 5.5, py + 2.0)
for i, a in enumerate([200, 240, 280, 320, 0, 40]):
    r = math.radians(a)
    empty("Slot%d" % (i + 1), px + math.cos(r) * 5.0, py + math.sin(r) * 5.0)
empty("Fire_1", px + 1.5, py + 1.0, kit.ground_fn(px, py) + 0.9)
for i, (x, y, z) in enumerate(smoke):
    empty("Smoke_%d" % (i + 1), x, y, z)
n = 1
for line, step in ((main, 9), (west, 9), (east, 10), (north, 10)):
    for k in range(0, len(line), step):
        if -60 < line[k][1] < 50:
            empty("Walk_%d" % n, line[k][0], line[k][1])
            n += 1
for i in range(6):
    a = i * math.tau / 6
    empty("Idle_%d" % (i + 1), px + math.cos(a) * 3.5, py + math.sin(a) * 3.5)
print("OVERLORD walk", n - 1, "smoke", len(smoke))

kit.finish_materials(metal_keys=("standlight",))
kit.export()
