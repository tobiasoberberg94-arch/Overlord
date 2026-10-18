#!/bin/bash
# Gelände im Bereich der Platzierungen (+Rand) abtasten: bash terrain_all.sh <map> <name> [raster_m] [rand_m]
UE=/c/Projekte/Overlord/UE
STEP=${3:-1.0}; PAD=${4:-40}
B=$(cd $UE && python -c "
import json;s=json.load(open('Scene_$2/scene.json'))
xs=sorted(p['m'][3][0]*.01 for p in s['placements'] if not p.get('foliage')); ys=sorted(p['m'][3][1]*.01 for p in s['placements'] if not p.get('foliage'))
q=len(xs)//100
print(xs[q]-$PAD, xs[-q-1]+$PAD, ys[q]-$PAD, ys[-q-1]+$PAD)")
"/c/Games/UE_5.7/Engine/Binaries/Win64/UnrealEditor-Cmd.exe" "C:/Projekte/Overlord/UE/Mortuary/Mortuary.uproject" -run=pythonscript -script="C:/Projekte/Overlord/repo/tools/pipeline/export_terrain.py $1 C:/Projekte/Overlord/UE/Scene_$2/terrain.json $STEP 700 $B" -unattended -nop4 -nosplash -AllowCommandletRendering > $UE/terr_$2.log 2>&1
grep "LogPython: Warning: OVERLORD gelaende" $UE/terr_$2.log | head -1
