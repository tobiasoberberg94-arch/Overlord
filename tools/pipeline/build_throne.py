# Blender: Thronsaal der 10. Ebene aus Lost-Temple-Bauteilen (Unreal-Export via export_meshes.py)
#   blender -b -P build_throne.py -- <Export-Ordner> <ziel.glb>
# Grundriss (Blender: +Y = Richtung Thron; im Spiel -Z):
#   Halle 20 x 60 m, Wände 10 m, Decke aus Kassettenplatten, zwei Säulenreihen (x = +-6),
#   Thronpyramide mit Löwenthron am Ende (y = +24), flankiert von zwei Kolossalstatuen,
#   Spitzbogentor am Eingang (y = -30), Kronleuchter über dem Mittelgang.
# Anker (Empties): Spawn, Gate, Throne, Keeper, Table, Desk, Slot1..10,
#   Banner_n (Gildenbanner), Fire_n (Feuer), Lamp_n (Kronleuchterlicht), Violet_n (Akzentlicht)
import json
import math
import os
import sys

import bpy
import numpy
from mathutils import Matrix, Vector

exp_dir, dst = [os.path.abspath(a) for a in sys.argv[sys.argv.index("--") + 1:][:2]]
MAX_TEX = 2048
# Dreiecksbudget je Vorlage (Instanzen teilen die Geometrie)
TRI_CAP = {}   # keine Reduktion – volle Originalqualität, Godot erzeugt LOD-Stufen
info = json.load(open(os.path.join(exp_dir, "materials.json"), encoding="utf-8"))["materials"]
tex_dir = os.path.join(exp_dir, "textures")
small_dir = os.path.join(os.path.dirname(dst), "_throne_tex")
os.makedirs(small_dir, exist_ok=True)

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
lib = bpy.data.collections.new("lib")       # Vorlagen (nicht exportiert)
hall = bpy.data.collections.new("hall")
scene.collection.children.link(hall)


# --- Bauteile laden ----------------------------------------------------------------
def load(name):
    before = set(bpy.data.objects)
    bpy.ops.import_scene.fbx(filepath=os.path.join(exp_dir, "meshes", name + ".fbx"))
    new = [o for o in bpy.data.objects if o not in before]
    meshes = [o for o in new if o.type == "MESH"]
    for o in new:
        for c in o.users_collection:
            c.objects.unlink(o)
    for o in [o for o in new if o.type != "MESH"]:
        bpy.data.objects.remove(o)
    # Maßstab/Drehung in die Geometrie übernehmen, mehrere Teile zu einem Mesh
    for o in meshes:
        scene.collection.objects.link(o)
        o.select_set(True)
    bpy.context.view_layer.objects.active = meshes[0]
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    if len(meshes) > 1:
        bpy.ops.object.join()
    o = bpy.context.view_layer.objects.active
    cap = TRI_CAP.get(name)
    tris = sum(len(p.vertices) - 2 for p in o.data.polygons)
    if cap and tris > cap:
        mod = o.modifiers.new("dec", "DECIMATE")
        mod.ratio = cap / tris
        mod.use_collapse_triangulate = True
        bpy.ops.object.modifier_apply(modifier="dec")
        print("OVERLORD reduziert", name, tris, "->", sum(len(p.vertices) - 2 for p in o.data.polygons))
    o.select_set(False)
    scene.collection.objects.unlink(o)
    lib.objects.link(o)
    o.name = name
    return o


_tpl = {}


def tpl(name):
    if name not in _tpl:
        _tpl[name] = load(name)
    return _tpl[name]


def put(name, x, y, z=0.0, rot=0.0, s=1.0, sz=None, rx=0.0, anchor="bottom"):
    """Instanz platzieren: Unterkante (oder Oberkante) mittig auf (x, y, z)."""
    t = tpl(name)
    o = t.copy()                           # teilt die Mesh-Daten (Instanz)
    hall.objects.link(o)
    o.rotation_euler = (math.radians(rx), 0, math.radians(rot))
    o.scale = (s, s, s if sz is None else sz)
    o.location = (0, 0, 0)
    bpy.context.view_layer.update()
    bb = [o.matrix_world @ Vector(c) for c in o.bound_box]
    lo = Vector((min(v.x for v in bb), min(v.y for v in bb), min(v.z for v in bb)))
    hi = Vector((max(v.x for v in bb), max(v.y for v in bb), max(v.z for v in bb)))
    ref_z = lo.z if anchor == "bottom" else hi.z
    o.location = Vector((x - (lo.x + hi.x) / 2, y - (lo.y + hi.y) / 2, z - ref_z))
    return o


def size(name):
    t = tpl(name)
    return Vector(t.dimensions)


def empty(name, x, y, z=0.0, rot=0.0):
    e = bpy.data.objects.new(name, None)
    e.location = (x, y, z)
    e.rotation_euler.z = math.radians(rot)
    hall.objects.link(e)
    return e


