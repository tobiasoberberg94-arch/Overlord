# Übergabe – Stand und nächste Schritte

Diese Datei fasst zusammen, was in der bisherigen (Cloud-)Sitzung besprochen und entschieden wurde,
damit eine neue Sitzung – z. B. lokal auf dem PC des Entwicklers – nahtlos weitermachen kann.
**Bitte zuerst diese Datei, dann `README.md` und `docs/ASSET_WUNSCHLISTE.txt` lesen.**

## Über den Entwickler
- Spricht Deutsch; Antworten bitte auf Deutsch, locker und direkt.
- Möchte ein **richtig gutes, „süchtig machendes“ Overlord-Spiel** (Lord of Nazarick-Stimmung,
  Anno/Civ-Verwaltung, Witcher-Kampf, Mass-Effect-Entscheidungen, Albedo-/Shalltear-Rivalität).
- Möchte, dass Claude möglichst **selbstständig** arbeitet (auch Programme am PC bedienen), und am
  Ende einen **Windows-Installer (.exe)**.

## Aktueller Stand (Branch `feature/godot-nazarick`, Version 2.0.0)
- **Godot 4.3**, GDScript, Compatibility-Renderer. Spiel ist **vollständig 3D** (der 2D-Teil wurde
  auf Wunsch komplett entfernt): 3D-Titel, begehbare Welt mit 20 Orten, Third-Person-Kampf
  (Witcher-Stil, Ainz/Momon), Management-Systeme (Aufträge, Regionen, Diplomatie, Legionen,
  Ausbau, Schatzkammer, Wochenziele, Errungenschaften), Story mit 11 Kapiteln + Epilog.
- Figuren und Gebäude sind **prozedural aus Grundformen** gebaut. Echte Modelle (`.glb`) ersetzen sie
  automatisch – siehe README › „3D-Modelle (.glb) einbinden“ und `data/models.json`
  (Animationsnamen, Skalierung). Portraits in Menüs sind 3D-Renders (`PortraitStudio`).
- Tests: `tools/sim_test.tscn` (Strategie, headless), `tools/combat_test.tscn` (Kampf + .glb),
  `tools/world3d_test.tscn` (alle Orte, Screenshots). Build: `tools/build_windows.sh` + NSIS
  (`installer/overlord.nsi`). Der Installer im Ordner `release/` ist noch die alte Version 1.2.0.

## Offene Entscheidung: Engine
- Zur Wahl stehen: **bei Godot bleiben** (Empfehlung bisher – Code bleibt), **Unity** (C#, gut für
  Claude, Neuschreiben nötig) oder **Unreal** (Bundle-Assets sofort nutzbar, aber Blueprints sind
  für Claude schlecht bearbeitbar → nur C++).
- Vorgehen: **zuerst einen Ort testweise nach Godot bringen** (siehe unten) und dann gemeinsam
  entscheiden, ob die Qualität reicht oder ein Umstieg lohnt.

## Gekaufte Assets: Humble „Mega Unreal Engine Bundle“ (30 Umgebungen, Fab-Keys eingelöst)
Fab-Lizenz erlaubt laut Epic die Nutzung in anderen Engines (bitte auf der Fab-Seite der Pakete
gegenprüfen). Die Pakete sind für UE5 (Nanite/Lumen) gebaut → Export als FBX, Polygone reduzieren,
Materialien neu aufsetzen.

| Paket | Geplanter Ort im Spiel (`data/locations.json`) |
|---|---|
| Abandoned Mortuary | `tombs` – Grabkammern Ebene 1–3 (**erster Test**) |
| Medieval Lake Village | `carne` – Dorf Carne (**zweiter Test**) |
| Fantasy Castle | `re_capital`, evtl. `roble` (**dritter Test**) |
| Lost Temple | `treasury` / Thronsaal-Elemente |
| Victorian Grand Mansion | `royal` – Königliche Gemächer |
| Victorian Office | `library` / Ainz' Arbeitszimmer |
| Medieval Fantasy Village, Old Windmills, Flower Meadows | Carne / Umland E-Rantel |
| Artemis Temple | `theokratie` |
| Egyptian Palace | `baharuth` (Arwintar) |
| Ancient Mayan Ruins | `jungle` – Ebene 6 |
| Dragon Graveyard | `drachen`, `katze` |
| Monolith / Fallen City | evtl. `lava` |
Sci-Fi-/Moderne Pakete (Raumschiff, Data Center, Diner …) werden nicht gebraucht.

Einbau-Weg in Godot: ganze Orte als `assets/models/locations/<ort>.glb` mit benannten Ankern
(`Spawn`, `Gate`, `Throne`, `Table`, `Desk`, `Board`, `Keeper`, `Slot1…`) – siehe
`LocationBuilder._from_model`. Einzelne Requisiten als `assets/models/props/<id>.glb`.
Für schwere Szenen ggf. auf den Forward+-Renderer umstellen (PC des Entwicklers hat eine Grafikkarte).

## Figuren: VRoid Studio + Mixamo
- VRoid Studio und ein Mixamo-Account sind vorhanden.
- Plan: **Albedo als erste Testfigur** (weißes Kleid, schwarze lange Haare, Hörner, schwarze Flügel,
  goldene Augen) in VRoid bauen → als VRM/FBX exportieren → Animationen (idle, walk, run, attack,
  dodge, block, hit, death, cast) über Mixamo → als `.glb` nach `assets/models/characters/albedo.glb`.
  Danach Ainz, Momon (`ainz_momon`), Shalltear, die übrigen Wächter, dann Gegner.
- Animationsnamen werden automatisch zugeordnet (`data/models.json → animation_aliases`).

## Nächste Schritte (Reihenfolge)
1. Repo klonen, Godot 4.3 bereitstellen, Spiel einmal starten und Tests laufen lassen.
2. Unreal 5: „Abandoned Mortuary“ öffnen, als FBX exportieren, reduzieren → `tombs.glb` → im Spiel prüfen.
3. Albedo mit VRoid + Mixamo → `albedo.glb` → im Thronsaal und in Audienzen prüfen.
4. Mit dem Entwickler entscheiden: Godot behalten oder Engine wechseln.
5. Windows-Installer neu bauen (Version 2.x) und `release/` aktualisieren.
