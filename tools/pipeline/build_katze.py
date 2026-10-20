# Blender: Katze-Ebene – verfluchtes Schlachtfeld im ewigen Nebel zwischen Re-Estize und dem Kaiserreich (town_kit).
# Südwesten: Feldlager des Königreichs hinter einer Palisade mit Wachtürmen (Zeltgassen, Feldherrenzelt, Feuerstellen,
# Trosswagen); Nordosten: das Lager des Kaiserreichs; dazwischen die Ebene mit Gräben, Kratern, Knochenfeldern,
# steckenden Speeren und verbrannten Wagen; im Norden die zerschossene Grenzfestung (Bresche, Trümmer).
#   blender -b -P build_katze.py -- <WorldKit-Ordner> <ziel.glb> [ErantelKit-Ordner]
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from loc_kit import Kit  # noqa: E402
from town_kit import Town, ROAD, PLAZA, FREE, YARD, HOUSE, RESERVED  # noqa: E402
from mathutils import noise, Vector  # noqa: E402

args = sys.argv[sys.argv.index("--") + 1:]
exp_dir, dst = [os.path.abspath(a) for a in args[:2]]
extra = os.path.abspath(args[2]) if len(args) > 2 else os.path.join(os.path.dirname(exp_dir), "ErantelKit")
kit = Kit(exp_dir, dst, seed=27, extra_dirs=[extra])
kit.lod_names = {"SM_Tree05", "SM_Tree06", "SM_Tree13"}
put, empty, rng = kit.put, kit.empty, kit.rng
HALF = 130.0
town = Town(kit, HALF)
CAMP = (-34.0, -40.0)       # Königreich
EMP = (46.0, 30.0)          # Kaiserreich
FORT = (-6.0, 78.0)         # Grenzfestung (Ruine)


def smooth(a, b, v):
    t = max(0.0, min(1.0, (v - a) / (b - a)))
    return t * t * (3 - 2 * t)


CRATERS = [(rng.uniform(-70, 70), rng.uniform(-30, 55), rng.uniform(2.5, 5.5)) for _ in range(26)]


def shape(x, y, h):
    for (cx_, cy_, r) in CRATERS:                       # Einschlagkrater (Magie, Belagerungsgeschütze)
        d = math.hypot(x - cx_, y - cy_)
        if d < r * 1.4:
            h += -0.9 * (1.0 - smooth(0.0, r, d)) + 0.25 * (smooth(r * 0.7, r, d) - smooth(r, r * 1.4, d))
    return h


TERRAIN = dict(half=HALF, flat_r=82.0, hill_h=8.0, edge_rise=18.0, inner_h=0.7, height_fn=shape)
kit.height_field(**TERRAIN)

# --- Straßen, Gräben -------------------------------------------------------------------------------------------------
road = kit.spline([(-6, -HALF + 2), (-10, -86), CAMP, (-12, -10), (4, 30), (FORT[0], FORT[1] - 18)])
emp_road = kit.spline([(HALF - 2, 50), (90, 40), EMP, (20, 12), (4, 30)])
town.road(road, 4.5, paved=False)
town.road(emp_road, 4.0, paved=False)
for (ax, ay, bx, by) in [(-60, 8, 30, -8), (-20, 34, 60, 16), (-72, 40, -30, 50)]:      # Schützengräben (Erdwälle)
    line = kit.spline([(ax, ay), ((ax + bx) / 2 + rng.uniform(-6, 6), (ay + by) / 2 + rng.uniform(-6, 6)), (bx, by)])
    town.road(line, 2.2, paved=False, occ=YARD)
    cum = Town._cum(line)
    d = 1.0
    while d < cum[-1]:
        x, y, tx, ty = Town._at(line, cum, d)
        nx, ny = -ty, tx
        put("SM_Fence02", x + nx * 1.6, y + ny * 1.6, rot=math.degrees(math.atan2(ty, tx)) + rng.uniform(-8, 8),
            rx=rng.uniform(-20, 20), sink=0.3)
        d += rng.uniform(2.2, 4.0)
