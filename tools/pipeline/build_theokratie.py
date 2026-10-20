# Blender: Slane-Theokratie – heilige Hauptstadt aus hellem Kalkstein (town_kit).
#   blender -b -P build_theokratie.py -- <ErantelKit-Ordner> <ziel.glb>
# Blender-Y = im Spiel -Z.  Südtor → Prozessionsstraße mit Säulen und Standbildern → Platz der Sechs Götter (sechs
# Tempel im Kreis um das Götterdenkmal) → Domtreppe → Kathedrale (Rotunde mit Glockentürmen) auf der Domterrasse.
# Klosterviertel im Westen (Kreuzgang, Gärten), Pilgerherbergen und Märkte im Osten.
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from loc_kit import Kit  # noqa: E402
from town_kit import Town, ROAD, PLAZA, FREE, YARD, HOUSE, RESERVED  # noqa: E402
from mathutils import noise, Vector  # noqa: E402

exp_dir, dst = [os.path.abspath(a) for a in sys.argv[sys.argv.index("--") + 1:][:2]]
kit = Kit(exp_dir, dst, seed=6)
kit.lod_names = {"SM_Tree02", "SM_Tree03", "SM_Tree4", "SM_Tree05", "SM_Tree06", "SM_Tree07", "SM_Tree08", "SM_Tree09",
                 "SM_Tree10", "SM_Tree13", "SM_ChurchTree01", "SM_Spruce1", "SM_TreeType1", "SM_type2Tree",
                 "FV_tree_01", "FV_tree_02"}
put, rng = kit.put, kit.rng
HALF = 150.0
town = Town(kit, HALF)

C = (0.0, 6.0)
RX, RY = 108.0, 106.0
SIX = (0.0, 10.0)          # Platz der Sechs Götter
DOM = (0.0, 66.0)          # Kathedrale
KLOSTER = (-62.0, 30.0)
PILGER = (58.0, -10.0)


def wall_r(a):
    return 1.0 + noise.noise(Vector((math.cos(a) * 1.2, math.sin(a) * 1.2, 3.3))) * 0.06


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
    # Domterrasse: +4 m, nach Süden über eine breite Treppe/Rampe erreichbar
    d = max(abs(x - DOM[0]) / 40.0, abs(y - (DOM[1] + 4)) / 30.0)
    return h + 4.0 * (1.0 - smooth(0.85, 1.15, d))


TERRAIN = dict(half=HALF, flat_r=114.0, hill_h=8.0, edge_rise=16.0, inner_h=0.2, height_fn=shape)
kit.height_field(**TERRAIN)
SG, WG, EG = ring_pt(-90), ring_pt(180), ring_pt(0)

# --- Straßen und Plätze --------------------------------------------------------------------------------------
proc = kit.spline([(SG[0], SG[1] - 46), (SG[0], SG[1] - 10), SG, (0, -60), (0, -24), SIX, (0, 28), (0, 40)])
west = kit.spline([(WG[0] - 40, WG[1]), WG, (-70, 12), (-40, 12), SIX])
east = kit.spline([SIX, (36, 6), PILGER, (82, -4), EG, (EG[0] + 40, EG[1])])
ring_in = kit.spline([ring_pt(a, 12) for a in range(-80, 280, 10)] + [ring_pt(-80, 12)])
lanes = [kit.spline(p) for p in [
    [(0, -60), (-30, -56), (-56, -44), (-78, -30)], [(0, -60), (30, -58), (56, -46), (76, -32)],
    [(-40, 12), (-44, -10), (-38, -34)], [(36, 6), (40, -20), (34, -40)],
    [(-40, 12), (-42, 40), (-30, 58)], [(36, 6), (40, 36), (30, 56)],
    [(-70, 12), (-80, 36), (-70, 58)], [(82, -4), (86, 24), (74, 48)],
    [(-30, -56), (-24, -80)], [(30, -58), (26, -80)], [(-56, -44), (-70, -66)], [(56, -46), (70, -66)],
]]
for line, w in [(proc, 10.0), (west, 7.0), (east, 7.0)]:
    town.road(line, w)
town.road(ring_in, 4.5, paved=False)
for l in lanes:
    town.road(l, 4.5, paved=True)
town.plaza(SIX[0], SIX[1], 25.0, ragged=0.3)
town.plaza(PILGER[0], PILGER[1], 11.0)
town.reserve(DOM[0], DOM[1] + 6, 80, 56, paved=0.6)                  # Domterrasse (Kalksteinplatten)
town.reserve(KLOSTER[0], KLOSTER[1], 30, 30, dirt=0.25)

# --- Mauer --------------------------------------------------------------------------------------------------------
outer = [ring_pt(a) for a in range(0, 360, 3)]
town.wall(outer, gates=[SG, WG, EG], tower_every=26.0)
for gx, gy, deg in [(SG[0], SG[1], -90), (WG[0], WG[1], 180), (EG[0], EG[1], 0)]:
    a = math.radians(deg)
    tx, ty = -math.sin(a), math.cos(a)
    for sgn in (-1, 1):
        put("SM_TowerrType2", gx + tx * sgn * 9.0, gy + ty * sgn * 9.0, s=0.38, rot=deg + 90)
        ix, iy = gx - math.cos(a) * 4 + tx * sgn * 3.8, gy - math.sin(a) * 4 + ty * sgn * 3.8
        put("SM_Knight_posed", ix, iy, rot=deg + 90 + 180)
        put("SM_Spear_low", ix + tx * sgn * 0.5, iy + ty * sgn * 0.5)

