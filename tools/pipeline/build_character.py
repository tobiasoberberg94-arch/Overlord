# Blender: Mixamo-Albedo (idle mit Skin + Animationen ohne Skin) -> albedo.glb
#   blender -b -P build_albedo2.py -- <mixamo-ordner> <texturordner> <ziel.glb>
# Eine Armatur, jede Animation als eigene Action/NLA-Spur (Name = Spiel-Animation).
# Texturen werden nach Materialname (badan = Koerper, mata = Augen) neu verknuepft,
# falls Mixamo sie nicht mitliefert.
import glob
import os
import sys

import bpy
from mathutils import Vector

mix, texdir, dst = [os.path.abspath(a) for a in sys.argv[sys.argv.index("--") + 1:][:3]]
bpy.ops.wm.read_factory_settings(use_empty=True)


def imported(fn):
    before = set(bpy.data.objects)
    fn()
    return [o for o in bpy.data.objects if o not in before]


objs = imported(lambda: bpy.ops.import_scene.fbx(filepath=os.path.join(mix, "idle.fbx"), automatic_bone_orientation=False))
arm = next(o for o in objs if o.type == "ARMATURE")
arm.name = "Albedo"
meshes = [o for o in objs if o.type == "MESH"]
arm.animation_data.action.name = "idle"
actions = {"idle": arm.animation_data.action}

for path in sorted(glob.glob(os.path.join(mix, "*.fbx"))):
    name = os.path.splitext(os.path.basename(path))[0]
    if name == "idle":
        continue
    new = imported(lambda: bpy.ops.import_scene.fbx(filepath=path, automatic_bone_orientation=False))
    a = next(o for o in new if o.type == "ARMATURE")
    a.animation_data.action.name = name
    actions[name] = a.animation_data.action
    for o in new:
        bpy.data.objects.remove(o)

# Einheiten pruefen: Mixamo liest OBJ-Uploads als Zentimeter -> Figur ist 100x zu klein.
# Die Armatur (samt Animationen und Skin) wird dann als Ganzes hochskaliert.
_dg = bpy.context.evaluated_depsgraph_get()
_zs = [(o.evaluated_get(_dg).matrix_world @ v.co).z for o in meshes for v in o.evaluated_get(_dg).to_mesh().vertices]
_h = max(_zs) - min(_zs)
if _h < 0.2:
    arm.scale = arm.scale * 100.0
    bpy.context.view_layer.update()
    print("OVERLORD einheiten korrigiert: Hoehe", round(_h, 4), "-> x100")
arm.animation_data.action = None
for pb in arm.pose.bones:   # Ruhepose (der Import laesst den ersten Frame stehen)
    pb.location = (0, 0, 0)
    pb.rotation_quaternion = (1, 0, 0, 0)
    pb.rotation_euler = (0, 0, 0)
    pb.scale = (1, 1, 1)
for name, act in actions.items():
    act.use_fake_user = True
    tr = arm.animation_data.nla_tracks.new()
    tr.name = name
    tr.strips.new(name, int(act.frame_range[0]), act)
    tr.mute = True
print("OVERLORD animationen", sorted(actions))

