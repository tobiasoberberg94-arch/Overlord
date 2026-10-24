# Wolf (Tripo-FBX, Vierbeiner ohne Mixamo) → geriggtes, animiertes GLB für assets/models/characters/wolf.glb.
#   blender.exe -b --python tools/pipeline/build_wolf.py [-- <Quellordner> [<Ziel-GLB>]]
# Quellordner (Standard C:/Projekte/Overlord/Models/Wolf/src): model.fbx + Material_01_{BaseColor,Metallic,Normal,Roughness}.png.
# Ablauf wie build_hamsuke.py: Texturen (ffmpeg verkleinert: Grundfarbe 2K-JPEG 4:2:0, Rest 1K), Blick nach -Y, Pfoten auf z=0,
# Schulterhöhe ≈ 0,9 m; Skelett: Root, Pelvis, Spine, Chest, Neck, Head, Tail1-3, je Bein Oberschenkel/Unterschenkel/Pfote;
# Gewichte: nächster Knochen (Abstand/Radius) + Kantenglättung, Schwanz per Zeltfunktion; Aktionen: Idle, Walk (Schritt),
# Run (Galopp), Attack_Light (Biss), Attack_Heavy (Sprung), Hit, Stagger, Death, Dodge, Block (Knurrstellung).
import bpy, math, mathutils, time, os, sys, subprocess
import numpy as np

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
SRC = (argv[0] if len(argv) > 0 else "C:/Projekte/Overlord/Models/Wolf/src").replace("\\", "/").rstrip("/") + "/"
REPO = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..")).replace("\\", "/")
GLB = (argv[1] if len(argv) > 1 else REPO + "/assets/models/characters/wolf.glb").replace("\\", "/")
OUT = SRC + "build/"
os.makedirs(OUT, exist_ok=True)
SC = 1.45                      # Modell ist 0,84 Einheiten hoch (Kopf) → Schulter ≈ 0,9 m, Kopf ≈ 1,2 m, Länge ≈ 1,45 m
t0 = time.time()

# ---------------------------------------------------------------- Texturen (ffmpeg)
conv = {"base": ("Material_01_BaseColor.png", OUT + "wolf_basecolor.jpg", 2048, ["-q:v", "3", "-pix_fmt", "yuvj420p"]),
        "normal": ("Material_01_Normal.png", OUT + "wolf_normal.png", 1024, []),
        "metallic": ("Material_01_Metallic.png", OUT + "wolf_metallic.png", 1024, []),
        "roughness": ("Material_01_Roughness.png", OUT + "wolf_roughness.png", 1024, [])}
for k, (src, dst, px, extra) in conv.items():
    if os.path.exists(SRC + src) and not os.path.exists(dst):
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", SRC + src, "-vf", "scale=%d:-1" % px] + extra + [dst], check=True)

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.fbx(filepath=SRC + "model.fbx")
ob = [o for o in bpy.data.objects if o.type == 'MESH'][0]
ob.name = "Wolf"
me = ob.data
me.name = "Wolf"
for img in list(bpy.data.images):
    for key, tag in [("base", "_Base"), ("metallic", "_Meta"), ("normal", "_Norm"), ("roughness", "_Roug")]:
        if tag in img.name:
            img.filepath = conv[key][1]
            img.source = 'FILE'
            img.reload()
            img.name = "wolf_" + key
mat = me.materials[0]
mat.name = "Wolf"
for n in mat.node_tree.nodes:
    if n.type == 'TEX_IMAGE' and n.image and n.image.name == "wolf_base":
        mat.node_tree.nodes.active = n
    if n.type == 'BSDF_PRINCIPLED':
        n.inputs["Specular IOR Level"].default_value = 0.3
print("Texturen:", [(i.name, i.size[:]) for i in bpy.data.images])

