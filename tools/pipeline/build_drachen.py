# Blender: Argland & die Drachenlande – Hochplateau in einem Felsenkessel (town_kit, struct_kit).
# Süden: Grenzposten des Argland-Rates (Palisade, Wachturm, Zelte, Feuer). Mitte/Westen: das Gerippe eines
# gewaltigen Drachen (Wirbelsäule, Rippenbögen, Schädel mit Hörnern, halb im Boden). Norden: auf einem Hügel die
# zerfallene Drachenburg des Platin-Drachenkönigs (Ringmauer mit Breschen, Türme, Bergfried, Trümmer). Osten: der
# Hort – eine Höhle zwischen Felswänden mit glimmendem Goldberg. Dazu verbrannte Bäume, Geröll, Felsbrocken.
#   blender -b -P build_drachen.py -- <WorldKit-Ordner> <ziel.glb>   (DGKit und FCKit daneben)
import math
import os
import sys

import bmesh
import bpy

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from loc_kit import Kit  # noqa: E402
from town_kit import Town, ROAD, PLAZA, FREE, YARD, HOUSE, RESERVED  # noqa: E402
from struct_kit import Structs  # noqa: E402
from mathutils import noise, Vector, Matrix  # noqa: E402

exp_dir, dst = [os.path.abspath(a) for a in sys.argv[sys.argv.index("--") + 1:][:2]]
up = os.path.dirname(exp_dir)
kit = Kit(exp_dir, dst, seed=144, extra_dirs=[os.path.join(up, "DGKit"), os.path.join(up, "FCKit")])
put, empty, rng = kit.put, kit.empty, kit.rng
HALF = 230.0
PLAY = 120.0
town = Town(kit, 150.0)
sk = Structs(kit, town)

CASTLE = (0.0, 76.0)
DRAGON = (-36.0, 14.0)
LAIR = (78.0, 34.0)
POST = (16.0, -62.0)


def smooth(a, b, v):
    t = max(0.0, min(1.0, (v - a) / (b - a)))
    return t * t * (3 - 2 * t)


def shape(x, y, h):
    d = math.hypot(x - CASTLE[0], y - CASTLE[1])
    return h + 9.0 * (1.0 - smooth(20.0, 48.0, d))                   # Burghügel


TERRAIN = dict(half=HALF, flat_r=60.0, hill_h=30.0, edge_rise=34.0, inner_h=1.0, height_fn=shape)
kit.height_field(**TERRAIN)

# --- Wege -----------------------------------------------------------------------------------------------------------
road = kit.spline([(0, -115), (8, -80), POST, (2, -30), (-6, 8), (4, 36), (CASTLE[0], CASTLE[1] - 22)])
lair_rd = kit.spline([(4, 36), (30, 34), (54, 36), (LAIR[0] - 6, LAIR[1])])
bone_rd = kit.spline([(-6, 8), (-20, 10), (DRAGON[0] + 8, DRAGON[1])])
town.road(road, 4.0, paved=False)
town.road(lair_rd, 3.0, paved=False)
town.road(bone_rd, 2.6, paved=False)

# --- Grenzposten des Argland-Rates ----------------------------------------------------------------------------------
px, py = POST
PAL = [(px + math.cos(a) * 15, py + math.sin(a) * 12) for a in [k / 44 * math.tau for k in range(44)]]
gates = []
for (ax, ay), (bx, by) in zip(road[:-1], road[1:]):
    for (qx, qy), (rx, ry) in zip(PAL, PAL[1:] + PAL[:1]):
        d1x, d1y, d2x, d2y = bx - ax, by - ay, rx - qx, ry - qy
        den = d1x * d2y - d1y * d2x
        if abs(den) < 1e-9:
            continue
        t = ((qx - ax) * d2y - (qy - ay) * d2x) / den
        u = ((qx - ax) * d1y - (qy - ay) * d1x) / den
        if 0 <= t <= 1 and 0 <= u <= 1:
            g = (ax + t * d1x, ay + t * d1y)
            if all(math.hypot(g[0] - c[0], g[1] - c[1]) > 8 for c in gates):
                gates.append(g)
town.palisade(PAL, gates=gates, gate_w=5.0, height=4.0, towers=[(px + 11.5, py + 6.5), (px - 11.5, py - 6.5)], tower_h=8.0)
for k, (dx, dy) in enumerate([(-7, 3), (-7, -3), (6, 4), (6, -4)]):
    put("SM_Tent_low", px + dx, py + dy, rot=90 if dx < 0 else -90, s=2.4)
    town.mark_rect(px + dx, py + dy, 4, 5, 0, HOUSE)
