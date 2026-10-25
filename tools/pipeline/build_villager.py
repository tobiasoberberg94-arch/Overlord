# Dorfbewohner-Modell (Mann/Frau) um ein vorhandenes Mixamo-Rig bauen – ohne fremde Downloads.
# Spender: assets/models/characters/demiurge.glb (T-Pose, 1,84 m, Mixamo-Knochen, Clips idle/walk/run/hit/death/
# dodge/block/attack/cast). Der Spender-Körper wird verworfen, ein stilisierter Körper (Skin-Modifier + Subdivision)
# samt Kopf mit Gesicht, Frisuren, Hüten, Rüstungsteilen, Kleid, Schürze, Umhang und Wappenrock wird neu gebaut,
# automatisch gewichtet (Bone Heat) und mit allen Animationen als GLB exportiert. Die Spiellogik
# (scripts/world3d/villager_look.gd) färbt die Materialien je Bewohner und blendet Teile ein.
# Aufruf: blender -b --python build_villager.py -- m|f <out.glb> [renderdir]
import bpy, bmesh, sys, os, math
import numpy as np
from mathutils import Vector, Matrix

args = sys.argv[sys.argv.index("--") + 1:]
VARIANT = args[0]
OUT = os.path.abspath(args[1])
RENDER_DIR = args[2] if len(args) > 2 else ""
CLIP_DIRS = [a.split("=", 1)[1] for a in args[3:] if a.startswith("clips=")] or [r"C:\Projekte\Overlord\Models\Sebas\mixamo_civil"]
DONOR = r"C:\Projekte\Overlord\repo\assets\models\characters\demiurge.glb"
TEX_DIR = os.path.join(os.path.dirname(OUT), "villager_tex")
os.makedirs(TEX_DIR, exist_ok=True)
F = VARIANT == "f"
C = VARIANT == "c"          # Kind: großer Kopf, schmale Schultern, dünne Glieder (im Spiel auf ~0,6 skaliert)

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=DONOR)
scene = bpy.context.scene
scene.render.fps = 24
arm = [o for o in bpy.data.objects if o.type == 'ARMATURE'][0]
for o in list(bpy.data.objects):
    if o.type != 'ARMATURE':
        bpy.data.objects.remove(o)
for img in list(bpy.data.images):
    bpy.data.images.remove(img)
for m in list(bpy.data.materials):
    bpy.data.materials.remove(m)
arm.name = "Villager"
arm.data.name = "Villager"

# --- Animationen: jede Aktion als eigene NLA-Spur (so exportiert der glTF-Exporter sie alle), Namen ohne Suffix
if arm.animation_data is None:
    arm.animation_data_create()
ad = arm.animation_data
ad.action = None
for tr in list(ad.nla_tracks):
    ad.nla_tracks.remove(tr)
for a in list(bpy.data.actions):
    a.name = a.name.replace("_Albedo", "").replace("_Demiurge", "")
    a.use_fake_user = True
    tr = ad.nla_tracks.new()
    tr.name = a.name
    st = tr.strips.new(a.name, int(a.frame_range[0]), a)
    st.mute = False
print("Aktionen:", [a.name for a in bpy.data.actions])

# --- Zusätzliche Mixamo-Clips ohne Skin (z. B. Reden, Jubeln, Beten, Sitzen von einem anderen Mixamo-Rig) auf dieses Rig
# übertragen – Weltraum-Rotationsdeltas je Knochen wie in build_character.py (_retarget), Hüfte an Ort und Stelle.
def _retarget(src_arm, tgt_arm, name):
    from mathutils import Quaternion
    sb = {b.name.split(":")[-1]: b for b in src_arm.data.bones}
    order = [b for b in tgt_arm.data.bones]                     # Eltern vor Kindern (Blender-Reihenfolge)
    smw = src_arm.matrix_world.to_quaternion()
    tmw = tgt_arm.matrix_world.to_quaternion()
    rest_s = {k: smw @ b.matrix_local.to_quaternion() for k, b in sb.items()}
    rest_t = {b.name: tmw @ b.matrix_local.to_quaternion() for b in order}
    hips_s = next((b for k, b in sb.items() if k == "Hips"), None)
    hips_t = next((b for b in order if b.name.split(":")[-1] == "Hips"), None)
    h_s = (src_arm.matrix_world @ hips_s.head_local).z if hips_s else 1.0
    h_t = (tgt_arm.matrix_world @ hips_t.head_local).z if hips_t else 1.0
    ratio = h_t / h_s if abs(h_s) > 1e-6 else 1.0
    act = bpy.data.actions.new(name)
    if tgt_arm.animation_data is None:
        tgt_arm.animation_data_create()
    tgt_arm.animation_data.action = act
    src_act = src_arm.animation_data.action
    f0, f1 = int(src_act.frame_range[0]), int(src_act.frame_range[1])
    for pb in tgt_arm.pose.bones:
        pb.rotation_mode = "QUATERNION"
    for f in range(f0, f1 + 1):
        bpy.context.scene.frame_set(f)
        arm_pose = {}
        for b in order:
            key = b.name.split(":")[-1]
            pb = tgt_arm.pose.bones[b.name]
            if key in sb:
                sp = src_arm.pose.bones[sb[key].name]
                delta = (smw @ sp.matrix.to_quaternion()) @ rest_s[key].inverted()
                q_arm = tmw.inverted() @ (delta @ rest_t[b.name])
            else:   # Knochen ohne Gegenstück: Ruhelage relativ zum Elternteil
                q_arm = (arm_pose[b.parent.name] @ (b.parent.matrix_local.to_quaternion().inverted() @ b.matrix_local.to_quaternion())) if b.parent else b.matrix_local.to_quaternion()
            arm_pose[b.name] = q_arm
            if b.parent:
                rel = b.parent.matrix_local.to_quaternion().inverted() @ b.matrix_local.to_quaternion()
                loc_q = rel.inverted() @ arm_pose[b.parent.name].inverted() @ q_arm
            else:
                loc_q = b.matrix_local.to_quaternion().inverted() @ q_arm
            pb.rotation_quaternion = loc_q
            pb.keyframe_insert("rotation_quaternion", frame=f)
            if key == "Hips" and hips_s is not None:
                sp = src_arm.pose.bones[hips_s.name]
                d_world = (src_arm.matrix_world @ sp.head) - (src_arm.matrix_world @ hips_s.head_local)
                d_world.x = 0.0          # an Ort und Stelle: die Fortbewegung macht das Spiel
                d_world.y = 0.0
                d_arm = tgt_arm.matrix_world.inverted().to_3x3() @ (d_world * ratio)
                pb.location = b.matrix_local.to_3x3().inverted() @ d_arm
                pb.keyframe_insert("location", frame=f)
    tgt_arm.animation_data.action = None
    return act

