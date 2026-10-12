# Blender: Unreal-Export (level.fbx + materials.json + textures/) -> Godot-Ort tombs.glb
#   blender -b -P build_tombs.py -- <Export-Ordner> <ziel.glb>
# - Materialien neu aufsetzen (Basisfarbe + Normal, Texturen auf 1024 px)
# - schwere Meshes reduzieren
# - Anker setzen (Spawn, Gate, Keeper, Slot1..6, Lamp_*) per Raycast auf freie Bodenflaechen
# - so verschieben, dass Spawn bei (0,0,0) liegt; Ausgabe anchors.json fuer locations.json
import json
import math
import os
import sys

import bpy
import numpy
from mathutils import Vector
from mathutils.bvhtree import BVHTree

exp_dir, dst = [os.path.abspath(a) for a in sys.argv[sys.argv.index("--") + 1:][:2]]
MAX_TEX = 1024
DECIMATE_OVER = 800   # Flaechen; darueber wird reduziert
DECIMATE_RATIO = 0.3

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.fbx(filepath=os.path.join(exp_dir, "level.fbx"))
info = json.load(open(os.path.join(exp_dir, "materials.json"), encoding="utf-8"))
tex_dir = os.path.join(exp_dir, "textures")
small_dir = os.path.join(os.path.dirname(os.path.abspath(dst)), "_tex1024")
os.makedirs(small_dir, exist_ok=True)

cams = [o.matrix_world.translation.copy() for o in bpy.data.objects if o.type == "CAMERA"]
lamps = [(o.matrix_world.translation.copy(), tuple(o.data.color)) for o in bpy.data.objects if o.type == "LIGHT"]
for o in [o for o in bpy.data.objects if o.type in ("CAMERA", "LIGHT")]:
    bpy.data.objects.remove(o)

# Studio-/Hilfsgeometrie der Showcase-Map entfernen
for o in [o for o in bpy.data.objects if o.type == "MESH"]:
    names = {m.name for m in o.data.materials if m}
    if "MI_StudioMaterial" in names:
        print("OVERLORD entferne Hilfsobjekt", o.name, [round(d, 1) for d in o.dimensions])
        bpy.data.objects.remove(o)

# --- Texturen verkleinern ------------------------------------------------------
_cache = {}


def small_image(fname, is_normal):
    if not fname:
        return None
    if fname in _cache:
        return _cache[fname]
    src = os.path.join(tex_dir, fname)
    if not os.path.exists(src):
        return None
    img = bpy.data.images.load(src)
    w, h = img.size
    s = min(1.0, (MAX_TEX // (2 if is_normal else 1)) / max(w, h, 1))
    if s < 1.0:
        img.scale(max(1, int(w * s)), max(1, int(h * s)))
    has_alpha = False
    if not is_normal and img.channels == 4:
        px = numpy.empty(len(img.pixels), dtype=numpy.float32)
        img.pixels.foreach_get(px)
        has_alpha = bool(px[3::4].min() < 0.95)
    ext = ".png" if has_alpha else ".jpg"
    out = os.path.join(small_dir, os.path.splitext(fname)[0] + ext)
    img.filepath_raw = out
    img.file_format = "PNG" if has_alpha else "JPEG"
    img.save()
    img.reload()
    if is_normal:
        img.colorspace_settings.name = "Non-Color"
    _cache[fname] = (img, has_alpha)
    return _cache[fname]


# --- Materialien neu aufsetzen -------------------------------------------------
def base_name(n):
    # Blender haengt bei Duplikaten .001 an, der UE-Export manchmal _0/_1
    n = n.split(".")[0]
    if n in info["materials"]:
        return n
    for suffix in ("_0", "_1"):
        if n.endswith(suffix) and n[: -len(suffix)] in info["materials"]:
            return n[: -len(suffix)]
    return n


for mat in bpy.data.materials:
    entry = info["materials"].get(base_name(mat.name), {})
    mat.use_nodes = True
    nt = mat.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
    nt.links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])
    bsdf.inputs["Roughness"].default_value = 0.85
    low = mat.name.lower()
    bc = small_image(entry.get("basecolor"), False)
    if bc:
        t = nt.nodes.new("ShaderNodeTexImage")
        t.image = bc[0]
        nt.links.new(t.outputs["Color"], bsdf.inputs["Base Color"])
        if bc[1]:
            nt.links.new(t.outputs["Alpha"], bsdf.inputs["Alpha"])
            mat.blend_method = "CLIP"
            mat.alpha_threshold = 0.4
    else:
        bsdf.inputs["Base Color"].default_value = (0.35, 0.36, 0.34, 1)
    nm = small_image(entry.get("normal"), True)
    if nm:
        t = nt.nodes.new("ShaderNodeTexImage")
        t.image = nm[0]
        n = nt.nodes.new("ShaderNodeNormalMap")
        nt.links.new(t.outputs["Color"], n.inputs["Color"])
        nt.links.new(n.outputs["Normal"], bsdf.inputs["Normal"])
    if "glass" in low or "translucent" in low:
        bsdf.inputs["Alpha"].default_value = 0.25
        bsdf.inputs["Roughness"].default_value = 0.1
        mat.blend_method = "BLEND"
    if "decal" in low:
        mat.blend_method = "CLIP"

