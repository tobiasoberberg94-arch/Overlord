# Dunkles Junges (Tripo-FBX) → GLB mit radialem Rig: Körper, fünf Beine (unterer Teil, nach Winkelsektoren) und acht
# Tentakel (oberer Teil, nach Winkelsektoren). Aktionen: Idle (Tentakel wogen, Körper atmet), Walk (Beine heben sich
# reihum, Körper schaukelt), Roar (Tentakel peitschen hoch), Hit, Death (sackt zusammen).
# assets/models/characters/dark_young.glb – Höhe im Spiel 13 m (scripts/story/dark_young.gd skaliert).
#   blender.exe -b --python tools/pipeline/build_darkyoung.py [-- <Quellordner> [<Ziel-GLB>]]
import bpy, math, mathutils, time, os, sys, subprocess
import numpy as np

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
SRC = (argv[0] if len(argv) > 0 else "C:/Projekte/Overlord/Models/DunklesJunges/src").replace("\\", "/").rstrip("/") + "/"
REPO = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..")).replace("\\", "/")
GLB = (argv[1] if len(argv) > 1 else REPO + "/assets/models/characters/dark_young.glb").replace("\\", "/")
OUT = SRC + "build/"
os.makedirs(OUT, exist_ok=True)
SC = 13.0               # 1,0 Einheit → 13 m (haushoch wie in der Serie)
LEGS = 5
TENTACLES = 8
t0 = time.time()

conv = {"base": ("Material_01_BaseColor.png", OUT + "dy_basecolor.jpg", 2048, ["-q:v", "3", "-pix_fmt", "yuvj420p"]),
        "normal": ("Material_01_Normal.png", OUT + "dy_normal.png", 1024, []),
        "metallic": ("Material_01_Metallic.png", OUT + "dy_metallic.png", 1024, []),
        "roughness": ("Material_01_Roughness.png", OUT + "dy_roughness.png", 1024, [])}
for k, (src, dst, px, extra) in conv.items():
    if os.path.exists(SRC + src) and not os.path.exists(dst):
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", SRC + src, "-vf", "scale=%d:-1" % px] + extra + [dst], check=True)

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.fbx(filepath=SRC + "model.fbx")
ob = [o for o in bpy.data.objects if o.type == 'MESH'][0]
ob.name = "DarkYoung"
me = ob.data
me.name = "DarkYoung"
for img in list(bpy.data.images):
    for key, tag in [("base", "_Base"), ("metallic", "_Meta"), ("normal", "_Norm"), ("roughness", "_Roug")]:
        if tag in img.name:
            img.filepath = conv[key][1]
            img.source = 'FILE'
            img.reload()
            img.name = "dy_" + key
mat = me.materials[0]
mat.name = "DarkYoung"
for n in mat.node_tree.nodes:
    if n.type == 'TEX_IMAGE' and n.image and n.image.name == "dy_base":
        mat.node_tree.nodes.active = n
    if n.type == 'BSDF_PRINCIPLED':
        n.inputs["Specular IOR Level"].default_value = 0.4

ob.rotation_euler = (0.0, 0.0, math.radians(-90.0))
ob.scale = (SC, SC, SC)
ob.location = (0.0, 0.0, 0.5 * SC)
bpy.context.view_layer.objects.active = ob
for o in bpy.data.objects:
    o.select_set(o == ob)
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
N = len(me.vertices)
co = np.empty(N * 3, dtype=np.float64)
me.vertices.foreach_get("co", co)
co = co.reshape(N, 3)
H = co[:, 2].max()
cx, cy = float(np.median(co[:, 0])), float(np.median(co[:, 1]))
print("Maße: x %.2f..%.2f  y %.2f..%.2f  z %.2f..%.2f  Mitte (%.2f, %.2f)" % (co[:, 0].min(), co[:, 0].max(), co[:, 1].min(), co[:, 1].max(), co[:, 2].min(), H, cx, cy))

# Regionen: Beine (unteres Viertel, außerhalb des Kerns), Tentakel (oberhalb von 55 %, außerhalb des Kerns), Rest Körper
r = np.hypot(co[:, 0] - cx, co[:, 1] - cy)
ang = np.arctan2(co[:, 1] - cy, co[:, 0] - cx) % (2 * math.pi)
leg_zone = (co[:, 2] < 0.28 * H)
tent_zone = (co[:, 2] > 0.55 * H) & (r > 1.6)
# Beinsektoren: fünf gleich breite Sektoren, Startwinkel so wählen, dass die Sektorgrenzen in Lücken fallen
def best_offset(mask, k):
    best, bo = -1, 0.0
    for off in np.linspace(0, 2 * math.pi / k, 24, endpoint=False):
        sec = ((ang[mask] - off) % (2 * math.pi) / (2 * math.pi / k)).astype(int)
        counts = np.bincount(sec, minlength=k)
        score = counts.min()
        if score > best:
            best, bo = score, off
    return bo
