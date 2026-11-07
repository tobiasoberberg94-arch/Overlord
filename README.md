# Overlord TV

Eine Streaming-Startseite für den **Amazon Fire TV** (Fire OS 5+, Android 5.1 / API 22+), geschrieben in Kotlin.
Sie bündelt Streaming-Apps, beliebige Webseiten und die eigene Jellyfin-Bibliothek auf einer Oberfläche.
Alles lässt sich mit der Fire-TV-Fernbedienung bedienen, ein Touchscreen ist nicht nötig.

> Eigenes Logo (Krone + Ring) und eigene Farben (Violett/Cyan). Keine Logos oder Marken anderer Anbieter.

| Startseite | Kachel bearbeiten | Player-Leiste |
|---|---|---|
| ![Startseite](https://github.com/tobiasoberberg94-arch/Overlord/releases/latest/download/01-start.png) | ![Bearbeiten](https://github.com/tobiasoberberg94-arch/Overlord/releases/latest/download/05-bearbeiten.png) | ![Player-Leiste](https://github.com/tobiasoberberg94-arch/Overlord/releases/latest/download/14-playerleiste.png) |

*Die Bilder entstehen bei jedem Build automatisch in einem Android-TV-Emulator (GitHub Actions).*

---

## Funktionen

### Anbieter
- **Crunchyroll** und **Prime Video** sind feste Kacheln und starten die offiziellen Apps
  (Prime Video: `com.amazon.firebat` auf Fire TV, sonst `com.amazon.amazonvideo.livingroom`, `com.amazon.avod.thirdpartyclient`, `com.amazon.avod`).
  Ist eine App nicht installiert, öffnet sich der Amazon Appstore (Fallback: Play Store bzw. Webseite).
- **Eigene Kacheln:** beliebige **Webseite** (öffnet im eingebauten Browser) oder beliebige **installierte App**.
  Die Kachelfarbe einer App wird automatisch aus ihrem Symbol berechnet.
- **Bearbeiten** über ☰ oder langes Drücken von OK: öffnen, umbenennen, URL ändern, Beschreibung ändern,
  verschieben (◀ ▶, OK zum Beenden), **Reihe ändern** (eigene Reihen wie „Anime“ oder „Mediatheken“ anlegen),
  Farbe ändern, entfernen, im externen Browser öffnen bzw. im Appstore anzeigen.
  Entfernte feste Kacheln lassen sich unter *Einstellungen → Feste Kacheln* wiederherstellen.

### Oberfläche
- Dunkles Design mit großem Bereich oben: Titel, Info-Chips, Beschreibung, Fortschritt und Tastenhinweise
  der gewählten Kachel. Hintergrund und Lichtschein färben sich passend zur Kachel bzw. zum Titelbild.
- Darunter horizontale Reihen mit 16:9-Karten. Die gewählte Karte wird größer und bekommt einen Rahmen,
  die gewählte Reihe rutscht nach oben, die übrigen Reihen treten zurück.
- Kopfzeile mit Uhr, Datum und den Knöpfen **Suchen** und **Handy** (mit ▲ aus der ersten Reihe erreichbar).
- **Webseiten-Kacheln gestalten sich selbst:** Vorschaubild (`og:image`), Symbol (`apple-touch-icon`)
  und Markenfarbe (`theme-color`) werden automatisch geladen und auf dem Gerät zwischengespeichert.
- Eigene TV-Dialoge statt grauer Android-Fenster: Seitenmenü mit Symbolen, Eingabe-Karten,
  Farbwahl als Farbkreise, App-Auswahl als Raster.
- Schrift **Inter**, Symbole im Material-Stil, kurzes Logo-Intro beim Start.
- **Zuletzt besucht:** eigene Reihe mit den zuletzt im Browser geöffneten Seiten (inkl. Artwork),
  per ☰ als Kachel speicherbar.

### Weiterschauen
- Eigene Reihe ganz oben mit angefangenen Videos aus dem eingebauten Browser, mit Fortschrittsbalken und Restzeit.
- Ein Klick öffnet die Seite, startet den Player automatisch und springt an die letzte Stelle,
  **auch wenn der Player in einem iframe einer fremden Domain steckt**.
- Videos unter 5 Minuten (Werbung) werden ignoriert, ab 95 % gilt ein Video als fertig und verschwindet aus der Liste.
- Optionen je Eintrag (☰): *Weiterschauen*, *Von vorne beginnen*, *Webseite öffnen*, *Aus der Liste entfernen*.
- Die Karten zeigen das Vorschaubild des Videos (Poster) bzw. der Seite.

### Komfort beim Schauen
- **Player-Leiste** mit runden Symbol-Knöpfen: −10 s · Play/Pause · +10 s · Nächste Folge ·
  Intro +85 s · Tempo (0,75× – 2×) · Vollbild · Nativ.
- **Intro & Werbung automatisch überspringen:** Knöpfe wie „Intro überspringen“, „Skip Recap“ oder
  „Werbung überspringen“ werden automatisch gedrückt – auch im eingebetteten Player (abschaltbar im Browser-Menü).
- **Nächste Folge automatisch:** Am Ende eines Videos startet nach einem 10-Sekunden-Countdown die nächste Folge
  (abbrechen mit Zurück; abschaltbar).
- **Textgröße pro Webseite** (80–200 %) und **Ansicht pro Webseite** (Mobil, Desktop oder Smart-TV),
  gemerkt je Domain – ebenso der zuletzt genutzte Steuerungsmodus (Links/Zeiger/Normal).
- Das Browser-Menü zeigt, wie viele Werbe-Anfragen auf der Seite blockiert wurden.

### Handy-Fernbedienung
- *Einstellungen → Handy-Fernbedienung* (oder **Handy** in der Kopfzeile) zeigt einen **QR-Code** und eine PIN.
- Mit der Handy-Kamera scannen – ohne App-Installation öffnet sich eine Steuerseite im Handy-Browser (gleiches WLAN):
  - **Fernbedienung** mit Steuerkreuz, OK, Zurück, Start, ☰ (lang = Optionen) und Mediatasten
  - **Tippen:** Text landet im aktiven Eingabefeld – im Overlord-Dialog oder direkt im Formular der Webseite
    (Benutzername, Passwort, Suche …), optional mit Enter
  - **Öffnen:** Links vom Handy auf dem Fernseher öffnen oder direkt als Kachel speichern
  - **Mehr:** Weiterschauen-Liste und Kacheln antippen, um sie auf dem TV zu starten
- Geschützt durch eine 4-stellige PIN (neu erzeugbar), Sperre nach mehreren Fehlversuchen.
- **Sicherung:** Kacheln, Weiterschauen, Verlauf und Einstellungen als Datei herunterladen und
  (z. B. auf einem zweiten Fire TV) wieder einspielen.

### Selbst-Update & Design
- Overlord TV prüft regelmäßig das Release `latest` (Datei `version.json`) und meldet neue Versionen.
  Unter *Einstellungen → Update* wird die neue APK heruntergeladen und über den System-Installer eingespielt –
  ohne Downloader-App. (Einmalig „Apps aus unbekannten Quellen“ für Overlord TV erlauben.)
  Manuell: *Einstellungen → Info*, dann ☰.
- *Einstellungen → Design*: Akzentfarben wählen (Overlord, Ozean, Rubin, Smaragd, Sonne, Mitternacht) –
  gilt auch für die Link-Markierung im Browser.

### Weitere Einstellungen
- **Autostart:** Overlord TV startet beim Einschalten des Fire TV automatisch
  (ab Android 10 / Fire OS 8 mit der Berechtigung „Über anderen Apps einblenden“).
- **Werbeblocker-Statistik:** wie viele Werbe-Anfragen heute blockiert wurden.
- **Verlauf leeren**, **Weiterschauen leeren**, **feste Kacheln wiederherstellen**.

### Suche
- **Globale Suche** über *Suchen* in der Kopfzeile, die Suchtaste oder vom Handy:
  findet passende Kacheln, Weiterschauen-Einträge und Jellyfin-Titel – und schickt den Begriff auf Wunsch
  **direkt an die Suche jeder Webseiten-Kachel** („Auf Arte suchen“ öffnet Arte und sucht dort).

### Abspielen auf Webseiten („Scraper“)
- Der Browser erkennt Video-Streams einer Seite automatisch: Netzwerk-Anfragen auf `.m3u8`, `.mp4`, `.webm` usw.
  sowie die Quelle des gerade laufenden `<video>`, auch in iframes.
- Erscheint „🎬 Video erkannt“, startet *☰ lang → Video nativ abspielen* (oder **▶ Nativ** in der Player-Leiste)
  den Stream im eigenen, schlanken Vollbild-Player. Referer, Cookies und User-Agent werden übernommen.
  Dort gibt es keine Seiten-Werbung, keine Overlays, dafür schnelles Spulen und gespeicherten Fortschritt.
- Im nativen Player öffnet ☰ die Optionen: **Tempo**, **Audiospur**, **Untertitel** (eingebettete Spuren),
  **Schlaf-Timer** (15–90 Min.) und *Von vorne beginnen*.
- Kann der Stream nicht direkt abgespielt werden (z. B. abgelaufener Token), öffnet sich automatisch wieder die Webseite an der richtigen Stelle.
- **Nächste Folge:** sucht passende Knöpfe („Nächste Folge“, „Next episode“, Player-Next-Buttons in iframes).
  Gibt es keinen, wird die Folgennummer in der Adresse hochgezählt (`…/episode-5` → `…/episode-6`, `s01e05` → `s01e06`).

### Werbe- und Pop-up-Blocker im eingebauten Browser
- Blockiert Werbe-Domains: eingebaute Liste plus die öffentliche **StevenBlack-Hosts-Liste**.
  Die Liste wird wöchentlich im Hintergrund aktualisiert (JobScheduler, ohne Zusatzbibliothek)
  und lässt sich unter *Einstellungen → Werbeblocker* sofort aktualisieren.
- Blockiert `window.open`-Pop-ups, Pop-unders, neue Fenster auf fremde Domains und automatische Umleitungen ohne Klick.
  Die zuletzt blockierte Adresse lässt sich bei Bedarf über *☰ lang → Blockiert – trotzdem öffnen* aufrufen.
- **Startet ein Video auf einer Seite nicht?** *☰ lang → Schutz auf … ausschalten* deaktiviert Blocker und Overlay-Filter nur für diese Domain (wird gespeichert, lässt sich dort wieder einschalten).
- DRM-geschützte Web-Videos (Widevine) werden im eingebauten Browser freigegeben.
- Blendet Werbebanner und unsichtbare Klickflächen über der Seite aus, auch in iframes.
  Das Skript wird per `androidx.webkit` **`addDocumentStartJavaScript`** in alle Frames eingeschleust.
  Ältere WebViews ohne diese Funktion bekommen es als Fallback nach dem Laden der Seite in den Hauptframe.

### Optional: Jellyfin
- Anmeldung unter *Medienbibliothek → Jellyfin verbinden* mit Server-Adresse (z. B. `http://192.168.1.10:8096`), Benutzer und Passwort.
- Bibliothek im gleichen Reihen-Layout: *Weiterschauen*, *Als Nächstes*, *Neu in …* und alle Titel jeder Bibliothek,
  mit Covern, Serien → Staffeln → Folgen.
- Eigener Player: zuerst Direktwiedergabe, bei nicht unterstütztem Format automatisch HLS vom Server.
  Der Fortschritt wird an Jellyfin gemeldet (Weiterschauen auf allen Geräten).
  Am Ende einer Folge startet nach 10 Sekunden automatisch die nächste.
- Alles über die offizielle Jellyfin-REST-API. **Plex** ist nicht eingebaut.

---

## Tastenbelegung

| Taste | Startseite | Eingebauter Browser | Nativer Player / Jellyfin |
|---|---|---|---|
| Steuerkreuz | Karte wählen (▲ aus der ersten Reihe: Suchen / Handy) | **Link-Modus:** zum nächsten Link in der Richtung springen · **Zeiger-Modus:** Zeiger bewegen (halten = schneller, am Rand wird gescrollt) | ◀ ▶ spulen (halten = schneller), ▲ ▼ Infoleiste |
| OK | öffnen / starten | gewählten Link als echten Tipp anklicken (funktioniert auch bei Playern in iframes) | Play/Pause |
| OK lang | Kachel bearbeiten | Browser-Menü | – |
| ☰ | Kachel bearbeiten | Modus wechseln: Links → Zeiger → Normal | Optionen: Tempo, Audiospur, Untertitel, Schlaf-Timer |
| ☰ lang | – | Browser-Menü: Schnellsuche, Adresse, Video nativ abspielen, blockierte Seite öffnen, Schutz an/aus, Steuerung, Intro/Werbung überspringen, nächste Folge automatisch, Kachel speichern, extern öffnen, Desktop-Ansicht, Textgröße, neu laden | – |
| Suche | globale Suche | – | – |
| ⏯ | – | Play/Pause (auch im iframe) und Player-Leiste einblenden | Play/Pause |
| ⏪ / ⏩ | – | 10 s spulen (halten = 30 s); läuft kein Video, wird die Seite gescrollt | spulen |
| Zurück | – | Leiste ausblenden → Vollbild verlassen → vorherige Seite → Startseite | Beenden (Position wird gespeichert) |

**Player-Leiste:** Sobald ein Video läuft, erscheint unten eine große Leiste mit
−10 s · Play/Pause · +10 s · Nächste Folge · Intro +85 s · Tempo · Vollbild · Nativ.
◀ ▶ wählt einen Knopf, OK führt ihn aus, ▲ oder Zurück blendet die Leiste aus.
Im Vollbild steuert das Steuerkreuz direkt das Video (◀ ▶ spulen, OK Pause).

**Schnellsuche:** *☰ lang → Schnellsuche* schickt einen Suchbegriff an das Suchfeld der aktuellen Webseite.
Eingabe über die Bildschirmtastatur oder deren Mikrofon (bzw. Android-Spracherkennung, falls vorhanden).
Findet sich kein Suchfeld, wird mit `site:` über DuckDuckGo innerhalb der Seite gesucht.

---

## Installation auf dem Fire TV

### APK herunterladen
Jeder Push baut über GitHub Actions eine installierbare APK:
- **Actions → „APK bauen“ → gewünschter Lauf → Artifact `overlord-tv-apk`** (ZIP mit `overlord-tv.apk`).
- Bei jedem Push wird die APK zusätzlich als Release **`latest`** veröffentlicht:
  `https://github.com/tobiasoberberg94-arch/Overlord/releases/latest/download/overlord-tv.apk`
  (der direkte Download klappt nur, wenn das Repository öffentlich ist).

### Variante A: Downloader-App
1. Auf dem Fire TV: *Einstellungen → Mein Fire TV → Entwickleroptionen → Apps unbekannter Herkunft*
   für **Downloader** erlauben. Sind die Entwickleroptionen versteckt: *Mein Fire TV → Info* öffnen und 7× auf den Gerätenamen klicken.
2. Die App **Downloader** (von AFTVnews) aus dem Appstore installieren.
3. In Downloader die Release-Adresse oben eingeben (oder einen eigenen Link, z. B. per Kurz-URL), herunterladen und **Installieren** wählen.
4. Overlord TV erscheint unter *Apps*. Für den Startbildschirm: App markieren → ☰ → *Nach vorne verschieben*.

### Variante B: adb
1. *Entwickleroptionen → ADB-Debugging* einschalten, IP-Adresse unter *Mein Fire TV → Info → Netzwerk* nachsehen.
2. Am Rechner:
   ```bash
   adb connect 192.168.1.50:5555      # IP des Fire TV
   adb install -r overlord-tv.apk
   ```
3. Die Verbindung beim ersten Mal auf dem Fernseher bestätigen.

Updates lassen sich ohne Deinstallation über die alte Version installieren, weil alle Builds mit demselben Schlüssel signiert sind.

---

## Technik

- Kotlin, nur Android-Framework + **`androidx.webkit`** (keine Leanback-, Glide-, ExoPlayer- oder Coroutines-Bibliothek).
- `minSdk 22`, `targetSdk 34`, Fire-TV-Banner 320×180 (`drawable-xhdpi/banner.png`), `LEANBACK_LAUNCHER`,
  Touchscreen als optional deklariert.
- Aufbau:

| Datei | Inhalt |
|---|---|
| `MainActivity.kt` | Startseite, Kacheln, Bearbeiten/Verschieben, Einstellungen |
| `RowsView.kt` | Hero-Bereich, Reihen, Karten (Fokus-Animation, Farbverlauf) |
| `BrowserActivity.kt` | WebView, Blocker, Link-/Zeiger-Modus, Player-Leiste, Schnellsuche, Stream-Erkennung |
| `assets/overlord.js` | In alle Frames eingeschleustes Skript (Pop-ups, Overlays, Video-Steuerung, Link-Navigation, Suche) |
| `PlayerActivity.kt` | Eigener Player (VideoView) für Web-Streams und Jellyfin, nächste Folge, Spuren, Schlaf-Timer |
| `TvDialogs.kt`, `Ui.kt` | Design-System: Farben, Schrift, Seitenmenü, Eingabe-, Farb- und App-Dialoge |
| `SiteMeta.kt`, `ImageLoader.kt` | Artwork für Webseiten (og:image, Symbol, Markenfarbe), Bild-Cache |
| `Companion.kt`, `assets/companion.html`, `QrCode.kt` | Handy-Fernbedienung: Webserver mit PIN, Handy-Seite, QR-Generator |
| `SearchActivity.kt`, `History.kt` | Globale Suche, Verlauf „Zuletzt besucht“ |
| `LibraryActivity.kt`, `Jellyfin.kt` | Jellyfin-Bibliothek und REST-Client |
| `AdBlock.kt` | Domain-Blocker, Hosts-Liste, wöchentlicher Hintergrund-Job |
| `ContinueStore.kt`, `Tiles.kt` | Speicherung von Weiterschauen und Kacheln |

**Selbst bauen:** JDK 17 und Android SDK (Plattform 35) installieren, dann `./gradlew assembleRelease`.
Die APK liegt danach unter `app/build/outputs/apk/release/app-release.apk`.

**Signatur:** Der mitgelieferte Schlüssel `app/overlord.keystore` (Passwort `overlord`) ist öffentlich und nur für die eigene Installation gedacht.
Einen eigenen Schlüssel nutzt der Build über die Umgebungsvariablen
`OVERLORD_KEYSTORE`, `OVERLORD_KEYSTORE_PASSWORD`, `OVERLORD_KEY_ALIAS` und `OVERLORD_KEY_PASSWORD`.

**Hinweis:** Werbeblocker und Stream-Erkennung sind für Seiten gedacht, deren Inhalte du rechtmäßig ansehen darfst.
DRM-geschützte Streams (z. B. Widevine bei großen Anbietern) lassen sich nicht nativ abspielen. Dafür sind die offiziellen Apps da.
