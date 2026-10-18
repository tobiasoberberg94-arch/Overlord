"""Unreal: eine Karte als Platzierungsliste exportieren (statt eines riesigen Level-FBX).

  UnrealEditor-Cmd.exe <proj> -run=pythonscript -script="export_scene.py <map> <ausgabeordner>" -AllowCommandletRendering

Ergebnis in <ausgabe>/:
  scene.json      – je Platzierung: Mesh-Pfad, Weltmatrix (UE, cm, Zeilen), Material-Overrides; Foliage-/ISM-Instanzen einzeln
                    dazu Lichter (Punkt/Spot/Rect/Richtung), PlayerStart, Höhenbereich
  landscape.fbx   – Landschaft(en) als Mesh (falls vorhanden)
  meshes.txt      – alle benutzten Static Meshes (für export_meshes.py)
"""
import json
import os
import sys

import unreal

args = [a for a in sys.argv[1:] if a]
map_path, out_dir = args[0], args[1]
os.makedirs(out_dir, exist_ok=True)
les = unreal.get_editor_subsystem(unreal.LevelEditorSubsystem)
les.load_level(map_path)
eas = unreal.get_editor_subsystem(unreal.EditorActorSubsystem)
actors = eas.get_all_level_actors()


def mat_rows(t):
    m = t.to_matrix()
    return [[m.x_plane.x, m.x_plane.y, m.x_plane.z, m.x_plane.w],
            [m.y_plane.x, m.y_plane.y, m.y_plane.z, m.y_plane.w],
            [m.z_plane.x, m.z_plane.y, m.z_plane.z, m.z_plane.w],
            [m.w_plane.x, m.w_plane.y, m.w_plane.z, m.w_plane.w]]


placements, meshes, lights, landscapes = [], set(), [], []
spawn = None
for a in actors:
    cls = a.get_class().get_name()
    if cls == "PlayerStart":
        spawn = {"pos": [a.get_actor_location().x, a.get_actor_location().y, a.get_actor_location().z],
                 "yaw": a.get_actor_rotation().yaw}
    if "Landscape" in cls:
        landscapes.append(a)
        continue
    if a.is_hidden_ed() if hasattr(a, "is_hidden_ed") else False:
        continue
    for comp in a.get_components_by_class(unreal.StaticMeshComponent):
        sm = comp.get_editor_property("static_mesh")
        if not sm or not comp.is_visible():
            continue
        path = sm.get_path_name()
        mats = []
        for i in range(comp.get_num_materials()):
            m = comp.get_material(i)
            mats.append(m.get_name() if m else "")
        if isinstance(comp, unreal.InstancedStaticMeshComponent):
            n = comp.get_instance_count()
            for i in range(n):
                t = comp.get_instance_transform(i, True)
                placements.append({"mesh": path, "m": mat_rows(t), "mats": mats, "foliage": True})
        else:
            placements.append({"mesh": path, "m": mat_rows(comp.get_world_transform()), "mats": mats,
                               "foliage": False, "actor": a.get_actor_label()})
        meshes.add(path.split(".")[0])
    for comp in a.get_components_by_class(unreal.LightComponent):
        if not comp.is_visible():
            continue
        l = comp.get_world_location()
        c = comp.get_editor_property("light_color")
        kind = comp.get_class().get_name()
        e = {"kind": kind, "pos": [l.x, l.y, l.z], "color": [c.r / 255.0, c.g / 255.0, c.b / 255.0],
             "intensity": comp.get_editor_property("intensity")}
        if hasattr(comp, "attenuation_radius"):
            try:
                e["radius"] = comp.get_editor_property("attenuation_radius")
            except Exception:
                pass
        r = comp.get_world_rotation()
        e["rot"] = [r.roll, r.pitch, r.yaw]
        lights.append(e)

# Landschaft(en) als FBX
if landscapes:
    eas.set_selected_level_actors(landscapes)
    task = unreal.AssetExportTask()
    task.object = unreal.get_editor_subsystem(unreal.UnrealEditorSubsystem).get_editor_world()
    task.filename = os.path.join(out_dir, "landscape.fbx")
    task.automated = True
    task.prompt = False
    task.replace_identical = True
    task.selected = True
    opts = unreal.FbxExportOption()
    opts.collision = False
    opts.level_of_detail = False
    task.options = opts
    ok = unreal.Exporter.run_asset_export_task(task)
    unreal.log_warning("OVERLORD landschaft %s (%d)" % (ok, len(landscapes)))
    # Landschaftsmaterial: Texturparameter merken (für die Bodentextur)
    lm = []
    for la in landscapes:
        try:
            mat = la.get_editor_property("landscape_material")
            if mat:
                for t in unreal.MaterialEditingLibrary.get_used_textures(mat.get_base_material() if isinstance(mat, unreal.MaterialInstance) else mat):
                    lm.append(t.get_path_name())
        except Exception as ex:
            unreal.log_warning("OVERLORD landschaftsmaterial: %s" % ex)
else:
    lm = []

json.dump({"map": map_path, "spawn": spawn, "placements": placements, "lights": lights, "landscape_textures": sorted(set(lm))},
          open(os.path.join(out_dir, "scene.json"), "w"), indent=0)
open(os.path.join(out_dir, "meshes.txt"), "w").write(" ".join(sorted(meshes)))
unreal.log_warning("OVERLORD szene %d platzierungen, %d meshes, %d lichter, landschaft %d" %
                   (len(placements), len(meshes), len(lights), len(landscapes)))
