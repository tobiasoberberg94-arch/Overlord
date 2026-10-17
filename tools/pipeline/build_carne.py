# Blender: Dorf Carne aus Medieval-Lake-Village-Bauteilen
#   blender -b -P build_carne.py -- <Export-Ordner> <ziel.glb>
# Grundriss (Blender-Y = im Spiel -Z):
#   Ankunft im Süden (Spawn y=-26, Gate y=-33), Dorfstraße Nord-Süd, Querstraße beim Dorfplatz (y=4),
#   Häuser um den Platz, Felder im Osten, Mühle/Wasserrad im Westen, Kirche mit Friedhof im Norden (y=44),
#   freie Wiese y=12..30 für den Überfall (Soldaten y=18, Engel y=26), Waldrand (Wald von Tob) dahinter.
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from loc_kit import Kit  # noqa: E402

exp_dir, dst = [os.path.abspath(a) for a in sys.argv[sys.argv.index("--") + 1:][:2]]
kit = Kit(exp_dir, dst, tri_cap={
    "SM_HouseSet02": 60000, "SM_StorageSet": 30000, "SM_WoodenBox01": 3000, "SM_WoodenBox03": 3000,
    "SM_tombstone02": 3000, "SM_tombStone01": 3000, "SM_ChurchTree01": 8000, "SM_Tree05": 8000,
})
put, empty = kit.put, kit.empty
HALF = 80.0

# --- Gelände: innen eben, außen Hügel ------------------------------------------------
def path_fn(x, y):
    """1 auf den Erdwegen (Hauptstraße, Querstraße, Dorfplatz, Kirchweg), sonst 0."""
    wob = math.sin(y * 0.15) * 0.8
    if abs(x - wob) < 2.2 and -46 < y < 44:
        return 1.0
    if abs(y - 4.0 - math.sin(x * 0.2) * 0.6) < 1.9 and -30 < x < 30:
        return 1.0
    if (x - 1.0) ** 2 / 64 + (y - 4.0) ** 2 / 49 < 1.0:
        return 1.0
    return 0.0


kit.terrain(HALF, flat_r=46.0, hill_h=6.0, tex="Textures_T_LandScapeLayer01_BC.png",
            normal="Textures_T_LandScapeLayer01_N.png", tile=5.0, edge_rise=8.0, res=360,
            path_tex="Textures_T_LandScapeLayer04_BC.png", path_normal="Textures_T_LandScapeLayer04_N.png",
            path_fn=path_fn)

# --- Dorfplatz ----------------------------------------------------------------------
put("SM_firestone", 4.5, 7.5)                     # Feuerstelle
put("SM_FireWoodSet02", 6.6, 8.8, rot=30)
put("SM_WoodenWagon01", -5.5, 9.0, rot=20)
put("SM_WoodenWagon02", 6.5, -1.5, rot=-70)
for (x, y, r) in [(-4.8, -1.8, 10), (-4.0, -2.6, 40), (-5.6, -2.9, 0)]:
    put("SM_WoodenBarrel01", x, y, rot=r)
for (x, y, r) in [(5.4, 10.6, 15), (6.1, 11.4, 50)]:
    put("SM_WoodenBox01", x, y, rot=r)
put("SM_WoodenBox03", 5.6, 11.6, z=None, rot=5)
put("SM_WoodenChair01", 2.2, 9.6, rot=90)
put("SM_WoodenChair01", 6.9, 6.0, rot=0)
for (x, y) in [(-3.2, -3.0), (3.2, -3.0), (-3.2, 11.0), (3.2, 11.0), (-3.0, -16), (3.0, -16), (-3.0, 24), (3.0, 24)]:
    put("SM_StandLight", x, y)
put("SM_Sign01", 2.6, -9.0, z=1.2, rot=180)

# --- Häuser -------------------------------------------------------------------------
put("SM_HouseSet01", -16.0, -9.0, rot=90)
put("SM_HouseSet01", 17.0, 15.0, rot=-90)
put("SM_HouseSet02", -14.0, 13.5, rot=90)
put("SM_HouseSet02", 14.5, -10.5, rot=-90)
put("SM_HouseSet02", -14.5, 30.0, rot=90)
put("SM_StorageSet", 16.0, -27.0, rot=-90)
put("SM_StorageSet", -16.0, -26.0, rot=90)
put("SM_StorageSet", 15.0, 31.0, rot=-90)
put("SM_WaterWheel01", -27.0, 2.0, rot=90)
put("SM_Ladder01", -10.5, -6.0, rot=90)