# ---------------------------------------------------------------- Ausrichten: Blick nach -Y, Pfoten auf z=0
# Original: Länge x (Nase +X), Breite y, Höhe z (-0,42 … 0,42)
ob.rotation_euler = (0.0, 0.0, math.radians(-90.0))
ob.scale = (SC, SC, SC)
ob.location = (0.0, 0.0, 0.421 * SC)
bpy.context.view_layer.objects.active = ob
for o in bpy.data.objects:
    o.select_set(o == ob)
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
N = len(me.vertices)
co = np.empty(N * 3, dtype=np.float64)
me.vertices.foreach_get("co", co)
co = co.reshape(N, 3)
print("Maße nach Ausrichtung: x %.2f..%.2f  y %.2f..%.2f  z %.2f..%.2f" % (co[:, 0].min(), co[:, 0].max(), co[:, 1].min(), co[:, 1].max(), co[:, 2].min(), co[:, 2].max()))

# Landmarken aus der Analyse (Original-Einheiten x,z; y = Seite) → finale Koordinaten (x_f = y*SC, y_f = -x*SC, z_f = (z+0.421)*SC)
def P(x, z, y=0.0):
    return (y * SC, -x * SC, (z + 0.421) * SC)

# ---------------------------------------------------------------- Skelett
arm_data = bpy.data.armatures.new("WolfRig")
arm = bpy.data.objects.new("WolfRig", arm_data)
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
bone("Root", (0, 0, 0), (0, 0, 0.25))
bone("Pelvis", P(-0.36, -0.02), P(-0.12, 0.04), "Root")
bone("Spine", P(-0.12, 0.04), P(0.10, 0.06), "Pelvis", True)
bone("Chest", P(0.10, 0.06), P(0.20, 0.14), "Spine", True)
bone("Neck", P(0.20, 0.14), P(0.30, 0.25), "Chest", True)
bone("Head", P(0.30, 0.25), P(0.50, 0.30), "Neck", True)
bone("Tail1", P(-0.40, -0.06), P(-0.46, -0.20), "Pelvis")
bone("Tail2", P(-0.46, -0.20), P(-0.49, -0.38), "Tail1", True)
for side, sy in [("L", 1.0), ("R", -1.0)]:
    bone("Thigh_" + side, P(-0.37, -0.05, 0.05 * sy), P(-0.32, -0.20, 0.05 * sy), "Pelvis")
    bone("Shin_" + side, P(-0.32, -0.20, 0.05 * sy), P(-0.27, -0.33, 0.05 * sy), "Thigh_" + side, True)
    bone("HindPaw_" + side, P(-0.27, -0.33, 0.05 * sy), P(-0.16, -0.41, 0.05 * sy), "Shin_" + side, True)
    bone("UpperArm_" + side, P(0.15, -0.02, 0.07 * sy), P(0.18, -0.16, 0.07 * sy), "Chest")
    bone("Forearm_" + side, P(0.18, -0.16, 0.07 * sy), P(0.18, -0.31, 0.07 * sy), "UpperArm_" + side, True)
    bone("FrontPaw_" + side, P(0.18, -0.31, 0.07 * sy), P(0.24, -0.41, 0.07 * sy), "Forearm_" + side, True)
bpy.ops.object.mode_set(mode='OBJECT')

# ---------------------------------------------------------------- Gewichte
W_BONES = [("Pelvis", 0.26), ("Spine", 0.26), ("Chest", 0.24), ("Neck", 0.16), ("Head", 0.24),
           ("Tail1", 0.07), ("Tail2", 0.07)]
for side in ["L", "R"]:
    W_BONES += [("Thigh_" + side, 0.11), ("Shin_" + side, 0.07), ("HindPaw_" + side, 0.06),
                ("UpperArm_" + side, 0.09), ("Forearm_" + side, 0.065), ("FrontPaw_" + side, 0.06)]
names = [nm for nm, r in W_BONES]
def seg_dist(p, a, b):
    ab = b - a
    t = np.clip(((p - a) @ ab) / (ab @ ab), 0.0, 1.0)
    return np.linalg.norm(p - (a + t[:, None] * ab), axis=1)
scores = np.empty((N, len(W_BONES)))
for i, (nm, r) in enumerate(W_BONES):
    b = arm_data.bones[nm]
    scores[:, i] = seg_dist(co, np.array(b.head_local), np.array(b.tail_local)) / r
