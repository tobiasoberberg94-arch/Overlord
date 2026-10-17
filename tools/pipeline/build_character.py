# Blender: Mixamo-Albedo (idle mit Skin + Animationen ohne Skin) -> albedo.glb
#   blender -b -P build_albedo2.py -- <mixamo-ordner> <texturordner> <ziel.glb>
# Eine Armatur, jede Animation als eigene Action/NLA-Spur (Name = Spiel-Animation).
# Texturen werden nach Materialname (badan = Koerper, mata = Augen) neu verknuepft,
# falls Mixamo sie nicht mitliefert.
import glob
import math
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

# Anbauteile, die für Mixamo abgetrennt wurden, wieder ansetzen (5. Argument ff.):
#   attach=<datei.fbx>:transfer   – Gewichte vom nächsten Körperpunkt übernehmen (Umhang)
#   attach=<datei.fbx>:hands      – starr an die Hände (x<0 → RightHand, x>0 → LeftHand; Schwert/Schild)
#   attach=<datei.fbx>:<Knochen>  – starr an einen Knochen
# Die Dateien liegen im Koordinatensystem der Mixamo-Vorbereitung (Meter, Füße auf 0).
_opts0 = dict(a.split("=", 1) for a in sys.argv[sys.argv.index("--") + 4:] if "=" in a and not a.startswith("attach="))
_attach = [a.split("=", 1)[1] for a in sys.argv[sys.argv.index("--") + 4:] if a.startswith("attach=")]
if _attach:
    bpy.context.view_layer.update()
    body = max(meshes, key=lambda m: len(m.data.vertices))
    bnames = {b.name.split(":")[-1]: b.name for b in arm.data.bones}
    # Bezug: das für Mixamo hochgeladene Mesh (ref=<datei.fbx>). Mixamo gibt den Körper gedreht/skaliert zurück –
    # die Ähnlichkeitstransformation Hochlade-Mesh → gerigter Körper (Umeyama über gleiche Punkte) setzt die Anbauteile
    # an die richtige Stelle.
    M = None
    if _opts0.get("ref"):
        import numpy as np
        from mathutils import Matrix
        rnew = imported(lambda: bpy.ops.import_scene.fbx(filepath=os.path.abspath(_opts0["ref"])))
        ref = max((x for x in rnew if x.type == "MESH"), key=lambda m: len(m.data.vertices))
        A = np.array([(ref.matrix_world @ v.co)[:] for v in ref.data.vertices])
        dg = bpy.context.evaluated_depsgraph_get()
        arm_pose = arm.data.pose_position
        arm.data.pose_position = "REST"
        bpy.context.view_layer.update()
        ev = body.evaluated_get(bpy.context.evaluated_depsgraph_get()).to_mesh()
        B = np.array([(body.matrix_world @ v.co)[:] for v in ev.vertices])
        arm.data.pose_position = arm_pose
        print("OVERLORD bezug punkte", len(A), len(B))
        if len(A) == len(B):
            ma, mb = A.mean(0), B.mean(0)
            Ac, Bc = A - ma, B - mb
            U, S, Vt = np.linalg.svd(Bc.T @ Ac / len(A))
            D = np.eye(3)
            if np.linalg.det(U) * np.linalg.det(Vt) < 0:
                D[2, 2] = -1
            Rm = U @ D @ Vt
            sc = np.trace(np.diag(S) @ D) / (Ac ** 2).sum(1).mean()
            t = mb - sc * Rm @ ma
            M = Matrix.Identity(4)
            for i in range(3):
                for j in range(3):
                    M[i][j] = sc * Rm[i, j]
                M[i][3] = t[i]
            err = np.abs((sc * (Rm @ A.T)).T + t - B).max()
            print("OVERLORD bezug skala", round(float(sc), 4), "fehler", round(float(err), 4))
        for x in rnew:
            bpy.data.objects.remove(x)
    def joint(n):
        b = arm.data.bones.get(bnames.get(n, ""))
        return (arm.matrix_world @ b.head_local) if b else None

    def regrip(o):
        """Waffe neu in die Hand legen: Schwert (x<0, rechte Hand) mit der Klinge zur Daumenseite der Faust,
        Schild (x>0, linke Hand) flach auf Handrücken/Unterarm, Vorderseite nach außen."""
        import numpy as np
        from mathutils import Matrix
        W = o.matrix_world
        P = np.array([(W @ v.co)[:] for v in o.data.vertices])
        side = "R" if P[:, 0].mean() < 0 else "L"
        o["side"] = side
        S = "Right" if side == "R" else "Left"
        wrist, mid, idx, pnk, fore = (joint(S + n) for n in ("Hand", "HandMiddle1", "HandIndex1", "HandPinky1", "ForeArm"))
        if wrist is None or fore is None or (mid is None and idx is None):
            print("OVERLORD griff: Handgelenke fehlen", S)
            return
        if mid is None:
            mid = idx
        fy = (mid - wrist).normalized()                     # Richtung Finger
        if idx is not None and pnk is not None:
            knuck = (idx - pnk).normalized()                # Knöchellinie, zum Daumen hin
        else:
            # Rig ohne kleinen Finger: in der Ruhepose hängen die Arme, Daumen zeigen nach vorn (-Y)
            fwd = Vector((0, -1, 0))
            knuck = (fwd - fy * fwd.dot(fy)).normalized()
        dors = fy.cross(knuck).normalized()                 # Handrücken/-fläche
        if (dors.x > 0) != (side == "L"):                   # nach außen (vom Körper weg)
            dors = -dors
        knuck = dors.cross(fy).normalized() * (1 if knuck.dot(dors.cross(fy)) > 0 else -1)
        c = P.mean(0)
        ev, evec = np.linalg.eigh(np.cov((P - c).T))
        e = [Vector(evec[:, i]) for i in (2, 1, 0)]          # lang, mittel, dünn
        palm = wrist + (mid - wrist) * 0.45
        if side == "R":                                     # Schwert
            proj = (P - c) @ np.array(e[0])
            # Griffende = Ende, das in Ruhe näher am Handgelenk liegt
            near_end = c + np.array(e[0]) * (proj.min() if np.linalg.norm(c + np.array(e[0]) * proj.min() - np.array(wrist)) <
                                              np.linalg.norm(c + np.array(e[0]) * proj.max() - np.array(wrist)) else proj.max())
            if (Vector(c) - Vector(near_end)).dot(e[0]) < 0:
                e[0] = -e[0]
            grip = Vector(near_end) + e[0] * 0.12
            src = Matrix((e[0], e[1], e[0].cross(e[1]))).transposed()
            dst = Matrix((knuck, fy, knuck.cross(fy))).transposed()
            Rm = dst @ src.inverted()
            roll = float(_opts0.get("roll_" + side, "0"))
            if roll:
                Rm = Matrix.Rotation(math.radians(roll), 3, fy) @ Rm
            T = Matrix.Translation(palm) @ Rm.to_4x4() @ Matrix.Translation(-grip)
        else:                                               # Schild
            front = e[2] if e[2].dot(Vector((0, -1, 0))) > 0 else -e[2]   # Vorderseite zeigt in Ruhe nach vorn (-Y)
            e0 = e[0]
            src = Matrix((e0, front.cross(e0), front)).transposed()
            dst = Matrix((knuck, dors.cross(knuck), dors)).transposed()
            Rm = dst @ src.inverted()
            fdir = (wrist - fore).normalized()
            centre = wrist - fdir * 0.12 + dors * 0.16
            roll = float(_opts0.get("roll_" + side, "0"))
            if roll:
                Rm = Matrix.Rotation(math.radians(roll), 3, fy) @ Rm
            T = Matrix.Translation(centre) @ Rm.to_4x4() @ Matrix.Translation(-Vector(c))
        o.data.transform(W.inverted() @ T @ W)
        print("OVERLORD griff", S, "neu ausgerichtet")

    for spec in _attach:
        path, mode = spec.rsplit(":", 1)
        new = imported(lambda: bpy.ops.import_scene.fbx(filepath=os.path.abspath(path)))
        for x in [x for x in new if x.type != "MESH"]:
            bpy.data.objects.remove(x)
        for o in [x for x in new if x.type == "MESH"]:
            mw = (M @ o.matrix_world) if M is not None else o.matrix_world.copy()
            # gleiche Objekt-Transformation wie der Körper (der glTF-Export rechnet Skin-Meshes im Armatur-Raum),
            # die Punkte werden so umgerechnet, dass sie an derselben Weltposition bleiben
            o.parent = arm
            o.matrix_parent_inverse = body.matrix_parent_inverse.copy()
            o.matrix_basis = body.matrix_basis.copy()
            bpy.context.view_layer.update()
            o.data.transform(o.matrix_world.inverted() @ mw)
            for g in list(o.vertex_groups):
                o.vertex_groups.remove(g)
            mod = o.modifiers.new("Armature", "ARMATURE")
            mod.object = arm
            if mode == "transfer":
                for g in body.vertex_groups:
                    o.vertex_groups.new(name=g.name)
                dt = o.modifiers.new("dt", "DATA_TRANSFER")
                dt.object = body
                dt.use_vert_data = True
                dt.data_types_verts = {"VGROUP_WEIGHTS"}
                dt.vert_mapping = "POLYINTERP_NEAREST"
                dt.layers_vgroup_select_src = "ALL"
                dt.layers_vgroup_select_dst = "NAME"
                bpy.context.view_layer.objects.active = o
                bpy.ops.object.modifier_move_to_index(modifier="dt", index=0)
                bpy.ops.object.modifier_apply(modifier="dt")
            elif mode == "back":
                # Umhang: oben Brust, Mitte Rücken, unten Hüfte (+ etwas Bein je Seite) – keine Armgewichte
                zs_ = [(o.matrix_world @ v.co).z for v in o.data.vertices]
                z0_, z1_ = min(zs_), max(zs_)
                grp = {n: (o.vertex_groups.get(bnames[n]) or o.vertex_groups.new(name=bnames[n]))
                       for n in ("Spine2", "Spine1", "Spine", "Hips", "LeftUpLeg", "RightUpLeg") if n in bnames}
                for v in o.data.vertices:
                    p_ = o.matrix_world @ v.co
                    t = (p_.z - z0_) / max(z1_ - z0_, 1e-6)       # 0 unten … 1 oben
                    ws = {"Spine2": max(0.0, t * 2 - 1), "Spine1": 1 - abs(t * 2 - 1.2) if 0.1 < t < 1.0 else 0.0,
                          "Spine": max(0.0, 1 - abs(t * 2 - 0.7)), "Hips": max(0.0, 1 - t * 2)}
                    leg = 0.25 * max(0.0, 1 - t * 2)
                    ws["LeftUpLeg" if p_.x > 0 else "RightUpLeg"] = leg
                    tot = sum(ws.values()) or 1.0
                    for n, w in ws.items():
                        if n in grp and w > 0:
                            grp[n].add([v.index], w / tot, "REPLACE")
                o["overlord_rigid"] = True
            elif mode == "grip":
                regrip(o)
                for v in o.data.vertices:
                    p_ = o.matrix_world @ v.co
                    bn = "RightHand" if o.get("side") == "R" else "LeftHand"
                    g = o.vertex_groups.get(bnames[bn]) or o.vertex_groups.new(name=bnames[bn])
                    g.add([v.index], 1.0, "REPLACE")
            else:
                for v in o.data.vertices:
                    p_ = o.matrix_world @ v.co
                    bn = mode if mode in bnames else ("RightHand" if p_.x < 0 else "LeftHand")
                    g = o.vertex_groups.get(bnames[bn]) or o.vertex_groups.new(name=bnames[bn])
                    g.add([v.index], 1.0, "REPLACE")
            meshes.append(o)
            if mode != "transfer":
                o["overlord_rigid"] = True
            print("OVERLORD anbau", os.path.basename(path), mode, len(o.data.vertices), "punkte")

