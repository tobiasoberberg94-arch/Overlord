/*
 * Overlord – wird in jede Seite und jedes iframe geladen.
 *  - Pop-ups (window.open) blockieren
 *  - typische Werbe-Elemente ausblenden
 *  - Video-Fortschritt melden / fortsetzen (Weiterschauen)
 *  - Wiedergabe-Befehle (Play/Pause, Spulen) von der Fernbedienung empfangen
 *  - Link-Navigation mit dem Steuerkreuz (nur oberster Frame)
 */
(function () {
  if (window.__ovLoaded) return;
  window.__ovLoaded = true;

  var B = window.OverlordBridge;

  // ---------------------------------------------------------------- Pop-ups
  try {
    var noop = function () { return null; };
    Object.defineProperty(window, 'open', { value: noop, writable: false, configurable: false });
  } catch (e) {
    try { window.open = function () { return null; }; } catch (e2) {}
  }

  // ---------------------------------------------------------------- Werbung ausblenden
  var CSS = [
    '.adsbygoogle', 'ins.adsbygoogle', '[id^="google_ads"]', '[id^="div-gpt-ad"]',
    'iframe[src*="doubleclick"]', 'iframe[src*="googlesyndication"]', 'iframe[src*="/ads/"]',
    'iframe[id*="ad_"]', 'iframe[name*="ad_"]', '[class*="ad-banner"]', '[class*="adbanner"]',
    '[id*="ad-banner"]', '[class*="ad-container"]', '[id*="ad-container"]', '[class*="advert"]',
    '[id*="advert"]', '[class*="sponsor"]', '[class^="ad-"]', '[class*=" ad-"]', '[id^="ad-"]',
    'a[href*="/aff/"]', 'a[href*="affiliate"]', 'a[target="_blank"][rel*="sponsored"]',
    'div[style*="z-index: 2147483647"]', 'div[style*="z-index:2147483647"]'
  ].join(',') + '{display:none!important;visibility:hidden!important;pointer-events:none!important}' +
    '.ov-focus{outline:4px solid #E50914!important;outline-offset:2px!important;' +
    'box-shadow:0 0 0 8px rgba(229,9,20,.35)!important;border-radius:4px!important}';

  function addCss() {
    try {
      var s = document.createElement('style');
      s.textContent = CSS;
      (document.head || document.documentElement).appendChild(s);
    } catch (e) {}
  }
  if (document.documentElement) addCss();
  else document.addEventListener('DOMContentLoaded', addCss);

  // Unsichtbare Klick-Fänger über der ganzen Seite entfernen (typischer Pop-under-Trick)
  function killOverlays() {
    try {
      var all = document.querySelectorAll('body > div, body > a, body > span');
      var W = window.innerWidth, H = window.innerHeight;
      for (var i = 0; i < all.length; i++) {
        var el = all[i];
        var st = getComputedStyle(el);
        if (st.position !== 'fixed' && st.position !== 'absolute') continue;
        var z = parseInt(st.zIndex, 10) || 0;
        var r = el.getBoundingClientRect();
        var covers = r.width >= W * 0.9 && r.height >= H * 0.9;
        var transparent = parseFloat(st.opacity) < 0.1 || (st.backgroundColor === 'rgba(0, 0, 0, 0)' && !el.textContent.trim());
        if (covers && transparent && z > 100 && !el.querySelector('video,iframe')) el.remove();
      }
    } catch (e) {}
  }
  setInterval(killOverlays, 1500);

  // ---------------------------------------------------------------- Video / Weiterschauen
  var MIN_DURATION = 300; // kürzere Videos = Werbung / Trailer -> ignorieren

  function hook(v) {
    if (v.__ovHooked) return;
    v.__ovHooked = true;
    var last = 0;
    var resumed = false;
    function tryResume() {
      if (resumed || !B || !(v.duration > MIN_DURATION)) return;
      resumed = true;
      try {
        var p = B.resume(v.duration);
        if (p > 0) v.currentTime = p;
      } catch (e) {}
    }
    v.addEventListener('loadedmetadata', tryResume);
    v.addEventListener('durationchange', tryResume);
    if (v.readyState >= 1) tryResume();
    v.addEventListener('timeupdate', function () {
      var now = Date.now();
      if (now - last < 5000) return;
      last = now;
      if (B && v.duration > MIN_DURATION && !v.paused) {
        try { B.progress(v.currentTime, v.duration); } catch (e) {}
      }
    });
    v.addEventListener('pause', function () {
      if (B && v.duration > MIN_DURATION) {
        try { B.progress(v.currentTime, v.duration); } catch (e) {}
      }
    });
    v.addEventListener('ended', function () {
      if (B && v.duration > MIN_DURATION) {
        try { B.progress(v.duration, v.duration); } catch (e) {}
      }
    });
  }

  function scan() {
    var vs = document.getElementsByTagName('video');
    for (var i = 0; i < vs.length; i++) hook(vs[i]);
  }
  document.addEventListener('DOMContentLoaded', scan);
  setInterval(scan, 2000);

  function mainVideo() {
    var vs = document.getElementsByTagName('video');
    var best = null, bestArea = 0;
    for (var i = 0; i < vs.length; i++) {
      var r = vs[i].getBoundingClientRect();
      var a = r.width * r.height;
      if (vs[i].duration > 0 && a >= bestArea) { best = vs[i]; bestArea = a; }
    }
    return best;
  }

  function command(cmd) {
    var v = mainVideo();
    if (v) {
      try {
        if (cmd === 'toggle') { if (v.paused) v.play(); else v.pause(); }
        else if (cmd === 'pause') v.pause();
        else if (cmd === 'back') v.currentTime = Math.max(0, v.currentTime - 10);
        else if (cmd === 'fwd') v.currentTime = Math.min(v.duration, v.currentTime + 10);
        else if (cmd === 'fullscreen') {
          var f = v.requestFullscreen || v.webkitRequestFullscreen;
          if (f) f.call(v);
        }
      } catch (e) {}
    }
    // an alle Unter-Frames weitergeben (Player liegt meist in einem iframe)
    for (var i = 0; i < window.frames.length; i++) {
      try { window.frames[i].postMessage({ __ov: cmd }, '*'); } catch (e) {}
    }
  }
  window.__ovCmd = command;
  window.addEventListener('message', function (e) {
    if (e.data && typeof e.data === 'object' && e.data.__ov) command(e.data.__ov);
  });

  // ---------------------------------------------------------------- Link-Navigation (oberster Frame)
  if (window.top !== window) return;

  var SEL = 'a[href],button,input:not([type=hidden]),select,textarea,[onclick],[role=button],' +
    '[role=link],[role=tab],[role=menuitem],[tabindex]:not([tabindex="-1"]),summary,video,iframe';
  var cur = null;

  function visible(el, r) {
    if (r.width < 6 || r.height < 6) return false;
    var st = getComputedStyle(el);
    return st.visibility !== 'hidden' && st.display !== 'none' && parseFloat(st.opacity) > 0.05;
  }

  function candidates() {
    var els = document.querySelectorAll(SEL);
    var H = window.innerHeight;
    var out = [];
    for (var i = 0; i < els.length; i++) {
      var el = els[i];
      var r = el.getBoundingClientRect();
      if (r.bottom < -H * 2 || r.top > H * 3) continue;
      if (!visible(el, r)) continue;
      // verschachtelte klickbare Elemente: nur das äußerste nehmen
      var p = el.parentElement, nested = false;
      while (p && p !== document.body) {
        if (p.matches && p.matches('a[href],button')) { nested = true; break; }
        p = p.parentElement;
      }
      if (nested) continue;
      out.push({ el: el, r: r });
    }
    return out;
  }

  function setFocus(el) {
    if (cur) cur.classList.remove('ov-focus');
    cur = el;
    if (!el) return;
    el.classList.add('ov-focus');
    var r = el.getBoundingClientRect();
    if (r.top < 60 || r.bottom > window.innerHeight - 60) {
      el.scrollIntoView({ block: 'center', inline: 'nearest' });
    }
  }

  window.__ovNav = function (dir) {
    var W = window.innerWidth, H = window.innerHeight;
    var o;
    if (cur && document.contains(cur)) {
      var cr = cur.getBoundingClientRect();
      if (cr.bottom < 0 || cr.top > H) cur = null;
      else o = { x: cr.left + cr.width / 2, y: cr.top + cr.height / 2, r: cr };
    } else cur = null;
    var list = candidates();
    if (!cur) {
      // erstes sichtbares Element wählen
      var first = null, fs = 1e9;
      for (var i = 0; i < list.length; i++) {
        var r0 = list[i].r;
        if (r0.top < 0 || r0.top > H) continue;
        var s0 = r0.top * 3 + r0.left;
        if (s0 < fs) { fs = s0; first = list[i].el; }
      }
      if (first) { setFocus(first); return 'ok'; }
      window.scrollBy(0, dir === 'up' ? -H * 0.6 : H * 0.6);
      return 'scroll';
    }
    var best = null, bestScore = 1e12;
    for (var j = 0; j < list.length; j++) {
      var c = list[j];
      if (c.el === cur) continue;
      var r = c.r;
      var cx = r.left + r.width / 2, cy = r.top + r.height / 2;
      var main, side;
      if (dir === 'right') { main = r.left - o.r.right; side = Math.abs(cy - o.y); if (cx <= o.x + 1) continue; }
      else if (dir === 'left') { main = o.r.left - r.right; side = Math.abs(cy - o.y); if (cx >= o.x - 1) continue; }
      else if (dir === 'down') { main = r.top - o.r.bottom; side = Math.abs(cx - o.x); if (cy <= o.y + 1) continue; }
      else { main = o.r.top - r.bottom; side = Math.abs(cx - o.x); if (cy >= o.y - 1) continue; }
      if (main < -4) main = Math.abs(main) * 2; // überlappend
      var score = main + side * (dir === 'left' || dir === 'right' ? 3 : 1.5);
      if (score < bestScore) { bestScore = score; best = c.el; }
    }
    if (best) { setFocus(best); return 'ok'; }
    if (dir === 'down') window.scrollBy(0, H * 0.6);
    else if (dir === 'up') window.scrollBy(0, -H * 0.6);
    return 'scroll';
  };

  /** Liefert die Bildschirm-Position des fokussierten Elements (in Geräte-Pixeln) für einen echten Klick. */
  window.__ovFocusPoint = function () {
    if (!cur || !document.contains(cur)) return null;
    var r = cur.getBoundingClientRect();
    var vv = window.visualViewport;
    var scale = vv ? vv.scale : 1;
    var ox = vv ? vv.offsetLeft : 0, oy = vv ? vv.offsetTop : 0;
    var dpr = window.devicePixelRatio || 1;
    var x = r.left + Math.min(r.width / 2, 40);
    if (r.width < 80) x = r.left + r.width / 2;
    var y = r.top + r.height / 2;
    return { x: (x - ox) * scale * dpr, y: (y - oy) * scale * dpr };
  };

  window.__ovClearFocus = function () { setFocus(null); };
})();
