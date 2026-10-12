"""Unreal: einzelne Static Meshes als FBX exportieren (+ Basistexturen, Materialliste).

  UnrealEditor-Cmd.exe <proj> -run=pythonscript -script="export_meshes.py <ausgabeordner> /Game/Pfad/SM_A /Game/Pfad/SM_B ..."
Ergebnis: <ausgabe>/meshes/<Name>.fbx, <ausgabe>/textures/*.png, <ausgabe>/materials.json
"""
import json
import os
import sys

import unreal

args = [a for a in sys.argv[1:] if a]
out_dir, paths = args[0], args[1:]
mesh_dir = os.path.join(out_dir, "meshes")
tex_dir = os.path.join(out_dir, "textures")
os.makedirs(mesh_dir, exist_ok=True)
os.makedirs(tex_dir, exist_ok=True)

SLOTS = {"basecolor": ("basecolor", "base color", "albedo", "diffuse", "color", "_bc", "_d"),
         "normal": ("normal", "_n")}


def classify(name):
    n = name.lower()
    for slot, keys in SLOTS.items():
        if any(k in n for k in keys):
            return slot
    return None


exported = {}


def export_tex(tex):
    p = tex.get_path_name()
    if p in exported:
        return exported[p]
    fname = tex.get_name() + ".png"
    t = unreal.AssetExportTask()
    t.object = tex
    t.filename = os.path.join(tex_dir, fname)
    t.automated = True
    t.prompt = False
    t.replace_identical = True
    t.exporter = unreal.TextureExporterPNG()
    if not unreal.Exporter.run_asset_export_task(t):
        fname = tex.get_name() + ".tga"
        t.exporter = unreal.TextureExporterTGA()
        t.filename = os.path.join(tex_dir, fname)
        unreal.Exporter.run_asset_export_task(t)
    exported[p] = fname
    return fname


materials = {}
for path in paths:
    sm = unreal.load_asset(path)
    name = path.split("/")[-1]
    task = unreal.AssetExportTask()
    task.object = sm
    task.filename = os.path.join(mesh_dir, name + ".fbx")
    task.automated = True
    task.prompt = False
    task.replace_identical = True
    opts = unreal.FbxExportOption()
    opts.collision = False
    opts.level_of_detail = False
    task.options = opts
    ok = unreal.Exporter.run_asset_export_task(task)
    unreal.log("OVERLORD %s: %s" % (name, ok))
    for sl in sm.static_materials:
        mat = sl.material_interface
        if not mat or mat.get_name() in materials:
            continue
        entry = {}
        try:
            for p in unreal.MaterialEditingLibrary.get_texture_parameter_names(mat):
                tex = mat.get_texture_parameter_value(p)
                slot = classify(str(p))
                if tex and slot and slot not in entry:
                    entry[slot] = export_tex(tex)
        except Exception as e:
            unreal.log_warning("OVERLORD %s: %s" % (mat.get_name(), e))
        if "basecolor" not in entry:
            base = mat.get_base_material() if isinstance(mat, unreal.MaterialInstance) else mat
            for tex in unreal.MaterialEditingLibrary.get_used_textures(base):
                slot = classify(tex.get_name())
                if slot and slot not in entry:
                    entry[slot] = export_tex(tex)
        materials[mat.get_name()] = entry

with open(os.path.join(out_dir, "materials.json"), "w", encoding="utf-8") as f:
    json.dump({"materials": materials, "anchors": {}, "lights": []}, f, indent=1)
unreal.log("OVERLORD fertig: %d Meshes, %d Materialien, %d Texturen" % (len(paths), len(materials), len(exported)))
