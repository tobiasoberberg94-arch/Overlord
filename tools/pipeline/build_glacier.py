# Blender: Eisgletscher (5. Ebene, Cocytus) – Schneetal, Eisklippen, Eisnadeln, zugefrorener See, gefrorener Tempel.
#   blender -b -P build_glacier.py -- <GlacierKit-Ordner> <ziel.glb>
# Benennung steuert die Shader im Spiel (location_builder._special_surfaces):
#   SnowGround → Schnee, Ice_* / IceLake → Gletschereis, frost_* → Reif-Überzug.
import math
import os
import sys

import bmesh
import bpy

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from loc_kit import Kit  # noqa: E402
from mathutils import Matrix, Vector, noise  # noqa: E402

exp_dir, dst = [os.path.abspath(a) for a in sys.argv[sys.argv.index("--") + 1:][:2]]
# sehr dichte Teile vereinfachen: die Statuen hatten je 450 000 Dreiecke (Ladezeit: Kollision je Dreieck), die
# Eisklippen am Talrand stehen weit weg
kit = Kit(exp_dir, dst, seed=31, tri_cap={"SM_statuehuman": 70000, "SM_rock_02": 18000, "SM_rock_01": 12000,
                                         "SM_rock_03": 12000})
put, empty, rng = kit.put, kit.empty, kit.rng
HALF = 110.0
LAKE = (0.0, 12.0, 17.0)
TEMPLE = (0.0, 52.0)

def plaza(x, y, v):
    """Tempelplatz eben (Talhöhe 0), nach außen in 9 m weich in den Hang übergehend."""
    dx = max(0.0, abs(x - TEMPLE[0]) - 15.0)
    dy = max(0.0, (TEMPLE[1] - 16.0) - y, y - (TEMPLE[1] + 12.0))
    k = min(1.0, math.hypot(dx, dy) / 9.0)
    k = k * k * (3 - 2 * k)
    return v * k


g = kit.terrain(HALF, flat_r=48.0, hill_h=14.0, tex="Textures_T_ground_texture_T_rocky_ground_D.png", tile=6.0,
                edge_rise=22.0, res=360, inner_h=0.6, height_fn=plaza)
g.name = "SnowGround"


def tag(o, prefix):
    if o is not None:
        o.name = prefix + o.name
    return o


kit.occupy(LAKE[0], LAKE[1], LAKE[2] + 2)
kit.occupy(TEMPLE[0], TEMPLE[1], 14)
kit.occupy(0, -40, 8)

# --- Zugefrorener See ------------------------------------------------------------------------------
bm = bmesh.new()
bmesh.ops.create_circle(bm, cap_ends=True, segments=64, radius=LAKE[2])
for v in bm.verts:
    a = math.atan2(v.co.y, v.co.x)
    v.co.xy *= 1.0 + noise.noise(Vector((math.cos(a), math.sin(a), 0.4))) * 0.18
lm = bpy.data.meshes.new("IceLake"); bm.to_mesh(lm); bm.free()
lo = bpy.data.objects.new("IceLake", lm)
lo.location = (LAKE[0], LAKE[1], kit.ground_fn(LAKE[0], LAKE[1]) + 0.04)
kit.out.objects.link(lo)
for k in range(10):                                      # Eisschollen am Ufer
    a = rng.uniform(0, math.tau); d = LAKE[2] * rng.uniform(0.85, 1.05)
    tag(put(rng.choice(["SM_ground_rock_02", "SM_ground_rock_05"]), LAKE[0] + math.cos(a) * d, LAKE[1] + math.sin(a) * d,
            rot=rng.uniform(0, 360), s=rng.uniform(0.3, 0.6), sink=0.25), "Ice_")

# --- Eisklippen am Talrand ---------------------------------------------------------------------------
for k in range(46):
    a = k / 46 * math.tau + rng.uniform(-0.05, 0.05)
    d = rng.uniform(70, 92)
    x, y = math.cos(a) * d, math.sin(a) * d
    if abs(x) < 9 and y < 0:
        continue                                          # Zugang im Süden frei
    tag(put(rng.choice(["SM_rock_01", "SM_rock_02", "SM_rock_03"]), x, y, rot=rng.uniform(0, 360), s=rng.uniform(1.6, 2.8),
            sink=1.0), "Ice_")

