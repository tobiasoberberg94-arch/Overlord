#!/usr/bin/env bash
# Startet Overlord TV im Android-TV-Emulator, bedient es per Tastenereignis
# und speichert Screenshots nach shots/.
set -x
mkdir -p shots
shot() { sleep "${2:-3}"; adb exec-out screencap -p > "shots/$1.png"; }
key() { for k in "$@"; do adb shell input keyevent "$k"; sleep 0.8; done; }
longkey() { adb shell input keyevent --longpress "$1"; sleep 0.8; }

# Lokaler Demo-Server (aus Sicht des Emulators: 10.0.2.2)
(cd demo && nohup python3 -m http.server 8000 >/dev/null 2>&1 &)
BASE="http://10.0.2.2:8000/"

adb install -r dist/overlord-tv.apk || exit 0
adb shell settings put global stay_on_while_plugged_in 7 || true

# Startseite mit Beispieldaten
adb shell am start -n de.overlord.tv/.MainActivity --ez overlord_demo true --es demo_base "$BASE"
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
adb shell am start -a android.intent.action.VIEW -d "https://www.arte.tv/de/" -n de.overlord.tv/.BrowserActivity
shot 09-browser 25
key KEYCODE_DPAD_DOWN KEYCODE_DPAD_DOWN KEYCODE_DPAD_RIGHT; shot 10-linkmodus 3
key KEYCODE_MENU;                           shot 11-zeigermodus 2
longkey KEYCODE_MENU;                       shot 12-browsermenue 3
key KEYCODE_BACK KEYCODE_BACK

# Video-Seite mit Player-Leiste
adb shell am start -a android.intent.action.VIEW -d "${BASE}watch.html?ep=3" -n de.overlord.tv/.BrowserActivity
shot 13-video 15
key KEYCODE_MEDIA_PLAY_PAUSE;               shot 14-playerleiste 2
key KEYCODE_DPAD_RIGHT KEYCODE_DPAD_RIGHT KEYCODE_DPAD_RIGHT; shot 15-playerleiste-knopf 1
key KEYCODE_BACK
longkey KEYCODE_MENU;                       shot 16-browsermenue-video 3
key KEYCODE_BACK KEYCODE_BACK KEYCODE_BACK KEYCODE_BACK

# Jellyfin-Demo-Server
adb shell am start -n de.overlord.tv/.MainActivity --ez open_library true
shot 17-jellyfin 25
key KEYCODE_DPAD_DOWN;                      shot 18-jellyfin-reihen 6

echo "===== LOGCAT (Fehler) ====="
adb logcat -d -v brief AndroidRuntime:E System.err:W '*:S' | tail -n 120
ls -la shots
exit 0
