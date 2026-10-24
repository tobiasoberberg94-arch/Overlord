# Victim (Tripo-FBX, schwebender Engel der 8. Ebene) → GLB mit einfachem Rig: Körper schwebt und atmet, die Zweig-Flügel
# wiegen sich; Aktionen Idle, Hit, Death (sinkt zu Boden). assets/models/characters/victim.glb
#   blender.exe -b --python tools/pipeline/build_victim.py [-- <Quellordner> [<Ziel-GLB>]]
import bpy, math, mathutils, time, os, sys, subprocess
import numpy as np

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
SRC = (argv[0] if len(argv) > 0 else "C:/Projekte/Overlord/Models/Victim/src").replace("\\", "/").rstrip("/") + "/"
REPO = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..")).replace("\\", "/")
GLB = (argv[1] if len(argv) > 1 else REPO + "/assets/models/characters/victim.glb").replace("\\", "/")
OUT = SRC + "build/"
os.makedirs(OUT, exist_ok=True)
SC = 1.5                 # 1,0 Einheit hoch → 1,5 m
HOVER = 0.7              # schwebt 0,7 m über dem Boden
t0 = time.time()

conv = {"base": ("Material_01_BaseColor.png", OUT + "victim_basecolor.jpg", 2048, ["-q:v", "3", "-pix_fmt", "yuvj420p"]),
        "normal": ("Material_01_Normal.png", OUT + "victim_normal.png", 1024, []),
        "metallic": ("Material_01_Metallic.png", OUT + "victim_metallic.png", 1024, []),
        "roughness": ("Material_01_Roughness.png", OUT + "victim_roughness.png", 1024, [])}
for k, (src, dst, px, extra) in conv.items():
    if os.path.exists(SRC + src) and not os.path.exists(dst):
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", SRC + src, "-vf", "scale=%d:-1" % px] + extra + [dst], check=True)

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.fbx(filepath=SRC + "model.fbx")
ob = [o for o in bpy.data.objects if o.type == 'MESH'][0]
ob.name = "Victim"
me = ob.data
me.name = "Victim"
for img in list(bpy.data.images):
    for key, tag in [("base", "_Base"), ("metallic", "_Meta"), ("normal", "_Norm"), ("roughness", "_Roug")]:
        if tag in img.name:
            img.filepath = conv[key][1]
            img.source = 'FILE'
            img.reload()
            img.name = "victim_" + key
mat = me.materials[0]
mat.name = "Victim"
for n in mat.node_tree.nodes:
    if n.type == 'TEX_IMAGE' and n.image and n.image.name == "victim_base":
        mat.node_tree.nodes.active = n
    if n.type == 'BSDF_PRINCIPLED':
        n.inputs["Specular IOR Level"].default_value = 0.35

# Blick nach -Y (Tripo: +X), Unterkante auf HOVER
ob.rotation_euler = (0.0, 0.0, math.radians(-90.0))
ob.scale = (SC, SC, SC)
ob.location = (0.0, 0.0, 0.5 * SC + HOVER)
bpy.context.view_layer.objects.active = ob
for o in bpy.data.objects:
    o.select_set(o == ob)
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
N = len(me.vertices)
co = np.empty(N * 3, dtype=np.float64)
me.vertices.foreach_get("co", co)
co = co.reshape(N, 3)
print("Maße: x %.2f..%.2f  y %.2f..%.2f  z %.2f..%.2f" % (co[:, 0].min(), co[:, 0].max(), co[:, 1].min(), co[:, 1].max(), co[:, 2].min(), co[:, 2].max()))

arm_data = bpy.data.armatures.new("VictimRig")
arm = bpy.data.objects.new("VictimRig", arm_data)
bpy.context.scene.collection.objects.link(arm)
bpy.context.view_layer.objects.active = arm
arm.select_set(True)
bpy.ops.object.mode_set(mode='EDIT')
EB = {}
def bone(name, head, tail, parent=None):
    b = arm_data.edit_bones.new(name)
    b.head = mathutils.Vector(head); b.tail = mathutils.Vector(tail)
    if parent:
        b.parent = EB[parent]
    EB[name] = b
zc = (co[:, 2].min() + co[:, 2].max()) * 0.5
bone("Root", (0, 0, 0), (0, 0, 0.3))
bone("Body", (0, 0, HOVER + 0.1), (0, 0, zc + 0.5), "Root")
bone("Head", (0, -0.1, zc + 0.3), (0, -0.4, zc + 0.6), "Body")
# Zweig-Flügel: seitlich weit außen, je Seite Schwerpunkt der äußeren Vertices
for side, sgn in [("L", 1.0), ("R", -1.0)]:
    sel = co[:, 0] * sgn > 0.32
    tip = co[sel].mean(axis=0) if sel.sum() > 30 else np.array((0.55 * sgn, 0.0, zc + 0.3))
    bone("Wing_" + side, (0.2 * sgn, tip[1], zc + 0.2), tuple(tip), "Body")
bpy.ops.object.mode_set(mode='OBJECT')

# Gewichte: Flügel per Flutfüllung (|x| > 0,22 m), Kopf nach vorn/oben, Rest Körper
E = len(me.edges)
ev = np.empty(E * 2, dtype=np.int64)
me.edges.foreach_get("vertices", ev)
ev = ev.reshape(E, 2)
ax = np.abs(co[:, 0])
allowed = ax > 0.22
is_wing = ax > 0.45
for it in range(300):
    grow = is_wing.copy()
    grow[ev[:, 1][is_wing[ev[:, 0]]]] = True
    grow[ev[:, 0][is_wing[ev[:, 1]]]] = True
    grow &= allowed
    if grow.sum() == is_wing.sum():
        break
    is_wing = grow
