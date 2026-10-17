"""Unreal: Transparenzmasken aller MASKED-Materialinstanzen als Graubild exportieren.
Quelle je Material: eigene Maskentextur (OP/Opacity/Mask → R-Kanal) oder der Alphakanal der Farbtextur
(ColorOpacity/albedo/Texture_R … → A-Kanal). Ein Hilfsmaterial (unlit, Kanal → Emissive) wird in ein
Render-Target gezeichnet; so umgehen wir, dass der Texturexport den Alphakanal verliert.

  UnrealEditor-Cmd.exe <proj> -run=pythonscript -script="export_opacity.py <mat_params.json> <ausgabeordner>" -AllowCommandletRendering
Ergebnis: <ausgabe>/textures/<Material>_OP.png (Radiance-HDR, Graustufen) + <ausgabe>/opacity.json {Material: Datei}
"""
import json
import os
import sys

import unreal

args = [a for a in sys.argv[1:] if a]
params = json.load(open(args[0]))
out_dir = args[1]
tex_dir = os.path.join(out_dir, "textures")
os.makedirs(tex_dir, exist_ok=True)
world = unreal.get_editor_subsystem(unreal.UnrealEditorSubsystem).get_editor_world()
mel = unreal.MaterialEditingLibrary
tools = unreal.AssetToolsHelpers.get_asset_tools()

MASK_KEYS = ("OP", "Opacity", "Opacity_Mask", "Mask")
COLOR_KEYS = ("ColorOpacity", "albedo", "Albedo", "Texture_R", "Bc", "BC")


def make_mat(name, channel, sampler, tex):
    """Hilfsmaterial anlegen und speichern (Shader landen im DDC). Existiert es schon, wird es geladen –
    im ersten Lauf sind die Shader oft noch nicht fertig, daher das Skript zweimal ausführen."""
    path = "/Game/_Overlord/" + name
    if unreal.EditorAssetLibrary.does_asset_exist(path):
        return unreal.load_asset(path)
    m = tools.create_asset(name, "/Game/_Overlord", unreal.Material, unreal.MaterialFactoryNew())
    m.set_editor_property("shading_model", unreal.MaterialShadingModel.MSM_UNLIT)
    n = mel.create_material_expression(m, unreal.MaterialExpressionTextureSampleParameter2D, -400, 0)
    n.set_editor_property("parameter_name", "Tex")
    n.set_editor_property("texture", tex)          # passende Standardtextur, sonst kompiliert VT/Graustufen nicht
    n.set_editor_property("sampler_type", sampler)
    mel.connect_material_property(n, channel, unreal.MaterialProperty.MP_EMISSIVE_COLOR)
    mel.recompile_material(m)
    unreal.EditorAssetLibrary.save_asset(path)
    return m


mats = {}


def mat_for(channel, tex):
    vt = bool(tex.get_editor_property("virtual_texture_streaming"))
    cs = tex.get_editor_property("compression_settings")
    if cs in (unreal.TextureCompressionSettings.TC_GRAYSCALE, unreal.TextureCompressionSettings.TC_ALPHA):
        if tex.get_editor_property("srgb"):
            st = unreal.MaterialSamplerType.SAMPLERTYPE_VIRTUAL_GRAYSCALE if vt else unreal.MaterialSamplerType.SAMPLERTYPE_GRAYSCALE
        else:
            st = unreal.MaterialSamplerType.SAMPLERTYPE_VIRTUAL_LINEAR_GRAYSCALE if vt else unreal.MaterialSamplerType.SAMPLERTYPE_LINEAR_GRAYSCALE
    elif cs == unreal.TextureCompressionSettings.TC_MASKS:
        st = unreal.MaterialSamplerType.SAMPLERTYPE_VIRTUAL_MASKS if vt else unreal.MaterialSamplerType.SAMPLERTYPE_MASKS
    elif not tex.get_editor_property("srgb"):
        st = unreal.MaterialSamplerType.SAMPLERTYPE_VIRTUAL_LINEAR_COLOR if vt else unreal.MaterialSamplerType.SAMPLERTYPE_LINEAR_COLOR
    else:
        st = unreal.MaterialSamplerType.SAMPLERTYPE_VIRTUAL_COLOR if vt else unreal.MaterialSamplerType.SAMPLERTYPE_COLOR
    key = (channel, str(st))
    if key not in mats:
        mats[key] = make_mat("M_OverlordOpacity_%s_%s" % (channel, str(st).split(".")[-1].split(":")[0].replace("SAMPLERTYPE_", "")), channel, st, tex)
    return mats[key]


result = {}
done = {}
for mi, e in params.items():
    if "MASKED" not in e.get("blend", ""):
        continue
    tx = {k.lower(): v for k, v in e["textures"].items() if v}
    src, channel = None, "A"
    for k in ("op", "opacity", "opacity_mask", "mask"):
        t = tx.get(k)
        # „Mask“ ist oft eine RMA/ORM-Packtextur – nur echte Maskentexturen nehmen
        if t and (k != "mask" or t.split(".")[-1].lower().endswith(("_mask", "_o", "_opacity"))):
            src = t
            name = t.split(".")[-1]
            channel = "R" if any(x in name.lower() for x in ("mask", "_op", "opacity", "_o")) and not name.endswith(("_BC", "_D")) else "A"
            break
    if not src and e.get("base", "").startswith(("M_Foliage", "M_Billboard")) and (tx.get("ort") or "").endswith("_ART"):
        src, channel = tx["ort"], "R"
    if not src:
        for k in ("coloropacity", "albedo", "texture_r", "bc", "basecolor", "color"):
            if tx.get(k):
                src = tx[k]
                break
    if not src or "DefaultTexture" in src:
        continue
    if (src, channel) in done:
        result[mi] = done[(src, channel)]
        continue
    tex = unreal.load_asset(src)
    if not isinstance(tex, unreal.Texture2D):
        continue
    fname = "%s_%s_OP.png" % (tex.get_name(), channel)
    try:
        # Eigenschaften über den Editor setzen erzwingt einen synchronen Neubau der Textur (nur im Speicher,
        # nichts wird gespeichert): volle Auflösung, kein virtuelles Streaming → Hilfsmaterial sieht echte Pixel.
        tex.set_editor_property("virtual_texture_streaming", False)
        tex.set_editor_property("never_stream", True)
        tex.set_force_mip_levels_to_be_resident(60.0)
        w = min(tex.blueprint_get_size_x(), 2048)
        h = min(tex.blueprint_get_size_y(), 2048)
        mid = unreal.MaterialLibrary.create_dynamic_material_instance(world, mat_for(channel, tex))
        mid.set_texture_parameter_value("Tex", tex)
        rt = unreal.RenderingLibrary.create_render_target2d(world, w, h, unreal.TextureRenderTargetFormat.RTF_RGBA8)
        unreal.RenderingLibrary.draw_material_to_render_target(world, rt, mid)
        unreal.RenderingLibrary.export_render_target(world, rt, tex_dir, fname)
        done[(src, channel)] = fname
        result[mi] = fname
        unreal.log_warning("OVERLORD maske %s <- %s.%s %dx%d rt %dx%d" % (mi, tex.get_name(), channel, w, h, rt.size_x, rt.size_y))
    except Exception as ex:
        unreal.log_warning("OVERLORD FEHLER %s: %s" % (mi, ex))
json.dump(result, open(os.path.join(out_dir, "opacity.json"), "w"), indent=1)
unreal.log_warning("OVERLORD masken %d" % len(result))