leg_off = best_offset(leg_zone & (r > 1.2), LEGS)
tent_off = best_offset(tent_zone, TENTACLES)
leg_sec = ((ang - leg_off) % (2 * math.pi) / (2 * math.pi / LEGS)).astype(int)
tent_sec = ((ang - tent_off) % (2 * math.pi) / (2 * math.pi / TENTACLES)).astype(int)

arm_data = bpy.data.armatures.new("DarkYoungRig")
arm = bpy.data.objects.new("DarkYoungRig", arm_data)
bpy.context.scene.collection.objects.link(arm)
bpy.context.view_layer.objects.active = arm
arm.select_set(True)
bpy.ops.object.mode_set(mode='EDIT')
EB = {}
def bone(name, head, tail, parent=None, connect=False):
    b = arm_data.edit_bones.new(name)
    b.head = mathutils.Vector(head); b.tail = mathutils.Vector(tail)
    if parent:
        b.parent = EB[parent]; b.use_connect = connect
    EB[name] = b
bone("Root", (0, 0, 0), (0, 0, 1.0))
bone("Body", (cx, cy, 0.3 * H), (cx, cy, 0.75 * H), "Root")
leg_dirs = {}
for i in range(LEGS):
    sel = leg_zone & (leg_sec == i) & (r > 1.0)
    if sel.sum() < 50:
        sel = leg_zone & (leg_sec == i)
    foot = co[sel & (co[:, 2] < 0.12 * H)].mean(axis=0) if (sel & (co[:, 2] < 0.12 * H)).sum() > 20 else co[sel].mean(axis=0)
    hip = np.array((cx + (foot[0] - cx) * 0.45, cy + (foot[1] - cy) * 0.45, 0.32 * H))
    knee = (hip + foot) * 0.5 + np.array((0.0, 0.0, 0.03 * H))
    bone("Leg%d" % i, tuple(hip), tuple(knee), "Body")
    bone("Shin%d" % i, tuple(knee), tuple(foot), "Leg%d" % i, True)
    leg_dirs[i] = (foot - hip)
for i in range(TENTACLES):
    sel = tent_zone & (tent_sec == i)
    if sel.sum() < 30:
        a = tent_off + (i + 0.5) * 2 * math.pi / TENTACLES
        tip = np.array((cx + math.cos(a) * 2.5, cy + math.sin(a) * 2.5, 0.85 * H))
    else:
        far = sel & (r > np.percentile(r[sel], 60))
        tip = co[far].mean(axis=0)
    base = np.array((cx + (tip[0] - cx) * 0.35, cy + (tip[1] - cy) * 0.35, 0.62 * H))
    mid = (base + tip) * 0.5
    bone("Tent%d" % i, tuple(base), tuple(mid), "Body")
    bone("TentTip%d" % i, tuple(mid), tuple(tip), "Tent%d" % i, True)
bpy.ops.object.mode_set(mode='OBJECT')

# Gewichte: Beine/Tentakel je Sektor und Nähe zur Kette (Zelt zwischen Ober-/Unterglied), Rest Körper, dann glätten
names = ["Body"] + ["Leg%d" % i for i in range(LEGS)] + ["Shin%d" % i for i in range(LEGS)] + ["Tent%d" % i for i in range(TENTACLES)] + ["TentTip%d" % i for i in range(TENTACLES)]
idx = {nm: k for k, nm in enumerate(names)}
W = np.zeros((N, len(names)))
W[:, idx["Body"]] = 1.0
def chain_weights(mask, upper, lower):
    a_ = np.array(arm_data.bones[upper].head_local); m_ = np.array(arm_data.bones[upper].tail_local); b_ = np.array(arm_data.bones[lower].tail_local)
    pt = co[mask]
    tpar = np.zeros(len(pt)); dbest = np.full(len(pt), 1e9)
    for si, (p0, p1) in enumerate([(a_, m_), (m_, b_)]):
        ab = p1 - p0
        tt = np.clip(((pt - p0) @ ab) / (ab @ ab), 0.0, 1.0)
        d = np.linalg.norm(pt - (p0 + tt[:, None] * ab), axis=1)
        mm = d < dbest
        dbest[mm] = d[mm]; tpar[mm] = si + tt[mm]
    Wt = np.zeros((len(pt), len(names)))
    u_ = tpar - 0.5
    Wt[:, idx[upper]] = np.clip(1.0 - np.abs(u_ - 0) / 1.2, 0.0, 1.0)
    Wt[:, idx[lower]] = np.clip(1.0 - np.abs(u_ - 1) / 1.2, 0.0, 1.0)
    Wt[:, idx["Body"]] = np.clip(0.35 - tpar, 0.0, 0.35) * 2.5
    W[mask] = Wt / np.maximum(Wt.sum(axis=1, keepdims=True), 1e-6)
