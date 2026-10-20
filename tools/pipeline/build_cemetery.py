# Blender: Friedhof von E-Rantel (Kapitel 3, Nacht der Untoten) – großer ummauerter Gottesacker an der
# Stadtmauer: Torbogen mit Gittertor, Hauptallee mit Zypressen und Laternen zu Khajits großem Mausoleum
# (Abgang zum unterirdischen Tempel der Zurrernon), Familiengrüfte an den Alleen, Gräberfelder mit Kreuzen,
# Grabplatten, Obelisken und eingefassten Familiengräbern, Kapelle, Totengräberhaus, tote Bäume.
#   blender -b -P build_cemetery.py -- <WorldKit-Ordner> <ziel.glb> [ErantelKit-Ordner]
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from loc_kit import Kit  # noqa: E402
from town_kit import Town, ROAD, PLAZA, FREE, YARD, HOUSE, RESERVED  # noqa: E402
from struct_kit import Structs  # noqa: E402
from mathutils import noise, Vector  # noqa: E402

args = sys.argv[sys.argv.index("--") + 1:]
exp_dir, dst = [os.path.abspath(a) for a in args[:2]]
extra = os.path.abspath(args[2]) if len(args) > 2 else os.path.join(os.path.dirname(exp_dir), "ErantelKit")
kit = Kit(exp_dir, dst, seed=66, extra_dirs=[extra])
kit.lod_names = {"SM_Tree05", "SM_Tree06", "SM_Tree13", "SM_Spruce1", "SM_Tree02", "SM_Tree09", "SM_ChurchTree01"}
put, empty, rng = kit.put, kit.empty, kit.rng
HALF = 125.0
town = Town(kit, HALF)
sk = Structs(kit, town)

X0, X1, Y0, Y1 = -58.0, 58.0, -46.0, 64.0          # Friedhofsmauer
KH = (0.0, 50.0)                                    # Khajits Mausoleum
CROSS_Y = 8.0


def shape(x, y, h):
    return h


TERRAIN = dict(half=HALF, flat_r=70.0, hill_h=6.0, edge_rise=10.0, inner_h=0.35, height_fn=shape)
kit.height_field(**TERRAIN)


def inside(x, y, m=0.0):
    return X0 + m < x < X1 - m and Y0 + m < y < Y1 - m


# --- Wege -----------------------------------------------------------------------------------------------------
main = kit.spline([(0, -110), (0, -60), (0, Y0), (0, KH[1] - 10)])
cross = kit.spline([(X0 + 2, CROSS_Y), (X1 - 2, CROSS_Y)])
ring = kit.spline([(X0 + 4, Y0 + 4), (X1 - 4, Y0 + 4), (X1 - 4, Y1 - 4), (X0 + 4, Y1 - 4), (X0 + 4, Y0 + 4)])
sides = [kit.spline([(x, Y0 + 4), (x, Y1 - 4)]) for x in (-30.0, 30.0)] + \
        [kit.spline([(X0 + 4, y), (X1 - 4, y)]) for y in (-20.0, 36.0)]
town.road(main, 5.0, paved=False)
town.road(cross, 4.0, paved=False)
town.road(ring, 3.0, paved=False)
for l in sides:
    town.road(l, 2.6, paved=False)
town.plaza(0.0, CROSS_Y, 7.0, paved=False)
town.plaza(KH[0], KH[1] - 13, 9.0, paved=False)

# --- Friedhofsmauer, Tor ----------------------------------------------------------------------------------------
sk.plain_wall([(X0, Y0), (X1, Y0), (X1, Y1), (X0, Y1)], height=3.3, T=0.75, gaps=[(0.0, Y0)], gap_w=5.0, closed=True)
sk.gate_pillars(0.0, Y0, 0.0, width=4.4, h=4.2)
put("SM_StandLight", -4.2, Y0 - 1.6)
put("SM_StandLight", 4.2, Y0 - 1.6)
town.lamps += [(-4.2, Y0 - 1.6, kit.ground_fn(-4.2, Y0 - 1.6) + 2.5), (4.2, Y0 - 1.6, kit.ground_fn(4.2, Y0 - 1.6) + 2.5)]

# --- Khajits Mausoleum ---------------------------------------------------------------------------------------------
kh = sk.mausoleum(KH[0], KH[1], 0.0, w=12.0, d=13.0, h=6.2, style="grand", mat="MI_MausoleumDark", steps=4)
for sx in (-1, 1):
    put("SM_Statue01", sx * 5.6, KH[1] - 12.5, rot=0, s=1.5)
    put("SM_smallbraizer02", sx * 3.2, KH[1] - 10.4, z=kh["z"] + 0.35 + 0.22 * 4)
town.reserve(KH[0], KH[1] - 2, 18, 22)

