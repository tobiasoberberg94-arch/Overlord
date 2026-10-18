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
from mathutils import Vector, noise  # noqa: E402

exp_dir, dst = [os.path.abspath(a) for a in sys.argv[sys.argv.index("--") + 1:][:2]]
kit = Kit(exp_dir, dst, seed=31)
put, empty, rng = kit.put, kit.empty, kit.rng
HALF = 110.0
LAKE = (0.0, 12.0, 17.0)
TEMPLE = (0.0, 52.0)

g = kit.terrain(HALF, flat_r=48.0, hill_h=14.0, tex="Textures_T_ground_texture_T_rocky_ground_D.png", tile=6.0,
                edge_rise=22.0, res=360, inner_h=0.6)
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


def crystal(x, y, h, r, lean):
    bm = bmesh.new()
    res = bmesh.ops.create_cone(bm, cap_ends=True, segments=6, radius1=r, radius2=r * 0.55, depth=h * 0.8)
    for v in bm.verts:
        v.co.z += h * 0.4
    top = bmesh.ops.create_cone(bm, cap_ends=True, segments=6, radius1=r * 0.55, radius2=0.0, depth=h * 0.25)
    for v in top["verts"]:
        v.co.z += h * 0.8 + h * 0.125
    me = bpy.data.meshes.new("Ice_Crystal"); bm.to_mesh(me); bm.free()
    me.materials.append(cm)
    o = bpy.data.objects.new("Ice_Crystal", me)
    o.location = (x, y, kit.ground_fn(x, y) - 0.2)
    o.rotation_euler = (lean[0], lean[1], rng.uniform(0, math.tau))
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
        tag(put("SM_floor02", tx + i * 5, ty + j * 5, z=gz + 0.2, rot=rng.choice([0, 90, 180, 270])), "frost_")
for k in range(10):
    a = k / 10 * math.tau
    tag(put("SM_middle_pillar2", tx + math.cos(a) * 11, ty - 2 + math.sin(a) * 9, z=gz + 0.4), "frost_")
put("SM_understair02", tx, ty - 11.5, z=gz - 1.2, rot=0)
tag(put("SM_statuestair", tx, ty + 7, z=gz + 0.4, rot=180, s=0.8), "frost_")
for sx in (-1, 1):
    tag(put("SM_statuehuman", tx + sx * 9, ty + 6, z=gz + 0.4, rot=180 - sx * 25, s=0.45), "frost_")
    tag(put("SM_wall02", tx + sx * 6, ty + 10, z=gz + 0.4, rot=180), "frost_")
    crystal(tx + sx * 4.5, ty - 9.5, 5.5, 0.6, (0.0, sx * 0.12))
for sx in (-1, 0, 1):
    tag(put("SM_wall02", tx + sx * 5, ty + 11, z=gz + 5.4, rot=180), "frost_")

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
empty("Keeper", tx, ty + 2, gz + 0.4, rot=180)
for i, a in enumerate([200, 235, 270, 305, 340, 20]):
    r = math.radians(a)
    empty("Slot%d" % (i + 1), tx + math.cos(r) * 5, ty - 4 + math.sin(r) * 4, gz + 0.4)
for i, (x, y) in enumerate(clusters[:8]):
    empty("Violet_%d" % (i + 1), x, y, kit.ground_fn(x, y) + 3.0)
for i, sx in enumerate((-1, 1)):
    empty("Lamp_%d" % (i + 1), tx + sx * 6, ty - 6, gz + 3.0)

kit.finish_materials()
kit.export()
