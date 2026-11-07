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
  function cleanLabel(el) {
    var t = String(el.innerText || el.textContent || '').replace(/\s+/g, ' ').trim();
    if (!t) t = String(el.getAttribute('aria-label') || el.value || el.getAttribute('title') || '').replace(/\s+/g, ' ').trim();
    return t;
  }

  /* Shadow-DOM: Wurzeln merken (auch „closed“), damit Player, Play-Knöpfe und Cookie-Dialoge
     darin gefunden werden. Läuft vor den Skripten der Seite (Document-Start). */
  var SHADOWS = [];
  var MEDIA_EVENTS = ['play', 'pause', 'seeked', 'loadedmetadata', 'ended'];
  function mediaEvent(e) {
    if (e.target && e.target.tagName === 'VIDEO') setTimeout(function () { try { report(); } catch (x) {} }, 60);
  }
  try {
    var origAttach = Element.prototype.attachShadow;
    if (origAttach) Element.prototype.attachShadow = function () {
      var sr = origAttach.apply(this, arguments);
      try {
        SHADOWS.push(sr);
        // Medien-Ereignisse verlassen den Shadow-DOM nicht → dort direkt lauschen
        MEDIA_EVENTS.forEach(function (t) { sr.addEventListener(t, mediaEvent, true); });
      } catch (e) {}
      return sr;
    };
  } catch (e) {}
  function liveShadows() {
    var out = [];
    for (var i = 0; i < SHADOWS.length; i++) {
      var h = SHADOWS[i].host;
      if (h && (h.isConnected === undefined ? D.documentElement.contains(h) : h.isConnected)) out.push(SHADOWS[i]);
    }
    if (SHADOWS.length > 200 && out.length < SHADOWS.length) SHADOWS = out;
    return out;
  }
  /** querySelectorAll über das Dokument und alle Shadow-Wurzeln. */
  function deepAll(sel) {
    var list = [].slice.call(D.querySelectorAll(sel));
    var srs = liveShadows();
    for (var i = 0; i < srs.length; i++) {
      try { list = list.concat([].slice.call(srs[i].querySelectorAll(sel))); } catch (e) {}
    }
    return list;
  }

  // Manche Player verlangen ein „window.chrome“-Objekt, das der Android-WebView fehlt
  try { if (!W.chrome) W.chrome = { runtime: {}, app: { isInstalled: false }, csi: function () {}, loadTimes: function () {} }; } catch (e) {}

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
  var ACC = '#8B5CF6';
  try { if (B && B.accent) ACC = String(B.accent()); } catch (e) {}
  var CSS = (PROTECT ? HIDE + '{display:none!important;visibility:hidden!important;pointer-events:none!important}' : '') +
    '#__ovl_hl{position:fixed;z-index:2147483647;pointer-events:none;border:3px solid #fff;border-radius:10px;' +
    'box-shadow:0 0 0 3px ' + ACC + ',0 0 26px 6px ' + ACC + 'BF,inset 0 0 0 1px rgba(0,0,0,.35);' +
    'background:' + ACC + '1A;transition:all .14s ease-out;display:none;box-sizing:border-box}';
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
    var list = deepAll('video');
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
        (v.paused ? 0 : 8000) + (v.readyState > 0 ? 100 : 0) - (isBackdrop(v) ? 20000 : 0);
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
  MEDIA_EVENTS.forEach(function (t) { D.addEventListener(t, mediaEvent, true); });

  function tryPlay(v) {
    try { var p = v.play(); if (p && p['catch']) p['catch'](function () {}); } catch (e) {}
  }

  /** Stummes Endlos-Video ohne Bedienelemente = Hintergrund-/Vorschau-Video, kein Player. */
  function isBackdrop(v) {
    if (v.controls) return false;
    var muted = v.muted || v.hasAttribute('muted');
    if (!muted) return false;
    if (v.loop) return true;
    // Stummes Autoplay-Video: in einem Link, in einem Teaser-/Hero-Bereich oder kurz = Vorschau/Trailer
    if (v.autoplay || v.hasAttribute('autoplay') || !v.paused) {
      if (closestSel(v, 'a[href]')) return true;
      var n = v.parentElement, k = 0, playerish = false;
      while (n && k++ < 6) {
        var c = clsOf(n);
        if (/hero|teaser|preview|backdrop|background|banner|trailer|cover|header-?video|ambient/i.test(c)) return true;
        if (/player|vjs|video-js|jw|plyr|bitmovin|shaka|mejs|flowplayer|clappr|dplayer|artplayer/i.test(c)) playerish = true;
        n = n.parentElement;
      }
      // Kurzer stummer Clip außerhalb eines Players (z. B. Trailer im Seitenkopf)
      var d = v.duration;
      if (!playerish && isFinite(d) && d > 0 && d < 180) return true;
    }
    return false;
  }

  var STYLE_MAX = ';position:fixed!important;left:0!important;top:0!important;right:0!important;bottom:0!important;' +
    'width:100vw!important;height:100vh!important;max-width:none!important;max-height:none!important;' +
    'z-index:2147483646!important;background:#000!important;margin:0!important;border:0!important;' +
    'transform:none!important;object-fit:contain!important;visibility:visible!important;opacity:1!important;';
  // Vorfahren: alles entfernen, was „position:fixed“ an den Vorfahren statt an den Bildschirm bindet
  var STYLE_ANC = ';transform:none!important;filter:none!important;perspective:none!important;contain:none!important;' +
    'will-change:auto!important;-webkit-clip-path:none!important;clip-path:none!important;' +
    '-webkit-mask-image:none!important;mask-image:none!important;backdrop-filter:none!important;' +
    'visibility:visible!important;opacity:1!important;';
  var STYLE_HIDE = ';visibility:hidden!important;opacity:0!important;pointer-events:none!important;';
  var cinemaOn = false;   // Overlord hat selbst ein Element bildschirmfüllend gemacht (Nachbarn ausgeblendet)
  function stash(el, extra) {
    if (el.__ovlOld === undefined) el.__ovlOld = el.getAttribute('style') || '';
    el.setAttribute('style', el.__ovlOld + extra);
  }
  function unstash(el) {
    if (el.__ovlOld === undefined) return;
    if (el.__ovlOld) el.setAttribute('style', el.__ovlOld); else el.removeAttribute('style');
    el.__ovlOld = undefined;
  }
  var maxTouched = [];
  /** Element bildschirmfüllend: Vorfahren entschärfen, alles daneben ausblenden (auch über Shadow-DOM-Grenzen). */
  function applyMax(el, on) {
    if (on) {
      stash(el, STYLE_MAX);
      var n = el, depth = 0;
      while (n && depth++ < 60) {
        var p = n.parentNode;
        if (!p || p === D || p === D.documentElement) break;
        var kids = p.children || [];
        for (var i = 0; i < kids.length; i++) {
          var s = kids[i];
          if (s === n || s.__ovlOld !== undefined || /^(SCRIPT|STYLE|LINK|META|TEMPLATE|SLOT)$/.test(s.tagName)) continue;
          stash(s, STYLE_HIDE);
          maxTouched.push(s);
        }
        if (p.nodeType === 11) { n = p.host; continue; }   // Shadow-Wurzel → weiter beim Host
        if (p !== D.body) { stash(p, STYLE_ANC); maxTouched.push(p); }
        n = p;
      }
    } else {
      unstash(el);
      for (var j = 0; j < maxTouched.length; j++) unstash(maxTouched[j]);
      maxTouched = [];
    }
    cinemaOn = !!on;
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
    '[aria-label*="Play"],[aria-label*="play"],[aria-label*="Abspielen"],[aria-label*="abspielen"],[aria-label*="Wiedergabe"],' +
    '[title*="Play"],[title*="play"],[title*="Abspielen"]';
  function clickBigPlay() {
    var els;
    try { els = deepAll(BIG_PLAY); } catch (e) { return false; }
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
    else if (m.tapReq) relayTap(e.source, m);
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
    if (cs.display === 'none') return false;
    // Im Kino-Modus blendet Overlord selbst alles neben dem Player aus – das zählt nicht als unsichtbar
    if (cinemaOn) return true;
    if (cs.visibility === 'hidden' || parseFloat(cs.opacity) === 0) return false;
    if (cs.pointerEvents === 'none' && el.tagName !== 'IFRAME' && el.tagName !== 'VIDEO') return false;
    return true;
  }
  O.visible = visible;

  /* ------------------------------------------------------------------ Cookie-Hinweise */
  /* Einwilligungs-Dialoge automatisch beantworten (Einstellung: ablehnen / zustimmen / aus).
     Läuft in allen Frames – viele Dialoge stecken in eigenen iframes oder im Shadow-DOM. */
  var CONSENT = 'reject';
  try { if (B && B.consentMode) CONSENT = String(B.consentMode()); } catch (e) {}
  var CONSENT_TXT = /cookie|datenschutz|privacy|privacidad|confidentialit|consent|einwillig|zustimm|tracking|personalisier|drittanbieter|dienstleister|partner|gdpr|dsgvo|rgpd|vie priv/i;
  var CONSENT_BOX = /consent|cookie|cmp|gdpr|privacy|datenschutz|usercentrics|onetrust|didomi|sp_message|cookiebot|klaro|borlabs|truste|qc-cmp|fc-consent|cc-window|cc-banner/i;
  var REJECT_RE = /^(alle[ns]?\s+)?(ablehnen|verweigern|zur(ü|ue)ckweisen)\b|^(nur|lediglich)\s+(technisch\s+)?(notwendige|erforderliche|essen[zt]ielle|funktionale|n(ö|oe)tige)|^nicht\s+(einverstanden|zustimmen|akzeptieren)|^(alle\s+)?(reject|decline|deny|refuse)(\s+all)?\b|^(use\s+)?(only\s+)?(strictly\s+)?(necessary|essential|required)(\s+cookies)?(\s+only)?$|^continue\s+without|^weiter\s+ohne|^ohne\s+(einwilligung|zustimmung)|^tout\s+refuser|^refuser|^continuer\s+sans/i;
  var SAVE_RE = /^(auswahl|einstellungen|pr(ä|ae)ferenzen)\s+(speichern|best(ä|ae)tigen|(ü|ue)bernehmen)|^(save|confirm)\s+(my\s+)?(choices|selection|settings|preferences)|^speichern(\s+und\s+(schlie(ß|ss)en|beenden))?$|^enregistrer/i;
  var ACCEPT_RE = /^(alle[ns]?\s+)?(akzeptieren|zustimmen|annehmen|erlauben|zulassen|best(ä|ae)tigen)\b|^einverstanden|^ich\s+(stimme\s+zu|bin\s+einverstanden|akzeptiere)|^(accept|agree|allow)(\s+all)?(\s+cookies)?(\s+and\s+continue)?$|^(i\s+)?(accept|agree)\b|^(ok|okay|verstanden|got\s+it|alles\s+klar)\s*[!.]?$|^tout\s+accepter|^accepter/i;
  var CMP_FRAME = /consent|cmp|privacy|cookie|gdpr|sp_message|usercentrics|onetrust|didomi|trustarc|quantcast|sourcepoint|cookiebot|klaro|borlabs/i;
  var consentDone = false, consentTries = 0;
  O.consentInfo = '';
  var CONSENT_STRICT = /cookie|consent|einwillig|tracking/i;
  function consentContext(el, strict) {
    if (!isTop && CMP_FRAME.test(String(location.href))) return true;
    var n = el, depth = 0;
    while (n && depth++ < 16) {
      if (n.nodeType === 11) { n = n.host; continue; }   // Shadow-Wurzel → Host
      if (n.nodeType !== 1 || n === D.body || n === D.documentElement) break;
      var role = n.getAttribute('role') || '';
      var box = n.tagName === 'DIALOG' || role === 'dialog' || role === 'alertdialog' || n.getAttribute('aria-modal') === 'true' ||
        CONSENT_BOX.test(clsOf(n));
      if (!box) { var pos = W.getComputedStyle(n).position; box = pos === 'fixed' || pos === 'sticky'; }
      if (box) {
        var txt = String(n.innerText || n.textContent || '').slice(0, 5000);
        if (CONSENT_TXT.test(txt) && (!strict || CONSENT_STRICT.test(txt))) return true;
      }
      n = n.parentNode;
    }
    return false;
  }
  var consentScan = safe(function () {
    if (consentDone || CONSENT === 'off' || !D.body) return;
    if (++consentTries > 45) return;   // nach ~40 s aufgeben
    var els = deepAll('button,a,[role="button"],input[type="button"],input[type="submit"],[class*="button"],[class*="btn"],[tabindex="0"]');
    var reject = null, save = null, accept = null;
    for (var i = 0; i < els.length && i < 4000; i++) {
      var el = els[i];
      // textContent ist billig (kein Layout) – innerText erst für Treffer
      var t = String(el.textContent || '');
      if (t.length > 200) continue;
      t = t.replace(/\s+/g, ' ').trim() || String(el.getAttribute('aria-label') || el.value || el.getAttribute('title') || '').replace(/\s+/g, ' ').trim();
      if (!t || t.length > 60) continue;
      var kind = REJECT_RE.test(t) ? 1 : (SAVE_RE.test(t) ? 2 : (ACCEPT_RE.test(t) ? 3 : 0));
      if (!kind || (kind === 1 && reject) || (kind === 2 && save) || (kind === 3 && accept)) continue;
      // „Speichern“ nur in eindeutigen Cookie-Dialogen (nicht in Einstellungsdialogen der Seite)
      if (!visible(el) || !consentContext(el, kind === 2)) continue;
      if (kind === 1) reject = el; else if (kind === 2) save = el; else accept = el;
    }
    var pick = CONSENT === 'accept' ? (accept || null) : (reject || save);
    if (!pick) {
      if (accept || reject || save) O.consentInfo = 'Dialog ohne passenden Knopf (' + cleanLabel(accept || reject || save).slice(0, 30) + ')';
      return;
    }
    consentDone = true;
    var label = cleanLabel(pick).slice(0, 40);
    O.consentInfo = 'gewählt: ' + label;
    try { pick.click(); } catch (e) {}
    call('consentHandled', label);
    // Manche Dialoge ignorieren Skript-Klicks: bleibt der Knopf sichtbar, tippt die App ihn echt an
    setTimeout(function () {
      if (!stillThere(pick)) return;
      O.consentInfo = 'Tipp angefordert: ' + label;
      requestTap(pick, label);
      setTimeout(function () {
        if (stillThere(pick)) O.consentInfo = 'Knopf reagiert nicht: ' + label;
        else { O.consentInfo = 'gewählt (Tipp): ' + label; call('consentHandled', label + ' (Tipp)'); }
      }, 3500);
    }, 1500);
  });
  setInterval(consentScan, 900);
  function stillThere(el) {
    var on = el.isConnected === undefined ? D.documentElement.contains(el) : el.isConnected;
    return on && visible(el);
  }

  /* Echter Tipp für Cookie-Knöpfe: Die App fragt ihn im Hauptframe ab (__ovl.consentTap) – iframes
     melden ihn per postMessage nach oben, aber nur Cookie-Dialog-Frames und nur innerhalb ihrer Fläche. */
  var consentTapReq = null;
  function requestTap(el, label) {
    var r = el.getBoundingClientRect();
    var x = r.left + r.width / 2, y = r.top + r.height / 2;
    if (isTop) consentTapReq = { x: x, y: y, iw: W.innerWidth, label: label, t: now() };
    else { try { W.parent.postMessage({ __ovl: 1, tapReq: 1, x: x, y: y, label: label }, '*'); } catch (e) {} }
  }
  function relayTap(src, m) {
    var fr = deepAll('iframe');
    for (var i = 0; i < fr.length; i++) {
      if (fr[i].contentWindow !== src) continue;
      var desc = String(fr[i].getAttribute('src') || '') + ' ' + clsOf(fr[i]) + ' ' + String(fr[i].getAttribute('title') || '');
      if (!CMP_FRAME.test(desc)) return;
      var r = fr[i].getBoundingClientRect();
      var x = Number(m.x), y = Number(m.y);
      if (!(x >= 0 && y >= 0 && x <= r.width && y <= r.height)) return;
      x += r.left + (fr[i].clientLeft || 0);
      y += r.top + (fr[i].clientTop || 0);
      if (isTop) consentTapReq = { x: x, y: y, iw: W.innerWidth, label: String(m.label || '').slice(0, 40), t: now() };
      else { try { W.parent.postMessage({ __ovl: 1, tapReq: 1, x: x, y: y, label: m.label }, '*'); } catch (e) {} }
      return;
    }
  }
  O.consentTap = function () {
    var r = consentTapReq;
    consentTapReq = null;
    if (!r || now() - r.t > 10000) return null;
    return { x: r.x, y: r.y, iw: r.iw, label: r.label };
  };

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
    // Auf den sichtbaren Bereich zuschneiden, damit bei riesigen Elementen alle vier Kanten sichtbar bleiben
    var vw = W.innerWidth, vh = W.innerHeight;
    var l = Math.max(r.left - 4, 4), t = Math.max(r.top - 4, 4);
    var rr = Math.min(r.right + 4, vw - 4), bb = Math.min(r.bottom + 4, vh - 4);
    if (rr - l < 8 || bb - t < 8) { h.style.display = 'none'; return; }
    h.style.display = 'block';
    h.style.left = l + 'px';
    h.style.top = t + 'px';
    h.style.width = (rr - l) + 'px';
    h.style.height = (bb - t) + 'px';
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

  /* ------------------------------------------------------------------ Video-Ansicht (Scraper) */
  /* Liest Karten (Bild + Titel + Link), Reihen und den Player einer Seite aus,
     damit Overlord sie als eigene TV-Oberfläche darstellen kann. */
  function matchesSel(el, sel) {
    var f = el.matches || el.webkitMatchesSelector || el.msMatchesSelector;
    try { return f ? f.call(el, sel) : false; } catch (e) { return false; }
  }
  function closestSel(el, sel) {
    while (el && el.nodeType === 1) { if (matchesSel(el, sel)) return el; el = el.parentElement; }
    return null;
  }
  function absUrl(u) {
    if (!u) return '';
    u = String(u).trim();
    if (/^data:|^blob:|^javascript:/i.test(u)) return '';
    try { return new URL(u, location.href).href; } catch (e) { return ''; }
  }
  function bestFromSrcset(ss) {
    if (!ss) return '';
    var best = '', bw = -1;
    ss.split(',').forEach(function (part) {
      var bits = part.trim().split(/\s+/);
      var w = parseInt(bits[1], 10) || 1;
      if (bits[0] && w > bw) { bw = w; best = bits[0]; }
    });
    return best;
  }
  function imageOf(root) {
    var im = root.tagName === 'IMG' ? root : root.querySelector('img');
    var src = '';
    var lazy = im ? (im.getAttribute('data-src') || im.getAttribute('data-lazy-src') || im.getAttribute('data-original') ||
      im.getAttribute('data-srcset') || '') : '';
    if (im && !lazy) {
      // Winzige Bilder (Symbole) – außer Platzhaltern von Lazy-Loadern, deren echtes Bild in data-* steht
      if (im.naturalWidth && im.naturalWidth < 60 && im.naturalHeight < 60) im = null;
    }
    if (im) {
      // Kleine Symbole (Flaggen, Icons) sind keine Vorschaubilder
      var ir = im.getBoundingClientRect();
      if (ir.width > 0 && (ir.width < 48 || ir.height < 30)) im = null;
    }
    if (im) {
      src = im.getAttribute('data-src') || im.getAttribute('data-lazy-src') || im.getAttribute('data-original') ||
        bestFromSrcset(im.getAttribute('data-srcset')) || bestFromSrcset(im.getAttribute('srcset')) || im.currentSrc || im.src;
    }
    if (!src) {
      var source = root.querySelector('source[srcset],source[data-srcset]');
      if (source) src = bestFromSrcset(source.getAttribute('data-srcset') || source.getAttribute('srcset'));
    }
    if (!src) {
      var cands = [root].concat([].slice.call(root.querySelectorAll('[style*="background"]'), 0, 6));
      for (var i = 0; i < cands.length && !src; i++) {
        var bg = '';
        try { bg = W.getComputedStyle(cands[i]).backgroundImage || ''; } catch (e) {}
        var m = /url\(["']?(.*?)["']?\)/.exec(bg);
        if (m) src = m[1];
      }
    }
    if (!src) {
      // Lazy-Loader mit <noscript><img src=…></noscript>-Ersatz
      var ns = root.querySelector('noscript');
      var nm = ns ? /<img[^>]+src=["']([^"']+)["']/i.exec(ns.textContent || ns.innerHTML || '') : null;
      if (nm) src = nm[1].replace(/&amp;/g, '&');
    }
    src = absUrl(src);
    if (/\.svg(\?|$)/i.test(src)) return '';
    return src;
  }
  function cleanText(t) { return String(t || '').replace(/\s+/g, ' ').trim(); }
  function linesOf(el) {
    var raw = String(el.innerText || el.textContent || '');
    return raw.split(/[\n\t]+/).map(cleanText).filter(function (x) { return x.length > 0; });
  }
  function titleOf(card, link, img) {
    var h = card.querySelector('h1,h2,h3,h4,h5,h6,[class*="title"],[class*="Title"],[class*="name"],[itemprop="name"]') ||
      card.querySelector('strong,b');
    var t = cleanText(link.getAttribute('title')) || cleanText(link.getAttribute('aria-label')) ||
      (h ? cleanText(h.textContent) : '') || (img ? cleanText(img.getAttribute('alt')) : '') ||
      cleanText(card.getAttribute('aria-label')) || (linesOf(link)[0] || '');
    if (t.length > 90) t = t.slice(0, 88) + '…';
    return t;
  }
  var DUR_RE = /\b(\d{1,2}:\d{2}(?::\d{2})?)\b|\b(\d{1,3})\s*(min\b|min\.|minuten)/i;
  var EP_RE = /\b(s\d{1,2}\s*e\d{1,3}|staffel\s*\d+|folge\s*\d+|episode\s*\d+|ep\.?\s*\d+|teil\s*\d+)\b/i;
  function subOf(card, title) {
    var lines = linesOf(card).filter(function (l) { return l !== title && title.indexOf(l) < 0; });
    if (lines.length && lines[0].length <= 60) return lines[0];
    var txt = lines.join(' ');
    var parts = [];
    var ep = EP_RE.exec(txt); if (ep && title.toLowerCase().indexOf(ep[0].toLowerCase()) < 0) parts.push(ep[0]);
    var d = DUR_RE.exec(txt); if (d) parts.push(d[0]);
    return parts.join(' · ');
  }
  function inChrome(el) { return !!closestSel(el, 'nav,header,footer,[role="navigation"],[role="banner"],[role="contentinfo"],#cookie,[class*="cookie"],[id*="cookie"],[class*="consent"]'); }

  var HEADING = 'h1,h2,h3,h4,[role="heading"],[class*="headline"],[class*="heading"],[class*="section-title"],[class*="sectionTitle"],[class*="rail-title"],[class*="row-title"]';
  function headingFor(container, firstItem) {
    var lbl = cleanText(container.getAttribute('aria-label'));
    if (lbl && lbl.length < 60) return lbl;
    var lb = container.getAttribute('aria-labelledby') || (container.parentElement && container.parentElement.getAttribute('aria-labelledby'));
    if (lb) {
      var le = D.getElementById(lb.split(/\s+/)[0]);
      var lt = le ? cleanText(le.textContent) : '';
      if (lt && lt.length < 70) return lt;
    }
    // Nächstgelegene Überschrift vor der ersten Karte – Kartentitel (in Links/Karten) zählen nicht
    var hs = container.querySelectorAll(HEADING), found = '';
    for (var i = 0; i < hs.length; i++) {
      var pos = hs[i].compareDocumentPosition(firstItem);
      if (!(pos & 4) || hs[i].contains(firstItem) || cardHeading(hs[i])) continue;
      var t = cleanText(hs[i].textContent);
      if (t && t.length < 70) found = t;
    }
    if (found) return found;
    var node = container;
    for (var depth = 0; depth < 4 && node; depth++) {
      var sib = node.previousElementSibling;
      for (var k = 0; k < 3 && sib; k++) {
        var h = (matchesSel(sib, HEADING) && !cardHeading(sib)) ? sib : null;
        if (!h) {
          var all = sib.querySelectorAll(HEADING);
          for (var q = all.length - 1; q >= 0 && !h; q--) if (!cardHeading(all[q])) h = all[q];
        }
        if (h) { var tt = cleanText(h.textContent); if (tt && tt.length < 70) return tt; }
        sib = sib.previousElementSibling;
      }
      node = node.parentElement;
    }
    return '';
  }
  function cardHeading(h) {
    if (closestSel(h, 'a[href]')) return true;
    var c = closestSel(h, 'li,article,[class*="card"],[class*="Card"],[class*="teaser"],[class*="Teaser"],[class*="tile"]');
    return !!(c && c.querySelector('img,picture') && c.querySelectorAll('a[href]').length <= 3 &&
      c.getBoundingClientRect().width < W.innerWidth * 0.6);
  }

  function findPlayer() {
    var best = null, area = 0;
    var els = deepAll('video,iframe,embed,object');
    for (var i = 0; i < els.length; i++) {
      var el = els[i], r = el.getBoundingClientRect();
      if (r.width < 200 || r.height < 110) continue;
      if (el.tagName === 'VIDEO' && isBackdrop(el)) continue;   // Hintergrund-Video, kein Player
      if (el.tagName === 'IFRAME') {
        var s = (el.src || el.getAttribute('data-src') || '') + ' ' + clsOf(el) + ' ' + (el.getAttribute('allow') || '') + (el.hasAttribute('allowfullscreen') ? ' allowfullscreen' : '');
        var looks = /player|embed|video|stream|watch|\/e\/|\/v\/|fullscreen|autoplay|encrypted-media/i.test(s) ||
          (r.width >= W.innerWidth * 0.45 && r.height >= 200);
        if (!looks || /doubleclick|googlesyndication|ads?[\.\/-]/i.test(el.src || '')) continue;
      }
      var a = r.width * r.height;
      if (a > area) { area = a; best = el; }
    }
    return best;
  }

  /* Player vor dem Start: großes 16:9-Vorschaubild mit Play-Knopf (das <video> entsteht oft erst nach dem Klick) */
  var PLAY_LABEL = /(^|[^a-z])(play|abspielen|wiedergabe|wiedergeben|starten|ansehen|anschauen|jetzt\s+(an)?sehen|watch|lecture|lire|reproducir)([^a-z]|$)/i;
  var PLAY_CLS = /(^|[\s_-])(play|big-?play|play-?(button|btn|icon|overlay|layer|cta)|start-?(button|screen))([\s_-]|$)/i;
  var NOT_PLAY = /playlist|autoplay|playback-?rate|speed|settings|einstellung|trailer-?link|merken|teilen|share|download/i;
  function playButtonIn(root) {
    var els = root.querySelectorAll('button,[role="button"],a,[class*="play"],[class*="Play"],[aria-label],svg');
    var rr = root.getBoundingClientRect(), cx = rr.left + rr.width / 2, cy = rr.top + rr.height / 2;
    var best = null, bestD = 1e9;
    for (var i = 0; i < els.length && i < 300; i++) {
      var el = els[i];
      if (el.tagName === 'svg' || el.tagName === 'SVG') { el = el.parentElement; if (!el || el === root) continue; }
      var lbl = ((el.getAttribute('aria-label') || '') + ' ' + (el.getAttribute('title') || '') + ' ' + cleanText(el.textContent)).slice(0, 80);
      var cls = clsOf(el);
      if (!(PLAY_LABEL.test(lbl) || PLAY_CLS.test(cls)) || NOT_PLAY.test(lbl + ' ' + cls)) continue;
      // Link zu einer anderen Seite = Teaser, kein Player
      if (el.tagName === 'A' && el.href && el.href.split('#')[0] !== location.href.split('#')[0]) continue;
      if (!visible(el)) continue;
      var r = el.getBoundingClientRect();
      var d = Math.abs(r.left + r.width / 2 - cx) + Math.abs(r.top + r.height / 2 - cy);
      if (d < bestD) { bestD = d; best = el; }
    }
    return best;
  }
  function findPlaceholder() {
    var vw = W.innerWidth, vh = W.innerHeight;
    var cands = deepAll('[class*="player"],[class*="Player"],[id*="player"],[id*="Player"],[class*="video"],[class*="Video"],' +
      '[data-player],[data-video],[data-testid*="player"],[data-testid*="video"],[class*="stage"],[class*="Stage"]');
    var best = null, bestA = 0;
    for (var i = 0; i < cands.length && i < 600; i++) {
      var el = cands[i], r = el.getBoundingClientRect();
      if (r.width < Math.max(240, vw * 0.4) || r.height < 135) continue;
      var ratio = r.width / r.height;
      if (ratio < 1.2 || ratio > 2.6) continue;
      if (r.top + (W.pageYOffset || 0) > vh * 2.2) continue;            // weit unten → eher Teaser
      if (inChrome(el) || closestSel(el, 'a[href]')) continue;           // ganzer Block ist ein Link → Teaser
      var btn = playButtonIn(el);
      if (!btn) continue;
      var a = r.width * r.height;
      if (a > bestA) { bestA = a; best = { el: el, btn: btn }; }
    }
    return best;
  }

  function isActive(el) {
    if (!el) return false;
    var c = clsOf(el) + ' ' + (el.parentElement ? clsOf(el.parentElement) : '');
    return /(^|[\s_-])(active|selected|current|is-active|aktiv|on)([\s_-]|$)/i.test(c) ||
      el.getAttribute('aria-selected') === 'true' || !!el.getAttribute('aria-current') ||
      (!!el.href && el.href.split('#')[0] === location.href.split('#')[0]);
  }

  /* Staffeln: Reiter/Links wie „Staffel 1“, „Season 2“, „Filme“, „Specials“ */
  var SEASON_RE = /^\s*((staffel|season|serie|teil|part)\s*\d+|\d+\.?\s*(staffel|season)|s\d{1,2}|filme?|movies?|specials?|extras?|ova)\s*$/i;
  var SEASON_OPT = /^\s*((staffel|season|saison|temporada)\s*\d+|\d+\.?\s*(staffel|season))\b/i;
  function seasonsOf() {
    O._seasonSelect = null;
    var els = D.querySelectorAll('a,button,[role="tab"],[data-season]');
    var hits = [];
    for (var i = 0; i < els.length && hits.length < 60; i++) {
      var el = els[i];
      if (closestSel(el, 'header,footer')) continue;
      var t = cleanText(el.textContent || el.getAttribute('aria-label'));
      if (!t || t.length > 24 || !SEASON_RE.test(t) || !visible(el)) continue;
      if (hits.some(function (h) { return h.contains(el) || el.contains(h); })) continue;
      hits.push(el);
    }
    if (hits.length < 2) {
      // Staffel-Auswahl als Klappliste (<select>)
      var sels = D.querySelectorAll('select');
      for (var si = 0; si < sels.length; si++) {
        var sel = sels[si];
        if (!visible(sel) || closestSel(sel, 'header,footer')) continue;
        var opts = [].filter.call(sel.options, function (o) { return SEASON_OPT.test(cleanText(o.textContent)); });
        if (opts.length < 2) continue;
        O._seasonSelect = sel;
        return opts.map(function (o) { return { title: cleanText(o.textContent).slice(0, 40), url: '', active: !!o.selected, index: o.index }; });
      }
      return [];
    }
    // Größte Gruppe im selben Container
    var best = [];
    hits.forEach(function (h) {
      var n = h.parentElement, depth = 0;
      while (n && depth++ < 5) {
        var group = hits.filter(function (x) { return n.contains(x); });
        if (group.length >= 2) { if (group.length > best.length) best = group; break; }
        n = n.parentElement;
      }
    });
    O._seasonEls = best;
    return best.map(function (el, i) {
      return { title: cleanText(el.textContent || el.getAttribute('aria-label')), url: (el.href && /^https?:/i.test(el.href)) ? el.href : '', active: isActive(el), index: i };
    });
  }
  O.clickSeason = safe(function (i) {
    var sel = O._seasonSelect;
    if (sel) {
      sel.selectedIndex = i;
      ['input', 'change'].forEach(function (n) { var ev = D.createEvent('Event'); ev.initEvent(n, true, true); sel.dispatchEvent(ev); });
      return true;
    }
    var el = (O._seasonEls || [])[i];
    if (!el) return false;
    el.click();
    return true;
  });

  /* Folgen: Links mit gleichem Adressmuster und fortlaufender Nummer (episode-1, folge-2, ?ep=3 …) */
  function episodeTitle(a, num) {
    var row = closestSel(a, 'tr,li,[class*="episode"],[class*="Episode"],[class*="folge"]') || a;
    var lines = linesOf(row).filter(function (l) { return !/^(#|nr\.?\s*)?\d+\.?$/i.test(l) && l.length < 90; });
    var t = lines.filter(function (l) { return !/^(folge|episode|ep\.?)\s*\d+\s*$/i.test(l); })[0] || '';
    if (/^(folge|episode|ep\.?)\s*\d+/i.test(t)) return { title: t, row: row };   // steht schon „Folge N – …“ da
    return { title: t ? ('Folge ' + num + ' – ' + t) : ('Folge ' + num), row: row };
  }
  /* (a) Fortlaufende Adressen: …/folge-1, …?episode=2 – gleiches Muster, nur die Nummer ändert sich */
  function urlEpisodes() {
    var links = D.querySelectorAll('a[href]');
    var groups = {};
    for (var i = 0; i < links.length; i++) {
      var a = links[i];
      if (closestSel(a, 'header,footer,[class*="pagination"],[class*="pager"]')) continue;
      if (/(n(ä|ae)chste|vorherige|next|prev|weiter|zur(ü|ue)ck)/i.test(cleanText(a.textContent) + ' ' + (a.getAttribute('aria-label') || ''))) continue;
      var u = a.href.split('#')[0];
      // Schlüsselwort muss am Wortanfang stehen (sonst wären /page/2, ?seite=3, /archive/2 … Fehlalarme)
      var m = /^(.*?(?:^|[^a-z])(?:episode|folge|ep|e)[-_\/=]?)(\d{1,3})(\D{0,24})$/i.exec(u);
      if (!m) continue;
      var key = m[1] + '#' + m[3];
      // Einträge aus Folgenlisten (Textzeilen) sind bessere Titelquellen als Bildkarten
      var score = (closestSel(a, 'tr,li,ol,table') ? 2 : 0) + (a.querySelector('img') ? -1 : 1);
      (groups[key] = groups[key] || []).push({ a: a, num: parseInt(m[2], 10), s: 0, url: u, score: score });
    }
    var best = null;
    Object.keys(groups).forEach(function (k) {
      var byNum = {}, list = [];
      groups[k].forEach(function (x) {
        var prev = byNum[x.num];
        if (!prev) { byNum[x.num] = x; list.push(x); }
        else if (x.score > prev.score) { list[list.indexOf(prev)] = x; byNum[x.num] = x; }
      });
      if (list.length >= 2 && (!best || list.length > best.length)) best = list;
    });
    return best;
  }

  /* (b) Nummer aus Text oder Adress-Teil („Folge 3“, „S01 E05“, …-s01-e05/…) – für Seiten mit eindeutiger ID je Folge */
  var EP_SE_TXT = /(?:^|[^a-z0-9])S(\d{1,2})\s*[|:\/,.]?\s*E(\d{1,3})(?![0-9])/i;
  var EP_SE_URL = /[-_\/]s(\d{1,2})[-_]?e(\d{1,3})(?=[-_\/.?#]|$)/i;
  var EP_N_TXT = /(?:^|[^a-zäöüé])(?:folge|[ée]pisode|ep\.|teil)\s*(\d{1,3})(?![0-9]|[.,][0-9])/i;
  var EP_N_URL = /[-_\/](?:folge|episode)[-_]?(\d{1,3})(?=[-_\/.?#]|$)/i;
  var EP_OF_TXT = /\((\d{1,3})\s*\/\s*(\d{1,3})\)/;   // „Die letzte Stunde (2/6)“
  function epNumFrom(text, url) {
    var m = EP_SE_TXT.exec(text) || EP_SE_URL.exec(url);
    if (m) return { s: parseInt(m[1], 10), e: parseInt(m[2], 10) };
    m = EP_N_TXT.exec(text) || EP_N_URL.exec(url);
    if (m) return { s: 0, e: parseInt(m[1], 10) };
    m = EP_OF_TXT.exec(text);
    if (m && parseInt(m[1], 10) >= 1 && parseInt(m[1], 10) <= parseInt(m[2], 10)) return { s: 0, e: parseInt(m[1], 10) };
    return null;
  }
  function textEpisodes() {
    var links = D.querySelectorAll('a[href]');
    var byUrl = {}, hits = [];
    for (var i = 0; i < links.length && hits.length < 400; i++) {
      var a = links[i];
      if (!/^https?:/i.test(a.href) || closestSel(a, 'header,footer,nav,[class*="pagination"],[class*="pager"]')) continue;
      var txt = cleanText((a.getAttribute('aria-label') || '') + ' ' + (a.getAttribute('title') || '') + ' ' + (a.innerText || a.textContent || ''));
      if (txt.length > 300) txt = txt.slice(0, 300);
      if (/(n(ä|ae)chste|vorherige|next|prev(ious)?)\s*(folge|episode)/i.test(txt)) continue;
      var u = a.href.split('#')[0];
      var n = epNumFrom(txt, u.split('?')[0]);
      if (!n) continue;
      var prev = byUrl[u];
      if (prev) { if (txt.length > prev.txt.length) { prev.a = a; prev.txt = txt; } continue; }
      var h = { a: a, s: n.s, num: n.e, url: u, txt: txt, score: 0 };
      byUrl[u] = h;
      hits.push(h);
    }
    if (hits.length < 2) return null;
    // Kleinster Container mit mehreren Folgen-Links = eine Folgenliste
    var touched = [];
    hits.forEach(function (h) {
      var n = h.a.parentElement, d = 0;
      while (n && n !== D.body && d++ < 12) { if (!n.__ovlEp) { n.__ovlEp = 0; touched.push(n); } n.__ovlEp++; n = n.parentElement; }
    });
    var groups = [];
    hits.forEach(function (h) {
      var n = h.a.parentElement, c = null, d = 0;
      while (n && n !== D.body && d++ < 12) { if (n.__ovlEp >= 2) { c = n; break; } n = n.parentElement; }
      if (!c) return;
      var g = null;
      for (var q = 0; q < groups.length; q++) if (groups[q].c === c) { g = groups[q]; break; }
      if (!g) { g = { c: c, list: [], seen: {} }; groups.push(g); }
      var k = h.s + ':' + h.num;
      if (!g.seen[k]) { g.seen[k] = 1; g.list.push(h); }
    });
    touched.forEach(function (n) { try { delete n.__ovlEp; } catch (e) { n.__ovlEp = 0; } });
    var best = null;
    groups.forEach(function (g) { if (g.list.length >= 2 && (!best || g.list.length > best.length)) best = g.list; });
    return best;
  }

  function episodesOf() {
    var list = urlEpisodes();
    if (!list || list.length < 3) {
      var alt = textEpisodes();
      if (alt && (!list || alt.length > list.length)) list = alt;
    }
    if (!list) return null;
    list.sort(function (x, y) { return (x.s - y.s) || (x.num - y.num); });
    var here = location.href.split('#')[0];
    var items = list.map(function (x) {
      var et = episodeTitle(x.a, x.num);
      var card = closestSel(x.a, 'li,article,[class*="card"],[class*="Card"],[class*="teaser"],[class*="Teaser"],[class*="tile"]');
      var root = (card && card.contains(et.row)) ? card : et.row;
      var big = null, imgs = root.querySelectorAll ? root.querySelectorAll('img') : [];
      for (var q = 0; q < imgs.length && !big; q++) { var rr = imgs[q].getBoundingClientRect(); if (rr.width >= 80 && rr.height >= 45) big = imgs[q]; }
      return { url: x.url, num: x.num, season: x.s || 0, title: et.title, image: big ? imageOf(big) : '', active: x.url === here };
    });
    var cur = -1;
    items.forEach(function (it, idx) { if (it.active) cur = idx; });
    if (cur < 0) {
      // Aktuelle Folge über den Seitentitel bestimmen („Folge 2: …“, „S01 E02“)
      var og = D.querySelector('meta[property="og:title"]');
      var me = epNumFrom(cleanText(D.title) + ' ' + cleanText(og ? og.getAttribute('content') : ''), here.split('?')[0]);
      if (me) items.forEach(function (it, idx) { if (cur < 0 && it.num === me.e && (!me.s || !it.season || it.season === me.s)) cur = idx; });
      if (cur >= 0) items[cur].active = true;
    }
    return { items: items.slice(0, 200), next: (cur >= 0 && cur + 1 < items.length) ? items[cur + 1].url : '' };
  }

  /* Versionen/Quellen: Umschalter am Player (Sprache, Untertitel, Qualität, Quelle) */
  var SOURCE_CONT = /source|quelle|server|mirror|hoster|stream-?(select|list|links|switch)|player-?(select|switch|tab|nav|source|option)|lang(uage)?-?(select|switch|list)|sprache|version|variant|audio-?track/i;
  function sourcesOf() {
    var conts = D.querySelectorAll('[class],[id]');
    var best = null;
    for (var i = 0; i < conts.length; i++) {
      var c = conts[i];
      if (!SOURCE_CONT.test(clsOf(c)) || closestSel(c, 'header,footer') || !visible(c)) continue;
      var cands = c.querySelectorAll('a,button,[role="tab"],[role="option"],li,[data-src],[data-link],[data-url],[data-lang]');
      var items = [];
      for (var j = 0; j < cands.length && items.length < 16; j++) {
        var el = cands[j];
        if (!visible(el) || items.some(function (x) { return x.contains(el); })) continue;
        var img = el.querySelector('img');
        var label = cleanText(el.textContent) || cleanText(el.getAttribute('title')) || cleanText(el.getAttribute('aria-label')) ||
          (img ? cleanText(img.getAttribute('alt') || img.getAttribute('title')) : '') || cleanText(el.getAttribute('data-lang'));
        if (!label || label.length > 40) continue;
        items.push(el);
      }
      if (items.length >= 2 && items.length <= 12 && (!best || items.length > best.length)) best = items;
    }
    if (!best) return [];
    O._sourceEls = best;
    return best.map(function (el, i) {
      var img = el.querySelector('img');
      var label = cleanText(el.textContent) || cleanText(el.getAttribute('title')) || cleanText(el.getAttribute('aria-label')) ||
        (img ? cleanText(img.getAttribute('alt') || img.getAttribute('title')) : '') || ('Version ' + (i + 1));
      return { label: label, active: isActive(el), index: i };
    });
  }
  O.pickSource = safe(function (i) {
    var el = (O._sourceEls || [])[i];
    if (!el) return false;
    var inner = el.tagName === 'LI' ? el.querySelector('a,button') : null;
    (inner || el).click();
    return true;
  });

  O.extract = safe(function () {
    var found = [], byUrl = {}, imgByUrl = {};
    function add(card, link, img, textOnly) {
      if (!link || !link.href || inChrome(card)) return;
      var url = link.href;
      if (!/^https?:/i.test(url) || url.split('#')[0] === location.href.split('#')[0]) return;
      var r = card.getBoundingClientRect();
      var w = r.width, h = r.height;
      if (img) { var ri = img.getBoundingClientRect(); w = Math.max(w, ri.width); h = Math.max(h, ri.height); }
      if (textOnly ? (w < 30 || h < 10) : (w < 70 || h < 40)) return;
      var image = textOnly ? '' : (img ? imageOf(img.tagName === 'IMG' ? img : card) : imageOf(card));
      // Bild und Titel stecken oft in getrennten Links zur selben Adresse (Bild-Link + Titel-/Overlay-Link)
      if (image && !imgByUrl[url]) imgByUrl[url] = image;
      var prev = byUrl[url];
      if (prev && !textOnly) { if (!prev.image && image) { prev.image = image; prev.noimg = false; } return; }
      var title = titleOf(card, link, img);
      if (!title || title.length < 2) return;
      if (prev && textOnly && prev.textOnly) return;
      if (!image && !textOnly && imgByUrl[url]) image = imgByUrl[url];
      var it = { el: card, url: url, title: title, image: image, sub: subOf(card, title), textOnly: !!textOnly };
      if (!prev) byUrl[url] = it;
      found.push(it);
      return it;
    }
    // 1) Links mit Bild – und kartengroße Links, deren Bild noch nicht nachgeladen wurde
    var links = D.querySelectorAll('a[href]');
    for (var i = 0; i < links.length && found.length < 400; i++) {
      var a = links[i];
      var im = a.querySelector('img,picture,[style*="background"],noscript');
      if (im) { add(a, a, a.querySelector('img')); continue; }
      var lr = a.getBoundingClientRect();
      if (lr.width >= 140 && lr.height >= 80 && lr.width <= W.innerWidth * 0.9) {
        var added = add(a, a, null);
        if (added) added.noimg = !added.image;
      }
    }
    // 2) Karten, bei denen Bild und Link Geschwister sind
    var cards = D.querySelectorAll('article,li,[class*="card"],[class*="Card"],[class*="teaser"],[class*="Teaser"],[class*="tile"],[class*="item"],[class*="episode"],[class*="Episode"]');
    for (var j = 0; j < cards.length && found.length < 400; j++) {
      var c = cards[j];
      if (!c.querySelector('img,[style*="background"]')) continue;
      var l = c.querySelector('a[href]');
      if (l && !byUrl[l.href]) add(c, l, c.querySelector('img'));
    }
    // 3) Folgen-Listen ohne Bilder („Folge 3“, „S1E4“ …)
    for (var k = 0; k < links.length && found.length < 400; k++) {
      var e = links[k];
      if (e.querySelector('img')) continue;
      var tx = cleanText(e.textContent);
      if (tx && tx.length < 80 && EP_RE.test(tx)) add(e, e, null, true);
    }

    // Gruppieren: kleinster gemeinsamer Container mit mehreren Karten = eine Reihe
    var touched = [];
    found.forEach(function (it) {
      var n = it.el.parentElement, depth = 0;
      while (n && n !== D.body && depth++ < 14) {
        if (!n.__ovlCnt) { n.__ovlCnt = 0; touched.push(n); }
        n.__ovlCnt++;
        n = n.parentElement;
      }
    });
    var groups = [];
    found.forEach(function (it) {
      var n = it.el.parentElement, c = null, depth = 0;
      while (n && n !== D.body && depth++ < 14) { if (n.__ovlCnt >= 3) { c = n; break; } n = n.parentElement; }
      if (!c) c = it.el.parentElement || D.body;
      var g = null;
      for (var q = 0; q < groups.length; q++) if (groups[q].c === c) { g = groups[q]; break; }
      if (!g) { g = { c: c, items: [] }; groups.push(g); }
      g.items.push(it);
    });
    touched.forEach(function (n) { try { delete n.__ovlCnt; } catch (e) { n.__ovlCnt = 0; } });

    var sections = [];
    groups.forEach(function (g) {
      // Kartengroße Links ohne Bild nur in Reihen, die auch echte Bildkarten haben
      var hasImg = g.items.some(function (it) { return !!it.image; });
      var list = hasImg ? g.items : g.items.filter(function (it) { return !it.noimg; });
      if (!list.length) return;
      var items = list.slice(0, 60).map(function (it) { return { url: it.url, title: it.title, image: it.image, sub: it.sub }; });
      sections.push({ title: headingFor(g.c, list[0].el), items: items });
    });
    // Einzelne Karten ohne Reihe sammeln
    var merged = [], loose = [];
    sections.forEach(function (sct) { if (sct.items.length >= 2 || sct.title) merged.push(sct); else loose = loose.concat(sct.items); });
    if (loose.length) merged.push({ title: '', items: loose.slice(0, 60) });

    function meta(sel) { var m = D.querySelector(sel); return m ? (m.getAttribute('content') || '') : ''; }
    var player = findPlayer();
    var holder = player ? null : findPlaceholder();
    var nextLink = findNext(false);
    var eps = episodesOf();
    var seasons = seasonsOf();
    var sources = (player || holder) ? sourcesOf() : [];
    // Folgen und Staffel-Links nicht doppelt in anderen Reihen zeigen
    if (eps || seasons.length) {
      var epUrls = {};
      if (eps) eps.items.forEach(function (e) { epUrls[e.url] = 1; });
      seasons.forEach(function (x) { if (x.url) epUrls[x.url.split('#')[0]] = 1; });
      merged = merged.map(function (sct) {
        // Bildkarten bleiben in ihrer Reihe; Textlinks (z. B. Folgenlisten, Staffel-Links) entfallen
        var items = sct.items.filter(function (it) { return it.image || !epUrls[it.url.split('#')[0]]; });
        // Reihe besteht komplett aus denselben Folgen → doppelt, weglassen
        var allEps = items.length > 0 && items.every(function (it) { return epUrls[it.url.split('#')[0]]; });
        return { title: sct.title, items: allEps && eps && eps.items.length >= items.length ? [] : items };
      }).filter(function (sct) { return sct.items.length > 0; });
    }
    var activeSeason = '';
    seasons.forEach(function (x) { if (x.active) activeSeason = x.title; });
    return {
      url: location.href,
      title: cleanTitle(cleanText(meta('meta[property="og:title"]')) || cleanText(D.title), cleanText(meta('meta[property="og:site_name"]'))),
      site: cleanText(meta('meta[property="og:site_name"]')),
      description: cleanText(meta('meta[property="og:description"]') || meta('meta[name="description"]')).slice(0, 300),
      image: absUrl(meta('meta[property="og:image"]')),
      player: player ? { tag: player.tagName, poster: absUrl(player.getAttribute('poster') || '') } :
        (holder ? { tag: 'VORSCHAU', poster: imageOf(holder.el) } : null),
      next: (eps && eps.next) || (nextLink && nextLink.href ? nextLink.href : ''),
      episodes: eps ? eps.items : [],
      seasons: seasons,
      activeSeason: activeSeason,
      sources: sources,
      sections: merged.slice(0, 24)
    };
  });

  /** Seitentitel ohne Anhängsel: „Folge 1 - hier anschauen“, „… | ARTE“, „- jetzt streamen!“ */
  var TITLE_JUNK = /streamen|anschauen|ansehen|online|kostenlos|mediathek|jetzt|^hier\b|\bwatch\b|\bstream\b|replay|in voller l(ä|ae)nge/i;
  function cleanTitle(t, site) {
    t = cleanText(t);
    var host = /^[\d.:]+$/.test(location.hostname) ? '' : baseDomain(location.hostname).split('.')[0].toLowerCase();
    if (host.length < 3) host = '';
    var sn = String(site || '').toLowerCase();
    for (var guard = 0; guard < 4; guard++) {
      var re = /\s+(\||–|—|-|·|:)\s+(?!.*\s(\||–|—|-|·)\s)/;   // letzter Trenner
      var m = re.exec(t);
      if (!m) break;
      var last = cleanText(t.slice(m.index + m[0].length).replace(/[!.]+$/, ''));
      var l = last.toLowerCase();
      var isSite = l.length >= 2 && ((host && (l.indexOf(host) >= 0 || (l.length >= 3 && host.indexOf(l.replace(/\s+/g, '')) >= 0))) ||
        (sn && (l === sn || sn.indexOf(l) >= 0 || l.indexOf(sn) >= 0)));
      if (isSite || TITLE_JUNK.test(last) || last.length <= 2) t = t.slice(0, m.index); else break;
    }
    return t;
  }

  /** Seite einmal durchscrollen, damit nachladende Bilder/Karten erscheinen. */
  /** Scrollt die Seite selbst oder (bei App-artigen Seiten) einen eigenen Scroll-Container? */
  function mainScroller() {
    var se = D.scrollingElement || D.documentElement;
    if (se.scrollHeight > W.innerHeight + 60) return null;
    var best = null, bestA = 0;
    var els = D.querySelectorAll('div,main,section,[role="main"]');
    for (var i = 0; i < els.length && i < 3000; i++) {
      var el = els[i];
      if (el.clientHeight < W.innerHeight * 0.5 || el.scrollHeight < el.clientHeight + 100) continue;
      var ov = W.getComputedStyle(el).overflowY;
      if (ov !== 'auto' && ov !== 'scroll') continue;
      var a = el.clientWidth * el.clientHeight;
      if (a > bestA) { bestA = a; best = el; }
    }
    return best;
  }
  /** Waagerechte Reihen (Karussells) im Bild ein Stück weiterschieben, damit ihre Bilder nachladen. */
  var sideMoved = [];
  function sideStep() {
    var els = D.querySelectorAll('ul,ol,div,section');
    var n = 0;
    for (var i = 0; i < els.length && i < 4000 && n < 12; i++) {
      var el = els[i];
      if (el.scrollWidth < el.clientWidth + 60 || el.clientWidth < 200) continue;
      var r = el.getBoundingClientRect();
      if (r.bottom < 0 || r.top > W.innerHeight) continue;
      var ov = W.getComputedStyle(el).overflowX;
      if (ov !== 'auto' && ov !== 'scroll') continue;
      if (el.__ovlSide === undefined) { el.__ovlSide = el.scrollLeft; sideMoved.push(el); }
      el.scrollLeft = Math.min(el.scrollLeft + el.clientWidth, el.scrollWidth);
      n++;
    }
  }
  O.prefetch = safe(function () {
    // Schrittweise nach unten, bis die Seite nicht mehr wächst (max. ~6 s), dann zurück nach oben
    var i = 0, still = 0, lastH = 0, h = W.innerHeight;
    var sc = mainScroller();
    var t = setInterval(function () {
      try {
        i++;
        var docH = sc ? sc.scrollHeight : Math.max(D.body ? D.body.scrollHeight : 0, D.documentElement.scrollHeight);
        var y = Math.min(i * h * 0.8, docH);
        if (sc) sc.scrollTop = y; else W.scrollTo(0, y);
        sideStep();
        if (docH === lastH && i * h * 0.8 >= docH) still++; else still = 0;
        lastH = docH;
        if (still >= 2 || i >= 22) {
          clearInterval(t);
          setTimeout(function () {
            if (sc) sc.scrollTop = 0;
            W.scrollTo(0, 0);
            sideMoved.forEach(function (el) { try { el.scrollLeft = el.__ovlSide || 0; delete el.__ovlSide; } catch (e) {} });
            sideMoved = [];
          }, 250);
        }
      } catch (e) { clearInterval(t); }
    }, 260);
    return true;
  });

  /** Kurzbefund der Seite für das Protokoll (adb logcat -s OverlordVV). */
  O.diag = safe(function () {
    var vids = deepAll('video').map(function (v) {
      var r = v.getBoundingClientRect(), anc = [], n = v.parentElement;
      for (var a = 0; a < 3 && n; a++) { anc.push((n.tagName.toLowerCase() + '.' + clsOf(n).trim().split(/\s+/)[0]).slice(0, 28)); n = n.parentElement; }
      return Math.round(r.width) + 'x' + Math.round(r.height) + (v.paused ? '' : ' läuft') + (isBackdrop(v) ? ' hintergrund' : '') +
        (v.muted ? ' stumm' : '') + (v.autoplay ? ' autoplay' : '') + (v.loop ? ' loop' : '') + (v.controls ? ' controls' : '') +
        (isFinite(v.duration) ? ' ' + Math.round(v.duration) + 's' : '') + (v.currentSrc ? '' : ' ohne-quelle') + ' in ' + anc.join(' < ');
    }).slice(0, 4);
    var fr = [], ifr = D.getElementsByTagName('iframe');
    for (var i = 0; i < ifr.length && fr.length < 6; i++) {
      var r = ifr[i].getBoundingClientRect();
      if (r.width < 60 || r.height < 60) continue;
      var host = '';
      try { host = new URL(ifr[i].src || ifr[i].getAttribute('data-src') || '', location.href).hostname; } catch (e) {}
      fr.push((host || 'leer') + ' ' + Math.round(r.width) + 'x' + Math.round(r.height));
    }
    var ph = findPlaceholder();
    var big = [];
    // Große Blöcke oben auf der Seite (Kandidaten für Player-Bereiche) mit Klassennamen
    var blocks = D.querySelectorAll('div,section,figure,[class]');
    for (var k = 0; k < blocks.length && big.length < 4 && k < 3000; k++) {
      var b = blocks[k], br = b.getBoundingClientRect();
      if (br.width < W.innerWidth * 0.6 || br.height < 150 || br.top > W.innerHeight || br.width / br.height < 1.3 || br.width / br.height > 2.4) continue;
      var c = clsOf(b).trim();
      if (c) big.push(b.tagName.toLowerCase() + '.' + c.slice(0, 50));
    }
    var se = D.scrollingElement || D.documentElement;
    return {
      hoehe: se.scrollHeight, fenster: W.innerHeight, links: D.links.length, bilder: D.images.length,
      shadow: liveShadows().length, videos: vids, iframes: fr,
      vorschau: ph ? (clsOf(ph.el).trim().slice(0, 40) + ' → ' + cleanLabel(ph.btn).slice(0, 30)) : '',
      bloecke: big, cookie: O.consentInfo || '', scroller: mainScroller() ? 'eigener' : 'fenster',
      text: D.body ? cleanText(D.body.innerText || '').slice(0, 200) : ''
    };
  });

  /** Kino-Modus: nur der Player, bildschirmfüllend (auch Player in iframes). */
  O.cinema = safe(function (on) {
    var marked = D.querySelectorAll('[data-ovl-cinema]');
    for (var i = 0; i < marked.length; i++) { applyMax(marked[i], false); marked[i].removeAttribute('data-ovl-cinema'); }
    if (!on) { O.cmd('unmaximize'); return 'off'; }
    var p = findPlayer();
    if (!p) {
      // Noch kein Player, aber ein Vorschaubild mit Play-Knopf → die App tippt ihn echt an
      var ph = findPlaceholder();
      if (!ph) return null;
      try { ph.el.scrollIntoView({ block: 'center' }); } catch (e) { ph.el.scrollIntoView(); }
      var br = ph.btn.getBoundingClientRect();
      return { tap: 1, x: br.left + br.width / 2, y: br.top + br.height / 2, iw: W.innerWidth };
    }
    try { p.scrollIntoView(); } catch (e) {}
    p.setAttribute('data-ovl-cinema', '1');
    applyMax(p, true);
    if (p.tagName === 'VIDEO') tryPlay(p);
    return p.tagName;
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
