# Blender: Festungsstadt E-Rantel – gewachsene Handelsstadt hinter einer unregelmäßigen Mauer
#   blender -b -P build_erantel.py -- <ErantelKit-Ordner> <ziel.glb>
# ErantelKit = Fantasy-Castle-Gebäude (auf Menschenmaß ~0.62 skaliert) + Medieval-Lake-Village-Häuser/Requisiten.
# Blender-Y = im Spiel -Z.  Südtor (0, -58), Hauptstraße windet sich zum Marktplatz (-2, -14),
# weiter durchs innere Tor (0, 26) zur Zitadelle (2, 50). Gassen nach Westen/Osten, Stadttore W/O.
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from loc_kit import Kit  # noqa: E402
from mathutils import noise, Vector  # noqa: E402

exp_dir, dst = [os.path.abspath(a) for a in sys.argv[sys.argv.index("--") + 1:][:2]]
kit = Kit(exp_dir, dst, seed=8)   # volle Originalqualität, Godot erzeugt LOD-Stufen
kit.lod_names = {"SM_Tree02", "SM_Tree03", "SM_Tree4", "SM_Tree05", "SM_Tree06", "SM_Tree07", "SM_Tree08", "SM_Tree09",
                 "SM_Tree10", "SM_Tree13", "SM_ChurchTree01", "SM_Spruce1", "SM_TreeType1", "SM_type2Tree",
                 "MW_tree_02", "MW_tree_03", "MW_pine_tree_Var_01", "FV_tree_01", "FV_tree_02"}   # Bäume: Instancing + Detailstufen
put, empty, rng = kit.put, kit.empty, kit.rng
HALF = 125.0
C = (0.0, 2.0)                                    # Stadtmitte (Mauerellipse)
MARKET = (-2.0, -14.0)
FC = 0.62                                         # Fantasy-Castle-Maßstab -> Türen ~2,1 m


def wall_r(a):
    """Mauerradius je Winkel: Ellipse mit Ausbuchtungen."""
    n = noise.noise(Vector((math.cos(a) * 1.3, math.sin(a) * 1.3, 2.2)))
    return 1.0 + n * 0.12


RX, RY = 64.0, 60.0
GATES = {-90: "S", 180: "W", 0: "O"}             # Winkel (Grad) -> Tor
wall = []
for k in range(0, 360, 4):
    a = math.radians(k)
    r = wall_r(a)
    wall.append((C[0] + math.cos(a) * RX * r, C[1] + math.sin(a) * RY * r, k))


def gate_pos(deg, inset=0.0):
    a = math.radians(deg)
    r = wall_r(a)
    return C[0] + math.cos(a) * (RX * r - inset), C[1] + math.sin(a) * (RY * r - inset)


SG, WG, OG = gate_pos(-90), gate_pos(180), gate_pos(0)

# --- Straßen ---------------------------------------------------------------------------------
main = kit.spline([(SG[0], SG[1] - 50), (SG[0] + 2, SG[1] - 20), SG, (3, -44), (-3, -30), MARKET, (4, 2), (-2, 14), (0, 26),
                   (2, 38), (2, 46)])
west = kit.spline([MARKET, (-14, -10), (-28, -4), (-44, -2), WG, (WG[0] - 40, WG[1] + 6)])
east = kit.spline([MARKET, (12, -18), (26, -12), (42, -4), OG, (OG[0] + 40, OG[1] - 8)])
lanes = [
    kit.spline([(3, -44), (18, -40), (32, -34), (44, -26)]),
    kit.spline([(-3, -30), (-18, -36), (-32, -38), (-46, -30)]),
    kit.spline([(-28, -4), (-30, 10), (-24, 22), (-10, 20)]),
    kit.spline([(26, -12), (30, 4), (24, 18), (10, 20)]),
    kit.spline([(4, 2), (14, 6), (24, 18)]),
    kit.spline([(-2, 14), (-14, 8), (-28, -4)]),
]
upper = kit.spline([(0, 26), (-14, 32), (-20, 44), (-8, 56), (8, 56), (20, 44), (14, 32), (0, 26)])
market = kit.spline([(MARKET[0] - 12, MARKET[1] - 2), (MARKET[0] - 6, MARKET[1] + 9), (MARKET[0] + 7, MARKET[1] + 8),
                     (MARKET[0] + 12, MARKET[1] - 3), (MARKET[0] + 3, MARKET[1] - 10), (MARKET[0] - 9, MARKET[1] - 8),
                     (MARKET[0] - 12, MARKET[1] - 2)])
