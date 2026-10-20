# Blender: Heiliges Königreich Roble – die Große Mauer gegen die Abelion-Hügel (town_kit).
#   blender -b -P build_roble.py -- <WorldKit-Ordner> <ziel.glb> [ErantelKit-Ordner]   (FCKit daneben)
# Blender-Y = im Spiel -Z.  Der Spieler kommt aus dem Süden (Abelion-Hügel: Felsen, verbrannte Lager der
# Halbmenschen, Gebeine) auf die 16 m hohe Mauer zu, die quer durchs Land läuft; Wehrtürme, das Torhaus mit
# zwei Türmen. Dahinter im Norden die Garnisonsstadt (Kasernen, Lagerhäuser, Kapelle, Bergfried, Übungsplatz)
# und das Feldlager der Verteidiger.
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
kit = Kit(exp_dir, dst, seed=51, extra_dirs=[extra, os.path.join(os.path.dirname(exp_dir), "FCKit")])
kit.lod_names = {"SM_Tree02", "SM_Tree10", "SM_Tree09", "SM_Tree4", "SM_Tree13", "SM_Spruce1", "SM_ChurchTree01",
                 "SM_Tree05", "SM_Tree06", "MW_tree_02", "FV_tree_01"}
put, rng = kit.put, kit.rng
HALF = 150.0
town = Town(kit, HALF)


def wall_y(x):
    """Mauerlinie: leicht geschwungen, folgt den Hügeln."""
    return 26.0 + 7.0 * math.sin(x * 0.018 + 0.6) + 3.0 * math.sin(x * 0.051)


def smooth(a, b, v):
    t = max(0.0, min(1.0, (v - a) / (b - a)))
    return t * t * (3 - 2 * t)


def shape(x, y, h):
    # Süden (Abelion): rauer und hügeliger; Norden: sanftes Ackerland; an den Kartenrändern Berge
    south = smooth(10.0, -30.0, y - wall_y(x))
    n = noise.noise(Vector((x * 0.02, y * 0.02, 7.7)))
    h += south * (4.5 * n + 0.8 * noise.noise(Vector((x * 0.045, y * 0.045, 2.2))))
    return h


TERRAIN = dict(half=HALF, flat_r=100.0, hill_h=12.0, edge_rise=26.0, inner_h=0.5, height_fn=shape)
kit.height_field(**TERRAIN)

GATE = (0.0, wall_y(0.0))
TOWN_C = (0.0, 68.0)
CAMP = (54.0, 66.0)

# --- Straßen ---------------------------------------------------------------------------------------------------------
road_s = kit.spline([(4, -HALF + 2), (-8, -90), (6, -50), (-3, -20), (GATE[0], GATE[1] - 12), GATE])
road_n = kit.spline([GATE, (0, GATE[1] + 14), (2, 46), TOWN_C, (-2, 90), (4, 120), (0, HALF - 2)])
wall_rd = kit.spline([(-130, wall_y(-130) + 14), (-60, wall_y(-60) + 14), (0, GATE[1] + 14), (60, wall_y(60) + 14),
                      (130, wall_y(130) + 14)])
lanes = [kit.spline(p) for p in [
    [(2, 46), (-24, 50), (-46, 58)], [(2, 46), (26, 48), (CAMP[0] - 12, CAMP[1] - 4)],
    [TOWN_C, (-26, 74), (-48, 84)], [TOWN_C, (24, 76), (44, 86)], [(-2, 90), (-30, 100)], [(-2, 90), (26, 102)],
]]
town.road(road_s, 5.0, paved=False)
town.road(road_n, 6.0, paved=True)
town.road(wall_rd, 4.0, paved=False)
for l in lanes:
    town.road(l, 4.0, paved=False)
town.plaza(TOWN_C[0], TOWN_C[1], 12.0)
town.plaza(GATE[0], GATE[1] + 16, 9.0, paved=False)            # Aufmarschplatz hinter dem Tor

# --- Die Große Mauer ---------------------------------------------------------------------------------------------------
line = [(x, wall_y(x)) for x in range(-int(HALF) - 10, int(HALF) + 11, 6)]
town.great_wall(line, height=16.0, T=6.0, gaps=[GATE], gap_w=12.0, stairs_every=60.0, outer_side=-1)
# Wehrtürme in festen Abständen, Torhaus
for x in range(-140, 141, 35):
    if abs(x) < 20:
        continue
    y = wall_y(x)
    put("SM_TowerrType2", x, y, s=0.4, rot=math.degrees(math.atan2(wall_y(x + 1) - y, 1.0)))