for (cx_, cy_, r) in CRATERS:
    town.plaza(cx_, cy_, r * 0.9, paved=False, ragged=0.8)

# --- Feldlager des Königreichs -------------------------------------------------------------------------------------------
cx, cy = CAMP
PAL = [(cx + math.cos(a) * 30 * (1 + 0.06 * math.sin(a * 3)), cy + math.sin(a) * 24 * (1 + 0.06 * math.cos(a * 2)))
       for a in [k / 64 * math.tau for k in range(64)]]
gates = []
for (ax, ay), (bx, by) in zip(road[:-1], road[1:]):
    for (px, py), (qx, qy) in zip(PAL, PAL[1:] + PAL[:1]):
        # Schnittpunkt Straße × Palisade
        d1x, d1y, d2x, d2y = bx - ax, by - ay, qx - px, qy - py
        den = d1x * d2y - d1y * d2x
        if abs(den) < 1e-9:
            continue
        t = ((px - ax) * d2y - (py - ay) * d2x) / den
        u = ((px - ax) * d1y - (py - ay) * d1x) / den
        if 0 <= t <= 1 and 0 <= u <= 1:
            g = (ax + t * d1x, ay + t * d1y)
            if all(math.hypot(g[0] - q[0], g[1] - q[1]) > 8 for q in gates):
                gates.append(g)
towers = [(cx + math.cos(a) * 27, cy + math.sin(a) * 21) for a in [math.radians(d) for d in (45, 135, 225, 315)]]
town.palisade(PAL, gates=gates, gate_w=6.0, height=4.2, towers=towers, tower_h=7.5)
# Zeltgassen
for row in range(-2, 3):
    for col in range(-3, 4):
        x, y = cx + col * 6.2 + rng.uniform(-0.4, 0.4), cy + row * 7.0 + rng.uniform(-0.4, 0.4)
        if town.at(x, y) != FREE or abs(col) < 1 and abs(row) < 1:
            continue
        put("SM_Tent_low", x, y, rot=90 + rng.choice([0, 180]) + rng.uniform(-5, 5), s=2.5)
        town.mark_rect(x, y, 4, 5, 0, HOUSE)
        if rng.random() < 0.5:
            kit.ph(rng.choice(["wooden_crate_01", "wine_barrel_01", "wicker_basket_01", "wooden_bucket_01"]), x + 2.4, y + 1.0,
                   rot=rng.uniform(0, 360))
# Feldherrenzelt (groß) mit Bannern, Kartentisch
put("SM_Tent_low", cx, cy, rot=90, s=4.2)
town.mark_rect(cx, cy, 7, 9, 0, HOUSE)
kit.ph("WoodenTable_01", cx + 5.5, cy - 1.5, rot=10)
for k in range(4):
    x, y = cx - 6 + k * 4, cy - 6.5
    put("SM_Spear_low", x, y, z=kit.ground_fn(x, y) - 0.1, s=2.6)
    put("SM_Cloth01", x + 0.35, y, z=kit.ground_fn(x, y) + 3.6, rot=90, s=3.5, nocol=True)
for (x, y) in [(cx - 14, cy - 10), (cx + 14, cy + 10), (cx - 14, cy + 10), (cx + 14, cy - 10)]:
    kit.ph("stone_fire_pit", x, y, rot=rng.uniform(0, 360))
    town.lamps.append((x, y, kit.ground_fn(x, y) + 0.8))
    for k in range(3):
        a = rng.uniform(0, math.tau)
        kit.ph(rng.choice(["wooden_stool_01", "wooden_stool_02", "wooden_crate_02"]), x + math.cos(a) * 1.7, y + math.sin(a) * 1.7,
               rot=rng.uniform(0, 360))
