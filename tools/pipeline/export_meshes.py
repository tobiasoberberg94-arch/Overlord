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

SLOTS = {"basecolor": ("basecolor", "base color", "albedo", "diffuse", "color", "_bc", "_d", "_basecolor", "_albedo"),
         "normal": ("normal", "_n", "_nm", "_normal")}


JUNK = ("empty", "default", "noise", "_mask", "white", "black", "dummy")


def classify_param(pn):
    """Slot aus dem Parameternamen (Base_Texture, Base_Normal, BaseColor …)."""
    if any(k in pn for k in ("normal", "_n ", "nrm")):
        return "normal"
    if any(k in pn for k in ("base_texture", "basecolor", "base color", "base_color", "albedo", "diffuse", "base texture")):
        return "basecolor"
    if pn.endswith("-bc") or pn.endswith("_bc"):
        return "basecolor"
    if pn.endswith("-n") or pn.endswith("_n"):
        return "normal"
    return None


def classify(name):
    n = name.lower()
    # Endungen zuerst (T_Wall_BC / T_Wall_N), sonst Teilwörter
    for slot, ends in (("basecolor", ("_bc", "_d", "_basecolor", "_albedo", "_diffuse")), ("normal", ("_n", "_nm", "_normal"))):
        if any(n.endswith(e) for e in ends):
            return slot
    for slot, keys in SLOTS.items():
        if any(k in n for k in keys):
            return slot
    return None


exported = {}


def export_tex(tex):
    """Textur als PNG speichern. Über RenderingLibrary (rendert die Textur), weil der
    Asset-Exporter bei vielen Formaten/virtuellen Texturen mit einer Assertion abbricht."""
    p = tex.get_path_name()
    if p in exported:
        return exported[p]
    if not isinstance(tex, unreal.Texture2D):
        exported[p] = None
        return None
    # Eindeutiger Dateiname aus dem Paketpfad (gleiche Texturnamen in verschiedenen Ordnern!)
    pkg = p.split(".")[0].split("/")
    stem = "_".join(pkg[3:-1] + [tex.get_name()]) if len(pkg) > 4 else tex.get_name()
    fname = stem + ".png"
    try:
        world = unreal.get_editor_subsystem(unreal.UnrealEditorSubsystem).get_editor_world()
        unreal.RenderingLibrary.export_texture2d(world, tex, tex_dir, fname)
    except Exception as e:
        unreal.log_warning("OVERLORD Textur %s nicht exportiert: %s" % (tex.get_name(), e))
        fname = None
    if fname and not os.path.exists(os.path.join(tex_dir, fname)):
        # HDR-Texturen landen als .exr
        alt = os.path.splitext(fname)[0] + ".exr"
        fname = alt if os.path.exists(os.path.join(tex_dir, alt)) else None
    exported[p] = fname
    return fname


materials = {}
for path in paths:
    sm = unreal.load_asset(path)
    name = path.split("/")[-1]
    if isinstance(sm, unreal.Texture2D):        # einzelne Texturen (z. B. Bodenschichten) direkt exportieren
        unreal.log("OVERLORD Textur %s -> %s" % (name, export_tex(sm)))
        continue
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
            params = []
            for p in unreal.MaterialEditingLibrary.get_texture_parameter_names(mat):
                tex = mat.get_texture_parameter_value(p)
                if not tex or any(k in tex.get_name().lower() for k in JUNK):
                    continue                     # Platzhalter (weiß, Rauschen, Maske)
                pn = str(p).lower()
                slot = classify_param(pn) or classify(tex.get_name())
                if slot:
                    # Basis-Schicht vor Deck-/Detailschichten (Top_, Detail_, Layer2 …)
                    prio = 0 if any(k in pn for k in ("base", "albedo", "diffuse", "color")) else 1
                    if any(k in pn for k in ("top", "detail", "overlay", "puddle", "snow", "moss")):
                        prio = 2
                    params.append((prio, slot, tex))
            for prio, slot, tex in sorted(params, key=lambda t: t[0]):
                if slot not in entry:
                    f = export_tex(tex)
                    if f:
                        entry[slot] = f
        except Exception as e:
            unreal.log_warning("OVERLORD %s: %s" % (mat.get_name(), e))
        if "basecolor" not in entry:
            base = mat.get_base_material() if isinstance(mat, unreal.MaterialInstance) else mat
            for tex in unreal.MaterialEditingLibrary.get_used_textures(base):
                if any(k in tex.get_name().lower() for k in JUNK):
                    continue
                slot = classify(tex.get_name())
                if slot and slot not in entry:
                    f = export_tex(tex)
                    if f:
                        entry[slot] = f
        if "basecolor" not in entry:
            try:
                names = [(str(q), (mat.get_texture_parameter_value(q).get_name() if mat.get_texture_parameter_value(q) else None))
                         for q in unreal.MaterialEditingLibrary.get_texture_parameter_names(mat)]
            except Exception:
                names = []
            unreal.log_warning("OVERLORD ohne Farbe %s %s" % (mat.get_name(), names))
        materials[mat.get_name()] = entry

with open(os.path.join(out_dir, "materials.json"), "w", encoding="utf-8") as f:
    json.dump({"materials": materials, "anchors": {}, "lights": []}, f, indent=1)
unreal.log("OVERLORD fertig: %d Meshes, %d Materialien, %d Texturen" % (len(paths), len(materials), len(exported)))
