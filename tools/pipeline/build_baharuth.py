# Blender: Arwintar, Hauptstadt des Baharuth-Kaiserreichs – geordnete Kaiserstadt mit breiten Prachtalleen (town_kit).
#   blender -b -P build_baharuth.py -- <ErantelKit-Ordner> <ziel.glb>
# Blender-Y = im Spiel -Z.  Südtor → Kaiserallee (Baumreihen, Laternen) → Reichsplatz mit Standbild →
# Palastterrasse mit Gärten und dem Kaiserpalast im Norden. Osten: Kaiserliche Arena (Kolosseum);
# Westen: Magische Akademie mit Turm. Rasterstraßen, helle Putzfassaden, wenig Armenviertel.
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from loc_kit import Kit  # noqa: E402
from town_kit import Town, ROAD, PLAZA, FREE, YARD, HOUSE, RESERVED  # noqa: E402
from mathutils import noise, Vector  # noqa: E402

exp_dir, dst = [os.path.abspath(a) for a in sys.argv[sys.argv.index("--") + 1:][:2]]
kit = Kit(exp_dir, dst, seed=33)
kit.lod_names = {"SM_Tree02", "SM_Tree03", "SM_Tree4", "SM_Tree05", "SM_Tree06", "SM_Tree07", "SM_Tree08", "SM_Tree09",
                 "SM_Tree10", "SM_Tree13", "SM_ChurchTree01", "SM_Spruce1", "SM_TreeType1", "SM_type2Tree",
                 "FV_tree_01", "FV_tree_02"}
put, rng = kit.put, kit.rng
HALF = 160.0
town = Town(kit, HALF)

C = (0.0, 4.0)
RX, RY = 118.0, 114.0
P = (0.0, 6.0)             # Reichsplatz
PAL = (0.0, 84.0)          # Kaiserpalast
ARENA = (72.0, 12.0)       # Kaiserliche Arena
ACAD = (-70.0, 30.0)       # Magische Akademie


def wall_r(a):
    return 1.0 + noise.noise(Vector((math.cos(a) * 1.1, math.sin(a) * 1.1, 8.1))) * 0.05


def ring_pt(deg, inset=0.0):
    a = math.radians(deg)
    r = wall_r(a)
    return C[0] + math.cos(a) * (RX * r - inset), C[1] + math.sin(a) * (RY * r - inset)


def inside(x, y, shrink=1.0):
    a = math.atan2(y - C[1], x - C[0])
    r = wall_r(a)
    return ((x - C[0]) / (RX * r * shrink)) ** 2 + ((y - C[1]) / (RY * r * shrink)) ** 2 < 1.0


def smooth(a, b, v):
    t = max(0.0, min(1.0, (v - a) / (b - a)))
    return t * t * (3 - 2 * t)


def shape(x, y, h):
    # Palastterrasse: +3 m mit sanfter Böschung
    tx = 1.0 - smooth(34.0, 44.0, abs(x - PAL[0]))
    ty = 1.0 - smooth(28.0, 38.0, abs(y - (PAL[1] - 4)))
    return h + 3.0 * tx * ty


TERRAIN = dict(half=HALF, flat_r=124.0, hill_h=9.0, edge_rise=16.0, inner_h=0.2, height_fn=shape)
kit.height_field(**TERRAIN)
SG, WG, EG = ring_pt(-90), ring_pt(180), ring_pt(0)

# --- Straßen (Raster mit zwei Prachtalleen) ----------------------------------------------------------------
ave_n = kit.spline([(SG[0], SG[1] - 46), (SG[0], SG[1] - 10), SG, (0, -60), (0, -20), P, (0, 30), (0, 52)])
ave_w = kit.spline([(WG[0] - 40, WG[1]), WG, (-80, 6), (-40, 6), P])
ave_e = kit.spline([P, (40, 6), (52, 8), (EG[0] - 30, 4), EG, (EG[0] + 40, EG[1])])
grid = []
for gx in (-84, -56, -28, 28, 56, 84):
    grid.append(kit.spline([(gx, -96), (gx + rng.uniform(-2, 2), -50), (gx, 0), (gx + rng.uniform(-2, 2), 50), (gx, 90)]))
for gy in (-80, -54, -28, 32, 58):
    grid.append(kit.spline([(-104, gy), (-50, gy + rng.uniform(-2, 2)), (0, gy), (50, gy + rng.uniform(-2, 2)), (104, gy)]))
ring_in = kit.spline([ring_pt(a, 12) for a in range(-80, 280, 10)] + [ring_pt(-80, 12)])
for line, w in [(ave_n, 11.0), (ave_w, 9.0), (ave_e, 9.0)]:
    town.road(line, w)
for g in grid:
    town.road(g, 5.0, paved=True)
town.road(ring_in, 4.5, paved=False)
town.plaza(P[0], P[1], 24.0, ragged=0.4)
town.plaza(ACAD[0], ACAD[1] - 16, 11.0, ragged=0.5)

