# Skelettdrache (Tripo-FBX) → geriggtes, animiertes GLB für assets/models/characters/skeletal_dragon.glb.
#   blender.exe -b --python tools/pipeline/build_dragon.py [-- <Quellordner> [<Ziel-GLB>]]
# Quellordner (Standard C:/Projekte/Overlord/Models/SkelettDrache/src): model.fbx + Material_01_{BaseColor,Metallic,Normal,Roughness}.png.
# Wie build_wolf.py: Blick nach -Y, Füße auf z=0, Spannweite 4,5 m, Länge 3,3 m; Skelett: Root, Pelvis, Spine, Neck1/2, Head, Tail1-3,
# je Bein zwei Knochen, je Flügel Arm + Hand; Flügelhaut per Region (|x| groß) den Flügelknochen zugeordnet.
# Aktionen: Idle, Walk, Run, Attack_Light (Biss), Attack_Heavy (Flügelschlag), Hit, Stagger, Death (bricht zusammen),
# Dodge (Satz zurück mit Flügelschlag), Block (geduckt, Flügel vor).
import bpy, math, mathutils, time, os, sys, subprocess
import numpy as np

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
SRC = (argv[0] if len(argv) > 0 else "C:/Projekte/Overlord/Models/SkelettDrache/src").replace("\\", "/").rstrip("/") + "/"
REPO = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..")).replace("\\", "/")
GLB = (argv[1] if len(argv) > 1 else REPO + "/assets/models/characters/skeletal_dragon.glb").replace("\\", "/")
OUT = SRC + "build/"
os.makedirs(OUT, exist_ok=True)
SC = 4.5                       # Modell 1,0 lang / 0,54 hoch → 4,5 m lang, 2,4 m hoch, Spannweite 3,3 m
t0 = time.time()

conv = {"base": ("Material_01_BaseColor.png", OUT + "dragon_basecolor.jpg", 2048, ["-q:v", "3", "-pix_fmt", "yuvj420p"]),
        "normal": ("Material_01_Normal.png", OUT + "dragon_normal.png", 1024, []),
        "metallic": ("Material_01_Metallic.png", OUT + "dragon_metallic.png", 1024, []),
        "roughness": ("Material_01_Roughness.png", OUT + "dragon_roughness.png", 1024, [])}
for k, (src, dst, px, extra) in conv.items():
    if os.path.exists(SRC + src) and not os.path.exists(dst):
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", SRC + src, "-vf", "scale=%d:-1" % px] + extra + [dst], check=True)

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.fbx(filepath=SRC + "model.fbx")
ob = [o for o in bpy.data.objects if o.type == 'MESH'][0]
ob.name = "SkeletalDragon"
me = ob.data
me.name = "SkeletalDragon"
for img in list(bpy.data.images):
    for key, tag in [("base", "_Base"), ("metallic", "_Meta"), ("normal", "_Norm"), ("roughness", "_Roug")]:
        if tag in img.name:
            img.filepath = conv[key][1]
            img.source = 'FILE'
            img.reload()
            img.name = "dragon_" + key
mat = me.materials[0]
mat.name = "SkeletalDragon"
for n in mat.node_tree.nodes:
    if n.type == 'TEX_IMAGE' and n.image and n.image.name == "dragon_base":
        mat.node_tree.nodes.active = n
    if n.type == 'BSDF_PRINCIPLED':
        n.inputs["Specular IOR Level"].default_value = 0.3
print("Texturen:", [(i.name, i.size[:]) for i in bpy.data.images])

# Quelle (gemessen): Länge y (Kopf bei -0,37, Schwanz bei +0,37), Spannweite x (±0,5, beide Flügel ausgebreitet),
# Höhe z (-0,27 … 0,27) – liegt schon mit Blick nach -Y, also keine Drehung
ob.rotation_euler = (0.0, 0.0, 0.0)
ob.scale = (SC, SC, SC)
ob.location = (0.0, 0.0, 0.269 * SC)
bpy.context.view_layer.objects.active = ob
for o in bpy.data.objects:
    o.select_set(o == ob)
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
N = len(me.vertices)
co = np.empty(N * 3, dtype=np.float64)
me.vertices.foreach_get("co", co)
co = co.reshape(N, 3)
print("Maße nach Ausrichtung: x %.2f..%.2f  y %.2f..%.2f  z %.2f..%.2f" % (co[:, 0].min(), co[:, 0].max(), co[:, 1].min(), co[:, 1].max(), co[:, 2].min(), co[:, 2].max()))

