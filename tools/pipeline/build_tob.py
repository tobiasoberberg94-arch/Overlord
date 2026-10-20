# Blender: Großer Wald von Tob – uralter, dichter Wald (struct_kit, Fotoscans).
# Pfad von Süden (Carne-Seite) über einen Bach mit Bohlenbrücke nach Norden zur Lichtung vor Hamsukes Höhle: eine
# Felswand aus Fotoscan-Felsen am Fuß eines bewaldeten Hügels, darin der Höhleneingang (dunkle Grotte mit Nest aus
# Zweigen und Knochen). Am Seitenpfad die Ruinen eines alten Elfenschreins, östlich das Lager der Kräutersammler aus
# Carne (Unterstand, Trockengestelle, Körbe, Feuerstelle). Umgestürzte Stämme, Wurzelteller, Baumstümpfe.
#   blender -b -P build_tob.py -- <TobKit-Ordner> <ziel.glb>   (DGKit daneben: Knochen)
import math
import os
import sys

import bmesh
import bpy

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from loc_kit import Kit  # noqa: E402
from town_kit import Town, ROAD, PLAZA, FREE, YARD, HOUSE, RESERVED  # noqa: E402
from struct_kit import Structs  # noqa: E402
from mathutils import noise, Vector  # noqa: E402

exp_dir, dst = [os.path.abspath(a) for a in sys.argv[sys.argv.index("--") + 1:][:2]]
kit = Kit(exp_dir, dst, seed=44, extra_dirs=[os.path.join(os.path.dirname(exp_dir), "DGKit")])
kit.lod_names = {"SM_Tree02", "SM_Tree03", "SM_Tree4", "SM_Tree05", "SM_Tree06", "SM_Tree07", "SM_Tree08", "SM_Tree09",
                 "SM_Tree10", "SM_Tree13", "SM_ChurchTree01", "MW_tree_02", "MW_tree_03", "MW_pine_tree_Var_01",
                 "FV_tree_01", "FV_tree_02"}
put, empty, rng = kit.put, kit.empty, kit.rng
HALF = 110.0
town = Town(kit, HALF)
sk = Structs(kit, town)
DEN = (2.0, 60.0)                 # Höhleneingang
RUINS = (-34.0, 18.0)
CAMP = (24.0, 6.0)


def smooth(a, b, v):
    t = max(0.0, min(1.0, (v - a) / (b - a)))
    return t * t * (3 - 2 * t)


def creek_y(x):
    return -28.0 + 6.0 * math.sin(x * 0.045 + 0.7) + 2.0 * math.sin(x * 0.13)


def shape(x, y, h):
    # Hügel hinter der Höhle: steile Felsstufe ab y = 67, nach Norden auslaufend
    side = 1.0 - smooth(26.0, 44.0, abs(x - DEN[0]))
    hill = 13.0 * smooth(66.5, 75.0, y + 1.5 * noise.noise(Vector((x * 0.2, 1.0, 3.0)))) * side
    h += hill * (0.85 + 0.15 * noise.noise(Vector((x * 0.08, y * 0.08, 5.0))))
    # Bachbett quer durch den Wald
    d = abs(y - creek_y(x))
    return h - 1.3 * (1.0 - smooth(1.6, 3.8, d))


TERRAIN = dict(half=HALF, flat_r=20.0, hill_h=10.0, edge_rise=10.0, inner_h=1.4, height_fn=shape)
kit.height_field(**TERRAIN)
g0 = kit.ground_fn

# --- Wege --------------------------------------------------------------------------------------------------
path = kit.spline([(4, -110), (-6, -70), (6, -40), (2, -28), (-4, -12), (8, 14), (-2, 36), (2, DEN[1] - 10)])
side = kit.spline([(-4, -12), (-18, -2), (RUINS[0], RUINS[1])])
camp_rd = kit.spline([(8, 14), (16, 10), CAMP])
town.road(path, 3.2, paved=False)
town.road(side, 2.4, paved=False)
town.road(camp_rd, 2.2, paved=False)
town.plaza(DEN[0], DEN[1] - 9, 10.5, paved=False, ragged=1.8)