# --- Polygone reduzieren (pro Mesh-Datenblock, Instanzen teilen ihn) ----------
done = set()
dg = bpy.context.evaluated_depsgraph_get()
before = sum(len(o.data.polygons) for o in bpy.data.objects if o.type == "MESH")
for o in [o for o in bpy.data.objects if o.type == "MESH"]:
    me = o.data
    if me.name in done or len(me.polygons) <= DECIMATE_OVER:
        continue
    done.add(me.name)
    mod = o.modifiers.new("dec", "DECIMATE")
    mod.ratio = DECIMATE_RATIO
    dg.update()
    new = bpy.data.meshes.new_from_object(o.evaluated_get(dg))
    o.modifiers.remove(mod)
    users = [u for u in bpy.data.objects if u.data == me]
    for u in users:
        u.data = new
after = sum(len(o.data.polygons) for o in bpy.data.objects if o.type == "MESH")
print("OVERLORD flaechen", before, "->", after)

# --- Raycast-Hilfen ------------------------------------------------------------
meshes = [o for o in bpy.data.objects if o.type == "MESH"]
verts, polys = [], []
for o in meshes:
    mw = o.matrix_world
    base = len(verts)
    verts.extend(mw @ v.co for v in o.data.vertices)
    polys.extend([base + i for i in p.vertices] for p in o.data.polygons)
bvh = BVHTree.FromPolygons(verts, polys)


def floor_at(p, up=1.6):
    hit = bvh.ray_cast(Vector((p.x, p.y, p.z + up)), Vector((0, 0, -1)), 6.0)
    return hit[0]


def free(p, d, maxd=30.0):
    o = p + Vector((0, 0, 1.0))
    hit = bvh.ray_cast(o, d, maxd)
    return hit[3] if hit[0] is not None else maxd


DIRS = [Vector((math.cos(a), math.sin(a), 0)) for a in [i * math.pi / 8 for i in range(16)]]

def floor_ok(f):
    return f is not None and abs(f.z) < 0.3


lo = Vector((min(v.x for v in verts), min(v.y for v in verts), 0))
hi = Vector((max(v.x for v in verts), max(v.y for v in verts), 0))
best = None
zs = []
x = lo.x + 0.5
while x < hi.x:
    y = lo.y + 0.5
    while y < hi.y:
        f = floor_at(Vector((x, y, 0.0)))
        if f is not None:
            zs.append(round(f.z, 1))
        if floor_ok(f) and bvh.ray_cast(f + Vector((0, 0, 0.5)), Vector((0, 0, 1)), 12.0)[0] is not None:
            dists = [free(f, d) for d in DIRS]
            if sum(1 for d in dists if d >= 30.0) <= 3 and min(dists) >= 1.2:
                score = sum(sorted(dists)[-8:]) + 4 * min(dists)
                if not best or score > best[0]:
                    best = (score, f, dists)
        y += 1.0
    x += 1.0
