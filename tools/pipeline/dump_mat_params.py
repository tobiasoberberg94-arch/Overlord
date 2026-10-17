"""Unreal: Texturparameter aller Materialinstanzen unter einem Ordner auflisten (+ Blend-Mode des Elternmaterials).
  UnrealEditor-Cmd.exe <proj> -run=pythonscript -script="dump_mat_params.py <ausgabe.json> /Game/Ordner1 /Game/Ordner2"
"""
import json
import sys

import unreal

args = [a for a in sys.argv[1:] if a]
out, roots = args[0], args[1:]
res = {}
for root in roots:
    for p in unreal.EditorAssetLibrary.list_assets(root, recursive=True):
        a = unreal.load_asset(p)
        if not isinstance(a, unreal.MaterialInstanceConstant):
            continue
        e = {"textures": {}, "scalars": {}}
        for tp in a.get_editor_property("texture_parameter_values"):
            t = tp.get_editor_property("parameter_value")
            e["textures"][str(tp.get_editor_property("parameter_info").get_editor_property("name"))] = t.get_path_name() if t else None
        for sp in a.get_editor_property("scalar_parameter_values"):
            e["scalars"][str(sp.get_editor_property("parameter_info").get_editor_property("name"))] = sp.get_editor_property("parameter_value")
        base = a.get_base_material()
        if base:
            e["blend"] = str(base.get_editor_property("blend_mode"))
            e["two_sided"] = bool(base.get_editor_property("two_sided"))
            e["base"] = base.get_name()
        res[a.get_name()] = e
json.dump(res, open(out, "w"), indent=1)
unreal.log_warning("OVERLORD materialien %d" % len(res))