# Stoff-Gewichte reparieren (optional, 4. Argument z. B. "cloth=skirt" oder "cloth=robe"):
# Mixamo bindet Rock/Mantel/Schulterplatten an Arm- und Beinknochen – der Stoff reißt dann zwischen den Beinen
# auf oder wird von den Armen mitgezogen. Liegt ein Punkt weit vom Gliedmaßenknochen entfernt, ist er Stoff:
# sein Gewicht wandert (weich, nach Entfernung) zum nächsten Rumpfknochen. Beine behalten einen Rest,
# damit der Rock beim Gehen etwas mitschwingt; Arme geben Stoffpunkte ganz ab (Mantel, Schulterplatten).
_opts = dict(a.split("=", 1) for a in sys.argv[sys.argv.index("--") + 4:] if "=" in a)
CLOTH = _opts.get("cloth", "")
if CLOTH:
    import numpy as np
    bpy.context.view_layer.update()
    mw = arm.matrix_world
    def joint_segments(a, m):
        """Knochen als Segment Gelenk → nächstes Gelenk (Mittel der Kind-Köpfe). Die Bone-Tails aus dem FBX-Import
        zeigen ohne automatische Ausrichtung beliebig (z. B. von der Hand bis zur Hüfte)."""
        out = {}
        for b in a.data.bones:
            h = m @ b.head_local
            if b.children:
                t = sum((m @ c.head_local for c in b.children), Vector()) / len(b.children)
            elif b.parent:
                d = h - (m @ b.parent.head_local)
                t = h + d * 0.5
            else:
                t = h
            out[b.name.split(":")[-1]] = (h, t, b.name)
        return out
    bones = joint_segments(arm, mw)
    # Optional base=<tpose.fbx> (Mixamo-Download ohne Animation, Pose „T-pose“): Regeln auf T-Pose-Positionen
    # rechnen – in der Mixamo-Ruhepose hängen die Arme und Haare/Stoff berühren die Hände.
    POS = {}
    if _opts.get("base"):
        tobj = imported(lambda: bpy.ops.import_scene.fbx(filepath=os.path.abspath(_opts["base"]), automatic_bone_orientation=False))
        tarm = next(o for o in tobj if o.type == "ARMATURE")
        tmeshes = [o for o in tobj if o.type == "MESH"]
        tarm.animation_data_clear() if tarm.animation_data else None
        if (max(z for z in [(o.matrix_world @ v.co).z for o in tmeshes for v in o.data.vertices]) -
                min(z for z in [(o.matrix_world @ v.co).z for o in tmeshes for v in o.data.vertices])) < 0.2:
            tarm.scale = tarm.scale * 100.0
        bpy.context.view_layer.update()
        tb = joint_segments(tarm, tarm.matrix_world)
        for k in bones:
            if k in tb:
                bones[k] = (tb[k][0], tb[k][1], bones[k][2])
        for o, t in zip(sorted(meshes, key=lambda m: len(m.data.vertices)), sorted(tmeshes, key=lambda m: len(m.data.vertices))):
            if len(o.data.vertices) == len(t.data.vertices):
                POS[o.name] = [t.matrix_world @ v.co for v in t.data.vertices]
                print("OVERLORD stoff: T-Pose-Positionen für", o.name)
            else:
                print("OVERLORD stoff: T-Pose passt nicht", len(o.data.vertices), len(t.data.vertices))
        for x in tobj:
            bpy.data.objects.remove(x)
    zs = [v[0].z for v in bones.values()] + [v[1].z for v in bones.values()]
    unit = (max(zs) - min(zs)) / 1.75                     # Körpergröße relativ zu 1,75 m
    # skirt = weiter Rock/Reifrock (Beine darunter unsichtbar), robe = Robe/Mantel bis zum Boden (Ainz), cape = Umhang
    keep_leg = {"skirt": 0.08, "robe": 0.3, "cape": 0.6}.get(CLOTH, 0.25)
    leg_r = {"skirt": (-1.0, -0.5), "robe": (0.09, 0.2)}.get(CLOTH, (0.11, 0.22))   # Reifrock: Beine/Füße unsichtbar → alles Stoff
    hand_bones = [n for n in bones if n.startswith(("LeftHand", "RightHand"))]
    LIMBS = {"arm": ["LeftArm", "LeftForeArm", "RightArm", "RightForeArm"] + hand_bones,
             "leg": ["LeftUpLeg", "LeftLeg", "RightUpLeg", "RightLeg"] + [n for n in bones if n.startswith(("LeftFoot", "RightFoot", "LeftToe", "RightToe"))]}
    R = {"arm": (0.07 * unit, 0.15 * unit), "leg": (leg_r[0] * unit, leg_r[1] * unit)}
    TORSO = [n for n in ("Hips", "Spine", "Spine1", "Spine2", "LeftShoulder", "RightShoulder", "Neck") if n in bones]
    cx = bones["Hips"][0].x if "Hips" in bones else 0.0

    def seg_dist(p, a_, b_):
        ab = b_ - a_
        t = max(0.0, min(1.0, (p - a_).dot(ab) / max(ab.length_squared, 1e-9)))
        return (p - (a_ + ab * t)).length

    def smooth(e0, e1, x):
        t = max(0.0, min(1.0, (x - e0) / (e1 - e0)))
        return t * t * (3 - 2 * t)

    def reweight(o, vg):
        moved = 0
        for v in o.data.vertices:
            p = POS[o.name][v.index] if o.name in POS else o.matrix_world @ v.co
            ws = {o.vertex_groups[g.group].name.split(":")[-1]: g.weight for g in v.groups}
            give = 0.0
            hair = 0.0
            for kind, names in LIMBS.items():
                for n in names:
                    w = ws.get(n, 0.0)
                    if w <= 0.001 or n not in bones:
                        continue
                    f = smooth(*R[kind], seg_dist(p, bones[n][0], bones[n][1]))
                    if kind == "arm":
                        wrist_ = bones["LeftHand" if n.startswith("Left") else "RightHand"][0]
                        lateral = abs(p.x - cx) > abs(wrist_.x - cx) - 0.05 * unit
                        if (p - wrist_).length < 0.15 * unit or (lateral and (p - wrist_).length < 0.4 * unit):
                            # echte Hand: Arm bleibt Arm; Fingergewichte → Handknochen (Fingergelenke unzuverlässig)
                            if n.startswith(("LeftHand", "RightHand")) and n not in ("LeftHand", "RightHand"):
                                hb = "LeftHand" if n.startswith("Left") else "RightHand"
                                vg[n].add([v.index], 0.0, "REPLACE")
                                ws[hb] = ws.get(hb, 0.0) + w
                                vg[hb].add([v.index], ws[hb], "REPLACE")
                            continue
                    if n.startswith(("LeftHand", "RightHand")):
                        # Hand/Finger: nur nahe am Handgelenk gültig (Mixamo setzt Fingergelenke bei Kleidern/Haaren
                        # manchmal falsch, z. B. an die Hüfte) – sonst als Stoff behandeln
                        wrist = bones["LeftHand" if n.startswith("Left") else "RightHand"][0]
                        f = smooth(0.16 * unit, 0.22 * unit, (p - wrist).length)
                        if f > 0.0 and p.z > (bones["Hips"][0].z - 0.15 * unit if "Hips" in bones else 0.0):
                            # weit weg von der Hand, auf Rumpfhöhe: herabhängendes Haar → an Kopf/Hals wie die Locke
                            vg[n].add([v.index], w * (1.0 - f), "REPLACE")
                            hair += w * f
                            continue
                    # Arme stehen in der T-Pose waagerecht: deutlich darunter hängende Punkte (Haar, Kragen)
                    # oder Punkte weiter innen als das Schultergelenk gehören nicht zum Arm
                    sh = bones.get("LeftArm" if n.startswith("Left") else "RightArm", bones[n])[0]
                    if kind == "arm" and (abs(p.x - cx) < abs(sh.x - cx) - 0.02 * unit or
                                        (p.z < sh.z - 0.07 * unit and seg_dist(p, bones[n][0], bones[n][1]) > 0.07 * unit
                                         and abs(p.x - cx) < abs(sh.x - cx) + 0.1 * unit)):   # nur körpernah (Ärmel bleiben)
                        # weiter innen als das Schultergelenk: kein Arm, sondern Haar/Kragen → an Kopf/Hals
                        vg[n].add([v.index], 0.0, "REPLACE")
                        hair += w
                        continue
                    if kind == "arm":
                        # Abstandsregel bei Armen nur körpernah (Umhang, Kragen); weite Ärmel bleiben am Arm
                        f *= 1.0 - smooth(abs(sh.x - cx) + 0.05 * unit, abs(sh.x - cx) + 0.2 * unit, abs(p.x - cx))
                    if f <= 0.0:
                        continue
                    keep = keep_leg if kind == "leg" else 0.0
                    d = w * f * (1.0 - keep)
                    vg[n].add([v.index], w - d, "REPLACE")
                    give += d
            if hair > 0.0:
                for n, share in (("Head", 0.6), ("Neck", 0.4)):
                    if n in vg:
                        vg[n].add([v.index], ws.get(n, 0.0) + hair * share, "REPLACE")
                moved += 1
            if give <= 0.0:
                continue
            # auf die zwei nächsten Rumpfknochen verteilen
            near = sorted((seg_dist(p, bones[n][0], bones[n][1]), n) for n in TORSO)[:2]
            inv = [1.0 / max(d_, 1e-3) for d_, _ in near]
            for (d_, n), iw in zip(near, inv):
                vg[n].add([v.index], ws.get(n, 0.0) + give * iw / sum(inv), "REPLACE")
            moved += 1
        return moved

    for o in meshes:
        vg = {g.name.split(":")[-1]: g for g in o.vertex_groups}
        for n in TORSO + [b for b in ("Head",) if b in bones]:
            if n not in vg:
                vg[n] = o.vertex_groups.new(name=bones[n][2])
        def probe(tag):
            if not os.environ.get("CLOTH_DEBUG"):
                return
            for v in o.data.vertices:
                p_ = POS[o.name][v.index] if o.name in POS else o.matrix_world @ v.co
                if (p_ - Vector((0.28, 0.0, 0.82))).length < 0.012:
                    gs = sorted(((o.vertex_groups[g.group].name.split(":")[-1], round(g.weight, 2)) for g in v.groups), key=lambda x: -x[1])[:4]
                    lh = bones["LeftHand"]
                    print("OVERLORD probe", tag, v.index, [round(c, 3) for c in p_], gs, "hand-seg", [round(c, 2) for c in lh[0]], [round(c, 2) for c in lh[1]],
                          "dist", round(seg_dist(p_, lh[0], lh[1]), 3))
        probe("vorher")
        moved = reweight(o, vg)
        probe("pass1")
        # Übergänge glätten; danach erneut umgewichten (das Glätten trägt sonst Fuß-/Armgewicht zurück in den Stoff)
        bpy.context.view_layer.objects.active = o
        o.select_set(True)
        bpy.ops.object.mode_set(mode="WEIGHT_PAINT")
        bpy.ops.object.vertex_group_smooth(group_select_mode="ALL", factor=0.5, repeat=10 if CLOTH == "robe" else 4)
        bpy.ops.object.mode_set(mode="OBJECT")
        probe("geglaettet")
        moved += reweight(o, vg)
        probe("pass2")
        bpy.ops.object.mode_set(mode="WEIGHT_PAINT")
        bpy.ops.object.vertex_group_normalize_all(lock_active=False)
        bpy.ops.object.mode_set(mode="OBJECT")
        print("OVERLORD stoff", CLOTH, o.name, "punkte umgewichtet", moved)

