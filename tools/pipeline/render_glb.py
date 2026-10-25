# Kontaktbogen eines Figuren-GLB: je Aktion drei Posen (Workbench, Texturfarben). Aufruf:
#   blender -b --python render_glb.py -- <modell.glb> <ausgabe.png> [aktion,aktion,...]
import bpy, sys, os, math, subprocess, tempfile
args = sys.argv[sys.argv.index("--") + 1:]
glb, out = os.path.abspath(args[0]), os.path.abspath(args[1])
only = args[2].split(",") if len(args) > 2 else None
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=glb)
arm = [o for o in bpy.data.objects if o.type == 'ARMATURE'][0]
for o in list(bpy.data.objects):
    if o.name.startswith("Icosphere"):
        bpy.data.objects.remove(o)
meshes = [o for o in bpy.data.objects if o.type == 'MESH']
zs = []
for o in meshes:
    zs += [(o.matrix_world @ v.co).z for i, v in enumerate(o.data.vertices) if i % 50 == 0]
height = max(zs) - min(zs) if zs else 1.8
scene = bpy.context.scene
scene.render.engine = 'BLENDER_WORKBENCH'
scene.display.shading.light = 'STUDIO'
scene.display.shading.color_type = 'TEXTURE'
scene.render.resolution_x = 300
scene.render.resolution_y = 460
scene.world = bpy.data.worlds.new("W")
scene.world.color = (0.22, 0.22, 0.25)
cam_data = bpy.data.cameras.new("C")
cam = bpy.data.objects.new("C", cam_data)
scene.collection.objects.link(cam)
d = max(3.2, height * 2.3)
cam.location = (d * 0.35, -d, height * 0.55)
cam.rotation_euler = (math.radians(84), 0, math.radians(19))
cam_data.lens = 45
scene.camera = cam
if arm.animation_data is None:
    arm.animation_data_create()
ad = arm.animation_data
for tr in ad.nla_tracks:
    tr.mute = True
tmp = tempfile.mkdtemp()
files = []
acts = [a for a in bpy.data.actions if only is None or any(a.name.startswith(n) for n in only)]
print("Aktionen:", [(a.name, int(a.frame_range[1])) for a in bpy.data.actions], "Höhe %.2f" % height)
for a in acts:
    ad.action = a
    f0, f1 = a.frame_range
    for k, fr in enumerate([f0, f0 + (f1 - f0) * 0.4, f0 + (f1 - f0) * 0.8]):
        scene.frame_set(int(fr))
        p = os.path.join(tmp, "%s_%d.png" % (a.name, k))
        scene.render.filepath = p
        bpy.ops.render.render(write_still=True)
        files.append(p)
# Bogen: je Aktion eine Zeile aus drei Bildern
rows = []
for i in range(0, len(files), 3):
    r = os.path.join(tmp, "row%d.png" % (i // 3))
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error"] + sum([["-i", f] for f in files[i:i + 3]], []) + ["-filter_complex", "hstack=3", r], check=True)
    rows.append(r)
# maximal 5 Zeilen je Bogen, mehrere Bögen nebeneinander
cols = []
for i in range(0, len(rows), 5):
    c = os.path.join(tmp, "col%d.png" % (i // 5))
    chunk = rows[i:i + 5]
    if len(chunk) == 1:
        subprocess.run(["cp", chunk[0], c], check=True)
    else:
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error"] + sum([["-i", f] for f in chunk], []) + ["-filter_complex", "vstack=%d" % len(chunk), c], check=True)
    cols.append(c)
if len(cols) == 1:
    subprocess.run(["cp", cols[0], out], check=True)
else:
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error"] + sum([["-i", f] for f in cols], []) + ["-filter_complex", "hstack=%d:shortest=0" % len(cols), out], check=True)
print("BOGEN", out)
