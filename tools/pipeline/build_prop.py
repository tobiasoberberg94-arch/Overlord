# Requisit aus einem Tripo-FBX (Maske, Waffe …) → GLB mit eingebetteten Texturen für assets/models/props.
#   blender.exe -b --python tools/pipeline/build_prop.py -- <Quellordner> <Ziel-GLB> <Maßstab> <px,py,pz> [rot_z°] [base_px] [normal_px]
# Quellordner: model.fbx + *_BaseColor/_Metallic/_Normal/_Roughness.png (Tripo-Export). Vorher mit ffmpeg
# verkleinerte Texturen in <Quellordner>/build/ (base.jpg, normal.png, metallic.png, roughness.png) – legt das Skript an,
# wenn ffmpeg im Pfad ist. Drehpunkt px,py,pz in Blender-Einheiten des Originals wird zum Ursprung, danach Maßstab;
# rot_z dreht das Modell vorher um die Hochachse (Tripo-Modelle blicken mal nach +X, mal nach -Y).
import bpy, math, mathutils, os, sys, subprocess, glob

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
SRC = argv[0].replace("\\", "/").rstrip("/") + "/"
GLB = argv[1].replace("\\", "/")
SCALE = float(argv[2])
PIV = mathutils.Vector(tuple(float(v) for v in argv[3].split(",")))
ROT_Z = float(argv[4]) if len(argv) > 4 else 0.0
BASE_PX = int(argv[5]) if len(argv) > 5 else 2048
NORMAL_PX = int(argv[6]) if len(argv) > 6 else 1024
OUT = SRC + "build/"
os.makedirs(OUT, exist_ok=True)
NAME = os.path.splitext(os.path.basename(GLB))[0]

# ---------------------------------------------------------------- Texturen verkleinern (ffmpeg)
def tex(suffix):
    hits = glob.glob(SRC + "*_" + suffix + ".png")
    return hits[0] if hits else None
conv = {"base": (tex("BaseColor"), OUT + NAME + "_basecolor.jpg", BASE_PX, ["-q:v", "3", "-pix_fmt", "yuvj420p"]),   # 4:2:0 – Godots JPEG-Decoder lädt kein 4:4:4
        "normal": (tex("Normal"), OUT + NAME + "_normal.png", NORMAL_PX, []),
        "metallic": (tex("Metallic"), OUT + NAME + "_metallic.png", NORMAL_PX, []),
        "roughness": (tex("Roughness"), OUT + NAME + "_roughness.png", NORMAL_PX, [])}
for k, (src, dst, px, extra) in conv.items():
    if src and not os.path.exists(dst):
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", src, "-vf", "scale=%d:-1" % px] + extra + [dst], check=True)

# ---------------------------------------------------------------- Import und Texturen
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.fbx(filepath=SRC + "model.fbx")
ob = [o for o in bpy.data.objects if o.type == 'MESH'][0]
ob.name = NAME
ob.data.name = NAME
for img in list(bpy.data.images):
    for key, tag in [("base", "_Base"), ("metallic", "_Meta"), ("normal", "_Norm"), ("roughness", "_Roug")]:
        if tag in img.name:
            img.filepath = conv[key][1]
            img.source = 'FILE'
            img.reload()
            img.name = NAME + "_" + key
mat = ob.data.materials[0]
mat.name = NAME
for n in mat.node_tree.nodes:
    if n.type == 'BSDF_PRINCIPLED':
        n.inputs["Specular IOR Level"].default_value = 0.4
print("Texturen:", [(i.name, i.size[:]) for i in bpy.data.images])

# ---------------------------------------------------------------- Drehpunkt, Drehung, Maßstab einbacken
me = ob.data
for v in me.vertices:
    v.co = (v.co - PIV)
ob.rotation_euler = (0.0, 0.0, math.radians(ROT_Z))
ob.scale = (SCALE, SCALE, SCALE)
bpy.context.view_layer.objects.active = ob
for o in bpy.data.objects:
    o.select_set(o == ob)
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
bb = [ob.matrix_world @ mathutils.Vector(c) for c in ob.bound_box]
print("Maße (m): x %.3f..%.3f  y %.3f..%.3f  z %.3f..%.3f  (Blender: -y = vorn, z = oben)" % (min(v.x for v in bb), max(v.x for v in bb), min(v.y for v in bb), max(v.y for v in bb), min(v.z for v in bb), max(v.z for v in bb)))
print("Mesh: %d Vertices, %d Flächen" % (len(me.vertices), len(me.polygons)))

# ---------------------------------------------------------------- Export
bpy.ops.export_scene.gltf(filepath=GLB, export_format='GLB', use_selection=True, export_apply=False,
    export_animations=False, export_skins=False, export_morph=False, export_image_format='AUTO',
    export_texcoords=True, export_normals=True, export_yup=True)
print("GLB:", GLB, os.path.getsize(GLB), "Bytes")

# ---------------------------------------------------------------- Kontrollbild
scene = bpy.context.scene
scene.render.engine = 'BLENDER_WORKBENCH'
scene.display.shading.light = 'STUDIO'
scene.display.shading.color_type = 'TEXTURE'
scene.render.resolution_x = 600
scene.render.resolution_y = 600
cam_data = bpy.data.cameras.new("cam")
cam = bpy.data.objects.new("cam", cam_data)
scene.collection.objects.link(cam)
scene.camera = cam
ctr = sum(bb, mathutils.Vector()) / 8.0
r = max(max(v.x for v in bb) - min(v.x for v in bb), max(v.y for v in bb) - min(v.y for v in bb), max(v.z for v in bb) - min(v.z for v in bb)) * 2.2
cam.location = ctr + mathutils.Vector((r * 0.5, -r * 0.8, r * 0.3))
cam.rotation_euler = (ctr - cam.location).to_track_quat('-Z', 'Y').to_euler()
scene.render.filepath = OUT + NAME + "_preview.png"
bpy.ops.render.render(write_still=True)
print("FERTIG")