# Schwanz geometrisch abtrennen: hinter den Hüften und unter der Rückenlinie (final y > 0.57, z < 0.55)
tidx = [names.index("Tail1"), names.index("Tail2")]
is_tail = (co[:, 1] > 0.57) & (co[:, 2] < 0.55) & (np.abs(co[:, 0]) < 0.09)
scores_nt = scores.copy()
scores_nt[:, tidx] = 1e9
best = np.argmin(scores_nt, axis=1)
W = np.zeros((N, len(W_BONES)))
W[np.arange(N), best] = 1.0
E = len(me.edges)
ev = np.empty(E * 2, dtype=np.int64)
me.edges.foreach_get("vertices", ev)
ev = ev.reshape(E, 2)
deg = np.maximum(np.bincount(ev[:, 0], minlength=N) + np.bincount(ev[:, 1], minlength=N), 1)[:, None]
for it in range(10):
    acc = np.zeros_like(W)
    np.add.at(acc, ev[:, 0], W[ev[:, 1]])
    np.add.at(acc, ev[:, 1], W[ev[:, 0]])
    W = 0.45 * W + 0.55 * acc / deg
# Schwanz: Zeltgewichte entlang der Kette, Basis mit dem Becken
chain = [np.array(arm_data.bones["Tail1"].head_local), np.array(arm_data.bones["Tail1"].tail_local), np.array(arm_data.bones["Tail2"].tail_local)]
pt = co[is_tail]
tpar = np.zeros(len(pt)); dbest = np.full(len(pt), 1e9)
for si in range(2):
    a_, b_ = chain[si], chain[si + 1]
    ab = b_ - a_
    tt = np.clip(((pt - a_) @ ab) / (ab @ ab), 0.0, 1.0)
    d = np.linalg.norm(pt - (a_ + tt[:, None] * ab), axis=1)
    sel = d < dbest
    dbest[sel] = d[sel]; tpar[sel] = si + tt[sel]
Wt = np.zeros((len(pt), len(W_BONES)))
u_ = tpar - 0.5
for si in range(2):
    Wt[:, tidx[si]] = np.clip(1.0 - np.abs(u_ - si) / 1.4, 0.0, 1.0)
Wt[:, names.index("Pelvis")] = np.maximum(Wt[:, names.index("Pelvis")], np.clip(0.5 - tpar, 0.0, 0.5) * 2.0)
W[is_tail] = Wt / np.maximum(Wt.sum(axis=1, keepdims=True), 1e-6)
for it in range(6):
    acc = np.zeros_like(W)
    np.add.at(acc, ev[:, 0], W[ev[:, 1]])
    np.add.at(acc, ev[:, 1], W[ev[:, 0]])
    sm = 0.3 * W + 0.7 * acc / deg
    W[is_tail] = sm[is_tail]
W[W < 0.02] = 0.0
W /= np.maximum(W.sum(axis=1, keepdims=True), 1e-6)
print("Gewichte je Knochen (Anteil):", {nm: round(float((np.argmax(W, axis=1) == i).mean()), 3) for i, (nm, r) in enumerate(W_BONES)})
LEVELS = 40
for i, (nm, r) in enumerate(W_BONES):
    vg = ob.vertex_groups.new(name=nm)
    q = np.rint(W[:, i] * LEVELS).astype(int)
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
        b.rotation_euler = (0, 0, 0); b.location = (0, 0, 0); b.scale = (1, 1, 1)
def key(bname, frame, rot=None, loc=None, scale=None):
    b = pb[bname]
    if rot is not None:
        b.rotation_euler = tuple(math.radians(a) for a in rot); b.keyframe_insert("rotation_euler", frame=frame)
    if loc is not None:
        b.location = loc; b.keyframe_insert("location", frame=frame)
    if scale is not None:
        b.scale = scale; b.keyframe_insert("scale", frame=frame)
def begin(name):
    reset_pose()
    act = bpy.data.actions.new(name); act.use_fake_user = True
    arm.animation_data.action = act
    return act