# ---------------------------------------------------------------- Flügel spiegeln: Tripo hat einen Flügel ausgebreitet und einen
# zerknittert hängend; der ausgebreitete wird auf die andere Seite gespiegelt, der hängende (außerhalb von |x| 0,55 m) entfernt.
import bmesh
# (keine Flügel-Spiegelung mehr: die Quelle hat beide Flügel ausgebreitet)

def Q(x, y, z):
    """Punkt der Quelle (x Seite, y Länge mit Kopf bei -y, z Höhe) → Meter, Füße auf z = 0."""
    return (x * SC, y * SC, (z + 0.269) * SC)

arm_data = bpy.data.armatures.new("DragonRig")
arm = bpy.data.objects.new("DragonRig", arm_data)
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
bone("Root", (0, 0, 0), (0, 0, 0.5))
# Rumpf: Becken über den Hinterbeinen (y 0,12 … 0,20), Schultern über den Vorderbeinen (y -0,10 … -0,16), Rücken
# um z 0,1, Bauch um -0,1; der Hals senkt sich zum Kopf (Schnauze vorn bei y -0,36, z -0,05)
bone("Pelvis", Q(0, 0.14, -0.03), Q(0, 0.03, 0.0), "Root")
bone("Spine", Q(0, 0.03, 0.0), Q(0, -0.12, 0.02), "Pelvis", True)
bone("Neck1", Q(0, -0.12, 0.02), Q(0, -0.21, 0.04), "Spine", True)
bone("Neck2", Q(0, -0.21, 0.04), Q(0, -0.28, 0.01), "Neck1", True)
bone("Head", Q(0, -0.28, 0.01), Q(0, -0.36, -0.05), "Neck2", True)
# Schwanz: nach hinten und hinab, die Spitze rollt sich am Boden zur +x-Seite ein
bone("Tail1", Q(0, 0.14, -0.03), Q(0, 0.23, -0.06), "Pelvis")
bone("Tail2", Q(0, 0.23, -0.06), Q(0.03, 0.30, -0.13), "Tail1", True)
bone("Tail3", Q(0.03, 0.30, -0.13), Q(0.12, 0.35, -0.22), "Tail2", True)
# Beine bis zu den gemessenen Füßen (+x = L): vorn L (0,147 / -0,104), R (-0,149 / -0,163);
# hinten L (0,111 / 0,203), R (-0,108 / 0,122)
FEET = {"L": {"hind": (0.111, 0.203), "front": (0.147, -0.104)}, "R": {"hind": (-0.108, 0.122), "front": (-0.149, -0.163)}}
for side, sy in [("L", 1.0), ("R", -1.0)]:
    hx, hy = FEET[side]["hind"]
    fx, fy = FEET[side]["front"]
    bone("Thigh_" + side, Q(0.07 * sy, 0.15, -0.03), Q((0.07 * sy + hx) * 0.5 + 0.02 * sy, (0.15 + hy) * 0.5, -0.14), "Pelvis")
    bone("Shin_" + side, Q((0.07 * sy + hx) * 0.5 + 0.02 * sy, (0.15 + hy) * 0.5, -0.14), Q(hx, hy, -0.245), "Thigh_" + side, True)
    bone("UpperArm_" + side, Q(0.07 * sy, -0.12, -0.02), Q((0.07 * sy + fx) * 0.5 + 0.02 * sy, (-0.12 + fy) * 0.5, -0.13), "Spine")
    bone("Forearm_" + side, Q((0.07 * sy + fx) * 0.5 + 0.02 * sy, (-0.12 + fy) * 0.5, -0.13), Q(fx, fy, -0.245), "UpperArm_" + side, True)
    # Flügel: ein starrer Knochen vom Ansatz über der Schulter zum Schwerpunkt des äußeren Flügeldrittels (Mesh-Maß)
    wsel = (co[:, 0] * sy > 1.15 * SC * 0.25)
    wtip = co[wsel].mean(axis=0) if wsel.sum() > 50 else np.array(Q(0.38 * sy, 0.1, 0.23))
    bone("WingArm_" + side, Q(0.07 * sy, -0.03, 0.10), tuple(wtip), "Spine")