import glob
def imported(fn):
    before = set(bpy.data.objects)
    fn()
    return [o for o in bpy.data.objects if o not in before]

for cdir in CLIP_DIRS:
    for path in sorted(glob.glob(os.path.join(cdir, "*.fbx"))):
        cname = os.path.splitext(os.path.basename(path))[0]
        if cname.startswith("_") or bpy.data.actions.get(cname):
            continue
        new = imported(lambda: bpy.ops.import_scene.fbx(filepath=path, automatic_bone_orientation=False))
        sa = next((o for o in new if o.type == "ARMATURE"), None)
        if sa is None:
            print("Clip ohne Armatur:", path)
            continue
        ad.action = None
        act = _retarget(sa, arm, cname)
        act.use_fake_user = True
        tr = ad.nla_tracks.new()
        tr.name = cname
        st = tr.strips.new(cname, int(act.frame_range[0]), act)
        st.mute = False
        for o in new:
            bpy.data.objects.remove(o)
        for a in list(bpy.data.actions):
            if a.users == 0:
                bpy.data.actions.remove(a)
        print("Clip übernommen:", cname, int(act.frame_range[1]), "Bilder")
for pb in arm.pose.bones:
    pb.location = (0, 0, 0)
    pb.rotation_quaternion = (1, 0, 0, 0)
    pb.rotation_euler = (0, 0, 0)
    pb.scale = (1, 1, 1)
scene.frame_set(0)

# Finger- und Endknochen verformen nicht (Fäustlinge, saubere Gewichte)
for b in arm.data.bones:
    n = b.name
    b.use_deform = not ("Thumb" in n or "Index" in n or "Middle" in n or "Ring" in n or "Pinky" in n or n.endswith("_End"))

MW = arm.matrix_world.copy()
def P(name):
    return MW @ arm.data.bones["mixamorig:" + name].head_local

hips, spine, spine1, spine2, neck, head, headtop = [P(n) for n in ["Hips", "Spine", "Spine1", "Spine2", "Neck", "Head", "HeadTop_End"]]
larm, lfore, lhand = P("LeftArm"), P("LeftForeArm"), P("LeftHand")
rarm, rfore, rhand = P("RightArm"), P("RightForeArm"), P("RightHand")
lup, lleg, lfoot, ltoe = P("LeftUpLeg"), P("LeftLeg"), P("LeftFoot"), P("LeftToeBase")
rup, rleg, rfoot, rtoe = P("RightUpLeg"), P("RightLeg"), P("RightFoot"), P("RightToeBase")
hy = head.y - 0.01           # Kopfmitte (Tiefe); Blick -Y (Blender) = +Z (Godot)
HC = Vector((0.0, hy, head.z + 0.125))   # Kopfmitte
print("Landmarken: Hüfte %.3f Hals %.3f Kopf %.3f Scheitel %.3f Schulter x %.3f Ellbogen x %.3f Hand x %.3f Knie %.3f Knöchel %.3f" % (
    hips.z, neck.z, head.z, headtop.z, larm.x, lfore.x, lhand.x, lleg.z, lfoot.z))

# ---------------------------------------------------------------- Hilfen
def new_obj(name, bm):
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new(name, me)
    scene.collection.objects.link(ob)
    for p in me.polygons:
        p.use_smooth = True
    return ob

def tf(bm, verts, loc=(0, 0, 0), scale=(1, 1, 1), rot=(0, 0, 0)):
    m = Matrix.Translation(Vector(loc))
    r = Matrix.Rotation(math.radians(rot[0]), 4, 'X') @ Matrix.Rotation(math.radians(rot[1]), 4, 'Y') @ Matrix.Rotation(math.radians(rot[2]), 4, 'Z')
    s = Matrix.Diagonal((scale[0], scale[1], scale[2], 1.0))
    bmesh.ops.transform(bm, matrix=m @ r @ s, verts=verts)

def add_sphere(bm, center, radius, scale=(1, 1, 1), rot=(0, 0, 0), seg=24, rings=16):
    g = bmesh.ops.create_uvsphere(bm, u_segments=seg, v_segments=rings, radius=radius)
    tf(bm, g["verts"], center, scale, rot)
    return g["verts"]

def add_cone(bm, center, r1, r2, depth, seg=24, rot=(0, 0, 0), scale=(1, 1, 1)):
    g = bmesh.ops.create_cone(bm, cap_ends=True, segments=seg, radius1=r1, radius2=r2, depth=depth)
    tf(bm, g["verts"], center, scale, rot)
    return g["verts"]

def add_box(bm, center, size, rot=(0, 0, 0)):
    g = bmesh.ops.create_cube(bm, size=1.0)
    tf(bm, g["verts"], center, size, rot)
    return g["verts"]

def add_torus(bm, center, R, r, seg=24, rings=10, scale=(1, 1, 1), rot=(0, 0, 0)):
    vs = []
    for i in range(seg):
        a = 2 * math.pi * i / seg
        ring = []
        for j in range(rings):
            b = 2 * math.pi * j / rings
            x = (R + r * math.cos(b)) * math.cos(a)
            y = (R + r * math.cos(b)) * math.sin(a)
            z = r * math.sin(b)
            ring.append(bm.verts.new((x, y, z)))
        vs.append(ring)
    for i in range(seg):
        for j in range(rings):
            bm.faces.new((vs[i][j], vs[(i + 1) % seg][j], vs[(i + 1) % seg][(j + 1) % rings], vs[i][(j + 1) % rings]))
    allv = [v for ring in vs for v in ring]
    tf(bm, allv, center, scale, rot)
    return allv