for i in range(LEGS):
    chain_weights(leg_zone & (leg_sec == i) & (r > 0.9), "Leg%d" % i, "Shin%d" % i)
for i in range(TENTACLES):
    chain_weights(tent_zone & (tent_sec == i), "Tent%d" % i, "TentTip%d" % i)
E = len(me.edges)
ev = np.empty(E * 2, dtype=np.int64)
me.edges.foreach_get("vertices", ev)
ev = ev.reshape(E, 2)
deg = np.maximum(np.bincount(ev[:, 0], minlength=N) + np.bincount(ev[:, 1], minlength=N), 1)[:, None]
for it in range(14):
    acc = np.zeros_like(W)
    np.add.at(acc, ev[:, 0], W[ev[:, 1]])
    np.add.at(acc, ev[:, 1], W[ev[:, 0]])
    W = 0.4 * W + 0.6 * acc / deg
W[W < 0.02] = 0.0
W /= np.maximum(W.sum(axis=1, keepdims=True), 1e-6)
print("Anteile:", {nm: round(float((np.argmax(W, axis=1) == k).mean()), 3) for k, nm in enumerate(names) if (np.argmax(W, axis=1) == k).mean() > 0.004})
LEVELS = 40
for k, nm in enumerate(names):
    vg = ob.vertex_groups.new(name=nm)
    q = np.rint(W[:, k] * LEVELS).astype(int)
    for lv in range(1, LEVELS + 1):
        ii = np.nonzero(q == lv)[0]
        if len(ii):
            vg.add(ii.tolist(), lv / LEVELS, 'REPLACE')
ob.parent = arm
mod = ob.modifiers.new("Armature", 'ARMATURE')
mod.object = arm
print("Rig fertig nach %.0f s" % (time.time() - t0))

# ---------------------------------------------------------------- Animationen (Welt-Achsen: Tentakel/Beine kippen radial nach außen/innen)
scene = bpy.context.scene
scene.render.fps = 24
pb = arm.pose.bones
for b in pb:
    b.rotation_mode = 'QUATERNION'
arm.animation_data_create()
def local_axis(bname, world_axis):
    return (arm_data.bones[bname].matrix_local.to_3x3().inverted() @ mathutils.Vector(world_axis)).normalized()
# Radiale Richtung je Glied (waagerecht, von der Mitte weg) und die dazu senkrechte Tangente (Kippachse)
def tangent(bname):
    h = arm_data.bones[bname].head_local
    d = mathutils.Vector((h.x - cx, h.y - cy, 0.0))
    if d.length < 0.01:
        d = mathutils.Vector((1, 0, 0))
    d.normalize()
    return mathutils.Vector((-d.y, d.x, 0.0))      # Drehung um die Tangente kippt das Glied radial
TANG = {nm: local_axis(nm, tangent(nm)) for nm in names if nm != "Body"}
UPAX = {nm: local_axis(nm, (0, 0, 1)) for nm in names if nm != "Body"}
def reset_pose():
    for b in pb:
        b.rotation_quaternion = (1, 0, 0, 0); b.location = (0, 0, 0); b.scale = (1, 1, 1)
def key_tilt(bname, frame, deg, twist=0.0):
    q = mathutils.Quaternion(TANG[bname], math.radians(deg)) @ mathutils.Quaternion(UPAX[bname], math.radians(twist))
    pb[bname].rotation_quaternion = q
    pb[bname].keyframe_insert("rotation_quaternion", frame=frame)
def key_body(frame, loc=None, scale=None, rot=None):
    b = pb["Body"]
    if loc is not None:
        b.location = loc; b.keyframe_insert("location", frame=frame)
    if scale is not None:
        b.scale = scale; b.keyframe_insert("scale", frame=frame)
    if rot is not None:
        b.rotation_quaternion = mathutils.Quaternion(local_axis("Body", rot[0]), math.radians(rot[1])); b.keyframe_insert("rotation_quaternion", frame=frame)
