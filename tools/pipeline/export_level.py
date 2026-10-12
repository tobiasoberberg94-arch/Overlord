"""Unreal-Editor-Skript: exportiert ein Level als FBX plus Texturen und Materialliste.

Aufruf (headless):
  UnrealEditor-Cmd.exe <projekt.uproject> -run=pythonscript -script="export_level.py <map> <ausgabeordner>"
Ohne Argumente wird die größte .umap unter /Game gewählt und nach <Projekt>/Export geschrieben.
"""
import json
import os
import sys

import unreal

args = [a for a in sys.argv[1:] if a]
asset_reg = unreal.AssetRegistryHelpers.get_asset_registry()


def find_maps():
    maps = asset_reg.get_assets_by_class(unreal.TopLevelAssetPath("/Script/Engine", "World"), True)
    return [str(m.package_name) for m in maps if str(m.package_name).startswith("/Game")]


maps = find_maps()
unreal.log("OVERLORD maps: %s" % maps)
map_path = args[0] if args else None
if not map_path:
    # Showcase-/Demo-Map bevorzugen, sonst die erste
    pref = [m for m in maps if any(k in m.lower() for k in ("showcase", "demo", "overview", "main"))]
    map_path = (pref or maps)[0]
out_dir = args[1] if len(args) > 1 else os.path.join(unreal.Paths.project_dir(), "Export")
tex_dir = os.path.join(out_dir, "textures")
os.makedirs(tex_dir, exist_ok=True)

unreal.log("OVERLORD exportiere %s -> %s" % (map_path, out_dir))
les = unreal.get_editor_subsystem(unreal.LevelEditorSubsystem)
les.load_level(map_path)
world = unreal.get_editor_subsystem(unreal.UnrealEditorSubsystem).get_editor_world()

# --- Level als FBX -----------------------------------------------------------
task = unreal.AssetExportTask()
task.object = world
task.filename = os.path.join(out_dir, "level.fbx")
task.automated = True
task.prompt = False
task.replace_identical = True
task.selected = False
opts = unreal.FbxExportOption()
opts.collision = False
opts.level_of_detail = False
opts.vertex_color = True
opts.export_local_time = False
task.options = opts
ok = unreal.Exporter.run_asset_export_task(task)
unreal.log("OVERLORD level.fbx: %s" % ok)

# --- Materialien -> Texturen ---------------------------------------------------
SLOTS = {
    "basecolor": ("basecolor", "base color", "albedo", "diffuse", "color", "_bc", "_d"),
    "normal": ("normal", "_n"),
    "orm": ("orm", "rma", "arm", "mra", "_mr", "roughness", "_r"),
}


def classify(name):
    n = name.lower()
    for slot, keys in SLOTS.items():
        if any(k in n for k in keys):
            return slot
    return None


exported = {}


def export_tex(tex):
    path = tex.get_path_name()
    if path in exported:
        return exported[path]
    fname = tex.get_name() + ".png"
    t = unreal.AssetExportTask()
    t.object = tex
    t.filename = os.path.join(tex_dir, fname)
    t.automated = True
    t.prompt = False
    t.replace_identical = True
    t.exporter = unreal.TextureExporterPNG()
    if not unreal.Exporter.run_asset_export_task(t):
        t.exporter = unreal.TextureExporterTGA()
        fname = tex.get_name() + ".tga"
        t.filename = os.path.join(tex_dir, fname)
        unreal.Exporter.run_asset_export_task(t)
    exported[path] = fname
    return fname


materials = {}
actors = unreal.get_editor_subsystem(unreal.EditorActorSubsystem).get_all_level_actors()
for actor in actors:
    for comp in actor.get_components_by_class(unreal.StaticMeshComponent):
        for mat in comp.get_materials():
            if not mat or mat.get_name() in materials:
                continue
            entry = {}
            try:
                for p in unreal.MaterialEditingLibrary.get_texture_parameter_names(mat):
                    tex = mat.get_texture_parameter_value(p) if hasattr(mat, "get_texture_parameter_value") else None
                    slot = classify(str(p))
                    if tex and slot and slot not in entry:
                        entry[slot] = export_tex(tex)
            except Exception as e:  # Basismaterial ohne Parameter
                unreal.log_warning("OVERLORD %s: %s" % (mat.get_name(), e))
            if "basecolor" not in entry:
                # Fallback: alle vom Material benutzten Texturen nach Namen einordnen
                base = mat.get_base_material() if isinstance(mat, unreal.MaterialInstance) else mat
                for tex in unreal.MaterialEditingLibrary.get_used_textures(base):
                    slot = classify(tex.get_name())
                    if slot and slot not in entry:
                        entry[slot] = export_tex(tex)
            materials[mat.get_name()] = entry

# Anker-Kandidaten: PlayerStart und Lichter
anchors = {}
for actor in actors:
    loc = actor.get_actor_location()
    cls = actor.get_class().get_name()
    if cls == "PlayerStart":
        anchors["Spawn"] = [loc.x, loc.y, loc.z, actor.get_actor_rotation().yaw]
lights = []
for actor in actors:
    for comp in actor.get_components_by_class(unreal.PointLightComponent):
        l = comp.get_world_location()
        c = comp.get_editor_property("light_color")
        lights.append({"pos": [l.x, l.y, l.z], "color": [c.r, c.g, c.b], "intensity": comp.get_editor_property("intensity"),
                       "radius": comp.get_editor_property("attenuation_radius")})

with open(os.path.join(out_dir, "materials.json"), "w", encoding="utf-8") as f:
    json.dump({"map": map_path, "maps": maps, "materials": materials, "anchors": anchors, "lights": lights}, f, indent=1)
unreal.log("OVERLORD fertig: %d Materialien, %d Texturen, %d Lichter" % (len(materials), len(exported), len(lights)))