# Reservierungen: Palastterrasse, Arena, Akademie
town.reserve(PAL[0], PAL[1], 78, 60, paved=0.0)
town.reserve(ARENA[0], ARENA[1], 64, 64)
town.reserve(ACAD[0], ACAD[1] + 4, 40, 30)

# --- Mauer ------------------------------------------------------------------------------------------------------
outer = [ring_pt(a) for a in range(0, 360, 3)]
town.wall(outer, gates=[SG, WG, EG], tower_every=26.0)
for gx, gy, deg in [(SG[0], SG[1], -90), (WG[0], WG[1], 180), (EG[0], EG[1], 0)]:
    a = math.radians(deg)
    tx, ty = -math.sin(a), math.cos(a)
    for sgn in (-1, 1):
        put("SM_TowerrType2", gx + tx * sgn * 9.5, gy + ty * sgn * 9.5, s=0.4, rot=deg + 90)
        ix, iy = gx - math.cos(a) * 4 + tx * sgn * 4.0, gy - math.sin(a) * 4 + ty * sgn * 4.0
        put("SM_Knight_posed", ix, iy, rot=deg + 90 + 180)
        put("SM_Spear_low", ix + tx * sgn * 0.5, iy + ty * sgn * 0.5)

# --- Kaiserpalast mit Terrasse und Gärten -------------------------------------------------------------------
put("SM_Build6", PAL[0], PAL[1] + 8, rot=180, s=0.4)
for sgn in (-1, 1):
    put("SM_TowerrType2", PAL[0] + sgn * 30, PAL[1] - 16, s=0.32)
    put("SM_Build1", PAL[0] + sgn * 26, PAL[1] - 6, rot=-90 * sgn, s=0.45)
garden = kit.spline([(0, 52), (0, 62)])
town.road(garden, 8.0)
for row in range(4):                                       # Gartenachsen: Baumreihen, Hecken, Statuen
    y = PAL[1] - 22 + row * 6
    for sgn in (-1, 1):
        for k in range(3):
            x = sgn * (8 + k * 7)
            put("SM_ChurchTree01", x, y, rot=rng.uniform(0, 360), s=0.7)
            if k < 2:
                put("SM_Bush07", x + sgn * 3.5, y, rot=rng.uniform(0, 360), s=1.2, nocol=True)
for sgn in (-1, 1):
    put("SM_Statue01", sgn * 5.0, PAL[1] - 28, rot=0, s=1.5)
    put("SM_StandLight", sgn * 5.5, PAL[1] - 34)
    town.lamps.append((sgn * 5.5, PAL[1] - 34, kit.ground_fn(sgn * 5.5, PAL[1] - 34) + 2.6))

# --- Kaiserliche Arena (Amphitheater, Tor nach Westen zur Stadt) ----------------------------------------------------
town.colosseum(ARENA[0], ARENA[1], R=30.0, r_arena=15.0, gates=(180.0, 0.0), segs=56)
for k in range(8):                                                         # Fackeln/Laternen am Arenaboden
    a = k / 8 * math.tau + 0.2
    x, y = ARENA[0] + math.cos(a) * 13.5, ARENA[1] + math.sin(a) * 13.5
    put("SM_StandLight", x, y, s=1.1)
    town.lamps.append((x, y, kit.ground_fn(x, y) + 2.6))
for k in range(6):                                                         # Laternen am Vorplatz
    a = math.radians(180 + (k - 2.5) * 12)
    x, y = ARENA[0] + math.cos(a) * 34, ARENA[1] + math.sin(a) * 34
    put("SM_StandLight", x, y, s=1.2)
    town.lamps.append((x, y, kit.ground_fn(x, y) + 2.8))
put("SM_Statue01", ARENA[0] - 36, ARENA[1] - 6, rot=90, s=1.8)
put("SM_Statue01", ARENA[0] - 36, ARENA[1] + 6, rot=90, s=1.8)
arena_road = kit.spline([(24, 8), (ARENA[0] - 34, 12)])
town.road(arena_road, 7.0)
# --- Magische Akademie ---------------------------------------------------------------------------------------------
put("SM_CastleSep4", ACAD[0], ACAD[1] + 10, s=0.55)
put("SM_Build1", ACAD[0] - 12, ACAD[1] + 2, rot=90, s=0.5)
put("SM_Build1", ACAD[0] + 12, ACAD[1] + 2, rot=-90, s=0.5)
put("SM_Statue01", ACAD[0], ACAD[1] - 16, s=1.6)

# --- Reichsplatz: Standbild, Laternen, Bäume -------------------------------------------------------------------------
put("SM_RoundOrn", P[0], P[1], s=1.15)
put("SM_Statue01", P[0], P[1], s=2.4)
for k in range(8):
    a = k / 8 * math.tau + math.pi / 8
    x, y = P[0] + math.cos(a) * 19, P[1] + math.sin(a) * 19
    put("SM_StandLight", x, y, s=1.3)
    town.lamps.append((x, y, kit.ground_fn(x, y) + 3.1))
