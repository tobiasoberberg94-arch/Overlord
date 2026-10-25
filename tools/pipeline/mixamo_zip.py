# Mixamo-Upload-Paket: <Name>/<name>_mixamo.fbx -> <Name>/<name>_mixamo.zip (OBJ + MTL + Grundfarbe)
# Mixamo nimmt Blender-FBX oft nicht an ("Upload failed"); OBJ im ZIP mit der Grundfarbe klappt zuverlaessig
# (so wurden Aura, Demiurge usw. hochgeladen). Aufruf: blender -b --python mixamo_zip.py -- <Modellordner> [...]
import bpy, os, sys, zipfile, glob
dirs = sys.argv[sys.argv.index("--") + 1:]
for d in dirs:
    d = os.path.abspath(d)
    fbx = glob.glob(os.path.join(d, "*_mixamo.fbx"))
    if not fbx:
        print("KEIN FBX:", d)
        continue
    fbx = fbx[0]
    name = os.path.basename(fbx).replace("_mixamo.fbx", "")
    base = os.path.join(d, name + "_mixamo_basecolor.jpg")
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.fbx(filepath=fbx)
    meshes = [o for o in bpy.data.objects if o.type == 'MESH']
    for o in bpy.data.objects:
        o.select_set(o.type == 'MESH')
    bpy.context.view_layer.objects.active = meshes[0]
    if len(meshes) > 1:
        bpy.ops.object.join()
    ob = bpy.context.view_layer.objects.active
    ob.name = name
    ob.data.name = name
    bb = [ob.matrix_world @ v.co for v in ob.data.vertices]
    zs = [v.z for v in bb]; ys = [v.y for v in bb]; xs = [v.x for v in bb]
    obj = os.path.join(d, name + ".obj")
    bpy.ops.wm.obj_export(filepath=obj, export_selected_objects=True, export_materials=True, export_uv=True,
                          export_normals=True, export_triangulated_mesh=True, forward_axis='NEGATIVE_Z', up_axis='Y',
                          path_mode='STRIP')
    mtl = os.path.join(d, name + ".mtl")
    with open(mtl, "w") as f:
        f.write("newmtl Material_01\nKd 1 1 1\nmap_Kd %s\n" % os.path.basename(base))
    # OBJ auf das eine Material zeigen lassen
    lines = open(obj, encoding="utf-8").read().splitlines()
    out = []
    seen = False
    for ln in lines:
        if ln.startswith("mtllib"):
            out.append("mtllib %s.mtl" % name)
        elif ln.startswith("usemtl"):
            if not seen:
                out.append("usemtl Material_01")
                seen = True
        else:
            out.append(ln)
    open(obj, "w", encoding="utf-8").write("\n".join(out) + "\n")
    zpath = os.path.join(d, name + "_mixamo.zip")
    with zipfile.ZipFile(zpath, "w", zipfile.ZIP_DEFLATED) as z:
        z.write(obj, os.path.basename(obj))
        z.write(mtl, os.path.basename(mtl))
        z.write(base, os.path.basename(base))
    print("ZIP %s: %d Dreiecke, Hoehe %.2f m, Breite %.2f, Tiefe %.2f, Textur %s, %d KB" % (
        name, len(ob.data.polygons), max(zs) - min(zs), max(xs) - min(xs), max(ys) - min(ys), os.path.exists(base), os.path.getsize(zpath) // 1024))
