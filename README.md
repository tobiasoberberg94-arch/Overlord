# Overlord – Streaming-Hub für Fire TV

Eine schlanke Fire-TV-App, die mehrere Streaming-Anbieter auf einem Startbildschirm bündelt.

![Kacheln](https://img.shields.io/badge/Fire%20TV-Fire%20OS%205%2B-orange)

## Funktionen

- **Startseite im Streaming-Look**: großer Hero-Bereich mit Infos zur ausgewählten Kachel,
  darunter horizontale Reihen – komplett mit der Fernbedienung bedienbar
- **Weiterschauen**: Folgen, die du im eingebauten Browser angefangen hast, erscheinen in einer
  eigenen Reihe mit Fortschrittsbalken und laufen an der letzten Stelle weiter
  (Videos unter 5 Minuten – Werbung/Trailer – werden ignoriert, fertig geschaute fliegen raus)
- **Crunchyroll** und **Prime Video** sind vorinstalliert – die offiziellen Apps werden direkt gestartet
- **Eigene Kacheln** (Karte „+ Hinzufügen“): beliebige Webseite oder installierte App
- **Werbe- & Pop-up-Blocker** im eingebauten Browser:
  - Werbe-Domains werden geblockt (eingebaute Liste + StevenBlack-Hosts-Liste, wöchentlich aktualisiert)
  - `window.open`-Pop-ups, Pop-unders und Umleitungen auf fremde Domains ohne Klick werden verhindert
  - typische Werbebanner und unsichtbare Klick-Fänger werden ausgeblendet – auch in Player-iframes
- **Fernbedienungs-Steuerung** im Browser:
  - **Link-Modus** (Standard): Steuerkreuz springt von Link zu Link, OK klickt
  - **Cursor-Modus**: Steuerkreuz bewegt einen Zeiger (z. B. für Player-Knöpfe)
  - **☰ Menü**: Modus wechseln (Links → Cursor → Normal)
  - **⏯ Play/Pause**: Video starten/pausieren – auch wenn der Player in einem iframe steckt
  - **⏪ / ⏩**: 10 s spulen (bei laufendem Video) bzw. seitenweise scrollen
  - **Zurück**: Vollbild verlassen / vorherige Seite / Startseite
- Kacheln **bearbeiten**: Karte auswählen und **☰** oder **OK lange drücken**

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
  MainActivity.kt   Startseite (Hero + Reihen), Hinzufügen/Bearbeiten
  WebActivity.kt    TV-Browser: Link-/Cursor-Steuerung, Pop-up-Filter, Vollbild-Video
  AdBlocker.kt      Domain-Blockliste
  HistoryStore.kt   Weiterschauen (Video-Fortschritt pro Seite)
  Tile.kt           Kachel-Modell + Speicherung
app/src/main/assets/
  inject.js         läuft in jeder Seite/jedem iframe: Werbung ausblenden, Video-Fortschritt,
                    Play/Pause-Befehle, Link-Navigation
```

Einzige Abhängigkeit: `androidx.webkit`. Läuft ab Fire OS 5 (API 22).