# Kirche + Friedhof im Norden
put("SM_ChurchSet", 0.0, 50.0, rot=0)
for i in range(8):
    x = 13.0 + (i % 4) * 2.2
    y = 41.0 + (i // 4) * 3.0
    put("SM_tombStone01" if i % 2 else "SM_tombstone02", x, y, rot=180 + kit.rng.uniform(-8, 8))
put("SM_Statue01", 21.5, 46.5, rot=200)
put("SM_ChurchTree01", 24.5, 42.0, rot=40)
for x in [11.0, 15.5, 20.0]:
    put("SM_StoneWall01", x + 1.2, 38.5, rot=0)
put("SM_StoneWall02", 24.8, 40.2, rot=90)

# --- Felder (Weizen) mit Zäunen im Osten, Heu --------------------------------------------
kit.scatter(["SM_WheatGrass01", "SM_WheatGrass03"], 220, (24, -38, 40, -14), min_d=0.9, s=(0.9, 1.2))
for y in range(-38, -12, 4):
    put("SM_Fence01", 22.6, y + 2, rot=90)
for x in range(24, 41, 4):
    put("SM_Fence01", x + 2, -12.5, rot=0)
put("SM_Hay", 34.0, 12.0, rot=90, s=0.7)
kit.scatter(["SM_WheatGrass01"], 60, (-40, -38, -24, -16), min_d=1.0)
for y in range(-38, -14, 4):
    put("SM_Fence02", -23.0, y + 2, rot=90)

# Steinmauern und Weidenzäune entlang der Straße
for y in [-34, -20]:
    put("SM_StoneWall01", -4.6, y, rot=90)
    put("SM_StoneWall01", 4.6, y, rot=90)
put("SM_GateWall01", 0.0, -36.5, rot=0)            # Torbogen am Dorfeingang

# --- Vegetation: Gras, Büsche, Bäume, Waldrand -----------------------------------------
road = [(-3.2, -42, 3.2, 46), (-32, 1.0, 32, 7.0)]
houses = [(-24, -16, -8, 20), (8, -18, 24, 22), (-22, 24, -8, 36), (10, 26, 22, 36), (-6, 40, 6, 58)]
fields = [(22, -40, 42, -12), (-42, -40, -22, -14)]
square = [(-8, -5, 9, 13)]
fight = [(-10, 12, 10, 32)]
avoid = road + houses + fields + square + fight
kit.scatter(["SM_Foliage_5", "SM_Bush06", "SM_Foliage_5"], 420, (-50, -50, 50, 50), avoid=avoid, min_d=1.2)
kit.scatter(["SM_Bush01", "SM_Bush03"], 40, (-46, -46, 46, 46), avoid=avoid, min_d=4.0, nocol=True)
kit.scatter(["SM_Rock03"], 14, (-44, -44, 44, 44), avoid=avoid, min_d=6.0)
for (x, y, r, s) in [(-34, 18, 0, 1.0), (31, -2, 90, 0.8), (-36, -44, 40, 1.0)]:
    put("SM_Rock01", x, y, rot=r, s=s, sink=0.6)
# einzelne Bäume im Dorf
for (x, y, t) in [(-9, -20, "SM_Tree05"), (10, -20, "SM_Tree05"), (-24, 8, "SM_Tree13"), (26, 6, "SM_Tree02"),
                  (-8, 21, "SM_Tree05"), (9, 22, "SM_Tree05"), (-28, 30, "SM_Tree09")]:
    put(t, x, y, rot=kit.rng.uniform(0, 360))
# Waldring (Wald von Tob im Norden dichter)
trees = ["SM_Tree02", "SM_Tree09", "SM_Tree13", "SM_Tree02"]
for i in range(46):
    a = i / 46 * math.tau + kit.rng.uniform(-0.03, 0.03)
    r = kit.rng.uniform(52, 72)
    x, y = math.cos(a) * r, math.sin(a) * r
    if abs(x) < 6 and y < -40:          # Straße nach Süden frei lassen
        continue
    put(kit.rng.choice(trees), x, y, rot=kit.rng.uniform(0, 360), s=kit.rng.uniform(0.9, 1.25))
for i in range(16):                     # dichter Waldrand hinter der Kirche
    x = kit.rng.uniform(-45, 45)
    y = kit.rng.uniform(60, 74)
    put(kit.rng.choice(trees[:3]), x, y, rot=kit.rng.uniform(0, 360), s=kit.rng.uniform(1.0, 1.3))

# --- Anker ---------------------------------------------------------------------------
empty("Spawn", 0, -26.0, rot=0)
empty("Gate", 0, -31.5)
empty("Board", 3.5, -2.0)
for i, a in enumerate([200, 240, 280, 320, 0, 40]):
    r = math.radians(a)
    empty("Slot%d" % (i + 1), math.cos(r) * 6.0, 4.0 + math.sin(r) * 6.0)
empty("Fire_1", 4.5, 7.5, 1.0)

kit.finish_materials(metal_keys=("standlight",))
kit.export()
