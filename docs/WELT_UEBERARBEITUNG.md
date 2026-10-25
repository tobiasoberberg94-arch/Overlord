# Welt-Überarbeitung – Stand und Fortschritt

Ziel: eine Welt, in der man stehen bleibt und sich umsieht (siehe Masterprompt des Entwicklers, Oktober 2026).
Dieses Dokument hält fest, was je Ort erledigt ist und was noch offen ist. Stand: 2026-10-25 (Version 2.15.0).

## Spieltest 2.13 – Nazarick (erledigt, Version 2.15)
Mängelliste und Abhakstand je Ort: `docs/SPIELTEST_2_13.md`. In 2.15 erledigt:
- **Partikel und Licht**: Flammen als Flammenzungen-Shader, Funken und Glut als weiche Punkte, Rauch aus weichen
  Wolken (Rauch-Atlas, beleuchtet), keine Quadrate mehr (Partikel-Billboards behalten ihre Größe); das Vorwärmen
  der Kampfeffekte nach jeder Ankunft ist unsichtbar (vorher flogen weiße Funken durchs Bild).
- **Treppenportale und Gate**: Treppenabgänge statt schwebender Laternen, im Stil der Ebene (schwarzer Marmor mit
  Gold; Gletscher bereifter Fels mit Schneekappen; Dschungel Moosstein; Lava Basalt); Ankunft 3,4 m vor dem Portal;
  Königliche Gemächer nutzen die Doppeltüren des Modells mit Namensschild (Türstil `nameplate`); Gate als Portal
  aus wirbelnder Finsternis. Ankunftspunkte werden auf den Boden gesetzt (Schatzkammer: steckte in der Treppe).
- **Gletscher**: Modell neu gebaut (`build_glacier.py`): ebener Tempelplatz, Krone aus Eiskristallen statt
  schwarzer Plattenwand, Löwe und Zierpodest entfernt, Statuen vereinfacht (Ladezeit 8,7 → 5,4 s); Fichten mit
  Schnee im Laubmaterial (kein Flackern), Eis mit Felsstruktur, See mit Verwehungen, keine Lichtsäulen mehr;
  Cocytus bleibt auf seinem Posten.
- **Lava**: Platzhalterflächen über der Lava entfernt, Lava-Shader mit Krustenschollen und glühenden Rissen,
  Feuerschalen mit glimmenden Kohlen.
- **Bibliothek**: Eingangswand geschlossen, durchgehender Läufer statt verstreuter Teppiche (`build_library.py`,
  Ausstattung `rug`).
- **Entdeckungen**: feste Plätze und passende Gestalt (`discoveries.json` → dritter Eintrag `{"vis", "at", "yaw"}`):
  Gefrorener Todesritter im Eisblock, Schneekugel, Bäumchen mit Schild, Hinweistafeln am Weg, Särge mit Kerzen,
  Lesepult, Notiz auf dem Lesetisch, Bartisch, Warnschild; Wandtafeln nur noch an Wänden über Kopfhöhe.
  Fundstellen je Ort lenkbar (`locations.json` → `spots`: Suchmitten und Sperrkreise, z. B. nicht in der Arena).
- **Prüfwerkzeuge** (`tools/world3d_test.gd`): `LOC=mats` (Materialien je Fläche), `LOC=actors` (Figuren, Blick),
  `LOC=walk` (Lauftest, Absturz), `LOC=parts` (alle Partikel), `MESHNAME=` (Meshes nach Namen), `HIDE=` und
  `PROBEMATS=` für Aufnahmen, `RAYS` mit Höhe.

## Gameplay-Bereinigung (erledigt)
- **Herzenskrieg entfernt**: kein Rivalitätswert, keine Eifersucht, keine sieben Rivalitäts-Ereignisse mehr
  (`rv_*`), keine Eifersuchts-Nebenwirkungen bei Lob, Geschenken und Aufträgen, kein Rivalitäts-Meter im HUD.
  Geblieben: Gunst, Stimmung und Erschöpfung, die liebevollen/vernachlässigten Bemerkungen von Albedo und
  Shalltear, die Krönungs- und Schuld-Ereignisse. Errungenschaft „Frieden im Harem“ → „Zwei Herzen“.
  Alte Spielstände werden beim Laden bereinigt (`Game._normalize`).