bpy.ops.object.mode_set(mode='OBJECT')

# ---------------------------------------------------------------- Gewichte
W_BONES = [("Pelvis", 0.15), ("Spine", 0.15), ("Neck1", 0.09), ("Neck2", 0.08), ("Head", 0.11),
           ("Tail1", 0.07), ("Tail2", 0.06), ("Tail3", 0.06)]
for side in ["L", "R"]:
    W_BONES += [("Thigh_" + side, 0.07), ("Shin_" + side, 0.055), ("UpperArm_" + side, 0.065), ("Forearm_" + side, 0.055),
                ("WingArm_" + side, 0.12)]
names = [nm for nm, r in W_BONES]
def seg_dist(p, a, b):
    ab = b - a
    t = np.clip(((p - a) @ ab) / (ab @ ab), 0.0, 1.0)
    return np.linalg.norm(p - (a + t[:, None] * ab), axis=1)
scores = np.empty((N, len(W_BONES)))
for i, (nm, r) in enumerate(W_BONES):
    b = arm_data.bones[nm]
    scores[:, i] = seg_dist(co, np.array(b.head_local), np.array(b.tail_local)) / r
# Flügel: seitlich weit außen (final |x| in Metern: Rumpf bis 0,54, Beine bis 0,63)
ax = np.abs(co[:, 0])
# Flügelhaut per Flutfüllung über die Mesh-Kanten: Start weit außen, erlaubt bis knapp an die Schulter,
# aber nie in den Rumpfkern (|x| < 0,45 m) oder die unteren Beine (|x| < 0,9 m und z < 0,5 m)
E = len(me.edges)
ev = np.empty(E * 2, dtype=np.int64)
me.edges.foreach_get("vertices", ev)
ev = ev.reshape(E, 2)
# erst die Beine abtrennen (von den Pfoten aufwärts bis 0,9 m, nur nahe am Rumpf), dann darf der Flügel überall sonst wachsen
is_leg = (co[:, 2] < 0.15) & (ax < 0.75)
leg_allowed = (co[:, 2] < 0.9) & (ax < 0.75)
for it in range(300):
    grow = is_leg.copy()
    grow[ev[:, 1][is_leg[ev[:, 0]]]] = True
    grow[ev[:, 0][is_leg[ev[:, 1]]]] = True
    grow &= leg_allowed
    if grow.sum() == is_leg.sum():
        break
    is_leg = grow
print("Bein-Vertices (Flutfüllung): %d" % is_leg.sum())
allowed = (ax > 0.45) & ~is_leg
is_wing = ax > 1.2
for it in range(400):
    grow = is_wing.copy()
    grow[ev[:, 1][is_wing[ev[:, 0]]]] = True
    grow[ev[:, 0][is_wing[ev[:, 1]]]] = True
    grow &= allowed
    if grow.sum() == is_wing.sum():
        break
    is_wing = grow
print("Flutfüllung Flügel: %d Vertices nach %d Schritten" % (is_wing.sum(), it))
wing_idx = {side: [names.index("WingArm_" + side)] for side in ["L", "R"]}
scores_nw = scores.copy()
for side in ["L", "R"]:
    scores_nw[:, wing_idx[side]] = 1e9
best = np.argmin(scores_nw, axis=1)
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
# Flügelhaut: starr am Flügelknochen, am Ansatz (nahe der Schulter) mit dem Rücken gemischt
for side, sgn in [("L", 1.0), ("R", -1.0)]:
    sel = is_wing & ((co[:, 0] * sgn) > 0)
    pt = co[sel]
    a_ = np.array(arm_data.bones["WingArm_" + side].head_local); b_ = np.array(arm_data.bones["WingArm_" + side].tail_local)
    ab = b_ - a_
    tt = np.clip(((pt - a_) @ ab) / (ab @ ab), 0.0, 1.0)
    Wt = np.zeros((len(pt), len(W_BONES)))
    Wt[:, wing_idx[side][0]] = 1.0
    Wt[:, names.index("Spine")] = np.clip(0.25 - tt, 0.0, 0.25) * 3.0
    W[sel] = Wt / np.maximum(Wt.sum(axis=1, keepdims=True), 1e-6)