# --- Bach mit Wasserband, Brücke, Trittsteinen ---------------------------------------------------------------
bm = bmesh.new()
prev = None
xs = [x * 2.0 for x in range(-56, 57)]
for x in xs:
    y = creek_y(x)
    tx, ty = 1.0, (creek_y(x + 0.5) - creek_y(x - 0.5))
    L = math.hypot(tx, ty)
    nx, ny = -ty / L, tx / L
    z = min(g0(x + nx * dd, y + ny * dd) for dd in (-1.0, 0.0, 1.0)) + 0.5
    a = bm.verts.new((x + nx * 2.6, y + ny * 2.6, z))
    b = bm.verts.new((x - nx * 2.6, y - ny * 2.6, z))
    if prev:
        bm.faces.new((prev[0], prev[1], b, a))
    prev = (a, b)
    town.mark_rect(x, y, 2.2, 5.6, math.degrees(math.atan2(ty, tx)), RESERVED, dirt=0.8)
bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
for f in bm.faces:
    if f.normal.z < 0:
        f.normal_flip()
me = bpy.data.meshes.new("Water_River_Creek")
bm.to_mesh(me)
bm.free()
wm = bpy.data.materials.new("MI_CreekWater")
kit.keep_mats.add(wm.name)
me.materials.append(wm)
kit.out.objects.link(bpy.data.objects.new("Water_River_Creek", me))
bx = 2.0
by = creek_y(bx)
bank = max(g0(bx, by - 4.5), g0(bx, by + 4.5))
sk.boardwalk([(bx, by - 5.0), (bx, by + 5.0)], bank + 0.35, width=2.2, post_every=2.5)
for s in (-1, 1):                                       # Geländer aus Rundholz
    for k in range(5):
        p = Vector((bx + s * 1.05, by - 4.5 + k * 2.25, bank + 0.35))
        sk.log(p, p + Vector((0, 0, 1.0)), 0.06)
    sk.log((bx + s * 1.05, by - 4.5, bank + 1.3), (bx + s * 1.05, by + 4.5, bank + 1.3), 0.05)
for k in range(9):                                      # Trittsteine und Ufersteine
    x = rng.uniform(-60, 60)
    if abs(x - bx) < 6:
        continue
    y = creek_y(x) + rng.uniform(-2.6, 2.6)
    kit.ph(rng.choice(["boulder_01", "rock_moss_set_02", "namaqualand_boulder_05"]), x, y, z=g0(x, y) - 0.2,
           rot=rng.uniform(0, 360), s=rng.uniform(0.5, 1.0))

# --- Hamsukes Höhle -------------------------------------------------------------------------------------------
dx, dy = DEN
cave = sk.cave_alcove(dx, dy, 0.0, w=5.2, h=4.3, depth=7.0)
gz = g0(dx, dy)
# Felswand: zwei große Felsflanken, ein Sturzfels über dem Eingang, Felsblöcke davor und auf dem Hügel
for (ox, rot_, s_) in [(-8.2, 6.0, 1.35), (12.2, -8.0, 1.35)]:
    kit.ph("mountainside", dx + ox - 2.0 * (1 if ox > 0 else -1) * 0.0, dy + 3.6, z=gz - 0.6, rot=rot_, s=s_)
kit.ph("rock_face_01", dx, dy + 2.6, z=gz + 3.9, rot=180.0 + rng.uniform(-6, 6), s=1.65)
for (ox, oy, s_) in [(-18.0, 6.0, 1.2), (21.0, 7.0, 1.15), (-2.0, 13.0, 1.5)]:
    kit.ph("mountainside", dx + ox, dy + oy, z=g0(dx + ox, dy + oy) - 2.5, rot=rng.uniform(-20, 20), s=s_)
for _ in range(14):
    a = rng.uniform(math.pi * 1.1, math.pi * 1.9)
    d = rng.uniform(7.0, 13.0)
    x, y = dx + math.cos(a) * d * 1.3, dy + 2 + math.sin(a) * d * 0.45
    if abs(x - dx) < 4.5 and y > dy - 6:
        continue
    kit.ph(rng.choice(["rock_moss_set_01", "rock_moss_set_02", "boulder_01"]), x, y, rot=rng.uniform(0, 360), s=rng.uniform(0.6, 1.4))
