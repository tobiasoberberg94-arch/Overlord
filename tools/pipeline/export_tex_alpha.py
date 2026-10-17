"""Unreal: Texturen MIT Alphakanal als PNG exportieren (Blätter, Gras, Gitter …).
Variante 1: ImageWriteBlueprintLibrary.export_to_disk; Variante 2: Canvas-Kopie in ein RGBA8-Render-Target.

  UnrealEditor-Cmd.exe <proj> -run=pythonscript -script="export_tex_alpha.py <zielordner> /Game/Pfad/T_A ..." -AllowCommandletRendering
"""
import os
import sys

import unreal

args = [a for a in sys.argv[1:] if a]
out_dir, paths = args[0], args[1:]
os.makedirs(out_dir, exist_ok=True)
world = unreal.get_editor_subsystem(unreal.UnrealEditorSubsystem).get_editor_world()


def stem_of(tex):
    pkg = tex.get_path_name().split(".")[0].split("/")
    return "_".join(pkg[3:-1] + [tex.get_name()]) if len(pkg) > 4 else tex.get_name()


def via_canvas(tex, fname):
    w, h = tex.blueprint_get_size_x(), tex.blueprint_get_size_y()
    w, h = min(w, 2048), min(h, 2048)
    rt = unreal.RenderingLibrary.create_render_target2d(world, w, h, unreal.TextureRenderTargetFormat.RTF_RGBA8,
                                                         unreal.LinearColor(0, 0, 0, 0))
    unreal.RenderingLibrary.clear_render_target2d(world, rt, unreal.LinearColor(0, 0, 0, 0))
    canvas, size, ctx = unreal.RenderingLibrary.begin_draw_canvas_to_render_target(world, rt)
    canvas.draw_texture(tex, unreal.Vector2D(0, 0), unreal.Vector2D(w, h), unreal.Vector2D(0, 0), unreal.Vector2D(1, 1),
                        unreal.LinearColor(1, 1, 1, 1), unreal.BlendMode.BLEND_OPAQUE)
    unreal.RenderingLibrary.end_draw_canvas_to_render_target(world, ctx)
    unreal.RenderingLibrary.export_render_target(world, rt, out_dir, fname)


mode = os.environ.get("OVERLORD_TEXMODE", "imagewrite")
for p in paths:
    tex = unreal.load_asset(p)
    if not isinstance(tex, unreal.Texture2D):
        unreal.log_warning("OVERLORD fehlt %s" % p)
        continue
    fname = stem_of(tex) + ".png"
    tex.set_editor_property("never_stream", True)
    tex.set_force_mip_levels_to_be_resident(60.0)
    unreal.log_warning("OVERLORD groesse %s %dx%d src %s" % (fname, tex.blueprint_get_size_x(), tex.blueprint_get_size_y(),
                       tex.get_editor_property("compression_settings")))
    # Erzwingt das Fertigkompilieren der Textur (sonst zeichnet der Canvas die weiße Ersatztextur)
    tmp = os.path.join(out_dir, "_tmp")
    os.makedirs(tmp, exist_ok=True)
    unreal.RenderingLibrary.export_texture2d(world, tex, tmp, "x.hdr")
    try:
        if mode == "imagewrite":
            opts = unreal.ImageWriteOptions()
            opts.format = unreal.DesiredImageFormat.PNG
            opts.overwrite_file = True
            opts.async_ = False
            unreal.ImageWriteBlueprintLibrary.export_to_disk(tex, os.path.join(out_dir, fname), opts)
        else:
            via_canvas(tex, fname)
        unreal.log_warning("OVERLORD ok %s" % fname)
    except Exception as e:
        unreal.log_warning("OVERLORD FEHLER %s: %s" % (fname, e))
