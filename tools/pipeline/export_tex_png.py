"""Unreal: Texturen mit Alphakanal als PNG exportieren (AssetExportTask + TextureExporterPNG).
RenderingLibrary.export_texture2d schreibt Radiance-HDR ohne Alpha – für Gras/Laub ungeeignet.

  UnrealEditor-Cmd.exe <proj> -run=pythonscript -script="export_tex_png.py <zielordner> /Game/Pfad/T_A /Game/Pfad/T_B ..."
Dateiname wie bei export_meshes.py (Paketordner + Name), überschreibt die HDR-Fassung.
"""
import os
import sys

import unreal

args = [a for a in sys.argv[1:] if a]
out_dir, paths = args[0], args[1:]
os.makedirs(out_dir, exist_ok=True)
for p in paths:
    tex = unreal.load_asset(p)
    if tex is None:
        unreal.log_warning("OVERLORD fehlt %s" % p)
        continue
    pkg = tex.get_path_name().split(".")[0].split("/")
    stem = "_".join(pkg[3:-1] + [tex.get_name()]) if len(pkg) > 4 else tex.get_name()
    task = unreal.AssetExportTask()
    task.object = tex
    task.filename = os.path.join(out_dir, stem + ".png")
    task.automated = True
    task.replace_identical = True
    task.prompt = False
    task.exporter = unreal.TextureExporterPNG()
    ok = unreal.Exporter.run_asset_export_task(task)
    unreal.log_warning("OVERLORD %s %s" % ("ok" if ok else "FEHLER", task.filename))
