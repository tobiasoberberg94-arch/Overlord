# Blender: heruntergeladenes Albedo-FBX fuer Mixamo vorbereiten
#   blender -b -P prep_fan.py -- <fbx> <texturordner> <ziel.fbx>
# - auf 1.75 m skalieren, Fuesse auf z=0, mittig
# - Blickrichtung -Y (Blender) = +Z im FBX, wie Mixamo es erwartet (Modell blickt im Original nach +Y)
# - Texturen ins FBX einbetten
import math
import os
import sys

import bpy
from mathutils import Vector

src, texdir, dst = [os.path.abspath(a) for a in sys.argv[sys.argv.index("--") + 1:][:3]]
HEIGHT = 1.75
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.fbx(filepath=src)
obs = [o for o in bpy.data.objects if o.type == "MESH"]
for o in [o for o in bpy.data.objects if o.type != "MESH"]:
    bpy.data.objects.remove(o)
for o in obs:
    o.select_set(True)
bpy.context.view_layer.objects.active = obs[0]
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)

lo = Vector((min(v.co.x for o in obs for v in o.data.vertices), min(v.co.y for o in obs for v in o.data.vertices), min(v.co.z for o in obs for v in o.data.vertices)))
hi = Vector((max(v.co.x for o in obs for v in o.data.vertices), max(v.co.y for o in obs for v in o.data.vertices), max(v.co.z for o in obs for v in o.data.vertices)))
s = HEIGHT / (hi.z - lo.z)
shift = Vector((-(lo.x + hi.x) / 2, -(lo.y + hi.y) / 2, -lo.z))
for o in obs:
    for v in o.data.vertices:
        p = (v.co + shift) * s
        v.co = Vector((-p.x, -p.y, p.z))   # 180 Grad um Z: Blick von +Y nach -Y
    o.data.update()
print("OVERLORD skaliert", round(s, 4), "hoehe", HEIGHT)

# Texturen sicher auf der Platte haben (FBX-Einbettung braucht Dateipfade)
for img in bpy.data.images:
    if img.packed_file or not os.path.exists(bpy.path.abspath(img.filepath)):
        name = "mata.png" if "2" in img.name else "badan.png"
        p = os.path.join(texdir, name)
        if os.path.exists(p):
            img.filepath = p
            img.reload()
    print("OVERLORD bild", img.name, img.filepath, img.size[:])

bpy.ops.export_scene.fbx(filepath=dst, use_selection=False, object_types={"MESH"},
                         path_mode="COPY", embed_textures=True, add_leaf_bones=False)
print("OVERLORD fbx", dst, os.path.getsize(dst) // 1024, "KB")