# Nest: Zweige, Knochen
ix, iy, iz = cave["inside"]
for k in range(6):
    a = k / 6 * math.tau
    kit.ph("dry_branches_medium_01", ix + math.cos(a) * 0.9, iy + math.sin(a) * 0.9, z=gz, rot=math.degrees(a) + 90, s=1.2)
for k in range(5):
    put(rng.choice(["SM_small_bone_01", "SM_small_bone_02", "SM_horn_02", "SM_horn_03"]), dx + rng.uniform(-2.0, 2.0),
        dy + rng.uniform(-3.0, 2.0), rot=rng.uniform(0, 360), rx=rng.uniform(70, 110), s=rng.uniform(0.35, 0.6), nocol=True)
for k in range(3):                                      # Kratzspuren: entrindete Baumstämme vor der Höhle
    kit.ph("dead_tree_trunk_02", dx + rng.choice((-1, 1)) * rng.uniform(5, 9), dy - rng.uniform(8, 14), rot=rng.uniform(0, 360),
           s=rng.uniform(1.2, 1.6))
town.reserve(dx, dy + 4, 26, 12)

# --- Ruinen eines alten Elfenschreins am Seitenpfad ----------------------------------------------------------
rx, ry = RUINS
for k in range(7):
    a = k / 7 * math.tau
    x, y = rx + math.cos(a) * 6.5, ry + math.sin(a) * 6.5
    put("SM_column_ruin_module_bottom", x, y, rot=rng.uniform(0, 360))
    if rng.random() < 0.6:
        put("SM_column_ruin_module_body", x, y, z=g0(x, y) + 0.9, rot=rng.uniform(0, 360))
put("SM_stone_door_staute", rx, ry + 8.5, rot=180, s=0.7)
for k in range(5):
    put(rng.choice(["SM_old_stone_wall", "SM_Mossy_Stone_Wall01"]), rx + rng.uniform(-9, 9), ry + rng.uniform(-9, 9),
        rot=rng.uniform(0, 360), s=rng.uniform(0.5, 0.8), sink=0.4)
put("SM_firestone", rx, ry)
town.plaza(rx, ry, 9.0, paved=False, ragged=1.5)

# --- Lager der Kräutersammler ------------------------------------------------------------------------------------
cx, cy = CAMP
town.plaza(cx, cy, 8.0, paved=False, ragged=1.4)
if "SM_StorageSet" in town._have():                    # Hütte der Kräutersammler (Schuppen mit Vordach)
    put("SM_StorageSet", cx + 3.0, cy + 7.0, rot=200.0, s=0.85, sink=0.15)
    kit.occupy(cx + 3.0, cy + 7.0, 4.5)
    town.mark_rect(cx + 3.0, cy + 7.0, 8.5, 6.5, 200.0, HOUSE)
else:
    sk.lean_to(cx + 2.0, cy + 4.2, 200.0, w=4.4, d=2.6, h=2.3)
sk.drying_rack(cx - 3.5, cy + 2.5, rot=70.0)
sk.drying_rack(cx + 5.5, cy - 1.0, rot=-20.0, w=2.6)
kit.ph("stone_fire_pit", cx, cy, rot=rng.uniform(0, 360))
for k in range(4):
    a = k / 4 * math.tau + 0.4
    kit.ph(rng.choice(["wooden_stool_01", "tree_stump_02", "wooden_crate_02"]), cx + math.cos(a) * 2.1, cy + math.sin(a) * 2.1,
           rot=rng.uniform(0, 360), s=1.0 if k else 0.45)
for k in range(6):
    a, d = rng.uniform(0, math.tau), rng.uniform(2.8, 5.5)
    kit.ph(rng.choice(["wicker_basket_01", "wicker_basket_02", "wooden_bucket_01", "wooden_bowl_02"]), cx + math.cos(a) * d,
           cy + math.sin(a) * d, rot=rng.uniform(0, 360))
if "SM_WoodenWagon02" in town._have():
    put("SM_WoodenWagon02", cx - 6.0, cy - 4.0, rot=30.0)
kit.ph("hatchet", cx + 1.0, cy - 2.2, rot=40.0)

