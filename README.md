# Overlord – Herrscher von Nazarick

Ein **3D-Third-Person-Action-RPG mit Herrscher- und Strategie-Ebene** in **Godot 4** (GDScript), inspiriert von *Overlord* – spielerisch angelehnt an *The Witcher 3* (Kampf), *Mass Effect/Dragon Age* (Gefährten, Entscheidungen) und *Anno/Civilization* (Verwaltung, Einfluss, Feldzüge).
Du bist **Momonga / Ainz Ooal Gown**: Du gehst selbst durch das Große Grab und die Neue Welt, gewährst deinen Wächtern Audienzen, erteilst Befehle am Kriegstisch, führst Schlachten persönlich – und deine Wächter führen alles auf **ihre eigene Weise** aus.

![Titel](docs/screenshots/title_3d.png)

| Thronsaal (begehbar) | Kampf auf der Katze-Ebene |
|---|---|
| ![Thronsaal](docs/screenshots/3d_throne.png) | ![Kampf](docs/screenshots/3d_combat.png) |
| **Die Weltkarte als 3D-Kriegstisch** | **Audienz – Portraits sind 3D-Renders** |
| ![Kriegstisch](docs/screenshots/3d_map_table.png) | ![Audienz](docs/screenshots/3d_audience.png) |
| **Schlacht persönlich anführen** | **Die Figuren von Nazarick** |
| ![Schlacht](docs/screenshots/3d_battle.png) | ![Figuren](docs/screenshots/3d_figures.png) |

Alles ist 3D: Orte, Figuren, Weltkarte, Titelbildschirm. Die Figuren und Gebäude sind prozedural gebaut und werden automatisch durch echte `.glb`-Modelle ersetzt, sobald sie vorliegen (siehe *3D-Modelle*). Menüs (Aufträge, Verwaltung, Diplomatie …) erscheinen als Fenster über der 3D-Welt.

---

## Installieren (Windows)

1. `OverlordNazarick-Setup-2.8.0.exe` ausführen (liegt nach dem Build unter `build/`).
2. Windows SmartScreen meldet evtl. „Unbekannter Herausgeber“ (die Datei ist nicht signiert) → **Weitere Informationen → Trotzdem ausführen**.
3. Installation durchklicken – danach gibt es Verknüpfungen auf dem Desktop und im Startmenü. Deinstallieren über „Apps & Features“.

Selbst bauen (Linux/macOS/WSL mit Godot 4.3, Windows-Exportvorlage und NSIS):

```bash
GODOT=/pfad/zu/godot ./tools/build_windows.sh
# → build/windows/OverlordNazarick.exe        (portable Einzeldatei, kein Installer nötig)
# → build/OverlordNazarick-Setup-2.8.0.exe    (Installer mit Startmenü/Desktop-Verknüpfung)
```

---

## Starten aus dem Quellcode

1. **Godot 4.3** oder neuer installieren (Standard-Version, kein .NET nötig): <https://godotengine.org/download>
2. Godot öffnen → **Importieren** → `project.godot` in diesem Ordner wählen → **Importieren & Bearbeiten**.
3. **F5** (oder ▶ oben rechts) – das Spiel startet mit dem Titelbildschirm.

Ohne Editor, direkt aus der Kommandozeile:

```bash
godot --path /pfad/zu/Overlord
```

Renderer: *Compatibility* (OpenGL 3.3) – läuft also auch auf älteren Grafikkarten und Laptops. Fenstergröße 1600×900, frei skalierbar.

---

## Third-Person: Nazarick begehen

Du betrittst Nazarick und die Neue Welt **selbst** – als Ainz Ooal Gown in der dritten Person. Neue Spieler werden von Albedo, Demiurge, Cocytus und Shalltear durch eine kurze Einführung geführt (erneut abrufbar im Menü).

| Steuerung | |
|---|---|
| Gehen / Rennen | `WASD` / `Shift` |
| Kamera / Zoom | Maus (Klick fängt den Zeiger) / Mausrad |
| Sprechen, benutzen | `E` |
| Gate (Reisen), Zeit, Aufträge, Karte | `G`, `T`, `J`, `M` |
| Diplomatie, Verwaltung, Nazarick, Wächter | `P`, `V`, `N`, `U` |
| Chronik, Speichern, Menü | `C`, `F5`, `Esc` |

- **20 begehbare Orte**: Thronsaal, Grabkammern, Eisgletscher, Dschungel & Amphitheater, Lavahölle, Königliche Gemächer, Bibliothek von Ashurbanipal, Schatzkammer – sowie Carne, E-Rantel, die Königshauptstadt, Arwintar, das Heilige Königreich, die Theokratie, der Wald von Tob, der Elfenwald, die Sümpfe, die Katze-Ebene, das Azerlisia-Gebirge und die Drachenlande. Reisen per **Gate**; Regionen der Welt müssen erst erkundet sein.
- **Die Wächter sind dort, wo sie wirklich sind**: im Thronsaal, auf ihrer Ebene, am Einsatzort ihres Auftrags oder als Feldherr bei ihrer Legion – als 3D-Figuren (Albedo mit Hörnern und schwarzen Flügeln, Shalltear im Ballkleid mit Lanze, Demiurge mit Brille und Schwanz, der vierarmige Cocytus …). Stimmung zeigt sich in Haltung und Licht. Ansprechen öffnet die Audienz.
- **Weltkarte als 3D-Kriegstisch**: Reliefgelände, Burgen der Fraktionen, Nazarick als Pyramide, Wege, eigene Legionen und feindliche Heere als Spielfiguren, die über das Gelände ziehen. Rechte Maustaste dreht, Mausrad zoomt.
- **Schlachten persönlich anführen**: Trifft eine Legion auf den Feind, kann Ainz per Gate aufs Schlachtfeld und die feindliche Armee in 3D besiegen – oder dem Feldherrn mit einer Taktik das Kommando lassen.
- **Thron** (Zeit), **Kriegsrat** (Aufträge, Karte, Diplomatie), **Albedos Pult** (Verwaltung, Ausbau, Schatzkammer, Wochenziele) und **Lagetafeln** in jeder Region verbinden die Welt mit allen Management-Systemen.
- Die **Zeit läuft in Echtzeit** (ein Tag je 45 Sekunden, am Thron anhaltbar); Berichte, Ereignisse und Schlachten erscheinen als Depeschen.
- Story-Figuren begegnen dir je nach Kapitel: Gazef, Nigun, Clementine, Hamsuke, Jircniv, Neia, die Platinrüstung …

Alle Umgebungen, Figuren und Himmel werden prozedural erzeugt; echte `.glb`-Modelle ersetzen sie automatisch.

## Controller

Das Spiel lässt sich vollständig mit Gamepad spielen (Xbox, PlayStation und kompatible; Namen hier nach Xbox, PlayStation zeigt ✕ ○ □ △ und L1/R1/L2/R2). Sobald der Controller benutzt wird, zeigen Hilfe, Aufforderungen und Zauberleiste seine Tasten, der Mauszeiger verschwindet, und in allen Fenstern ist ein Knopf fokussiert (Steuerkreuz/Stick wandern, A bestätigt, B schließt).

| Taste | Wirkung |
|---|---|
| Linker Stick / L3 | Gehen / Rennen |
| Rechter Stick / R3 | Kamera / Ziel fixieren |
| X / Y | Leichter / schwerer Angriff |
| B | Ausweichrolle · in Fenstern zurück |
| LT | Blocken, im richtigen Moment Parade |
| A | Sprechen, benutzen, Türen · in Fenstern bestätigen |
| Steuerkreuz | Zauber 1–4 |
| RB / RT | Zauber 5 / 6 |
| LB | Superrang-Magie (Ainz) |
| Start | Menü – darin „Bücher, Karten & Berichte“ (Zauberbuch, Questbuch, Karte, Depeschen, Zeit, Gate, Ainz ↔ Momon, Diplomatie …) |
| Back | Weltkarte |

Einstellungen → Steuerung: Kamera-Empfindlichkeit, Y-Achse umkehren, Vibration. Technik: `scripts/autoload/pad.gd` (Geräteerkennung, Symbole, Vibration), Belegung in `Player3D._ensure_actions`, Fokus in `Overlay._focus_first`. Test ohne Gerät: `LOC=pad godot res://tools/world3d_test.tscn` simuliert Stick, Tasten und Menüs.

## Kampfsystem (Third-Person, im Stil von The Witcher 3)

| Aktion | Taste |
|---|---|
| Leichte Attacke (Kombo) / Schwere Attacke | linke / rechte Maustaste |
| Ausweichrolle (mit i-Frames) | `Leertaste` |
| Blocken – früh gedrückt = **Parieren** | `F` halten |
| Ziel fixieren (Lock-on) | `Q` |
| Zauber bzw. Techniken | `1` `2` `3` `4` `5` `R` |
| Superrang-Magie (nur Ainz) | `Y` (QWERTZ; auf US-Tastaturen `Z`) |
| Kampfstil wechseln: Ainz ↔ Momon | `X` |
| Zauberbuch (Seelen, Zauber, Ringe) | `B` |

