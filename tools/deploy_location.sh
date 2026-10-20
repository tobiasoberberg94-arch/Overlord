#!/bin/bash
# Ortsmodell aus dem Blender-Bau übernehmen: GLB + Streuliste kopieren, importieren, Texturen auf GPU-Kompression,
# Farbstatistik der neuen Texturen.   tools/deploy_location.sh <id> [quellordner]
set -e
ID=$1
SRC=${2:-/c/Projekte/Overlord/UE}
GODOT=/c/Tools/Godot/Godot_v4.3-stable_win64_console.exe
cd "$(dirname "$0")/.."
cp "$SRC/$ID.glb" assets/models/locations/
[ -f "$SRC/${ID}_scatter.json" ] && cp "$SRC/${ID}_scatter.json" assets/models/locations/
$GODOT --headless --path . --import > /dev/null 2>&1 || true
python -I tools/pipeline/vram_import.py --ue assets/models/locations
$GODOT --headless --path . --import > /dev/null 2>&1 || true
$GODOT --headless --path . --script res://tools/tex_stats.gd 2>&1 | grep "Texturen"
echo "bereit: $ID"