# --- Wald: alte Riesen, Unterholz, Totholz -------------------------------------------------------------------------
for k in range(0, len(path), 22):                       # umgestürzte Stämme neben dem Pfad
    x, y = path[k]
    sd = rng.choice([-1, 1])
    kit.ph(rng.choice(["dead_tree_trunk", "dead_tree_trunk_02"]), x + sd * rng.uniform(4.5, 8.0), y + rng.uniform(-2, 2),
           rot=rng.uniform(0, 360), s=rng.uniform(1.4, 2.2))
for _ in range(26):
    x, y = rng.uniform(-HALF + 6, HALF - 6), rng.uniform(-HALF + 6, HALF - 6)
    if town.at(x, y) == FREE and kit.free(x, y, 3):
        kit.ph(rng.choice(["root_cluster_01", "tree_stump_01", "tree_stump_02", "dead_tree_trunk_02", "rock_moss_set_01"]), x, y,
               rot=rng.uniform(0, 360), s=rng.uniform(0.9, 1.5))
        kit.occupy(x, y, 2.5)
        town.mark_rect(x, y, 3, 3, 0, HOUSE)
kit.occupy(dx, dy, 14)
kit.occupy(dx, dy - 10, 9)
kit.occupy(rx, ry, 10)
kit.occupy(cx, cy, 8)
kit.occupy(0, -40, 6)
BIG = ["SM_Tree4", "SM_Tree10", "SM_Tree02", "SM_Tree09", "SM_Tree13", "SM_Tree03", "MW_tree_02", "MW_tree_03",
       "FV_tree_02", "FV_tree_01", "MW_pine_tree_Var_01", "SM_ChurchTree01"]
UNDER = ["SM_Bush07", "SM_Foliage_56", "SM_Bush01", "SM_Foliage_59", "SM_Foliage_22", "SM_Foliage_24", "SM_Foliage_27",
         "SM_Foliage_12", "MW_bush", "FV_bush_05", "SM_Bush03"]
creek_box = [(-HALF, -40.0, HALF, -16.0)]
kit.forest((-HALF + 3, -HALF + 3, HALF - 3, HALF - 3), BIG, 900, min_d=3.6, s=(1.0, 1.6), under=UNDER, under_n=4,
           threshold=-0.45, density_scale=0.05)
kit.forest((-HALF + 3, -HALF + 3, HALF - 3, HALF - 3), ["SM_Tree05", "SM_Tree06", "SM_Tree07", "SM_Tree08"], 160,
           min_d=4.0, s=(0.8, 1.2), threshold=-0.2)

sk.flush("SM_Tobwald")
kit.terrain(HALF, flat_r=TERRAIN["flat_r"], hill_h=TERRAIN["hill_h"], tex="Texture_T_Mossy_ForesFloor_BC.png", tile=5.0,
            edge_rise=TERRAIN["edge_rise"], res=420, inner_h=TERRAIN["inner_h"], path_tex="Textures_T_LandScapeLayer04_BC.png",
            path_normal="Textures_T_LandScapeLayer04_N.png", path_fn=town.path_fn, dirt_fn=town.dirt_fn, height_fn=shape)
ALL = (-HALF + 2, -HALF + 2, HALF - 2, HALF - 2)
kit.grass(ALL, 26000, s=(0.8, 1.5))
kit.grass(ALL, 2600, kind="@flower", s=(0.7, 1.1))
kit.meadow(ALL, UNDER + ["SM_Foliage_33", "SM_Foliage_34", "MW_plant_ground", "MW_flower_clump_01"], 2600, s=(0.8, 1.4))

# --- Anker ---------------------------------------------------------------------------------------------------------
empty("Spawn", -6.0, -66.0, rot=-15)
empty("Gate", -5.0, -74.0)
empty("Board", 0.0, -60.0)
empty("Keeper", dx, dy - 3.5, rot=180)
for i, a in enumerate([200, 235, 270, 305, 340, 20]):
    r = math.radians(a)
    empty("Slot%d" % (i + 1), dx + math.cos(r) * 6, dy - 13 + math.sin(r) * 5)
empty("Fire_1", rx, ry, g0(rx, ry) + 0.6)
empty("Fire_2", cx, cy, g0(cx, cy) + 0.6)
n = 1
for k in range(0, len(path), 10):
    empty("Walk_%d" % n, path[k][0], path[k][1])
    n += 1
town.save_map(os.path.splitext(dst)[0] + "_map.png")
kit.finish_materials()
kit.export()