for line, w in [(ave_n, 11.0)]:                                     # Allee: Baumreihen zwischen Fahrbahn und Häusern
    cum = Town._cum(line)
    d = 30.0
    while d < cum[-1] - 20:
        x, y, tx, ty = Town._at(line, cum, d)
        for sgn in (-1, 1):
            nx_, ny_ = -ty * sgn, tx * sgn
            px_, py_ = x + nx_ * (w / 2 - 0.8), y + ny_ * (w / 2 - 0.8)
            if inside(px_, py_, 0.95) and town.at(px_, py_) == ROAD and math.hypot(px_ - P[0], py_ - P[1]) > 26:
                put("SM_ChurchTree01", px_, py_, rot=rng.uniform(0, 360), s=0.75)
        d += 12.0

# --- Häuser ------------------------------------------------------------------------------------------------------------
RICH = [("SM_House", 0.66, 3), ("SM_House3", 0.66, 3), ("SM_House4", 0.66, 3), ("SM_House6", 0.66, 3),
        ("SM_AccomsP8", 0.62, 1)]
MID = [("SM_House", 0.62, 3), ("SM_House6", 0.62, 3), ("SM_House3", 0.62, 2), ("FV_house_02", 0.78, 2),
       ("FV_house_05", 0.78, 2), ("FV_house_03", 0.78, 1)]
POOR = [("FV_house_05", 0.74, 2), ("SM_HouseSet01", 1.0, 2), ("SM_StorageSet", 1.0, 2), ("FV_house_02", 0.74, 1)]


def district(x, y):
    if not inside(x, y, 0.93):
        return None
    d = math.hypot(x - P[0], y - P[1])
    if d < 52 or (abs(x) < 40 and y > 20):
        return RICH
    if inside(x, y, 0.75):
        return MID
    return POOR if y < -40 else MID


def dress(p):
    town.dress_front(p)


for line, w in [(ave_n, 11.0), (ave_w, 9.0), (ave_e, 9.0)]:
    for side in (-1, 1):
        town.frontage(line, w, side, district, on_place=dress, setback=(0.8, 1.4))
for g in grid:
    for side in (-1, 1):
        town.frontage(g, 5.0, side, district, on_place=dress, yard_depth=(4, 10))
for side in (-1, 1):
    town.frontage(ring_in, 4.5, side, district, on_place=dress, yard_depth=(4, 8))
town.fill(lambda x, y: inside(x, y, 0.9), MID + POOR, tries=1200, on_place=dress,
          align=lambda x, y: 0.0 if (int(x) // 7 + int(y) // 9) % 2 else 90.0)

# --- Märkte und Leben ---------------------------------------------------------------------------------------------------
town.market(-30.0, -38.0, r=13.0, rings=(8.0,), n=10, centerpiece=None, statue=("SM_Statue01", 1.2))
town.market(34.0, -40.0, r=11.0, rings=(7.0,), n=8, centerpiece=None, statue=None)
town.tavern((P[0] + 26, P[1] - 14))
town.tavern((-30.0, -24.0), n_tables=2)
for line, w in [(ave_n, 11.0), (ave_w, 9.0), (ave_e, 9.0)]:
    town.lamps_along(line, w, every=16.0)

# --- Draußen ---------------------------------------------------------------------------------------------------------
town.outskirts(lambda x, y: inside(x, y, 1.12),
               farms=[(-86, -136, 20), (92, -130, -15), (-144, 58, 80), (142, -66, -100), (-76, 142, 160), (88, 140, 200)],
               fields=[(-46, -140, 26, 16, 12), (50, -144, 24, 14, -8), (-142, 92, 18, 24, 6), (144, -18, 16, 22, -12),
                       (-34, 150, 28, 12, 4), (44, 152, 22, 12, -6)],
               trees=1600, keep_clear=[(SG[0], SG[1] - 30, 14)])
kit.terrain(HALF, flat_r=TERRAIN["flat_r"], hill_h=TERRAIN["hill_h"], tex="Textures_T_LandScapeLayer01_BC.png",
            normal="Textures_T_LandScapeLayer01_N.png", tile=5.0, edge_rise=TERRAIN["edge_rise"], res=540,
            inner_h=TERRAIN["inner_h"], path_tex="Textures_T_BayStone_BC.png", path_normal="Textures_T_BayStone_N.png",
            path_fn=town.path_fn, dirt_fn=town.dirt_fn, height_fn=shape)
kit.grass((-HALF + 2, -HALF + 2, HALF - 2, HALF - 2), 26000, s=(0.8, 1.5))

town.anchors(spawn=(SG[0] + 1.0, SG[1] + 10.0, 0), gate=(SG[0], SG[1] - 8.0), board=(P[0] + 10.0, P[1] - 18.0),
             keeper=(PAL[0], PAL[1] - 26, 180), slots_center=(P[0], P[1] - 14),
             lines=[(ave_n, 8), (ave_w, 8), (ave_e, 8)] + [(g, 10) for g in grid], inside=lambda x, y: inside(x, y, 0.95))
town.save_map(os.path.splitext(dst)[0] + "_map.png")
kit.finish_materials(metal_keys=("knight", "spear", "standlight"))
kit.export()