def key_root(frame, loc):
    pb["Root"].location = loc; pb["Root"].keyframe_insert("location", frame=frame)
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

# Idle: Tentakel wogen mit Phasen, Körper atmet (96 Bilder)
a = begin("Idle")
L = 96
for s in range(13):
    f = 1 + s * 8
    ph = s / 12 * 2 * math.pi
    key_body(f, scale=(1.0 + 0.025 * math.sin(ph), 1.0 + 0.025 * math.sin(ph), 1.0 + 0.04 * math.sin(ph)))
    for i in range(TENTACLES):
        p = ph + i * 0.9
        key_tilt("Tent%d" % i, f, 7 * math.sin(p), 10 * math.sin(p * 0.7))
        key_tilt("TentTip%d" % i, f, 12 * math.sin(p + 1.2), 14 * math.sin(p * 0.8 + 0.5))
finish(a, L)

# Walk: Beine heben sich reihum (Kippen nach innen beim Anheben), Körper schaukelt (40 Bilder)
a = begin("Walk")
L = 40
for s in range(11):
    f = 1 + s * 4
    ph = s / 10 * 2 * math.pi
    for i in range(LEGS):
        p = ph + i * 2 * math.pi * 2.0 / LEGS
        lift = max(0.0, math.sin(p))
        key_tilt("Leg%d" % i, f, -14 * lift)
        key_tilt("Shin%d" % i, f, 22 * lift)
    key_root(f, (0, 0, 0.18 * abs(math.sin(ph * 2.5))))
    key_body(f, rot=((1, 0, 0), 2.5 * math.sin(ph)))
    for i in range(TENTACLES):
        key_tilt("Tent%d" % i, f, 6 * math.sin(ph + i), 0)
        key_tilt("TentTip%d" % i, f, 10 * math.sin(ph + i + 1.0), 0)
finish(a, L)

# Roar: Körper bläht sich, Tentakel peitschen nach oben und außen (30 Bilder)
a = begin("Roar")
for f, s in [(1, 1.0), (8, 1.1), (22, 1.08), (30, 1.0)]:
    key_body(f, scale=(s, s, s * 1.05))
for i in range(TENTACLES):
    for f, d in [(1, 0), (8, -35), (22, -25), (30, 0)]:
        key_tilt("Tent%d" % i, f, d, 15 * math.sin(i))
        key_tilt("TentTip%d" % i, f, d * 0.8, 0)
finish(a, 30)

# Hit (10), Death (48): sackt zusammen, Beine knicken, Tentakel hängen
a = begin("Hit")
for f, s in [(1, 1.0), (3, 0.96), (10, 1.0)]:
    key_body(f, scale=(1.0 / s, 1.0 / s, s))
finish(a, 10)
a = begin("Death")
for f, z in [(1, 0.0), (14, -0.6), (36, -0.24 * H), (48, -0.25 * H)]:
    key_root(f, (0, 0, z))
for i in range(LEGS):
    for f, d in [(1, 0), (36, 45), (48, 48)]:
        key_tilt("Leg%d" % i, f, d)
        key_tilt("Shin%d" % i, f, -d * 0.6)
for i in range(TENTACLES):
    for f, d in [(1, 0), (36, 40), (48, 42)]:
        key_tilt("Tent%d" % i, f, d)
        key_tilt("TentTip%d" % i, f, d * 0.9)
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
bpy.ops.wm.save_as_mainfile(filepath=OUT + "dy_rig.blend")

scene.render.engine = 'BLENDER_WORKBENCH'
scene.display.shading.light = 'STUDIO'
scene.display.shading.color_type = 'TEXTURE'
scene.render.resolution_x = 600
scene.render.resolution_y = 600
cam_data = bpy.data.cameras.new("cam")
cam = bpy.data.objects.new("cam", cam_data)
scene.collection.objects.link(cam)
scene.camera = cam
ctr = mathutils.Vector((cx, cy, H * 0.5))
cam.location = ctr + mathutils.Vector((H * 1.3, -H * 1.6, H * 0.35))
cam.rotation_euler = (ctr - cam.location).to_track_quat('-Z', 'Y').to_euler()
for act_name, frame in [("Idle", 33), ("Walk", 13), ("Roar", 8), ("Death", 48)]:
    reset_pose()
    for tr in arm.animation_data.nla_tracks:
        tr.mute = tr.name != act_name
    scene.frame_set(frame)
    scene.render.filepath = OUT + "pose_" + act_name.lower() + ".png"
    bpy.ops.render.render(write_still=True)
print("FERTIG nach %.0f s" % (time.time() - t0))