def add_arc(bm, rx, ry, z0, z1, a0, a1, cy, segs=12, rings=5, flare=0.0, thick=0.012):
    """Gewölbte Stoffbahn um den Rumpf: Ellipse (rx, ry) um (0, cy), Winkel a0..a1 in Grad (0 = vorn, 180 = hinten),
    von z0 (unten) bis z1 (oben); flare weitet den Saum nach unten. Mit Dicke (beidseitig sichtbar)."""
    rows = []
    for j in range(rings + 1):
        t = j / rings
        z = z1 + (z0 - z1) * t
        f = 1.0 + flare * t
        row = []
        for i in range(segs + 1):
            a = math.radians(a0 + (a1 - a0) * i / segs)
            row.append(bm.verts.new((rx * f * math.sin(a), cy - ry * f * math.cos(a), z)))
        rows.append(row)
    faces = []
    for j in range(rings):
        for i in range(segs):
            faces.append(bm.faces.new((rows[j][i], rows[j][i + 1], rows[j + 1][i + 1], rows[j + 1][i])))
    bmesh.ops.recalc_face_normals(bm, faces=faces)
    if thick > 0:
        bmesh.ops.solidify(bm, geom=faces, thickness=thick)
    return faces

def set_material(ob, mats, chooser):
    """mats: Liste von Materialien; chooser(face_center, normal) -> Index."""
    me = ob.data
    for m in mats:
        me.materials.append(m)
    for p in me.polygons:
        p.material_index = chooser(Vector(p.center), Vector(p.normal))

def box_uv(ob, tiling=6.0):
    me = ob.data
    if not me.uv_layers:
        me.uv_layers.new(name="UVMap")
    uv = me.uv_layers[0].data
    for p in me.polygons:
        n = p.normal
        ax = max(range(3), key=lambda i: abs(n[i]))
        for li in p.loop_indices:
            co = me.vertices[me.loops[li].vertex_index].co
            if ax == 0:
                u, v = co.y, co.z
            elif ax == 1:
                u, v = co.x, co.z
            else:
                u, v = co.x, co.y
            uv[li].uv = (u * tiling, v * tiling)

def weight_all(ob, bone, w=1.0):
    vg = ob.vertex_groups.new(name="mixamorig:" + bone)
    vg.add(list(range(len(ob.data.vertices))), w, 'REPLACE')

def weight_by(ob, fn):
    """fn(co) -> {bone: weight}; Gewichte normiert."""
    ob.vertex_groups.clear()
    groups = {}
    for i, v in enumerate(ob.data.vertices):
        d = fn(Vector(v.co))
        s = sum(d.values())
        for b, w in d.items():
            if w <= 0.0:
                continue
            if b not in groups:
                groups[b] = ob.vertex_groups.new(name="mixamorig:" + b)
            groups[b].add([i], w / s, 'REPLACE')

def attach(ob):
    ob.parent = arm
    ob.matrix_parent_inverse = arm.matrix_world.inverted()
    md = ob.modifiers.new("Armature", 'ARMATURE')
    md.object = arm

# Gewichte am Rumpf nach Höhe (Umhang, Schürze, Wappenrock, Rüstung)
def torso_weight(co):
    z = co.z
    if z >= spine2.z:
        return {"Spine2": 1.0}
    if z >= spine1.z:
        t = (z - spine1.z) / (spine2.z - spine1.z)
        return {"Spine2": t, "Spine1": 1 - t}
    if z >= spine.z:
        t = (z - spine.z) / (spine1.z - spine.z)
        return {"Spine1": t, "Spine": 1 - t}
    if z >= hips.z - 0.05:
        t = (z - (hips.z - 0.05)) / (spine.z - (hips.z - 0.05))
        return {"Spine": t, "Hips": 1 - t}
    return {"Hips": 1.0}

# ---------------------------------------------------------------- Texturen (Leinen, Leder) prozedural
def write_tex(name, arr):
    size = arr.shape[0]
    img = bpy.data.images.new(name, size, size, alpha=False)
    rgba = np.ones((size, size, 4), dtype=np.float32)
    rgba[..., 0] = arr
    rgba[..., 1] = arr
    rgba[..., 2] = arr
    img.pixels = rgba.ravel().tolist()
    img.filepath_raw = os.path.join(TEX_DIR, name + ".png")
    img.file_format = 'PNG'
    img.save()
    img.pack()
    return img

