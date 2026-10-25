# Blender: Königshauptstadt Re-Estize – alte, dicht gedrängte Hauptstadt am Fluss (town_kit).
#   blender -b -P build_recapital.py -- <ErantelKit-Ordner> <ziel.glb> [FCKit-Ordner]
# Blender-Y = im Spiel -Z.  Südtor → Hauptstraße → Steinbrücke über den Fluss → Großer Markt → Rampe zum
# Königsschloss Ro-Lente auf dem Burgberg im Norden (eigene Ringmauer). Westen: Domplatz mit Kathedrale;
# Osten: Gildenplatz; südlich des Flusses Handwerker und Armenviertel, Kais mit Booten und Stegen.
import math
import os
import sys

import bmesh
import bpy

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from loc_kit import Kit  # noqa: E402
from town_kit import Town, ROAD, PLAZA, FREE, YARD, HOUSE, RESERVED, WALL  # noqa: E402
from mathutils import noise, Vector  # noqa: E402

args = sys.argv[sys.argv.index("--") + 1:]
exp_dir, dst = [os.path.abspath(a) for a in args[:2]]
fc_dir = os.path.abspath(args[2]) if len(args) > 2 else os.path.join(os.path.dirname(exp_dir), "FCKit")
kit = Kit(exp_dir, dst, seed=41, extra_dirs=[fc_dir])
kit.lod_names = {"SM_Tree02", "SM_Tree03", "SM_Tree4", "SM_Tree05", "SM_Tree06", "SM_Tree07", "SM_Tree08", "SM_Tree09",
                 "SM_Tree10", "SM_Tree13", "SM_ChurchTree01", "SM_Spruce1", "SM_TreeType1", "SM_type2Tree",
                 "FV_tree_01", "FV_tree_02"}
put, rng = kit.put, kit.rng
HALF = 165.0
town = Town(kit, HALF)

C = (0.0, 0.0)
RX, RY = 122.0, 116.0
M = (0.0, 14.0)            # Großer Markt
DOM = (-56.0, 34.0)        # Domplatz
GILDE = (58.0, 30.0)       # Gildenplatz
SUED = (12.0, -62.0)       # Markt südlich des Flusses
CASTLE = (0.0, 92.0)       # Burgberg (Mitte des Plateaus)


def wall_r(a):
    return 1.0 + noise.noise(Vector((math.cos(a) * 1.4, math.sin(a) * 1.4, 5.5))) * 0.08


def ring_pt(deg, inset=0.0):
    a = math.radians(deg)
    r = wall_r(a)
    return C[0] + math.cos(a) * (RX * r - inset), C[1] + math.sin(a) * (RY * r - inset)


def inside(x, y, shrink=1.0):
    a = math.atan2(y - C[1], x - C[0])
    r = wall_r(a)
    return ((x - C[0]) / (RX * r * shrink)) ** 2 + ((y - C[1]) / (RY * r * shrink)) ** 2 < 1.0


SG, WG, EG = ring_pt(-90), ring_pt(184), ring_pt(-4)

# --- Fluss (West → Ost, südlich der Mitte) ------------------------------------------------------------
river = kit.spline([(-HALF - 10, -14), (-110, -20), (-70, -12), (-30, -26), (0, -22), (34, -30), (72, -18), (112, -26),
                    (HALF + 10, -20)], step=2.0)


def river_d(x, y):
    best = 1e9
    for (ax, ay), (bx, by) in zip(river[:-1], river[1:]):
        if abs(ax - x) > 40 and abs(bx - x) > 40:
            continue
        dx, dy = bx - ax, by - ay
        L = dx * dx + dy * dy or 1e-6
        t = max(0.0, min(1.0, ((x - ax) * dx + (y - ay) * dy) / L))
        best = min(best, math.hypot(x - (ax + t * dx), y - (ay + t * dy)))
    return best


def smooth(a, b, v):
    t = max(0.0, min(1.0, (v - a) / (b - a)))
    return t * t * (3 - 2 * t)


def shape(x, y, h):
    d = math.hypot(x - CASTLE[0], y - CASTLE[1])
    h += 13.0 * (1.0 - smooth(26.0, 60.0, d))                    # Burgberg mit Plateau
    rd = river_d(x, y)
    if inside(x, y, 0.97):
        w = 1.0 - smooth(9.6, 10.4, rd)                          # in der Stadt: Kaimauern, steile Kante
    else:
        w = 1.0 - smooth(6.5, 12.5, rd)                          # draußen: Uferböschung, schneidet durch Hügel
    return h * (1.0 - w) + min(h - 3.6, -3.6) * w


