#!/usr/bin/env bash
# Baut die Windows-EXE + PCK (Godot-Export) und den Installer (Inno Setup).
# Voraussetzungen: Godot 4.3 mit Windows-Exportvorlage, Inno Setup 6 (ISCC).
#   GODOT=/pfad/zu/godot ISCC=/pfad/zu/ISCC.exe ./tools/build_windows.sh
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
ISCC="${ISCC:-ISCC.exe}"
mkdir -p build/windows
"$GODOT" --headless --path . --import >/dev/null 2>&1 || true
"$GODOT" --headless --path . --export-release "Windows Desktop" build/windows/OverlordNazarick.exe
"$ISCC" /Q installer/overlord.iss
ls -lh build/windows/ build/OverlordNazarick-Setup-*.exe