def finish(act, last):
    act.frame_range = (1, last); act.use_frame_range = True
    tr = arm.animation_data.nla_tracks.new(); tr.name = act.name
    tr.strips.new(act.name, 1, act)
    arm.animation_data.action = None

# Beinschwung: Winkel um die lokale X-Achse (Knochen zeigen nach unten → positiv = Schwung nach hinten/vorn, je Bein gleich)
def leg_keys(prefix_upper, prefix_lower, prefix_paw, side, L, phase, swing, bend, paw_amt=1.0):
    """Ein Bein über eine Schleife der Länge L Bilder: Oberschenkel sin, Unterschenkel beugt beim Vorschwung."""
    steps = 8
    for s in range(steps + 1):
        f = 1 + int(round(L * s / steps))
        ph = (s / steps + phase) * 2 * math.pi
        up = swing * math.sin(ph)
        lo = bend * max(0.0, math.sin(ph + 0.9))           # Beugung während des Vorschwungs
        pw = paw_amt * bend * 0.6 * max(0.0, math.sin(ph + 1.6))
        key(prefix_upper + side, f, rot=(up, 0, 0))
        key(prefix_lower + side, f, rot=(lo, 0, 0))
        key(prefix_paw + side, f, rot=(-pw, 0, 0))

# Idle: Atmen, Kopf wendet sich, Schwanz wedelt leicht (72 Bilder)
a = begin("Idle")
for f, s in [(1, 1.0), (36, 1.03), (72, 1.0)]:
    key("Spine", f, scale=(s, 1.0, s)); key("Chest", f, scale=(s, 1.0, s))
for f, r in [(1, (0, 0, 0)), (20, (3, 0, 12)), (40, (-2, 0, -8)), (60, (2, 0, 4)), (72, (0, 0, 0))]:
    key("Head", f, rot=r)
for f, r in [(1, 0), (18, 10), (36, 0), (54, -10), (72, 0)]:
    key("Tail1", f, rot=(0, 0, r)); key("Tail2", f, rot=(0, 0, r * 0.8))
for f, r in [(1, 0), (36, 2), (72, 0)]:
    key("Neck", f, rot=(r, 0, 0))
finish(a, 72)

# Walk: Schritt (lateral sequence), 28 Bilder Schleife
a = begin("Walk")
L = 28
leg_keys("Thigh_", "Shin_", "HindPaw_", "L", L, 0.00, 22, 25)
leg_keys("UpperArm_", "Forearm_", "FrontPaw_", "L", L, 0.25, 24, 30)
leg_keys("Thigh_", "Shin_", "HindPaw_", "R", L, 0.50, 22, 25)
leg_keys("UpperArm_", "Forearm_", "FrontPaw_", "R", L, 0.75, 24, 30)
for s in range(9):
    f = 1 + int(round(L * s / 8)); ph = s / 8 * 4 * math.pi
    key("Root", f, loc=(0, 0, 0.012 * math.sin(ph)))
    key("Head", f, rot=(3 * math.sin(ph), 0, 0))
    key("Tail1", f, rot=(0, 0, 8 * math.sin(ph * 0.5)))
    key("Spine", f, rot=(0, 1.5 * math.sin(ph * 0.5), 0))
finish(a, L)

# Run: Galopp – Vorderbeine und Hinterbeine je paarweise, Rücken federt (14 Bilder)
a = begin("Run")
L = 14
for side in ["L", "R"]:
    leg_keys("Thigh_", "Shin_", "HindPaw_", side, L, 0.0 if side == "L" else 0.06, 38, 40)
    leg_keys("UpperArm_", "Forearm_", "FrontPaw_", side, L, 0.5 if side == "L" else 0.56, 36, 45)
for s in range(9):
    f = 1 + int(round(L * s / 8)); ph = s / 8 * 2 * math.pi
    key("Root", f, loc=(0, 0, 0.07 * math.sin(ph) + 0.03))
    key("Spine", f, rot=(10 * math.sin(ph), 0, 0))
    key("Pelvis", f, rot=(-6 * math.sin(ph), 0, 0))
    key("Head", f, rot=(-6 * math.sin(ph), 0, 0))
    key("Tail1", f, rot=(-15 * math.sin(ph) - 10, 0, 0))