W, L, H = 10.0, 30.0, 10.0          # halbe Breite, halbe Länge, Wandhöhe
PILLAR_X = 6.0
PILLAR_Y = [-22.5, -15.0, -7.5, 0.0, 7.5, 15.0]
DAIS_Y = 24.0

# --- Boden ---------------------------------------------------------------------------
for ix in range(4):
    for iy in range(12):
        x = -W + 2.5 + ix * 5
        y = -L + 2.5 + iy * 5
        put("SM_floor", x, y, -0.22)
# Zierfliesen-Streifen links/rechts des Mittelgangs (der Teppich liegt in der Mitte)
for iy in range(-10, 9):
    for sx in (-1, 1):
        put("SM_floordan", 3.25 * sx, iy * 2.5 + 1.25, -0.2)

# --- Decke (Kassetten nach unten) ----------------------------------------------------
for ix in range(4):
    for iy in range(12):
        put("SM_ceiling01", -W + 2.5 + ix * 5, -L + 2.5 + iy * 5, H, rx=180.0)

# --- Wände: zwei Reihen Mauerplatten, unten prunkvolle Reliefs ---------------------------
for iy in range(12):
    y = -L + 2.5 + iy * 5
    for sx in (-1, 1):
        for row in range(2):
            put("SM_brick", sx * W, y, row * 5.0, rot=90.0)
for ix in range(4):
    x = -W + 2.5 + ix * 5
    for row in range(2):
        put("SM_brick", x, L, row * 5.0)
        if ix in (0, 3) or row == 1:
            put("SM_brick", x, -L, row * 5.0)
# Eingangstor (Spitzbogen mit Tür) mittig in der Vorderwand
put("SM_wall01", 0, -L + 0.4, 0, rot=180.0, s=1.25)
# Wandreliefs zwischen den Säulen (Front zeigt in die Halle)
for y in [-18.75, -3.75, 11.25]:
    for sx in (-1, 1):
        put("SM_ceilingwall02", sx * (W - 1.0), y, 0.0, rot=-90.0 * sx, s=0.95)
for y in [-11.25, 3.75]:
    for sx in (-1, 1):
        put("SM_middlewall02", sx * (W - 0.7), y, 0.0, rot=-90.0 * sx)
# Zierleisten oben an den Wänden
for iy in range(12):
    y = -L + 2.5 + iy * 5
    for sx in (-1, 1):
        put("SM_updan", sx * (W - 0.3), y, H - 0.62, rot=90.0)

# --- Säulen: hohe Säule + Aufsatz bis unter die Decke, Querbalken zur Wand ------------------
for y in PILLAR_Y:
    for sx in (-1, 1):
        put("SM_middle_pillar", sx * PILLAR_X, y, 0.0)
        put("SM_middlepillar03", sx * PILLAR_X, y, 6.6, sz=(H - 6.6) / 2.91)
        put("SM_ceilingdan02", sx * (PILLAR_X + W) / 2, y, H - 0.56, rot=0.0, s=1.0)
# Längsbalken über den Säulenreihen
for iy in range(12):
    for sx in (-1, 1):
        put("SM_ceilingdan01", sx * PILLAR_X, -L + 2.5 + iy * 5, H - 0.66, rot=90.0)

# --- Thronbereich ----------------------------------------------------------------------
put("SM_understair02", 0, DAIS_Y, 0.0, s=1.15)                    # Stufenpyramide
dais_top = 1.7 * 1.15
put("SM_statuestair", 0, DAIS_Y + 1.0, dais_top - 0.05, s=0.6)    # Löwenthron
for sx in (-1, 1):
    put("SM_statuehuman", sx * 6.9, L - 3.2, 0.0, s=0.85)           # Kolossalstatuen
    put("SM_brizer", sx * 3.2, DAIS_Y - 5.6, 0.0, s=0.9)            # Feuerschalen vor dem Podest
    put("SM_longpot03", sx * 4.6, DAIS_Y - 4.6, 0.0, s=1.3)         # Pfauen
    put("SM_smallfence01b", sx * 6.6, DAIS_Y - 4.2, 0.0, rot=0.0, s=0.7)
# Rückwand hinter dem Thron: Relief
put("SM_ceilingwall02", 0, L - 0.8, 3.5, s=1.1)

# --- Ausstattung der Halle ---------------------------------------------------------------
for i, y in enumerate(PILLAR_Y):
    for sx in (-1, 1):
        if i % 2 == 0:
            put("SM_pot", sx * (W - 1.6), y, 0.0, s=1.2)
        else:
            put("SM_longpot03", sx * (W - 1.8), y, 0.0, s=1.1)
for y in [-18.75, -3.75, 11.25]:
    put("SM_smallbraizer02", 0, y, H - 0.2, s=1.8, anchor="top")    # Kronleuchter
for y in PILLAR_Y:
    for sx in (-1, 1):
        put("SM_smallbraizer01", sx * (PILLAR_X + 1.2), y + 3.75, H - 0.1, s=0.8, anchor="top")
