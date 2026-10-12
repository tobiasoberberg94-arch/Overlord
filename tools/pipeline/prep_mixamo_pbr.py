# Blender: KI-/Scan-Modell (ein Mesh, PBR-Texturen) fuer Mixamo vorbereiten
#   blender -b -P prep_mixamo_pbr.py -- <modell.fbx> <texturordner> <ziel.fbx> [hoehe_m] [dreiecke] [drehung_z_grad]
# Erwartet im Texturordner Material_01_{BaseColor,Normal,Roughness,Metallic}.png.
# - Polygone reduzieren (Standard 40.000 Dreiecke), Fuesse auf z=0, Hoehe skalieren
# - Blickrichtung pruefen: Gesicht muss nach -Y (Blender) = +Z (glTF/Mixamo) zeigen
# - Texturen auf 2048 px verkleinern (BaseColor als JPG), PBR-Material neu aufbauen, einbetten
import os
import sys

import bpy
from mathutils import Vector

args = sys.argv[sys.argv.index("--") + 1:]
src, texdir, dst = [os.path.abspath(a) for a in args[:3]]
HEIGHT = float(args[3]) if len(args) > 3 else 1.85
TRIS = int(args[4]) if len(args) > 4 else 40000
ROT_Z = float(args[5]) if len(args) > 5 else 0.0   # z. B. -90, wenn das Modell nach +X blickt
MAX_TEX = 2048

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.fbx(filepath=src)
for o in [o for o in bpy.data.objects if o.type != "MESH"]:
    bpy.data.objects.remove(o)
obs = [o for o in bpy.data.objects if o.type == "MESH"]
for o in obs:
    o.select_set(True)
bpy.context.view_layer.objects.active = obs[0]
if len(obs) > 1:
    bpy.ops.object.join()
ob = bpy.context.view_layer.objects.active
if ROT_Z:
    import math
    ob.rotation_euler.z += math.radians(ROT_Z)
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)

# Reduzieren
tris = sum(len(p.vertices) - 2 for p in ob.data.polygons)
if tris > TRIS:
    mod = ob.modifiers.new("dec", "DECIMATE")
    mod.ratio = TRIS / tris
    mod.use_collapse_triangulate = True
    bpy.ops.object.modifier_apply(modifier="dec")
print("OVERLORD dreiecke", tris, "->", sum(len(p.vertices) - 2 for p in ob.data.polygons))

# Skalieren, Fuesse auf 0, mittig
co = [v.co for v in ob.data.vertices]
lo = Vector((min(c.x for c in co), min(c.y for c in co), min(c.z for c in co)))
hi = Vector((max(c.x for c in co), max(c.y for c in co), max(c.z for c in co)))
s = HEIGHT / (hi.z - lo.z)
off = Vector(((lo.x + hi.x) / 2, (lo.y + hi.y) / 2, lo.z))
for v in ob.data.vertices:
    v.co = (v.co - off) * s
ob.data.update()
print("OVERLORD hoehe", HEIGHT, "skala", round(s, 4))


# Texturen verkleinern
def tex(key, jpg):
    p = os.path.join(texdir, "Material_01_%s.png" % key)
    if not os.path.exists(p):
        return None
    img = bpy.data.images.load(p)
    w, h = img.size
    if max(w, h) > MAX_TEX:
        img.scale(MAX_TEX * w // max(w, h), MAX_TEX * h // max(w, h))
    out = os.path.join(os.path.dirname(dst), "%s_%s.%s" % (os.path.splitext(os.path.basename(dst))[0], key.lower(), "jpg" if jpg else "png"))
    img.filepath_raw = out
    img.file_format = "JPEG" if jpg else "PNG"
    img.save()
    img.filepath = out
    img.reload()
    if key != "BaseColor":
        img.colorspace_settings.name = "Non-Color"
    return img


mat = bpy.data.materials.new("Body")
mat.use_nodes = True
nt = mat.node_tree
bsdf = nt.nodes["Principled BSDF"]
for key, socket, jpg in (("BaseColor", "Base Color", True), ("Roughness", "Roughness", True), ("Metallic", "Metallic", True), ("Normal", None, False)):
    img = tex(key, jpg)
    if not img:
        continue
    t = nt.nodes.new("ShaderNodeTexImage")
    t.image = img
    if socket:
        nt.links.new(t.outputs["Color"], bsdf.inputs[socket])
    else:
        nm = nt.nodes.new("ShaderNodeNormalMap")
        nt.links.new(t.outputs["Color"], nm.inputs["Color"])
        nt.links.new(nm.outputs["Normal"], bsdf.inputs["Normal"])
    print("OVERLORD textur", key, img.size[:])
ob.data.materials.clear()
ob.data.materials.append(mat)

bpy.ops.export_scene.fbx(filepath=dst, use_selection=False, object_types={"MESH"},
                         path_mode="COPY", embed_textures=True, add_leaf_bones=False)
print("OVERLORD fbx", dst, os.path.getsize(dst) // 1024, "KB")