# --- Familiengrüfte entlang der Alleen ------------------------------------------------------------------------------
STY = ["gable", "gable", "dome", "pyramid", "gable"]
MAT = ["MI_Mausoleum", "MI_MausoleumDark", "MI_Mausoleum", "MI_GraveStone"]
crypts = []
for y in (-34.0, -24.0, 22.0, 30.0):                     # an der Hauptallee, Front zur Allee
    for sx in (-1, 1):
        w, d = rng.uniform(4.0, 5.2), rng.uniform(4.6, 6.0)
        c = sk.mausoleum(sx * (2.5 + d / 2 + 1.6), y, -90 * sx, w=w, d=d, h=rng.uniform(3.4, 4.4), style=rng.choice(STY),
                         mat=rng.choice(MAT), portico=rng.random() < 0.25)
        crypts.append(c)
for x in (-46.0, -40.0, -17.0, 17.0, 40.0, 46.0):        # an der Querallee
    if abs(x) < 10:
        continue
    for sy in (-1, 1):
        if rng.random() < 0.35:
            continue
        w, d = rng.uniform(3.8, 4.8), rng.uniform(4.2, 5.4)
        yy = CROSS_Y + sy * (2.0 + d / 2 + 1.5)
        if town.rect_free(x, yy, w + 2, d + 2, 0, (FREE, YARD)):
            crypts.append(sk.mausoleum(x, yy, 180 if sy > 0 else 0, w=w, d=d, h=rng.uniform(3.2, 4.2), style=rng.choice(STY),
                                       mat=rng.choice(MAT)))
for (x, y, r) in [(-50, 54, 180), (-38, 56, 180), (38, 56, 180), (50, 54, 180), (-52, -38, 0), (52, -38, 0)]:
    if town.rect_free(x, y, 7, 8, r, (FREE, YARD)):
        crypts.append(sk.mausoleum(x, y, r, w=5.0, d=5.6, h=4.0, style=rng.choice(STY), mat=rng.choice(MAT), portico=True))
for c in crypts:
    town.lamps.append((c["door"][0], c["door"][1], c["door"][2] + 2.2)) if rng.random() < 0.35 else None

# --- Kapelle, Totengräberhaus ------------------------------------------------------------------------------------------
put("SM_ChurchSet", 40.0, -32.0, rot=-90, s=1.0)
town.reserve(40.0, -32.0, 18, 22)
town.place("SM_HouseSet01", 1.0, -40.0, -34.0, 90)
town.yard(town.plots[-1], 6.0)
for k in range(3):
    kit.ph(rng.choice(["rusted_spade_01", "wooden_broom", "wicker_basket_01", "wooden_bucket_01"]), -34.0 + k * 0.9, -30.5 + k * 0.4,
           rot=rng.uniform(0, 360))

# --- Gräberfelder ---------------------------------------------------------------------------------------------------------
KIT_STONES = ["SM_tombStone01", "SM_tombstone02"]
n_graves = 0
for qx0, qx1 in ((X0 + 7, -6.0), (6.0, X1 - 7)):
    for qy0, qy1 in ((Y0 + 7, CROSS_Y - 4), (CROSS_Y + 4, Y1 - 7)):
        y = qy0
        while y < qy1:
            x = qx0 + rng.uniform(0, 1.2)
            row_style = rng.random()
            while x < qx1:
                if town.at(x, y) != FREE or not town.rect_free(x, y, 1.5, 2.6, 0, (FREE,)):
                    x += 1.6
                    continue
                r = rng.random()
                tilt = rng.uniform(-12, 12) if rng.random() < 0.18 else rng.uniform(-3, 3)
                if r < 0.04:
                    sk.plot(x + 1.2, y + 0.4, 0.0)
                    x += 4.4
                    continue
                if r < 0.1:
                    sk.obelisk(x, y, h=rng.uniform(2.2, 3.6))
                elif r < 0.42 if row_style < 0.5 else r < 0.25:
                    sk.cross(x, y + 0.9, rng.uniform(-4, 4), h=rng.uniform(1.0, 1.5), tilt=tilt)
                elif r < 0.62:
                    sk.slab(x, y, rng.uniform(-3, 3))
                else:
                    put(rng.choice(KIT_STONES), x, y + 0.9, rot=180 + rng.uniform(-8, 8), s=rng.uniform(0.85, 1.15),
                        sink=rng.uniform(0.0, 0.25), rx=tilt)
                    town.mark_rect(x, y, 1.2, 2.2, 0, HOUSE)
                n_graves += 1
                x += rng.uniform(2.0, 2.8)
            y += rng.uniform(3.4, 4.0)
print("OVERLORD gräber", n_graves)

# --- Bäume: Zypressen an der Hauptallee, tote Bäume, Laternen -------------------------------------------------------------
for y in range(int(Y0) + 8, int(KH[1]) - 16, 7):
    for sx in (-1, 1):
        if town.at(sx * 4.2, y) in (FREE, YARD, ROAD):
            put("SM_Spruce1", sx * 4.2, y, rot=rng.uniform(0, 360), s=0.42, sz=0.62)
