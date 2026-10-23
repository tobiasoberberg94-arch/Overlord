# Welt-Überarbeitung – Stand und Fortschritt

Ziel: eine Welt, in der man stehen bleibt und sich umsieht (siehe Masterprompt des Entwicklers, Oktober 2026).
Dieses Dokument hält fest, was je Ort erledigt ist und was noch offen ist. Stand: 2026-10-23.

## Gameplay-Bereinigung (erledigt)
- **Herzenskrieg entfernt**: kein Rivalitätswert, keine Eifersucht, keine sieben Rivalitäts-Ereignisse mehr
  (`rv_*`), keine Eifersuchts-Nebenwirkungen bei Lob, Geschenken und Aufträgen, kein Rivalitäts-Meter im HUD.
  Geblieben: Gunst, Stimmung und Erschöpfung, die liebevollen/vernachlässigten Bemerkungen von Albedo und
  Shalltear, die Krönungs- und Schuld-Ereignisse. Errungenschaft „Frieden im Harem“ → „Zwei Herzen“.
  Alte Spielstände werden beim Laden bereinigt (`Game._normalize`).

## Innenräume (System erledigt, Räume laufend)
- Türen in Orten: `data/locations.json` → `doors` [{id, to, name, at, yaw}]; Innenräume sind eigene Orte mit
  `group: "interior"` und `parent`. Schild mit Namen und Laterne an jeder Tür; „Verlassen“ bringt den Spieler vor
  dieselbe Tür zurück. Innenräume werden prozedural gebaut (`scripts/world3d/interiors.gd`) aus Fotomaterialien
  und Fotoscan-Requisiten; eigene Entdeckungen je Raum (`data/discoveries.json` → `placed`).
- Fertig: Abenteurergilde E-Rantel (Empfang, Auftragstafel, Schankstube, Büro des Gildenmeisters, Lager,
  Trophäenwand, Rangtafel, Chronik), Gasthaus Goldener Pavillon (Tresen, Kamin, Empore mit Zimmertüren und
  Gästebuch, Zimmer 3 von Momon und Nabe, Gepäck-Versteck), Apotheke Bareare (Tresen mit Waage, Tränke-Regale,
  Kessel, Werkstatt, Hinterzimmer, Nfireas Platz, Geheimvorrat), Enris Haus in Carne (Herd, Betten, Goblin-Horn,
  Nemus Zeichnungen, lose Diele).
- Offen: Schmiede und Tempel in E-Rantel, Gebäude der Königshauptstadt (Palast, Acht Finger), Arwintar
  (Magierakademie), Kathedrale der Theokratie, Feo Jera (Schmieden der Zwerge), Dorfschenke in Carne.

## Proportionen (erledigt)
- Menschen 1,6–1,85 m (vorher ~2,1 m, so groß wie Laternen): `ProcModel.HUMAN = 0.84`. Ainz, Wächter mit Modell und
  Sonderformen unverändert. Sichtfeld der Kamera 54° statt 68° (Häuser wirkten zu klein), Kameraabstand 7 m.

## Orte – Prüfung je Ort (laufend)
| Ort | Stand | Offen |
|---|---|---|
| E-Rantel | Türen zu Gilde, Gasthaus, Apotheke; Marktplatz mit Bewohnern | Schmiede, Tempel, Viertel stärker unterscheiden (Armenviertel vs. Händler), Stadtmauern-Erlebnis |
| Carne | Enris Haus begehbar | Goblin-Lager, Schenke, Spuren des Überfalls (Kapitel 2) |
| übrige 20 Orte | unverändert seit 2.4 | Einzelprüfung: Wahrzeichen, Geheimnisse, Beute-Plätze, Belebung |
