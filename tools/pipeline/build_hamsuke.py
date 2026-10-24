# Hamsuke (Tripo-FBX, Vierbeiner ohne Mixamo) → ausgerichtetes, geriggtes und animiertes GLB für das Spiel.
#   blender.exe -b --python tools/pipeline/build_hamsuke.py [-- <Quellordner> [<Ziel-GLB>]]
# Quellordner (Standard C:/Projekte/Overlord/Hamsuke): hamsuke_tripo.fbx, hamsuke_basecolor.jpg, hamsuke_metallic.png,
# hamsuke_normal.png, hamsuke_roughness.png. Ziel (Standard): assets/models/characters/hamsuke.glb neben diesem Skript.
# Ablauf: FBX laden, Texturen zuweisen, Blick nach -Y/Füße auf z=0/Höhe 2,2 m, Skelett (Root, Hips, Body, Head, Ohren,
# Arme, Schwanzkette), Gewichte (nächster Knochen + Glättung, Schwanz entlang der Kette), zehn Aktionen (Idle, Walk, Run,
# Attack_Light, Attack_Heavy, Hit, Stagger, Death, Dodge, Block), GLB mit eingebetteten Texturen, Kontrollbilder.
import bpy, math, mathutils, time, os, sys
import numpy as np

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
SRC = (argv[0] if len(argv) > 0 else "C:/Projekte/Overlord/Hamsuke").replace("\\", "/").rstrip("/") + "/"
REPO = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..")).replace("\\", "/")
GLB = (argv[1] if len(argv) > 1 else REPO + "/assets/models/characters/hamsuke.glb").replace("\\", "/")
FBX = SRC + "hamsuke_tripo.fbx"
OUT = SRC + "build/"
os.makedirs(OUT, exist_ok=True)
SC = 2.2            # Zielhöhe ≈ 2,2 m (Tripo-Modell ist 1 m hoch)
t0 = time.time()

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.fbx(filepath=FBX)
ob = [o for o in bpy.data.objects if o.type == 'MESH'][0]
ob.name = "Hamsuke"
me = ob.data
me.name = "Hamsuke"

# ---------------------------------------------------------------- Texturen (Anhänge als webp)
role = {"Base": ("hamsuke_basecolor.jpg", "hamsuke_basecolor"), "Meta": ("hamsuke_metallic.png", "hamsuke_metallic"), "Norm": ("hamsuke_normal.png", "hamsuke_normal"), "Roug": ("hamsuke_roughness.png", "hamsuke_roughness")}
for img in list(bpy.data.images):
    for k, (f, nm) in role.items():
        if ("_" + k) in img.name:
            img.filepath = SRC + f
            img.source = 'FILE'
            img.reload()
            img.name = nm
mat = me.materials[0]
mat.name = "Hamsuke"
nt = mat.node_tree
for n in nt.nodes:
    if n.type == 'TEX_IMAGE' and n.image and n.image.name == "hamsuke_basecolor":
        nt.nodes.active = n
    if n.type == 'BSDF_PRINCIPLED':
        n.inputs["Specular IOR Level"].default_value = 0.3
print("Texturen:", [(i.name, i.size[:], i.file_format) for i in bpy.data.images])

# ---------------------------------------------------------------- Ausrichten: Blick nach -Y, Füße auf z=0, Höhe 2,2 m
ob.rotation_euler = (0.0, 0.0, math.radians(-90.0))
ob.scale = (SC, SC, SC)
ob.location = (0.0, 0.0, 0.499 * SC)
bpy.context.view_layer.objects.active = ob
for o in bpy.data.objects:
    o.select_set(o == ob)
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
N = len(me.vertices)
co = np.empty(N * 3, dtype=np.float64)
me.vertices.foreach_get("co", co)
co = co.reshape(N, 3)
print("Maße nach Ausrichtung: x %.2f..%.2f  y %.2f..%.2f  z %.2f..%.2f" % (co[:, 0].min(), co[:, 0].max(), co[:, 1].min(), co[:, 1].max(), co[:, 2].min(), co[:, 2].max()))