for sx in (-1, 1):
    put("SM_TowerT3Uvd", GATE[0] + sx * 9.5, GATE[1], s=0.62)
    put("SM_StandLight", GATE[0] + sx * 5.0, GATE[1] - 9, s=1.4)
    town.lamps.append((GATE[0] + sx * 5.0, GATE[1] - 9, kit.ground_fn(GATE[0] + sx * 5.0, GATE[1] - 9) + 3.3))
    put("SM_Knight_posed", GATE[0] + sx * 3.4, GATE[1] - 6, rot=180)
    put("SM_Spear_low", GATE[0] + sx * 3.9, GATE[1] - 6)
put("SM_TempleDoor", GATE[0], GATE[1] + 1.5, rot=90, s=2.5)
town.reserve(GATE[0], GATE[1], 30, 14)

# --- Garnisonsstadt -------------------------------------------------------------------------------------------------------
put("SM_CastleSep4", -22.0, 98.0, s=0.5)                                   # Bergfried der Festung
town.reserve(-22.0, 98.0, 16, 16)
put("SM_ChurchSet", 22.0, 64.0, rot=-90, s=1.1)                            # Kapelle
town.reserve(22.0, 64.0, 22, 26)
for k in range(4):                                                         # Kasernen und Zeughäuser am Aufmarschplatz
    for sx in (-1, 1):
        x, y = sx * (16 + k * 13), GATE[1] + 26
        if town.rect_free(x, y, 11, 8, 0, (FREE, YARD)):
            town.place("SM_StorageSet", 1.0, x, y, 180 if sx < 0 else 180)
MIL = [("SM_HouseSet01", 1.0, 3), ("FV_house_05", 0.76, 2), ("FV_house_02", 0.76, 2), ("SM_StorageSet", 1.0, 2),
       ("SM_House6", 0.62, 1), ("SM_House", 0.62, 1)]


def district(x, y):
    if y < wall_y(x) + 22 or y > 128 or abs(x) > 70:
        return None
    if math.hypot(x - CAMP[0], y - CAMP[1]) < 24:
        return None
    return MIL


def dress(p):
    town.dress_front(p, props=("SM_WoodenBarrel01", "SM_WoodenBox01", "SM_WoodenBucket02", "FV_crate_01", "FV_barrel_01",
                               "SM_FireWoodSet01"))


for line_, w in [(road_n, 6.0)] + [(l, 4.0) for l in lanes]:
    for side in (-1, 1):
        town.frontage(line_, w, side, district, on_place=dress, yard_depth=(5, 10))
town.fill(lambda x, y: district(x, y) is not None, MIL, tries=500, on_place=dress)
# Übungsplatz: Waffenständer, Fässer, Feuerstelle
ty_ = TOWN_C[1] + 4
town.plaza(-33, ty_ + 17, 9.0, paved=False)
for k in range(5):
    put("SM_Spear_low", -40 + k * 1.2, ty_ + 12)
for k in range(4):
    kit.ph(rng.choice(["wooden_barrels_01", "wooden_crate_01", "wine_barrel_01"]), -26 + k * 1.8, ty_ + 24, rot=rng.uniform(0, 360))
kit.ph("stone_fire_pit", -33, ty_ + 17)
town.tavern((TOWN_C[0] + 10, TOWN_C[1] + 10), n_tables=2)
town.lamps_along(road_n, 6.0, every=18.0)

# --- Feldlager der Verteidiger (Neia, Kapitel Jaldabaoth) ------------------------------------------------------------------
cx, cy = CAMP
town.plaza(cx, cy, 20.0, paved=False, ragged=1.5)
for i in range(-3, 4):
    for j in range(-1, 2):
        if i == 0:
            continue
        put("SM_Tent_low", cx + i * 5.0, cy + j * 6.5, rot=rng.choice([0, 180]), s=2.3)
for k in range(8):
    x, y = cx - 21 + k * 6, cy + 14
    put("SM_Spear_low", x, y, z=kit.ground_fn(x, y) - 0.1, s=2.6)
    put("SM_Cloth01", x + 0.35, y, z=kit.ground_fn(x, y) + 3.6, rot=90, s=3.5, nocol=True)
for (x, y) in [(cx - 15, cy - 9), (cx + 15, cy - 9), (cx, cy + 6)]:
    put("SM_StandLight", x, y, s=1.2)
    town.lamps.append((x, y, kit.ground_fn(x, y) + 2.9))
for _ in range(14):
    a, d = rng.uniform(0, math.tau), rng.uniform(4, 17)
    kit.ph(rng.choice(["wooden_crate_01", "wooden_crate_02", "wine_barrel_01", "wooden_barrels_01", "barrel_03"]),
           cx + math.cos(a) * d, cy + math.sin(a) * d, rot=rng.uniform(0, 360))
