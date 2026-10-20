# Blender: Festungsstadt E-Rantel – Handelsstadt hinter zwei Mauerringen (town_kit: Häuserzeilen Wand an Wand)
#   blender -b -P build_erantel.py -- <ErantelKit-Ordner> <ziel.glb>
# Blender-Y = im Spiel -Z.  Südtor → Hauptstraße → Marktplatz → Tor der inneren Mauer → Zitadelle (Rathaus).
# Westen: Handwerkerviertel mit Tempelplatz; Osten: Kaufmannsviertel mit Gildenplatz (Abenteurergilde).
# Draußen: Händlerlager vor dem Südtor, Felder, Gehöfte, Waldränder.
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from loc_kit import Kit  # noqa: E402
from town_kit import Town, ROAD, PLAZA, FREE, YARD, HOUSE  # noqa: E402
from mathutils import noise, Vector  # noqa: E402

exp_dir, dst = [os.path.abspath(a) for a in sys.argv[sys.argv.index("--") + 1:][:2]]
kit = Kit(exp_dir, dst, seed=8)
kit.lod_names = {"SM_Tree02", "SM_Tree03", "SM_Tree4", "SM_Tree05", "SM_Tree06", "SM_Tree07", "SM_Tree08", "SM_Tree09",
                 "SM_Tree10", "SM_Tree13", "SM_ChurchTree01", "SM_Spruce1", "SM_TreeType1", "SM_type2Tree",
                 "FV_tree_01", "FV_tree_02"}
put, empty, rng = kit.put, kit.empty, kit.rng
HALF = 140.0
town = Town(kit, HALF)

C = (0.0, 6.0)
RX, RY = 90.0, 84.0
M = (0.0, -16.0)          # Marktplatz
T = (-46.0, 14.0)         # Tempelplatz
G = (44.0, -8.0)          # Gildenplatz
CIT = (0.0, 54.0)         # Zitadelle


def wall_r(a):
    return 1.0 + noise.noise(Vector((math.cos(a) * 1.3, math.sin(a) * 1.3, 2.2))) * 0.1


def ring_pt(deg, inset=0.0):
    a = math.radians(deg)
    r = wall_r(a)
    return C[0] + math.cos(a) * (RX * r - inset), C[1] + math.sin(a) * (RY * r - inset)


SG, WG, EG = ring_pt(-90), ring_pt(180), ring_pt(0)
IG = (0.0, 31.0)          # Tor der inneren Mauer

# --- Straßen und Plätze ----------------------------------------------------------------------------
main = kit.spline([(SG[0] + 2, SG[1] - 46), (SG[0], SG[1] - 12), SG, (3, -66), (-2, -44), M, (3, 2), (-1, 18), IG, (0, 40)])
west = kit.spline([M, (-18, -10), (-32, 2), T, (-64, 10), WG, (WG[0] - 40, WG[1] + 4)])
east = kit.spline([M, (18, -14), G, (66, -2), EG, (EG[0] + 40, EG[1] - 6)])
ring_in = kit.spline([ring_pt(a, 12) for a in range(-80, 280, 12)] + [ring_pt(-80, 12)])
lanes = [
    kit.spline([T, (-40, 32), (-24, 42)]),
    kit.spline([G, (42, 24), (24, 40)]),
    kit.spline([(-2, -44), (-26, -42), (-52, -36), (-72, -26)]),
    kit.spline([(3, -66), (28, -60), (52, -46), (70, -30)]),
    kit.spline([(-32, 2), (-38, -18), (-26, -42)]),
    kit.spline([(18, -14), (32, -32), (28, -60)]),
    kit.spline([T, (-62, 30), (-68, 48)]),
    kit.spline([G, (64, 22), (66, 46)]),
    kit.spline([(-18, -10), (-14, -30), (-2, -44)]),
    kit.spline([(-40, 32), (-58, 58)]),
    kit.spline([(42, 24), (54, 60)]),
    # Querverbindungen in den Vierteln (dichtes Gassennetz)
    kit.spline([(-52, -36), (-60, -10), (-64, 10)]),
    kit.spline([(52, -46), (60, -20), (66, -2)]),
    kit.spline([(-26, -42), (-30, -62), (-14, -72)]),
    kit.spline([(28, -60), (14, -72)]),
    kit.spline([(-62, 30), (-78, 22)]),
    kit.spline([(64, 22), (80, 14)]),
    kit.spline([(-24, 42), (-36, 58), (-30, 72)]),
    kit.spline([(24, 40), (36, 56), (30, 72)]),
    kit.spline([(-38, -18), (-56, -18)]),
    kit.spline([(32, -32), (50, -30)]),
]
cit_loop = kit.spline([(0, 36), (-16, 42), (-22, 56), (-10, 70), (10, 70), (22, 56), (16, 42), (0, 36)])
town.plaza(M[0], M[1], 16.0)
town.plaza(T[0], T[1], 10.0)
town.plaza(G[0], G[1], 9.0)
town.plaza(CIT[0], CIT[1] - 8, 11.0)
for line, w in [(main, 7.0), (west, 6.0), (east, 6.0)]:
    town.road(line, w)