# --- Eisnadeln (Kristalle) ---------------------------------------------------------------------------
cm = bpy.data.materials.new("Ice")


def crystal(x, y, h, r, lean, z=None):
    bm = bmesh.new()
    res = bmesh.ops.create_cone(bm, cap_ends=True, segments=6, radius1=r, radius2=r * 0.55, depth=h * 0.8)
    for v in bm.verts:
        v.co.z += h * 0.4
    top = bmesh.ops.create_cone(bm, cap_ends=True, segments=6, radius1=r * 0.55, radius2=0.0, depth=h * 0.25)
    for v in top["verts"]:
        v.co.z += h * 0.8 + h * 0.125
    bmesh.ops.rotate(bm, verts=bm.verts, matrix=Matrix.Rotation(rng.uniform(0, math.tau), 3, "Z"))
    me = bpy.data.meshes.new("Ice_Crystal"); bm.to_mesh(me); bm.free()
    me.materials.append(cm)
    o = bpy.data.objects.new("Ice_Crystal", me)
    o.location = (x, y, (kit.ground_fn(x, y) if z is None else z) - 0.2)
    o.rotation_euler = (lean[0], lean[1], 0.0)
    kit.out.objects.link(o)


clusters = []
for _ in range(34):
    a = rng.uniform(0, math.tau); d = rng.uniform(22, 66)
    x, y = math.cos(a) * d, math.sin(a) * d
    if abs(x) < 7 and -50 < y < 0:
        continue
    if math.hypot(x - LAKE[0], y - LAKE[1]) < LAKE[2] + 3 or math.hypot(x - TEMPLE[0], y - TEMPLE[1]) < 15:
        continue
    clusters.append((x, y))
    for _ in range(rng.randint(3, 7)):
        crystal(x + rng.uniform(-2.5, 2.5), y + rng.uniform(-2.5, 2.5), rng.uniform(2.0, 7.5), rng.uniform(0.35, 0.9),
                (rng.uniform(-0.3, 0.3), rng.uniform(-0.3, 0.3)))
kit._ground_mats = getattr(kit, "_ground_mats", []) + [cm]

# --- Gefrorener Tempel des Cocytus ---------------------------------------------------------------------
tx, ty = TEMPLE
gz = kit.ground_fn(tx, ty)
for i in range(-2, 3):
    for j in range(-2, 2):
        tag(put("SM_floor02", tx + i * 5, ty + j * 5, z=gz - 0.1, rot=rng.choice([0, 90, 180, 270])), "frost_")
for k in range(10):
    a = k / 10 * math.tau
    tag(put("SM_middle_pillar2", tx + math.cos(a) * 11, ty - 2 + math.sin(a) * 9, z=gz + 0.12), "frost_")
shrine = tag(put("SM_statuestair", tx, ty + 7, z=gz + 0.12, rot=180, s=0.8), "frost_")
# Der Löwe des Schreinmodells sitzt nur auf einer Seite und ragt über das Podest: diese Fläche entfernen
shrine.data = shrine.data.copy()
lion = [i for i, m in enumerate(shrine.data.materials) if m and m.name.startswith("MI_statuestair_03")]
if lion:
    bm = bmesh.new(); bm.from_mesh(shrine.data)
    bmesh.ops.delete(bm, geom=[f for f in bm.faces if f.material_index in lion], context="FACES")
    bm.to_mesh(shrine.data); bm.free()
    print("OVERLORD Löwe entfernt", lion)
for sx in (-1, 1):
    tag(put("SM_statuehuman", tx + sx * 9, ty + 6, z=gz + 0.12, rot=180 - sx * 25, s=0.45), "frost_")
    crystal(tx + sx * 6.6, ty - 13.0, 5.5, 0.6, (0.0, sx * 0.18))   # flankieren den Zugang, vor dem Platz