kit.ph("stone_fire_pit", cx, cy - 2, rot=0)

# --- Abelion-Hügel: verbrannte Lager, Gebeine, Felsen ----------------------------------------------------------------------
for (bx, by) in [(-60, -40), (50, -70), (-30, -100), (80, -20), (-95, -80)]:
    for _ in range(rng.randint(3, 5)):
        a, d = rng.uniform(0, math.tau), rng.uniform(2, 8)
        put("SM_Tent_low", bx + math.cos(a) * d, by + math.sin(a) * d, rot=rng.uniform(0, 360), s=rng.uniform(1.6, 2.2),
            rx=rng.uniform(-25, 25))
    for _ in range(rng.randint(4, 8)):
        a, d = rng.uniform(0, math.tau), rng.uniform(1, 10)
        put(rng.choice(["SM_Skeleton_01", "SM_Skeleton_03", "SM_Skeleton_05", "SM_skull_02", "SM_skull_04"]),
            bx + math.cos(a) * d, by + math.sin(a) * d, rot=rng.uniform(0, 360), s=rng.uniform(0.9, 1.1), nocol=True)
    kit.ph("stone_fire_pit", bx, by, rot=rng.uniform(0, 360))
    kit.ph(rng.choice(["dead_tree_trunk", "dead_tree_trunk_02"]), bx + 6, by - 3, rot=rng.uniform(0, 360))
    town.plaza(bx, by, 9.0, paved=False, ragged=2.0)
for _ in range(70):
    x, y = rng.uniform(-HALF + 8, HALF - 8), rng.uniform(-HALF + 8, 0)
    if y < wall_y(x) - 14 and town.at(x, y) == FREE:
        put(rng.choice(["SM_Rock01", "SM_Rock03", "SM_rock_03", "SM_rock_01"]), x, y, rot=rng.uniform(0, 360),
            s=rng.uniform(0.5, 1.6), sink=0.4)
        town.mark_rect(x, y, 4, 4, 0, HOUSE)

# --- Land: Felder im Norden, Wald, Gehöfte ---------------------------------------------------------------------------------
town.outskirts(lambda x, y: y < wall_y(x) + 12 or (district(x, y) is not None) or math.hypot(x - CAMP[0], y - CAMP[1]) < 24,
               farms=[(-100, 80, 10), (100, 96, -20), (-110, 130, 80)],
               fields=[(-70, 60, 26, 16, 8), (84, 70, 22, 16, -6), (-62, 120, 24, 14, 4), (70, 128, 24, 12, -10)],
               trees=700, keep_clear=[(GATE[0], GATE[1] + 20, 20)])
for _ in range(700):                                            # lichte Bäume in den Abelion-Hügeln
    x, y = rng.uniform(-HALF + 6, HALF - 6), rng.uniform(-HALF + 6, HALF - 6)
    if y < wall_y(x) - 18 and town.at(x, y) == FREE and noise.noise(Vector((x * 0.025, y * 0.025, 3.1))) > 0.15:
        put(rng.choice(["SM_Tree02", "SM_Tree10", "SM_Tree09", "SM_Spruce1"]), x, y, rot=rng.uniform(0, 360),
            s=rng.uniform(0.8, 1.3), sink=0.2)
        town.mark_rect(x, y, 4, 4, 0, HOUSE)

kit.terrain(HALF, flat_r=TERRAIN["flat_r"], hill_h=TERRAIN["hill_h"], tex="Textures_T_LandScapeLayer01_BC.png",
            normal="Textures_T_LandScapeLayer01_N.png", tile=5.0, edge_rise=TERRAIN["edge_rise"], res=500,
            inner_h=TERRAIN["inner_h"], path_tex="Texture_T_Cobblestone_BC.png", path_normal="Texture_T_Cobblestone_N.png",
            path_fn=town.path_fn, dirt_fn=town.dirt_fn, height_fn=shape)
kit.grass((-HALF + 2, -HALF + 2, HALF - 2, HALF - 2), 24000, s=(0.8, 1.4))

town.anchors(spawn=(0.0, -64.0, 0), gate=(0.0, -72.0), board=(6.0, -58.0), keeper=(0.0, GATE[1] + 18, 180),
             slots_center=(CAMP[0], CAMP[1] - 12), lines=[(road_n, 8)] + [(l, 9) for l in lanes],
             inside=lambda x, y: y > wall_y(x) + 10)
town.save_map(os.path.splitext(dst)[0] + "_map.png")
kit.finish_materials(metal_keys=("standlight", "spear", "knight"))
kit.export()