roads = [(main, 6.0), (west, 4.5), (east, 4.5), (upper, 4.0), (market, 16.0)] + [(l, 3.2) for l in lanes]
path_fn = kit.roads_mask(roads, HALF)
kit.terrain(HALF, flat_r=78.0, hill_h=9.0, tex="Textures_T_LandScapeLayer01_BC.png",
            normal="Textures_T_LandScapeLayer01_N.png", tile=5.0, edge_rise=12.0, res=440, inner_h=0.6,
            path_tex="Textures_T_BayStone_BC.png", path_normal="Textures_T_BayStone_N.png", path_fn=path_fn)

# --- Mauer -------------------------------------------------------------------------------------
gate_pts = [gate_pos(d) for d in GATES]
for i in range(len(wall)):
    (ax, ay, ka), (bx, by, kb) = wall[i], wall[(i + 1) % len(wall)]
    L = math.hypot(bx - ax, by - ay)
    rot = math.degrees(math.atan2(by - ay, bx - ax))
    n = max(1, round(L / 5.0))
    for j in range(n):
        t = (j + 0.5) / n
        x, y = ax + (bx - ax) * t, ay + (by - ay) * t
        if any(math.hypot(x - gx, y - gy) < 7.0 for gx, gy in gate_pts):
            continue
        for row in range(2):
            put("SM_brick", x, y, z=kit.ground_fn(x, y) - 0.5 + row * 5.0, rot=rot)
        put("SM_updan", x, y, z=kit.ground_fn(x, y) + 9.4, rot=rot)
    kit.occupy((ax + bx) / 2, (ay + by) / 2, 4.0)
for k in range(0, 360, 28):
    a = math.radians(k + 6)
    x, y = C[0] + math.cos(a) * RX * wall_r(a), C[1] + math.sin(a) * RY * wall_r(a)
    if all(math.hypot(x - gx, y - gy) > 12 for gx, gy in gate_pts):
        put("SM_TowerSmall", x, y, s=0.62, rot=rng.uniform(0, 360))
for d, (gx, gy) in zip(GATES, gate_pts):
    a = math.radians(d)
    tx, ty = -math.sin(a), math.cos(a)            # entlang der Mauer
    for sgn in (-1, 1):
        put("SM_TowerrType2", gx + tx * sgn * 9.5, gy + ty * sgn * 9.5, s=0.3, rot=d + 90)
        ix, iy = gx - math.cos(a) * 3 + tx * sgn * 3.8, gy - math.sin(a) * 3 + ty * sgn * 3.8
        put("SM_Knight_posed", ix, iy, rot=d + 90 + 180)
        put("SM_Spear_low", ix + tx * sgn * 0.5, iy + ty * sgn * 0.5)
    kit.occupy(gx, gy, 9.0)

# Innere Mauer (Bogen um das Obere Viertel) mit Tor bei (0, 26)
for k in range(200, 341, 5):
    a = math.radians(k)
    x, y = 0 + math.cos(a) * 30, 50 + math.sin(a) * 24
    if math.hypot(x - 0, y - 26) < 6:
        continue
    put("SM_brick", x, y, z=kit.ground_fn(x, y) - 0.5, rot=k + 90)
    put("SM_updan", x, y, z=kit.ground_fn(x, y) + 4.4, rot=k + 90)
    kit.occupy(x, y, 3.0)
for sgn in (-1, 1):
    put("SM_TowerrType2", sgn * 7.0, 26.5, s=0.24)

# --- Bauten -----------------------------------------------------------------------------------
smoke = []
YARD = ["SM_WoodenBarrel01", "SM_FireWoodSet02", "SM_WoodenBucket01", "SM_WoodenBox01", "SM_WoodenBox03", "SM_Chair",
        "SM_FlowerPot01", "SM_FlowerPot02"]


def dress(hx, hy, rot, rad, name):
    r = math.radians(rot)
    fx, fy = math.sin(r), -math.cos(r)
    sx, sy = math.cos(r), math.sin(r)
    if rng.random() < 0.7:
        side = rng.choice((-1, 1))
        kit.clutter(hx + fx * rad * 0.9 + sx * side * rad * 0.6, hy + fy * rad * 0.9 + sy * side * rad * 0.6, YARD,
                    n=(1, 3), r=(0.3, 1.2))
    if rng.random() < 0.25:
        put(rng.choice(["SM_Cloth01", "SM_Cloth02", "SM_Cloth03"]), hx - fx * (rad + 1.0), hy - fy * (rad + 1.0),
            z=kit.ground_fn(hx, hy) + 1.0, rot=rot, nocol=True)
    if rng.random() < 0.3:
        put(rng.choice(["SM_Tree05", "SM_Tree06", "SM_Tree13"]), hx - fx * (rad + 3.5), hy - fy * (rad + 3.5),
            rot=rng.uniform(0, 360), s=rng.uniform(0.55, 0.8))
    if rng.random() < 0.5:
        smoke.append((hx, hy, kit.ground_fn(hx, hy) + 8.0))


