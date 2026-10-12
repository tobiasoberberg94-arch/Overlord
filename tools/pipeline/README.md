# Asset-Pipeline (Unreal/Fab → Godot, Figuren → Mixamo → Godot)

Werkzeuge: Blender 4.2 (`blender -b -P <skript> -- …`), Unreal 5.7 (`UnrealEditor-Cmd.exe`).

**Ort aus einem Fab-Paket**
1. Paket im Unreal-Editor über das Fab-Fenster in ein Projekt holen.
2. `UnrealEditor-Cmd.exe <proj>.uproject -run=pythonscript -script="export_level.py /Game/<Pfad>/<Map> <Export-Ordner>" -unattended -NullRHI`
   → `level.fbx`, `textures/`, `materials.json`
3. `blender -b -P build_tombs.py -- <Export-Ordner> <ort>.glb` (Materialien, Reduktion, Anker Spawn/Gate/Keeper/Slot)
4. `<ort>.glb` nach `assets/models/locations/`.

**Figur**
1. `blender -b -P prep_mixamo.py -- <modell.fbx> <texturordner> <figur>_mixamo.fbx` (1,75 m, Blick nach vorne, Texturen eingebettet)
2. In Mixamo hochladen, Marker setzen; `idle` **mit** Skin, weitere Animationen **ohne** Skin (walk/run „In Place“)
   als `idle, walk, run, attack_light, attack_heavy, dodge, block, hit, death, cast .fbx` in einen Ordner.
3. `blender -b -P build_character.py -- <animationsordner> <texturordner> <figur>.glb`
4. `<figur>.glb` nach `assets/models/characters/`, ggf. `scale` in `data/models.json`.

`preview.py` rendert Kontrollbilder, `inspect_fbx.py` zeigt Kennzahlen eines FBX.