# ---------------------------------------------------------------- Schwanz-Mittellinie aus dem Mesh
# Schwanz = alles hinter der Rückenlinie des Rumpfes (y > 0,62 m; oberhalb des Rückens y > 0,42 m)
y_thr = np.where(co[:, 2] >= 1.45, 0.42, 0.62)
is_tail = co[:, 1] > y_thr
cz = np.arange(0.1, 2.25, 0.1)
cl = []
for z in cz:
    sel = is_tail & (co[:, 2] >= z - 0.05) & (co[:, 2] < z + 0.05)
    if sel.sum() > 20:
        cl.append((float(co[sel, 0].mean()), float(co[sel, 1].mean()), float(z)))
cl = np.array(cl)
print("Schwanz-Vertices %d, Mittellinie: %s" % (is_tail.sum(), [tuple(round(v, 2) for v in r) for r in cl[::3]]))
def tail_at(z):
    return (float(np.interp(z, cl[:, 2], cl[:, 0])), float(np.interp(z, cl[:, 2], cl[:, 1])), z)
TJ = [tail_at(0.15), tail_at(0.7), tail_at(1.25), tail_at(1.8), tail_at(float(cl[-1, 2]))]

# ---------------------------------------------------------------- Skelett
arm_data = bpy.data.armatures.new("HamsukeRig")
arm = bpy.data.objects.new("HamsukeRig", arm_data)
bpy.context.scene.collection.objects.link(arm)
bpy.context.view_layer.objects.active = arm
arm.select_set(True)
bpy.ops.object.mode_set(mode='EDIT')
EB = {}
def bone(name, head, tail, parent=None, connect=False):
    b = arm_data.edit_bones.new(name)
    b.head = mathutils.Vector(head)
    b.tail = mathutils.Vector(tail)
    if parent:
        b.parent = EB[parent]
        b.use_connect = connect
    EB[name] = b
    return b
# (x = rechts/links, y = hinten(+)/vorn(-), z = Höhe)
bone("Root", (0, 0, 0), (0, 0, 0.35))
bone("Hips", (0, 0.1, 0.02), (0, 0.15, 0.5), "Root")
bone("Body", (0, 0.15, 0.5), (0, -0.1, 1.35), "Hips", True)
bone("Head", (0, -0.3, 1.3), (0, -0.72, 1.72), "Body")
bone("Ear_L", (-0.36, -0.45, 1.55), (-0.46, -0.5, 1.85), "Head")
bone("Ear_R", (0.36, -0.45, 1.55), (0.46, -0.5, 1.85), "Head")
bone("Arm_L", (-0.4, -0.5, 1.2), (-0.46, -0.86, 0.85), "Body")
bone("Arm_R", (0.4, -0.5, 1.2), (0.46, -0.86, 0.85), "Body")
bone("Tail1", TJ[0], TJ[1], "Hips")
bone("Tail2", TJ[1], TJ[2], "Tail1", True)
bone("Tail3", TJ[2], TJ[3], "Tail2", True)
bone("Tail4", TJ[3], TJ[4], "Tail3", True)
bpy.ops.object.mode_set(mode='OBJECT')

# ---------------------------------------------------------------- Gewichte: nächster Knochen (Abstand/Radius), dann geglättet
W_BONES = [("Hips", 0.75), ("Body", 0.9), ("Head", 0.55), ("Ear_L", 0.17), ("Ear_R", 0.17), ("Arm_L", 0.2), ("Arm_R", 0.2),
           ("Tail1", 0.15), ("Tail2", 0.14), ("Tail3", 0.14), ("Tail4", 0.14)]
def seg_dist(p, a, b):
    ab = b - a
    t = np.clip(((p - a) @ ab) / (ab @ ab), 0.0, 1.0)
    proj = a + t[:, None] * ab
    return np.linalg.norm(p - proj, axis=1)
scores = np.empty((N, len(W_BONES)))
for i, (nm, r) in enumerate(W_BONES):
    b = arm_data.bones[nm]
    scores[:, i] = seg_dist(co, np.array(b.head_local), np.array(b.tail_local)) / r