for k in range(10, len(main) - 4, 9):
    x, y = main[k]
    if Y0 < y < KH[1] - 14:
        put("SM_StandLight", x + 3.0, y + 1.5)
        town.lamps.append((x + 3.0, y + 1.5, kit.ground_fn(x, y) + 2.5))
for l in [cross] + sides:
    town.lamps_along(l, 2.6, every=22.0)
for _ in range(60):
    x, y = rng.uniform(X0 + 5, X1 - 5), rng.uniform(Y0 + 5, Y1 - 5)
    if town.at(x, y) == FREE and town.rect_free(x, y, 3, 3, 0, (FREE,)):
        if rng.random() < 0.5:
            kit.ph(rng.choice(["dead_tree_trunk_02", "tree_stump_01", "dead_tree_trunk"]), x, y, rot=rng.uniform(0, 360))
        else:
            put(rng.choice(["SM_Tree05", "SM_Tree13", "SM_Tree06"]), x, y, rot=rng.uniform(0, 360), s=rng.uniform(0.55, 0.85))
        town.mark_rect(x, y, 2.5, 2.5, 0, HOUSE)

# --- Draußen: Stadtmauer im Westen, Häuser im Süden ---------------------------------------------------------------------------
cw = [(-92.0, -HALF + 2), (-86.0, -40.0), (-88.0, 30.0), (-80.0, 90.0), (-40.0, 104.0), (30.0, 108.0), (HALF - 2, 100.0)]
town.great_wall(kit.spline(cw, step=6.0), height=13.0, T=5.0, gaps=[], stairs_every=999.0, outer_side=1)
for (x, y) in [(-86.0, -40.0), (-88.0, 30.0), (-80.0, 90.0), (-40.0, 104.0), (30.0, 108.0)]:
    put("SM_TowerrType2", x, y, s=0.36)
road_s = kit.spline([(0, -60), (-24, -66), (-56, -70)])
town.road(road_s, 4.0, paved=True)
OUT = [("FV_house_05", 0.76, 2), ("SM_HouseSet01", 1.0, 2), ("FV_house_02", 0.76, 1), ("SM_House6", 0.62, 1)]
for side in (-1, 1):
    town.frontage(main, 5.0, side, lambda x, y: OUT if y < Y0 - 10 and y > -100 else None,
                  on_place=lambda p: town.dress_front(p), yard_depth=(4, 8))
    town.frontage(road_s, 4.0, side, lambda x, y: OUT if not inside(x, y, -6) else None,
                  on_place=lambda p: town.dress_front(p), yard_depth=(4, 8))

# --- Gelände, Bewuchs --------------------------------------------------------------------------------------------------------
sk.flush("SM_Friedhof")
kit.terrain(HALF, flat_r=TERRAIN["flat_r"], hill_h=TERRAIN["hill_h"], tex="Textures_T_LandScapeLayer02_BC.png",
            normal="Textures_T_LandScapeLayer02_N.png", tile=5.0, edge_rise=TERRAIN["edge_rise"], res=420,
            inner_h=TERRAIN["inner_h"], path_tex="Texture_T_Cobblestone_BC.png", path_normal="Texture_T_Cobblestone_N.png",
            path_fn=town.path_fn, dirt_fn=town.dirt_fn, height_fn=shape)
ALL = (-HALF + 2, -HALF + 2, HALF - 2, HALF - 2)
kit.grass(ALL, 18000, s=(0.7, 1.4))
kit.meadow(ALL, ["SM_Foliage_81", "SM_Foliage_82", "SM_Foliage_90", "SM_Foliage_91", "SM_Foliage_99", "SM_Bush07"], 1400, s=(0.8, 1.3))

# --- Anker -------------------------------------------------------------------------------------------------------------------
empty("Spawn", 0.0, Y0 - 9.0, rot=0)
empty("Gate", 0.0, Y0 - 15.0)
empty("Board", 5.5, Y0 - 6.0)
empty("Keeper", KH[0], KH[1] - 10.0, kh["z"] + 0.35 + 0.22 * 4, rot=180)
for i, a in enumerate([200, 235, 270, 305, 340, 20]):
    r = math.radians(a)
    empty("Slot%d" % (i + 1), math.cos(r) * 5.0, CROSS_Y + math.sin(r) * 4.0)
for i, (x, y, z) in enumerate(town.lamps[:48]):
    empty("Lamp_%d" % (i + 1), x, y, z)
for i, sx in enumerate((-1, 1)):
    empty("Fire_%d" % (i + 1), sx * 3.2, KH[1] - 10.4, kh["z"] + 2.6)
    empty("Violet_%d" % (i + 1), sx * 2.0, KH[1] - 8.0, kh["z"] + 3.6)
n = 1
for line, step in [(main, 7), (cross, 7)] + [(l, 8) for l in sides]:
    for k in range(0, len(line), step):
        x, y = line[k]
        if inside(x, y, 3):
            empty("Walk_%d" % n, x, y)
            n += 1
town.save_map(os.path.splitext(dst)[0] + "_map.png")
kit.finish_materials(metal_keys=("standlight", "braizer"))
kit.export()
