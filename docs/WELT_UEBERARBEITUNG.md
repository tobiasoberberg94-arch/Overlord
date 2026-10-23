# Welt-Überarbeitung – Stand und Fortschritt

Ziel: eine Welt, in der man stehen bleibt und sich umsieht (siehe Masterprompt des Entwicklers, Oktober 2026).
Dieses Dokument hält fest, was je Ort erledigt ist und was noch offen ist. Stand: 2026-10-23 (Version 2.5.0).

## Gameplay-Bereinigung (erledigt)
- **Herzenskrieg entfernt**: kein Rivalitätswert, keine Eifersucht, keine sieben Rivalitäts-Ereignisse mehr
  (`rv_*`), keine Eifersuchts-Nebenwirkungen bei Lob, Geschenken und Aufträgen, kein Rivalitäts-Meter im HUD.
  Geblieben: Gunst, Stimmung und Erschöpfung, die liebevollen/vernachlässigten Bemerkungen von Albedo und
  Shalltear, die Krönungs- und Schuld-Ereignisse. Errungenschaft „Frieden im Harem“ → „Zwei Herzen“.
  Alte Spielstände werden beim Laden bereinigt (`Game._normalize`).

## Innenräume (System erledigt, zehn Räume)
- Türen in Orten: `data/locations.json` → `doors` [{id, to, name, at, yaw}]; Innenräume sind eigene Orte mit
  `group: "interior"` und `parent`. Schild mit Namen und Laterne an jeder Tür; „Verlassen“ bringt den Spieler vor
  dieselbe Tür zurück. Innenräume werden prozedural gebaut (`scripts/world3d/interiors.gd` – Baukasten und erste
  Räume, `scripts/world3d/interiors_more.gd` – weitere Räume) aus Fotomaterialien und Fotoscan-Requisiten; eigene
  Entdeckungen je Raum (`data/discoveries.json` → `placed`).
- Fertig (E-Rantel): Abenteurergilde (Empfang, Auftragstafel, Schankstube, Büro des Gildenmeisters, Lager,
  Trophäenwand, Rangtafel, Chronik), Gasthaus Goldener Pavillon (Tresen, Kamin, Empore mit Zimmertüren und
  Gästebuch, Zimmer 3 von Momon und Nabe, Gepäck-Versteck), Apotheke Bareare (Tresen mit Waage, Tränke-Regale,
  Kessel, Werkstatt, Hinterzimmer, Nfireas Platz, Geheimvorrat), Schmiede zum Glühenden Amboss (Esse, Amboss,
  Löschtrog, Werkbank, Schwertständer, Erz; Zunftbrief, Auftragstafel, vergessene Klinge), Tempel der Vier Götter
  (Säulenschiff, bunte Fenster, Altar mit Sonnenscheibe, vier Statuen, Priester; Stiftertafel, Schriften,
  Reliquienschrein).
- Fertig (übrige Orte): Enris Haus und Dorfschenke in Carne, Kathedrale der Sechs Götter (Theokratie, Kardinal
  Raymond), Magierakademie von Arwintar (Fluders Studierzimmer mit Beschwörungskreis, Kristall, Sternkarte),
  Schmiedehalle von Feo Jera (drei Essen, Runenpfeiler, Zwerge, Gondo).
- Neue Figuren: Harlan Eisenhand (Schmied), Priester Rolan, Wirtin Marla, Kardinal Raymond, Fluder Paradyne.
  Bewohner-Stile für Innenräume: `priest`, `mage`, `smith`, `dwarf` (`Townsfolk.spawn(..., style)`).
- Offen: Ro-Lente-Schloss und Acht-Finger-Keller in Re-Estize, Kaiserpalast in Arwintar, Hütten der
  Echsenmenschen, Elfenbaumhäuser, Türen in Nazarick (die Ebenen sind bereits begehbare Modelle).

## Proportionen (erledigt)
- Menschen 1,6–1,85 m (vorher ~2,1 m, so groß wie Laternen): `ProcModel.HUMAN = 0.84`. Ainz, Wächter mit Modell und
  Sonderformen unverändert. Sichtfeld der Kamera 54° statt 68° (Häuser wirkten zu klein), Kameraabstand 7 m.

## Entdeckungen und Ausstattung (System erledigt, alle Außenorte ausgestattet)
- Entdeckungen liegen nicht mehr an beliebigen Zufallsplätzen: Inschriften und Schreine stehen frei und sichtbar
  (mindestens 2,5 m Luft, Sicht vom Startpunkt), Verstecke liegen hinter Deckung (Fels, Mauer, Stamm in 1–2,5 m),
  weiter draußen (ab 18 m) und ohne Sicht vom Startpunkt (`QuestWorld._spots` mit mode open/hidden). Von Hand
  gesetzte Entdeckungen je Ort über `placed` in `data/discoveries.json` (kind lore/lectern/plaque/note/spot/cache).
- Ausstattung aus Daten (`data/dressing.json`, `scripts/world3d/dressing.gd`): Banner (Fraktion), Feuerschalen,
  Lagerfeuer (auch erloschen), Statuen, Kisten, Fässer, Zelte, Palisaden, Brunnen, Gedenksteine, Laternenpfähle,
  Heuhaufen, Wäscheleinen, Überfall-Trümmer, Galgen, beliebige Fotoscans, Rauch, Staub, Licht – mit Bedingungen
  (`requires`/`requires_not`), damit Orte sich mit der Geschichte verändern.