best = np.argmin(scores, axis=1)
W = np.zeros((N, len(W_BONES)))
W[np.arange(N), best] = 1.0
# Glätten über Kanten
E = len(me.edges)
ev = np.empty(E * 2, dtype=np.int64)
me.edges.foreach_get("vertices", ev)
ev = ev.reshape(E, 2)
deg = np.bincount(ev[:, 0], minlength=N) + np.bincount(ev[:, 1], minlength=N)
deg = np.maximum(deg, 1)[:, None]
for it in range(12):
    acc = np.zeros_like(W)
    np.add.at(acc, ev[:, 0], W[ev[:, 1]])
    np.add.at(acc, ev[:, 1], W[ev[:, 0]])
    W = 0.4 * W + 0.6 * acc / deg
# Schwanz: Lage t entlang der Kette (0..4) → Zeltgewichte zwischen Nachbarknochen, Basis mischt mit Hips
TAIL = ["Tail1", "Tail2", "Tail3", "Tail4"]
tidx = [[nm for nm, r in W_BONES].index(t) for t in TAIL]
hips_i = [nm for nm, r in W_BONES].index("Hips")
chain = [np.array(arm_data.bones["Tail1"].head_local)] + [np.array(arm_data.bones[t].tail_local) for t in TAIL]
# Schwanz = alles nahe der Schwanzkette (dicker Schlangenschwanz, Radius ≈ 0,13 m), oberhalb der Hüfte großzügiger
# Rumpf & Co. ohne Schwanzknochen neu zuweisen
scores_nt = scores.copy()
scores_nt[:, tidx] = 1e9
best = np.argmin(scores_nt, axis=1)
W = np.zeros((N, len(W_BONES)))
W[np.arange(N), best] = 1.0
for it in range(12):
    acc = np.zeros_like(W)
    np.add.at(acc, ev[:, 0], W[ev[:, 1]])
    np.add.at(acc, ev[:, 1], W[ev[:, 0]])
    W = 0.4 * W + 0.6 * acc / deg
pt = co[is_tail]
tpar = np.zeros(len(pt))
dbest = np.full(len(pt), 1e9)
for si in range(4):
    a_, b_ = chain[si], chain[si + 1]
    ab = b_ - a_
    tt = np.clip(((pt - a_) @ ab) / (ab @ ab), 0.0, 1.0)
    d = np.linalg.norm(pt - (a_ + tt[:, None] * ab), axis=1)
    sel = d < dbest
    dbest[sel] = d[sel]
    tpar[sel] = si + tt[sel]
Wt = np.zeros((len(pt), len(W_BONES)))
u_ = tpar - 0.5
for si in range(4):
    Wt[:, tidx[si]] = np.clip(1.0 - np.abs(u_ - si) / 1.5, 0.0, 1.0)
base = np.clip(0.5 - tpar, 0.0, 0.5) * 2.0      # ganz unten noch mit der Hüfte verbunden
Wt[:, hips_i] = np.maximum(Wt[:, hips_i], base)
W[is_tail] = Wt / np.maximum(Wt.sum(axis=1, keepdims=True), 1e-6)
for it in range(8):
    acc = np.zeros_like(W)
    np.add.at(acc, ev[:, 0], W[ev[:, 1]])
    np.add.at(acc, ev[:, 1], W[ev[:, 0]])
    sm = 0.3 * W + 0.7 * acc / deg
    W[is_tail] = sm[is_tail]
W[W < 0.02] = 0.0
print("Schwanz-Vertices:", int(is_tail.sum()))
tsel = is_tail & (co[:, 2] > 0.9)
print("Schwanz-Gewichte (Mittel, y>0.6 z>0.4, n=%d):" % tsel.sum(), {nm: round(float(W[tsel, i].mean()), 3) for i, (nm, r) in enumerate(W_BONES)})
W /= np.maximum(W.sum(axis=1, keepdims=True), 1e-6)
print("Gewichte: Anteil je Knochen", {nm: round(float((best == i).mean()), 3) for i, (nm, r) in enumerate(W_BONES)})
LEVELS = 40
for i, (nm, r) in enumerate(W_BONES):
    vg = ob.vertex_groups.new(name=nm)
    col = W[:, i]
    q = np.rint(col * LEVELS).astype(int)
    for lv in range(1, LEVELS + 1):
        idx = np.nonzero(q == lv)[0]
        if len(idx):
            vg.add(idx.tolist(), lv / LEVELS, 'REPLACE')
