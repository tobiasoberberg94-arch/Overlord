#!/usr/bin/env bash
# Startet Overlord TV im Android-TV-Emulator, bedient es per Tastenereignis
# und speichert Screenshots nach shots/.
set -x
mkdir -p shots
shot() { sleep "${2:-3}"; timeout 30 adb exec-out screencap -p > "shots/$1.png"; echo "shot $1 $(date +%T)"; }
key() { for k in "$@"; do timeout 15 adb shell input keyevent "$k"; sleep 0.8; done; }
longkey() { timeout 15 adb shell input keyevent --longpress "$1"; sleep 0.8; }
start() { timeout 30 adb shell am start "$@"; }

# Lokaler Demo-Server (aus Sicht des Emulators: 10.0.2.2)
setsid nohup python3 .github/scripts/serve.py demo </dev/null >/dev/null 2>&1 &
BASE="http://10.0.2.2:8000/"

adb install -r dist/overlord-tv.apk || exit 0
adb shell settings put global stay_on_while_plugged_in 7 || true

# Startseite mit Beispieldaten
start -n de.overlord.tv/.MainActivity --ez overlord_demo true --es demo_base "$BASE"
shot 01-start 25
key KEYCODE_DPAD_RIGHT;                     shot 02-weiterschauen 4
key KEYCODE_DPAD_DOWN;                      shot 03-anbieter 5
key KEYCODE_DPAD_RIGHT KEYCODE_DPAD_RIGHT;  shot 04-webseite 5
key KEYCODE_MENU;                           shot 05-bearbeiten 3
key KEYCODE_BACK
key KEYCODE_DPAD_DOWN;                      shot 06-bibliothek 3
key KEYCODE_DPAD_DOWN;                      shot 07-einstellungen 3
key KEYCODE_DPAD_UP KEYCODE_DPAD_UP KEYCODE_DPAD_RIGHT KEYCODE_DPAD_RIGHT KEYCODE_DPAD_RIGHT KEYCODE_DPAD_RIGHT
key KEYCODE_DPAD_CENTER;                    shot 08-hinzufuegen 3
key KEYCODE_BACK

# Eingebauter Browser
start -a android.intent.action.VIEW -d "https://www.arte.tv/de/" -n de.overlord.tv/.BrowserActivity
shot 09-browser 25
key KEYCODE_DPAD_DOWN KEYCODE_DPAD_DOWN KEYCODE_DPAD_RIGHT; shot 10-linkmodus 3
key KEYCODE_MENU;                           shot 11-zeigermodus 2
longkey KEYCODE_MENU;                       shot 12-browsermenue 3
key KEYCODE_BACK KEYCODE_BACK

# Video-Seite mit Player-Leiste
start -a android.intent.action.VIEW -d "${BASE}watch.html?ep=3" -n de.overlord.tv/.BrowserActivity
shot 13-video 15
key KEYCODE_MEDIA_PLAY_PAUSE;               shot 14-playerleiste 2
key KEYCODE_DPAD_RIGHT KEYCODE_DPAD_RIGHT KEYCODE_DPAD_RIGHT; shot 15-playerleiste-knopf 1
key KEYCODE_BACK
longkey KEYCODE_MENU;                       shot 16-browsermenue-video 3
key KEYCODE_BACK KEYCODE_BACK KEYCODE_BACK KEYCODE_BACK

# Nativer Player (Browser-Menü → „Video nativ abspielen“)
start -a android.intent.action.VIEW -d "${BASE}watch.html?ep=3" -n de.overlord.tv/.BrowserActivity
sleep 12
longkey KEYCODE_MENU
key KEYCODE_DPAD_DOWN KEYCODE_DPAD_DOWN KEYCODE_DPAD_CENTER; shot 17-nativer-player 8
key KEYCODE_MENU;                           shot 18-player-optionen 3
key KEYCODE_BACK KEYCODE_BACK KEYCODE_BACK KEYCODE_BACK

# Video-Ansicht: Demo-Mediathek als TV-Oberfläche, Folge wählen → Kino-Modus
start -a android.intent.action.VIEW -d "${BASE}index.html" -n de.overlord.tv/.BrowserActivity --ez video true
shot 23-videoansicht 10
key KEYCODE_DPAD_RIGHT;                     shot 24-videoansicht-karte 3
key KEYCODE_DPAD_DOWN KEYCODE_DPAD_DOWN;    shot 25-videoansicht-folgen 3
key KEYCODE_DPAD_UP KEYCODE_DPAD_UP KEYCODE_DPAD_CENTER; shot 26-kinomodus 14
key KEYCODE_BACK;                           shot 27-zurueck-zur-uebersicht 4
key KEYCODE_BACK KEYCODE_BACK KEYCODE_BACK