- **Zustandsautomat** für Spieler und Gegner (`scripts/combat/fighter.gd`): Bereit · Bewegung · Angriff (*Wind-up → aktiv → Recovery*) · Ausweichen · Block · Zauber · Taumeln · Gelähmt · Tot.
- **Hitboxes/Hurtboxes** (`hitbox.gd`, `hurtbox.gd`): echte Area3D-Trefferzonen auf getrennten Physik-Ebenen; jeder Angriff trifft ein Ziel höchstens einmal, Bogen-/Reichweitenprüfung inklusive.
- **Ausdauer** (schwere Attacken, Rolle, Blocken, Momons Techniken) und **Mana** (Ainz' Zauber) regenerieren sich; **Haltung (Poise)** bricht bei wuchtigen Treffern → Taumeln.
- **Schaden**: Rüstung mindert physischen Schaden, Widerstände je Schadensart (physisch, Feuer, negativ, heilig); wer nach einem verfehlten Angriff in der Recovery steht, nimmt mehr Schaden.
- **Statuseffekte**: Brennen (Schaden über Zeit), Unterkühlt (verlangsamt), Gelähmt, Schutzbarriere.
- **Ainz** – magiefokussiert: Stabhiebe plus *Feuerkugel* (Projektil mit Flammenschweif, Explosion, entzündet), *Kettendrachenblitz* (springt auf bis zu fünf Ziele), *Druckwelle* (stößt zurück, bricht jede Deckung – wie Aard), *Größere Magische Schutzbarriere* (Wabenschild, absorbiert einen Treffer – wie Quen), *Lähmung* (Bannkreise – wie Axii), der **Herzgriff** (ein geisterhaftes Herz schlägt immer schneller, bis Ainz die Hand schließt) und die Superrang-Magie **Fallen Down**: vier Sekunden Beschwörung mit Kranz aus Magiekreisen, dann fällt eine Säule aus Licht vom Himmel.
- **Momon** – zwei Großschwerter: 3-Schlag-Kombo, Großschwert-Spaltung, *Sprungangriff* (Bogen mit Nachbildern, Krater beim Aufschlag), *Schwerterwirbel* und *Schwertwurf* (Ausdauer); mehr Leben und Rüstung, kaum Mana.
- **Treffergefühl** (`combat_fx.gd`): Trefferstopp (Angreifer und Opfer frieren kurz ein), federndes Zurückzucken am Skelett der Figuren, Funken an Rüstung, Blut und Blutnebel an Fleisch, Knochensplitter an Untoten, Steinbrocken an Golems, Lichtfunken an Engeln – mit Bodenkollision und Blutflecken am Boden. Hiebspuren genau auf der Trefferzone, Kamera-Erschütterung, Blickwinkel-Stoß, kurze Zeitlupe bei Paraden und großen Siegen, Schadenszahlen mit **Kritisch**, **Rückentreffer**, **Konter** und **Wehrlos**. Erschütterung und Trefferstopp lassen sich in den Einstellungen abschwächen bzw. abschalten.
- **Kampfgeräusche** (`tools/audio/combat_sfx.py`, prozedural): Schwünge, Treffer je Stoff, Block, Parade, Explosionen, Blitze, Eis, Schatten, Licht, Herzschlag, Superrang – als Raumklang mit Hall je Ort.
- **Gegner-KI mit Gruppenregie** (`enemy_3d.gd`, `combat_director.gd`): höchstens zwei Nahkämpfer und zwei Schützen greifen gleichzeitig an, die anderen umkreisen Ainz auf eigenen Plätzen (Wölfe und Quagoa im Rücken). Verhaltensarten: Fußvolk, Duellanten (blocken und kontern), Hünen (unaufhaltsame schwere Schläge), Rudeltiere, Plänkler (zuschlagen, ausweichen), Bogenschützen und Zauberer (halten Abstand, schießen mit Vorhalt, Flächenzauber mit Bodenwarnung, Beschwörungen), Bosse mit Phasen bei halbem Leben. Gegner rufen sich gegenseitig zu Hilfe und weichen Feuerkugeln aus; Todesritter überleben den ersten tödlichen Treffer.
- **Lesbare Angriffe**: Beim Ausholen pulsieren Gegner **orange (blockbar)** oder **rot (nur ausweichen!)**, schwere Schläge und Flächenzauber zeigen eine sich füllende Bodenwarnung, kurz vor dem Treffer blitzt es (jetzt blocken = Parade). Angriffe außerhalb des Blickfelds melden Pfeile am Bildschirmrand, rote Bögen zeigen, woher Ainz getroffen wurde; Bosse bekommen einen großen Lebens- und Haltungsbalken.
- **Gegner** (`data/combat.json`): Skelettkrieger und -schützen, Ältester Leichnam, Todesritter, Ritter, Schützen und Magier der Schrift (beschwören Flammenerzengel), Engel der Herrschaft, Wölfe, Echsenkrieger und -schamanen, Quagoa, Elfenkrieger und -schützinnen, Söldner – dazu Bosse wie Zaryusu, Brain, Gagaran, Succulent (Spiegelbilder) und der Elfenkönig.
- Begegnungen je Ort in `data/locations.json` (`encounters`). Besiegte Gegner bringen Gold, Eliten zusätzlich Beute. Fällt Ainz, zieht er sich nach Nazarick zurück (Stimmung −4).
- Werte anpassen: `data/combat.json` (Stile, Angriffe mit `windup/active/recovery/damage/range/arc/stagger/lunge/unblockable`, Zauber, Gegner).

---

## Fortschritt im Kampf: Seelen, Zauberbuch und Ringe

Jeder besiegte Gegner gibt **Seelen** frei – violette Lichter, die aufsteigen und in einem Bogen zu Ainz fliegen (Fußvolk wenige, Eliten und Bosse viele, Beschworene kaum). Der Zähler steht neben Ainz' Namen im HUD.

- **Zauberbuch** [`B`]: Seelen in Macht verwandeln. Jeder Zauber und jede Technik steigt von **Rang I bis III** (mehr Schaden, kürzere Abklingzeit, geringere Kosten) – Rang III mit Sonderwirkung: *Feuerkugel* dreifach maximiert (drei Kugeln im Fächer), *Kettendrachenblitz* springt auf acht Ziele, *Druckwelle* betäubt, *Schutzbarriere* fängt zwei Treffer ab, *Lähmung* bannt drei Feinde, *Herzgriff* schneller, *Fallen Down* größer; Momons *Schwerterwirbel* doppelt, *Schwertwurf* mit beiden Klingen.
- **Neue Magie** zum Erlernen: **Negative Burst** (Ausbruch negativer Energie rings um Ainz), **Erschaffe Untoten: Todesritter** (erhebt sich aus dem Boden und kämpft an Ainz' Seite, auf Rang III zwei), **Schwarzes Loch** (saugt Feinde an und verschlingt sie, ab Kapitel 3), **Realitätsschnitt** (zerschneidet den Raum entlang einer Linie, unblockbar, ab Kapitel 5); für Momon **Unbeugsame Haltung** und **Erdspaltung**.
- **Zauberleiste frei belegen**: im Zauberbuch jeden bekannten Zauber auf `1`–`5` oder `R` legen; die Rang-Rauten erscheinen über den Tasten.
- **Ringe des Overlords**: drei Plätze, 18 Ringe in fünf Seltenheiten (Feuer-, Sturm-, Todesschaden, Abklingzeiten, Lebensraub, Leben, Mana, Rüstung, Seelen …) – darunter einzigartige Ringe aus jedem Kapitel-Moment (*Ring der Urflamme*, *Siegel von Carne*, *Ring des Herrschaftsengels*, *Ring der Kampfkünste*, *Blutroter Ring*, *Platinsiegel*). Überzählige Ringe werden zu Seelen eingeschmolzen.
- **Beute zum Aufheben**: Eliten und Bosse lassen leuchtende Funde mit Lichtsäule in der Farbe ihrer Seltenheit fallen – Ringe für Ainz oder Artefakte für die Schatzkammer. Ainz hebt sie im Vorbeigehen auf.
- Acht neue Errungenschaften (Seelensammler, Meister aller Künste, Der Höchste der Magier, Die Hand des Overlords …). Erinnerungen im Questbuch bringen keinen Lohn.
- Werte: `data/grimoire.json` (Seelen, Rangkosten und -wirkung, Sonderwirkungen, Ringe), neue Zauber in `data/combat.json`.

---

## Begehbare Gebäude und Innenräume

Wichtige Gebäude lassen sich **betreten**: ein Wirtshausschild mit Laterne markiert die Tür, `E` führt hinein, „Verlassen“ wieder vor dieselbe Tür. Die Innenräume sind eigene Orte (`data/locations.json`, `group: "interior"`, erreichbar über `doors` des umgebenden Ortes) und werden prozedural aus Fotomaterialien und Fotoscan-Requisiten gebaut (`scripts/world3d/interiors.gd`).

| Gebäude | Ort | Was es gibt |
|---|---|---|
| **Abenteurergilde** | E-Rantel | Empfang mit Tresen und Empfangsdame, Auftragstafel mit den Kopfgeldern der Stadt, Schankstube mit Abenteurern, Kamin, Trophäenwand, Lager, Büro des Gildenmeisters Ainzach, Rangtafel und Gildenchronik zum Lesen |
| **Gasthaus Goldener Pavillon** | E-Rantel | Tresen mit Fässern und Regal, Kamin, Tische mit Gästen, Wirt, Empore mit Zimmertüren – Zimmer 3 gehört Momon und Nabe; Gästebuch, vergessenes Gepäck |
| **Apotheke Bareare** | E-Rantel | Lizzies Laden: Tresen mit Waage, Regale voller Tränke, Kräuter an der Decke, brodelnder Kessel, Nfireas verwaister Arbeitsplatz, Hinterzimmer, Geheimvorrat |
| **Enris Haus** | Carne | Herd, Tisch, zwei Betten, das Horn des Goblin-Generals, Nemus Zeichnungen, eine lose Diele |
| **Schmiede zum Glühenden Amboss** | E-Rantel | Esse mit Glut und Rauchfang, Amboss, Löschtrog, Werkbank mit Barren, Schwertständer, Erzkisten; Schmied Harlan, Zunftbrief, Auftragstafel (Momons Schwerter, Clementines Dolch), vergessene Klinge |
| **Tempel der Vier Götter** | E-Rantel | Säulenschiff mit bunten Fenstern, Bänke, Altar mit Sonnenscheibe, vier Götterstatuen, Weihwasserbecken, Priester und Betende; Stiftertafel, Schriften (Khajiits Nachfragen), Reliquienschrein |
| **Dorfschenke** | Carne | Kurzer Tresen, Herd mit Kochtopf, drei Tische mit Hockern, Spinnrad, Gemüsekörbe; Wirtin Marla, Aushang (Wolfsjagd, Goblins trinken gratis), Gästebuch, Schmugglerfach |
| **Kathedrale der Sechs Götter** | Slane-Theokratie | Großes Schiff mit Bannern, sechs Statuen, goldener Altar, Kardinal Raymond; Tafel der Sechs Götter, Lehren der Sechs (Bericht über Nigun), Schatz der Kardinäle |
| **Magierakademie** | Arwintar | Fluders Studierzimmer: Bücherwände mit Leiter, Beschwörungskreis, Kristall, Sternkarte, Fernrohr, Trankregal, Magier; Fluders Forschungen, Stundenplan, versiegelte Truhe |
| **Schmiedehalle von Feo Jera** | Azerlisia | Drei Zwergenessen mit Ambossen, Runenpfeiler mit Leuchtsteinen, Statue des Runenkönigs, Erzkarren, Zwerge bei der Arbeit, Gondo; Runentafel der Meister, Buch der Runen, Erzkiste |
| **Thronsaal von Ro-Lente** | Re-Estize (Schloss, oben an der Rampe) | Säulenschiff mit Löwenbannern und bunten Fenstern, Podest mit Thron und Baldachin, Kriegstisch, Wachen und Adlige; König Ranpossa III., Gazef; Stammbaum der Könige, Protokoll des Thronrats, Kronschatz |
| **Audienzsaal des Kaisers** | Arwintar (Kaiserpalast) | Weißer Marmor, rote Banner, Thron, Kriegstisch, kaiserliche Wachen und Hofstaat; Jircniv; Die Vier Kaiserlichen Ritter, Jircnivs Reformen, Geheimarchiv |

| **Keller der Acht Finger** | Re-Estize (Kellerluke im Armenviertel, beim Bettlerfeuer) | Der erste Kerker einer Stadt: Pfeiler und Fackeln, Käfige mit einem Gefangenen, Zähltisch voller Gold, Schmuggelware – bewacht von Schlägern, Armbrustschützen und einem Söldner (Kampf); Schuldbuch, Liste der Schutzgelder, Kasse der Acht Finger |
| **Kanalisation von E-Rantel** | E-Rantel (Kanalgitter im Osten der Stadt – verschlossen, Schlüssel auf dem Friedhof) | Verlies: langes Steingewölbe mit Wasserrinne, Bögen, vergitterten Nischen, Schleim, leuchtenden Pilzen und Gebeinen; Skelette, Kultisten und ein Priester der Zurrernon (Kampf); Zeichen an der Wand, Khajits Aufzeichnungen, Opfergaben – und das Siegel der Gefallenen auf dem Kultaltar |
| **Gruft der Gefallenen** | Katze-Ebene (Portal im Osten – versiegelt, Siegel aus der Kanalisation) | Verlies: Säulenhalle mit Sarkophagen, kalten Feuerschalen, Bannern beider Reiche, Gebeinen; Skelette und der **General der Gefallenen** – ein Boss mit Phasen, der Gefallene aus dem Nebel ruft; Grabinschrift, Letzter Befehl, Steinthron; nach dem Sieg der Schatz des Generals |

**Handel** (`data/trade.json`, `scripts/ui/trade_dialog.gd`): Händler bieten im Gespräch „Handeln“ an. Lizzie verkauft Heil- und Manatränke, Ringe und Handschuhe und kauft Kräuter; der Schmied verkauft Klingen und Panzer (Mithril ab Kapitel 3, Echsenschuppen nach dem Sumpf) und kauft Erz, Schuppen, Zähne; die Wirte vermieten Zimmer (alles erholt), kochen Eintopf und erzählen Gerüchte; der Priester segnet gegen Spende; Gondo handelt mit Runenwerk, Fluder mit Artefakten der Gelehrten; Gilde und Enri kaufen alle Materialien zum Grundwert. Mengen für laufende Aufträge bleiben im Beutel; abgelegte Ausrüstung lässt sich zum Schmelzwert verkaufen.

**Verliese und Schlüssel** (`doors` → `key`, `hint`, `style: grate | crypt`): Verschlossene Eingänge zeigen „Verschlossen“ und einen Hinweis, bis der passende Schlüssel im Beutel liegt (einmalig aufschließen, danach offen). Schlüssel sind eigene Entdeckungen (`data/discoveries.json` → `placed`, `kind: "key"`, `item`) und einzigartige Beutelgegenstände (`data/quests.json` → `materials`, `unique`, unverkäuflich). Die Kette: Schlüssel aus dem Mausoleum auf dem **Friedhof von E-Rantel** → **Kanalgitter** in E-Rantel → Siegel der Gefallenen auf dem Altar der **Kanalisation** → **Gruft der Gefallenen** unter der Katze-Ebene mit dem General (Boss; danach erhebt er sich nicht mehr, der Schatz bleibt). Errungenschaften: Unter der Stadt, Bezwinger der Gruft, Schlüsselmeister. Test: `LOC=dungeon`.

**Nazarick**: Die Ebenen sind über **Treppen und Tore** verbunden (Türen in den Hallen: Grabkammern ↔ Eisgletscher ↔ Dschungel ↔ Lavahölle ↔ Königliche Gemächer ↔ Thronsaal ↔ Bibliothek / Schatzkammer, Abstieg vom Mausoleum im Grasland in die Grabkammern); man kommt jeweils vor der Gegentür an. Die Ebenen sind ausgestattet (violette Feuerschalen, Dienstmädchen, Eiskristalle, Lavaspalten, Truhen der Schatzkammer) und verändern sich mit der Geschichte: erbeutete Standarten des Königreichs nach der Krönung, Tribut der Reiche nach der Entscheidung der Welt.

Jeder Raum hat eigene **Entdeckungen** (`data/discoveries.json` → `placed`: Lesepult, Tafel, Aushang, Versteck) mit fester Position – Lesen bringt Wissen, Durchsuchen Beute. Der Stand der Welt-Überarbeitung je Ort steht in `docs/WELT_UEBERARBEITUNG.md`.

**Ausstattung der Orte** (`data/dressing.json`, `scripts/world3d/dressing.gd`): Banner, Feuerschalen, Lagerfeuer, Statuen, Kisten, Fässer, Zelte, Palisaden, Brunnen, Gedenksteine, Laternen, Wäscheleinen, Trümmer, Galgen, Fotoscans, Rauch, Staub und Lichter je Ort – mit Bedingungen (`requires`/`requires_not`), sodass sich die Orte mit der Geschichte verändern: Banner des Königreichs werden nach der Krönung zu Bannern Nazaricks, auf der Katze-Ebene stehen vor der Schlacht die Lager beider Heere und danach erloschene Feuer, Trümmer und Blut, vor der Mauer von Roble lagert in Kapitel 9 Jaldabaoths Horde. Prüfen: `LOC=dresscheck godot res://tools/world3d_test.tscn` meldet jedes Stück, das in einem Gebäude steckt oder am Hang steht.

**Tag-Nacht-Wechsel** (`scripts/world3d/day_cycle.gd`, Einstellungen → Grafik): Im Freien wandert die Sonne – ein Sonnenlauf dauert acht Spieltage. Abends wird das Licht warm und flach, nachts wird die Sonne zum Mond, der Himmel dunkel und blau, Laternen und Feuer leuchten heller, Händler schließen ihre Stände und zwei Drittel der Bewohner gehen heim (Wachen bleiben), und der Umgebungsklang wechselt zur Nachtvariante (Grillen, Eule, ferner Hund). Innenräume, Nazarick und der Friedhof (immer Nacht) bleiben unberührt. Bilder zu fester Tageszeit: `TOD=0.8 LOC=stageview STAGEVIEW="e_rantel:0,14"`.

**Eine Welt, die reagiert** (`data/barks.json`, `scripts/world3d/barks.gd`): Wer nahe vorbeigeht, bekommt etwas zu hören. Als **Momon** jubeln die Städter („Der dunkle Held!“), Wachen grüßen, Händler preisen an; als **Ainz** in einer Menschenstadt schreien sie, rufen die Wache und weichen zurück, Wachen stellen sich – bis zur Krönung, danach „Heil dem Zauberkönig!“. In Carne kennt man den Retter in beiden Gestalten. Nachts, nach dem Massaker auf der Katze-Ebene, im Thronsaal des Königs oder im Kaisersaal fallen andere Sätze. In Nazarick verneigen sich die Dienstmädchen („Ainz-sama!“), und die Figuren selbst – Albedo, Shalltear, Demiurge, Cocytus, Pandora's Actor, Sebas, Aura, Mare, die Pleiaden, Gazef, Enri, Nfirea, Jircniv, Fluder, Gondo, Hamsuke, Zaryusu … – sprechen eigene Zeilen, manche nur nach bestimmten Ereignissen. Test: `LOC=barks`.

**Erkunden mit Overlord-Herz**: In der ganzen Welt liegen die **41 Erinnerungsstücke von Ainz Ooal Gown** versteckt – Touch Mes Schildsplitter, Ulberts Ziegenmaske, Peroroncinos Pfeilfeder, Tabulas Entwürfe, Bukubukuchagamas Stimmkristall, Momongas erster Ring … jedes mit einem Text über das Gildenmitglied, abseits der Wege und hinter Deckung, in Städten, Wäldern, Ebenen und den Hallen Nazaricks. Der **Kodex** im Questbuch zeigt die Sammlung (fehlende Stücke mit Ortshinweis), den Entdeckungs-Fortschritt je Ort („Ortskundig“ – alles gefunden bringt Gold) und alles bereits Gelesene. Belohnungen und Errungenschaften bei 10, 20 und 41 Stücken sowie 5 und 15 ortskundigen Orten. Und Lesen lohnt sich: Das **Buch der Runen** in Feo Jera nennt die Reihenfolge, in der die vier Runenpfeiler der Schmiedehalle zu berühren sind – wer sie findet, öffnet die Kammer der Runenmeister (Runenschild der Zwerge). Test: `LOC=kodex`.

**Nacht und Wetter als Spielfaktor** (`scripts/world3d/weather.gd`): Nachts glühen die Fenster der Häuser, Wachen tragen Fackeln – und die Welt wird gefährlicher: Wölfe im Grasland, im Wald von Tob und vor Carne, Schläger der Acht Finger in den Gassen von E-Rantel und Re-Estize, Untote auf der Katze-Ebene, Höllenhunde im Sumpf und in den Drachenlanden, Quagoa im Gebirge, Elfenschützen im Wald, Dämonen vor der Mauer von Roble (Kapitel 9). Das Wetter wird je Spieltag und Gegend ausgewürfelt: klar, bedeckt, Regen mit Blitz und Donner, Nebelmorgen, Schneefall im Gebirge, Sandsturm in den Drachenlanden – mit eigenen Klängen (`rain`, `storm`, `snowwind`, Donner) und Wirkung auf Himmel, Sonne und Nebel. Bilder zu festem Wetter: `WEATHER=rain TOD=0.25 LOC=stageview STAGEVIEW="e_rantel:0,14"`.

**Bewohner**: Städte und Dörfer haben neben den Passanten **Händler hinter jedem Marktstand** des Ortsmodells (tagsüber) und **zwei Wachen am Tor** im Wappenrock ihrer Fraktion (Königreich blau, Kaiserreich rot, Theokratie weiß, Roble blau, Carne grün). Innenräume bekommen passende Bewohner-Stile (`Townsfolk.spawn(..., style)`: `adventurer`, `priest`, `mage`, `smith`, `dwarf`, `maid`, `guard`, `noble`, `merchant`).

**Umgebungsklänge** (`assets/audio/ambience/`, erzeugt von `tools/audio/ambience.py`): jeder Ort hat eine nahtlose Klangschleife seiner Art – Wind und Vögel im Wald, Stimmengewirr und Hammerschläge in der Stadt, Hühner im Dorf, Frösche im Sumpf, Krähen über dem Schlachtfeld, Eule und Grillen auf dem Friedhof, Grollen in der Lavahölle, Chor und Kerzen im Tempel, Blasebalg und Hammer in der Schmiede, Kaminknistern in Gasthaus und Stube, Hofgemurmel im Thronsaal – nachts Grillen, Eule und ferner Hund oder Wolf (`<art>_night`). Lautstärke: Einstellungen → Audio → Umgebungsklänge.

---

## Testmodus: Orte und Kämpfe ohne Freischaltung

- **Titelbild → „Testwelt (alles frei)“**: neues Spiel im letzten Kapitel mit allen Wächtern, allen erkundeten Gegenden, allen Kapitel-Momenten als Erinnerung und 5000 Gold (`Game.unlock_everything`, Spielstand trägt `testwelt`).
- **Pausenmenü → „🧪 Testmodus“** (in jedem Spiel): zu jedem Ort reisen (Außenorte, Nazarick-Ebenen, Innenräume), jeden Gegner aus `data/combat.json` vor sich beschwören (Bosse und Eliten einzeln, andere zu dritt), jeden Story-Einsatz als Erinnerung starten, Tageszeit und Wetter sofort umstellen, heilen und alle Gegner entfernen, „Alles freischalten“ für einen laufenden Spielstand.
- Prüfung: `LOC=testmenu godot res://tools/world3d_test.tscn`.

## Feinschliff: Fotomodus, Schritte, Musik

- **Fotomodus** (`F9`, Pausenmenü, Controller: Start → Fotomodus; `scripts/world3d/photo_mode.gd`): Die Welt hält an, das HUD verschwindet, die Kamera fliegt frei (WASD / linker Stick, Q/E bzw. LT/RT auf und ab, Shift / L3 schnell, Mausrad Brennweite). Vier Filter (Natur, Sepia, Noir, Kräftig – Tasten 1–4 oder Steuerkreuz), Leertaste / A speichert ein Foto ohne Einblendungen nach `user://screenshots/` (Windows: `%APPDATA%\Godot\app_userdata\Overlord\screenshots`).
- **Schritte und Spuren** (`Player3D._footsteps`): Schrittgeräusche im Takt der Bewegung je Untergrund (Stein in Städten, Nazarick und Gewölben, Holz in Schenken und Stuben, Gras im Freien, Schnee auf dem Gletscher und bei Schneefall, Sand in den Drachenlanden – `assets/audio/sfx/step_<art>_1..3.ogg`, erzeugt mit `tools/audio/ambience.py steps`); in Schnee und Sand bleiben Fußspuren zurück, die nach einer halben Minute verblassen.
- **Lebendige Wiesen**: Gras weicht dem Spieler aus (Shader-Global `player_pos`, `assets/shaders/grass.gdshader`), in Wäldern und Dörfern fallen Blätter, über Wiesen tanzen Schmetterlinge; bei Regen werden die Hauswände nass (`overlord_weather.z`).
- **Dynamische Musik** (`World3D._music_tick`): Ortsmusik in Ruhe, „Spannung“ sobald Gegner näher als 30 m sind, „Schlacht“ im Kampf – mit Nachhall nach dem letzten Treffer, nie während Story-Einsätzen.
- **Ankunft**: Beim Betreten eines Außenortes (Reise, Spielstart) schwenkt die Kamera von oben hinter dem Spieler in die Spielkamera. Test: `LOC=polish`.

## Story-Einsätze: die großen Momente selbst erleben

Zwölf Schlüsselmomente der Geschichte – aus allen Kapiteln von der Ankunft bis zum Platin-Drachenlord – lassen sich statt per Depesche **selbst in 3D spielen** – mit Filmszenen (Letterbox, Kamerafahrten, Untertitel mit Porträt, Ainz' Gedanken), Verbündeten an Ainz' Seite und Bossen mit Zwischenszenen. Erscheint die Depesche, bietet sie *„⚔ Selbst erleben“* an; die im Einsatz getroffene Entscheidung wird wie eine Antwort in der Depesche gewertet.

| Moment | Ort | Was passiert |
|---|---|---|
| **Der Treueschwur der Wächter** | Amphitheater, 6. Ebene | Magietest mit Aura und Mare gegen einen Urfeuer-Elementar; die Wächter treffen ein (Shalltear per Gate, Cocytus im Frosthauch), knien nieder – und beantworten die Frage, wer Ainz für sie ist. |
| **Rauch über Carne** | Dorf Carne (brennend) | Enri und Nemu auf der Flucht, das Gate, Herzgriff und Drachenblitz, ein Todesritter erhebt sich, Albedo kommt nach; Kampf um den Dorfplatz gegen die Ritter und ihren feigen Hauptmann Belius. |
| **Die Sonnenlicht-Schrift** | Carne, Abenddämmerung | Gazef wird ausgetauscht, Nigun beschwört Engel, die Prinzipalität und schließlich den Engel der Herrschaft – Heiliges Urteil, „Das also ist Schmerz“, Schwarzes Loch. Am Ende: Negative Burst oder Gefangennahme. |
| **Die Nacht der Untoten** | Friedhof von E-Rantel | Als Momon mit Nabe durch die Untotenflut, ein Ältester Leichnam, Khajit und Clementine am Mausoleum; Kettendrachenblitz, die Enthüllung – und Nfireas Schicksal. |
| **Overlord gegen Wahren Vampir** | Wald von Tob, Mitternacht | Das Duell gegen die beherrschte Shalltear mit Einherjar-Abbild und Blutrausch; beendet mit Fallen Down (kostet 150 Gold) oder List. |
| **Frost über dem Sumpf** | Sümpfe der Echsenmenschen | Ainz lässt den ganzen See in einer Welle zu Eis erstarren; **als Cocytus** kämpft Ihr gegen die Krieger der Stämme, Zenberu und Zaryusu mit Frost Pain – danach bittet Crusch um sein Leben: Wiederbelebung oder nicht. |
| **Gehenna** | Königshauptstadt bei Nacht | Eine haushohe Gehenna-Flamme quer durch die Stadt, brennende Häuser, Dämonen aus dem Feuer; **als Momon** mit Nabe gegen den maskierten Jaldabaoth – ein aufgeführter Kampf, den die Stadt nie vergisst. Danach legt Demiurge seine Liste vor. |
| **Die Schlacht auf der Katze-Ebene** | Katze-Ebene | Der Nebel lichtet sich vor einem Heer aus Tausenden Soldaten. *Iä Shub-Niggurath*: Superrang-Kreise, die Sanduhr, ein schwarzer Wind, unter dem die Reihen fallen, fünf Dunkle Junge steigen aus dem Boden – oder Todesreiter brechen nur die Adelsbanner. Zum Schluss Gazef Stronoffs Duell. |
| **Die Hallen von Feo Jera** | Azerlisia-Gebirge | Ainz, Aura und Shalltear retten den Runenschmied Gondo vor den Quagoa und ihrem Herrn Pe Riyuro; danach die Frage, was aus der Runenkunst wird. |
| **Das Mädchen mit den bösen Augen** | Heiliges Königreich, vor der Großen Mauer | Neia verteidigt zwei Kinder gegen Bafolk und Höllenhunde, die Paladine zögern – der Zauberkönig erscheint. Ihre Frage: Warum rettet ein Untoter die Schwachen? |
| **Der Elfenkönig** | Ewiger Wald, Thron aus lebendem Holz | Decem Hougan beleidigt Aura und Mare: Ainz kämpft selbst, **Aura kämpft mit Mare an ihrer Seite** – oder der König wird gelähmt der Theokratie übergeben. |
| **Das Gleichgewicht der Welt** | Katze-Ebene, Nebel bei Nacht | Die Platinrüstung stellt die Frage nach Ainz' Absicht: Frieden – oder ein Kampf gegen schwebende Klingen an der Seite von Albedo und Cocytus. |

- **Technik** (`scripts/story/`): `story_mission.gd` (Ablauf: Szenen, Wellen, Bosse mit Einführung, Schwellen-Szenen und Aufgeben, Wegpunkte, Verbündete), `cutscene.gd` (Kamera relativ zu Figuren mit Sichtprüfung, Figuren stellen/gehen/knien/stürzen/aus dem Boden steigen, Effekte, Entscheidungen), `story_fx.gd` (Gate, Großbrand, Schutzkuppel, Schwarzes Loch, gefrierendes Wasser, Gehenna-Flamme, Superrang-Kreise, Sanduhr, schwarzer Wind, Tageszeit-Stimmungen, Kulissen wie der Elfenthron), `army_crowd.gd` (Heer aus Tausenden Soldaten in einem MultiMesh, fällt im Shader), `dark_young.gd` (Dunkles Junges, ganz prozedural), `scripts/ui/cinematic_ui.gd` (Letterbox, Untertitel, Entscheidungen, `Esc` überspringt).
- **Inhalte**: `data/story_missions.json` – Schritte und Szenen als Daten, Gegner und Verbündete in `data/combat.json`, neue Figuren in `data/figures.json`.
- **Verbündete** kämpfen eigenständig, folgen Ainz und kündigen ihre Angriffe in Blau an; Bosse können **aufgeben** (knien nieder), Untote ihres Gefolges zerfallen, Lebende ergeben sich.
- **Kapitel-Momente** im Questbuch [`J`]: erlebte (oder ohne Euch entschiedene) Momente lassen sich als **Erinnerung** erneut spielen – ohne Lohn und ohne Folgen für das Reich.
- Scheitert Ainz in einem Einsatz, wartet die Depesche weiter: erneut versuchen oder anders entscheiden.

---

## 3D-Modelle (.glb) einbinden

Das Spiel nutzt **echte 3D-Modelle**, sobald sie vorhanden sind – sonst automatisch die prozeduralen Ersatzfiguren und -gebäude. Auch die Portraits in Dialogen und Menüs werden aus dem jeweiligen Modell gerendert.

**Ablage** (Dateiname = ID, `.glb` empfohlen, auch `.gltf`/`.tscn`):

| Ordner | Inhalt |
|---|---|
| `assets/models/characters/<id>.glb` | Figuren: Ainz, Momon, Wächter, NPCs, Gegner |
| `assets/models/props/<id>.glb` | Requisiten/Gebäude, ersetzen die Grundformen überall im Spiel |
| `assets/models/locations/<ort>.glb` | ein ganzer Ort – ersetzt das prozedurale Rezept komplett |

Zusätzlich lädt das Spiel Modelle **zur Laufzeit ohne Neu-Export** aus `<Spielordner>/models/<kind>/` und `user://models/<kind>/` (z. B. `%APPDATA%\Godot\app_userdata\Overlord – Herrscher von Nazarick\models\characters\albedo.glb`).

**Anforderungen**
- Maßstab 1 Einheit = 1 Meter, Figuren ca. 1,8–2,3 m, Ursprung zwischen den Füßen, Blick nach **+Z** (sonst `rot_y` in `data/models.json`).
- Figuren mit Skelett und Animationen im selben `.glb`. Erkannt werden (Groß-/Kleinschreibung egal, Teilwort genügt – erweiterbar in `data/models.json → animation_aliases`):
  `idle`, `walk`, `run`, `attack_light` (*attack, slash, attack1 …*), `attack_heavy` (*heavy, slam, attack2 …*), `dodge` (*roll*), `block`, `hit`, `stagger`, `death`, `cast`.
  Angriffs-Animationen werden automatisch auf die Dauer des jeweiligen Angriffs gestreckt.
- Pro Modell optional in `data/models.json`: `{"characters": {"albedo": {"scale": 1.0, "rot_y": 180, "y": 0, "anims": {"attack_light": "Albedo_Slash"}}}}`.
- Requisiten erhalten automatisch eine Kollision aus ihren Meshes.
- **Requisiten an Figuren** (`tools/pipeline/build_prop.py`): Jaldabaoths Maske (`props/jaldabaoth_mask.glb`, hängt am Kopfknochen des Demiurge-Modells, Drehpunkt auf Augenhöhe, Blick nach +Z) und Frost Pain (`props/frost_pain.glb`, Griff im Ursprung, Klinge nach +Y, sitzt in Zaryusus Hand) werden aus Tripo-FBX gebaut: `blender -b --python tools/pipeline/build_prop.py -- <Quellordner> <Ziel-GLB> <Maßstab> <px,py,pz> [rot_z] [Basis-px] [Normal-px]`. Fehlen die Dateien, bleibt jeweils die prozedurale Version (`ProcModel.accessories`, `_hand_weapon`). Grundfarben als JPEG 4:2:0 – Godots Decoder lädt kein 4:4:4.
- **Eigene Rigs für Bestien** (alle aus Tripo-FBX in `C:\Projekte\Overlord\Models\<Name>\src`): `build_wolf.py` (Waldwolf und Höllenhund, Schritt/Galopp/Biss/Sprung), `build_dragon.py` (Skelettdrache: Flügel um die Körperachse schlagend, der ausgebreitete Flügel wird auf die zerknitterte Seite gespiegelt; neuer Gegner `skeletal_dragon` nachts auf dem Friedhof ab Kapitel 3 und auf der Katze-Ebene ab Kapitel 5), `build_victim.py` (schwebt, Zweigflügel wiegen sich), `build_darkyoung.py` (radiales Rig mit fünf Beinen und acht Tentakeln; `scripts/story/dark_young.gd` nutzt das Modell, wenn es vorliegt, und behält Gang, Stampfen und Brüllen). Testmodi `LOC=wolf`, `LOC=dragon`, `LOC=darkyoung`, `LOC=hamsuke`, `LOC=props`, `LOC=buildings` (Drehung, Skalierung und Unterkante der vergrößerten Gebäude).
- **Größen** (Serienmaßstab): Häuser und Türme der Orts-Baukästen werden beim Laden um 30 % höher gesetzt (`LocationBuilder.BUILDING_SCALE_Y`, Grundriss bleibt, Kollision wächst mit), Todesritter 1,4-fach (≈ 3 m), Hamsuke 1,6-fach, Skelettdrache 1,35-fach (≈ 6 m lang), Dunkles Junges 13 m hoch. Einstellbar in `data/models.json` (`scale`) und `data/combat.json` (`height`).
- **Für Mixamo vorbereitet** (`<Name>/<name>_mixamo.fbx`, 60.000 Dreiecke, 2K-Texturen, Blick nach vorn): Solution (erledigt: `solution.glb`), Jircniv, Entoma, Sebas, Nigun, Gazef, Khajit, Momon, Quagoa, Zenberu, Pandoras Actor, Gargantua, Mare. Ablauf: Nutzer lädt das ZIP hoch und setzt die Marker, die Clips (idle mit Skin, übrige ohne Skin, Gehen/Laufen „In Place“) werden im Browser gesucht und mit `tools/pipeline/grab_download.sh` nach `<Name>/mixamo/` abgelegt; `build_character.py <mixamo-ordner> <Name-ordner> <ziel.glb>` baut das GLB, `render_glb.py` den Kontaktbogen zur Kontrolle.
- **Dorfbewohner-Modelle** (`tools/pipeline/build_villager.py` → `assets/models/characters/villager_m.glb` und `villager_f.glb`): ohne fremde Downloads gebaut – um Demiurges Mixamo-Skelett (T-Pose, 1,84 m, mit allen seinen Clips idle/walk/run/hit/death/dodge/block/attack/cast) entsteht ein stilisierter Körper per Skin-Modifier und Subdivision (Mann breitschultrig, Frau schmaler mit weiter Hüfte), dazu Kopf mit Augen, Brauen, Nase, Mund und Ohren, sieben Frisuren, Bart, Elfenohren, Mütze, Strohhut, Topfhelm mit Sehschlitz und Kamm, Krone, Brille, Brustpanzer mit Schulterplatten, Schürze, Wappenrock, Umhang und Rock als eigene Knoten. Materialien heißen `Skin`, `Hair`, `Top`, `Bottom`, `Boots`, `Trim`, `Pupil`, `Cape`, `Tabard`, `Skirt`, `Hat` …; `scripts/world3d/villager_look.gd` färbt sie je Figur (Kopie je Oberfläche) und blendet die Teile nach der Figurenbeschreibung ein (dieselben Felder wie bei den Ersatzfiguren: skin, hair, top, bottom, trim, eyes, armor, apron, cape, tabard, helmet, plume, beard, glasses, crown, cap, straw, ears, female, weapon). Bewohner (`Townsfolk`) und alle menschlichen Figuren aus `data/figures.json` ohne eigenes Modell (Enri, Nfirea, Gazef, Sebas, Jircniv, Clementine, Neia, Ritter, Priester, Fluder, Ranpossa …) nutzen sie automatisch (`ProcModel.model_of`); Figuren mit Flügeln, Schwanz, Hörnern oder Schnauze bleiben prozedural, ein eigenes GLB `<figur>.glb` hat stets Vorrang. Gewichte per Bone Heat (Rückfall: nächstes Knochensegment), Finger- und Endknochen verformen nicht. Zusätzliche Mixamo-Clips ohne Skin (Reden, Streiten, Klatschen, Jubeln, Winken, Beten, Sitzen, Sitzen-Reden, Trinken aus `C:\Projekte\Overlord\Models\Sebas\mixamo_civil`, Parameter `clips=<ordner>`) werden per Weltraum-Rotationsdeltas auf das Rig übertragen (`_retarget` wie in `build_character.py`); `CharacterRig.play_extra(name, loop)` spielt sie, `Townsfolk._idle_clip` lässt Gesprächsgruppen reden und streiten, Wartende winken, klatschen und jubeln, Priester beten, Magier und Adlige reden, und beim Sprechen gestikulieren Bewohner. Prüfmodus `LOC=villagers` (Bewohnerstile, benannte Figuren, Gang, Clips; Bilder `villagers_*.png`). Menschliche Gegner mit `"model": "soldier"` in `data/combat.json` tragen dasselbe Modell: `VillagerLook.enemy_spec` leitet aus Art, Farbe und Waffe Rüstung, Helm, Wappenrock, Umhang, Robe, Kapuze (`Hood`) und Waffe ab (Soldaten mit Wappenrock, Kultisten in Kapuzenroben, Banditen mit Mütze und Bogen, Gagaran mit Hammer …); Prüfmodus `LOC=enemies`. Kinder (`villager_c.glb`: großer Kopf, schmale Glieder, im Spiel auf 0,55–0,68 skaliert) laufen in Dörfern mit und ersetzen die kleinen Figuren (`scale` < 0,7 oder `child`); an den Wirtshaustischen der Abenteurergilde und des Gasthauses sitzen Gäste (`Interiors.chair_guest_at` → `Townsfolk.spawn_seated`: Sitzen, Plaudern, Trinken). Prüfmodus `LOC=seats`.
- **Mixamo-Upload** klappt zuverlässig nur als ZIP mit OBJ + MTL + Grundfarbe (`tools/pipeline/mixamo_zip.py` baut es aus `<Name>/<name>_mixamo.fbx`); Blender-FBX lehnt Mixamo oft mit „Upload failed“ ab.
- **Nicht-Menschen ohne Mixamo** (Beispiel Hamsuke, `tools/pipeline/build_hamsuke.py`): Mixamo riggt nur Zweibeiner. Für den Weisen König des Waldes baut das Skript aus dem Tripo-FBX (Quellen in `C:\Projekte\Overlord\Hamsuke`) ein eigenes Skelett (Hüfte, Rumpf, Kopf, Ohren, Pfoten, vierteilige Schwanzkette entlang der aus dem Mesh berechneten Mittellinie), verteilt die Gewichte (nächster Knochen, geglättet; Schwanz als Zeltfunktion entlang der Kette) und erzeugt zehn Animationen per Schlüsselbildern (Idle, Walk, Run, Attack_Light, Attack_Heavy, Hit, Stagger, Death, Dodge, Block) – Namen in `data/models.json → characters.hamsuke.anims`. Ausrichtung: Blick nach -Y in Blender (= +Z im Spiel), Füße auf 0, Höhe 2,2 m, Texturen eingebettet (Godot legt sie beim Import daneben ab).
- Orts-Modelle können Ankerpunkte als benannte Knoten (Empty/Marker) enthalten: `Spawn`, `Gate`, `Throne`, `Table`, `Desk`, `Board`, `Keeper`, `Slot1` … `SlotN`.
- Quellen: selbst modelliert (Blender), lizenzfreie Pakete oder KI-Generatoren mit passender Lizenz; Animationen z. B. über Mixamo. Keine Modelle aus offiziellen Spielen/Anime ohne Rechte.

**Noch fehlende Modelle** (alle derzeit Ersatzfiguren):

- Figuren: `ainz`, `ainz_momon`, `albedo`, `shalltear`, `demiurge`, `cocytus`, `aura`, `mare`, `sebas`, `narberal`, `pandora`, `yuri`, `lupusregina`, `entoma`, `cz`, `victim`, `neuronist`, `gazef`, `jircniv`, `neia`, `hamsuke`, `nigun`, `clementine`, `platinum_dragon`, `death_knight`, `skeleton`, `death_knight`, `soldier`, `wolf`, `angel`, `golem`
- Requisiten: `house`, `tower`, `tree`, `tree_conifer`, `rock`, `brazier`, `pillar`, `crystal`, `banner`, `throne`, `war_table`, `desk`, `gate_portal`, `coffin`, `bookshelf`, `tent`, `stilt_hut`, `gold_pile`, `chest`, `palace`, `cathedral`, `city_wall_segment`, `ice_spike`, `statue`
- Ganze Orte (optional): `throne`, `tombs`, `glacier`, `jungle`, `lava`, `royal`, `library`, `treasury`, `carne`, `e_rantel`, `re_capital`, `baharuth`, `roble`, `theokratie`, `tob_wald`, `elfen`, `sumpf`, `katze`, `azerlisia`, `drachen`

Der Test `tools/combat_test.tscn` erzeugt zur Laufzeit ein Test-`.glb` mit Animationen, lädt es über `ModelLib`, prüft die Animationszuordnung und das Platzieren eines Requisits mit Kollision.

---

## Spielanleitung

| Aktion | In der Welt | Taste |
|---|---|---|
| Aufträge erteilen | Kriegsrat im Thronsaal / Lagetafel jeder Region | `J` |
| Weltkarte (3D-Kriegstisch), Legionen | Kriegsrat | `M` |
| Diplomatie | Kriegsrat | `P` |
| Finanzen & Erlasse | Albedos Pult | `V` |
| Wächter ansehen, Audienz gewähren, ausrüsten | Wächter ansprechen (`E`) | `U` |
| Nazarick: Ausbau, Schatzkammer, Wochenziele, Errungenschaften | Albedos Pult | `N` |
| Zeit vergehen lassen (1 Tag / Woche / Monat, Zeitfluss anhalten) | Thron | `T` |
| Reisen | Gate | `G` |
| Depesche öffnen | – | `Enter` |
| Chronik · Speichern · Menü · Vollbild | – | `C` · `F5` · `Esc` · `F11` |

**Der Kreislauf**

1. **Auftrag wählen** – Hauptaufträge (★) treiben die Story voran, Nebenaufträge (◆) bringen Ressourcen, Vorschläge (✧) stammen von deinen Untertanen selbst.
2. **Vollstrecker wählen** – jede Kachel zeigt die Erfolgsaussicht. Manche Aufträge kann nur ein bestimmter Charakter erledigen.
3. **Befehlsart wählen**: *Freie Hand*, *Im Verborgenen*, *Gnadenlos*, *Diplomatisch*, *Mit höchster Eile*.
   Die Tafel warnt dich, wenn ein Charakter dazu neigt, einen Befehl **eigenmächtig auszulegen** (Shalltear und „diskret“ … nun ja), und zeigt seinen **eigenen Stil** bei *Freier Hand* (Demiurge: „Der Große Plan“).
4. **Zeit vergehen lassen.** Sie stoppt automatisch, sobald eine **Depesche** eintrifft: Bericht, Ereignis, Eigeninitiative oder Vorschlag.
5. **Reagieren** – loben, belohnen, tadeln oder schweigen. Jede Reaktion hat Folgen – besonders bei Albedo und Shalltear.

**Ressourcen**: Macht · Wissen · Ruf · Stimmung · Gold · **Aufmerksamkeit** (wie sehr die Welt auf Nazarick aufmerksam wird – hohe Werte locken gefährliche Mächte an) · **Effizienz der Guardians** (aus Stimmung, Gunst und Erschöpfung).

**Die Herzen der Wächterinnen**: Albedo und Shalltear sehnen sich nach Eurer Aufmerksamkeit – Lob, Geschenke und Aufträge steigern ihre Gunst, Vernachlässigung senkt sie (und lässt sie unüberlegt handeln). Ihre Rivalität untereinander ist seit Version 2.5 kein eigenes Spielsystem mehr: kein Eifersuchtswert, kein Streit im Thronsaal, keine Intrigen gegeneinander. Vernachlässigte Untertanen ergreifen dafür häufiger eigenmächtig die Initiative.

**Die Strategie-Ebene**

- **Weltkarte [M]** – 13 Regionen mit Einfluss, Unruhe und täglichen Einkünften. Regionen müssen erst erkundet werden; Einfluss wächst durch Aufträge (mit abnehmendem Ertrag), Grausamkeit erzeugt Unruhe und Aufstände.
- **Reichsverwaltung [V]** – Finanzübersicht (Einkünfte je Region, Unterhalt für Grab, Einsätze, Erlasse und Legionen) und **Erlasse**: zehn Regierungsentscheidungen mit laufenden Kosten und Wirkungen, begrenzte Plätze, und jeder Wächter hat eine Meinung dazu.
- **Diplomatie [P]** – 8 Fraktionen (Königreich Re-Estize, Baharuth-Kaiserreich, Slane-Theokratie, Argland-Rat, Zwerge, Heiliges Königreich Roble, Elfenkönigreich) mit Beziehung, Furcht und Verträgen: Geschenke, Handelsabkommen, Nichtangriffspakt, Machtdemonstration, Tribut, Vasallentum, Frieden, Krieg. Gesandtschaften führt ein Wächter aus – Albedo verhandelt brillant, Shalltear … eher nicht. Fraktionen reagieren auf Ruf und Aufmerksamkeit, schicken eigene Gesandte und erklären bei Hass den Krieg.
- **Legionen & Schlachten** – Skelette, Todesritter, Liche, Seelenfresser, Todesreiter … im Grab ausheben, einen Wächter zum Feldherrn ernennen (er fehlt dann für Aufträge), über das Wegenetz marschieren lassen (die Heere ziehen sichtbar über die Karte, mit eigener Zeitsteuerung), Regionen erobern oder feindliche Heere abfangen. Jede Schlacht kann Ainz **persönlich in 3D** schlagen – oder per Taktik dem Feldherrn überlassen.
- **Bedrohungen mit Frist** – Inquisition, Spione, Aufstände, Abenteurer-Expeditionen, der Platin-Drache: Wer nicht rechtzeitig reagiert, verliert Gebiete, Gold und Ansehen.
- **Lageberichte** – Mitten im Auftrag melden sich die Untertanen mit Komplikationen: Zeugen, starke Gegner, Doppelagenten … du entscheidest über Risiko, Dauer und Methode – oder lässt dem Wächter freie Hand.
- **Teams** – zwei Untertanen gemeinsam entsenden; Synergien (Aura + Mare, Albedo + Demiurge) und Konflikte (Albedo + Shalltear, Demiurge + Sebas).
- **Vier Schwierigkeitsgrade** – von *Gnädiger Herrscher* bis *Albtraum von Nazarick* (Startgold, Einkünfte, Unterhalt, Bedrohungen, Feindstärke).
- **Kapitelziele** verlangen neben Story-Entscheidungen auch Einfluss, Ressourcen und Zeit – das Reich muss wirklich wachsen.

**Das Große Grab wächst mit – „nur noch eine Woche …“**

- **Wächter-Ränge I–X** – jeder Auftrag, jede Schlacht und jede Audienz bringt Erfahrung. Ein Rangaufstieg (vom *Getreuen* bis zur *Legende von Nazarick*) erhöht alle Werte und stärkt die Legion, die der Wächter führt. Fanfare inklusive.
- **Artefakte & Schatzkammer** – 35 Artefakte in fünf Seltenheiten (*Gewöhnlich, Selten, Episch, Legendär, Weltklasse*): Triumphe, Schlachten, gebannte Bedrohungen, Errungenschaften und Albedos Truhe bringen Beute. Jeder Wächter hat Waffe, Rüstung und Kleinod; Lieblingsstücke (Spuhletit-Lanze für Shalltear, Frosthellebarde für Cocytus …) wirken stärker. Überzählige Funde lassen sich einschmelzen.
- **Ausbau der Ebenen** – 10 Bauwerke × 3 Stufen (Grabkammern, Gletscher, Amphitheater, Lavahölle, Königliche Gemächer, Bibliothek von Ashurbanipal, Schatzkammer, Golemschmiede …): billigere Legionen, stärkere Heere, mehr Erfahrung, Gold, Wissen, Audienzen, Beute. Immer nur ein Bauprojekt zugleich – jede Entscheidung zählt.
- **Albedos Wochenziele** – jede Woche drei neue Ziele mit Belohnung; wer alle erfüllt, öffnet **Albedos Truhe** (Gold + garantiert seltenes Artefakt). Aufeinanderfolgende Wochen bauen eine **Serie** auf, die die Truhe immer wertvoller macht.
- **45 Errungenschaften** in Bronze, Silber, Gold und Platin – mit Belohnungen bis hin zu einem Weltgegenstand.

**Story**: 11 Kapitel – *Die Ankunft · Das Dorf Carne · Der Dunkle Held · Blutiger Wahnsinn (der Shalltear-Zwischenfall) · Frost über dem Sumpf · Gehenna · Das Zauberkönigreich · Die Hallen von Feo Jera · Das Heilige Königreich · Der Wald der Elfen · Der Platin-Drachenlord* – mit einem **Epilog**, der sich aus deinen Entscheidungen zusammensetzt (Weltordnung, Ruf, Vasallen, Albedo & Shalltear, das Schicksal jedes Wächters). Danach geht die Herrschaft endlos weiter. Dazu 42 Aufträge (10 Haupt-, 15 Neben-, 17 Vorschlagsaufträge), 33 Ereignisse und 23 Eigeninitiativen, mit Verzweigungen (Carne retten oder ignorieren, Name „Ainz Ooal Gown“ annehmen oder Momonga bleiben, Shalltear selbst stellen oder Albedo schicken …).

Spielstände liegen in `user://saves/` (Windows: `%APPDATA%\Godot\app_userdata\Overlord – Herrscher von Nazarick\saves`).

---

## Projektstruktur

```
project.godot              Projekt (Autoloads, Theme, Compatibility-Renderer)
scenes/
  title_screen.tscn        Titelbildschirm (3D-Kamerafahrt durch den Thronsaal)
  world_3d.tscn            die begehbare Welt (Hauptszene des Spiels)
scripts/
  autoload/
    content.gd             lädt data/*.json
    game.gd                Spielzustand & Spiellogik (Aufträge, Zeit, Emotionen, Depeschen)
    world.gd, military.gd, diplomacy.gd   Regionen/Wirtschaft, Legionen/Schlachten, Fraktionen
    progress.gd            Ränge, Artefakte, Ausbau, Wochenziele, Errungenschaften
  world3d/
    world_3d.gd            Third-Person-Welt: Orte laden, HUD, Interaktion, Echtzeit, Depeschen, Kampf-HUD
    player_3d.gd           Ainz/Momon: Steuerung, Kamera, Kampf, Lock-on, Zauber
    model_lib.gd           findet/lädt .glb-Modelle (auch zur Laufzeit)
    character_rig.gd       Modell oder Ersatzfigur + Animationssteuerung
    proc_model.gd          prozedurale Ersatzfiguren mit Gelenken
    actor_3d.gd            Figuren als Portrait-Aufsteller, Interaktionsobjekte
    loot_drop.gd           Beute zum Aufheben (Lichtsäule in Seltenheitsfarbe)
    location_builder.gd    Rezepte der 20 Orte (Thronsaal, Gletscher, Stadt, Wald …)
    b3.gd                  3D-Baukasten (Materialien, Primitive mit Kollision, Licht, Partikel)
  combat/
    fighter.gd             Kämpfer-Basis: Zustandsautomat, Werte, Treffer, Status
    hitbox.gd, hurtbox.gd  Trefferzonen
    enemy_3d.gd            Gegner-KI: Verhaltensarten, Reaktionen, Fern-/Flächen-/Beschwörungsangriffe, Bossphasen
    combat_director.gd     Gruppenregie: Angriffsrechte, Kreisplätze, Alarm
    combat_fx.gd           Treffergefühl: Partikel, Trefferstopp, Zeitlupe, Kamera, Zahlen, Raumklang
    spell_fx.gd            Inszenierung der Zauber (Geschosse, Explosionen, Blitze, Herzgriff, Superrang)
    slash_fx.gd            Hiebspuren · ground_mark.gd Bodenwarnungen und Magiekreise · hit_react.gd Zurückzucken, Verbeugen, Knien
    projectile.gd          Geschosse (Lenkung, Pfeilflug)
    soul_orbs.gd           Seelen besiegter Gegner fliegen zu Ainz
    save_system.gd         JSON-Speichern/Laden (3 Slots)
  story/
    story_mission.gd       spielbare Story-Momente: Szenen, Wellen, Bosse (Einführung, Schwellen, Aufgeben), Verbündete
    cutscene.gd            Filmszenen: Kamera relativ zu Figuren, Figuren, Effekte, Entscheidungen
    story_fx.gd            Gate, Großbrand, Schutzkuppel, Schwarzes Loch, Tageszeit-Stimmungen
  scenes/                  Skripte der Szenen
  ui/
    palette.gd             zentrale Farbpalette
    nazarick_theme.gd      erzeugt das Theme (→ assets/ui/nazarick_theme.tres)
    ui_fx.gd               Tween-Animationen (Einblenden, Pop-in, Hover, Pulsieren, Schreibmaschine)
    portrait.gd            Portrait mit Rahmen; Bild-Asset oder prozeduraler Platzhalter
    guardian_card.gd       Statuskarte eines Wächters
    throne_visual.gd       gezeichneter Thron mit dem Overlord
    background.gd          Shader-Hintergrund + Partikel
    overlay.gd             Basisklasse modaler Fenster
    dispatch_dialog.gd     Berichte / Ereignisse / Vorschläge
    mission_board.gd       Auftragstafel
    character_view.gd      Charakter-Details & Audienzen
    chronicle_view.gd, save_load_dialog.gd, portrait_button.gd, stat_bar.gd
data/
  characters.json          Charaktere: Werte, Stimme, Gefühle, Reaktionen, Vorschläge
  missions.json            Aufträge (Haupt, Neben, Vorschläge)
  events.json              Story-, Zufalls- und Rivalitätsereignisse + Eigeninitiativen
  story.json               Kapitel und Befehlsarten
  story_missions.json      spielbare Story-Einsätze (Schritte und Szenen als Daten)
  grimoire.json            Zauberbuch: Seelen, Zauberränge, Sonderwirkungen, Ringe
  regions.json, factions.json, systems.json   Strategie-Ebene
  progression.json         Ränge, Artefakte, Ebenen, Wochenziele, Errungenschaften
  locations.json           begehbare 3D-Orte, Story-Figuren, Begegnungen
  combat.json              Kampfstile, Angriffe, Zauber, Gegner
  models.json              Einstellungen & Animationsnamen für 3D-Modelle
assets/
  ui/                      Theme, Schriften (Cinzel, Cormorant Garamond, DejaVu – alle frei lizenziert)
  shaders/                 Hintergrund-Shader
  characters/              ← hier Portraits ablegen
  backgrounds/             ← hier Hintergründe ablegen
tools/                     Theme-Builder, Simulations- und UI-Tests
```

---

## Grafik

Das Spiel kommt ohne 2D-Artworks aus:

- **Maßstab**: Menschen sind 1,6–1,85 m groß (`ProcModel.HUMAN`), Ainz 2 m, Cocytus 2,5 m; Häuser, Laternen und Marktstände der Ortsmodelle sind in Metern gebaut. Die Kamera hat 54° senkrechtes Sichtfeld.
- **Figuren** werden prozedural aus `data/figures.json` gebaut (Hautfarbe, Frisur, Kleidung, Hörner, Flügel, Schwanz, Waffe, Sonderformen wie Cocytus, Pandora's Actor oder Hamsuke) und durch `assets/models/characters/<id>.glb` ersetzt, sobald vorhanden.
- **Portraits** in Dialogen, Berichten und Menüs sind **3D-Renders** dieser Figuren (`PortraitStudio`, einmal je Figur erzeugt; Stimmung färbt das Kantenlicht).
- **Orte, Himmel und Weltkarte** sind prozedural; Gebäude/Requisiten lassen sich durch `assets/models/props/*.glb` ersetzen, ganze Orte durch `assets/models/locations/*.glb`.
- **UI**: Schriften, Ornamentrahmen (`assets/ui/frames/`) und Icons (`assets/ui/icons/`, inkl. `item_<id>` und `frame_<seltenheit>` für Artefakte).

Eine Liste gewünschter Modelle und Icons steht in `docs/ASSET_WUNSCHLISTE.txt`.

**Grafikqualität** (Einstellungen → Grafik, `scripts/world3d/graphics_quality.gd`):

| Stufe | Was sie tut | Bildrate (RTX 3060 Ti, 3440×1440, FSR 2 77 %) |
|---|---|---|
| **Ultra** | alles in voller Qualität (kontaktgehärtete PCSS-Schatten, globale Beleuchtung in voller Auflösung) | Städte 47–56, Wälder 37–40 FPS |
| **Hoch** (Standard) | im Bild wie Ultra: PCSS mit halb so vielen Abtastungen, GI in halber Auflösung, SDFGI mit 8 Strahlen, Spiegelungen/SSIL/Nebel etwas gröber | Städte 54–62, Wälder 43–47 FPS |
| **Ausgewogen** | zusätzlich gefilterte PCF-Schatten, Schattenkarte 2048, keine Spiegelungen in der Natur, Gras und Bäume wechseln früher in ihre fernen Detailstufen | Städte 62–66, Wälder 54–61 FPS |

Keine Stufe reduziert die Dreiecke der Modelle. Messen: `LOC=bench BENCHLEVELS=2,1,0 godot res://tools/world3d_test.tscn` (mit `BENCHSHOT=1` Bilder bei angehaltener Zeit, `BENCHAB=1` Kosten je Effekt, `BENCHINFO=1` Dreiecksverteilung).

---

## Inhalte erweitern

Alle Inhalte sind JSON – neue Aufträge, Ereignisse oder Charaktere brauchen **keinen Code**.

**Neuer Auftrag** (`data/missions.json`):

```json
{
  "id": "s_beispiel", "title": "Der verfluchte Turm",
  "category": "Erkundung", "location": "Azerlisia-Gebirge",
  "description": "…", "days": 4, "difficulty": 55,
  "weights": {"intellekt": 2, "kampf": 1},
  "recommended": ["aura"],
  "rewards": {"info": 8, "gold": 50},
  "requires": {"chapter_min": 3},
  "on_success": {"set_flags": ["turm_erkundet"]},
  "outcomes": {"triumph": "…", "success": "…", "partial": "…", "failure": "…"},
  "char_outcomes": {"shalltear": {"success": "Text in Shalltears Stimme …"}}
}
```

Optionale Felder: `main`, `repeatable`, `required_char`, `forced_tier`, `followup_event`, `replace_report_with_event`, `failure`, `proposal` + `proposal_text` + `proposal_requires` (Vorschläge erscheinen nur, wenn ein Charakter sie unterbreitet – dazu die ID in `proposals` des Charakters eintragen).

**Neues Ereignis** (`data/events.json`): `type` ist `story` (einmalig, sobald `trigger` erfüllt), `random` (gewichtet, mit `cooldown`/`once`) oder `chain` (nur über `queue_events`/`followup_event`). Jede Wahl (`choices`) hat `label`, `effects`, `reaction`, optional `variant` (`primary`, `danger`, `success`, `warning`) und `requires`.

**Bedingungen** (`requires`, `trigger`): `chapter`, `chapter_min/max`, `day_in_chapter_min`, `flags_all/none/any`, `res_min/max`, `jealousy_min`, `favor_min/max`, `idle`, `unlocked`, `missions_done`.

**Effekte** (`effects`, `on_success`, `on_trigger`): `res`, `chars` (favor/mood/fatigue), `set_flags`, `clear_flags`, `unlock_missions`, `unlock_chars`, `status`, `lord_name`, `log`, `queue_events`.

**Platzhalter in Texten**: `{lord}` → „Momonga-sama“ bzw. „Ainz-sama“, `{lord_full}` → voller Name. Texte unterstützen BBCode (`[i]`, `[b]`, `[color=#ff2a4f]…[/color]`).

**Neuer Charakter**: Eintrag in `data/characters.json` nach dem Muster der vorhandenen (Werte, `voice`, `reactions`, `audience`, optional `emotion` + `rival` für eifersüchtige Charaktere, `deviations` für eigenmächtige Auslegungen, `style` für Freie Hand). Mit `"unlocked": false` startet er gesperrt und wird per Effekt `unlock_chars` freigeschaltet.

**Theme ändern**: Farben in `scripts/ui/palette.gd`, Stile in `scripts/ui/nazarick_theme.gd`, danach neu bauen:

```bash
godot --headless --path . --script res://tools/build_theme.gd
```

---

## Tests

```bash
# Spielt 6 Partien mit zufälligen Entscheidungen bis zum Ende, prüft Speichern/Laden
godot --headless --path . res://tools/sim_test.tscn
# 3D-Rauchtest: Titel, alle Orte, Kampf, Audienz, Kriegstisch, persönliche Schlacht; Screenshots nach tools/screenshots3d/
godot --path . res://tools/world3d_test.tscn     # LOC=<ort> | combat | title | gallery (alle Figuren + Portraits)
# Welt-Prüfungen: Türen, Ausstattung, Controller, Handel, Bemerkungen, Kodex, Feinschliff, Verliese, freie Bodenpunkte
LOC=doors DOORLOC=e_rantel DOORID=gilde godot --path . res://tools/world3d_test.tscn   # LOC=dresscheck | pad | trade | barks | kodex | polish | dungeon
LOC=probe PROBE="e_rantel:30,28;katze:20,16" godot --path . res://tools/world3d_test.tscn   # Strahl auf den Boden (Körpername, Höhe, Neigung)
TOD=0.8 WEATHER=rain LOC=stageview STAGEVIEW="e_rantel:0,14;katze:map" godot --path . res://tools/world3d_test.tscn   # Rundblicke zu fester Tageszeit/Wetter
godot --headless --path . res://tools/combat_test.tscn   # Kampfsystem + .glb-Laden
# Story-Einsatz automatisch durchspielen (Szenen, Kämpfe, Entscheidung; Screenshots alle n Zeilen)
LOC=story STORY=sm_carne STORYCHOICE=0 STORYSHOTS=3 godot --path . res://tools/world3d_test.tscn   # STORYDISPATCH=1 | STORYREPLAY=1
```

---

*Nicht-kommerzielles Fan-Projekt. „Overlord“ © Kugane Maruyama / KADOKAWA. Schriften: Cinzel & Cormorant Garamond (SIL OFL), DejaVu Sans (freie Lizenz).*