# vor der Stadt sanftes Hügelland (vorher stiegen direkt vor der Mauer hohe Hänge an)
TERRAIN = dict(half=HALF, flat_r=138.0, hill_h=4.5, edge_rise=8.0, inner_h=0.3, height_fn=shape)
kit.height_field(**TERRAIN)

# Fluss im Raster sperren (keine Häuser), Ufer als Erde
for (ax, ay), (bx, by) in zip(river[:-1], river[1:]):
    L = math.hypot(bx - ax, by - ay)
    rot = math.degrees(math.atan2(by - ay, bx - ax))
    town.mark_rect((ax + bx) / 2, (ay + by) / 2, L + 1.0, 21.0, rot, RESERVED, dirt=0.7)

# Wasserfläche (im Spiel: Wasser-Shader über den Namen „Water…“)
bm = bmesh.new()
prev = None
WATER_Z = -2.35
for i in range(len(river)):
    (x, y) = river[i]
    (nx_, ny_) = river[min(i + 1, len(river) - 1)]
    (px_, py_) = river[max(i - 1, 0)]
    tx, ty = nx_ - px_, ny_ - py_
    L = math.hypot(tx, ty) or 1.0
    ox, oy = -ty / L * 11.0, tx / L * 11.0
    a = bm.verts.new((x + ox, y + oy, WATER_Z))
    b = bm.verts.new((x - ox, y - oy, WATER_Z))
    if prev:
        bm.faces.new((prev[0], prev[1], b, a))
    prev = (a, b)
me = bpy.data.meshes.new("Water_River")
bm.to_mesh(me)
bm.free()
wmat = bpy.data.materials.new("MI_RiverWater")
kit.keep_mats.add(wmat.name)
me.materials.append(wmat)
wo = bpy.data.objects.new("Water_River", me)
kit.out.objects.link(wo)

# Kaimauern aus Steinlagen entlang des Flusses in der Stadt
rcum = Town._cum(river)
dq = 0.0
while dq < rcum[-1]:
    x, y, tx, ty = Town._at(river, rcum, dq)
    for sgn in (-1, 1):
        nx_, ny_ = -ty * sgn, tx * sgn
        qx, qy = x + nx_ * 10.1, y + ny_ * 10.1
        if inside(qx, qy, 0.96) and all(math.hypot(qx - bx_, qy - by_) > 4.5 for bx_, by_ in [(0, -22), (-40, -18), (44, -24)]):
            put("SM_brick", qx, qy, z=-5.2, rot=math.degrees(math.atan2(ty, tx)))
    dq += 4.8

# --- Straßen, Brücken, Plätze ----------------------------------------------------------------------------
BRIDGE_Y = -22.0
main = kit.spline([(SG[0], SG[1] - 46), (SG[0], SG[1] - 12), SG, (4, -96), (-3, -74), SUED, (2, -40), (0, BRIDGE_Y - 10),
                   (0, BRIDGE_Y + 10), (2, 0), M, (-2, 32), (3, 50), (0, 66), (0, 76)])
