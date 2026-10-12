# Blender: FBX einlesen und Kennzahlen ausgeben.  blender -b -P inspect_fbx.py -- level.fbx
import sys
from collections import Counter

import bpy
from mathutils import Vector

src = sys.argv[sys.argv.index("--") + 1]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.fbx(filepath=src)
obs = [o for o in bpy.data.objects if o.type == "MESH"]
tris = sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for o in obs)
lo = Vector((1e9,) * 3)
hi = Vector((-1e9,) * 3)
for o in obs:
    for c in o.bound_box:
        w = o.matrix_world @ Vector(c)
        lo = Vector(map(min, lo, w))
        hi = Vector(map(max, hi, w))
print("OVERLORD objekte", len(obs), "meshdaten", len({o.data.name for o in obs}), "dreiecke", tris)
print("OVERLORD bounds", [round(v, 2) for v in lo], [round(v, 2) for v in hi])
print("OVERLORD typen", Counter(o.type for o in bpy.data.objects))
big = sorted(obs, key=lambda o: -len(o.data.polygons))[:15]
for o in big:
    print("OVERLORD gross", o.name, len(o.data.polygons), [m.name for m in o.data.materials][:3])
print("OVERLORD materialien", sorted({m.name for o in obs for m in o.data.materials if m})[:40])
