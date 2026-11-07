#!/usr/bin/env bash
# Sucht auf echten legalen Mediatheken (ZDF, ARD, arte) eine aktuelle Serie und eine Folge daraus,
# damit der Emulator-Test den Aufbau „Übersicht → Serie (Staffeln/Folgen) → Folge“ prüfen kann.
# Ergebnis: series.txt mit Zeilen  name|übersicht|serie|folge  (leere Felder = nicht gefunden).
# Gibt außerdem Strukturhinweise der Seiten aus (Player-Klassen, Staffel-/Folgenlinks).
set -u
UA="Mozilla/5.0 (Linux; Android 11; AFTKA) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Mobile Safari/537.36"
get() { curl -sSL --compressed --max-time 25 -A "$UA" -H "Accept-Language: de-DE,de;q=0.9" "$1" 2>/dev/null || true; }
abs() { case "$2" in http*) echo "$2" ;; /*) echo "$1$2" ;; *) echo "" ;; esac; }
hints() {
  echo "  Player-Klassen: $(grep -oiE 'class="[^"]*(player|video)[^"]*"' <<<"$1" | sort | uniq -c | sort -rn | head -n 6 | tr -s ' ' | tr '\n' ';')"
  echo "  <video>: $(grep -oi '<video' <<<"$1" | wc -l) · <iframe>: $(grep -oi '<iframe' <<<"$1" | wc -l) · Staffel-Texte: $(grep -oiE '(staffel|season) ?[0-9]+' <<<"$1" | sort -u | head -n 5 | tr '\n' ',')"
}

: > series.txt

# ---------- ARD Mediathek
O="https://www.ardmediathek.de/serien"
H=$(get "$O")
S=$(grep -oE 'href="(https://www\.ardmediathek\.de)?/serie/[^"]+"' <<<"$H" | head -n 1 | sed -E 's/^href="//; s/"$//')
S=$(abs "https://www.ardmediathek.de" "$S")
E=""
if [ -n "$S" ]; then
  HS=$(get "$S")
  E=$(grep -oE 'href="(https://www\.ardmediathek\.de)?/video/[^"]+"' <<<"$HS" | head -n 1 | sed -E 's/^href="//; s/"$//')
  E=$(abs "https://www.ardmediathek.de" "$E")
  echo "ARD Serie: $S"; hints "$HS"
fi
[ -n "$E" ] && { echo "ARD Folge: $E"; hints "$(get "$E")"; }
echo "ard|$O|$S|$E" >> series.txt

# ---------- ZDF
O="https://www.zdf.de/serien"
H=$(get "$O")
S=$(grep -oE 'href="(https://www\.zdf\.de)?/serien/[a-z0-9-]+/?"' <<<"$H" | head -n 1 | sed -E 's/^href="//; s/"$//')
S=$(abs "https://www.zdf.de" "$S")
E=""
if [ -n "$S" ]; then
  HS=$(get "$S")
  slug=$(sed -E 's#^https://www\.zdf\.de##; s#/$##' <<<"$S")
  E=$(grep -oE "href=\"(https://www\.zdf\.de)?(/video)?$slug/[^\"]+\"" <<<"$HS" | head -n 1 | sed -E 's/^href="//; s/"$//')
  [ -z "$E" ] && E=$(grep -oE 'href="(https://www\.zdf\.de)?/video/[^"]+"' <<<"$HS" | head -n 1 | sed -E 's/^href="//; s/"$//')
  E=$(abs "https://www.zdf.de" "$E")
  echo "ZDF Serie: $S"; hints "$HS"
fi
[ -n "$E" ] && { echo "ZDF Folge: $E"; hints "$(get "$E")"; }
echo "zdf|$O|$S|$E" >> series.txt

# ---------- arte
O="https://www.arte.tv/de/videos/fernsehfilme-und-serien/"
H=$(get "$O")
[ -z "$(grep -oE 'href="(https://www\.arte\.tv)?/de/videos/' <<<"$H" | head -n 1)" ] && { O="https://www.arte.tv/de/"; H=$(get "$O"); }
S=$(grep -oE 'href="(https://www\.arte\.tv)?/de/videos/RC-[0-9]+/[^"]+"' <<<"$H" | head -n 1 | sed -E 's/^href="//; s/"$//')
S=$(abs "https://www.arte.tv" "$S")
E=""
if [ -n "$S" ]; then
  HS=$(get "$S")
  E=$(grep -oE 'href="(https://www\.arte\.tv)?/de/videos/[0-9]{6}-[0-9]{3}-[A-Z]/[^"]+"' <<<"$HS" | head -n 1 | sed -E 's/^href="//; s/"$//')
  E=$(abs "https://www.arte.tv" "$E")
  echo "arte Serie: $S"; hints "$HS"
fi
[ -n "$E" ] && { echo "arte Folge: $E"; hints "$(get "$E")"; }
echo "arte|$O|$S|$E" >> series.txt

echo "===== Gefundene Testseiten ====="
cat series.txt
exit 0