kit.ph("stone_fire_pit", px, py)
for k in range(3):
    a = k / 3 * math.tau
    kit.ph(rng.choice(["wooden_stool_01", "wooden_crate_02", "wooden_stool_02"]), px + math.cos(a) * 1.8, py + math.sin(a) * 1.8,
           rot=rng.uniform(0, 360))
for k in range(4):
    x, y = px - 4 + k * 2.6, py + 8.5
    put("SM_Spear_low", x, y, z=kit.ground_fn(x, y) - 0.1, s=2.6)
    put("SM_Cloth02", x + 0.35, y, z=kit.ground_fn(x, y) + 3.6, rot=90, s=3.5, nocol=True)
for _ in range(6):
    a, d = rng.uniform(0, math.tau), rng.uniform(3, 9)
    kit.ph(rng.choice(["wooden_crate_01", "wooden_barrels_01", "wine_barrel_01", "wicker_basket_01"]), px + math.cos(a) * d,
           py + math.sin(a) * d * 0.8, rot=rng.uniform(0, 360))

# --- Drachengerippe ---------------------------------------------------------------------------------------------------
# Die Wirbelsäule läuft über die Scheitel der Rippenbögen (das Tier liegt auf der Seite des Bauchs), Hals und Schwanz
# senken sich zum Boden; der Schädel liegt am Halsende im Sand.
dx0, dy0 = DRAGON
ang = math.radians(28.0)                                 # Richtung Kopf
ux, uy = math.cos(ang), math.sin(ang)
SPINE = 50.0
N = 46
RIB_H = 5.7                                              # Höhe SM_back_bone_03 bei Maßstab 1


def rib_scale(t):
    return 1.75 * math.sin(min(max((t - 0.18) / 0.5, 0.0), 1.0) * math.pi) if 0.18 < t < 0.68 else 0.0


pts = []
for k in range(N):
    t = k / (N - 1)
    s_ = (t - 0.4) * SPINE
    bend = 4.0 * math.sin(t * math.pi * 1.3)              # geschwungene Wirbelsäule
    x = dx0 + ux * s_ - uy * bend
    y = dy0 + uy * s_ + ux * bend
    rs = rib_scale(t)
    if rs > 0.05:
        h = RIB_H * rs * 0.86 - 0.8 * rs                 # Scheitel der Rippen (abzüglich Einsinken)
    elif t <= 0.18:
        h = 0.4 + (t / 0.18) * (RIB_H * rib_scale(0.2) * 0.86 - 0.8 * rib_scale(0.2) - 0.4)   # Schwanz steigt an
    else:
        h = max(0.5, (1.0 - (t - 0.68) / 0.32) * (RIB_H * rib_scale(0.66) * 0.86 - 0.8 * rib_scale(0.66)) + 0.6)  # Hals
    pts.append(Vector((x, y, kit.ground_fn(x, y) + h)))
for k in range(N - 1):                                   # Wirbel: dicke Knochenstücke mit Dornfortsätzen
    t = k / (N - 1)
    a, b = pts[k], pts[k + 1]
    r = 0.32 + 0.55 * math.sin(min(max(t, 0.05), 0.95) * math.pi)
    sk.log(a, b, r, mat="MI_Bone", sides=9)
    if k % 2 == 0:
        sk.log(a, a + Vector((0, 0, 1.1 * r + 0.4)), r * 0.32, mat="MI_Bone", sides=6)
        side = Vector((-uy, ux, 0)) * (r * 0.9)
        sk.log(a - side, a + side, r * 0.28, mat="MI_Bone", sides=6)          # Querfortsätze
for k in range(N):
    t = k / (N - 1)
    rs = rib_scale(t)
    if rs < 0.35 or k % 2:
        continue
    a = pts[k]
    b = pts[min(k + 1, N - 1)]
    tang = (b - pts[max(k - 1, 0)]).normalized()
    rot = math.degrees(math.atan2(tang.y, tang.x)) - 90.0    # Bogenebene senkrecht zur Wirbelsäule
    tilt = rng.uniform(-8, 8)
    put(rng.choice(["SM_back_bone_03", "SM_back_bone_01"]), a.x, a.y, rot=rot, s=rs, rx=tilt, sink=0.8 * rs)
head = pts[-1] + Vector((ux * 3.0, uy * 3.0, 0))
put("SM_skull_03", head.x, head.y, rot=math.degrees(ang) - 90 + 12, s=1.6, rx=-8, sink=0.6)
for k in range(3):                                      # Krallen/Hörner im Sand
    a_, d_ = rng.uniform(0, math.tau), rng.uniform(9, 16)
    put(rng.choice(["SM_horn_01", "SM_horn_03"]), dx0 + math.cos(a_) * d_, dy0 + math.sin(a_) * d_, rot=rng.uniform(0, 360),
        s=rng.uniform(1.8, 2.6), rx=rng.uniform(-60, 60), sink=0.5)