town.road(ring_in, 4.5, paved=False)
for l in lanes:
    town.road(l, 4.0, paved=rng.random() < 0.6)
town.road(cit_loop, 4.0)


def inside(x, y, shrink=1.0):
    a = math.atan2(y - C[1], x - C[0])
    r = wall_r(a)
    return ((x - C[0]) / (RX * r * shrink)) ** 2 + ((y - C[1]) / (RY * r * shrink)) ** 2 < 1.0


def in_citadel(x, y):
    return ((x - CIT[0]) / 30.0) ** 2 + ((y - (CIT[1] - 2)) / 25.0) ** 2 < 1.0


# --- Gelände (flach in der Stadt, Hügel draußen) ---------------------------------------------------
def shape(x, y, h):
    return h + (0.8 if in_citadel(x, y) else 0.0)


TERRAIN = dict(half=HALF, flat_r=96.0, hill_h=10.0, edge_rise=16.0, inner_h=0.35, height_fn=shape)
kit.height_field(**TERRAIN)

# Reservierungen vor dem Häuserbau: Zitadelle, Tempel, Gilde, Kaserne am Südtor
town.reserve(CIT[0], CIT[1] + 6, 26, 18)
town.reserve(T[0] - 2, T[1] + 18, 28, 22)
town.reserve(G[0] + 2, G[1] + 14, 22, 12)
town.reserve(SG[0] + 22, SG[1] + 16, 22, 16, dirt=0.9)

# --- Stadtmauern -------------------------------------------------------------------------------------
outer = [ring_pt(a) for a in range(0, 360, 4)]
town.wall(outer, gates=[SG, WG, EG], tower_every=30.0)
inner = [(CIT[0] + math.cos(math.radians(a)) * 30, CIT[1] - 2 + math.sin(math.radians(a)) * 25) for a in range(0, 360, 6)]
town.wall(inner, gates=[IG], tower_every=26.0, height_rows=1, small_tower=("SM_TowerSmall", 0.45))
for gx, gy, deg in [(SG[0], SG[1], -90), (WG[0], WG[1], 180), (EG[0], EG[1], 0)]:
    a = math.radians(deg)
    tx, ty = -math.sin(a), math.cos(a)
    for sgn in (-1, 1):
        put("SM_TowerrType2", gx + tx * sgn * 8.5, gy + ty * sgn * 8.5, s=0.34, rot=deg + 90)
        ix, iy = gx - math.cos(a) * 4 + tx * sgn * 3.6, gy - math.sin(a) * 4 + ty * sgn * 3.6
        put("SM_Knight_posed", ix, iy, rot=deg + 90 + 180)
        put("SM_Spear_low", ix + tx * sgn * 0.5, iy + ty * sgn * 0.5)
for sgn in (-1, 1):
    put("SM_TowerrType2", IG[0] + sgn * 6.5, IG[1], s=0.26)

# --- Wahrzeichen -------------------------------------------------------------------------------------
put("SM_Build1", CIT[0], CIT[1] + 6, rot=0, s=0.62)                      # Rathaus / Zitadelle
for sgn in (-1, 1):
    put("SM_TowerrType2", CIT[0] + sgn * 13.5, CIT[1] + 8, s=0.3)
put("SM_ChurchSet", T[0] - 2, T[1] + 18, rot=0, s=1.35)                  # Tempel der Vier
put("SM_Build1", G[0] + 2, G[1] + 14, rot=0, s=0.5)                      # Abenteurergilde
for k in range(4):                                                       # Kaserne: Zelte, Waffenständer
    put("SM_Tent_low", SG[0] + 16 + k * 4.5, SG[1] + 12, rot=90, s=2.0)