for k in range(5):                                       # Trosswagen und Vorräte
    x, y = cx + 20 + rng.uniform(-3, 3), cy - 12 + k * 5.5
    if town.at(x, y) == FREE:
        put(rng.choice(["SM_WoodenWagon01", "SM_WoodenWagon02"]), x, y, rot=rng.uniform(80, 100), s=1.15)
        kit.ph(rng.choice(["wooden_barrels_01", "wooden_crate_01", "wine_barrel_01"]), x - 2.5, y + 1.2, rot=rng.uniform(0, 360))

# --- Lager des Kaiserreichs ------------------------------------------------------------------------------------------------
ex, ey = EMP
EPAL = [(ex + math.cos(a) * 20, ey + math.sin(a) * 17) for a in [k / 48 * math.tau for k in range(48)]]
egates = []
for (ax, ay), (bx, by) in zip(emp_road[:-1], emp_road[1:]):
    for (px, py), (qx, qy) in zip(EPAL, EPAL[1:] + EPAL[:1]):
        d1x, d1y, d2x, d2y = bx - ax, by - ay, qx - px, qy - py
        den = d1x * d2y - d1y * d2x
        if abs(den) < 1e-9:
            continue
        t = ((px - ax) * d2y - (py - ay) * d2x) / den
        u = ((px - ax) * d1y - (py - ay) * d1x) / den
        if 0 <= t <= 1 and 0 <= u <= 1:
            g = (ax + t * d1x, ay + t * d1y)
            if all(math.hypot(g[0] - q[0], g[1] - q[1]) > 8 for q in egates):
                egates.append(g)
town.palisade(EPAL, gates=egates, gate_w=5.5, height=4.0,
              towers=[(ex + math.cos(a) * 17.5, ey + math.sin(a) * 14.5) for a in [math.radians(d) for d in (60, 240)]], tower_h=7.0)
for row in range(-1, 2):
    for col in range(-2, 3):
        x, y = ex + col * 6.0, ey + row * 7.0
        if town.at(x, y) == FREE and not (col == 0 and row == 0):
            put("SM_Tent_low", x, y, rot=rng.choice([0, 180]), s=2.4)
            town.mark_rect(x, y, 4, 5, 0, HOUSE)
put("SM_Tent_low", ex, ey, rot=0, s=3.8)
kit.ph("stone_fire_pit", ex + 7, ey - 9)

# --- Die Ebene: Knochen, Speere, verbrannte Wagen, tote Bäume ----------------------------------------------------------------
BONES = ["SM_Skeleton_01", "SM_Skeleton_02", "SM_Skeleton_03", "SM_Skeleton_04", "SM_Skeleton_05", "SM_Skeleton_06",
         "SM_Skeleton_07", "SM_Skeleton_08"]
for _ in range(110):
    x, y = rng.uniform(-80, 80), rng.uniform(-20, 62)
    if town.at(x, y) not in (FREE, PLAZA) or not kit.free(x, y, 2.5):
        continue
    put(rng.choice(BONES), x, y, rot=rng.uniform(0, 360), s=rng.uniform(0.35, 0.6), sink=0.15)
    for _s in range(rng.randint(1, 4)):
        put("SM_Spear_low", x + rng.uniform(-3, 3), y + rng.uniform(-3, 3), rot=rng.uniform(0, 360),
            rx=rng.uniform(-35, 35), s=rng.uniform(1.5, 2.4), sink=0.6)
    kit.occupy(x, y, 2.2)
for _ in range(14):                                     # gefallene Ritter
    x, y = rng.uniform(-60, 60), rng.uniform(-10, 55)
    if kit.free(x, y, 2) and town.at(x, y) in (FREE, PLAZA):
        put("SM_Knight_posed", x, y, rot=rng.uniform(0, 360), rx=rng.choice([0, 85, 85]), sink=0.3)
for _ in range(10):                                     # umgestürzte, zerbrochene Wagen
    x, y = rng.uniform(-60, 60), rng.uniform(-15, 55)
    if kit.free(x, y, 3) and town.at(x, y) in (FREE, PLAZA):
        put("SM_WoodenWagon02", x, y, rot=rng.uniform(0, 360), rx=rng.uniform(-35, 35), sink=0.3)
        kit.ph(rng.choice(["wooden_crate_02", "barrel_03"]), x + rng.uniform(-3, 3), y + rng.uniform(-3, 3), rot=rng.uniform(0, 360))