for it in range(6):
    acc = np.zeros_like(W)
    np.add.at(acc, ev[:, 0], W[ev[:, 1]])
    np.add.at(acc, ev[:, 1], W[ev[:, 0]])
    sm = 0.3 * W + 0.7 * acc / deg
    W[is_wing] = sm[is_wing]
W[W < 0.02] = 0.0
W /= np.maximum(W.sum(axis=1, keepdims=True), 1e-6)
print("Flügel-Vertices: %d  Gewichte je Knochen (Anteil):" % is_wing.sum(), {nm: round(float((np.argmax(W, axis=1) == i).mean()), 3) for i, (nm, r) in enumerate(W_BONES)})
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
WING_AXIS = {}
WING_SIGN = {"L": -1.0, "R": 1.0}
for side in ["L", "R"]:
    pb["WingArm_" + side].rotation_mode = 'QUATERNION'
    WING_AXIS[side] = (arm_data.bones["WingArm_" + side].matrix_local.to_3x3().inverted() @ mathutils.Vector((0.0, 1.0, 0.0))).normalized()
arm.animation_data_create()
def reset_pose():
    for b in pb:
        b.rotation_euler = (0, 0, 0); b.rotation_quaternion = (1, 0, 0, 0); b.location = (0, 0, 0); b.scale = (1, 1, 1)
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
def leg_keys(upper, lower, side, L, phase, swing, bend):
    steps = 8
    for s in range(steps + 1):
        f = 1 + int(round(L * s / steps))
        ph = (s / steps + phase) * 2 * math.pi
        key(upper + side, f, rot=(swing * math.sin(ph), 0, 0))
        key(lower + side, f, rot=(bend * max(0.0, math.sin(ph + 0.9)), 0, 0))
def wings(frame, flap, sweep=0.0, hand=None):
    """Flügel um die Körperlängsachse schlagen (positiv = nach oben), unabhängig von der Ruhelage des Knochens."""
    for side in ["L", "R"]:
        b = pb["WingArm_" + side]
        b.rotation_quaternion = mathutils.Quaternion(WING_AXIS[side], math.radians(flap * WING_SIGN[side]))
        b.keyframe_insert("rotation_quaternion", frame=frame)

# Idle: Atmen, Hals wiegt, Schwanz pendelt, Flügel heben sich leicht (72 Bilder)
a = begin("Idle")
for f, s in [(1, 1.0), (36, 1.03), (72, 1.0)]:
    key("Spine", f, scale=(s, 1.0, s))
for f, r in [(1, (0, 0, 0)), (24, (4, 0, 8)), (48, (-3, 0, -6)), (72, (0, 0, 0))]:
    key("Neck1", f, rot=r); key("Head", f, rot=(r[0] * 0.5, 0, r[2]))
for f, r in [(1, 0), (18, 8), (36, 0), (54, -8), (72, 0)]:
    key("Tail1", f, rot=(0, 0, r)); key("Tail2", f, rot=(0, 0, r * 0.8)); key("Tail3", f, rot=(0, 0, r * 0.6))
for f, fl in [(1, 0), (36, 6), (72, 0)]:
    wings(f, fl)
finish(a, 72)

# Walk (32 Bilder) und Run (16 Bilder)
a = begin("Walk")
L = 32
leg_keys("Thigh_", "Shin_", "L", L, 0.00, 20, 22)
leg_keys("UpperArm_", "Forearm_", "L", L, 0.25, 22, 26)
leg_keys("Thigh_", "Shin_", "R", L, 0.50, 20, 22)
leg_keys("UpperArm_", "Forearm_", "R", L, 0.75, 22, 26)
for s in range(9):
    f = 1 + int(round(L * s / 8)); ph = s / 8 * 4 * math.pi
    key("Root", f, loc=(0, 0, 0.02 * math.sin(ph)))
    key("Neck1", f, rot=(3 * math.sin(ph), 0, 0))
    key("Tail1", f, rot=(0, 0, 6 * math.sin(ph * 0.5)))
    wings(f, 4 * math.sin(ph * 0.5))