finish(a, L)

# Attack_Light: Biss – Satz nach vorn, Kopf schnappt (14 Bilder)
a = begin("Attack_Light")
for f, y in [(1, 0.0), (4, 0.06), (8, -0.28), (14, 0.0)]:
    key("Root", f, loc=(0, y, 0))
for f, r in [(1, 0), (4, -12), (8, 22), (14, 0)]:
    key("Neck", f, rot=(r, 0, 0))
for f, r in [(1, 0), (4, -18), (8, 20), (14, 0)]:
    key("Head", f, rot=(r, 0, 0))
for f, r in [(1, 0), (4, 8), (8, -10), (14, 0)]:
    key("Chest", f, rot=(r, 0, 0))
for side in ["L", "R"]:
    for f, r in [(1, 0), (4, 10), (8, -25), (14, 0)]:
        key("UpperArm_" + side, f, rot=(r, 0, 0))
finish(a, 14)

# Attack_Heavy: Sprung – ducken, abspringen, landen (22 Bilder)
a = begin("Attack_Heavy")
for f, (y, z) in [(1, (0, 0)), (5, (0.08, -0.12)), (11, (-0.35, 0.35)), (15, (-0.55, 0.05)), (22, (0, 0))]:
    key("Root", f, loc=(0, y, z))
for f, r in [(1, 0), (5, 12), (11, -22), (15, 10), (22, 0)]:
    key("Spine", f, rot=(r, 0, 0)); key("Chest", f, rot=(r * 0.5, 0, 0))
for f, r in [(1, 0), (5, -10), (11, 15), (15, 25), (22, 0)]:
    key("Head", f, rot=(r, 0, 0))
for side in ["L", "R"]:
    for f, r in [(1, 0), (5, 30), (11, -45), (15, -10), (22, 0)]:
        key("Thigh_" + side, f, rot=(r, 0, 0))
    for f, r in [(1, 0), (5, 35), (11, 10), (15, 20), (22, 0)]:
        key("Shin_" + side, f, rot=(r, 0, 0))
    for f, r in [(1, 0), (5, 15), (11, -40), (15, 10), (22, 0)]:
        key("UpperArm_" + side, f, rot=(r, 0, 0))
    for f, r in [(1, 0), (5, 10), (11, 30), (15, 5), (22, 0)]:
        key("Forearm_" + side, f, rot=(r, 0, 0))
finish(a, 22)

# Hit: Zurückzucken (10 Bilder)
a = begin("Hit")
for f, y in [(1, 0.0), (3, 0.12), (10, 0.0)]:
    key("Root", f, loc=(0, y, 0))
for f, r in [(1, 0), (3, -15), (10, 0)]:
    key("Neck", f, rot=(r, 0, 0)); key("Head", f, rot=(r, 0, 6))
for f, r in [(1, 0), (3, -8), (10, 0)]:
    key("Chest", f, rot=(r, 0, 0))
finish(a, 10)

# Stagger: taumeln (18 Bilder)
a = begin("Stagger")
for f, r in [(1, 0), (5, 14), (10, -12), (14, 6), (18, 0)]:
    key("Spine", f, rot=(0, r, 0)); key("Head", f, rot=(0, -r * 0.5, 8))
for f, z in [(1, 0.0), (9, -0.06), (18, 0.0)]:
    key("Root", f, loc=(0, 0, z))
finish(a, 18)

# Death: bricht seitlich zusammen (34 Bilder)
a = begin("Death")
for f, (r, z) in [(1, (0, 0.0)), (8, (15, -0.08)), (20, (82, -0.42)), (34, (84, -0.44))]:
    key("Root", f, rot=(0, r, 0), loc=(0, 0, z))
for f, r in [(1, 0), (20, 20), (34, 22)]:
    key("Neck", f, rot=(r, 0, 0)); key("Head", f, rot=(r * 0.8, 0, -10))