for y in [-24.0, -12.0]:
    for sx in (-1, 1):
        put("SM_brizer", sx * 8.0, y, 0.0, s=0.7)

# --- Anker ------------------------------------------------------------------------------
empty("Spawn", 0, -21.0, 0.0, rot=0.0)
empty("Gate", 0, -27.0, 0.0)
empty("Throne", 0, DAIS_Y - 5.2, 0.0)
empty("Keeper", -2.6, DAIS_Y - 5.0, 0.0)
empty("Table", -4.3, -11.0, 0.0)
empty("Desk", 4.3, -11.0, 0.0)
n = 1
for i in range(5):
    for sx in (-1, 1):
        empty("Slot%d" % n, 3.6 * sx, 1.0 + i * 3.4, 0.0)
        n += 1
n = 1
for y in PILLAR_Y[1:]:
    for sx in (-1, 1):
        empty("Banner_%d" % n, sx * (W - 0.4), y, 9.2)
        n += 1
n = 1
for sx in (-1, 1):
    for y, h, k in [(DAIS_Y - 5.6, 1.7, "Fire"), (-24.0, 1.3, "Fire"), (-12.0, 1.3, "Fire")]:
        empty("%s_%d" % (k, n), sx * (3.2 if y > 0 else 8.0), y, h)
        n += 1
for i, y in enumerate([-18.75, -3.75, 11.25]):
    empty("Lamp_%d" % (i + 1), 0, y, H - 2.6)
empty("Violet_1", 0, L - 2.0, 6.0)
empty("Violet_2", 0, DAIS_Y, 4.0)

# --- Materialien: verkleinerte Texturen, PBR, beidseitig ----------------------------------
_cache = {}


def small(fname, normal):
    if not fname:
        return None
    if fname in _cache:
        return _cache[fname]
    src = os.path.join(tex_dir, fname)
    if not os.path.exists(src):
        return None
    img = bpy.data.images.load(src)
    w, h = img.size
    m = MAX_TEX
    if max(w, h) > m:
        img.scale(max(1, w * m // max(w, h)), max(1, h * m // max(w, h)))
    alpha = False
    if not normal and img.channels == 4:
        px = numpy.empty(len(img.pixels), dtype=numpy.float32)
        img.pixels.foreach_get(px)
        alpha = bool(px[3::4].min() < 0.5)
    out = os.path.join(small_dir, os.path.splitext(fname)[0] + (".png" if alpha else ".jpg"))
    img.filepath_raw = out
    img.file_format = "PNG" if alpha else "JPEG"
    img.save()
    img.reload()
    if normal:
        img.colorspace_settings.name = "Non-Color"
    _cache[fname] = (img, alpha)
    return _cache[fname]


for mat in bpy.data.materials:
    e = info.get(mat.name.split(".")[0], {})
    mat.use_nodes = True
    mat.use_backface_culling = False
    nt = mat.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    b = nt.nodes.new("ShaderNodeBsdfPrincipled")
    nt.links.new(b.outputs["BSDF"], out.inputs["Surface"])
    b.inputs["Roughness"].default_value = 0.7
    bc = small(e.get("basecolor"), False)
    if bc:
        t = nt.nodes.new("ShaderNodeTexImage")
        t.image = bc[0]
        nt.links.new(t.outputs["Color"], b.inputs["Base Color"])
        if bc[1]:
            nt.links.new(t.outputs["Alpha"], b.inputs["Alpha"])
            mat.blend_method = "CLIP"
    else:
        b.inputs["Base Color"].default_value = (0.12, 0.1, 0.1, 1)
    nm = small(e.get("normal"), True)
    if nm:
        t = nt.nodes.new("ShaderNodeTexImage")
        t.image = nm[0]
        n2 = nt.nodes.new("ShaderNodeNormalMap")
        nt.links.new(t.outputs["Color"], n2.inputs["Color"])
        nt.links.new(n2.outputs["Normal"], b.inputs["Normal"])
    # Gold/Bronze-Teile glänzen lassen
    low = mat.name.lower()
    if any(k in low for k in ("statuestair", "brizer", "braizer", "longpot", "pot", "weapon", "statuehuman")):
        b.inputs["Metallic"].default_value = 0.55
        b.inputs["Roughness"].default_value = 0.4

tris = sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for o in hall.objects if o.type == "MESH")
uniq = sum(sum(len(p.vertices) - 2 for p in t.data.polygons) for t in _tpl.values())
print("OVERLORD teile", len(hall.objects), "dreiecke gesamt", tris, "einzigartig", uniq)

# Nur die Halle exportieren
for o in list(scene.collection.objects):
    scene.collection.objects.unlink(o)
bpy.ops.export_scene.gltf(filepath=dst, export_format="GLB", export_yup=True, export_apply=True,
                          export_lights=False, export_cameras=False, export_extras=False,
                          use_active_collection=False, use_visible=False)
print("OVERLORD glb", dst, os.path.getsize(dst) // (1024 * 1024), "MB")