# Reservierte Plätze: Gilden, Zitadelle, Tempel, Markt
kit.occupy(2, 48, 14)
kit.occupy(MARKET[0], MARKET[1], 11)
GUILDS = [("SM_Build1", -20.0, -24.0, 30, 0.55), ("SM_AccomsP7", 18.0, -27.0, -20, 0.45),
          ("SM_AccomsP16", 16.0, 0.0, 200, 0.9 * FC / 0.62), ("SM_Build3", -16.0, 40.0, 60, 0.5),
          ("SM_Build4", 17.0, 40.0, -60, 0.5), ("SM_FarTower", -30.0, 52.0, 0, 0.9)]
for (nm, x, y, r, s) in GUILDS:
    put(nm, x, y, rot=r, s=s)
    kit.occupy(x, y, max(kit.size(nm).x, kit.size(nm).y) * s * 0.5)
put("SM_Build2", 2.0, 52.0, rot=180, s=0.42)                 # Zitadelle / Rathaus

CITY = [("SM_House", FC), ("SM_House3", FC), ("SM_House4", FC), ("SM_House6", FC), ("SM_AccomsP8", FC),
        ("SM_HouseAdd2", FC), ("SM_HouseSet01", 1.0), ("SM_HouseSet02", 1.0),
        ("FV_house_01", 0.8), ("FV_house_02", 0.8), ("FV_house_03", 0.8), ("FV_house_04", 0.8), ("FV_house_05", 0.8)]
kit.along(main, CITY, spacing=(5, 8), gap=(3.6, 4.6), jitter=6, skip=0.05, on_place=dress, start=58, end=230)
for line in (west, east):
    kit.along(line, CITY, spacing=(5, 8), gap=(2.9, 3.8), jitter=7, skip=0.05, on_place=dress, start=10, end=62)
for line in lanes:
    kit.along(line, CITY + [("SM_StorageSet", 1.0)], spacing=(5, 9), gap=(2.3, 3.2), jitter=10, skip=0.1, on_place=dress)
kit.along(upper, [("SM_Build5", 0.3), ("SM_AccomsP12", 0.35), ("SM_House4", FC), ("SM_House6", FC)], spacing=(8, 12),
          gap=(3.0, 4.0), jitter=5, skip=0.2, on_place=dress, sides=(1,))
# Zweite Reihe / Hinterhöfe in den Blöcken (unregelmäßig, wie gewachsen)
for _ in range(240):
    a = rng.uniform(0, math.tau)
    rr = math.sqrt(rng.uniform(0.05, 0.8))
    x, y = C[0] + math.cos(a) * RX * rr, C[1] + math.sin(a) * RY * rr
    if y > 22 and abs(x) < 34:
        continue
    nm, s = rng.choice(CITY)
    sz = kit.size(nm)
    rad = max(sz.x, sz.y) * s * 0.5
    if kit.free(x, y, rad):
        rot = rng.uniform(0, 360)
        put(nm, x, y, rot=rot, s=s, sink=0.15)
        kit.occupy(x, y, rad)
        dress(x, y, rot, rad, nm)

# Marktplatz: Brunnen, Stände, Zelte, Wagen, Kisten
mx, my = MARKET
put("SM_RoundOrn", mx, my, s=0.9)
put("SM_Statue01", mx, my)
for i in range(9):
    a = i * math.tau / 9 + rng.uniform(-0.15, 0.15)
    d = rng.uniform(8.5, 11.0)
    x, y = mx + math.cos(a) * d, my + math.sin(a) * d
    if i % 3 == 0:
        put("SM_Tent_low", x, y, rot=math.degrees(a) + 90, s=1.5)
    else:
        put(rng.choice(["SM_WoodenWagon01", "SM_WoodenWagon02"]), x, y, rot=math.degrees(a) + 90 + rng.uniform(-20, 20))
    kit.clutter(x, y, ["SM_WoodenBarrel01", "SM_WoodenBox01", "SM_WoodenBox03", "SM_WoodenBucket02", "SM_Hay"],
                n=(2, 4), r=(1.2, 2.4), s=(0.5, 1.0))
for (dx, dy) in [(-7, -6), (6, 6), (-8, 6), (8, -6)]:
    put("SM_StandLight", mx + dx, my + dy)
