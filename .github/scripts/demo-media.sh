#!/usr/bin/env bash
# Erzeugt Demo-Video, Poster und eine Beispielseite für die Emulator-Screenshots.
set -e
mkdir -p demo
ffmpeg -loglevel error -y -f lavfi -i "testsrc2=size=960x540:rate=24" -f lavfi -i "sine=frequency=220:sample_rate=44100" \
  -t 420 -c:v libx264 -preset veryfast -crf 34 -g 48 -pix_fmt yuv420p -c:a aac -b:a 48k -movflags +faststart demo/demo.mp4
# HLS-Teststream mit zwei Qualitätsstufen (Qualitätswahl im eigenen Player)
mkdir -p demo/hls/540 demo/hls/360
ffmpeg -loglevel error -y -i demo/demo.mp4 -c copy -f hls -hls_time 6 -hls_playlist_type vod \
  -hls_segment_filename 'demo/hls/540/s%03d.ts' demo/hls/540/index.m3u8
ffmpeg -loglevel error -y -i demo/demo.mp4 -vf scale=640:360 -c:v libx264 -preset ultrafast -crf 36 -g 48 -pix_fmt yuv420p \
  -c:a aac -b:a 48k -f hls -hls_time 6 -hls_playlist_type vod -hls_segment_filename 'demo/hls/360/s%03d.ts' demo/hls/360/index.m3u8
cat > demo/hls/master.m3u8 <<'M3U'
#EXTM3U
#EXT-X-STREAM-INF:BANDWIDTH=900000,RESOLUTION=960x540
540/index.m3u8
#EXT-X-STREAM-INF:BANDWIDTH=400000,RESOLUTION=640x360
360/index.m3u8
M3U
cat > demo/hls.html <<'HTML'
<!doctype html>
<html lang="de"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Die Expedition – HLS-Stream</title>
<style>body{margin:0;background:#0b1020;color:#fff;font-family:sans-serif}video{width:100%;max-height:80vh;background:#000}h1{margin:16px}</style>
</head><body>
<video controls preload="auto" src="hls/master.m3u8" poster="poster1.jpg"></video>
<h1>Die Expedition – HLS-Stream mit zwei Qualitätsstufen</h1>
<script>try { fetch('hls/master.m3u8'); } catch (e) {}</script>
</body></html>
HTML

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
# Serien-Aufbau: Serienseite mit Staffel-Reitern und Folgentabelle, Folgenseite mit Versions-Umschalter
cat > demo/serie.html <<'HTML'
<!doctype html>
<html lang="de"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width">
<title>Die Expedition – DemoFlix</title><meta property="og:site_name" content="DemoFlix">
<meta property="og:image" content="poster1.jpg">
<meta property="og:description" content="Eine Forscherin bricht in ein unbekanntes Tal auf – und findet mehr, als sie gesucht hat.">
<style>body{margin:0;font:16px sans-serif;background:#f4f4f4;color:#222}header{background:#333;padding:10px}header a{color:#fff;margin-right:12px}
.cover{display:flex;gap:20px;padding:16px}.cover img{width:200px;height:290px;object-fit:cover}
ul.seasons{list-style:none;display:flex;gap:6px;padding:0 16px}ul.seasons a{display:block;padding:8px 14px;background:#ddd;color:#222;text-decoration:none}
ul.seasons a.active{background:#7c3aed;color:#fff}table{margin:12px 16px;border-collapse:collapse;width:90%}td{border-bottom:1px solid #ccc;padding:8px}
td img{width:22px;height:14px}</style></head>
<body><header><a href="index.html">DemoFlix</a><a href="index.html">Serien</a><a href="index.html">Filme</a></header>
<div class="cover"><img src="poster1.jpg" alt="Die Expedition"><div><h1>Die Expedition</h1>
<p>Eine Forscherin bricht in ein unbekanntes Tal auf – und findet mehr, als sie gesucht hat.</p></div></div>
<ul class="seasons"><li><a href="serie.html?staffel=1" class="active">Staffel 1</a></li><li><a href="serie.html?staffel=2">Staffel 2</a></li><li><a href="serie.html?staffel=0">Filme</a></li></ul>
<table class="episodes"><tbody>
<tr><td><a href="folge.html?staffel=1&episode=1">Folge 1</a></td><td><a href="folge.html?staffel=1&episode=1"><strong>Aufbruch</strong> – <span>Departure</span></a></td><td><img src="de.png" alt="Deutsch"><img src="en.png" alt="Englisch"></td></tr>
<tr><td><a href="folge.html?staffel=1&episode=2">Folge 2</a></td><td><a href="folge.html?staffel=1&episode=2"><strong>Sturm</strong> – <span>Storm</span></a></td><td><img src="de.png" alt="Deutsch"></td></tr>
<tr><td><a href="folge.html?staffel=1&episode=3">Folge 3</a></td><td><a href="folge.html?staffel=1&episode=3"><strong>Das Tal</strong> – <span>The Valley</span></a></td><td><img src="de.png" alt="Deutsch"></td></tr>
<tr><td><a href="folge.html?staffel=1&episode=4">Folge 4</a></td><td><a href="folge.html?staffel=1&episode=4"><strong>Heimkehr</strong> – <span>Homecoming</span></a></td><td><img src="en.png" alt="Englisch"></td></tr>
</tbody></table><footer><a href="index.html">Impressum</a></footer></body></html>
HTML
cat > demo/folge.html <<'HTML'
<!doctype html>
<html lang="de"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width">
<title>Die Expedition – Folge</title><meta property="og:site_name" content="DemoFlix"><meta property="og:image" content="poster1.jpg">
<style>body{margin:0;font:16px sans-serif;background:#111;color:#eee}header{background:#333;padding:10px}header a{color:#fff}
video{display:block;width:100%;max-height:60vh;background:#000}.version-select{display:flex;gap:8px;padding:10px}
.version-select button{padding:8px 14px;background:#333;color:#fff;border:0}.version-select button.active{background:#7c3aed}
ol a{color:#9cf}</style></head>
<body><header><a href="serie.html?staffel=1">Zurück zur Serie</a></header><h1 id="t" style="margin:12px">Die Expedition</h1>
<video id="v" src="demo.mp4" poster="poster1.jpg" controls autoplay playsinline></video>
<div class="version-select"><button class="active" onclick="sel(this,0)">Deutsch</button><button onclick="sel(this,1)">Original mit Untertiteln</button><button onclick="sel(this,2)">Audiodeskription</button></div>
<a id="next" href="#">Nächste Folge »</a>
<h2 style="margin:12px">Alle Folgen</h2><ol>
<li><a href="folge.html?staffel=1&episode=1">Folge 1 – Aufbruch</a></li><li><a href="folge.html?staffel=1&episode=2">Folge 2 – Sturm</a></li>
<li><a href="folge.html?staffel=1&episode=3">Folge 3 – Das Tal</a></li><li><a href="folge.html?staffel=1&episode=4">Folge 4 – Heimkehr</a></li></ol>
<script>var ep=+(location.search.match(/episode=(\d+)/)||[0,1])[1];document.getElementById('t').textContent='Die Expedition · Folge '+ep;
document.title='Die Expedition – Folge '+ep;document.getElementById('next').href='folge.html?staffel=1&episode='+(ep+1);
function sel(b,i){[].forEach.call(document.querySelectorAll('.version-select button'),function(x){x.classList.remove('active')});b.classList.add('active');var t=v.currentTime;v.src='demo.mp4#v'+i;v.currentTime=t;v.play();}</script>
</body></html>
HTML
ls -la demo