- Prüfung: `LOC=dresscheck [DRESSLOCS=ort,ort]` lädt die Orte und meldet jedes Stück, das in einem Gebäude oder
  Fels steckt, keinen Boden unter sich hat oder am Hang steht (`AUSSTATTUNG`-Zeilen). Alle Einträge sind geprüft.

## Umgebungsklänge (erledigt)
- `assets/audio/ambience/<art>.ogg` (17 nahtlose Schleifen à 24 s, prozedural aus `tools/audio/ambience.py`):
  forest, jungle, village, town, cemetery, swamp, lava, glacier, mountain, battlefield, meadow, interior, home,
  hall, tombs, church, forge. Zuordnung je Ortsart in `Audio.AMBIENCE_OF` (ein Ort kann mit `"ambience"` eine
  andere nennen), Überblendung 2,4 s beim Ortswechsel, eigener Regler „Umgebungsklänge“ in den Einstellungen.

## Orte – Prüfung je Ort
| Ort | Identität und Ausstattung | Offen |
|---|---|---|
| E-Rantel | Türen zu Gilde, Gasthaus, Apotheke, Schmiede, Tempel; Lager der Reisenden vor dem Tor, Feuerschalen und Banner am Tor (Königreich → Nazarick nach der Krönung), Brunnen, Laternen, Waren und Wäsche am Markt | Viertel stärker unterscheiden, Stadtmauer-Erlebnis |
| Carne | Enris Haus und Dorfschenke begehbar; Gedenkstein der Überfallnacht, Spuren des Überfalls (Kapitel 1–2), Goblin-Lager mit Palisade ab Kapitel 2, Laternen, Heu, Wäsche | Dorfältester, Goblin-Figuren im Lager |
| Re-Estize | Ro-Lente-Schloss mit Feuerschalen und Bannern, Prachtstraße mit Königsbannern und Statuen, Marktlaternen, Brückenlaternen, Armenviertel südlich des Flusses (Bettlerfeuer, Wäsche, Trümmer, Galgen); nach dem Ende des Königreichs Banner Nazaricks | Schloss und Acht-Finger-Keller begehbar |
| Arwintar | Kaiserpalast mit Feuerschalen und kaiserlichen Bannern (nach dem Pakt daneben Nazaricks), Kaiserstraße mit Statuen, Arena mit Bannern und Händlern, leuchtender Turm der Magierakademie (begehbar: Fluders Studierzimmer), Brunnen, Wohnviertel | Palast begehbar, Arena-Innenraum |
| Theokratie | Tempel der Sechs mit goldenen Feuerschalen, Statuen, Bannern und Lichtstaub (begehbar: Kathedrale), Platzlaternen, Exerzierplatz der Schriften mit Zelten, Richtstätte | Priesterrouten |
| Roble | Tor mit Feuerschalen und Bannern; vor dem Krieg Wachfeuer, in Kapitel 9 Jaldabaoths Lager vor der Mauer (Zelte, Palisaden, Feuer, Banner, brennende Felder), Trümmer des Sturms; nach der Rettung erloschene Feuer, Banner Nazaricks, Gedenkstein; Stadt dahinter mit Feuer, Vorräten, Wäsche | Lager der Flüchtlinge, Neias Posten |
| Katze-Ebene | Lager des Königreichs (Südwesten) und des Kaiserreichs (Osten) mit Bannern, Feuern, Vorräten; Ruine mit Feuerschalen; nach dem Massaker erloschene Feuer, zerschlagene Lager, Blut, die Spur der Dunklen Jungen, violette Flammen und Nazaricks Banner | Nebelgrenze, Untote außerhalb der Mission |
| Azerlisia | Tor von Feo Jera mit Feuerschalen, Laternen, Erzkisten (begehbar: Schmiedehalle), Banner der Zwerge nach dem Bündnis, Lager der Expedition ab Kapitel 8, überfallener Zwergenkarren, Fels und Totholz | Quagoa-Höhle |
| Drachenlande | Sitz des Platin-Drachenlords mit blauen Flammen, Bannern des Rats und kaltem Licht, Asche über dem Drachenskelett, Lager im Süden, Karawane, die einem Drachen begegnete | Drachenhorst |
| Sumpf | Dorf der Echsenmenschen mit Palisade, Stammesbannern, Körben, Reisig; nördliche Siedlung mit Feuer; Irrlichter und Leuchtkäfer; Frost in Kapitel 5; nach dem Krieg Banner Nazaricks und Gedenkstein | Hütten begehbar, Fischgestelle |
| Elfenwald | Lichter der Elfen in den Baumkronen, Blütenstaub, Lager auf der Lichtung, Hinterhalt gegen eine Patrouille der Theokratie, Banner Nazaricks nach dem Elfenkönig | Baumhäuser begehbar |
| Friedhof E-Rantel | Kapelle mit grünem Totenlicht während Khajiits Ritual (Kapitel ≤ 3), danach Feuerschalen; Laternen am Tor und an den Wegen, frisches Grab, Häuser davor | Krypta begehbar |
| Grasland um Nazarick | Mausoleum mit Bannern Nazaricks, violetten Flammen, Statuen und Lichtstaub; Felder der untoten Arbeiter ab Kapitel 3 (Zaun, Heu, Brunnen), Wolfsrevier, Felsen | – |
| Großer Wald von Tob | Hamsukes Revier im Norden, verlassenes Jägerlager, Auras Patrouillenposten ab Kapitel 2 mit Banner Nazaricks, Wolfsbau, Stümpfe, Blütenstaub | – |
| Nazarick-Ebenen | unverändert (eigene Modelle); Umgebungsklang hall/tombs/lava/glacier/jungle | Ausstattung nach Kapitel (Banner, Gäste) |