west = kit.spline([M, (-20, 20), (-40, 30), DOM, (-80, 26), (-100, 20), WG, (WG[0] - 40, WG[1] + 4)])
east = kit.spline([M, (20, 22), (40, 28), GILDE, (80, 22), (100, 16), EG, (EG[0] + 40, EG[1] - 4)])
ring_in = kit.spline([ring_pt(a, 13) for a in range(-80, 280, 10)] + [ring_pt(-80, 13)])
south_w = kit.spline([SUED, (-20, -58), (-50, -56), (-80, -50), (-100, -42)])
south_e = kit.spline([SUED, (40, -66), (70, -60), (98, -50)])
quay_n = kit.spline([(-100, -5), (-70, 2), (-40, -8), (-12, -6), (14, -10), (40, -12), (74, 0), (100, -8)])
quay_s = kit.spline([(-96, -38), (-66, -30), (-34, -44), (-10, -40), (16, -44), (40, -48), (76, -36), (100, -44)])
lanes = [kit.spline(p) for p in [
    [(-2, 32), (-24, 48), (-42, 60), (-58, 74)], [(3, 50), (26, 54), (44, 66), (60, 78)],
    [(-40, 30), (-34, 8), (-40, -6)], [(40, 28), (36, 6), (40, -10)],
    [DOM, (-64, 56), (-76, 76)], [GILDE, (68, 54), (78, 72)],
    [(-80, 26), (-86, 50), (-90, 70)], [(80, 22), (88, 46), (92, 66)],
    [(-20, 20), (-18, 0), (-12, -6)], [(20, 22), (18, 2), (14, -10)],
    [(-50, -56), (-56, -78), (-46, -96)], [(40, -66), (48, -84), (36, -100)],
    [(-3, -74), (-26, -80), (-50, -90)], [(4, -96), (26, -92), (50, -100)],
    [(-80, -50), (-84, -72), (-70, -92)], [(70, -60), (78, -80), (64, -98)],
    [(-100, 20), (-104, 0), (-100, -5)], [(100, 16), (104, -2), (100, -8)],
    [(-24, 48), (-14, 64), (-26, 80)], [(26, 54), (16, 70), (26, 84)],
]]
castle_ramp = kit.spline([(0, 66), (8, 72), (4, 80), (-4, 86), (0, 92)])
for line, w in [(main, 7.5), (west, 6.5), (east, 6.5), (castle_ramp, 6.0)]:
    town.road(line, w)
for line in (south_w, south_e, quay_n, quay_s):
    town.road(line, 5.0, paved=line in (quay_n, quay_s))
town.road(ring_in, 4.5, paved=False)
for l in lanes:
    town.road(l, 4.0, paved=rng.random() < 0.55)
for (px, py, pr) in [(M[0], M[1], 18.0), (DOM[0], DOM[1], 12.0), (GILDE[0], GILDE[1], 10.0), (SUED[0], SUED[1], 11.0)]:
    town.plaza(px, py, pr)
# Brücken über den Fluss: Hauptstraße und zwei Nebenbrücken
for bx, by in [(0, BRIDGE_Y), (-40, -18), (44, -24)]:
    put("FV_bridge", bx, by, z=-0.35, rot=90, s=1.25 if bx == 0 else 1.0)
    town.mark_rect(bx, by, 6, 24, 0, ROAD, paved=1.0)
for bx, by in [(-40, -18), (44, -24)]:
    town.road(kit.spline([(bx, by - 16), (bx, by + 16)]), 4.0, paved=False)

# --- Burgberg: Königsschloss Ro-Lente mit Ringmauer ------------------------------------------------------
town.reserve(CASTLE[0], CASTLE[1] + 6, 70, 52)
put("SM_CastleUvd", CASTLE[0], CASTLE[1] + 8, rot=180, s=0.36)
castle_ring = [(CASTLE[0] + math.cos(math.radians(a)) * 40, CASTLE[1] + 2 + math.sin(math.radians(a)) * 32) for a in range(0, 360, 5)]
town.wall(castle_ring, gates=[(0, CASTLE[1] - 30)], tower_every=24.0, height_rows=2,
          small_tower=("SM_TowerT3Uvd", 0.42))
for sgn in (-1, 1):
    put("SM_TowerT3Uvd", sgn * 7.5, CASTLE[1] - 30, s=0.5)

# --- Stadtmauer -------------------------------------------------------------------------------------------
outer = [ring_pt(a) for a in range(0, 360, 3)]
river_gaps = []
for a in range(0, 360, 3):
    x, y = ring_pt(a)
    if river_d(x, y) < 13:
        river_gaps.append((x, y))
town.wall(outer, gates=[SG, WG, EG] + river_gaps, tower_every=28.0)
for gx, gy, deg in [(SG[0], SG[1], -90), (WG[0], WG[1], 184), (EG[0], EG[1], -4)]:
    a = math.radians(deg)
    tx, ty = -math.sin(a), math.cos(a)
    for sgn in (-1, 1):
        put("SM_TowerrType2", gx + tx * sgn * 8.5, gy + ty * sgn * 8.5, s=0.36, rot=deg + 90)
        ix, iy = gx - math.cos(a) * 4 + tx * sgn * 3.6, gy - math.sin(a) * 4 + ty * sgn * 3.6
        put("SM_Knight_posed", ix, iy, rot=deg + 90 + 180)
        put("SM_Spear_low", ix + tx * sgn * 0.5, iy + ty * sgn * 0.5)
for x, y in river_gaps[::3]:                     # Wassertürme, wo der Fluss die Mauer quert
    put("SM_TowerSmall", x, y + (14 if y > -20 else -14), s=0.7)

