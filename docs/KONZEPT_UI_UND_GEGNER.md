# Konzept: UI-Neugestaltung und Gegner-Varianten

Stand 2026-10-17. Ziel: Die Oberfläche soll zur neuen Grafik passen (dunkler Luxus von Nazarick statt
„Debug-Kästen“), und Gegner wie der Skelettkrieger bekommen sichtbar unterschiedliche Varianten bis hin zu Raritäten.

## 1. UI – Leitbild „Obsidian & Gold“

Vorbilder: Diablo IV (Ornamentrahmen, Kugeln), Elden Ring (minimales HUD), Baldur's Gate 3 (Dialoge, Karten).

**Bildsprache**
- Flächen: schwarzes, leicht durchscheinendes Obsidian-Glas mit feinem Rauschen und Vignette statt flacher grauer Kästen.
- Rahmen: dünne Goldkante mit Eck-Ornamenten (9-Slice), aktiv/hover mit violettem Leuchten (Nazarick-Violett).
- Schrift: Cinzel für Titel, Cormorant Garamond für Fließtext (sind schon da), Zahlen in Cinzel mit Tabellenziffern.
- Bewegung: alles blendet/gleitet weich ein (Tween 0,15–0,25 s), Knöpfe mit Hover-Glanz und Klickgeräusch.

**HUD in der 3D-Welt (aufgeräumt)**
- Unten links: Leben/Mana/Ausdauer als schlanke, ornamentierte Balken mit nachlaufendem „Schadensbalken“.
- Unten Mitte: Zauberleiste mit runden Slots, radialem Cooldown, Tastenbeschriftung, Leuchten bei Bereitschaft.
- Oben Mitte: Kompassband (Ziele, Gate, NPCs) statt des großen Kopfbalkens; Ort/Tag erscheint nur beim Betreten.
- Rechts: kompakter Auftrags-Tracker (max. 3 Zeilen, halbtransparent); Wochenziele/Herzenskrieg erst auf Taste.
- Steuerungshilfe: nur beim ersten Besuch, danach per F1. Meldungen als kurze „Toasts“, die von selbst verschwinden.
- Schadenszahlen, Gegner-Namensschild mit Raritätsfarbe, Ziel-Lebensbalken beim Lock-on.

**Menüs**
- Hauptmenü: Thronsaal als lebender Hintergrund (vorhanden), Menü als goldgerahmte Säule links, Logo animiert.
- Charakter/Wächter: große 3D-Vorschau der Figur (Portrait-Studio rendert schon), daneben Werte als Karten.
- Dialoge: Kinobalken oben/unten, Namensschild, Porträt, Antworten als Karten mit Symbol (Drohung, List, Gnade …).
- Weltkarte: der vorhandene 3D-Kartentisch, dazu Pergament-Tooltips.

**Umsetzung**
1. Theme neu (`assets/ui/nazarick_theme.tres`): StyleBoxes aus einem Shader (Obsidian-Glas + Goldkante + Ecken) –
   auflösungsunabhängig, keine verpixelten Texturen. Dazu 9-Slice-Ornamente als Vektor/SVG.
2. HUD-Bausteine als eigene Szenen (Balken, Slot, Kompass, Toast, Namensschild).
3. Danach jede Ansicht (`scripts/ui/*.gd`, ~4200 Zeilen) auf die neuen Bausteine umstellen.
4. Optional: kostenlose Fab-UI-Pakete (Fantasy-GUI-Rahmen, Icons) prüfen und übernehmen.

## 2. Gegner-Varianten (Beispiel Skelett)

Ein Grundmodell (Mixamo-Rig, alle Animationen) + **Ausrüstung an Knochen** + **Material/Leuchten** + **Raritätsstufe**:

| Variante | Aussehen | Rolle |
|---|---|---|
| Skelett (Standard) | blanke Knochen | Schwarm, wenig Leben |
| Skelettkrieger | rostiger Helm, Rundschild, Schwert | Nahkampf, blockt |
| Skelettbogenschütze | Kapuze, Bogen, Köcher | Fernkampf |
| Skelettmagier | zerschlissene Robe, Stab, violette Augen | Zauber |
| Elite: Todesritter-Knappe | schwarze Plattenrüstung, glühende Augen | stark, selten |
| Rar: Goldenes Skelett | vergoldete Knochen, Funkeln | Beute-Bonus |
| Rar: Frost- / Blut-Skelett | Reif-/Blutleuchten, Partikelaura | Spezialangriffe |

**Raritäten:** Gewöhnlich (weiß) · Veredelt (grün) · Selten (blau) · Episch (violett) · Legendär (gold) – Farbe am
Namensschild, Aura-Partikel, etwas größere Statur, bessere Beute.

**Technik:** `data/models.json` bekommt `variants` (Basis-Modell, Farbe/Emission, Anbauteile je Knochen
`mixamorig:Head`/`RightHand`/`LeftForeArm`, Aura). `CharacterRig` hängt die Teile per `BoneAttachment3D` an –
ein Rig, beliebig viele Varianten. Anbauteile: Waffen/Rüstungsteile aus den Fab-Paketen (z. B. Fantasy Castle Ritter)
oder eigene KI-Modelle.

**Wo du helfen kannst:** Für die Elite/Raren sehen eigene Modelle am besten aus (wie bei Ainz & Co.). Sinnvoll wären
z. B. „Skelettkrieger mit Rüstung“, „Skelettmagier“, „Todesritter“ – Rest (Standard, Gold/Frost/Blut, Bogen) baue ich
über Anbauteile und Materialien.