## Innenräume (System erledigt, fünfzehn Räume)
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
- Version 2.6: Thronsaal von Ro-Lente (Re-Estize, oben an der Schlossrampe; König Ranpossa III., Gazef) und
  Audienzsaal des Kaisers (Arwintar; Jircniv) – ein gemeinsamer Raumtyp `court` mit Fraktionsfarben, Wachen im
  Wappenrock, Adligen, Kriegstisch, Podest mit Thron und Baldachin.
- Nazarick: Treppen und Tore zwischen den Ebenen als Türen (Ankunft vor der Gegentür), Abstieg vom Mausoleum im
  Grasland in die Grabkammern.
- Version 2.7: Keller der Acht Finger (Re-Estize, Kellerluke im Armenviertel beim Bettlerfeuer) als erster Kerker – Pfeiler, Fackeln,
  Käfige mit Gefangenem, Zähltisch, Schmuggelware; Gegner über `encounters` des Innenraums (Schläger, Armbrustschützen,
  Söldner); Schuldbuch, Liste der Schutzgelder, Kasse.
- Version 2.8: Kanalisation von E-Rantel (`sewer`: Wasserrinne, Bögen, Gitter, Schleim, Gebeine, Kultaltar der Zurrernon) und
  Gruft der Gefallenen (`crypt`: Säulenhalle, Sarkophage, kalte Feuerschalen, Podest des Generals) als Verliese hinter
  verschlossenen Türen; Steingewölbe-Baukasten `InteriorsMore._vault`, Gebeine `_bones`. Begrenzung langer Räume
  (`B3.bounds` mit der größeren Halbseite) korrigiert.
- Offen: Hütten der Echsenmenschen, Elfenbaumhäuser.

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

## Dorfbewohner-Modelle (erledigt, Version 2.10)
- Die Holzpuppen sind Geschichte: `tools/pipeline/build_villager.py` baut um Demiurges Mixamo-Skelett zwei stilisierte Körper
  (`villager_m.glb`, `villager_f.glb`) mit Gesicht, Frisuren, Bart, Hüten, Helm, Krone, Brille, Brustpanzer, Schürze, Wappenrock,
  Umhang und Rock als schaltbare Knoten; alle Clips des Spenders (Stehen, Gehen, Laufen, Treffer, Tod, Ausweichen, Block, Angriffe,
  Zauber) sind enthalten. `scripts/world3d/villager_look.gd` färbt die Materialien je Figur und blendet die Teile ein.
- Bewohner aller Stile (`Townsfolk`: Dorf, Abenteurer, Wachen, Priester, Magier, Schmiede, Zwerge, Dienstmädchen, Adlige, Händler;
  Frauen/Männer je Stil unterschiedlich häufig, Frisuren und Kleider passend) und alle Menschen aus `data/figures.json` ohne
  eigenes Modell tragen sie automatisch (`ProcModel.model_of`); eigenes GLB hat Vorrang, Sonderformen bleiben prozedural.
  Neues Feld `female` in `figures.json`, wo Kleid oder Hose das Geschlecht nicht verraten (Neia, Clementine, Priester, Fluder …).
- Gebäude werden um ihren Bodenursprung skaliert (vorher hob die Hüllen-Unterkante vergrabener Fundamente Häuser bis 0,55 m an);
  Prüfmodus `LOC=buildings`. Dunkles Junges brüllt genau einmal je Brüllen.
- Version 2.11: neun Mixamo-Clips (Reden, Streiten, Klatschen, Jubeln, Winken, Beten, Sitzen, Sitzen-Reden, Trinken; über Sebas'
  Rig ohne Skin geladen, `Models/Sebas/mixamo_civil`) sind auf das Bewohner-Rig übertragen: Gesprächsgruppen reden und streiten,
  Wartende winken, klatschen, jubeln, Priester beten, Magier und Adlige reden, beim Sprechen wird gestikuliert
  (`Townsfolk._idle_clip`, `CharacterRig.play_extra`). Solution und Sebas sind echte Mixamo-Modelle (`solution.glb`, `sebas.glb`).
- Version 2.12: menschliche Gegner (`"model": "soldier"`: Soldaten, Söldner, Banditen, Abenteurer, Gagaran, Brain, Decem, Acht Finger,
  Schrift-Bogenschützen, Sonnenlicht-Zauberer, Zurrernorn-Kultisten und -Priester) tragen das Bewohner-Modell mit Rüstung, Helm,
  Wappenrock, Umhang, Robe und neuer Kapuze; Kampfclips aus dem Rig (`VillagerLook.enemy_spec`, Prüfmodus `LOC=enemies`).