for _ in range(40):
    x, y = rng.uniform(-HALF + 8, HALF - 8), rng.uniform(-HALF + 8, HALF - 8)
    if town.at(x, y) == FREE and kit.free(x, y, 3):
        kit.ph(rng.choice(["dead_tree_trunk", "dead_tree_trunk_02", "tree_stump_01", "tree_stump_02"]), x, y, rot=rng.uniform(0, 360))
        kit.occupy(x, y, 2.0)

# --- Ruine der Grenzfestung -------------------------------------------------------------------------------------------------
fx, fy = FORT
ring = [(fx + math.cos(a) * 24, fy + math.sin(a) * 18) for a in [k / 40 * math.tau for k in range(40)]]
breaches = [ring[30], ring[8], ring[19]]                 # Tor im Süden, zwei Breschen
town.great_wall(ring + [ring[0]], height=9.0, T=4.0, gaps=breaches, gap_w=9.0, stairs_every=999.0, outer_side=-1,
                name="SM_FortRuin")
for (bx, by) in breaches[1:]:                            # Trümmerhalden in den Breschen
    for _ in range(9):
        kit.ph(rng.choice(["rock_moss_set_02", "boulder_01", "namaqualand_boulder_05", "stone_01"]), bx + rng.uniform(-4, 4),
               by + rng.uniform(-4, 4), rot=rng.uniform(0, 360), s=rng.uniform(0.6, 1.6))
put("SM_TowerSmall", fx - 22, fy + 8, s=0.62, sink=0.5)
put("SM_TowerSmall", fx + 21, fy + 6, rx=9, s=0.55, sink=3.0)            # eingestürzt, schief
put("SM_CastleSep3", fx, fy + 6, s=0.7, sink=3.5)
town.plaza(fx, fy, 16.0, paved=False, ragged=1.5)

# --- Gelände, Bewuchs ---------------------------------------------------------------------------------------------------------
kit.terrain(HALF, flat_r=TERRAIN["flat_r"], hill_h=TERRAIN["hill_h"], tex="Textures_T_LandScapeLayer02_BC.png",
            normal="Textures_T_LandScapeLayer02_N.png", tile=6.0, edge_rise=TERRAIN["edge_rise"], res=420,
            inner_h=TERRAIN["inner_h"], path_tex="Textures_T_LandScapeLayer04_BC.png", path_normal="Textures_T_LandScapeLayer04_N.png",
            path_fn=town.path_fn, dirt_fn=town.dirt_fn, height_fn=shape)
ALL = (-HALF + 2, -HALF + 2, HALF - 2, HALF - 2)
kit.grass(ALL, 12000, s=(0.6, 1.2))
kit.meadow(ALL, ["SM_Foliage_33", "SM_Foliage_81", "SM_WheatGrass03"], 1400, s=(0.7, 1.1))

# --- Anker -----------------------------------------------------------------------------------------------------------------------
empty("Spawn", road[0][0] + 2, -96.0, rot=0)
empty("Gate", road[0][0] + 2, -104.0)
empty("Board", road[0][0] + 7, -90.0)
empty("Keeper", fx, fy - 22, rot=180)
for i, a in enumerate([200, 235, 270, 305, 340, 20]):
    r = math.radians(a)
    empty("Slot%d" % (i + 1), cx + math.cos(r) * 8, cy + 14 + math.sin(r) * 5)
for i, (x, y, z) in enumerate(town.lamps):
    empty("Fire_%d" % (i + 1), x, y, z)
for i in range(6):
    a = i / 6 * math.tau
    empty("Violet_%d" % (i + 1), math.cos(a) * 35, 22 + math.sin(a) * 26, 2.0)
town.save_map(os.path.splitext(dst)[0] + "_map.png")
kit.finish_materials(metal_keys=("spear", "standlight", "knight"))
kit.export()