town.plaza(dx0 + ux * 6, dy0 + uy * 6, 28.0, paved=False, ragged=3.0)

# --- Drachenburg (Ruine) auf dem Hügel -----------------------------------------------------------------------------------
cx, cy = CASTLE
ring = [(cx + math.cos(a) * 26, cy + math.sin(a) * 21) for a in [k / 44 * math.tau for k in range(44)]]
breaches = [ring[33], ring[8], ring[17], ring[27]]
town.great_wall(ring + [ring[0]], height=11.0, T=4.5, gaps=breaches, gap_w=8.0, stairs_every=999.0, outer_side=-1,
                name="SM_DragonRuin")
for (bx, by) in breaches[1:]:
    for _ in range(10):
        kit.ph(rng.choice(["rock_moss_set_02", "boulder_01", "namaqualand_boulder_05", "rock_face_02"]), bx + rng.uniform(-5, 5),
               by + rng.uniform(-5, 5), rot=rng.uniform(0, 360), s=rng.uniform(0.7, 1.8))
for (tx, ty, s_, tilt) in [(cx - 25, cy + 6, 0.5, 0.0), (cx + 24, cy + 9, 0.45, 7.0), (cx - 12, cy + 20, 0.5, 0.0), (cx + 14, cy - 19, 0.42, -9.0)]:
    put("SM_TowerT3Uvd", tx, ty, s=s_, rx=tilt, sink=1.0 + abs(tilt) * 0.3)
put("SM_CastleSep4", cx, cy + 6, s=0.6, sink=6.0)
put("SM_CastleSep2", cx - 8, cy + 4, s=0.7, rx=6, sink=8.0)
for sx in (-1, 1):
    put("SM_brizer", cx + sx * 5.5, cy - 17.0, s=1.1)
    put("SM_Statue01", cx + sx * 8.0, cy - 19.0, rot=0, s=3.0)
town.plaza(cx, cy, 18.0, paved=False, ragged=2.0)

# --- Der Hort: Höhle zwischen Felswänden, Goldberg ----------------------------------------------------------------------------
lx, ly = LAIR
for (ox, oy, rot_, model, s_) in [(6, -9, -70, "mountainside", 2.6), (6, 9, -110, "mountainside", 2.6), (14, 0, -90, "mountainside", 3.0),
                                  (3, -15, -50, "rock_face_01", 5.0), (3, 15, -130, "rock_face_01", 5.0), (10, 0, -90, "rock_face_02", 6.0)]:
    kit.ph(model, lx + ox, ly + oy, z=kit.ground_fn(lx, ly) - 2.5, rot=rot_, s=s_)
for _ in range(12):
    a, d = rng.uniform(-1.2, 1.2), rng.uniform(4, 12)
    kit.ph(rng.choice(["boulder_01", "namaqualand_boulder_02", "stone_01"]), lx - math.cos(a) * d, ly + math.sin(a) * d * 1.5,
           rot=rng.uniform(0, 360), s=rng.uniform(0.6, 1.6))
# Goldberg (im Spiel: Gold-Shader über den Namen „GoldPile“), Truhen, Waffen
bm = bmesh.new()
g = kit.ground_fn(lx + 6, ly)
R_G, H_G = 5.5, 1.8
segs, rings = 28, 8
verts = [[None] * segs for _ in range(rings + 1)]
for i in range(rings + 1):
    rr = R_G * (1 - i / rings)
    for k in range(segs):
        a = k / segs * math.tau
        n = noise.noise(Vector((math.cos(a) * 2.2, math.sin(a) * 2.2, i * 0.4))) * 0.35
        z = g - 0.1 + H_G * (1 - (rr / R_G) ** 2) * (1 + n * 0.3)
        verts[i][k] = bm.verts.new((lx + 6 + math.cos(a) * rr * (1 + n * 0.25), ly + math.sin(a) * rr * 1.3 * (1 + n * 0.25), z))
top = bm.verts.new((lx + 6, ly, g - 0.1 + H_G))
for i in range(rings):
    for k in range(segs):
        k2 = (k + 1) % segs
        if i == rings - 1:
            bm.faces.new((verts[i][k], verts[i][k2], top))
        else:
            bm.faces.new((verts[i][k], verts[i][k2], verts[i + 1][k2], verts[i + 1][k]))
bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
me = bpy.data.meshes.new("GoldPile_Lair")
bm.to_mesh(me)
bm.free()
mat = bpy.data.materials.new("MI_Gold")
kit.keep_mats.add(mat.name)
me.materials.append(mat)
gold_obj = bpy.data.objects.new("GoldPile_Lair", me)
kit.out.objects.link(gold_obj)
for k in range(5):
    a = k / 5 * math.tau + 0.4
    kit.ph(rng.choice(["treasure_chest", "brass_goblets", "brass_pot_01", "antique_estoc", "kite_shield"]),
           lx + 6 + math.cos(a) * (R_G + 0.8), ly + math.sin(a) * (R_G + 0.8) * 1.3, rot=rng.uniform(0, 360))