from collections import Counter
print("OVERLORD boden-z", Counter(zs).most_common(8))
print("OVERLORD bester raum", best and ([round(v, 1) for v in best[1]], [round(d, 1) for d in best[2]]))
if not best:
    raise SystemExit("OVERLORD: kein Innenraum gefunden")
_, spawn, dists = best
i_far = max(range(len(DIRS)), key=lambda i: dists[i])
fwd = DIRS[i_far]
look = min(dists[i_far] - 2.0, 9.0)
keeper = floor_at(spawn + fwd * look)
if not floor_ok(keeper):
    keeper = spawn + fwd * look
# Gate seitlich (nicht hinter dem Spawn, sonst fuellt sein Licht das Kamerabild)
i_side = max(((i_far + 4) % 16, (i_far + 12) % 16), key=lambda i: dists[i])
back = DIRS[i_side]
gate = floor_at(spawn + back * max(1.2, min(dists[i_side] - 1.0, 3.5)))
if not floor_ok(gate):
    gate = spawn.copy()
slots = []
side = Vector((-fwd.y, fwd.x, 0))
for k in range(6):
    a = (k - 2.5) * 0.45
    p = keeper - fwd * 3.5 + (side * math.sin(a) - fwd * (1 - math.cos(a))) * 3.5
    f = floor_at(p)
    if floor_ok(f) and free(f, (keeper - f).normalized(), 30) > 1.0:
        slots.append(f)

# Begegnung: freier Punkt seitlich, ca. 8-12 m entfernt
enc = None
for i in sorted(range(16), key=lambda i: -dists[i]):
    if i == i_far:
        continue
    d = min(dists[i] - 1.5, 12.0)
    if d > 5:
        enc = floor_at(spawn + DIRS[i] * d)
        if floor_ok(enc):
            break

# --- Verschieben: Spawn auf Ursprung ------------------------------------------
shift = -spawn
for o in bpy.data.objects:
    if o.parent is None:
        o.location += shift


def anchor(name, p, yaw_dir=None):
    e = bpy.data.objects.new(name, None)
    e.location = p + shift
    if yaw_dir is not None:
        e.rotation_euler.z = math.atan2(yaw_dir.y, yaw_dir.x) - math.pi / 2
    bpy.context.scene.collection.objects.link(e)
    return e


anchor("Spawn", spawn, fwd)
anchor("Gate", gate)
anchor("Keeper", keeper)
for k, s in enumerate(slots, 1):
    anchor("Slot%d" % k, s)

# Lampen als echte Punktlichter (Godot normalisiert Energie/Reichweite beim Laden)
for k, (p, col) in enumerate(lamps, 1):
    ld = bpy.data.lights.new("Lamp_%d" % k, "POINT")
    ld.color = col
    ld.energy = 60
    ld.shadow_soft_size = 0.2
    lo = bpy.data.objects.new("Lamp_%d" % k, ld)
    lo.location = p + shift
    bpy.context.scene.collection.objects.link(lo)


def godot(p):  # Blender Z-up -> Godot Y-up
    q = p + shift
    return [round(q.x, 2), round(q.z, 2), round(-q.y, 2)]


report = {"spawn": godot(spawn), "gate": godot(gate), "keeper": godot(keeper), "slots": len(slots),
          "encounter_at": [godot(enc)[0], godot(enc)[2]] if enc else None, "lamps": len(lamps),
          "free_dists": [round(d, 1) for d in dists]}
json.dump(report, open(os.path.join(os.path.dirname(os.path.abspath(dst)), "tombs_anchors.json"), "w"), indent=1)
print("OVERLORD anker", report)

bpy.ops.export_scene.gltf(filepath=dst, export_format="GLB", export_yup=True, export_apply=True,
                          export_lights=True, export_cameras=False, export_extras=False,
                          export_image_format="AUTO")
print("OVERLORD glb", dst, os.path.getsize(dst) // (1024 * 1024), "MB")