finish(a, L)
a = begin("Run")
L = 16
for side in ["L", "R"]:
    leg_keys("Thigh_", "Shin_", side, L, 0.0 if side == "L" else 0.06, 32, 36)
    leg_keys("UpperArm_", "Forearm_", side, L, 0.5 if side == "L" else 0.56, 30, 40)
for s in range(9):
    f = 1 + int(round(L * s / 8)); ph = s / 8 * 2 * math.pi
    key("Root", f, loc=(0, 0, 0.1 * math.sin(ph) + 0.05))
    key("Spine", f, rot=(8 * math.sin(ph), 0, 0))
    key("Neck1", f, rot=(-6 * math.sin(ph), 0, 0))
    key("Tail1", f, rot=(-12 * math.sin(ph) - 8, 0, 0))
    wings(f, 22 + 10 * math.sin(ph))
finish(a, L)

# Attack_Light: Biss – Hals schnellt vor (14 Bilder)
a = begin("Attack_Light")
for f, y in [(1, 0.0), (4, 0.15), (8, -0.45), (14, 0.0)]:
    key("Root", f, loc=(0, y, 0))
for f, r in [(1, 0), (4, -12), (8, 18), (14, 0)]:
    key("Neck1", f, rot=(r, 0, 0)); key("Neck2", f, rot=(r * 0.6, 0, 0))
for f, r in [(1, 0), (4, -15), (8, 15), (14, 0)]:
    key("Head", f, rot=(r, 0, 0))
for f, fl in [(1, 0), (4, 15), (8, -5), (14, 0)]:
    wings(f, fl)
finish(a, 14)

# Attack_Heavy: Flügelschlag – aufbäumen, Flügel hoch, niederschlagen (24 Bilder)
a = begin("Attack_Heavy")
for f, (y, z) in [(1, (0, 0)), (8, (0.2, 0.45)), (14, (-0.2, -0.05)), (24, (0, 0))]:
    key("Root", f, loc=(0, y, z))
for f, r in [(1, 0), (8, -22), (14, 12), (24, 0)]:
    key("Spine", f, rot=(r, 0, 0)); key("Pelvis", f, rot=(r * 0.5, 0, 0))
for f, r in [(1, 0), (8, -20), (14, 15), (24, 0)]:
    key("Neck1", f, rot=(r, 0, 0)); key("Head", f, rot=(r * 0.6, 0, 0))
for f, fl in [(1, 0), (8, 55), (14, -30), (24, 0)]:
    wings(f, fl)
for side in ["L", "R"]:
    for f, r in [(1, 0), (8, -35), (14, 15), (24, 0)]:
        key("UpperArm_" + side, f, rot=(r, 0, 0))
    for f, r in [(1, 0), (8, 25), (14, 20), (24, 0)]:
        key("Thigh_" + side, f, rot=(r, 0, 0))
finish(a, 24)

# Hit (10), Stagger (18)
a = begin("Hit")
for f, y in [(1, 0.0), (3, 0.18), (10, 0.0)]:
    key("Root", f, loc=(0, y, 0))
for f, r in [(1, 0), (3, -16), (10, 0)]:
    key("Neck1", f, rot=(r, 0, 0)); key("Head", f, rot=(r * 0.6, 0, 8))
for f, fl in [(1, 0), (3, 18), (10, 0)]:
    wings(f, fl)
finish(a, 10)
a = begin("Stagger")
for f, r in [(1, 0), (5, 12), (10, -10), (14, 5), (18, 0)]:
    key("Spine", f, rot=(0, r, 0)); key("Neck1", f, rot=(0, -r * 0.6, 8))
for f, z in [(1, 0.0), (9, -0.1), (18, 0.0)]:
    key("Root", f, loc=(0, 0, z))
finish(a, 18)

# Death: bricht auf den Bauch zusammen, Hals und Flügel sinken (36 Bilder)
a = begin("Death")
for f, z in [(1, 0.0), (10, -0.15), (24, -0.62), (36, -0.64)]:
    key("Root", f, loc=(0, 0, z))
for f, r in [(1, 0), (10, 8), (24, 28), (36, 30)]:
    key("Neck1", f, rot=(r, 0, 0)); key("Neck2", f, rot=(r * 0.6, 0, 0)); key("Head", f, rot=(r * 0.3, 0, 0))