rng = np.random.default_rng(7)
S = 256
yy, xx = np.mgrid[0:S, 0:S]
ta = 0.5 + 0.5 * np.sin(xx * 2 * np.pi / 8.0)
tb = 0.5 + 0.5 * np.sin(yy * 2 * np.pi / 8.0)
weave = 0.80 + 0.10 * np.where(((xx // 8 + yy // 8) % 2) == 0, ta, tb) + 0.06 * ta * tb
linen = np.clip(weave + rng.normal(0, 0.018, (S, S)), 0, 1).astype(np.float32)
grain = rng.normal(0, 1, (S, S))
for _ in range(3):
    grain = (grain + np.roll(grain, 1, 0) + np.roll(grain, -1, 0) + np.roll(grain, 1, 1) + np.roll(grain, -1, 1)) / 5.0
leather = np.clip(0.82 + 0.05 * grain / (grain.std() + 1e-6) + rng.normal(0, 0.02, (S, S)), 0, 1).astype(np.float32)
IMG_LINEN = write_tex("villager_linen", linen)
IMG_LEATHER = write_tex("villager_leather", leather)

def material(name, rgb, rough=0.8, metal=0.0, tex=None):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    bsdf = m.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = (rgb[0], rgb[1], rgb[2], 1.0)
    bsdf.inputs["Roughness"].default_value = rough
    bsdf.inputs["Metallic"].default_value = metal
    m.diffuse_color = (rgb[0], rgb[1], rgb[2], 1.0)
    m.roughness = rough
    m.metallic = metal
    if tex is not None:
        t = m.node_tree.nodes.new("ShaderNodeTexImage")
        t.image = tex
        m.node_tree.links.new(t.outputs["Color"], bsdf.inputs["Base Color"])
    return m

M_SKIN = material("Skin", (0.87, 0.72, 0.60), 0.6)
M_HAIR = material("Hair", (0.25, 0.16, 0.10), 0.55)
M_TOP = material("Top", (0.45, 0.35, 0.25), 0.85, tex=IMG_LINEN)
M_BOTTOM = material("Bottom", (0.30, 0.26, 0.22), 0.85, tex=IMG_LINEN)
M_BOOTS = material("Boots", (0.22, 0.15, 0.10), 0.6, tex=IMG_LEATHER)
M_TRIM = material("Trim", (0.55, 0.42, 0.22), 0.5, tex=IMG_LEATHER)
M_EYE = material("Eye", (0.95, 0.95, 0.93), 0.3)
M_PUPIL = material("Pupil", (0.12, 0.08, 0.06), 0.25)
M_MOUTH = material("Mouth", (0.45, 0.18, 0.16), 0.6)
M_METAL = material("Metal", (0.62, 0.63, 0.66), 0.35, 0.9)
M_APRON = material("Apron", (0.92, 0.90, 0.86), 0.9, tex=IMG_LINEN)
M_CAPE = material("Cape", (0.40, 0.10, 0.10), 0.85, tex=IMG_LINEN)
M_TABARD = material("Tabard", (0.15, 0.20, 0.45), 0.85, tex=IMG_LINEN)
M_SKIRT = material("Skirt", (0.35, 0.28, 0.22), 0.85, tex=IMG_LINEN)
M_HAT = material("Hat", (0.35, 0.28, 0.18), 0.8, tex=IMG_LINEN)
M_GOLD = material("Gold", (0.85, 0.68, 0.25), 0.3, 0.9)
M_HOOD = material("Hood", (0.28, 0.18, 0.36), 0.85, tex=IMG_LINEN)

# ---------------------------------------------------------------- Körper (Skin-Modifier + Subdivision)
objs = []
bm = bmesh.new()
sv = {}
def skv(name, co, rx, ry):
    sv[name] = (bm.verts.new(co), rx, ry)
sy = spine.y
shoulder_r = 0.055 if C else (0.062 if F else 0.075)
if C:
    skv("pelvis", (0, hips.y, hips.z - 0.02), 0.15, 0.105)
    skv("waist", (0, sy, spine.z + 0.03), 0.135, 0.10)
    skv("chest", (0, spine1.y, spine1.z + 0.02), 0.145, 0.11)
    skv("upper", (0, spine2.y, spine2.z + 0.02), 0.14, 0.105)
    skv("neck", (0, neck.y, neck.z + 0.005), 0.05, 0.05)
    skv("necktop", (0, neck.y, neck.z + 0.07), 0.048, 0.048)
else:
    skv("pelvis", (0, hips.y, hips.z - 0.02), 0.19 if F else 0.175, 0.125 if F else 0.115)
    skv("waist", (0, sy, spine.z + 0.03), 0.135 if F else 0.16, 0.10 if F else 0.115)
    skv("chest", (0, spine1.y, spine1.z + 0.02), 0.165 if F else 0.185, 0.125 if F else 0.13)
    skv("upper", (0, spine2.y, spine2.z + 0.02), 0.155 if F else 0.19, 0.115 if F else 0.125)
    skv("neck", (0, neck.y, neck.z + 0.005), 0.055, 0.055)
    skv("necktop", (0, neck.y, neck.z + 0.07), 0.05, 0.05)
for side, (sa, sf, sh) in {"l": (larm, lfore, lhand), "r": (rarm, rfore, rhand)}.items():
    sx = 1 if side == "l" else -1
    skv(side + "shin", (sx * 0.11, sa.y, sa.z + 0.02), 0.06 if C else (0.07 if F else 0.085), 0.06 if C else (0.07 if F else 0.085))
    skv(side + "arm", (sa.x, sa.y, sa.z), shoulder_r, shoulder_r)
    skv(side + "elbow", (sf.x, sf.y, sf.z), 0.04 if C else (0.044 if F else 0.05), 0.04 if C else (0.044 if F else 0.05))
    skv(side + "wrist", (sh.x, sh.y, sh.z), 0.033 if C else 0.038, 0.03 if C else 0.034)
    skv(side + "hand", (sh.x + sx * 0.16, sh.y - 0.005, sh.z - 0.005), 0.04 if C else 0.045, 0.018 if C else 0.02)
for side, (su, sl, sf, st) in {"l": (lup, lleg, lfoot, ltoe), "r": (rup, rleg, rfoot, rtoe)}.items():
    sx = 1 if side == "l" else -1
    skv(side + "hip", (sx * 0.095, su.y, su.z), 0.078 if C else (0.098 if F else 0.095), 0.078 if C else (0.098 if F else 0.095))
    skv(side + "knee", (sx * 0.095, sl.y, sl.z), 0.056 if C else 0.066, 0.056 if C else 0.066)
    skv(side + "ankle", (sx * 0.095, sf.y, sf.z + 0.02), 0.045 if C else 0.05, 0.045 if C else 0.05)
    skv(side + "toe", (sx * 0.11, st.y - 0.03, 0.03), 0.052, 0.03)
edges = [("pelvis", "waist"), ("waist", "chest"), ("chest", "upper"), ("upper", "neck"), ("neck", "necktop"),
         ("upper", "lshin"), ("lshin", "larm"), ("larm", "lelbow"), ("lelbow", "lwrist"), ("lwrist", "lhand"),
         ("upper", "rshin"), ("rshin", "rarm"), ("rarm", "relbow"), ("relbow", "rwrist"), ("rwrist", "rhand"),
         ("pelvis", "lhip"), ("lhip", "lknee"), ("lknee", "lankle"), ("lankle", "ltoe"),
         ("pelvis", "rhip"), ("rhip", "rknee"), ("rknee", "rankle"), ("rankle", "rtoe")]
for a, b in edges:
    bm.edges.new((sv[a][0], sv[b][0]))
bm.verts.index_update()
order = [(v.index, rx, ry) for (v, rx, ry) in sv.values()]
root_index = sv["pelvis"][0].index
body = new_obj("Body", bm)
skin = body.modifiers.new("Skin", 'SKIN')
skin.use_smooth_shade = True
skin.branch_smoothing = 0.6
data = body.data.skin_vertices[0].data
for idx, rx, ry in order:
    data[idx].radius = (rx, ry)
data[root_index].use_root = True
sub = body.modifiers.new("Subd", 'SUBSURF')
sub.levels = 2
sub.render_levels = 2
deps = bpy.context.evaluated_depsgraph_get()
ev = body.evaluated_get(deps)
me2 = bpy.data.meshes.new_from_object(ev)
body.modifiers.clear()
old = body.data
body.data = me2
bpy.data.meshes.remove(old)
for p in body.data.polygons:
    p.use_smooth = True
print("Körper: %d Punkte, %d Flächen" % (len(body.data.vertices), len(body.data.polygons)))

BELT_Z = hips.z + 0.01
BOOT_Z = 0.19
SLEEVE_X = lfore.x + 0.02      # bis zum Ellbogen Ärmel, darunter Haut (aufgekrempelt)
def body_mat(c, n):
    if c.z >= neck.z - 0.01 and abs(c.x) < 0.12:
        return 0                                 # Hals
    if abs(c.x) > 0.19 and c.z > spine2.z - 0.08:  # Arme
        if abs(c.x) > lhand.x + 0.01:
            return 0                             # Hand
        if abs(c.x) > SLEEVE_X:
            return 0                             # Unterarm (Haut)
        return 1                                 # Ärmel
    if c.z < BOOT_Z:
        return 3                                 # Stiefel
    if c.z < BELT_Z:
        return 2                                 # Hose
    return 1                                     # Oberteil
set_material(body, [M_SKIN, M_TOP, M_BOTTOM, M_BOOTS], body_mat)
box_uv(body, 5.0)
objs.append(body)

# Gürtel und Kragen
bm = bmesh.new()
add_torus(bm, (0, hips.y, BELT_Z + 0.015), (0.19 if F else 0.175) + 0.005, 0.02, scale=(1, 0.68, 1))
belt = new_obj("Belt", bm)
set_material(belt, [M_TRIM], lambda c, n: 0)
box_uv(belt, 5.0)
weight_all(belt, "Hips")
objs.append(belt)
bm = bmesh.new()
add_torus(bm, (0, neck.y, neck.z + 0.015), 0.07, 0.016, scale=(1, 1, 0.8))
collar = new_obj("Collar", bm)
set_material(collar, [M_TRIM], lambda c, n: 0)
box_uv(collar, 5.0)
weight_all(collar, "Spine2")
objs.append(collar)

# ---------------------------------------------------------------- Kopf mit Gesicht
bm = bmesh.new()
HR = 0.128 if C else 0.105      # Kinder: größerer Kopf
add_sphere(bm, HC, HR, scale=(0.95, 0.98, 1.15))
# Hals-Übergang: kleiner Kegel unter dem Kinn
add_cone(bm, (0, hy + 0.005, HC.z - 0.11), 0.058, 0.075, 0.06)
chin_faces = len(bm.faces)
ex = 0.04 if C else 0.036
EZ = HC.z + (0.005 if C else 0.015)
for sx in (-1, 1):
    add_sphere(bm, (sx * ex, hy - (0.1 if C else 0.083), EZ), 0.026 if C else 0.021, seg=16, rings=10)
eye_faces = len(bm.faces)
for sx in (-1, 1):
    add_sphere(bm, (sx * ex, hy - (0.12 if C else 0.1), EZ), 0.014 if C else 0.011, seg=12, rings=8)
pupil_faces = len(bm.faces)
# Nase, Ohren (Haut)
add_sphere(bm, (0, hy - 0.105, EZ - 0.035), 0.016, scale=(0.9, 1.1, 1.4), seg=12, rings=8)
for sx in (-1, 1):
    add_sphere(bm, (sx * 0.10, hy + 0.005, EZ - 0.02), 0.03, scale=(0.5, 1.0, 1.15), seg=12, rings=8)
skin_faces = len(bm.faces)
# Brauen (Haar), Mund
for sx in (-1, 1):
    add_box(bm, (sx * ex, hy - 0.098, EZ + 0.03), (0.042, 0.012, 0.009), rot=(0, 0, sx * 6))
brow_faces = len(bm.faces)
add_box(bm, (0, hy - 0.103, EZ - 0.068), (0.04, 0.008, 0.008))
head_ob = new_obj("Head", bm)
me = head_ob.data
for m in (M_SKIN, M_EYE, M_PUPIL, M_HAIR, M_MOUTH):
    me.materials.append(m)
for p in me.polygons:
    i = p.index
    if i < chin_faces:
        p.material_index = 0
    elif i < eye_faces:
        p.material_index = 1
    elif i < pupil_faces:
        p.material_index = 2
    elif i < skin_faces:
        p.material_index = 0
    elif i < brow_faces:
        p.material_index = 3
    else:
        p.material_index = 4
weight_all(head_ob, "Head")
objs.append(head_ob)

# Elfenohren (optional)
bm = bmesh.new()
for sx in (-1, 1):
    add_cone(bm, (sx * 0.15, hy + 0.01, EZ + 0.01), 0.028, 0.004, 0.13, seg=10, rot=(0, sx * 95, 0), scale=(1, 0.6, 1))
ears = new_obj("Ears_elf", bm)
set_material(ears, [M_SKIN], lambda c, n: 0)
weight_all(ears, "Head")
objs.append(ears)

# ---------------------------------------------------------------- Frisuren (optional, Haar-Material)
def hair_cap(bm, scale=(1.03, 1.02, 1.1), back_down=0.0, front_up=0.0):
    add_sphere(bm, HC + Vector((0, 0.008, 0.012)), HR + 0.012, scale=scale)
    geom = bm.verts[:] + bm.edges[:] + bm.faces[:]
    # Schnittebene: vorn über den Brauen, hinten tiefer im Nacken
    co = Vector((0, hy, EZ + 0.03 + front_up))
    no = Vector((0, 0.5 + back_down, 1.0)).normalized()
    bmesh.ops.bisect_plane(bm, geom=geom, plane_co=co, plane_no=no, clear_inner=True)

def hair_obj(name, build):
    bm = bmesh.new()
    build(bm)
    ob = new_obj(name, bm)
    set_material(ob, [M_HAIR], lambda c, n: 0)
    weight_all(ob, "Head")
    objs.append(ob)
    return ob

hair_obj("Hair_short", lambda bm: hair_cap(bm))
hair_obj("Hair_slick", lambda bm: hair_cap(bm, scale=(1.0, 1.0, 1.04), back_down=0.2))
def h_long(bm):
    hair_cap(bm, back_down=0.4)
    add_sphere(bm, (0, hy + 0.085, HC.z - 0.17), 1.0, scale=(0.115, 0.055, 0.21))
hair_obj("Hair_long", h_long)
def h_bob(bm):
    hair_cap(bm, scale=(1.12, 1.08, 1.12), back_down=0.6)
    add_torus(bm, (0, hy + 0.01, HC.z - 0.05), 0.105, 0.028, scale=(1.05, 1.0, 1.4))
hair_obj("Hair_bob", h_bob)
def h_bun(bm):
    hair_cap(bm, back_down=0.3)
    add_sphere(bm, (0, hy + 0.11, HC.z + 0.04), 0.055)
hair_obj("Hair_bun", h_bun)
def h_pony(bm):
    hair_cap(bm, back_down=0.3)
    add_sphere(bm, (0, hy + 0.13, HC.z - 0.09), 1.0, scale=(0.04, 0.045, 0.2), rot=(14, 0, 0))
hair_obj("Hair_ponytail", h_pony)
def h_twin(bm):
    hair_cap(bm, back_down=0.3)
    for sx in (-1, 1):
        add_sphere(bm, (sx * 0.135, hy + 0.03, HC.z - 0.12), 1.0, scale=(0.04, 0.04, 0.19), rot=(0, sx * 8, 0))
hair_obj("Hair_twin", h_twin)
def h_beard(bm):
    add_sphere(bm, (0, hy - 0.06, EZ - 0.11), 1.0, scale=(0.072, 0.05, 0.045))
    add_box(bm, (0, hy - 0.09, EZ - 0.09), (0.11, 0.03, 0.02))
hair_obj("Beard", h_beard)

# ---------------------------------------------------------------- Hüte, Helm, Krone, Brille (optional)
def opt_obj(name, build, mats, chooser=None, bone="Head", tiling=5.0):
    bm = bmesh.new()
    build(bm)
    ob = new_obj(name, bm)
    set_material(ob, mats, chooser if chooser else (lambda c, n: 0))
    box_uv(ob, tiling)
    weight_all(ob, bone)
    objs.append(ob)
    return ob

def hat_cap(bm):
    add_cone(bm, (0, hy + 0.01, HC.z + 0.12), 0.118, 0.10, 0.07)
    add_cone(bm, (0, hy - 0.06, HC.z + 0.085), 0.09, 0.09, 0.012, scale=(1.5, 1.4, 1))
opt_obj("Hat_cap", hat_cap, [M_HAT])
def hat_straw(bm):
    add_cone(bm, (0, hy, HC.z + 0.095), 0.27, 0.25, 0.015)
    add_cone(bm, (0, hy, HC.z + 0.145), 0.12, 0.10, 0.09)
opt_obj("Hat_straw", hat_straw, [M_HAT])
def helmet(bm):
    add_sphere(bm, HC + Vector((0, 0.005, 0.03)), HR + 0.022, scale=(1.0, 1.02, 1.08))
    add_cone(bm, (0, hy + 0.005, HC.z - 0.06), 0.128, 0.122, 0.11)
    add_box(bm, (0, hy - 0.125, EZ), (0.21, 0.02, 0.022))
    add_box(bm, (0, hy + 0.01, HC.z + 0.17), (0.03, 0.2, 0.09))
def helmet_mat(c, n):
    if abs(c.z - EZ) < 0.015 and c.y < hy - 0.1:
        return 1
    if c.z > HC.z + 0.13 and abs(c.x) < 0.02:
        return 2
    return 0
opt_obj("Helmet", helmet, [M_METAL, M_PUPIL, M_CAPE], helmet_mat)
def hood(bm):
    # Kapuze: liegt eng am Kopf (Gesicht frei) und fällt als Kragen über die Schultern
    add_sphere(bm, HC + Vector((0, 0.012, 0.02)), HR + 0.03, scale=(1.08, 1.1, 1.12))
    geom = bm.verts[:] + bm.edges[:] + bm.faces[:]
    bmesh.ops.bisect_plane(bm, geom=geom, plane_co=Vector((0, hy - 0.07, EZ + 0.01)), plane_no=Vector((0, 0.55, 1.0)).normalized(), clear_inner=True)
    add_cone(bm, (0, neck.y + 0.01, neck.z + 0.0), 0.27, 0.085, 0.2, seg=22)
bm = bmesh.new()
hood(bm)
hood_ob = new_obj("Hood", bm)
set_material(hood_ob, [M_HOOD], lambda c, n: 0)
box_uv(hood_ob, 5.0)
weight_by(hood_ob, lambda co: {"Head": 1.0} if co.z > neck.z + 0.07 else {"Spine2": 1.0})
objs.append(hood_ob)
def crown(bm):
    add_torus(bm, (0, hy, HC.z + 0.11), 0.105, 0.018, scale=(1, 1, 1.6))
    for i in range(6):
        a = 2 * math.pi * i / 6
        add_cone(bm, (0.105 * math.cos(a), hy + 0.105 * math.sin(a), HC.z + 0.16), 0.014, 0.002, 0.06, seg=8)
opt_obj("Crown", crown, [M_GOLD])
def glasses(bm):
    for sx in (-1, 1):
        add_torus(bm, (sx * ex, hy - 0.105, EZ), 0.028, 0.004, seg=16, rings=6, rot=(90, 0, 0))
    add_box(bm, (0, hy - 0.105, EZ), (0.02, 0.004, 0.004))
    for sx in (-1, 1):
        add_box(bm, (sx * 0.08, hy - 0.05, EZ), (0.004, 0.11, 0.004))
opt_obj("Glasses", glasses, [M_GOLD])

# ---------------------------------------------------------------- Rüstung, Schürze, Wappenrock, Umhang (optional)
WAIST_RX, WAIST_RY = (0.135, 0.10) if F else (0.16, 0.115)
CHEST_RX, CHEST_RY = (0.165, 0.125) if F else (0.185, 0.13)
HIP_RX, HIP_RY = (0.19, 0.125) if F else (0.175, 0.115)
def armor(bm):
    # Brustpanzer: geschlossene Schale um den Rumpf von der Taille bis unter die Schultern, oben leicht eingezogen
    add_arc(bm, CHEST_RX + 0.022, CHEST_RY + 0.028, spine.z - 0.01, spine2.z + 0.035, -180, 180, spine1.y, segs=28, rings=6, flare=-0.08, thick=0.015)
bm = bmesh.new()
armor(bm)
arm_ob = new_obj("Armor_chest", bm)
set_material(arm_ob, [M_METAL], lambda c, n: 0)
box_uv(arm_ob, 5.0)
weight_by(arm_ob, torso_weight)
objs.append(arm_ob)
bm = bmesh.new()
for sx in (1, -1):
    add_sphere(bm, (sx * (larm.x + 0.01), larm.y, larm.z + 0.03), 1.0, scale=(0.095, 0.085, 0.07))
paul = new_obj("Pauldrons", bm)
set_material(paul, [M_METAL], lambda c, n: 0)
box_uv(paul, 5.0)
weight_by(paul, lambda co: {("LeftArm" if co.x > 0 else "RightArm"): 0.65, "Spine2": 0.35})
objs.append(paul)

def apron(bm):
    # Schürze: gewölbte Bahn vorn vom Gürtel bis zum Knie, Latz bis zur Brust
    add_arc(bm, HIP_RX + 0.02, HIP_RY + 0.02, 0.64, hips.z + 0.02, -58, 58, hips.y, segs=12, rings=5, flare=0.06)
    add_arc(bm, WAIST_RX + 0.02, WAIST_RY + 0.02, hips.z + 0.02, spine1.z + 0.12, -32, 32, sy, segs=8, rings=3)
ap = opt_obj("Apron", apron, [M_APRON], bone="Hips")
weight_by(ap, torso_weight)
def tabard(bm):
    # Wappenrock: Bahn vorn und hinten von der Schulter bis über das Knie
    add_arc(bm, CHEST_RX + 0.03, CHEST_RY + 0.03, 0.74, spine2.z + 0.02, -42, 42, spine1.y, segs=10, rings=6, flare=0.05)
    add_arc(bm, CHEST_RX + 0.03, CHEST_RY + 0.03, 0.74, spine2.z + 0.02, 138, 222, spine1.y, segs=10, rings=6, flare=0.05)
tb = opt_obj("Tabard", tabard, [M_TABARD], bone="Hips")
weight_by(tb, torso_weight)
def cape(bm):
    # Umhang: weite Bahn um den Rücken, nach unten ausgestellt
    add_arc(bm, CHEST_RX + 0.045, CHEST_RY + 0.045, 0.5, spine2.z + 0.06, 100, 260, spine1.y, segs=16, rings=8, flare=0.3)
cp = opt_obj("Cape", cape, [M_CAPE], bone="Hips")
weight_by(cp, torso_weight)

# ---------------------------------------------------------------- Rock (Kleid/Robe) – optional
bm = bmesh.new()
RT, RB = (0.19 if F else 0.18), 0.40
ZT, ZB = hips.z + 0.0, 0.10
rings_v = []
NR, NS = 7, 28
for j in range(NR):
    t = j / (NR - 1)
    r = RT + (RB - RT) * (t ** 1.3)
    z = ZT + (ZB - ZT) * t
    ring = [bm.verts.new((r * math.cos(2 * math.pi * i / NS), hips.y + r * 0.72 * math.sin(2 * math.pi * i / NS), z)) for i in range(NS)]
    rings_v.append(ring)
for j in range(NR - 1):
    for i in range(NS):
        bm.faces.new((rings_v[j][i], rings_v[j][(i + 1) % NS], rings_v[j + 1][(i + 1) % NS], rings_v[j + 1][i]))
skirt = new_obj("Skirt", bm)
set_material(skirt, [M_SKIRT], lambda c, n: 0)
box_uv(skirt, 5.0)
def skirt_w(co):
    t = max(0.0, min(1.0, (ZT - co.z) / (ZT - ZB)))
    leg = "LeftUpLeg" if co.x > 0 else "RightUpLeg"
    side = min(1.0, abs(co.x) / 0.12)
    return {"Hips": 1.0 - 0.8 * t * side + 1e-4, leg: 0.8 * t * side + 1e-4}
weight_by(skirt, skirt_w)
objs.append(skirt)

# ---------------------------------------------------------------- Gewichte des Körpers (Bone Heat) und Anbindung
arm.data.pose_position = 'REST'
bpy.ops.object.select_all(action='DESELECT')
body.select_set(True)
arm.select_set(True)
bpy.context.view_layer.objects.active = arm
bpy.ops.object.parent_set(type='ARMATURE_AUTO')
arm.data.pose_position = 'POSE'
missing = 0
for v in body.data.vertices:
    if sum(g.weight for g in v.groups) < 0.05:
        missing += 1
print("Körper ohne Gewicht: %d Punkte (Gruppen: %d)" % (missing, len(body.vertex_groups)))
if missing > 0 or len(body.vertex_groups) == 0:
    # Rückfall: nächstes Knochensegment (Hauptknochen) mit weichem Übergang
    print("Rückfall auf Segment-Gewichte")
    segs = []
    for b in arm.data.bones:
        if b.use_deform and b.name.startswith("mixamorig:"):
            segs.append((b.name, MW @ b.head_local, MW @ b.tail_local))
    def seg_dist(p, a, b):
        ab = b - a
        t = max(0.0, min(1.0, (p - a).dot(ab) / max(ab.length_squared, 1e-9)))
        return (p - (a + ab * t)).length
    body.vertex_groups.clear()
    groups = {}
    for i, v in enumerate(body.data.vertices):
        p = body.matrix_world @ v.co
        ds = sorted(((seg_dist(p, a, b), n) for n, a, b in segs))[:2]
        w0 = 1.0
        w1 = 0.0
        if ds[1][0] < ds[0][0] * 1.6:
            w1 = 0.5 * (1.0 - (ds[1][0] - ds[0][0]) / (ds[0][0] * 0.6 + 1e-6))
            w1 = max(0.0, min(0.5, w1))
            w0 = 1.0 - w1
        for (d, n), w in ((ds[0], w0), (ds[1], w1)):
            if w <= 0:
                continue
            if n not in groups:
                groups[n] = body.vertex_groups.new(name=n)
            groups[n].add([i], w, 'REPLACE')
    if not any(md.type == 'ARMATURE' for md in body.modifiers):
        attach(body)
for ob in objs:
    if ob is body:
        continue
    attach(ob)

# ---------------------------------------------------------------- Export
bpy.ops.object.select_all(action='DESELECT')
arm.select_set(True)
for ob in objs:
    ob.select_set(True)
bpy.context.view_layer.objects.active = arm
bpy.ops.export_scene.gltf(filepath=OUT, export_format='GLB', use_selection=True, export_apply=True,
    export_animations=True, export_animation_mode='ACTIONS', export_nla_strips=True, export_anim_slide_to_zero=True,
    export_skins=True, export_yup=True, export_materials='EXPORT', export_image_format='AUTO', export_texcoords=True,
    export_normals=True, export_def_bones=False)
print("GLB geschrieben:", OUT, os.path.getsize(OUT))

# ---------------------------------------------------------------- Vorschau-Renders
if RENDER_DIR:
    os.makedirs(RENDER_DIR, exist_ok=True)
    scene.render.engine = 'BLENDER_WORKBENCH'
    scene.display.shading.light = 'STUDIO'
    scene.display.shading.color_type = 'MATERIAL'
    scene.display.shading.show_shadows = True
    scene.render.resolution_x = 420
    scene.render.resolution_y = 640
    scene.world = bpy.data.worlds.new("W")
    scene.world.color = (0.25, 0.25, 0.28)
    cam_data = bpy.data.cameras.new("C")
    cam = bpy.data.objects.new("C", cam_data)
    scene.collection.objects.link(cam)
    cam_data.lens = 50
    scene.camera = cam
    hidden_default = ["Ears_elf", "Hair_slick", "Hair_long", "Hair_bob", "Hair_bun", "Hair_ponytail", "Hair_twin", "Beard",
                      "Hat_cap", "Hat_straw", "Helmet", "Crown", "Glasses", "Armor_chest", "Pauldrons", "Apron", "Tabard", "Cape", "Skirt", "Hood"]
    def show(names):
        for ob in objs:
            ob.hide_render = ob.name in hidden_default and ob.name not in names
            if ob.name == "Hair_short":
                ob.hide_render = any(n.startswith("Hair_") and n != "Hair_short" for n in names) or "Helmet" in names
    def shot(tag, action=None, frame=0, yaw=0.0):
        a = math.radians(yaw)
        cam.location = (math.sin(a) * 4.2, -math.cos(a) * 4.2, 1.15)
        cam.rotation_euler = (math.radians(86), 0, a)
        ad.action = bpy.data.actions.get(action) if action else None
        for tr in ad.nla_tracks:
            tr.mute = True
        scene.frame_set(frame)
        scene.render.filepath = os.path.join(RENDER_DIR, "v%s_%s.png" % (VARIANT, tag))
        bpy.ops.render.render(write_still=True)
    show([])
    shot("tpose_front")
    shot("tpose_side", yaw=90)
    show(["Skirt", "Hair_long"] if F else ["Hair_short"])
    shot("idle", "idle", 40)
    shot("walk", "walk", 10, yaw=35)
    show(["Armor_chest", "Pauldrons", "Helmet", "Cape", "Tabard"])
    shot("knight", "idle", 90, yaw=25)
    show(["Apron", "Hat_straw", "Beard", "Hair_bob"])
    shot("farmer", "walk", 20, yaw=-30)
    show(["Hat_cap", "Glasses", "Hair_bun", "Crown"])
    shot("misc", "idle", 10, yaw=-20)
    show(["Hair_ponytail", "Ears_elf", "Skirt"])
    shot("elf", "idle", 70, yaw=20)
    show(["Hood", "Skirt"])
    shot("cultist", "idle", 20, yaw=10)
    show(["Hair_short"] if not F else ["Hair_long", "Skirt"])
    for cname, fr in [("talk", 40), ("argue", 60), ("cheer", 30), ("pray", 60), ("sit", 30), ("drink", 50), ("wave", 30)]:
        if bpy.data.actions.get(cname):
            shot("clip_" + cname, cname, fr, yaw=15)
print("DONE")