ob.parent = arm
mod = ob.modifiers.new("Armature", 'ARMATURE')
mod.object = arm
print("Rig fertig nach %.0f s" % (time.time() - t0))

# ---------------------------------------------------------------- Animationen
scene = bpy.context.scene
scene.render.fps = 24
pb = arm.pose.bones
for b in pb:
    b.rotation_mode = 'XYZ'
arm.animation_data_create()
def reset_pose():
    for b in pb:
        b.rotation_euler = (0, 0, 0)
        b.location = (0, 0, 0)
        b.scale = (1, 1, 1)
def key(bname, frame, rot=None, loc=None, scale=None):
    b = pb[bname]
    if rot is not None:
        b.rotation_euler = tuple(math.radians(a) for a in rot)
        b.keyframe_insert("rotation_euler", frame=frame)
    if loc is not None:
        b.location = loc
        b.keyframe_insert("location", frame=frame)
    if scale is not None:
        b.scale = scale
        b.keyframe_insert("scale", frame=frame)
def begin(name):
    reset_pose()
    act = bpy.data.actions.new(name)
    act.use_fake_user = True
    arm.animation_data.action = act
    return act
def finish(act, last):
    act.frame_range = (1, last)
    act.use_frame_range = True
    tr = arm.animation_data.nla_tracks.new()
    tr.name = act.name
    tr.strips.new(act.name, 1, act)
    arm.animation_data.action = None

# Idle: atmen, Ohren zucken, Schwanz wiegt sich (48 Bilder, Schleife)
a = begin("Idle")
for f, s in [(1, 1.0), (24, 1.025), (48, 1.0)]:
    key("Body", f, scale=(s, 1.0 + (s - 1.0) * 1.3, s))
for f, r in [(1, 0), (24, 2.5), (48, 0)]:
    key("Head", f, rot=(r, 0, 0))
for f, r in [(1, 0), (14, 0), (17, -16), (20, 0), (48, 0)]:
    key("Ear_L", f, rot=(0, 0, r))
for f, r in [(1, 0), (30, 0), (33, 16), (36, 0), (48, 0)]:
    key("Ear_R", f, rot=(0, 0, r))
for f, r in [(1, 0), (12, 6), (24, 0), (36, -6), (48, 0)]:
    key("Tail2", f, rot=(0, 0, r))
    key("Tail3", f, rot=(0, 0, -r * 0.8))
for f, r in [(1, 0), (24, 7), (48, 0)]:
    key("Tail4", f, rot=(r, 0, 0))
    key("Arm_L", f, rot=(r * 0.6, 0, 0))
    key("Arm_R", f, rot=(r * 0.6, 0, 0))
for f, z in [(1, 0.0), (24, 0.012), (48, 0.0)]:
    key("Root", f, loc=(0, 0, z))
for f, r in [(1, 0), (12, 1.5), (24, 0), (36, -1.5), (48, 0)]:
    key("Hips", f, rot=(0, 0, r))
finish(a, 48)

