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
cat > demo/index.html <<'HTML'
<!doctype html>
<html lang="de"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width">
<title>DemoFlix – Mediathek</title><meta property="og:site_name" content="DemoFlix">
<meta property="og:description" content="Beispiel-Mediathek für die Overlord-Video-Ansicht.">
<style>body{margin:0;background:#fff;color:#222;font:16px sans-serif}header{background:#333;color:#fff;padding:10px}
.row{display:flex;gap:12px;overflow:auto;padding:0 16px}.card{width:220px}.card img{width:220px;height:124px;display:block}
h2{margin:18px 16px 8px}aside{background:#ffd;padding:20px;margin:16px}</style></head>
<body><header><a href="/" style="color:#fff">DemoFlix</a> · <a href="/serien" style="color:#fff">Serien</a> · <a href="/filme" style="color:#fff">Filme</a></header>
<aside>Werbung! Jetzt das Super-Abo sichern …</aside>
<h2>Neue Folgen</h2><div class="row">
 <a class="card" href="watch.html?ep=3"><img src="poster1.jpg"><b>Die Expedition</b><br><span>Folge 3 · 7 Min.</span></a>
 <a class="card" href="watch.html?ep=1&s=2"><img src="poster2.jpg"><b>Nachtzug</b><br><span>Folge 1 · 7 Min.</span></a>
 <a class="card" href="watch.html?ep=5&s=3"><img src="poster3.jpg"><b>Küsten der Welt</b><br><span>Folge 5</span></a>
 <a class="card" href="watch.html?ep=2&s=4"><img src="poster4.jpg"><b>Stadt der Lichter</b><br><span>Folge 2</span></a>
</div>
<h2>Beliebte Serien</h2><div class="row">
 <a class="card" href="watch.html?ep=1&s=4"><img src="poster4.jpg"><b>Stadt der Lichter</b></a>
 <a class="card" href="watch.html?ep=1&s=3"><img src="poster3.jpg"><b>Küsten der Welt</b></a>
 <a class="card" href="watch.html?ep=1"><img src="poster1.jpg"><b>Die Expedition</b></a>
</div>
<h2>Die Expedition – Staffel 1</h2><ol>
 <li><a href="watch.html?ep=1">Folge 1 – Aufbruch</a></li><li><a href="watch.html?ep=2">Folge 2 – Sturm</a></li>
 <li><a href="watch.html?ep=3">Folge 3 – Das Tal</a></li><li><a href="watch.html?ep=4">Folge 4 – Heimkehr</a></li>
</ol><footer><a href="/impressum">Impressum</a></footer></body></html>
HTML
ls -la demo