put("SM_StorageSet", SG[0] + 26, SG[1] + 22, rot=180)

# --- Häuser ------------------------------------------------------------------------------------------
RICH = [("SM_House", 0.62, 3), ("SM_House3", 0.62, 3), ("SM_House4", 0.62, 2), ("SM_House6", 0.62, 3),
        ("FV_house_02", 0.78, 1), ("FV_house_05", 0.78, 1)]
MID = [("FV_house_02", 0.78, 3), ("FV_house_03", 0.78, 2), ("FV_house_05", 0.78, 3), ("SM_House", 0.62, 2),
       ("SM_House6", 0.62, 2), ("SM_House3", 0.62, 1), ("SM_HouseSet02", 1.0, 1)]
POOR = [("SM_HouseSet01", 1.0, 3), ("FV_house_05", 0.74, 2), ("SM_StorageSet", 1.0, 2), ("SM_HouseSet02", 1.0, 1),
        ("FV_house_02", 0.74, 1)]


def district(x, y):
    if not inside(x, y, 0.92):
        return None
    if in_citadel(x, y):
        return RICH[:4]
    dm = math.hypot(x - M[0], y - M[1])
    if dm < 34 or (x > 20 and y > -30):
        return RICH if dm < 30 else MID
    if x < -20:
        return POOR if y < -10 or x < -60 else MID
    return MID


def dress(p):
    town.dress_front(p)


for line, w in [(main, 7.0), (west, 6.0), (east, 6.0)]:
    for side in (-1, 1):
        town.frontage(line, w, side, district, on_place=dress)
for l in lanes:
    for side in (-1, 1):
        town.frontage(l, 4.0, side, district, on_place=dress, yard_depth=(4, 9))
for side in (-1, 1):
    town.frontage(ring_in, 4.5, side, district, on_place=dress, yard_depth=(4, 8))
    town.frontage(cit_loop, 4.0, side, lambda x, y: RICH[:4] if in_citadel(x, y) else None, on_place=dress)
town.fill(lambda x, y: inside(x, y, 0.9) and not in_citadel(x, y), POOR + MID, tries=900, on_place=dress)

# --- Marktplatz ---------------------------------------------------------------------------------------
mx, my = M
STALL = ["FV_crate_01", "FV_barrel_01", "FV_bag", "FV_bag_02", "SM_WoodenBox02", "SM_WoodenBucket02", "SM_FlowerPot02",
         "FV_crate_group_01", "FV_barrel_group_01"]
put("SM_RoundOrn", mx, my, s=0.85)
put("SM_Statue01", mx, my, s=1.1)
for i in range(16):                                       # zwei Ringe Marktstände, Gassen dazwischen
    a = i * math.tau / 16 + rng.uniform(-0.05, 0.05)
    d = 8.5 if i % 2 == 0 else 12.0
    x, y = mx + math.cos(a) * d, my + math.sin(a) * d
    if i % 5 == 4:
        put(rng.choice(["SM_WoodenWagon01", "SM_WoodenWagon02"]), x, y, rot=math.degrees(a) + 90 + rng.uniform(-25, 25))
        kit.clutter(x, y, ["FV_crate_01", "FV_barrel_01", "FV_bag", "FV_bag_02", "SM_WoodenBucket02"], n=(2, 4), r=(1.6, 2.6))
    else:
        town.stall(x, y, math.degrees(a) - 90, w=rng.uniform(2.6, 3.4), d=rng.uniform(1.6, 2.0))
for (dx, dy) in [(-8, -7), (7, 7), (-8, 7), (8, -7)]:
    put("SM_StandLight", mx + dx * 1.9, my + dy * 1.9)
    town.lamps.append((mx + dx * 1.9, my + dy * 1.9, kit.ground_fn(mx + dx * 1.9, my + dy * 1.9) + 2.6))