# --- Kathedrale: Rotunde mit zwei Glockentürmen, Treppe, Säulen -----------------------------------------------
put("SM_CastleSep3", DOM[0], DOM[1] + 6, s=2.1)
for sgn in (-1, 1):
    put("SM_CastleSep4", DOM[0] + sgn * 21, DOM[1] - 2, s=0.48)
    put("SM_ChurchSet", DOM[0] + sgn * 30, DOM[1] + 18, rot=-90 * sgn, s=1.1)
for k in range(7):                                     # Säulenreihe auf der Terrasse
    for sgn in (-1, 1):
        put("SM_Collum", DOM[0] + sgn * 9.0, DOM[1] - 20 + k * 4.5, z=kit.ground_fn(DOM[0] + sgn * 9.0, DOM[1] - 20 + k * 4.5) - 0.2, s=1.0)
for sgn in (-1, 1):
    put("SM_Statue01", sgn * 6.0, DOM[1] - 26, s=1.8)
    for k in range(6):                                       # Zypressenallee auf der Terrasse
        put("SM_Spruce1", sgn * 13.5, DOM[1] - 24 + k * 5.0, rot=rng.uniform(0, 360), s=0.6)
    for k in range(3):                                       # Heckenparterres
        for j in range(4):
            put("SM_Bush07", sgn * (19 + j * 3.2), DOM[1] - 22 + k * 7.0, rot=rng.uniform(0, 360), s=1.0, nocol=True)
    put("SM_RoundOrn", sgn * 26.0, DOM[1] - 14, s=0.75)       # Brunnenpavillons
town.road(kit.spline([(0, 36), (0, DOM[1] - 6)]), 8.0)

# --- Platz der Sechs Götter -------------------------------------------------------------------------------------
# Götterdenkmal in der Mitte; im Kreis sechs Schreine (Rundtempel mit Standbild) in einem Säulenring,
# dazwischen Zypressen, Hecken und Bänke.
put("SM_RoundOrn", SIX[0], SIX[1], s=1.3)
put("SM_Statue01", SIX[0], SIX[1], s=2.8)
for k in range(6):
    a = math.radians(k * 60 + 30)
    tx_, ty_ = SIX[0] + math.cos(a) * 30, SIX[1] + math.sin(a) * 30
    put("SM_RoundOrn", tx_, ty_, s=0.9)
    put("SM_Statue01", tx_, ty_, rot=math.degrees(a) + 90, s=1.5)
    put("SM_StandLight", SIX[0] + math.cos(a) * 24.5, SIX[1] + math.sin(a) * 24.5, s=1.3)
    town.lamps.append((SIX[0] + math.cos(a) * 24.5, SIX[1] + math.sin(a) * 24.5, 3.1))
    for j in (-1, 1):                                        # Zypressen und Hecken zwischen den Schreinen
        b = a + math.radians(30) * j * 0.55
        put("SM_Spruce1", SIX[0] + math.cos(b) * 33, SIX[1] + math.sin(b) * 33, rot=rng.uniform(0, 360), s=0.55)
        put("SM_Bush07", SIX[0] + math.cos(b) * 29.5, SIX[1] + math.sin(b) * 29.5, rot=rng.uniform(0, 360), s=1.1, nocol=True)
    kit.ph("painted_wooden_bench", SIX[0] + math.cos(a + 0.25) * 26.5, SIX[1] + math.sin(a + 0.25) * 26.5,
           rot=math.degrees(a + 0.25) + 90)
for k in range(48):                                          # Säulenring (Lücken an den Straßen)
    a = k / 48 * math.tau
    x, y = SIX[0] + math.cos(a) * 27.0, SIX[1] + math.sin(a) * 27.0
    if town.at(x, y) == ROAD or min(abs(math.degrees(a) - d) % 360 for d in (90, 270, 0, 180, 360)) < 7:
        continue
    put("SM_Collum", x, y, z=kit.ground_fn(x, y) - 0.4, s=0.8)
town.plaza(SIX[0], SIX[1], 37.0, paved=None, ragged=0.3)          # Gartenring freihalten
# Prozessionsstraße: Säulenpaare und Statuen
cum = Town._cum(proc)
d = 40.0
while d < cum[-1] - 50:
    x, y, tx, ty = Town._at(proc, cum, d)
    if inside(x, y, 0.95) and y < SIX[1] - 28:
        for sgn in (-1, 1):
            nx_, ny_ = -ty * sgn, tx * sgn
            put("SM_Collum", x + nx_ * 4.2, y + ny_ * 4.2, s=1.0)
            if int(d) % 16 < 8:
                put("SM_StandLight", x + nx_ * 4.6, y + ny_ * 4.6 + 2.0, s=1.2)
                town.lamps.append((x + nx_ * 4.6, y + ny_ * 4.6 + 2.0, 2.9))
    d += 8.0

