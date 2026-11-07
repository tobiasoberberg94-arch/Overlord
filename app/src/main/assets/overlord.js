/*
 * Overlord TV – wird per addDocumentStartJavaScript in JEDEN Frame (auch iframes) eingeschleust.
 * Aufgaben: Pop-up-Blocker, Werbe-/Overlay-Ausblendung, Video-Steuerung über Frame-Grenzen,
 * Weiterschauen-Meldungen, Link-Navigation mit dem Steuerkreuz, Schnellsuche.
 * Bewusst ES5, damit auch ältere Fire-OS-WebViews es ausführen.
 */
(function () {
  'use strict';
  if (window.__ovl) return;
  var W = window, D = document;
  var isTop = false;
  try { isTop = (W.top === W); } catch (e) { isTop = false; }
  var B = null;
  try { B = W.OverlordBridge || null; } catch (e) { B = null; }
  var O = W.__ovl = { version: 2 };
  var lastGesture = 0;

  /* Schutz (Blocker/Overlay-Filter) für diese Seite aktiv? Entscheidet die App anhand der
     Domain der Hauptseite – iframes ermitteln sie über ancestorOrigins/referrer. */
  var topHost = '';
  try { topHost = isTop ? location.hostname : ''; } catch (e) {}
  if (!topHost) {
    try {
      var ao = location.ancestorOrigins;
      if (ao && ao.length) topHost = new URL(ao[ao.length - 1]).hostname;
    } catch (e) {}
  }
  if (!topHost) { try { topHost = new URL(D.referrer).hostname; } catch (e) {} }
  var PROTECT = true;
  try { if (B && B.protect) PROTECT = !!B.protect(String(topHost || '')); } catch (e) {}
  O.protect = PROTECT;

  function now() { return new Date().getTime(); }
  function safe(fn) { return function () { try { return fn.apply(this, arguments); } catch (e) { return null; } }; }
  function baseDomain(h) {
    h = String(h || '').toLowerCase().replace(/^www\./, '');
    var p = h.split('.');
    if (p.length <= 2) return h;
    var tld = p[p.length - 1], sld = p[p.length - 2];
    if (tld.length === 2 && sld.length <= 3) return p.slice(-3).join('.');
    return p.slice(-2).join('.');
  }
  function sameSite(a, b) { return baseDomain(a) === baseDomain(b); }
  function clsOf(el) {
    var c = el.className;
    if (c && typeof c === 'object' && c.baseVal !== undefined) c = c.baseVal;
    return String(c || '') + ' ' + String(el.id || '');
  }
  function call(name, arg) {
    if (!B) return;
    try { if (arg === undefined) B[name](); else B[name](arg); } catch (e) {}
  }

  ['mousedown', 'pointerdown', 'touchstart', 'keydown', 'click'].forEach(function (t) {
    W.addEventListener(t, function (e) { if (e.isTrusted !== false) lastGesture = now(); }, true);
  });

  /* ------------------------------------------------------------------ Pop-ups */
  function fakeWin() {
    var f = {
      closed: false, opener: null, name: '',
      close: function () { f.closed = true; }, focus: function () {}, blur: function () {},
      postMessage: function () {}, moveTo: function () {}, resizeTo: function () {},
      document: { write: function () {}, writeln: function () {}, open: function () {}, close: function () {}, body: null },
      location: { href: '', assign: function () {}, replace: function () {} }
    };
    return f;
  }
  if (PROTECT) try {
    W.open = function (url) {
      var href = '';
      try { href = new URL(String(url || ''), location.href).href; } catch (e) {}
      if (isTop && href && now() - lastGesture < 1200) {
        try {
          if (sameSite(new URL(href).hostname, location.hostname)) { location.href = href; return W; }
        } catch (e) {}
      }
      call('popup', href || String(url || ''));
      return fakeWin();
    };
  } catch (e) {}

  /* ------------------------------------------------------------------ Kosmetik */
  var HIDE = [
    'ins.adsbygoogle', '.adsbygoogle', '[id^="google_ads_"]', '[id^="div-gpt-ad"]', '[id^="gpt-ad"]',
    'iframe[src*="doubleclick.net"]', 'iframe[src*="googlesyndication"]', 'iframe[src*="amazon-adsystem"]',
    'iframe[id^="google_ads_iframe"]', '[data-ad-slot]', '[data-ad-unit]', '[data-google-query-id]',
    '.ad-banner', '.ad_banner', '.adBanner', '.banner-ad', '.ad-container', '.ad-wrapper', '.ad-slot',
    '.adslot', '.advertisement', '.advert', '.ads-box', '.sponsored-ad', '.ad-box', '.ad-unit',
    '[id^="taboola"]', '.trc_rbox_container', '.OUTBRAIN', '[id^="outbrain"]', '.mgbox', '[id^="ScriptRoot"]',
    'a[href*="/aff_c?"]', 'a[href*="popads"]', 'a[href*="adsterra"]', 'a[href*="clickadu"]',
    'iframe[src*="exoclick"]', 'iframe[src*="juicyads"]', 'iframe[src*="adsterra"]'
  ].join(',');
  var CSS = (PROTECT ? HIDE + '{display:none!important;visibility:hidden!important;pointer-events:none!important}' : '') +
    '#__ovl_hl{position:fixed;z-index:2147483647;pointer-events:none;border:3px solid #fff;border-radius:10px;' +
    'box-shadow:0 0 0 3px #8B5CF6,0 0 26px 6px rgba(139,92,246,.75),inset 0 0 0 1px rgba(0,0,0,.35);' +
    'background:rgba(139,92,246,.10);transition:all .14s ease-out;display:none;box-sizing:border-box}';
  function addStyle() {
    if (D.getElementById('__ovl_css')) return;
    var s = D.createElement('style');
    s.id = '__ovl_css';
    s.textContent = CSS;
    (D.head || D.documentElement).appendChild(s);
  }
  try { if (D.documentElement) addStyle(); } catch (e) {}
  D.addEventListener('DOMContentLoaded', safe(addStyle));

  /* Unsichtbare Klickflächen über der Seite entschärfen */
  var PLAYERISH = /player|vjs|video|plyr|jw-|jwplayer|shaka|control|bitmovin|clappr|dplayer|artplayer|mejs|flowplayer|play|poster|start|thumb|cover|preview|episode|stream|watch|media|__ovl/i;
  function isTransparent(el, cs) {
    if (parseFloat(cs.opacity) < 0.1) return true;
    var bg = cs.backgroundColor || '';
    var clearBg = (bg === 'transparent' || /rgba\([^)]*,\s*0(\.0+)?\)$/.test(bg)) && (!cs.backgroundImage || cs.backgroundImage === 'none');
    if (!clearBg) return false;
    var txt = (el.textContent || '').replace(/\s+/g, '');
    return txt.length === 0 && !el.querySelector('img,svg,picture,canvas');
  }
  function kill(el) {
    el.__ovlKilled = true;
    el.style.setProperty('pointer-events', 'none', 'important');
  }
  function checkOverlay(el, area) {
    if (!el || el.__ovlKilled || el.id === '__ovl_hl') return;
    var tag = el.tagName;
    if (tag === 'VIDEO' || tag === 'IFRAME' || tag === 'HTML' || tag === 'BODY') return;
    var cs = W.getComputedStyle(el);
    if (cs.position !== 'fixed' && cs.position !== 'absolute') return;
    var r = el.getBoundingClientRect();
    if (r.width * r.height < area * 0.3) return;
    if (PLAYERISH.test(clsOf(el))) return;
    if (el.querySelector('video,iframe,embed,object')) return;
    var z = parseInt(cs.zIndex, 10) || 0;
    // Nur klar unsichtbare Flächen entschärfen (sichtbare Links/Knöpfe bleiben unangetastet)
    if (z > 0 && isTransparent(el, cs)) kill(el);
  }
  var sweep = safe(function () {
    if (!PROTECT || !D.body) return;
    var vw = W.innerWidth, vh = W.innerHeight, area = vw * vh;
    if (!vw || !vh) return;
    var pts = [[0.5, 0.5], [0.25, 0.3], [0.75, 0.3], [0.25, 0.75], [0.75, 0.75], [0.5, 0.12], [0.5, 0.9]];
    for (var i = 0; i < pts.length; i++) {
      var el = D.elementFromPoint(vw * pts[i][0], vh * pts[i][1]);
      var depth = 0;
      while (el && depth++ < 8) { checkOverlay(el, area); el = el.parentElement; }
    }
  });
  setInterval(sweep, 1500);

  /* ------------------------------------------------------------------ Videos */
  function allVideos() {
    var list = [].slice.call(D.getElementsByTagName('video'));
    var fr = D.getElementsByTagName('iframe');
    for (var i = 0; i < fr.length; i++) {
      try {
        var w = fr[i].contentWindow;
        if (w && !w.__ovl && w.document) list = list.concat([].slice.call(w.document.getElementsByTagName('video')));
      } catch (e) { /* fremde Herkunft – dort läuft unser eigenes Skript */ }
    }
    return list;
  }
  function mainVideo() {
    var vs = allVideos(), best = null, bestScore = -1;
    for (var i = 0; i < vs.length; i++) {
      var v = vs[i], d = v.duration, r = v.getBoundingClientRect();
      var s = (r.width * r.height) / 2000 +
        (isFinite(d) ? Math.min(d, 7200) : (d === Infinity ? 3000 : 0)) +
        (v.paused ? 0 : 8000) + (v.readyState > 0 ? 100 : 0);
      if (s > bestScore) { bestScore = s; best = v; }
    }
    return best;
  }
  function report() {
    if (!B) return;
    var v = mainVideo();
    if (!v) return;
    var d = v.duration;
    var src = String(v.currentSrc || v.src || '');
    if (O.rate && v.playbackRate !== O.rate && isFinite(d) && d >= 30) { try { v.playbackRate = O.rate; } catch (e) {} }
    var poster = '';
    try { poster = v.poster ? String(new URL(v.poster, location.href).href) : ''; } catch (e) {}
    call('video', JSON.stringify({
      poster: /^https?:/i.test(poster) ? poster : '',
      t: v.currentTime || 0,
      d: isFinite(d) ? d : (d === Infinity ? -2 : -1),
      p: !!v.paused,
      e: !!v.ended,
      src: /^https?:/i.test(src) ? src : '',
      top: isTop,
      f: String(location.href)
    }));
  }
  setInterval(safe(report), 2000);
  ['play', 'pause', 'seeked', 'loadedmetadata', 'ended'].forEach(function (t) {
    D.addEventListener(t, function (e) {
      if (e.target && e.target.tagName === 'VIDEO') setTimeout(safe(report), 60);
    }, true);
  });

  function tryPlay(v) {
    try { var p = v.play(); if (p && p['catch']) p['catch'](function () {}); } catch (e) {}
  }

  var STYLE_MAX = ';position:fixed!important;left:0!important;top:0!important;right:0!important;bottom:0!important;' +
    'width:100vw!important;height:100vh!important;max-width:none!important;max-height:none!important;' +
    'z-index:2147483646!important;background:#000!important;margin:0!important;border:0!important;' +
    'transform:none!important;object-fit:contain!important;';
  function applyMax(el, on) {
    if (on) {
      if (el.__ovlOld === undefined) el.__ovlOld = el.getAttribute('style') || '';
      el.setAttribute('style', el.__ovlOld + STYLE_MAX);
    } else if (el.__ovlOld !== undefined) {
      el.setAttribute('style', el.__ovlOld);
      el.__ovlOld = undefined;
    }
    try { D.documentElement.style.overflow = on ? 'hidden' : ''; } catch (e) {}
  }
  function toggleMax(v, force) {
    var on = (force === undefined) ? !v.__ovlMax : !!force;
    v.__ovlMax = on;
    applyMax(v, on);
    if (!isTop) { try { W.parent.postMessage({ __ovl: 1, maxMe: 1, on: on }, '*'); } catch (e) {} }
  }
  function maxChildFrame(src, on) {
    var fr = D.getElementsByTagName('iframe');
    for (var i = 0; i < fr.length; i++) {
      if (fr[i].contentWindow === src) {
        applyMax(fr[i], on);
        if (!isTop) { try { W.parent.postMessage({ __ovl: 1, maxMe: 1, on: on }, '*'); } catch (e) {} }
      }
    }
  }

  var BIG_PLAY = '.vjs-big-play-button,.jw-display-icon-display,.jw-icon-display,.plyr__control--overlaid,' +
    '.ytp-large-play-button,[class*="big-play"],[class*="play-button"],[class*="playbutton"],[class*="btn-play"],' +
    '[aria-label*="Play"],[aria-label*="play"],[aria-label*="Abspielen"],[title*="Play"],[title*="play"]';
  function clickBigPlay() {
    var els;
    try { els = D.querySelectorAll(BIG_PLAY); } catch (e) { return false; }
    for (var i = 0; i < els.length; i++) {
      if (visible(els[i])) { els[i].click(); return true; }
    }
    return false;
  }

  var NEXT_STRICT = /(n(ä|ae)chste|next)\s*(folge|episode|ep\b|ep\.|teil)/i;
  var NEXT_CLASS = /next[-_]?(episode|ep)\b|episode[-_]?next|vjs-next|jw-icon-next|skip-next|nextep|btn-next/i;
  var NEXT_LOOSE = /^\s*(n(ä|ae)chste[rs]?|next|weiter)\s*[›»>→]?\s*$|^\s*[›»→]\s*$/i;
  function findNext(loose) {
    var els;
    try { els = D.querySelectorAll('a,button,[role=button],[class*="next"],[class*="Next"],[aria-label]'); } catch (e) { return null; }
    for (var pass = 0; pass < (loose ? 2 : 1); pass++) {
      for (var i = 0; i < els.length; i++) {
        var el = els[i];
        var label = ((el.getAttribute('aria-label') || '') + ' ' + (el.getAttribute('title') || '') + ' ' + (el.textContent || '')).replace(/\s+/g, ' ').trim();
        if (label.length > 60) label = label.slice(0, 60);
        var ok = pass === 0 ? (NEXT_STRICT.test(label) || NEXT_CLASS.test(clsOf(el))) : NEXT_LOOSE.test(label);
        if (ok && visible(el)) return el;
      }
    }
    return null;
  }

  function control(name, arg) {
    if (name === 'next') {
      var n = findNext(!isTop);
      if (n) { n.click(); call('nextDone'); }
      return;
    }
    var v = mainVideo();
    if (name === 'autoplay') {
      if (v) { if (v.paused) tryPlay(v); } else clickBigPlay();
      return;
    }
    if (!v) return;
    var d = v.duration;
    var real = !isFinite(d) || d >= 30;
    switch (name) {
      case 'toggle': if (v.paused) tryPlay(v); else v.pause(); break;
      case 'play': tryPlay(v); break;
      case 'pause': v.pause(); break;
      case 'seek':
        if (real) {
          var t = v.currentTime + Number(arg || 0);
          if (isFinite(d)) t = Math.min(t, d - 1);
          v.currentTime = Math.max(0, t);
        }
        break;
      case 'seekTo':
        if (isFinite(d) && d >= 300) { v.currentTime = Math.max(0, Number(arg || 0)); tryPlay(v); }
        break;
      case 'maximize': if (real) toggleMax(v); break;
      case 'rate':
        O.rate = Number(arg) || 1;
        if (real) { try { v.playbackRate = O.rate; } catch (e) {} }
        break;
      case 'unmaximize': if (v.__ovlMax) toggleMax(v, false); break;
    }
  }

  /** Befehl ausführen und an alle iframes weiterreichen (dort läuft dieselbe Logik). */
  O.cmd = function (name, arg) {
    try { control(name, arg); } catch (e) {}
    var fr = D.getElementsByTagName('iframe');
    for (var i = 0; i < fr.length; i++) {
      try { fr[i].contentWindow.postMessage({ __ovl: 1, cmd: name, arg: arg }, '*'); } catch (e) {}
    }
    return true;
  };
  W.addEventListener('message', function (e) {
    var m = e.data;
    if (!m || typeof m !== 'object' || m.__ovl !== 1) return;
    if (m.cmd && e.source === W.parent && !isTop) O.cmd(m.cmd, m.arg);
    else if (m.maxMe) maxChildFrame(e.source, !!m.on);
  }, false);

  O.nextLocal = safe(function () {
    var n = findNext(false);
    if (n) { n.click(); return true; }
    return false;
  });
  O.nextByUrl = safe(function () {
    var u = String(location.href);
    var re = /(^|[^a-z])(episode|folge|ep|e)([-_\/=]?)(\d+)(?!.*[^a-z](episode|folge|ep|e)[-_\/=]?\d)/i;
    var m = u.match(re);
    if (!m) return false;
    var n = String(parseInt(m[4], 10) + 1);
    while (n.length < m[4].length) n = '0' + n;
    location.href = u.replace(re, m[1] + m[2] + m[3] + n);
    return true;
  });

  /* ------------------------------------------------------------------ Intro/Werbung überspringen */
  var AUTOSKIP = true;
  try { if (B && B.autoSkip) AUTOSKIP = !!B.autoSkip(); } catch (e) {}
  var SKIP_RE = /^\s*((intro|vorspann|opening|r(ü|ue)ckblick|recap|zusammenfassung|werbung|anzeige|ad|ads)\s*(jetzt\s*)?((ü|ue)berspringen|skip)|skip\s*(intro|recap|opening|ad|ads)|(ü|ue)berspringen|skip)\s*[›»>→]?\s*$/i;
  var SKIP_SEL = 'button,[role=button],[class*="skip"],[class*="Skip"],[id*="skip"],[class*="intro"],.ytp-ad-skip-button,.ytp-skip-ad-button';
  var skipScan = safe(function () {
    if (!AUTOSKIP || !D.body) return;
    var els = D.querySelectorAll(SKIP_SEL);
    for (var i = 0; i < els.length && i < 400; i++) {
      var el = els[i];
      if (el.__ovlSkipped) continue;
      var t = ((el.getAttribute('aria-label') || '') + ' ' + (el.textContent || '')).replace(/\s+/g, ' ').trim();
      if (!t || t.length > 40 || !SKIP_RE.test(t)) continue;
      if (!visible(el)) continue;
      el.__ovlSkipped = true;
      el.click();
      call('skipped', t);
    }
  });
  setInterval(skipScan, 1200);

  /* ------------------------------------------------------------------ Texteingabe */
  function isTextInput(t) {
    if (!t || !t.tagName) return false;
    if (t.isContentEditable || t.tagName === 'TEXTAREA') return true;
    return t.tagName === 'INPUT' && /^(text|search|email|url|password|tel|number|)$/i.test(t.type || '');
  }
  D.addEventListener('focusin', function (e) { if (isTextInput(e.target)) call('textFocus', true); }, true);
  D.addEventListener('focusout', function (e) { if (isTextInput(e.target)) call('textFocus', false); }, true);

  /* ------------------------------------------------------------------ Link-Navigation (nur Hauptframe) */
  function visible(el) {
    if (!el || !el.getBoundingClientRect) return false;
    var r = el.getBoundingClientRect();
    if (r.width < 4 || r.height < 4) return false;
    var cs = W.getComputedStyle(el);
    if (cs.visibility === 'hidden' || cs.display === 'none' || parseFloat(cs.opacity) === 0) return false;
    if (cs.pointerEvents === 'none' && el.tagName !== 'IFRAME' && el.tagName !== 'VIDEO') return false;
    return true;
  }
  O.visible = visible;

  if (!isTop) return;

  var SEL = 'a[href],button,input:not([type=hidden]),select,textarea,summary,[role=button],[role=link],' +
    '[role=menuitem],[role=tab],[role=option],[role=checkbox],[onclick],[tabindex]:not([tabindex="-1"]),' +
    'video,iframe,[contenteditable=""],[contenteditable="true"],label[for]';
  var cur = null, hl = null, hlOn = true;

  function candidates() {
    var all;
    try { all = D.querySelectorAll(SEL); } catch (e) { all = D.querySelectorAll('a[href],button,input,select,textarea,iframe,video'); }
    var out = [];
    for (var i = 0; i < all.length && out.length < 4000; i++) {
      var el = all[i];
      if (el.id === '__ovl_hl' || el.disabled) continue;
      if (visible(el)) out.push(el);
    }
    // Verschachtelte Kandidaten entfernen (z. B. <a><div onclick></div></a>): innere fliegen raus,
    // wenn sie fast die gleiche Fläche wie der äußere Kandidat haben.
    var res = [];
    for (var j = 0; j < out.length; j++) {
      var p = out[j].parentElement, dup = false, depth = 0;
      while (p && depth++ < 4) {
        if (out.indexOf(p) >= 0) {
          var a = p.getBoundingClientRect(), b = out[j].getBoundingClientRect();
          if (b.width * b.height > a.width * a.height * 0.6) { dup = true; }
          break;
        }
        p = p.parentElement;
      }
      if (!dup) res.push(out[j]);
    }
    return res;
  }

  function inViewport(r) {
    return r.bottom > 0 && r.right > 0 && r.top < W.innerHeight && r.left < W.innerWidth;
  }

  function overlap(a1, a2, b1, b2) { return Math.min(a2, b2) - Math.max(a1, b1); }

  function score(dir, a, b) {
    var ax = (a.left + a.right) / 2, ay = (a.top + a.bottom) / 2;
    var bx = (b.left + b.right) / 2, by = (b.top + b.bottom) / 2;
    var major, minor, ov;
    if (dir === 'down') {
      if (by <= ay + 1 || b.bottom <= a.bottom) return -1;
      major = Math.max(0, b.top - a.bottom) + (by - ay) * 0.05;
      ov = overlap(a.left, a.right, b.left, b.right);
      minor = ov > 0 ? Math.abs(bx - ax) * 0.15 : Math.min(Math.abs(b.left - a.right), Math.abs(a.left - b.right)) + 40;
    } else if (dir === 'up') {
      if (by >= ay - 1 || b.top >= a.top) return -1;
      major = Math.max(0, a.top - b.bottom) + (ay - by) * 0.05;
      ov = overlap(a.left, a.right, b.left, b.right);
      minor = ov > 0 ? Math.abs(bx - ax) * 0.15 : Math.min(Math.abs(b.left - a.right), Math.abs(a.left - b.right)) + 40;
    } else if (dir === 'right') {
      if (bx <= ax + 1 || b.right <= a.right) return -1;
      major = Math.max(0, b.left - a.right) + (bx - ax) * 0.05;
      ov = overlap(a.top, a.bottom, b.top, b.bottom);
      minor = ov > 0 ? Math.abs(by - ay) * 0.15 : Math.min(Math.abs(b.top - a.bottom), Math.abs(a.top - b.bottom)) + 40;
    } else {
      if (bx >= ax - 1 || b.left >= a.left) return -1;
      major = Math.max(0, a.left - b.right) + (ax - bx) * 0.05;
      ov = overlap(a.top, a.bottom, b.top, b.bottom);
      minor = ov > 0 ? Math.abs(by - ay) * 0.15 : Math.min(Math.abs(b.top - a.bottom), Math.abs(a.top - b.bottom)) + 40;
    }
    return major + minor * 2.5;
  }

  function ensureHl() {
    if (hl && hl.parentNode) return hl;
    hl = D.createElement('div');
    hl.id = '__ovl_hl';
    (D.body || D.documentElement).appendChild(hl);
    return hl;
  }
  var drawHl = safe(function () {
    if (!hlOn || !cur || !cur.isConnected && !D.documentElement.contains(cur)) { if (hl) hl.style.display = 'none'; return; }
    var r = cur.getBoundingClientRect();
    var h = ensureHl();
    h.style.display = 'block';
    h.style.left = (r.left - 4) + 'px';
    h.style.top = (r.top - 4) + 'px';
    h.style.width = (r.width + 8) + 'px';
    h.style.height = (r.height + 8) + 'px';
  });
  W.addEventListener('scroll', drawHl, true);
  W.addEventListener('resize', drawHl);
  setInterval(drawHl, 400);

  function setCur(el) {
    cur = el;
    var r = el.getBoundingClientRect();
    if (r.top < 0 || r.bottom > W.innerHeight || r.left < 0 || r.right > W.innerWidth) {
      try { el.scrollIntoView({ block: 'center', inline: 'nearest' }); } catch (e) { el.scrollIntoView(false); }
    }
    try {
      var ev = D.createEvent('MouseEvents');
      ev.initMouseEvent('mouseover', true, true, W, 0, 0, 0, 0, 0, false, false, false, false, 0, null);
      el.dispatchEvent(ev);
    } catch (e) {}
    if (!isTextInput(el) && el.tagName !== 'IFRAME' && el.focus) {
      try { el.focus({ preventScroll: true }); } catch (e) {}
    }
    drawHl();
  }

  function scrollableAncestor(el, horizontal) {
    while (el && el !== D.body && el !== D.documentElement) {
      var cs = W.getComputedStyle(el);
      var ov = horizontal ? cs.overflowX : cs.overflowY;
      if ((ov === 'auto' || ov === 'scroll') &&
        (horizontal ? el.scrollWidth > el.clientWidth + 2 : el.scrollHeight > el.clientHeight + 2)) return el;
      el = el.parentElement;
    }
    return null;
  }

  function scrollDir(dir, from) {
    var dx = 0, dy = 0;
    if (dir === 'down') dy = W.innerHeight * 0.6;
    if (dir === 'up') dy = -W.innerHeight * 0.6;
    if (dir === 'right') dx = W.innerWidth * 0.6;
    if (dir === 'left') dx = -W.innerWidth * 0.6;
    var c = from ? scrollableAncestor(from, dx !== 0) : null;
    if (!c) {
      var center = D.elementFromPoint(W.innerWidth / 2, W.innerHeight / 2);
      c = center ? scrollableAncestor(center, dx !== 0) : null;
    }
    if (c) c.scrollBy ? c.scrollBy(dx, dy) : (c.scrollTop += dy, c.scrollLeft += dx);
    else W.scrollBy(dx, dy);
  }

  /** Steuerkreuz im Link-Modus: springt zum nächsten Link in Richtung [dir]. */
  O.nav = safe(function (dir) {
    hlOn = true;
    var cands = candidates();
    var curOk = cur && D.documentElement.contains(cur) && visible(cur) && inViewport(cur.getBoundingClientRect());
    if (!curOk) {
      var best = null, bestS = 1e12;
      for (var i = 0; i < cands.length; i++) {
        var r = cands[i].getBoundingClientRect();
        if (!inViewport(r)) continue;
        var s = Math.max(0, r.top) * 2 + Math.max(0, r.left);
        if (s < bestS) { bestS = s; best = cands[i]; }
      }
      if (best) { setCur(best); return { ok: true }; }
      scrollDir(dir, null);
      return { ok: false, scrolled: true };
    }
    var a = cur.getBoundingClientRect();
    var pick = null, pickS = 1e12;
    for (var k = 0; k < cands.length; k++) {
      var el = cands[k];
      if (el === cur || el.contains(cur) || cur.contains(el)) continue;
      var b = el.getBoundingClientRect();
      var sc = score(dir, a, b);
      if (sc < 0) continue;
      // Ziele weit außerhalb des Bildschirms abwerten → erst scrollen
      if (!inViewport(b)) sc += 300;
      if (sc < pickS) { pickS = sc; pick = el; }
    }
    var limit = (dir === 'up' || dir === 'down') ? W.innerHeight * 0.9 : W.innerWidth * 0.9;
    if (pick && pickS < limit + 300) { setCur(pick); return { ok: true }; }
    scrollDir(dir, cur);
    setTimeout(drawHl, 120);
    return { ok: false, scrolled: true };
  });

  /** OK im Link-Modus: liefert Mittelpunkt des gewählten Elements → Android tippt dort echt. */
  O.activate = safe(function () {
    if (!cur || !D.documentElement.contains(cur)) return null;
    var r = cur.getBoundingClientRect();
    if (!inViewport(r)) {
      try { cur.scrollIntoView({ block: 'center' }); } catch (e) { cur.scrollIntoView(); }
      r = cur.getBoundingClientRect();
    }
    var x = r.left + r.width / 2, y = r.top + r.height / 2;
    x = Math.max(1, Math.min(W.innerWidth - 1, x));
    y = Math.max(1, Math.min(W.innerHeight - 1, y));
    var media = cur.tagName === 'VIDEO' || cur.tagName === 'IFRAME' || !!(cur.querySelector && cur.querySelector('video,iframe')) ||
      PLAYERISH.test(clsOf(cur));
    return { x: x, y: y, iw: W.innerWidth, tag: cur.tagName, media: media };
  });

  O.showHl = safe(function (on) { hlOn = !!on; drawHl(); });

  /** Vorschaubild, Symbol und Markenfarbe der Seite (für Weiterschauen-Karten). */
  O.pageMeta = safe(function () {
    function meta(sel) { var m = D.querySelector(sel); return m ? (m.getAttribute('content') || '') : ''; }
    function abs(u) { try { return u ? new URL(u, location.href).href : ''; } catch (e) { return ''; } }
    var icon = D.querySelector('link[rel~="apple-touch-icon"],link[rel="apple-touch-icon-precomposed"],link[rel~="icon"][sizes]');
    return {
      og: abs(meta('meta[property="og:image"]') || meta('meta[name="twitter:image"]')),
      icon: abs(icon ? icon.getAttribute('href') : ''),
      theme: meta('meta[name="theme-color"]')
    };
  });

  O.viewport = function () { return { iw: W.innerWidth, ih: W.innerHeight }; };

  /** Zeiger-Modus: an Position (CSS-Pixel) scrollen – auch in scrollbaren Containern. */
  O.scrollAt = safe(function (x, y, dx, dy) {
    var el = D.elementFromPoint(x, y);
    var c = el ? scrollableAncestor(el, dx !== 0) : null;
    if (c) { c.scrollTop += dy; c.scrollLeft += dx; } else W.scrollBy(dx, dy);
  });

  O.scrollPage = safe(function (dir) {
    scrollDir(dir > 0 ? 'down' : 'up', cur);
  });

  /* ------------------------------------------------------------------ Text vom Handy */
  O.insertText = safe(function (text, submit) {
    var el = D.activeElement;
    if (!isTextInput(el)) return false;
    if (el.isContentEditable) {
      D.execCommand('insertText', false, text);
    } else {
      var proto = el.tagName === 'TEXTAREA' ? HTMLTextAreaElement.prototype : HTMLInputElement.prototype;
      var desc = Object.getOwnPropertyDescriptor(proto, 'value');
      if (desc && desc.set) desc.set.call(el, text); else el.value = text;
      ['input', 'change'].forEach(function (n) { var ev = D.createEvent('Event'); ev.initEvent(n, true, true); el.dispatchEvent(ev); });
    }
    if (submit) {
      ['keydown', 'keypress', 'keyup'].forEach(function (n) {
        try { el.dispatchEvent(new KeyboardEvent(n, { key: 'Enter', code: 'Enter', keyCode: 13, which: 13, bubbles: true, cancelable: true })); } catch (e) {}
      });
      var f = el.form;
      if (f) { try { if (f.requestSubmit) f.requestSubmit(); else f.submit(); } catch (e) {} }
    }
    return true;
  });

  /* ------------------------------------------------------------------ Schnellsuche */
  var SEARCH_SEL = 'input[type=search],input[name=q],input[name=s],input[name=search],input[name=query],' +
    'input[name=keyword],input[name=keywords],input[name*=search],input[name*=query],input[id*=search],' +
    'input[class*=search],input[placeholder*=uch],input[placeholder*=earch],input[aria-label*=uch],input[aria-label*=earch]';
  var SEARCH_TOGGLE = '[aria-label*=Such],[aria-label*=such],[aria-label*=Search],[aria-label*=search],' +
    '[class*=search-toggle],[class*=search-icon],[class*=searchIcon],[class*=search-btn],a[href*="/search"],a[href*="/suche"]';
  O.search = safe(function (term, second) {
    var inputs = D.querySelectorAll(SEARCH_SEL);
    var input = null;
    for (var i = 0; i < inputs.length; i++) {
      var t = (inputs[i].type || 'text').toLowerCase();
      if (t !== 'text' && t !== 'search' && t !== '') continue;
      if (visible(inputs[i])) { input = inputs[i]; break; }
      if (!input) input = inputs[i];
    }
    if (!input) {
      if (second) return 'none';
      var toggles = D.querySelectorAll(SEARCH_TOGGLE);
      for (var k = 0; k < toggles.length; k++) {
        if (visible(toggles[k])) { toggles[k].click(); return 'opened'; }
      }
      return 'none';
    }
    try { input.focus(); } catch (e) {}
    var setter = Object.getOwnPropertyDescriptor(HTMLInputElement.prototype, 'value');
    if (setter && setter.set) setter.set.call(input, term); else input.value = term;
    ['input', 'change', 'keyup'].forEach(function (n) {
      var ev = D.createEvent('Event'); ev.initEvent(n, true, true); input.dispatchEvent(ev);
    });
    setTimeout(function () {
      var ok = false;
      ['keydown', 'keypress', 'keyup'].forEach(function (n) {
        try {
          var ke = new KeyboardEvent(n, { key: 'Enter', code: 'Enter', keyCode: 13, which: 13, bubbles: true, cancelable: true });
          input.dispatchEvent(ke);
        } catch (e) {}
      });
      var f = input.form;
      if (f) {
        try { if (f.requestSubmit) { f.requestSubmit(); ok = true; } } catch (e) {}
        if (!ok) { try { f.submit(); } catch (e) {} }
      }
    }, 150);
    return 'ok';
  });
})();