- Version 2.13: Kinder mit eigenen Proportionen (`villager_c.glb`, 18 % der Dorfbewohner, Figuren mit `scale` < 0,7 wie Nemu) und
  sitzende Gäste an den Wirtshaustischen (Gilde, Gasthaus: Sitzen, Plaudern, Trinken; fliehen nicht, drehen sich nicht weg).
- Version 2.14: drittes Verlies **Mausoleum der Zurrernon** unter dem Friedhof von E-Rantel (`kind: mausoleum`, Baukasten in
  `interiors_more.gd`): Schädelnischen, Totenspirale mit Kerzenkreis, Käfige, violette Feuerschalen, Altar mit der Todesperle.
  Schlüssel als Gegnerbeute (`drops_key` beim Priester der Zurrernon in der Kanalisation), Bosse Khajit und Clementine, Truhe
  „Khajits Vermächtnis“, Errungenschaft „Herr der Spirale“, drei Entdeckungen. Prüfmodus `LOC=mausoleum`.
- Offen: Gäste auch in der Dorfschenke und den Bänken; die übrigen elf Mixamo-Figuren (ZIP-Uploads durch den Nutzer).

## Testmodus und Größen (erledigt, Version 2.9)
- Titelbild „Testwelt (alles frei)“ (`Game.unlock_everything`: letztes Kapitel, alle Wächter, alle Gegenden erkundet, alle
  Kapitel-Momente als Erinnerung, 5000 Gold) und Pausenmenü „🧪 Testmodus“ (`World3D._test_menu`: Testreise zu jedem Ort,
  Gegner beschwören, Story-Einsatz starten, Tageszeit, Wetter, Heilen, Alles freischalten). Prüfung `LOC=testmenu`.
- Größen nach Serienmaßstab: Gebäude der Baukästen beim Laden 30 % höher (`LocationBuilder._enlarge_buildings`),
  Todesritter 1,4 (Höhe 3,0), Hamsuke 1,6, Skelettdrache 1,35 (Höhe 3,3), Dunkles Junges 13 m.
- Echte Modelle aus Tripo (Oktober 2026): Hamsuke, Wolf, Skelettdrache, Victim, Dunkles Junges, Maske, Frost Pain;
  13 Figuren für Mixamo vorbereitet (siehe README › 3D-Modelle).

## Verliese und Schlüssel (erledigt, Version 2.8)
- Türen mit `key` (Beutelgegenstand) bleiben verschlossen (Aufforderung „Verschlossen“, Hinweis `hint`), bis der Schlüssel im
  Beutel liegt; einmal aufgeschlossen (Flagge `unlocked_<ziel>`, Zähler `unlocked`) bleiben sie offen. Eingänge mit
  `style: grate` (Kanalgitter im Boden) oder `crypt` (Portal mit Schädeln) statt Wirtshausschild (`World3D._dungeon_entrance`).
- Schlüssel als Entdeckungen (`placed`, `kind: "key"`, `item`): Pickup-Art `key` (Sockel mit drehendem Schlüssel), Text beim
  Nehmen, einzigartige Beutelgegenstände (`data/quests.json` → `materials`, `unique` → unverkäuflich). Entdeckungen im
  Freien werden jetzt auf den Boden gesetzt (`World3D._on_ground`).
- Kette: Friedhof von E-Rantel (Schlüssel aus dem Mausoleum, beim Ältesten Leichnam) → Kanalgitter E-Rantel (30, 28) →
  Kanalisation (Skelette, Kultisten, Priester der Zurrernon; Zeichen, Khajits Aufzeichnungen, Opfergaben, Siegel der
  Gefallenen auf dem Altar → Zähler `dungeons`) → Gruftportal Katze-Ebene (20, 16) → Gruft der Gefallenen (Skelette,
  Schützen, General der Gefallenen: Boss mit Phasen und Beschwörungen; nach dem Sieg Flagge `gruft_general`, Schatz des
  Generals mit legendärem Stück, Zähler `dungeon_bosses`, kein Wiedererscheinen).
- Neue Gegner (`data/combat.json`): `zurrernorn_cultist`, `zurrernorn_priest`, `fallen_general`. Errungenschaften:
  Unter der Stadt, Bezwinger der Gruft, Schlüsselmeister. Test: `LOC=dungeon`.