# Serien-Aufbau: Staffeln, Folgentabelle, Versionen am Player
start -a android.intent.action.VIEW -d "${BASE}serie.html?staffel=1" -n de.overlord.tv/.BrowserActivity --ez video true
shot 30-serie-folgen 10
key KEYCODE_DPAD_DOWN;                      shot 31-serie-staffeln 3
key KEYCODE_DPAD_UP KEYCODE_DPAD_RIGHT KEYCODE_DPAD_CENTER; shot 32-folge-kino 12
key KEYCODE_BACK;                           shot 33-folge-versionen 4
key KEYCODE_BACK KEYCODE_BACK KEYCODE_BACK KEYCODE_BACK

# Video-Ansicht auf einer echten Seite (arte.tv)
start -a android.intent.action.VIEW -d "https://www.arte.tv/de/" -n de.overlord.tv/.BrowserActivity --ez video true
shot 28-videoansicht-arte 16
key KEYCODE_DPAD_DOWN;                      shot 29-videoansicht-arte-2 4
key KEYCODE_BACK KEYCODE_BACK KEYCODE_BACK

# Echte legale Mediatheken (ARD, ZDF, arte): Übersicht → Serie (Staffeln/Folgen) → Folge → Kino-Modus → Zurück.
# Serie und Folge hat find-series.sh vorher auf dem Runner gesucht (series.txt).
n=40
[ -s series.txt ] || printf '%s\n' "ard|https://www.ardmediathek.de/serien||" "zdf|https://www.zdf.de/serien||" "arte|https://www.arte.tv/de/||" > series.txt
mapfile -t SITES < series.txt
for line in "${SITES[@]}"; do
  IFS='|' read -r name over serie folge <<<"$line"
  [ -z "$name" ] && continue
  echo "== $name: $over | ${serie:-–} | ${folge:-–}"
  timeout 20 adb shell am force-stop de.overlord.tv < /dev/null
  start -a android.intent.action.VIEW -d "$over" -n de.overlord.tv/.BrowserActivity --ez video true
  shot "$n-$name-uebersicht" 18; n=$((n+1))
  key KEYCODE_DPAD_DOWN;                    shot "$n-$name-uebersicht-2" 3; n=$((n+1))
  if [ -n "$serie" ]; then
    start -a android.intent.action.VIEW -d "$serie" -n de.overlord.tv/.BrowserActivity
    shot "$n-$name-serie" 18; n=$((n+1))
    key KEYCODE_DPAD_DOWN;                  shot "$n-$name-serie-2" 3; n=$((n+1))
  fi
  if [ -n "$folge" ]; then
    start -a android.intent.action.VIEW -d "$folge" -n de.overlord.tv/.BrowserActivity
    shot "$n-$name-folge" 16; n=$((n+1))
    key KEYCODE_DPAD_CENTER;                shot "$n-$name-kino" 16; n=$((n+1))
    key KEYCODE_BACK;                       shot "$n-$name-zurueck" 5; n=$((n+1))
  fi
done
timeout 20 adb shell am force-stop de.overlord.tv < /dev/null

# Suche und Handy-Fernbedienung
start -n de.overlord.tv/.MainActivity --es open_search "Expedition"
shot 19-suche 8
key KEYCODE_BACK
start -n de.overlord.tv/.MainActivity --ez show_phone true
shot 20-handy-qr 6
key KEYCODE_BACK

# Jellyfin-Demo-Server
start -n de.overlord.tv/.MainActivity --ez open_library true
shot 21-jellyfin 25
key KEYCODE_DPAD_DOWN;                      shot 22-jellyfin-reihen 6

pkill -f "serve.py demo" || true
echo "===== ERKENNUNG (Video-Ansicht) ====="
timeout 30 adb logcat -d -v brief -s OverlordVV:I | grep -v "zwischen" | tail -n 160
echo "===== LOGCAT (Fehler) ====="
timeout 30 adb logcat -d -v brief AndroidRuntime:E System.err:W '*:S' | tail -n 120
ls -la shots
exit 0