# --- Wahrzeichen ------------------------------------------------------------------------------------------
put("SM_CastleSep3", DOM[0], DOM[1] + 22, rot=0, s=1.6)                   # Kathedrale (gotische Rotunde)
for sgn in (-1, 1):
    put("SM_TowerT3Uvd", DOM[0] + sgn * 15, DOM[1] + 16, s=0.42)          # Glockentürme
town.reserve(DOM[0], DOM[1] + 22, 40, 26)
put("SM_Build1", GILDE[0], GILDE[1] + 15, rot=0, s=0.7)                   # Gildenhaus
town.reserve(GILDE[0], GILDE[1] + 15, 24, 12)
put("SM_TowerrType2", GILDE[0] + 14, GILDE[1] + 18, s=0.3)
for sgn in (-1, 1):                                                        # Palais des Hochadels am Burgweg
    put("SM_Build1", sgn * 30, 62, rot=-90 * sgn, s=0.62)
    town.reserve(sgn * 30, 62, 10, 21)

# --- Häuser -----------------------------------------------------------------------------------------------
RICH = [("SM_House", 0.64, 3), ("SM_House3", 0.64, 3), ("SM_House4", 0.64, 3), ("SM_House6", 0.64, 3),
        ("SM_AccomsP8", 0.6, 1), ("FV_house_02", 0.8, 1)]
MID = [("FV_house_02", 0.78, 3), ("FV_house_03", 0.78, 2), ("FV_house_05", 0.78, 3), ("SM_House", 0.62, 2),
       ("SM_House6", 0.62, 2), ("SM_House3", 0.62, 2), ("SM_HouseSet02", 1.0, 1)]
POOR = [("SM_HouseSet01", 1.0, 3), ("FV_house_05", 0.72, 2), ("SM_StorageSet", 1.0, 3), ("FV_house_02", 0.72, 1),
        ("SM_HouseSet02", 1.0, 1)]


# Häuser in richtiger Größe: Türen größer als die Figuren (vorher Puppenhäuser)
HS = 1.35
RICH = [(n, s * HS, w) for n, s, w in RICH]
MID = [(n, s * HS, w) for n, s, w in MID]
POOR = [(n, s * HS, w) for n, s, w in POOR]


def district(x, y):
    if not inside(x, y, 0.93) or river_d(x, y) < 12.5:
        return None
    if math.hypot(x - CASTLE[0], y - CASTLE[1]) < 46:
        return None
    if y > 40:
        return RICH
    if y > -14:
        return MID if abs(x) > 34 else RICH
    return POOR if abs(x) > 40 or y < -80 else MID


def dress(p):
    town.dress_front(p)


for line, w in [(main, 7.5), (west, 6.5), (east, 6.5)]:
    for side in (-1, 1):
        town.frontage(line, w, side, district, on_place=dress)
for line in (south_w, south_e):
    for side in (-1, 1):
        town.frontage(line, 5.0, side, district, on_place=dress, yard_depth=(4, 9))
for line, side in ((quay_n, 1), (quay_s, -1)):                                   # Häuser mit Blick aufs Wasser
    town.frontage(line, 5.0, side, district, on_place=dress, yard_depth=(4, 8))
for l in lanes:
    for side in (-1, 1):
        town.frontage(l, 4.0, side, district, on_place=dress, yard_depth=(4, 9))
for side in (-1, 1):
    town.frontage(ring_in, 4.5, side, district, on_place=dress, yard_depth=(4, 8))
town.fill(lambda x, y: inside(x, y, 0.9) and river_d(x, y) > 13 and math.hypot(x - CASTLE[0], y - CASTLE[1]) > 46,
          POOR + MID, tries=1600, on_place=dress)

# --- Märkte, Wirtshäuser ------------------------------------------------------------------------------------
town.market(M[0], M[1], r=18.0, rings=(9.0, 13.0), n=18)
town.market(SUED[0], SUED[1], r=11.0, rings=(7.0,), n=8, centerpiece=None, statue=("SM_Statue01", 1.3))
town.tavern((M[0] + 18, M[1] - 10))
town.tavern((SUED[0] - 12, SUED[1] + 8), n_tables=2)
put("SM_Statue01", DOM[0], DOM[1], s=1.8)
put("SM_Statue01", GILDE[0], GILDE[1], s=1.4)
for line, w in [(main, 7.5), (west, 6.5), (east, 6.5), (castle_ramp, 6.0)]:
    town.lamps_along(line, w, every=17.0)

