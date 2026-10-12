# Blender: Mixamo-Albedo (idle mit Skin + Animationen ohne Skin) -> albedo.glb
#   blender -b -P build_albedo2.py -- <mixamo-ordner> <texturordner> <ziel.glb>
# Eine Armatur, jede Animation als eigene Action/NLA-Spur (Name = Spiel-Animation).
# Texturen werden nach Materialname (badan = Koerper, mata = Augen) neu verknuepft,
# falls Mixamo sie nicht mitliefert.
import glob
import os
import sys

import bpy

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

# Materialien: beleuchtetes PBR mit Basistextur; Haare/Augen mit Alpha-Clip
for o in meshes:
    for slot in o.material_slots:
        m = slot.material
        if not m:
            continue
        key = "mata" if "mata" in m.name.lower() or "2" in m.name else "badan"
        nt = m.node_tree
        bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
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