# Krone aus Eiskristallen hinter dem Schrein: in der Mitte am höchsten, nach außen niedriger, leicht nach hinten und
# außen geneigt (vorher stand hier eine Wand aus schwarzen Innenraumplatten mitten im Schnee)
for k in range(-5, 6):
    a = math.radians(k * 15.0)
    cx, cy = tx + math.sin(a) * 8.5, ty + 9.0 + math.cos(a) * 3.2
    hh = 10.5 - abs(k) * 1.35 + rng.uniform(-0.6, 0.6)
    crystal(cx, cy, hh, 0.75 + (5 - abs(k)) * 0.07, (-0.16 - rng.uniform(0, 0.08), math.sin(a) * 0.45), z=gz)
for k in range(-5, 5):                                 # kleinere Kristalle davor, in den Lücken
    a2 = math.radians((k + 0.5) * 15.0)
    crystal(tx + math.sin(a2) * 7.6, ty + 8.4 + math.cos(a2) * 2.6, (10.5 - abs(k + 0.5) * 1.35) * 0.55, 0.45,
            (-0.1, math.sin(a2) * 0.6), z=gz)

# --- Fichtenwald mit Reif, Felsen ------------------------------------------------------------------------
for _ in range(220):
    a = rng.uniform(0, math.tau); d = rng.uniform(40, 80)
    x, y = math.cos(a) * d, math.sin(a) * d
    if abs(x) < 8 and y < -30:
        continue
    if any(math.hypot(x - cx, y - cy) < 5 for cx, cy in clusters) or not kit.free(x, y, 3):
        continue
    if math.hypot(x - TEMPLE[0], y - TEMPLE[1]) < 22 or (abs(x) < 14 and y > 20):   # Blickachse zum Tempel frei
        continue
    tag(put(rng.choice(["SM_Spruce1", "SM_Spruce2", "SM_Spruce1"]), x, y, rot=rng.uniform(0, 360), s=rng.uniform(0.8, 1.3),
            sink=0.3), "frost_")
for _ in range(40):
    a = rng.uniform(0, math.tau); d = rng.uniform(15, 70)
    x, y = math.cos(a) * d, math.sin(a) * d
    if kit.free(x, y, 2) and not (abs(x) < 6 and y < 0):
        tag(put(rng.choice(["SM_ground_rock_01", "SM_ground_rock_03", "SM_ground_rock_06", "SM_rock_03"]), x, y,
                rot=rng.uniform(0, 360), s=rng.uniform(0.3, 0.8), sink=0.3), "Ice_")
# gefrorene Krieger: Skelette am Seeufer (Cocytus' Trainingsfeld)
for k in range(8):
    a = rng.uniform(0, math.tau); d = LAKE[2] + rng.uniform(4, 9)
    tag(put(rng.choice(["SM_skull_02", "SM_back_bone_01", "SM_horn_01", "SM_small_bone_01"]), LAKE[0] + math.cos(a) * d,
            LAKE[1] + math.sin(a) * d, rot=rng.uniform(0, 360), s=rng.uniform(0.3, 0.6), sink=0.2), "frost_")

# --- Anker ----------------------------------------------------------------------------------------------
empty("Spawn", 0, -40.0, rot=0)
empty("Gate", 0, -46.0)
empty("Keeper", tx, ty + 2, gz + 0.15, rot=180)
for i, a in enumerate([200, 235, 270, 305, 340, 20]):
    r = math.radians(a)
    empty("Slot%d" % (i + 1), tx + math.cos(r) * 5, ty - 4 + math.sin(r) * 4, gz + 0.15)
for i, (x, y) in enumerate(clusters[:8]):
    empty("Violet_%d" % (i + 1), x, y, kit.ground_fn(x, y) + 3.0)
for i, sx in enumerate((-1, 1)):
    empty("Lamp_%d" % (i + 1), tx + sx * 6, ty - 6, gz + 3.0)

kit.finish_materials()
kit.export()