names = ["Body", "Head", "Wing_L", "Wing_R"]
W = np.zeros((N, 4))
W[:, 0] = 1.0
head_sel = (co[:, 2] > zc + 0.25) & (co[:, 1] < -0.05) & ~is_wing
W[head_sel, 0] = 0.0; W[head_sel, 1] = 1.0
W[is_wing & (co[:, 0] > 0), :] = 0.0; W[is_wing & (co[:, 0] > 0), 2] = 1.0
W[is_wing & (co[:, 0] < 0), :] = 0.0; W[is_wing & (co[:, 0] < 0), 3] = 1.0
deg = np.maximum(np.bincount(ev[:, 0], minlength=N) + np.bincount(ev[:, 1], minlength=N), 1)[:, None]
for it in range(10):
    acc = np.zeros_like(W)
    np.add.at(acc, ev[:, 0], W[ev[:, 1]])
    np.add.at(acc, ev[:, 1], W[ev[:, 0]])
    W = 0.4 * W + 0.6 * acc / deg
W[W < 0.02] = 0.0
W /= np.maximum(W.sum(axis=1, keepdims=True), 1e-6)
print("Flügel-Vertices %d · Anteile:" % is_wing.sum(), {nm: round(float((np.argmax(W, axis=1) == i).mean()), 3) for i, nm in enumerate(names)})
LEVELS = 40
for i, nm in enumerate(names):
    vg = ob.vertex_groups.new(name=nm)
    q = np.rint(W[:, i] * LEVELS).astype(int)
    for lv in range(1, LEVELS + 1):
        idx = np.nonzero(q == lv)[0]
        if len(idx):
            vg.add(idx.tolist(), lv / LEVELS, 'REPLACE')
ob.parent = arm
mod = ob.modifiers.new("Armature", 'ARMATURE')
mod.object = arm

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

# Idle: schwebt auf und ab, dreht sich leicht, Zweige wiegen, Kopf nickt (96 Bilder)
a = begin("Idle")
for f, z in [(1, 0.0), (48, 0.12), (96, 0.0)]:
    key("Root", f, loc=(0, 0, z))
for f, r in [(1, 0), (24, 3), (48, 0), (72, -3), (96, 0)]:
    key("Body", f, rot=(0, r, 0))
for f, s in [(1, 1.0), (48, 1.025), (96, 1.0)]:
    key("Body", f, scale=(s, s, s))
for f, r in [(1, 0), (24, 6), (48, 0), (72, -6), (96, 0)]:
    key("Wing_L", f, rot=(r, 0, -r * 0.5)); key("Wing_R", f, rot=(r, 0, r * 0.5))
for f, r in [(1, 0), (48, 4), (96, 0)]:
    key("Head", f, rot=(r, 0, 0))
finish(a, 96)
a = begin("Walk")
for f, z in [(1, 0.0), (24, 0.1), (48, 0.0)]:
    key("Root", f, loc=(0, 0, z))
for f, r in [(1, 6), (24, -6), (48, 6)]:
    key("Wing_L", f, rot=(r, 0, 0)); key("Wing_R", f, rot=(r, 0, 0))
for f, r in [(1, 4), (48, 4)]:
    key("Body", f, rot=(r, 0, 0))
finish(a, 48)
a = begin("Hit")
for f, r in [(1, 0), (3, -10), (10, 0)]:
    key("Body", f, rot=(r, 0, 0))
for f, y in [(1, 0.0), (3, 0.1), (10, 0.0)]:
    key("Root", f, loc=(0, y, 0))
finish(a, 10)
a = begin("Death")
for f, (z, r) in [(1, (0.0, 0)), (12, (0.1, 10)), (36, (-HOVER - 0.1, 75)), (48, (-HOVER - 0.1, 78))]:
    key("Root", f, loc=(0, 0, z), rot=(0, r, 0))
for f, r in [(1, 0), (36, -40), (48, -42)]:
    key("Wing_L", f, rot=(r, 0, 0)); key("Wing_R", f, rot=(r, 0, 0))
finish(a, 48)
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

scene.render.engine = 'BLENDER_WORKBENCH'
scene.display.shading.light = 'STUDIO'
scene.display.shading.color_type = 'TEXTURE'
scene.render.resolution_x = 600
scene.render.resolution_y = 600
cam_data = bpy.data.cameras.new("cam")
cam = bpy.data.objects.new("cam", cam_data)
scene.collection.objects.link(cam)
scene.camera = cam
ctr = mathutils.Vector((0, 0, zc))
cam.location = (2.2, -3.0, zc + 0.6)
cam.rotation_euler = (ctr - cam.location).to_track_quat('-Z', 'Y').to_euler()
for act_name, frame in [("Idle", 24), ("Death", 48)]:
    reset_pose()
    for tr in arm.animation_data.nla_tracks:
        tr.mute = tr.name != act_name
    scene.frame_set(frame)
    scene.render.filepath = OUT + "pose_" + act_name.lower() + ".png"
    bpy.ops.render.render(write_still=True)
print("FERTIG nach %.0f s" % (time.time() - t0))
