# Spieltest 2.13 – Mängelliste und Stand

Spieltest des Nutzers vom 25.10.2026 (Version 2.13). Jeder Punkt wird einzeln geprüft, behoben und mit Bild kontrolliert.
Legende: [ ] offen · [~] in Arbeit · [x] erledigt (Version)

## Global (alle Orte)
- [x] Partikel ohne Textur: Lampen, Fackeln, Feuerschalen, Glut und Staub erscheinen als Quadrate (Thronsaal, Lava …)
      → Flammen sind jetzt Flammenzungen per Shader (assets/shaders/fx/flame.gdshader), Funken und Lichtstaub weiche,
        kleine Punkte; Ursachen der Quadrate: Partikel ohne Textur, Glow in grober Auflösung (1/32), Punktlichter im
        Volumennebel (Raster 48³) – alle drei behoben; alte einfarbige Laub-/Insekten-Rechtecke entfernt
- [~] Wetter: Regen sind Rechtecke, Schnee sind Dreiecke/Quadrate – weiche Tropfen, Schlieren und Flocken
      → Regen als Schlieren (fx_streak, senkrecht), Schnee als runde Flocken (fx_dot) – im Bild noch prüfen
- [x] Treppen/Tore zwischen den Ebenen Nazaricks: schwebende Laternen mit Schild und schwebendem Text → echte Treppenabgänge
      → Treppenportal aus dunklem Marmor mit Goldkanten, Stufen hinab in den Schacht, Name auf dem Sturz; im Thronsaal an
        die Rückwand bzw. Seitenwand gesetzt; keine schwebenden Namen mehr über Objekten (Türen, Gate, Thron …)
- [x] Gate (Teleport) ist ein Platzhalter → richtiges Gate-Portal
      → Ellipse aus wirbelnder Finsternis mit ausgefranstem, violett glühendem Rand (gate_portal.gdshader), Dunst am Fuß
- [~] Entdeckungen (Steintafeln, Inschriften, Schreine) stehen mitten im Weg → an Wände/Wegränder, passender aussehen; begehbare Schreine
      → Nazarick: jede Inschrift an festem Platz in passender Gestalt (Hinweistafeln am Teppich, Särge mit Kerzen,
        Lesepult in der Regalnische, Notiz auf dem Lesetisch, Bartisch, Dienstplan, Warnschild, Wandtafel); keine Schreine
        in Nazarick; Wandtafeln nur noch an Wänden über Kopfhöhe (nicht an Stufen, Sockeln); Außenorte folgen
- [ ] Beutekisten und Beutel liegen wahllos mitten im Weg (auch dort, wo sie keinen Sinn ergeben, z. B. Nazarick, Amphitheater)
- [ ] Beute ohne Textur (Knochenstaub, Blut, Klingensplitter …) → echte kleine Modelle mit Textur
- [x] Keine Gegner in Nazarick (Gruft, Ebenen) – Nazarick ist Zuhause
      → Skelette der Grabkammern und Todesritter der Lava sind keine Gegner mehr (Todesritter steht als Wache); der
        Übungsgolem im Amphitheater bleibt
- [x] Rauchsäulen mitten im Weg (Grabkammern: entfernt)
- [x] Lichtsäulen mitten im Ort (Gletscher …)
      → waren Ersatz-Kristalle (zwei grell leuchtende Prismen, weil kein Kristallmodell da ist): im Gletscher entfernt,
        der Ersatz-Kristall ist überall eine Gruppe aus Eisnadeln mit Eis-Shader und nur schwachem Glimmen
- [~] Rote Lichter ohne Sinn (Re-Estize …)
      → Prüfung LOC=lights (Re-Estize nachts, 147 Lichter): keine roten Lichtquellen; rote Kreise am Boden sind
        Angriffswarnungen der Gegner (Flügelschlag, Flächenangriffe) – bitte bei Bedarf mit Bild nachmelden
- [~] Lange Ladezeiten (Grabkammern, Gletscher, Lava, E-Rantel, Re-Estize) → messen und verkürzen
      → Messung je Schritt (LOADPROF=1): 60–75 % gingen in die Kollision (eine Dreiecksform je Mesh-Instanz, jeder Baum
        einzeln vermessen) → Formen je Mesh geteilt, Stammpunkte je Baumart: Kollision Re-Estize 15,7 → 3,1 s,
        Grabkammern 11,2 → 2,4 s, Carne 5,4 → 2,7 s; Gletscher 8,7 → 5,4 s (Modell vereinfacht)
- [~] Aus der Welt fallen beim Verlassen des Ortes (Dschungel, Carne, …) → Grenzen an allen Orten
      → Grenzen folgen dem Boden des Ortsmodells (4 m nach innen, 400 m hoch), dazu ein Sicherheitsnetz (40 m unter
        der letzten sicheren Stelle zurück); Lauftest LOC=walk: Dschungel in fünf Richtungen ohne Absturz – übrige Orte folgen
