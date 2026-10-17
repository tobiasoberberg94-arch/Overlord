# Blender: glb rendern (vorne, schraeg, hinten) -> preview_*.png
#   blender -b -P preview.py -- albedo.glb <ausgabeordner> [aktion] [frame]
import math
import os
import sys

import bpy
from mathutils import Vector

args = sys.argv[sys.argv.index("--") + 1:]
src, out = os.path.abspath(args[0]), os.path.abspath(args[1])
action = args[2] if len(args) > 2 else None
frame = int(args[3]) if len(args) > 3 else 1
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=src)
arm = next((o for o in bpy.data.objects if o.type == "ARMATURE"), None)
act = None
if action:   # glTF-Import benennt Aktionen teils um (z. B. "walk_Armature") – nach Präfix/Teilstring suchen
    act = bpy.data.actions.get(action) or next((a for a in bpy.data.actions if a.name.split("_")[0] == action or a.name.startswith(action)), None)
    print("OVERLORD aktionen", [a.name for a in bpy.data.actions], "->", act.name if act else None)
if arm and act:
    arm.animation_data_create()
    for t in list(arm.animation_data.nla_tracks):
        arm.animation_data.nla_tracks.remove(t)
    arm.animation_data.action = act
bpy.context.scene.frame_set(frame)
sc = bpy.context.scene
sc.render.engine = "BLENDER_EEVEE_NEXT"
sc.render.resolution_x, sc.render.resolution_y = 600, 800
sc.world = bpy.data.worlds.new("w")
sc.world.color = (0.25, 0.25, 0.28)
sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN"))
sun.data.energy = 3
sun.rotation_euler = (math.radians(50), 0, math.radians(30))
sc.collection.objects.link(sun)
cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
sc.collection.objects.link(cam)
sc.camera = cam
target = Vector((0, 0, 0.95))
for name, ang in (("front", 0), ("side", 60), ("back", 180)):
    a = math.radians(ang)
    cam.location = target + Vector((math.sin(a) * 3.4, -math.cos(a) * 3.4, 0.25))
    cam.rotation_euler = (target - cam.location).to_track_quat("-Z", "Y").to_euler()
    sc.render.filepath = os.path.join(out, "preview_%s%s.png" % (name, "_" + action if action else ""))
    bpy.ops.render.render(write_still=True)
print("OVERLORD gerendert")
