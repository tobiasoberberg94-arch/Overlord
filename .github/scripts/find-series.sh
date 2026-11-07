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
exec > >(tee series-hints.txt) 2>&1
links() { grep -oE 'href="[^"]+"' <<<"$1" | sed -E 's/^href="//; s/"$//' | grep -vE '^(#|javascript:|mailto:)' | awk '!seen[$0]++' | head -n "${2:-12}" | tr '\n' ' '; }

# ---------- ARD Mediathek
# Mehrere Serien probieren; als Folge eine nehmen, die schon/noch einen Stream hat (nicht erst angekündigt,
# nicht durch Jugendschutz-Zeiten gesperrt).
O="https://www.ardmediathek.de/serien"
H=$(get "$O")
echo "ARD Übersicht: $(wc -c <<<"$H") Bytes · Links: $(links "$H" 10)"
S=""; E=""; S1=""; E1=""
for s in $(grep -oE 'href="(https://www\.ardmediathek\.de)?/serie/[^"]+"' <<<"$H" | sed -E 's/^href="//; s/"$//' | awk '!seen[$0]++' | head -n 5); do
  s=$(abs "https://www.ardmediathek.de" "$s")
  HS=$(get "$s")
  for e in $(grep -oE 'href="(https://www\.ardmediathek\.de)?/video/[^"]+"' <<<"$HS" | sed -E 's/^href="//; s/"$//' | awk '!seen[$0]++' | head -n 6); do
    e=$(abs "https://www.ardmediathek.de" "$e")
    [ -z "$S1" ] && { S1="$s"; E1="$e"; }
    HE=$(get "$e")
    if grep -qiE '\.m3u8|\.mp4' <<<"$HE" && ! grep -qiE '"blockedByFsk":true|jugendschutz' <<<"$HE"; then S="$s"; E="$e"; break 2; fi
  done
done
[ -z "$S" ] && { S="$S1"; E="$E1"; echo "ARD: keine Folge mit Stream im HTML gefunden – nehme die erste"; }
if [ -n "$S" ]; then echo "ARD Serie: $S"; hints "$(get "$S")"; fi
[ -n "$E" ] && { echo "ARD Folge: $E"; hints "$(get "$E")"; }
echo "ard|$O|$S|$E" >> series.txt

# ---------- ZDF
O="https://www.zdf.de/serien"
H=$(get "$O")
echo "ZDF Übersicht: $(wc -c <<<"$H") Bytes · Links: $(links "$H" 25)"
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
echo "arte Übersicht: $(wc -c <<<"$H") Bytes"
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
