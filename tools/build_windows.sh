#!/usr/bin/env bash
# Baut die Windows-EXE (Godot-Export) und den Installer (NSIS).
# Voraussetzungen: Godot 4.3 mit Windows-Exportvorlage, makensis (NSIS).
#   GODOT=/pfad/zu/godot ./tools/build_windows.sh
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
mkdir -p build/windows
"$GODOT" --headless --path . --import >/dev/null 2>&1 || true
"$GODOT" --headless --path . --export-release "Windows Desktop" build/windows/OverlordNazarick.exe
makensis -V2 installer/overlord.nsi
ls -lh build/windows/OverlordNazarick.exe build/OverlordNazarick-Setup-*.exe