# Walk / Run: hüpfender Watschelgang (zwei Sätze je Schleife)
def hop_cycle(name, L, hop, tilt, waddle, arm_amp, tail_amp, head_amp):
    a = begin(name)
    h = L // 2
    for f, z in [(1, 0.0), (1 + h // 2, hop), (1 + h, 0.0), (1 + h + h // 2, hop), (1 + L, 0.0)]:
        key("Root", f, loc=(0, 0, z))
    for f, r in [(1, tilt), (1 + h // 2, tilt + 5), (1 + h, tilt), (1 + h + h // 2, tilt + 5), (1 + L, tilt)]:
        key("Body", f, rot=(r, 0, 0))
    for f, r in [(1, waddle), (1 + h, -waddle), (1 + L, waddle)]:
        key("Hips", f, rot=(0, 0, r))
    for f, r in [(1, -head_amp), (1 + h // 2, head_amp), (1 + h, -head_amp), (1 + h + h // 2, head_amp), (1 + L, -head_amp)]:
        key("Head", f, rot=(r, 0, 0))
    for f, r in [(1, arm_amp), (1 + h, -arm_amp), (1 + L, arm_amp)]:
        key("Arm_L", f, rot=(r, 0, 0))
        key("Arm_R", f, rot=(-r, 0, 0))
        key("Tail2", f, rot=(0, 0, tail_amp if r > 0 else -tail_amp))
        key("Tail3", f, rot=(0, 0, -tail_amp * 0.7 if r > 0 else tail_amp * 0.7))
        key("Tail4", f, rot=(tail_amp * 0.5 if r > 0 else -tail_amp * 0.5, 0, 0))
    finish(a, L)
hop_cycle("Walk", 20, 0.10, 6, 4, 20, 9, 3)
hop_cycle("Run", 14, 0.22, 14, 5, 32, 14, 5)

# Attack_Light: Biss nach vorn (15 Bilder)
a = begin("Attack_Light")
for f, r in [(1, 0), (4, -8), (8, 25), (15, 0)]:
    key("Body", f, rot=(r, 0, 0))
for f, r in [(1, 0), (4, -10), (8, 18), (15, 0)]:
    key("Head", f, rot=(r, 0, 0))
for f, r in [(1, 0), (4, -20), (8, 38), (15, 0)]:
    key("Arm_L", f, rot=(r, 0, 0))
    key("Arm_R", f, rot=(r, 0, 0))
for f, y in [(1, 0.0), (4, 0.08), (8, -0.25), (15, 0.0)]:
    key("Root", f, loc=(0, y, 0))
for f, r in [(1, 0), (8, -12), (15, 0)]:
    key("Tail2", f, rot=(r, 0, 0))
finish(a, 15)

# Attack_Heavy: aufbäumen und niederstampfen (26 Bilder)
a = begin("Attack_Heavy")
for f, z in [(1, 0.0), (10, 0.35), (16, -0.05), (26, 0.0)]:
    key("Root", f, loc=(0, 0, z))
for f, r in [(1, 0), (10, -25), (16, 30), (26, 0)]:
    key("Body", f, rot=(r, 0, 0))
for f, r in [(1, 0), (10, -15), (16, 25), (26, 0)]:
    key("Head", f, rot=(r, 0, 0))
for f, r in [(1, 0), (10, -45), (16, 48), (26, 0)]:
    key("Arm_L", f, rot=(r, 0, 0))
    key("Arm_R", f, rot=(r, 0, 0))
for f, r in [(1, 0), (10, 10), (16, -8), (26, 0)]:
    key("Tail2", f, rot=(r, 0, 0))
    key("Tail3", f, rot=(r * 0.6, 0, 0))
finish(a, 26)

# Hit: Zurückzucken (10 Bilder)
a = begin("Hit")
for f, r in [(1, 0), (3, -14), (10, 0)]:
    key("Body", f, rot=(r, 0, 0))
    key("Head", f, rot=(r * 0.8, 0, 0))
for f, y in [(1, 0.0), (3, 0.12), (10, 0.0)]:
    key("Root", f, loc=(0, y, 0))
finish(a, 10)

# Stagger: taumeln (18 Bilder)
a = begin("Stagger")
for f, r in [(1, 0), (5, 12), (10, -10), (14, 6), (18, 0)]:
    key("Body", f, rot=(0, 0, r))
    key("Head", f, rot=(0, 0, -r * 0.5))
for f, r in [(1, 0), (5, -8), (10, 4), (18, 0)]:
    key("Hips", f, rot=(r, 0, 0))
for f, z in [(1, 0.0), (9, -0.05), (18, 0.0)]:
    key("Root", f, loc=(0, 0, z))
finish(a, 18)

# Death: kippt zur Seite und bleibt liegen (36 Bilder)
a = begin("Death")
for f, r in [(1, 0), (8, 12), (22, 86), (36, 86)]:
    key("Root", f, rot=(0, 0, r))
for f, z in [(1, 0.0), (8, 0.15), (22, 0.55), (36, 0.5)]:
    key("Root", f, loc=(0, 0, z))
for f, r in [(1, 0), (22, 12), (36, 14)]:
    key("Head", f, rot=(r, 0, 0))
for f, r in [(1, 0), (22, 22), (36, 25)]:
    key("Tail2", f, rot=(r, 0, 0))
    key("Tail3", f, rot=(r * 0.8, 0, 0))
    key("Arm_L", f, rot=(r, 0, 0))
    key("Arm_R", f, rot=(r, 0, 0))
finish(a, 36)

# Dodge: Satz nach hinten/oben (12 Bilder)
a = begin("Dodge")
for f, z in [(1, 0.0), (5, 0.3), (12, 0.0)]:
    key("Root", f, loc=(0, 0, z))
for f, r in [(1, 0), (5, -15), (9, 5), (12, 0)]:
    key("Body", f, rot=(r, 0, 0))
for f, r in [(1, 0), (5, -30), (12, 0)]:
    key("Arm_L", f, rot=(r, 0, 0))
    key("Arm_R", f, rot=(r, 0, 0))
finish(a, 12)

# Block: ducken, Pfoten hoch (24 Bilder, Schleife)
a = begin("Block")
for f, s in [(1, 0.92), (12, 0.93), (24, 0.92)]:
    key("Body", f, scale=(1.04, s, 1.04))
for f, z in [(1, -0.06), (12, -0.05), (24, -0.06)]:
    key("Root", f, loc=(0, 0, z))
for f, r in [(1, 36), (12, 38), (24, 36)]:
    key("Arm_L", f, rot=(r, 0, 0))
    key("Arm_R", f, rot=(r, 0, 0))
for f, r in [(1, 8), (12, 10), (24, 8)]:
    key("Head", f, rot=(r, 0, 0))
finish(a, 24)
reset_pose()
print("Aktionen:", [x.name for x in bpy.data.actions])

# ---------------------------------------------------------------- Export GLB (Texturen eingebettet, alle Aktionen)
for o in bpy.data.objects:
    o.select_set(o in (ob, arm))
bpy.context.view_layer.objects.active = arm
bpy.ops.export_scene.gltf(filepath=GLB, export_format='GLB', use_selection=True,
    export_apply=False, export_animations=True, export_animation_mode='ACTIONS', export_nla_strips=True,
    export_anim_slide_to_zero=True, export_force_sampling=True, export_frame_range=False,
    export_rest_position_armature=True, export_skins=True, export_morph=False,
    export_image_format='AUTO', export_texcoords=True, export_normals=True, export_yup=True)
print("GLB exportiert:", GLB, "nach %.0f s" % (time.time() - t0))

# ---------------------------------------------------------------- Posen-Bilder zur Kontrolle
scene.render.engine = 'BLENDER_WORKBENCH'
scene.display.shading.light = 'STUDIO'
scene.display.shading.color_type = 'TEXTURE'
scene.render.resolution_x = 700
scene.render.resolution_y = 700
scene.render.image_settings.file_format = 'PNG'
cam_data = bpy.data.cameras.new("cam")
cam = bpy.data.objects.new("cam", cam_data)
scene.collection.objects.link(cam)
scene.camera = cam
ctr = mathutils.Vector((0, 0, 1.1))
cam.location = (3.2, -3.6, 2.4)
cam.rotation_euler = (ctr - cam.location).to_track_quat('-Z', 'Y').to_euler()
for act_name, frame in [("Idle", 24), ("Walk", 6), ("Attack_Heavy", 16), ("Death", 36)]:
    for tr in arm.animation_data.nla_tracks:
        tr.mute = tr.name != act_name
    scene.frame_set(frame)
    scene.render.filepath = OUT + "pose_" + act_name.lower() + ".png"
    bpy.ops.render.render(write_still=True)
cam.location = (2.6, 1.4, 1.6)
cam.rotation_euler = (mathutils.Vector((0, 0.8, 1.3)) - cam.location).to_track_quat('-Z', 'Y').to_euler()
for act_name, frame in [("Attack_Heavy", 16), ("Idle", 12), ("Walk", 11)]:
    for tr in arm.animation_data.nla_tracks:
        tr.mute = tr.name != act_name
    scene.frame_set(frame)
    scene.render.filepath = OUT + "tail_" + act_name.lower() + ".png"
    bpy.ops.render.render(write_still=True)
for tr in arm.animation_data.nla_tracks:
    tr.mute = False
bpy.ops.wm.save_as_mainfile(filepath=OUT + "hamsuke_rig.blend")
print("FERTIG nach %.0f s" % (time.time() - t0))
