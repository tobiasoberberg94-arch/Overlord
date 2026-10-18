# Blender: eine mit export_scene.py ausgelesene Unreal-Karte originalgetreu nachbauen.
#   blender -b -P build_scene.py -- <scene-ordner> <kit-ordner> <ziel.glb> [optionen.json]
# Optionen (JSON): {"crop": [x0, x1, y0, y1] (Meter, Blender-Koordinaten), "skip": ["SM_…"], "lod": ["SM_Tree…"],
#                   "nocol": ["SM_Grass…"], "anchors": {"Spawn": [x, y, z, rot], …}, "light_scale": 1.0,
#                   "extra": "modul.py" (Zusatzaufbau mit kit, z. B. Goldberge)}
# Koordinaten: Unreal (cm, linkshändig, Y rechts) → Blender (m, Y gespiegelt): B = F·M·F, Translation × 0,01.
import json
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from loc_kit import Kit  # noqa: E402
from mathutils import Matrix, Vector  # noqa: E402

args = sys.argv[sys.argv.index("--") + 1:]
scene_dir, kit_dir, dst = [os.path.abspath(a) for a in args[:3]]
opt = json.load(open(args[3], encoding="utf-8")) if len(args) > 3 else {}
sc = json.load(open(os.path.join(scene_dir, "scene.json")))
kit = Kit(kit_dir, dst, seed=3)
kit.lod_names = set(opt.get("lod", []))
skip = set(opt.get("skip", []))
nocol = set(opt.get("nocol", []))
crop = opt.get("crop")
F = Matrix.Diagonal((1.0, -1.0, 1.0, 1.0))
have = {os.path.splitext(f)[0] for f in os.listdir(os.path.join(kit_dir, "meshes"))}


def to_blender(rows):
    # Unreal speichert Zeilenvektoren (p' = p·M, Translation in der 4. Zeile) → transponieren
    m = Matrix(rows).transposed()
    m[0][3] *= 0.01
    m[1][3] *= 0.01
    m[2][3] *= 0.01
    return F @ m @ F


tp = os.path.join(scene_dir, "terrain.json")
if opt.get("terrain") and os.path.exists(tp):
    tt = json.load(open(tp))
    if not tt.get("none"):
        kit.heightfield(tt, opt["terrain"]["tex"], opt["terrain"].get("normal"), tile=opt["terrain"].get("tile", 4.0))

placed = missing = 0
miss = {}
thin = opt.get("thin", {})          # {"SM_GrassV1": 0.1} → nur jede n-te Instanz behalten
cnt = {}
seen = set()
for p in sc["placements"]:
    name = p["mesh"].split(".")[-1]
    if name in skip:
        continue
    if name in thin:
        cnt[name] = cnt.get(name, 0) + 1
        if (cnt[name] * 0.6180339) % 1.0 > thin[name]:
            continue
    if name not in have:
        miss[name] = miss.get(name, 0) + 1
        missing += 1
        continue
    mw = to_blender(p["m"])
    t = mw.to_translation()
    key = (name, round(t.x, 2), round(t.y, 2), round(t.z, 2))
    if key in seen:                      # doppelt exportierte Komponenten
        continue
    seen.add(key)
    if crop and not (crop[0] <= t.x <= crop[1] and crop[2] <= t.y <= crop[3]):
        continue
    # Foliage-Instanzen (ISM/HISM) und kleine Deko ohne Kollision → GPU-Instancing
    small = max(kit.size(name) * mw.to_scale().x) < 0.6
    kit.place(name, mw, nocol=name in nocol or (p.get("foliage") and name not in kit.lod_names) or (small and name not in kit.lod_names))
    placed += 1
print("OVERLORD platziert", placed, "fehlend", missing, sorted(miss.items(), key=lambda kv: -kv[1])[:12])

# Lichter (Unreal-Candela → grobe Blender-Watt; Godot normiert die Stärke ohnehin)
ls = float(opt.get("light_scale", 1.0))
n = 0
for l in sc["lights"]:
    if l["kind"] in ("DirectionalLightComponent", "SkyLightComponent"):
        continue
    pos = Vector((l["pos"][0] * 0.01, -l["pos"][1] * 0.01, l["pos"][2] * 0.01))
    if crop and not (crop[0] <= pos.x <= crop[1] and crop[2] <= pos.y <= crop[3]):
        continue
    col = opt.get("light_color", l["color"])
    kit.light(l["kind"], pos, col, min(2000.0, max(5.0, l.get("intensity", 10) * 2.0 * ls)))
    n += 1
print("OVERLORD lichter", n)

# Anker: PlayerStart der Karte oder vorgegeben
anchors = opt.get("anchors", {})
if sc.get("spawn") and "Spawn" in anchors and len(anchors["Spawn"]) > 3 and anchors["Spawn"][3] is None:
    anchors["Spawn"][3] = -sc["spawn"]["yaw"] - 90            # Blickrichtung des Unreal-PlayerStart übernehmen
if "Spawn" not in anchors and sc.get("spawn"):
    s_ = sc["spawn"]
    anchors["Spawn"] = [s_["pos"][0] * 0.01, -s_["pos"][1] * 0.01, s_["pos"][2] * 0.01, -s_["yaw"] - 90]
for k, v in anchors.items():
    z = v[2] if len(v) > 2 and v[2] is not None else None        # None → Bodenhöhe
    kit.empty(k, v[0], v[1], z, rot=v[3] if len(v) > 3 else 0.0)

if opt.get("extra"):
    ns = {"kit": kit, "Vector": Vector, "Matrix": Matrix, "math": math, "opt": opt}
    exec(open(os.path.join(os.path.dirname(os.path.abspath(__file__)), opt["extra"]), encoding="utf-8").read(), ns)

kit.finish_materials(metal_keys=tuple(opt.get("metal", ())))
kit.export()
