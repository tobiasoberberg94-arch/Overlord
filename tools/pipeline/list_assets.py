"""Unreal: alle Static Meshes unter einem Pfad mit Maßen auflisten (für die Auswahl von Bauteilen).

  UnrealEditor-Cmd.exe <proj> -run=pythonscript -script="list_assets.py /Game/FantasyCastle <ausgabe.json>"
"""
import json
import sys

import unreal

root, out = [a for a in sys.argv[1:] if a][:2]
reg = unreal.AssetRegistryHelpers.get_asset_registry()
assets = reg.get_assets_by_path(root, recursive=True)
rows = []
for a in assets:
    cls = str(a.asset_class_path.asset_name)
    if cls not in ("StaticMesh", "World", "Blueprint"):
        continue
    row = {"path": str(a.package_name), "class": cls}
    if cls == "StaticMesh":
        sm = unreal.load_asset(str(a.package_name))
        b = sm.get_bounding_box()
        size = b.max - b.min
        row["size_m"] = [round(size.x / 100, 2), round(size.y / 100, 2), round(size.z / 100, 2)]
        try:
            row["tris"] = unreal.EditorStaticMeshLibrary.get_number_verts(sm, 0)
        except Exception:
            pass
        row["mats"] = sorted({m.material_interface.get_name() for m in sm.static_materials if m.material_interface})
    rows.append(row)
with open(out, "w", encoding="utf-8") as f:
    json.dump(rows, f, indent=1)
unreal.log("OVERLORD %d Assets -> %s" % (len(rows), out))