- Offen: weitere Verliese (Khajits Mausoleum als eigener Raum, Schmugglerstollen unter Re-Estize), Schlüssel als Beute von Gegnern.

## Feinschliff (erledigt, Version 2.8)
- Fotomodus `scripts/world3d/photo_mode.gd` (F9 / Pausenmenü / Controller): freie Kamera, Welt hält an (`cinematic`), HUD aus,
  Filter über `Environment.adjustment_*`, Foto nach `user://screenshots/`, Steuerung mit Maus/Tastatur und Controller.
- Schritte (`Player3D._footsteps`): Untergrund aus Ortsart, Gruppe, Wetter und Strahl auf den Boden (Fotoscan/SM_/Straße →
  Stein); `step_<stone|grass|wood|snow|sand>_1..3.ogg` aus `tools/audio/ambience.py steps`; Fußspuren (Quads) in Schnee
  und Sand, höchstens 60, verblassen nach 18 s. Test: `LOC=polish` (Tob-Wald Gras, Gletscher Schnee mit Spuren).
- Gras weicht aus: `global uniform vec3 player_pos` in `grass.gdshader`, Shader-Global in `project.godot`, gesetzt je
  Bild in `World3D._process`. Blätter (forest, jungle, village, grassland) und Schmetterlinge (village, grassland, forest,
  swamp) als CPUParticles, die dem Spieler folgen (`_ambient_particles`). Nasse Wände bei Regen (`overlord_weather.z`).
- Dynamische Musik `World3D._music_tick` (alle 0,5 s): ruhig → `tension` (< 30 m) → `battle` (Gegner greift an oder
  < 10 m), zurück erst nach 6 s Ruhe; nicht in Story-Einsätzen und Filmszenen.
- Ankunftsschwenk `_arrival_pan` (3,2 s, nur Außenorte ohne Türankunft, `arrival_pans` im Testwerkzeug aus); während
  des Schwenks ist die Eingabe gesperrt (`_panning` in `blocked`).

## Erkunden mit Overlord-Herz (erledigt, Version 2.8)
- **41 Erinnerungsstücke von Ainz Ooal Gown** (`data/mementos.json`, `scripts/world3d/mementos.gd`): je Ort an versteckten
  Plätzen (`QuestWorld._spawn_mementos`, hidden-Heuristik, Innenräume als indoor), Pickup-Art `memento` (Sockel mit
  schwebendem Goldfragment), Text beim Aufheben, Stand in `Game.state.mementos`, Errungenschaften bei 10/20/41.
- **Kodex** im Questbuch: Sammelliste (gefunden/„? ? ?“ mit Ortshinweis), Ortskundig-Fortschritt je Ort
  (`Mementos.location_progress`: Inschriften, Schreine, Verstecke, feste Entdeckungen, Erinnerungsstücke), Gelesenes.
  „Ortskundig“ (alles an einem Ort gefunden): +60 Gold, Errungenschaften bei 5/15 Orten.
- **Runenrätsel** in der Schmiedehalle von Feo Jera: vier Pfeiler (Wasser, Erde, Luft, Feuer), Reihenfolge im Buch der
  Runen (Feuer, Erde, Luft, Wasser) → Kammer der Runenmeister: Runenschild der Zwerge, 300 Gold, Errungenschaft.
  Test: `LOC=kodex`.

## Nacht und Wetter (erledigt, Version 2.8)
- `scripts/world3d/weather.gd`: Wetterart je Spieltag und Gegend (`pick`, deterministisch), Faktoren über
  `DayCycle.set_weather` (Himmel, Sonne, Umgebungslicht, Nebel, Sonnentönung), Partikel um den Spieler (Regen, Schnee,
  Sand), Klangschleife (rain/storm/snowwind), Blitz (`DayCycle.flash`) und Donner (`sfx/thunder.ogg`). Nur bei aktivem
  Tag-Nacht-Wechsel. Test: `WEATHER=rain`.
- Nacht: Begegnungen mit `"night": true` erscheinen beim Dunkelwerden (`World3D._night_changed` → `_spawn_encounters(true)`),
  Fensterlichter je Haus (Gruppe `window_glow`, `location_builder._model_dressing`), Fackeln der Wachen (`Townsfolk.set_torches`).

