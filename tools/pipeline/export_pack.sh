#!/bin/bash
# Unreal-Szene + benutzte Meshes + Transparenzmasken in einem Rutsch exportieren.
#   bash export_pack.sh <map, z. B. /Game/Egyptian_Palace/Level/L_showcase_level> <name> [extra Content-Ordner für alle Meshes]
# Ergebnis: UE/Scene_<name>/scene.json und UE/<name>Kit (meshes, textures, materials.json mit opacity)
set -e
MAP="$1"; NAME="$2"; ALL="$3"
UE=/c/Projekte/Overlord/UE
U="/c/Games/UE_5.7/Engine/Binaries/Win64/UnrealEditor-Cmd.exe"
P="C:/Projekte/Overlord/UE/Mortuary/Mortuary.uproject"
T="C:/Projekte/Overlord/repo/tools/pipeline"
W="C:/Projekte/Overlord/UE"
"$U" "$P" -run=pythonscript -script="$T/export_scene.py $MAP $W/Scene_$NAME" -unattended -nop4 -nosplash -AllowCommandletRendering > $UE/scene_$NAME.log 2>&1
grep "LogPython: Warning: OVERLORD szene" $UE/scene_$NAME.log | head -1
L=$(cat $UE/Scene_$NAME/meshes.txt)
if [ -n "$ALL" ]; then
  L="$L $(cd $UE/Mortuary/Content && find $ALL -name 'SM_*.uasset' | sed 's/.uasset//; s#^#/Game/#' | tr '\n' ' ')"
fi
L=$(echo $L | tr ' ' '\n' | sort -u | tr '\n' ' ')
"$U" "$P" -run=pythonscript -script="$T/export_meshes.py $W/${NAME}Kit $L" -unattended -nop4 -nosplash -AllowCommandletRendering > $UE/kit_$NAME.log 2>&1
ROOTS=$(echo $L | tr ' ' '\n' | awk -F/ 'NF>3 {print "/"$2"/"$3}' | sort -u | tr '\n' ' ')
"$U" "$P" -run=pythonscript -script="$T/dump_mat_params.py $W/mat_params_$NAME.json $ROOTS" -unattended -nop4 -nosplash > $UE/dump_$NAME.log 2>&1
"$U" "$P" -run=pythonscript -script="$T/export_opacity.py $W/mat_params_$NAME.json $W/${NAME}Kit" -unattended -nop4 -nosplash -AllowCommandletRendering > $UE/opacity_$NAME.log 2>&1
cd $UE && python - "$NAME" <<'EOF'
import json, sys, os, shutil
n = sys.argv[1]
kit = n + "Kit"
op = json.load(open(os.path.join(kit, "opacity.json"))) if os.path.exists(os.path.join(kit, "opacity.json")) else {}
d = json.load(open(os.path.join(kit, "materials.json")))
for m, e in d["materials"].items():
    if m in op:
        e["opacity"] = op[m]
json.dump(d, open(os.path.join(kit, "materials.json"), "w"), indent=1)
print("KIT", n, "meshes", len(os.listdir(os.path.join(kit, "meshes"))), "materialien", len(d["materials"]), "masken", len(op))
EOF
