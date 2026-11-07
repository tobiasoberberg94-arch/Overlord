#!/usr/bin/env bash
# Erzeugt Demo-Video, Poster und eine Beispielseite für die Emulator-Screenshots.
set -e
mkdir -p demo
ffmpeg -loglevel error -y -f lavfi -i "testsrc2=size=960x540:rate=24" -f lavfi -i "sine=frequency=220:sample_rate=44100" \
  -t 420 -c:v libx264 -preset veryfast -crf 34 -g 48 -pix_fmt yuv420p -c:a aac -b:a 48k -movflags +faststart demo/demo.mp4
i=1
for spec in "#7c3aed-#0ea5e9|Die Expedition" "#db2777-#f59e0b|Nachtzug" "#0f766e-#22d3ee|Küsten der Welt" "#1e293b-#ef4444|Stadt der Lichter"; do
  grad="${spec%%|*}"; title="${spec#*|}"
  # Poster ohne Text (der Titel steht bereits auf der Karte): Verlauf + weiche Kreise
  convert -size 1280x720 "gradient:${grad}" \
    -fill "rgba(255,255,255,0.18)" -draw "circle 980,250 980,520" \
    -fill "rgba(0,0,0,0.20)" -draw "circle 260,620 260,860" \
    -fill "rgba(255,255,255,0.10)" -draw "circle 640,120 640,200" \
    -blur 0x2 "demo/poster$i.jpg" \
    || ffmpeg -loglevel error -y -f lavfi -i "testsrc2=size=1280x720" -frames:v 1 "demo/poster$i.jpg"
  i=$((i+1))
done
cat > demo/watch.html <<'HTML'
<!doctype html>
<html lang="de"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width">
<title>Die Expedition – Folge 3</title>
<meta property="og:image" content="poster1.jpg"><meta name="theme-color" content="#7c3aed">
<style>body{margin:0;background:#101018;color:#eee;font:18px sans-serif}h1{margin:18px 24px}
video{display:block;width:100%;max-height:68vh;background:#000}nav a{display:inline-block;margin:14px 24px;color:#9cf;font-size:22px}
.skip{position:absolute;right:30px;top:40%;padding:10px 16px;background:#fff;color:#000;border-radius:6px;display:none}</style></head>
<body><h1 id="t">Die Expedition · Folge 3</h1>
<video id="v" src="demo.mp4" poster="poster1.jpg" controls autoplay playsinline></video>
<button class="skip" id="skip" onclick="v.currentTime=95;this.style.display='none'">Intro überspringen</button>
<nav><a href="watch.html?ep=2">« Vorherige Folge</a><a href="watch.html?ep=4">Nächste Folge »</a></nav>
<script>var ep=(location.search.match(/ep=(\d+)/)||[0,3])[1];document.getElementById('t').textContent='Die Expedition · Folge '+ep;
document.title='Die Expedition – Folge '+ep;v.addEventListener('timeupdate',function(){skip.style.display=(v.currentTime>2&&v.currentTime<90)?'block':'none'});</script>
</body></html>
HTML
ls -la demo