town.plaza(lx + 4, ly, 9.0, paved=False, ragged=1.5)

# --- Bergriesen, Felswände, verbrannte Bäume, Geröll ----------------------------------------------------------------------
for k in range(26):
    a = k / 26 * math.tau + rng.uniform(-0.05, 0.05)
    d = rng.uniform(150, 210)
    put(rng.choice(["SM_rock_02", "SM_rock_01"]), math.cos(a) * d, math.sin(a) * d, z=-12.0, rot=rng.uniform(0, 360),
        s=rng.uniform(9.0, 15.0), sz=rng.uniform(10.0, 18.0), nocol=True)
for k in range(60):
    a = k / 60 * math.tau + rng.uniform(-0.03, 0.03)
    d = rng.uniform(84, 108)
    x, y = math.cos(a) * d, math.sin(a) * d
    if (abs(x) < 24 and y < 0) or (abs(y - LAIR[1]) < 26 and x > 60):
        continue
    put(rng.choice(["SM_rock_02", "SM_rock_01", "SM_Rock01"]), x, y, rot=rng.uniform(0, 360), s=rng.uniform(2.2, 3.6), sink=2.0)
for _ in range(70):
    x, y = rng.uniform(-90, 90), rng.uniform(-90, 90)
    if town.at(x, y) == FREE and kit.free(x, y, 3):
        if rng.random() < 0.45:
            kit.ph(rng.choice(["dead_tree_trunk", "dead_tree_trunk_02", "tree_stump_02"]), x, y, rot=rng.uniform(0, 360))
        else:
            kit.ph(rng.choice(["boulder_01", "namaqualand_boulder_02", "namaqualand_boulder_05", "rock_moss_set_02"]), x, y,
                   rot=rng.uniform(0, 360), s=rng.uniform(0.6, 1.8))
        kit.occupy(x, y, 2.5)
        town.mark_rect(x, y, 3, 3, 0, HOUSE)
for _ in range(50):
    a = rng.uniform(0, math.tau)
    d = rng.uniform(46, 85)
    x, y = math.cos(a) * d, math.sin(a) * d
    if town.at(x, y) == FREE and kit.free(x, y, 4):
        put("SM_Spruce1", x, y, rot=rng.uniform(0, 360), s=rng.uniform(0.6, 1.1), sink=0.3)
        kit.occupy(x, y, 3)

sk.flush("SM_Drachenlande")
kit.terrain(HALF, flat_r=TERRAIN["flat_r"], hill_h=TERRAIN["hill_h"], tex="Texture_T_Smooth_Layered_Rock_BC.png",
            normal="Texture_T_Smooth_Layered_Rock_N.png", tile=6.0, edge_rise=TERRAIN["edge_rise"], res=420,
            inner_h=TERRAIN["inner_h"], path_tex="Texture_T_GroundPace4_BC.png", path_normal="Texture_T_GroundPace4_N.png",
            path_fn=town.path_fn, dirt_fn=town.dirt_fn, height_fn=shape)
ALL = (-PLAY, -PLAY, PLAY, PLAY)
kit.grass(ALL, 6000, s=(0.5, 0.9))

# --- Anker ------------------------------------------------------------------------------------------------------------------
empty("Spawn", 0.0, -84.0, rot=0)
empty("Gate", 0.0, -92.0)
empty("Board", 6.0, -78.0)
empty("Keeper", cx, cy - 14, rot=180)
for i, a in enumerate([200, 235, 270, 305, 340, 20]):
    r = math.radians(a)
    empty("Slot%d" % (i + 1), math.cos(r) * 8, 4 + math.sin(r) * 6)
fires = [(px, py, kit.ground_fn(px, py) + 0.8)] + [(cx + sx * 5.5, cy - 17.0, kit.ground_fn(cx + sx * 5.5, cy - 17.0) + 2.4) for sx in (-1, 1)]
for i, (x, y, z) in enumerate(fires):
    empty("Fire_%d" % (i + 1), x, y, z)
for i in range(4):
    empty("Lamp_%d" % (i + 1), LAIR[0] + 6 + math.cos(i * 1.6) * 3, LAIR[1] + math.sin(i * 1.6) * 4, kit.ground_fn(*LAIR) + 2.5)
town.save_map(os.path.splitext(dst)[0] + "_map.png")
kit.finish_materials(metal_keys=("standlight",))
kit.export()