for side in ["L", "R"]:
    for f, r in [(1, 0), (20, 25), (34, 28)]:
        key("Thigh_" + side, f, rot=(r, 0, 0)); key("UpperArm_" + side, f, rot=(-r, 0, 0))
    for f, r in [(1, 0), (20, 30), (34, 32)]:
        key("Shin_" + side, f, rot=(r, 0, 0)); key("Forearm_" + side, f, rot=(r, 0, 0))
finish(a, 34)

# Dodge: Satz zur Seite/zurück (12 Bilder)
a = begin("Dodge")
for f, (y, z) in [(1, (0, 0)), (5, (0.25, 0.22)), (12, (0, 0))]:
    key("Root", f, loc=(0, y, z))
for f, r in [(1, 0), (5, -12), (12, 0)]:
    key("Spine", f, rot=(r, 0, 0))
for side in ["L", "R"]:
    for f, r in [(1, 0), (5, 35), (12, 0)]:
        key("Thigh_" + side, f, rot=(r, 0, 0)); key("UpperArm_" + side, f, rot=(-r * 0.6, 0, 0))
finish(a, 12)

# Block: Knurrstellung – geduckt, Kopf gesenkt (24 Bilder Schleife)
a = begin("Block")
for f, z in [(1, -0.1), (12, -0.09), (24, -0.1)]:
    key("Root", f, loc=(0, 0, z))
for f, r in [(1, 10), (12, 12), (24, 10)]:
    key("Neck", f, rot=(r, 0, 0)); key("Head", f, rot=(r * 0.8, 0, 0))
for side in ["L", "R"]:
    for f, r in [(1, 18), (12, 20), (24, 18)]:
        key("Thigh_" + side, f, rot=(r, 0, 0)); key("Shin_" + side, f, rot=(r * 0.8, 0, 0))
        key("UpperArm_" + side, f, rot=(-r * 0.5, 0, 0)); key("Forearm_" + side, f, rot=(r * 0.9, 0, 0))
finish(a, 24)
reset_pose()
print("Aktionen:", [x.name for x in bpy.data.actions])

# ---------------------------------------------------------------- Export
for o in bpy.data.objects:
    o.select_set(o in (ob, arm))
bpy.context.view_layer.objects.active = arm
bpy.ops.export_scene.gltf(filepath=GLB, export_format='GLB', use_selection=True, export_apply=False,
    export_animations=True, export_animation_mode='ACTIONS', export_nla_strips=True, export_anim_slide_to_zero=True,
    export_force_sampling=True, export_frame_range=False, export_rest_position_armature=True, export_skins=True,
    export_morph=False, export_image_format='AUTO', export_texcoords=True, export_normals=True, export_yup=True)
print("GLB exportiert:", GLB, os.path.getsize(GLB), "Bytes nach %.0f s" % (time.time() - t0))
bpy.ops.wm.save_as_mainfile(filepath=OUT + "wolf_rig.blend")

# ---------------------------------------------------------------- Kontrollbilder
scene.render.engine = 'BLENDER_WORKBENCH'
scene.display.shading.light = 'STUDIO'
scene.display.shading.color_type = 'TEXTURE'
scene.render.resolution_x = 700
scene.render.resolution_y = 500
scene.render.image_settings.file_format = 'PNG'
cam_data = bpy.data.cameras.new("cam")
cam = bpy.data.objects.new("cam", cam_data)
scene.collection.objects.link(cam)
scene.camera = cam
ctr = mathutils.Vector((0, 0, 0.6))
cam.location = (3.0, -2.2, 1.3)
cam.rotation_euler = (ctr - cam.location).to_track_quat('-Z', 'Y').to_euler()
for act_name, frame in [("Idle", 20), ("Walk", 8), ("Run", 4), ("Attack_Heavy", 11), ("Death", 34), ("Block", 12)]:
    reset_pose()
    for tr in arm.animation_data.nla_tracks:
        tr.mute = tr.name != act_name
    scene.frame_set(frame)
    scene.render.filepath = OUT + "pose_" + act_name.lower() + ".png"
    bpy.ops.render.render(write_still=True)
for tr in arm.animation_data.nla_tracks:
    tr.mute = False
print("FERTIG nach %.0f s" % (time.time() - t0))