# Wirtshaus am Markt: Tische und Bänke davor
inn = min(town.plots, key=lambda p: math.hypot(p["x"] - (mx + 16), p["y"] - (my + 12)))
ix, iy = inn["x"] + inn["fx"] * (inn["d"] / 2 + 2.6), inn["y"] + inn["fy"] * (inn["d"] / 2 + 2.6)
for k in range(3):
    r = math.radians(inn["rot"])
    tx, ty = ix + math.cos(r) * (k - 1) * 2.6, iy + math.sin(r) * (k - 1) * 2.6
    kit.ph(rng.choice(["WoodenTable_02", "WoodenTable_03", "round_wooden_table_01"]), tx, ty, rot=inn["rot"] + rng.uniform(-8, 8))
    for sgn in (-1, 1):
        kit.ph(rng.choice(["wooden_stool_01", "wooden_stool_02", "WoodenChair_01"]),
               tx - math.sin(r) * sgn * 0.85, ty + math.cos(r) * sgn * 0.85, rot=inn["rot"] + 90 * sgn + rng.uniform(-15, 15))
    kit.ph(rng.choice(["jug_01", "brass_goblets", "wooden_bowl_01"]), tx, ty, z=kit.ground_fn(tx, ty) + 0.78, rot=rng.uniform(0, 360))
kit.ph("wine_barrel_01", ix + 3.2, iy, rot=30)
kit.ph("wooden_barrels_01", ix - 3.4, iy + 0.5, rot=-20)
# Tempelplatz und Gildenplatz
put("SM_Statue01", T[0], T[1], s=1.6)
for k in range(4):
    a = k * math.tau / 4 + 0.6
    put("SM_StandLight", T[0] + math.cos(a) * 7, T[1] + math.sin(a) * 7)
put("SM_Statue01", G[0], G[1], s=1.3)
for k in range(5):
    a = k * math.tau / 5
    x, y = G[0] + math.cos(a) * 6.5, G[1] + math.sin(a) * 6.5
    kit.clutter(x, y, STALL, n=(1, 3), r=(0.6, 1.4))

# Laternen an den Hauptstraßen
for line, w in [(main, 7.0), (west, 6.0), (east, 6.0)]:
    town.lamps_along(line, w, every=18.0)

# --- Draußen ---------------------------------------------------------------------------------------------
def outside(x, y):
    return not inside(x, y, 1.12)


for i in range(9):                                        # Händlerlager vor dem Südtor
    x, y = SG[0] + rng.choice([-1, 1]) * rng.uniform(10, 24), SG[1] - rng.uniform(10, 32)
    if town.at(x, y) == FREE:
        put("SM_Tent_low", x, y, rot=rng.uniform(0, 360), s=rng.uniform(1.6, 2.1))
        kit.clutter(x, y, ["SM_WoodenBarrel01", "SM_WoodenBox01", "SM_FireWoodSet02", "FV_bag"], n=(2, 4), r=(2.0, 3.5))
        town.mark_rect(x, y, 7, 7, 0, YARD, dirt=0.8)
        kit.occupy(x, y, 4.0)
put("SM_firestone", SG[0] - 14, SG[1] - 22)
# Gehöfte und Felder vor der Stadt
FARMS = [(-70, -100, 20), (74, -96, -15), (-112, 40, 80), (110, -40, -100), (-60, 112, 160), (70, 110, 200)]
for fx, fy, fr in FARMS:
    if town.rect_free(fx, fy, 30, 26, fr, (FREE,)):
        town.place(rng.choice(["FV_house_01", "FV_house_04"]), 0.78, fx, fy, fr)
        town.place("SM_StorageSet", 1.0, fx + math.cos(math.radians(fr)) * 16, fy + math.sin(math.radians(fr)) * 16, fr + 90)
        for p in town.plots[-2:]:
            town.yard(p, 8.0)
FIELDS = [(-36, -104, 26, 16, 12), (40, -110, 24, 14, -8), (-110, 66, 18, 24, 6), (112, -12, 16, 22, -12),
          (-26, 120, 28, 14, 4), (36, 122, 22, 14, -6), (-118, -40, 16, 22, 10)]
for (fx, fy, fw, fh, fr) in FIELDS:
    r = math.radians(fr)
    for _ in range(int(fw * fh * 0.9)):
        u, v = rng.uniform(-fw / 2, fw / 2), rng.uniform(-fh / 2, fh / 2)
        x, y = fx + u * math.cos(r) - v * math.sin(r), fy + u * math.sin(r) + v * math.cos(r)
        if town.at(x, y) == FREE:
            put(rng.choice(["SM_WheatGrass01", "SM_WheatGrass03"]), x, y, rot=rng.uniform(0, 360), nocol=True)
    town.mark_rect(fx, fy, fw, fh, fr, YARD, dirt=0.35)
    kit.occupy(fx, fy, max(fw, fh) * 0.6)