- [x] Gras verschwindet je nach Blickrichtung/Bewegung und taucht wieder auf
      → jede 16-m-Kachel sprang bei 20 m schlagartig auf 28 % der Büschel; jetzt dünnt das Gras je Büschel stufenlos
        nach Entfernung aus (Shader), Kacheln verschwinden erst hinter dem Einsinken
- [x] Texturlose Felsbrocken („große Kartoffeln“) im Grasland und in Carne
      → es waren die Heuhaufen (zwei glatte gelbe Kugeln): jetzt Heustöcke aus trockenem Gras mit Haube, Stange und
        losem Heu am Fuß (11 Stück in Grasland, Carne, Re-Estize …)
- [x] Nachts zu dunkel (Re-Estize)
      → Mondlicht heller, Umgebungslicht nachts aus einer kühlen Mondlichtfarbe statt aus dem fast schwarzen Himmel,
        Belichtung nachts ×1,35 und ein schattenloses Fülllicht von der Gegenseite des Mondes (abgewandte Hausseiten
        waren schwarz) – im Bild geprüft (Re-Estize bei Regen und Nacht)
- [~] Festhängen an Ausstattung/Trümmern (Marktplatz Re-Estize …) → Begehbarkeit je Ort prüfen
      → Prüfwerkzeug LOC=trap (an jedem freien Punkt acht Richtungen laufen): Markt Re-Estize 161 Punkte, 2 Fallen an
        Hauswänden (keine auf dem Markt selbst); übrige Orte folgen
- [x] Bewohner laufen auf Dächern (E-Rantel): nur noch Wegpunkte mit freiem Weg, Bodenstrahl knapp über den Füßen
- [ ] Gegner spawnen sofort (Friedhof) → erst mit Auftrag bzw. nachts
- [x] Nach jeder Ankunft flogen weiße Funken und Punkte durchs Bild (Vorwärmen der Kampfeffekte hinter dem Ladeschleier,
      Funken bis 16 m/s, zwei Sekunden lang) → durchsichtig und nach wenigen Bildern wieder entfernt
- [x] Idee: Minikarte im HUD und eine Ortskarte mit wichtigen Gebäuden
      → nach jedem Ortsaufbau wird der Ort einmal senkrecht von oben aufgenommen (in Hallen knapp unter der Decke, also
        als Grundriss); Minikarte unten rechts (Ausschnitt ±46 m, Norden oben, Pfeil in Blickrichtung, Zeichen wie im
        Kompass), Lageplan mit Taste L: ganzer Ort mit Namen von Gate, Türen, Häusern, Figuren, Truhen und Funden

## Nazarick
- [x] Thronsaal: Lampen mit Quadrat-Effekten, Treppen, Gate, Steine im Weg
- [x] Grabkammern: lange Ladezeit; Ankunft vor einem halben Objekt (Treppe mit Podest); Kiste im Weg; Gegner (raus);
      Rauchsäulen im Weg; Beute ohne Textur; nur Shalltear – ihre Vampirbräute fehlen
      → halbes Treppenstück entfernt, Gate und Portale an der Stirnwand, Lücke dahinter zugemauert, keine Gegner, keine
        Rauchsäulen, drei Vampirbräute bei Shalltear, Särge mit Kerzen an der Rückwand (Ladezeit 12 s steht bei „Ladezeiten“)
- [x] Eisgletscher: lange Ladezeit; verschneite Bäume flackern; Eis sieht nicht gut aus; Lichtsäule mitten drin;
      Kisten/Blut/Splitter ohne Textur; Cocytus' Schrein gut, aber Wand dahinter schlecht und er steht verkehrt herum; Löwe falsch platziert
      → Ladezeit 8,7 → 5,4 s (Statuen 450 000 → 70 000 Dreiecke, Eisklippen vereinfacht, Bäume wieder in Instanzgruppen);
        Fichten: Schnee im Laubmaterial statt Überzug über ganze Blattkarten (weiße Rechtecke, Flackern), Stämme mit Rinde;
        Eis: Felsen behalten Struktur unter dem Eis, Kristalle mit Maserung, See als blankes Eis mit Verwehungen;
        Tempelplatz eben (versank im Hang), schwarze Plattenwand → Krone aus Eiskristallen, Löwe (einseitige Fläche des
        Schreinmodells) entfernt, Zierpodest weg; Cocytus bleibt auf seinem Posten und blickt zum Eingang (schlenderte
        vorher umher und stand oft mit dem Rücken zum Spieler); Treppenportale aus bereiftem Fels mit Schneekappen;
        Inschriften als gefrorener Todesritter im Eisblock und als Schneekugel mit Häuschen
- [x] Dschungel/Amphitheater: Gate-Ausgang führt aus der Welt; Beute ohne Sinn (auch im Amphitheater); begehbarer Schrein;
      Steintafeln mitten im Weg
      → Grenzen am Bodenrand, Lauftest ohne Absturz; Früchte und Leuchtkäfer nur noch im Wald zwischen Arena und Ringweg
        (Sperrkreise um Arena und Ankunftsweg, locations.json → spots); Schreine gibt es in Nazarick nicht mehr; die
        Inschrift ist jetzt ein Bäumchen mit Holzschild „Gepflanzt von Mare – NICHT gießen!“ am Wegrand;
        Treppenportale aus Moosstein mit Bronze