# --- Kais: Stege, Boote, Ladung ------------------------------------------------------------------------------
for k in range(10):
    i = rng.randrange(10, len(river) - 10)
    x, y = river[i]
    if not inside(x, y, 0.9) or abs(x) < 8:
        continue
    (ax, ay), (bx, by) = river[i - 1], river[i + 1]
    tx, ty = bx - ax, by - ay
    L = math.hypot(tx, ty) or 1.0
    side = rng.choice((-1, 1))
    nx_, ny_ = -ty / L * side, tx / L * side
    px_, py_ = x + nx_ * 9.0, y + ny_ * 9.0
    rot = math.degrees(math.atan2(-nx_, ny_))
    kit.ph("modular_wooden_pier", px_, py_, z=WATER_Z + 0.9, rot=rot)
    if rng.random() < 0.7 and "SM_Boat" in town._have():
        put("SM_Boat", x + nx_ * 5.0 + tx / L * 4, y + ny_ * 5.0 + ty / L * 4, z=WATER_Z - 0.15,
            rot=math.degrees(math.atan2(ty, tx)) + rng.uniform(-10, 10))
    for _ in range(rng.randint(2, 4)):
        q = rng.uniform(0, math.tau)
        kit.ph(rng.choice(["wooden_crate_01", "wooden_crate_02", "wine_barrel_01", "wooden_barrels_01", "barrel_03"]),
               x + nx_ * 13.5 + math.cos(q) * 1.6, y + ny_ * 13.5 + math.sin(q) * 1.6, rot=rng.uniform(0, 360))

# --- Draußen --------------------------------------------------------------------------------------------------
town.outskirts(lambda x, y: inside(x, y, 1.12) or river_d(x, y) < 14,
               farms=[(-90, -140, 20), (96, -132, -15), (-148, 60, 80), (146, -70, -100), (-80, 146, 160), (90, 144, 200)],
               fields=[(-50, -142, 26, 16, 12), (52, -146, 24, 14, -8), (-146, 96, 18, 24, 6), (148, -20, 16, 22, -12),
                       (-36, 152, 28, 12, 4), (46, 154, 22, 12, -6), (-150, -60, 16, 22, 10)],
               trees=1800, keep_clear=[(SG[0], SG[1] - 30, 14)])
for _ in range(140):                                     # Obstbäume und Linden in der Stadt
    x, y = rng.uniform(-110, 110), rng.uniform(-110, 110)
    if inside(x, y, 0.9) and town.at(x, y) == FREE and town.rect_free(x, y, 4, 4, 0, (FREE,)):
        put(rng.choice(["SM_Tree05", "SM_Tree06", "SM_Tree13", "SM_ChurchTree01"]), x, y, rot=rng.uniform(0, 360),
            s=rng.uniform(0.55, 0.85))
        town.mark_rect(x, y, 3, 3, 0, HOUSE)

# --- Gelände ------------------------------------------------------------------------------------------------------
kit.terrain(HALF, flat_r=TERRAIN["flat_r"], hill_h=TERRAIN["hill_h"], tex="Textures_T_LandScapeLayer01_BC.png",
            normal="Textures_T_LandScapeLayer01_N.png", tile=5.0, edge_rise=TERRAIN["edge_rise"], res=560,
            inner_h=TERRAIN["inner_h"], path_tex="Textures_T_BayStone_BC.png", path_normal="Textures_T_BayStone_N.png",
            path_fn=town.path_fn, dirt_fn=town.dirt_fn, height_fn=shape)
ALL = (-HALF + 2, -HALF + 2, HALF - 2, HALF - 2)
kit.grass(ALL, 30000, s=(0.8, 1.5))

# --- Anker -----------------------------------------------------------------------------------------------------------
town.anchors(spawn=(SG[0] + 1.0, SG[1] + 10.0, 0), gate=(SG[0], SG[1] - 8.0), board=(M[0] + 8.0, M[1] - 11.0),
             keeper=(0.0, 72.0, 180), slots_center=M, lines=[(main, 8), (west, 8), (east, 8)] + [(l, 9) for l in lanes],
             inside=lambda x, y: inside(x, y, 0.95))
town.save_map(os.path.splitext(dst)[0] + "_map.png")
kit.finish_materials(metal_keys=("knight", "spear", "standlight"))
kit.export()
