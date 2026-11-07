#!/usr/bin/env bash
# Startet Overlord TV im Android-TV-Emulator, bedient es per Tastenereignis
# und speichert Screenshots nach shots/.
set -x
mkdir -p shots
shot() { sleep "${2:-3}"; adb exec-out screencap -p > "shots/$1.png"; }
key() { for k in "$@"; do adb shell input keyevent "$k"; sleep 0.8; done; }

adb install -r dist/overlord-tv.apk || exit 0
adb shell settings put global stay_on_while_plugged_in 7 || true

# Startseite mit Beispieldaten
adb shell am start -n de.overlord.tv/.MainActivity --ez overlord_demo true
shot 01-start 25
key KEYCODE_DPAD_RIGHT;                     shot 02-weiterschauen 4
key KEYCODE_DPAD_DOWN;                      shot 03-anbieter 4
key KEYCODE_DPAD_RIGHT KEYCODE_DPAD_RIGHT;  shot 04-webseite 4
key KEYCODE_MENU;                           shot 05-bearbeiten 3
key KEYCODE_BACK
key KEYCODE_DPAD_DOWN;                      shot 06-bibliothek 3
key KEYCODE_DPAD_DOWN;                      shot 07-einstellungen 3

# Eingebauter Browser
adb shell am start -a android.intent.action.VIEW -d "https://www.arte.tv/de/" -n de.overlord.tv/.BrowserActivity
shot 08-browser 25
key KEYCODE_DPAD_DOWN KEYCODE_DPAD_DOWN KEYCODE_DPAD_RIGHT; shot 09-linkmodus 3
key KEYCODE_MENU;                           shot 10-zeigermodus 2
adb shell input keyevent --longpress KEYCODE_MENU; shot 11-browsermenue 3
key KEYCODE_BACK KEYCODE_BACK

# Video mit Player-Leiste
adb shell am start -a android.intent.action.VIEW -d "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/Sintel.mp4" -n de.overlord.tv/.BrowserActivity
shot 12-video 20
key KEYCODE_MEDIA_PLAY_PAUSE;               shot 13-playerleiste 2
key KEYCODE_BACK KEYCODE_BACK KEYCODE_BACK

# Jellyfin-Demo-Server
adb shell am start -n de.overlord.tv/.MainActivity --ez open_library true
shot 14-jellyfin 25
key KEYCODE_DPAD_DOWN;                      shot 15-jellyfin-reihen 6

echo "===== LOGCAT (Fehler) ====="
adb logcat -d -v brief AndroidRuntime:E System.err:W '*:S' | tail -n 120
echo "===== LOGCAT (App) ====="
adb logcat -d -v brief | grep -i -E "overlord|chromium.*(error|uncaught)" | tail -n 80
ls -la shots
exit 0