## Eine Welt, die reagiert (erledigt, Version 2.8)
- `data/barks.json` + `scripts/world3d/barks.gd`: Bemerkungen der Bewohner nach Gruppe (`Barks.group_for`: Stil des
  Bewohners, Ortsart, Gestalt des Spielers Ainz/Momon, Krönung, Carne, Nacht, Katze-Massaker, Hof Königreich/Kaiserreich)
  und der Figuren je Id (`Barks.for_char`, Einträge mit `requires`). Townsfolk: Sprechblase (Label3D), Abkühlzeit je
  Person 18–30 s und global 1,6 s, Schreck-Flucht (`ainz_human`), Wachen/Dienerschaft wenden sich zu, Dienstmädchen
  verneigen sich. Actor3D.say für Figuren (World3D prüft alle 0,5 s im Umkreis von 5 m, 25–40 s Pause). Test `LOC=barks`.

## Handel und Controller (erledigt, Version 2.7)
- `data/trade.json` + `scripts/ui/trade_dialog.gd`: Händler (Lizzie, Schmied, Wirte, Priester, Gondo, Fluder, Gilde, Enri)
  mit Angebot (Dienste heal/mana/rest/meal/bless/heal_full/rumor, Ausrüstung mit `requires`) und Ankauf (Materialien
  je Händlerpreis, `buys_all` zum Grundwert; Mengen laufender Aufträge bleiben), abgelegte Ausrüstung zum Schmelzwert.
  Einstieg über `QuestWorld._merchant_action` („Handeln“ im Gespräch). Test: `LOC=trade`.
- Controller: `scripts/autoload/pad.gd`, Belegung in `Player3D._ensure_actions`, Menüfokus in `Overlay._focus_first`,
  Pausenmenü „Bücher, Karten & Berichte“, Steuerung-Tab. Test: `LOC=pad`.
- HUD zeigt die Tageszeit im Freien (☀/☾ + Morgen … Nacht).

## Tag-Nacht-Wechsel und Bewohner (erledigt, Version 2.6)
- `scripts/world3d/day_cycle.gd`: ein Sonnenlauf = acht Spieltage (World3D.DAY_SECONDS je Tag). Sonne wandert
  (Höhe, Stärke, Farbe), nachts Mond von der Gegenseite, HDRI-Himmel über den Shader gedimmt, Umgebungslicht,
  Nebelfarbe, Lampen/Feuer heller (Meta `base_day`), Bewohner (`Townsfolk.set_night`), Nachtklang
  (`Audio.play_ambience_for(loc, night)`). Einstellung `day_cycle`; nur Außenorte der Welt, nicht Friedhof (Nacht-HDRI).
- Händler hinter jedem `SM_MarketStall*` des Ortsmodells (tagsüber), zwei Wachen am Tor (Wappenrock je Fraktion);
  Bewohner-Stile maid/guard/noble/merchant; Ausstattungsart `folk` setzt Gäste per Daten (Dienstmädchen Nazaricks).
- Prüfen: `TOD=0.8 LOC=stageview STAGEVIEW="ort:x,z"` (0 = Sonnenaufgang, 0,25 Mittag, 0,5 Abend, 0,8 Nacht).

## Umgebungsklänge (erledigt)
- `assets/audio/ambience/<art>.ogg` (23 nahtlose Schleifen à 24 s, prozedural aus `tools/audio/ambience.py`):
  forest, jungle, village, town, cemetery, swamp, lava, glacier, mountain, battlefield, meadow, interior, home,
  hall, tombs, church, forge, court sowie Nachtvarianten village/town/forest/meadow/mountain (`_night`). Zuordnung je Ortsart in `Audio.AMBIENCE_OF` (ein Ort kann mit `"ambience"` eine
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
| Nazarick-Ebenen | Treppen/Tore zwischen allen Ebenen; Thronsaal mit violetten Feuerschalen, Dienstmädchen, erbeuteten Standarten (nach der Krönung) und Tribut (nach der Entscheidung); Gemächer mit Dienstmädchen und Blumen; Bibliothek mit Leselichtern und Gelehrten; Schatzkammer mit Truhen, Goldkristall und Tribut; Grabkammern mit Totenlicht und Nebel; Gletscher mit Eiskristallen; Dschungel mit Lichtern und Feuer; Lavahölle mit Lavaspalten und Glut | – |