# --- Kloster mit Kreuzgang und Garten -----------------------------------------------------------------------------
kx, ky = KLOSTER
for sgn in (-1, 1):
    put("SM_HouseAdd2", kx + sgn * 9, ky, rot=90 * sgn, s=1.0)          # Arkaden des Kreuzgangs
    put("SM_HouseAdd2", kx, ky + sgn * 9, rot=90 + 90 * sgn, s=1.0)
put("SM_ChurchSet", kx, ky + 22, rot=180, s=1.0)
for k in range(8):
    a = k / 8 * math.tau
    put("SM_Bush07", kx + math.cos(a) * 3.5, ky + math.sin(a) * 3.5, rot=rng.uniform(0, 360), nocol=True)
put("SM_ChurchTree01", kx, ky, s=0.9)

# --- Häuser ----------------------------------------------------------------------------------------------------------
RICH = [("SM_House", 0.64, 3), ("SM_House3", 0.64, 3), ("SM_House4", 0.64, 3), ("SM_House6", 0.64, 3)]
MID = [("SM_House", 0.62, 3), ("SM_House6", 0.62, 3), ("SM_House3", 0.62, 2), ("FV_house_05", 0.76, 1),
       ("FV_house_02", 0.76, 1)]
POOR = [("FV_house_05", 0.72, 2), ("SM_HouseSet01", 1.0, 2), ("SM_StorageSet", 1.0, 1)]


def district(x, y):
    if not inside(x, y, 0.93) or math.hypot(x - SIX[0], y - SIX[1]) < 40:
        return None
    if abs(x - DOM[0]) < 46 and y > 34:
        return None
    if math.hypot(x - KLOSTER[0], y - KLOSTER[1]) < 22:
        return None
    if y > -30:
        return RICH
    return MID if inside(x, y, 0.8) else POOR


def dress(p):
    town.dress_front(p)


for line, w in [(proc, 10.0), (west, 7.0), (east, 7.0)]:
    for side in (-1, 1):
        town.frontage(line, w, side, district, on_place=dress, setback=(0.8, 1.4))
for l in lanes:
    for side in (-1, 1):
        town.frontage(l, 4.5, side, district, on_place=dress, yard_depth=(4, 10))
for side in (-1, 1):
    town.frontage(ring_in, 4.5, side, district, on_place=dress, yard_depth=(4, 8))
town.fill(lambda x, y: inside(x, y, 0.9) and math.hypot(x - SIX[0], y - SIX[1]) > 40 and not (abs(x) < 46 and y > 34),
          MID + POOR, tries=1000, on_place=dress)

# --- Pilgermarkt, Herbergen -----------------------------------------------------------------------------------------
town.market(PILGER[0], PILGER[1], r=11.0, rings=(7.0,), n=8, centerpiece=None, statue=("SM_Statue01", 1.4))
town.tavern((PILGER[0] + 12, PILGER[1] + 10))
for line, w in [(west, 7.0), (east, 7.0)]:
    town.lamps_along(line, w, every=17.0)

town.outskirts(lambda x, y: inside(x, y, 1.12),
               farms=[(-80, -128, 20), (86, -122, -15), (-134, 54, 80), (132, -62, -100), (-70, 132, 160), (80, 130, 200)],
               fields=[(-42, -132, 26, 16, 12), (46, -136, 24, 14, -8), (-132, 86, 18, 24, 6), (134, -16, 16, 22, -12),
                       (-30, 140, 28, 12, 4), (40, 142, 22, 12, -6)],
               trees=1500, keep_clear=[(SG[0], SG[1] - 30, 14)])
kit.terrain(HALF, flat_r=TERRAIN["flat_r"], hill_h=TERRAIN["hill_h"], tex="Textures_T_LandScapeLayer01_BC.png",
            normal="Textures_T_LandScapeLayer01_N.png", tile=5.0, edge_rise=TERRAIN["edge_rise"], res=500,
            inner_h=TERRAIN["inner_h"], path_tex="Texture_T_Cobblestone_BC.png", path_normal="Texture_T_Cobblestone_N.png",
            path_fn=town.path_fn, dirt_fn=town.dirt_fn, height_fn=shape)
kit.grass((-HALF + 2, -HALF + 2, HALF - 2, HALF - 2), 24000, s=(0.8, 1.5))

town.anchors(spawn=(SG[0] + 1.0, SG[1] + 10.0, 0), gate=(SG[0], SG[1] - 8.0), board=(SIX[0] + 9.0, SIX[1] - 24.0),
             keeper=(DOM[0], DOM[1] - 24, 180), slots_center=(SIX[0], SIX[1] - 14),
             lines=[(proc, 8), (west, 8), (east, 8)] + [(l, 9) for l in lanes], inside=lambda x, y: inside(x, y, 0.95))
town.save_map(os.path.splitext(dst)[0] + "_map.png")
kit.finish_materials(metal_keys=("knight", "spear", "standlight"))
kit.export()
