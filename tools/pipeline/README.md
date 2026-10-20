# Asset-Pipeline (Unreal/Fab → Godot, Figuren → Mixamo → Godot)

Werkzeuge: Blender 4.2 (`blender -b -P <skript> -- …`), Unreal 5.7 (`UnrealEditor-Cmd.exe`).

**Ort aus einem Fab-Paket**
1. Paket im Unreal-Editor über das Fab-Fenster in ein Projekt holen.
2. `UnrealEditor-Cmd.exe <proj>.uproject -run=pythonscript -script="export_level.py /Game/<Pfad>/<Map> <Export-Ordner>" -unattended -NullRHI`
   → `level.fbx`, `textures/`, `materials.json`
3. `blender -b -P build_tombs.py -- <Export-Ordner> <ort>.glb` (Materialien, Reduktion, Anker Spawn/Gate/Keeper/Slot)
4. `<ort>.glb` nach `assets/models/locations/`.

**Figur**
Das Modell muss in **T- oder A-Pose** stehen (Arme vom Körper weg), sonst kann Mixamo es nicht riggen.
1. Je nach Modell:
   - mehrere Meshes/eigene Texturen (z. B. Albedo): `blender -b -P prep_mixamo.py -- <modell.fbx> <texturordner> <figur>_mixamo.fbx`
   - KI-Modell mit einem Mesh + `Material_01_{BaseColor,Normal,Roughness,Metallic}.png` (z. B. Demiurge):
     `blender -b -P prep_mixamo_pbr.py -- <modell.fbx> <texturordner> <figur>_mixamo.fbx [hoehe_m] [dreiecke]`
     (reduziert auf 40.000 Dreiecke, Texturen 2K).
   - Meldet Mixamo „unable to map your existing skeleton“, stattdessen ein ZIP aus OBJ + MTL + BaseColor hochladen
     (Blender: OBJ-Export, Y-oben). Mixamo liest OBJ als Zentimeter – `build_character.py` korrigiert das automatisch.
2. In Mixamo hochladen, Marker setzen; `idle` **mit** Skin, weitere Animationen **ohne** Skin (walk/run „In Place“)
   als `idle, walk, run, attack_light, attack_heavy, dodge, block, hit, death, cast .fbx` in einen Ordner.
3. `blender -b -P build_character.py -- <animationsordner> <texturordner> <figur>.glb`
   (Texturordner: `badan/mata.png` oder `*_basecolor/_normal/_roughness/_metallic`)
4. `<figur>.glb` nach `assets/models/characters/`, ggf. `scale` in `data/models.json`.

`preview.py` rendert Kontrollbilder, `inspect_fbx.py` zeigt Kennzahlen eines FBX.

**Orte mit Baukästen (Stand Oktober 2026)**
- `loc_kit.py` (Kit): Bauteile setzen, Gelände (`height_field`/`terrain` mit Weg- und Hofmaske), Streulisten,
  `kit.ph(modell, x, y)` = Markierung für Poly-Haven-Fotoscans (im Spiel `PhProps.spawn_markers`).
  `Kit(..., extra_dirs=[…])` sucht Bauteile in mehreren Kit-Ordnern.
- `town_kit.py` (Town): Belegungsraster, Häuserzeilen Wand an Wand mit Gassen und Hinterhöfen, Marktstände,
  Wirtshäuser, Stadtmauern, `great_wall`, `colosseum`, `palisade` mit Wachtürmen, `outskirts`, `anchors`,
  `save_map` (Kontrollbild `<ort>_map.png`).
- `struct_kit.py` (Structs): Grüfte, Friedhofsmauern, Eisengitter, Gräber, Pfahlhütten, Stege, Totems,
  Zwergentor, Stollen, Riesenbäume mit Plattformen/Pavillons/Hängebrücken/Wendeltreppen, Höhleneingang.
  Materialnamen `MI_…` werden im Spiel durch Fotomaterialien ersetzt (`scripts/world3d/building_look.gd`).
- Bauen: `blender -b -P build_<ort>.py -- <Kit-Ordner> C:/Projekte/Overlord/UE/<ort>.glb`
- Übernehmen: `tools/deploy_location.sh <ort>` (kopiert GLB + Streuliste, importiert, stellt Texturen mit
  `vram_import.py --ue` auf GPU-Kompression um, aktualisiert `data/tex_stats.json`).
- Prüfen: `LOC=<ort> SHOTCAM="@x,-h,z,tx,-th,tz;…" godot res://tools/world3d_test.tscn` → `tools/screenshots3d/`.