- [x] Lava: lange Ladezeit; Lava ohne gute Textur; zwei Fackeln mit Quadrat-Effekten
      → zwei 120-m-Platzhalterflächen des Unreal-Exports lagen über der Lava (ausgeblendet); Lava-Shader neu: treibende
        Krustenschollen mit scharfen, glühenden Rissen, seltene offene Felder mit Adern und Krustenfetzen; die Risse
        verschwinden bei flachem Blick hinter den Schollen (verschmolzen vorher zu einer orangen Fläche), Kruste fast
        schwarz; Feuerschalen mit glimmenden Kohlen statt gelber Scheibe; Rauch aus weichen Wolken; Glut langsamer;
        Treppenportale aus Basalt mit Kupfer – Ladezeit 8,4 s bleibt (großes Felsmodell), steht bei „Ladezeiten“
- [x] Königliche Gemächer: nur die üblichen Punkte
      → Gate stand hinter der Wand (unerreichbar) → in die Halle; die Treppenportale steckten in der Wand → die
        Doppeltüren des Modells sind die Türen, mit Namensschild und Feuerschale; Bartisch und Dienstplan an festen Plätzen
- [x] Bibliothek: Teppiche mitten im Raum falsch platziert
      → neun kurze Läufer mit eingerolltem Ende im 7-m-Takt entfernt, ein durchgehender Läufer im Mittelgang; die
        Eingangswand hatte eine 10-m-Lücke ins Nichts (hinter dem Gate) → geschlossen, Treppenportal bündig an der Wand
- [x] Schatzkammer: Ankunft mitten in einer Treppe, man hängt fest
      → Ankunft unten auf dem Absatz vor der Treppe; überall wird der Ankunftspunkt jetzt auf den Boden gesetzt
- [ ] Grasland um Nazarick: texturlose Brocken; Leistung prüfen

## Neue Welt
- [ ] Carne: Regen ohne Textur; texturlose Brocken; Gras verschwindet; aus der Welt fallen
- [x] E-Rantel: lange Ladezeit; Häuser viel zu klein (Schilder fast so groß wie Häuser); Bewohner laufen auf Dächern;
      wahllos platzierte Gegenstände; riesige Hügel direkt vor der Stadt; Lücken in der Stadtmauer; Bauernhäuser im Berg
      → neu gebaut (build_erantel.py): Häuser ×1,35, Rathaus und Gilde größer, Mauerstücke füllen jeden Abschnitt
        (vorher 1 m Lücke je Abschnitt), Gelände vor der Stadt sanft (Hügel 10 → 4 m, flach bis 112 m), Gehöfte auf
        ebenen Plätzen, weniger Kleinkram vor den Häusern; Bewohner nur noch auf freien Wegen; Kollision schneller
- [x] Friedhof: Gegner erst mit Auftrag/nachts; Skelettdrache bewegt sich völlig falsch
      → Skelette und Bogenschützen erheben sich nachts oder sobald der Auftrag des Friedhofswärters läuft (beim Annehmen
        vor Ort sofort), der Lich nur nachts
      → Skelettdrache neu geriggt (build_dragon.py): die Quelle lag schon richtig (Kopf -Y, Flügel ±X), das Skript
        drehte sie um 90°, spiegelte den vermeintlich hängenden Flügel – in Wahrheit Kopf/Schwanz, der Drache hatte zwei
        Schwänze – und das Skelett lag quer im Körper (Wirbelsäule in den Flügeln, er lief seitwärts). Jetzt Skelett nach
        gemessenen Merkmalen (Kopf, Schwanzspitze, vier Füße, Flügelansatz); Lauf, Biss, Flügelschlag, Tod geprüft
- [x] Re-Estize: lange Ladezeit; Löcher in der Mauer; Häuser zu klein; Kellerluke der Acht Finger ist nur ein Schild am
      Boden → echter Eingang; nachts zu dunkel; kaputte Objekte und Kisten auf dem Markt; man hängt fest
      → neu gebaut (build_recapital.py): Häuser ×1,35, Mauer ohne Lücken, sanftes Umland; Kellerabgang der Acht Finger
        an einer Hauswand (schräge Doppeltür, ein Flügel offen, Laterne, Fässer); Nacht heller; Ladezeit Kollision
        15,7 → 3,1 s; Markt: 161 Punkte ohne Falle (LOC=trap); Banner, Statuen und Laternen,
        die durch die größeren Häuser in Wänden standen, neu gesetzt (Burgweg mit Bannern zu beiden Seiten)
- [ ] Alle übrigen Orte einzeln prüfen (Baharuth, Roble, Theokratie, Tob-Wald, Elfen, Sumpf, Katze, Azerlisia, Drachen …)

## Wunsch: begehbares Azerlisia-Gebirge
- [ ] Feo Jera als begehbarer Berg: Abstieg zu den Zwergen, Hauptstadt mit den Quagoa, zweite Zwergenstadt, Weg mit den Drachen
