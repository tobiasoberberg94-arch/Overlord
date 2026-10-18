"""Unreal: Landschafts-Höhenfeld einer Karte abtasten (Strahl von oben je Rasterpunkt).
  UnrealEditor-Cmd.exe <proj> -run=pythonscript -script="export_terrain.py <map> <ausgabe.json> [raster_m] [max_punkte_je_achse]"
Ergebnis: {"x0","y0","step" (cm, Unreal-Koordinaten), "nx","ny", "h": [Zeilen …] (cm, null = kein Treffer), "textures": [...]}
"""
import json
import sys

import unreal

args = [a for a in sys.argv[1:] if a]
map_path, out = args[0], args[1]
step_m = float(args[2]) if len(args) > 2 else 2.0
cap = int(args[3]) if len(args) > 3 else 600
les = unreal.get_editor_subsystem(unreal.LevelEditorSubsystem)
les.load_level(map_path)
world = unreal.get_editor_subsystem(unreal.UnrealEditorSubsystem).get_editor_world()
eas = unreal.get_editor_subsystem(unreal.EditorActorSubsystem)
lands = [a for a in eas.get_all_level_actors() if "Landscape" in a.get_class().get_name() and "Gizmo" not in a.get_class().get_name()]
if not lands:
    json.dump({"none": True}, open(out, "w"))
    raise SystemExit
lo = [1e18, 1e18, 1e18]
hi = [-1e18, -1e18, -1e18]
for la in lands:
    o, e = la.get_actor_bounds(False)
    for i, k in enumerate("xyz"):
        lo[i] = min(lo[i], getattr(o, k) - getattr(e, k))
        hi[i] = max(hi[i], getattr(o, k) + getattr(e, k))
if len(args) > 7:   # Ausschnitt in Metern (Unreal-Koordinaten): x0 x1 y0 y1
    bx = [float(a) * 100.0 for a in args[4:8]]
    lo[0], hi[0], lo[1], hi[1] = max(lo[0], bx[0]), min(hi[0], bx[1]), max(lo[1], bx[2]), min(hi[1], bx[3])
step = step_m * 100.0
nx = min(cap, int((hi[0] - lo[0]) / step) + 1)
ny = min(cap, int((hi[1] - lo[1]) / step) + 1)
step = max((hi[0] - lo[0]) / max(nx - 1, 1), (hi[1] - lo[1]) / max(ny - 1, 1))
nx = int((hi[0] - lo[0]) / step) + 1
ny = int((hi[1] - lo[1]) / step) + 1
others = [a for a in eas.get_all_level_actors() if a not in lands]
rows, hits = [], 0
for j in range(ny):
    row = []
    y = lo[1] + j * step
    for i in range(nx):
        x = lo[0] + i * step
        h = None
        for la in lands:
            try:
                v = la.get_height_at_location(unreal.Vector(x, y, 0))
                if v is not None:
                    h = float(v)
                    break
            except Exception:
                pass
        if h is None:
            r = unreal.SystemLibrary.line_trace_single(world, unreal.Vector(x, y, hi[2] + 1000), unreal.Vector(x, y, lo[2] - 1000),
                                                       unreal.TraceTypeQuery.TRACE_TYPE_QUERY1, True, others, unreal.DrawDebugTrace.NONE, True)
            if r:
                t = r.to_tuple()
                if t[0]:
                    h = float(t[4].z)
        if h is not None:
            hits += 1
        row.append(None if h is None else round(h, 1))
    rows.append(row)
tex = []
for la in lands:
    try:
        mat = la.get_editor_property("landscape_material")
        base = mat.get_base_material() if isinstance(mat, unreal.MaterialInstance) else mat
        tex += [t.get_path_name() for t in unreal.MaterialEditingLibrary.get_used_textures(base)]
        if isinstance(mat, unreal.MaterialInstance):
            for tp in mat.get_editor_property("texture_parameter_values"):
                v = tp.get_editor_property("parameter_value")
                if v:
                    tex.append(v.get_path_name())
    except Exception as ex:
        unreal.log_warning("OVERLORD material %s" % ex)
json.dump({"x0": lo[0], "y0": lo[1], "step": step, "nx": nx, "ny": ny, "h": rows, "textures": sorted(set(tex))}, open(out, "w"))
unreal.log_warning("OVERLORD gelaende %dx%d schritt %.0f cm treffer %d / %d" % (nx, ny, step, hits, nx * ny))