# Materialien: beleuchtetes PBR. Zwei Faelle:
# - PBR-Satz im Texturordner (*_basecolor/_normal/_roughness/_metallic, von prep_mixamo_pbr.py)
# - sonst: badan/mata (Albedo-Paket) bzw. die eingebettete Textur, Alpha-Clip fuer Haare/Augen
pbr = {k: next((os.path.join(texdir, f) for f in os.listdir(texdir) if f.lower().split(".")[0].endswith("_" + k)), None)
       for k in ("basecolor", "normal", "roughness", "metallic")}
for o in meshes:
    for slot in o.material_slots:
        m = slot.material
        if not m:
            continue
        nt = m.node_tree
        bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
        if pbr["basecolor"]:
            for n in [n for n in nt.nodes if n.type in ("TEX_IMAGE", "NORMAL_MAP")]:
                nt.nodes.remove(n)
            for key, socket in (("basecolor", "Base Color"), ("roughness", "Roughness"), ("metallic", "Metallic"), ("normal", None)):
                if not pbr[key]:
                    continue
                t = nt.nodes.new("ShaderNodeTexImage")
                t.image = bpy.data.images.load(pbr[key])
                if key != "basecolor":
                    t.image.colorspace_settings.name = "Non-Color"
                if socket:
                    nt.links.new(t.outputs["Color"], bsdf.inputs[socket])
                else:
                    nmap = nt.nodes.new("ShaderNodeNormalMap")
                    nt.links.new(t.outputs["Color"], nmap.inputs["Color"])
                    nt.links.new(nmap.outputs["Normal"], bsdf.inputs["Normal"])
            for l in list(bsdf.inputs["Alpha"].links):
                nt.links.remove(l)
            bsdf.inputs["Alpha"].default_value = 1.0
            print("OVERLORD material", m.name, "-> PBR")
            continue
        key = "mata" if "mata" in m.name.lower() or "2" in m.name else "badan"
        tex = next((n for n in nt.nodes if n.type == "TEX_IMAGE" and n.image and n.image.has_data), None)
        if tex is None:
            tex = nt.nodes.new("ShaderNodeTexImage")
            tex.image = bpy.data.images.load(os.path.join(texdir, key + ".png"))
        for l in list(bsdf.inputs["Base Color"].links):
            nt.links.remove(l)
        nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
        for l in list(bsdf.inputs["Alpha"].links):
            nt.links.remove(l)
        r = nt.nodes.new("ShaderNodeMath")
        r.operation = "ROUND"   # glTF: alphaMode MASK (Cutoff 0.5)
        nt.links.new(tex.outputs["Alpha"], r.inputs[0])
        nt.links.new(r.outputs[0], bsdf.inputs["Alpha"])
        bsdf.inputs["Roughness"].default_value = 0.7
        bsdf.inputs["Metallic"].default_value = 0.0
        print("OVERLORD material", m.name, "->", tex.image.name)

bpy.ops.export_scene.gltf(filepath=dst, export_format="GLB", export_yup=True, export_apply=False,
                          export_animations=True, export_animation_mode="NLA_TRACKS",
                          export_skins=True, export_def_bones=False, export_extras=False)
print("OVERLORD glb", dst, os.path.getsize(dst) // 1024, "KB")