# Stoff-Gewichte reparieren (optional, 4. Argument z. B. "cloth=skirt" oder "cloth=robe"):
# Mixamo bindet Rock/Mantel/Schulterplatten an Arm- und Beinknochen – der Stoff reißt dann zwischen den Beinen
# auf oder wird von den Armen mitgezogen. Liegt ein Punkt weit vom Gliedmaßenknochen entfernt, ist er Stoff:
# sein Gewicht wandert (weich, nach Entfernung) zum nächsten Rumpfknochen. Beine behalten einen Rest,
# damit der Rock beim Gehen etwas mitschwingt; Arme geben Stoffpunkte ganz ab (Mantel, Schulterplatten).
_opts = dict(a.split("=", 1) for a in sys.argv[sys.argv.index("--") + 4:] if "=" in a and not a.startswith("attach="))
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
    # creature = Wesen mit Zusatzgliedern (Cocytus: zweites Armpaar, Hellebarde, Schwanz) → Rumpf/Hüfte
    keep_leg = {"skirt": 0.08, "robe": 0.3, "cape": 0.6, "creature": 0.0}.get(CLOTH, 0.25)
    HAIR_TO = (("Spine2", 0.6), ("Spine1", 0.4)) if CLOTH == "creature" else (("Head", 0.6), ("Neck", 0.4))
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
                for n, share in HAIR_TO:
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

    for o in [m for m in meshes if not m.get("overlord_rigid")]:
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
        # rigid=Knochen:x0:x1:y0:y1:z0:z1[|…] – Waffen/Anbauteile in einer Box fest an einen Knochen (T-Pose-Koordinaten)
        for spec in [x for x in _opts.get("rigid", "").split("|") if x]:
            parts = spec.split(":")
            bn, (x0, x1, y0, y1, z0, z1) = parts[0], [float(c) for c in parts[1:7]]
            if bn not in bones:
                continue
            if bn not in vg:
                vg[bn] = o.vertex_groups.new(name=bones[bn][2])
            idx = []
            for v in o.data.vertices:
                p_ = POS[o.name][v.index] if o.name in POS else o.matrix_world @ v.co
                if x0 <= p_.x <= x1 and y0 <= p_.y <= y1 and z0 <= p_.z <= z1:
                    idx.append(v.index)
            for g in o.vertex_groups:
                g.remove(idx)
            vg[bn].add(idx, 1.0, "REPLACE")
            print("OVERLORD starr", bn, len(idx), "punkte")
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
