# Overlord – Streaming-Hub für Fire TV

Eine schlanke Fire-TV-App, die mehrere Streaming-Anbieter auf einem Startbildschirm bündelt.

![Kacheln](https://img.shields.io/badge/Fire%20TV-Fire%20OS%205%2B-orange)

## Funktionen

- **Kachel-Startbildschirm**, voll mit der Fernbedienung steuerbar
- **Crunchyroll** und **Prime Video** sind vorinstalliert – die offiziellen Apps werden direkt gestartet
  (ist eine App nicht installiert, öffnet sich der Amazon Appstore)
- **Eigene Kacheln hinzufügen** (Kachel „+“):
  - *Webseite* – wird im eingebauten TV-Browser geöffnet
  - *Installierte App* – jede App auf dem Fire TV als Kachel
- **Eingebauter TV-Browser** mit Maus-Cursor für Webseiten, die nicht für Fernbedienungen gemacht sind
  - Steuerkreuz: Cursor bewegen (am Bildschirmrand wird gescrollt, gedrückt halten = schneller)
  - OK: klicken
  - Menü-Taste (☰): Cursor an/aus
  - ⏪ / ⏩: seitenweise scrollen
  - Zurück: vorherige Seite / Vollbild verlassen / Browser schließen
  - Vollbild-Videos werden unterstützt, Pop-ups und `intent://`-Werbelinks werden blockiert
- Kacheln **bearbeiten**: Kachel auswählen und **Menü-Taste** oder **OK lange drücken** →
  Umbenennen, URL ändern, verschieben, Farbe ändern, entfernen

## APK bekommen

Bei jedem Push baut GitHub Actions automatisch die APK:

1. Im Repo auf **Actions → Build APK** → letzten Lauf öffnen
2. Unter *Artifacts* `Overlord-FireTV-apk` herunterladen und entpacken

Lokal bauen (Android SDK nötig):

```bash
./gradlew assembleRelease
# -> app/build/outputs/apk/release/app-release.apk
```

## Auf den Fire TV installieren (Sideload)

1. Fire TV: **Einstellungen → Mein Fire TV → Entwickleroptionen**
   → *Apps unbekannter Herkunft* (bzw. für die „Downloader“-App) aktivieren.
   (Entwickleroptionen erscheinen nach 7× Klicken auf *Info → Name des Fire TV*.)
2. Variante A – **Downloader-App**: APK z. B. als GitHub-Release hochladen und die URL im Downloader öffnen.
3. Variante B – **ADB** vom PC (Fire TV und PC im selben WLAN, *ADB-Debugging* an):
   ```bash
   adb connect <IP-des-Fire-TV>:5555
   adb install -r app-release.apk
   ```

Die App erscheint danach unter **Apps & Kanäle**.

## Projektstruktur

```
app/src/main/java/de/overlord/tv/
  MainActivity.kt   Startbildschirm mit Kacheln, Hinzufügen/Bearbeiten
  WebActivity.kt    TV-Browser mit Fernbedienungs-Cursor und Vollbild-Video
  Tile.kt           Kachel-Modell + Speicherung (SharedPreferences)
```

Keine externen Bibliotheken – nur Android-Framework + Kotlin. Läuft ab Fire OS 5 (API 22).