for f, r in [(1, 0), (24, 45), (36, 48)]:
    key("Tail1", f, rot=(r, 0, 0)); key("Tail2", f, rot=(r * 0.5, 0, 0))
for f, fl in [(1, 0), (10, 20), (24, -35), (36, -36)]:
    wings(f, fl)
for side in ["L", "R"]:
    for f, r in [(1, 0), (24, 55), (36, 58)]:
        key("Thigh_" + side, f, rot=(r, 0, 0)); key("UpperArm_" + side, f, rot=(-r, 0, 0))
    for f, r in [(1, 0), (24, -50), (36, -52)]:
        key("Shin_" + side, f, rot=(r, 0, 0)); key("Forearm_" + side, f, rot=(r, 0, 0))
finish(a, 36)

# Dodge: Satz zurück mit Flügelschlag (12 Bilder)
a = begin("Dodge")
for f, (y, z) in [(1, (0, 0)), (5, (0.3, 0.35)), (12, (0, 0))]:
    key("Root", f, loc=(0, y, z))
for f, fl in [(1, 0), (3, 50), (7, -20), (12, 0)]:
    wings(f, fl)
for side in ["L", "R"]:
    for f, r in [(1, 0), (5, 30), (12, 0)]:
        key("Thigh_" + side, f, rot=(r, 0, 0)); key("UpperArm_" + side, f, rot=(-r * 0.6, 0, 0))
finish(a, 12)

# Block: geduckt, Flügel als Schild gesenkt, Hals zurück (24 Bilder Schleife)
a = begin("Block")
for f, z in [(1, -0.15), (12, -0.13), (24, -0.15)]:
    key("Root", f, loc=(0, 0, z))
for f, r in [(1, -14), (12, -16), (24, -14)]:
    key("Neck1", f, rot=(r, 0, 0)); key("Head", f, rot=(r * 0.5, 0, 0))
for f, fl in [(1, -22), (12, -25), (24, -22)]:
    wings(f, fl, 0.0, -10)
for side in ["L", "R"]:
    for f, r in [(1, 15), (12, 17), (24, 15)]:
        key("Thigh_" + side, f, rot=(r, 0, 0)); key("Shin_" + side, f, rot=(r * 0.8, 0, 0))
        key("UpperArm_" + side, f, rot=(-r * 0.5, 0, 0)); key("Forearm_" + side, f, rot=(r * 0.9, 0, 0))
finish(a, 24)
reset_pose()
print("Aktionen:", [x.name for x in bpy.data.actions])

for o in bpy.data.objects:
    o.select_set(o in (ob, arm))
bpy.context.view_layer.objects.active = arm
bpy.ops.export_scene.gltf(filepath=GLB, export_format='GLB', use_selection=True, export_apply=False,
    export_animations=True, export_animation_mode='ACTIONS', export_nla_strips=True, export_anim_slide_to_zero=True,
    export_force_sampling=True, export_frame_range=False, export_rest_position_armature=True, export_skins=True,
    export_morph=False, export_image_format='AUTO', export_texcoords=True, export_normals=True, export_yup=True)
print("GLB exportiert:", GLB, os.path.getsize(GLB), "Bytes nach %.0f s" % (time.time() - t0))
bpy.ops.wm.save_as_mainfile(filepath=OUT + "dragon_rig.blend")

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
ctr = mathutils.Vector((0, 0, 1.2))
cam.location = (6.5, -5.5, 3.2)
cam.rotation_euler = (ctr - cam.location).to_track_quat('-Z', 'Y').to_euler()
for act_name, frame in [("Idle", 36), ("Walk", 9), ("Run", 5), ("Attack_Heavy", 8), ("Attack_Light", 8), ("Death", 36)]:
    reset_pose()
    for tr in arm.animation_data.nla_tracks:
        tr.mute = tr.name != act_name
    scene.frame_set(frame)
    scene.render.filepath = OUT + "pose_" + act_name.lower() + ".png"
    bpy.ops.render.render(write_still=True)
for tr in arm.animation_data.nla_tracks:
    tr.mute = False
print("FERTIG nach %.0f s" % (time.time() - t0))
