#!/bin/bash
# Wartet auf den jüngsten Mixamo-Download (.tmp/.fbx im Download-Ordner, FBX-Kopf, Größe stabil) und legt ihn ab.
# Aufruf: grab_download.sh <ziel.fbx> [sekunden]
dst=$1; limit=${2:-90}; dl=/c/Users/tobia/Downloads
t=0; last=-1
while [ $t -lt $limit ]; do
  f=$(ls -t "$dl"/*.tmp "$dl"/*.fbx 2>/dev/null | head -1)
  if [ -n "$f" ] && head -c 18 "$f" 2>/dev/null | grep -q "Kaydara FBX"; then
    sz=$(stat -c %s "$f")
    if [ "$sz" = "$last" ] && [ "$sz" -gt 100000 ]; then
      mkdir -p "$(dirname "$dst")"; mv "$f" "$dst" && echo "ABGELEGT $dst ($sz Bytes, $(basename "$f"))"; exit 0
    fi
    last=$sz
  fi
  sleep 3; t=$((t+3))
done
echo "KEIN DOWNLOAD nach $limit s"; ls -t "$dl" | head -3; exit 1