# Wald und Baumgruppen draußen, Obstbäume in der Stadt
BIG = ["SM_Tree4", "SM_Tree10", "SM_Tree02", "SM_Tree09", "SM_Tree13", "SM_Spruce1", "SM_Tree03"]
UNDER = ["SM_Bush07", "SM_Foliage_33", "SM_Foliage_56", "SM_Bush01", "SM_Foliage_22", "SM_Foliage_24"]
for _ in range(1400):
    x, y = rng.uniform(-HALF + 4, HALF - 4), rng.uniform(-HALF + 4, HALF - 4)
    if not inside(x, y, 1.25) and town.at(x, y) == FREE and noise.noise(Vector((x * 0.03, y * 0.03, 1.7))) > -0.05 \
            and math.hypot(x - main[0][0], y - main[0][1]) > 6:
        if all((x - px) ** 2 + (y - py) ** 2 > 20 for px, py, _ in kit.occupied[-60:]):
            put(rng.choice(BIG), x, y, rot=rng.uniform(0, 360), s=rng.uniform(0.9, 1.4), sink=0.2)
            kit.occupy(x, y, 2.2)
            town.mark_rect(x, y, 3, 3, 0, HOUSE)
            for _ in range(2):
                a, d = rng.uniform(0, math.tau), rng.uniform(1.0, 3.5)
                put(rng.choice(UNDER), x + math.cos(a) * d, y + math.sin(a) * d, rot=rng.uniform(0, 360),
                    s=rng.uniform(0.8, 1.3), nocol=True, sink=0.05)
for _ in range(120):
    x, y = rng.uniform(-80, 80), rng.uniform(-80, 80)
    if inside(x, y, 0.9) and town.at(x, y) == FREE and town.rect_free(x, y, 4, 4, 0, (FREE,)):
        put(rng.choice(["SM_Tree05", "SM_Tree06", "SM_Tree13", "SM_ChurchTree01"]), x, y, rot=rng.uniform(0, 360),
            s=rng.uniform(0.55, 0.85))
        town.mark_rect(x, y, 3, 3, 0, HOUSE)

# --- Gelände --------------------------------------------------------------------------------------------
kit.terrain(HALF, flat_r=TERRAIN["flat_r"], hill_h=TERRAIN["hill_h"], tex="Textures_T_LandScapeLayer01_BC.png",
            normal="Textures_T_LandScapeLayer01_N.png", tile=5.0, edge_rise=TERRAIN["edge_rise"], res=480,
            inner_h=TERRAIN["inner_h"], path_tex="Textures_T_BayStone_BC.png", path_normal="Textures_T_BayStone_N.png",
            path_fn=town.path_fn, dirt_fn=town.dirt_fn, height_fn=shape)
ALL = (-HALF + 2, -HALF + 2, HALF - 2, HALF - 2)
kit.grass(ALL, 30000, s=(0.8, 1.5))
kit.grass(ALL, 4000, kind="@flower")

# --- Anker ------------------------------------------------------------------------------------------------
empty("Spawn", SG[0] + 1.0, SG[1] + 10.0, rot=0)
empty("Gate", SG[0], SG[1] - 8.0)
empty("Board", mx + 7.0, my - 9.0)
empty("Keeper", CIT[0], CIT[1] - 6, rot=180)
for i, a in enumerate([200, 235, 270, 305, 340, 20]):
    r = math.radians(a)
    empty("Slot%d" % (i + 1), mx + math.cos(r) * 6.5, my + math.sin(r) * 6.5)
for i, (x, y, z) in enumerate(town.lamps[:60]):
    empty("Lamp_%d" % (i + 1), x, y, z)
for i, (x, y, z) in enumerate(town.smoke[:48]):
    empty("Smoke_%d" % (i + 1), x, y, z)
n = 1
for line, step in [(main, 8), (west, 8), (east, 8)] + [(l, 9) for l in lanes]:
    for k in range(0, len(line), step):
        x, y = line[k]
        if inside(x, y, 0.95):
            empty("Walk_%d" % n, x, y)
            n += 1
for i in range(12):
    a = i * math.tau / 12
    empty("Idle_%d" % (i + 1), mx + math.cos(a) * rng.uniform(4.0, 9.0), my + math.sin(a) * rng.uniform(4.0, 9.0))
print("OVERLORD häuser", len(town.plots), "walk", n - 1, "smoke", len(town.smoke), "lampen", len(town.lamps))

town.save_map(os.path.splitext(dst)[0] + "_map.png")
kit.finish_materials(metal_keys=("knight", "spear", "standlight"))
kit.export()