# Laternen entlang der Hauptstraße
for k in range(30, len(main) - 10, 14):
    x, y = main[k]
    if -52 < y < 46:
        put("SM_StandLight", x + 3.3, y + rng.uniform(-1, 1))

# --- Draußen -----------------------------------------------------------------------------------
def outside(x, y):
    return ((x - C[0]) / (RX * 1.12)) ** 2 + ((y - C[1]) / (RY * 1.12)) ** 2 > 1.0


# Händlerlager und Felder vor dem Südtor
for i in range(7):
    x, y = SG[0] + rng.choice([-1, 1]) * rng.uniform(10, 20), SG[1] - rng.uniform(8, 26)
    if path_fn(x, y) < 0.5:
        put("SM_Tent_low", x, y, rot=rng.uniform(0, 360), s=1.5)
        kit.clutter(x, y, ["SM_WoodenBarrel01", "SM_WoodenBox01", "SM_FireWoodSet02"], n=(2, 4), r=(2.0, 3.5))
        kit.occupy(x, y, 3.5)
for (fx, fy, fw, fh, fr) in [(-38, -84, 22, 14, 15), (36, -86, 20, 12, -10), (-84, 30, 16, 20, 5), (86, -30, 14, 20, -15)]:
    r = math.radians(fr)
    for _ in range(int(fw * fh * 0.9)):
        u, v = rng.uniform(-fw / 2, fw / 2), rng.uniform(-fh / 2, fh / 2)
        x, y = fx + u * math.cos(r) - v * math.sin(r), fy + u * math.sin(r) + v * math.cos(r)
        if path_fn(x, y) < 0.5:
            put(rng.choice(["SM_WheatGrass01", "SM_WheatGrass03"]), x, y, rot=rng.uniform(0, 360), nocol=True)
    kit.occupy(fx, fy, max(fw, fh) * 0.7)
BIG = ["SM_Tree4", "SM_Tree10", "SM_Tree02", "SM_Tree09", "SM_Tree13", "SM_Spruce1", "SM_Tree03"]
UNDER = ["SM_Bush07", "SM_Foliage_33", "SM_Foliage_56", "SM_Bush01", "SM_Foliage_22", "SM_Foliage_24"]
city_box = [(C[0] - RX * 1.15, C[1] - RY * 1.15, C[0] + RX * 1.15, C[1] + RY * 1.15)]
kit.forest((-HALF + 4, -HALF + 4, HALF - 4, HALF - 4), BIG, 380, avoid=city_box, min_d=4.5, under=UNDER, under_n=2,
           threshold=0.0)
ALL = (-HALF + 2, -HALF + 2, HALF - 2, HALF - 2)
kit.grass(ALL, 26000, avoid=[(-50, -45, 50, 50)], s=(0.8, 1.5))
kit.grass(ALL, 4000, kind="@flower", avoid=[(-50, -45, 50, 50)])
kit.grass((-60, -55, 60, 60), 3500, s=(0.5, 0.9))                     # Gras in Höfen und Ecken
kit.meadow(ALL, ["SM_Foliage_33", "SM_Foliage_34", "SM_Foliage_12"], 200, avoid=[(-50, -45, 50, 50)])

# --- Anker ---------------------------------------------------------------------------------------
empty("Spawn", SG[0] + 1.0, SG[1] + 9.0, rot=0)
empty("Gate", SG[0], SG[1] - 7.0)
empty("Board", mx + 6.0, my - 8.5)
for i, a in enumerate([200, 235, 270, 305, 340, 20]):
    r = math.radians(a)
    empty("Slot%d" % (i + 1), mx + math.cos(r) * 6.0, my + math.sin(r) * 6.0)
empty("Lamp_1", mx, my, kit.ground_fn(mx, my) + 6.0)
for i, (x, y, z) in enumerate(smoke[:40]):
    empty("Smoke_%d" % (i + 1), x, y, z)
n = 1
for line, step in [(main, 8), (west, 8), (east, 8)] + [(l, 9) for l in lanes]:
    for k in range(0, len(line), step):
        x, y = line[k]
        if not outside(x, y):
            empty("Walk_%d" % n, x, y)
            n += 1
for i in range(10):
    a = i * math.tau / 10
    empty("Idle_%d" % (i + 1), mx + math.cos(a) * rng.uniform(4.0, 8.0), my + math.sin(a) * rng.uniform(4.0, 8.0))
print("OVERLORD walk", n - 1, "smoke", len(smoke))

kit.finish_materials(metal_keys=("knight", "spear", "standlight"))
kit.export()
