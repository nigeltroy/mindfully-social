import Foundation

/// MSA-21 + MSA-32: hide Instagram “Use the app” / open-in-app / get-the-app
/// interstitial banners and sections inside WKWebView. Additive with MSA-16/18/19.
/// MSA-32 strengthened promo matching; MSA-36 drops characterData + full-doc
/// TreeWalker during scroll (chaos BUG-3) and scopes scans to chrome bands.
/// MSA-32 note: MutationObserver (characterData), TreeWalker text hits,
/// CSS :has() rules, and bottom-bar / full interstitial root climbing.
enum InstagramAppPromoHide {
    /// Injected at document-start alongside other Instagram site tweaks.
    static let userScriptSource: String = #"""
(function () {
  if (window.__msaAppPromoInstalled) return;
  window.__msaAppPromoInstalled = true;

  var STYLE_ID = 'msa-hide-app-promo-style';
  var MARK = 'data-msa-app-promo';
  var REASON = 'data-msa-app-promo-reason';

  // Exact / prefix phrases for install / open-in-app chrome (normalized).
  var EXACT = {
    'use the app': 'use-the-app',
    'open in app': 'open-in-app',
    'open in the app': 'open-in-app',
    'get the app': 'get-the-app',
    'get app': 'get-the-app',
    'install app': 'install',
    'install the app': 'install',
    'download app': 'download',
    'download the app': 'download',
    'open instagram': 'open-instagram',
    'open the instagram app': 'open-instagram',
    'see this post in the app': 'see-in-app',
    'see more in the app': 'see-in-app',
    'continue in app': 'continue-in-app',
    'continue in the app': 'continue-in-app'
  };

  var CONTAINS = [
    // No leading \\b: IG concatenates "close"+"use the app" → "closeuse the app".
    { re: /use the app/, reason: 'use-the-app' },
    { re: /open in app/, reason: 'open-in-app' },
    { re: /open in the app/, reason: 'open-in-app' },
    { re: /get the app/, reason: 'get-the-app' },
    { re: /install (the )?app/, reason: 'install' },
    { re: /download (the )?app/, reason: 'download' },
    { re: /continue in (the )?app/, reason: 'continue-in-app' },
    { re: /open (the )?instagram( app)?/, reason: 'open-instagram' },
    { re: /see (this|more).{0,24}in (the )?app/, reason: 'see-in-app' },
    { re: /app store/, reason: 'app-store' }
  ];

  function normText(s) {
    return String(s || '')
      .replace(/[\u200b-\u200d\ufeff]/g, '')
      .replace(/[\u00a0\u202f\u2000-\u200a\u205f\u3000]/g, ' ')
      .replace(/\s+/g, ' ')
      .trim()
      .toLowerCase();
  }

  function pushHitRow(out, el) {
    if (!el || el === document.body || el === document.documentElement) return;
    if (out.length >= 14) return;
    var r = el.getBoundingClientRect();
    var st = window.getComputedStyle(el);
    var txt = '';
    try {
      txt = normText(el.textContent || '').slice(0, 80);
    } catch (e0) {}
    var pseudo = '';
    try {
      var before = window.getComputedStyle(el, '::before').content;
      var after = window.getComputedStyle(el, '::after').content;
      pseudo = normText(
        (before && before !== 'none' ? before : '') +
          ' ' +
          (after && after !== 'none' ? after : '')
      ).slice(0, 40);
    } catch (e1) {}
    out.push({
      tag: el.tagName,
      id: el.id || '',
      cls: String(el.className || '').slice(0, 80),
      role: el.getAttribute('role') || '',
      aria: (el.getAttribute('aria-label') || '').slice(0, 48),
      href: (el.getAttribute('href') || '').slice(0, 64),
      pos: st.position,
      top: Math.round(r.top),
      bot: Math.round(r.bottom),
      h: Math.round(r.height),
      w: Math.round(r.width),
      txt: txt,
      pseudo: pseudo,
      marked: el.getAttribute(MARK) || '',
      inNav: isInBottomNav(el),
      hasNavLinks: containsBottomNavLinks(el)
    });
  }

  /** Infer bottom-nav top from Home/Explore links (banner sits just above). */
  function bottomNavTop() {
    var vh = window.innerHeight || 800;
    var best = vh - 84;
    try {
      var links = document.querySelectorAll(
        'a[href="/"], a[href="/explore/"], a[href="/reels/"]'
      );
      for (var i = 0; i < links.length; i++) {
        var r = links[i].getBoundingClientRect();
        if (r.height < 8 || r.height > 80) continue;
        if (r.top < vh * 0.55) continue;
        if (r.top < best) best = r.top;
      }
    } catch (e) {}
    return best;
  }

  /** Hit-test probe for dumps — probe ABOVE bottom nav (chaos 2325 strip). */
  function hitTestBottom() {
    var out = [];
    try {
      var vh = window.innerHeight || 800;
      var vw = window.innerWidth || 400;
      var navTop = bottomNavTop();
      if (document.elementsFromPoint) {
        var ys = [navTop - 18, navTop - 28, navTop - 40, navTop - 8, vh - 120];
        for (var yi = 0; yi < ys.length; yi++) {
          var y = ys[yi];
          if (y < 0 || y > vh) continue;
          var stack = document.elementsFromPoint(vw * 0.5, y) || [];
          for (var i = 0; i < stack.length && i < 6; i++) pushHitRow(out, stack[i]);
          if (out.length >= 12) break;
        }
      }
      // Document-wide short "use the app" text hunt (debug).
      var found = [];
      try {
        var walker = document.createTreeWalker(
          document.body || document.documentElement,
          NodeFilter.SHOW_TEXT,
          null
        );
        var node;
        while ((node = walker.nextNode()) && found.length < 8) {
          var t = normText(node.nodeValue || '');
          if (!t) continue;
          if (t.indexOf('use the app') === -1 && t.indexOf('open in app') === -1) continue;
          var p = node.parentElement;
          var pr = p ? p.getBoundingClientRect() : { top: 0, bottom: 0, height: 0, width: 0 };
          found.push({
            t: t.slice(0, 48),
            tag: p ? p.tagName : '',
            top: Math.round(pr.top),
            bot: Math.round(pr.bottom),
            h: Math.round(pr.height),
            w: Math.round(pr.width)
          });
        }
      } catch (e2) {}
      // Debug: chrome roots + their children in the banner slot.
      var chromeInfo = [];
      try {
        var roots = findBottomChromeRoots();
        for (var ri = 0; ri < roots.length && ri < 3; ri++) {
          var root = roots[ri];
          var rr = root.getBoundingClientRect();
          var childInfo = [];
          var kids = root.children || [];
          for (var ki = 0; ki < kids.length && ki < 8; ki++) {
            var ch = kids[ki];
            var cr = ch.getBoundingClientRect();
            childInfo.push({
              tag: ch.tagName,
              cls: String(ch.className || '').slice(0, 48),
              top: Math.round(cr.top),
              bot: Math.round(cr.bottom),
              h: Math.round(cr.height),
              w: Math.round(cr.width),
              hasNav: containsBottomNavLinks(ch),
              txt: normText(ch.textContent || '').slice(0, 36)
            });
          }
          chromeInfo.push({
            tag: root.tagName,
            cls: String(root.className || '').slice(0, 48),
            top: Math.round(rr.top),
            bot: Math.round(rr.bottom),
            h: Math.round(rr.height),
            childCount: kids.length,
            children: childInfo
          });
        }
      } catch (e3) {}
      // Every fixed/sticky/absolute node intersecting the banner band.
      var fixedBand = [];
      try {
        var all = document.querySelectorAll('div, section, aside, footer, nav, a, span, button');
        for (var fi = 0; fi < all.length && fixedBand.length < 20; fi++) {
          var fe = all[fi];
          var fst = window.getComputedStyle(fe);
          var fr = fe.getBoundingClientRect();
          if (fr.width < 8 || fr.height < 8) continue;
          // Intersect banner band [navTop-40, navTop+50]
          if (fr.bottom < navTop - 40 || fr.top > navTop + 50) continue;
          var pos = fst.position;
          if (pos !== 'fixed' && pos !== 'sticky' && pos !== 'absolute') {
            // Still include short full-width in-flow bars in the band.
            if (!(fr.width > vw * 0.5 && fr.height < 90)) continue;
          }
          fixedBand.push({
            tag: fe.tagName,
            cls: String(fe.className || '').slice(0, 48),
            pos: pos,
            top: Math.round(fr.top),
            bot: Math.round(fr.bottom),
            h: Math.round(fr.height),
            w: Math.round(fr.width),
            z: fst.zIndex || '',
            hasNav: containsBottomNavLinks(fe),
            txt: normText(fe.textContent || '').slice(0, 40),
            aria: (fe.getAttribute('aria-label') || '').slice(0, 40),
            bg: (fst.backgroundImage || '').slice(0, 60)
          });
        }
      } catch (e4) {}
      out.push({
        iframeCount: document.querySelectorAll('iframe').length,
        vh: vh,
        vw: vw,
        navTop: Math.round(navTop),
        textHits: found,
        chromeRoots: chromeInfo,
        fixedBand: fixedBand
      });
    } catch (e) {
      out.push({ error: String(e) });
    }
    return out;
  }

  /** Fixed bottom chrome that owns Home/Explore (banner is often its sibling child). */
  function findBottomChromeRoots() {
    var roots = [];
    var vh = window.innerHeight || 800;
    var seen = typeof WeakSet !== 'undefined' ? new WeakSet() : null;
    try {
      var links = document.querySelectorAll(
        'a[href="/"], a[href="/explore/"], a[href="/reels/"]'
      );
      for (var i = 0; i < links.length; i++) {
        var n = links[i];
        var r = n.getBoundingClientRect();
        if (r.top < vh * 0.55) continue;
        // Climb to the OUTERMOST fixed/sticky chrome near the bottom (not the
        // inner icon row). Chaos 2325 install strip is a sibling above the icons
        // inside the taller fixed wrapper (h≈84, top≈728 on FEA).
        var cur = n;
        var best = null;
        for (var d = 0; d < 14 && cur && cur !== document.body; d++) {
          try {
            var st = window.getComputedStyle(cur);
            var cr = cur.getBoundingClientRect();
            var fixedish =
              st.position === 'fixed' || st.position === 'sticky' || st.position === 'absolute';
            if (
              cr.bottom > vh - 30 &&
              cr.height > 48 &&
              cr.height < vh * 0.45 &&
              cr.width > window.innerWidth * 0.6
            ) {
              if (fixedish || containsBottomNavLinks(cur)) {
                best = cur; // keep climbing; outermost wins
              }
            }
          } catch (e0) {}
          cur = cur.parentElement;
        }
        if (best) {
          if (seen) {
            if (seen.has(best)) continue;
            seen.add(best);
          }
          roots.push(best);
        }
      }
    } catch (e) {}
    return roots;
  }

  /** Geometry-only: install row is a child of fixed bottom chrome (chaos 2325).
   *  Banner text often NOT in DOM text nodes. Pixel proof: y≈713–767, navTop≈728. */
  function hideGeometricInstallStrip() {
    var hidden = 0;
    try {
      var vh = window.innerHeight || 800;
      var vw = window.innerWidth || 400;
      var navTop = bottomNavTop();
      var roots = findBottomChromeRoots();
      for (var ri = 0; ri < roots.length; ri++) {
        var root = roots[ri];
        var kids = root.children || [];
        for (var ki = 0; ki < kids.length; ki++) {
          var el = kids[ki];
          if (!el || el.nodeType !== 1) continue;
          if (el.getAttribute(MARK) === '1') continue;
          // Skip the child that actually owns the tab links.
          if (containsBottomNavLinks(el)) continue;
          var r;
          var st;
          try {
            r = el.getBoundingClientRect();
            st = window.getComputedStyle(el);
          } catch (e0) {
            continue;
          }
          if (r.width < vw * 0.45) continue;
          if (r.height < 18 || r.height > 90) continue;
          // Must sit in/above the icon row band.
          if (r.top < navTop - 80) continue;
          if (r.top > navTop + 40) continue;
          if (st.display === 'none' || st.visibility === 'hidden' || Number(st.opacity) === 0) {
            continue;
          }
          if (collapse(el, 'geo-chrome-child')) hidden++;
        }
        // Also: direct descendants one level deeper (wrapper > row > strip).
        try {
          var nested = root.querySelectorAll(':scope > * > *');
          for (var ni = 0; ni < nested.length; ni++) {
            var ne = nested[ni];
            if (ne.getAttribute(MARK) === '1') continue;
            if (containsBottomNavLinks(ne)) continue;
            var nr = ne.getBoundingClientRect();
            if (nr.width < vw * 0.45) continue;
            if (nr.height < 18 || nr.height > 72) continue;
            if (nr.top < navTop - 80 || nr.top > navTop + 40) continue;
            // Prefer rows above the icons (top < navTop + 8).
            if (nr.top > navTop + 8 && nr.height < 40) continue;
            if (collapse(ne, 'geo-chrome-nested')) hidden++;
          }
        } catch (e1) {}
      }

      // Hit-test overlap band; climb to a short ancestor that is not the tab row.
      if (document.elementsFromPoint) {
        var ys2 = [navTop - 20, navTop - 8, navTop + 4, navTop + 16];
        for (var yi = 0; yi < ys2.length; yi++) {
          var stack = document.elementsFromPoint(vw * 0.5, ys2[yi]) || [];
          for (var si = 0; si < stack.length && si < 14; si++) {
            var hit = stack[si];
            if (!hit || hit === document.body || hit === document.documentElement) continue;
            var climb = hit;
            for (var c = 0; c < 6 && climb; c++) {
              if (climb.getAttribute && climb.getAttribute(MARK) === '1') break;
              if (containsBottomNavLinks(climb)) {
                climb = climb.parentElement;
                continue;
              }
              var hr;
              try {
                hr = climb.getBoundingClientRect();
              } catch (e2) {
                break;
              }
              if (hr.width >= vw * 0.45 && hr.height >= 18 && hr.height <= 90) {
                if (hr.top >= navTop - 80 && hr.top <= navTop + 40) {
                  var lab = readableLabel(climb);
                  var cls = String(climb.className || '');
                  if (
                    /use the app/.test(lab) ||
                    cls.indexOf('_acc8') !== -1 ||
                    cls.indexOf('_abpk') !== -1
                  ) {
                    if (collapse(climb, 'geo-hit-chrome')) hidden++;
                    break;
                  }
                }
              }
              climb = climb.parentElement;
            }
          }
        }
      }
    } catch (e) {}
    return hidden;
  }

  /** Last resort: any short text node saying “use the app” (any position). */
  function hideUseTheAppTextNodes() {
    var hidden = 0;
    try {
      if (!document.createTreeWalker) return 0;
      var walker = document.createTreeWalker(
        document.body || document.documentElement,
        NodeFilter.SHOW_TEXT,
        null
      );
      var node;
      var seen = typeof WeakSet !== 'undefined' ? new WeakSet() : null;
      while ((node = walker.nextNode())) {
        var t = normText(node.nodeValue || '');
        if (!t || t.length > 48) continue;
        if (t.indexOf('use the app') === -1 && !EXACT[t]) continue;
        var el = node.parentElement;
        if (!el || el.getAttribute(MARK) === '1') continue;
        if (isInBottomNav(el) || containsBottomNavLinks(el)) continue;
        if (seen) {
          if (seen.has(el)) continue;
          seen.add(el);
        }
        var root = findBannerRoot(el);
        if (collapse(root, 'use-the-app-text') || collapse(el, 'use-the-app-text')) {
          hidden++;
        }
      }
    } catch (e) {}
    return hidden;
  }

  function ensureStyle() {
    var style = document.getElementById(STYLE_ID);
    if (!style) {
      style = document.createElement('style');
      style.id = STYLE_ID;
      (document.head || document.documentElement).appendChild(style);
    }
    var parts = [
      '[' + MARK + '="1"] {',
      '  display: none !important;',
      '  visibility: hidden !important;',
      '  height: 0 !important;',
      '  max-height: 0 !important;',
      '  min-height: 0 !important;',
      '  margin: 0 !important;',
      '  padding: 0 !important;',
      '  overflow: hidden !important;',
      '  opacity: 0 !important;',
      '  pointer-events: none !important;',
      '  border: 0 !important;',
      '  transform: none !important;',
      '}',
      // Chaos 2325: sticky install strip often remounts above bottom nav.
      '[' + MARK + '="1"] * {',
      '  display: none !important;',
      '}'
    ];
    // CSS-force known install row only while hide is enabled (before-shots need it off).
    if (!(window.__msaAppPromo && window.__msaAppPromo.enabled === false)) {
      parts.push(
        'div._acc8._abpk, div._abpk._acc8 {',
        '  display: none !important;',
        '  visibility: hidden !important;',
        '  height: 0 !important;',
        '  max-height: 0 !important;',
        '  opacity: 0 !important;',
        '  pointer-events: none !important;',
        '}'
      );
    }
    style.textContent = parts.join('\n');
  }

  function readableLabel(el) {
    if (!el || el.nodeType !== 1) return '';
    var parts = [];
    try {
      parts.push(el.getAttribute('aria-label') || '');
      parts.push(el.getAttribute('title') || '');
      parts.push(el.textContent || '');
      var before = window.getComputedStyle(el, '::before').getPropertyValue('content');
      var after = window.getComputedStyle(el, '::after').getPropertyValue('content');
      if (before && before !== 'none') parts.push(before.replace(/^["']|["']$/g, ''));
      if (after && after !== 'none') parts.push(after.replace(/^["']|["']$/g, ''));
    } catch (e) {}
    return normText(parts.join(' '));
  }

  function labelLooksPromo(label) {
    if (!label) return null;
    var reason = matchPromoText(label);
    if (reason) return reason;
    if (/use the app/.test(label)) return 'use-the-app';
    if (/open in (the )?app/.test(label)) return 'open-in-app';
    return null;
  }

  /** Chaos 2325: IG sticky install row uses fixed div._acc8._abpk above bottom nav. */
  function hideKnownInstallClasses() {
    var hidden = 0;
    try {
      var nodes = document.querySelectorAll('div._acc8._abpk, div._acc8, div._abpk');
      for (var i = 0; i < nodes.length; i++) {
        var el = nodes[i];
        if (el.getAttribute(MARK) === '1') continue;
        if (containsBottomNavLinks(el)) continue;
        var label = readableLabel(el);
        if (!/use the app/.test(label) && !/close/.test(label)) continue;
        if (collapse(el, 'known-acc8-abpk')) hidden++;
      }
      // Any fixed short full-width bar whose label contains use-the-app.
      var vh = window.innerHeight || 800;
      var vw = window.innerWidth || 400;
      var all = document.querySelectorAll('div, section, aside');
      for (var j = 0; j < all.length; j++) {
        var bar = all[j];
        if (bar.getAttribute(MARK) === '1') continue;
        if (containsBottomNavLinks(bar)) continue;
        var st = window.getComputedStyle(bar);
        if (st.position !== 'fixed' && st.position !== 'sticky') continue;
        var r = bar.getBoundingClientRect();
        if (r.width < vw * 0.7) continue;
        if (r.height < 20 || r.height > 72) continue;
        if (r.top < vh * 0.7) continue;
        var lab = readableLabel(bar);
        if (!/use the app/.test(lab)) continue;
        if (collapse(bar, 'fixed-use-the-app')) hidden++;
      }
    } catch (e) {}
    return hidden;
  }

  /** Hit-test the sticky strip (chaos 2325) — catches shadow / pseudo / odd trees. */
  function hideBottomInstallStrip() {
    try {
      var vh = window.innerHeight || 800;
      var vw = window.innerWidth || 400;
      var hidden = 0;
      var navTop = bottomNavTop();
      var ys = [navTop - 16, navTop - 28, navTop - 40, navTop - 52, vh - 120];
      var xs = [vw * 0.5, vw * 0.35, vw * 0.65, vw * 0.2, vw * 0.8];
      var seen = typeof WeakSet !== 'undefined' ? new WeakSet() : null;

      function consider(el, reason) {
        if (!el || el.nodeType !== 1) return;
        if (seen) {
          if (seen.has(el)) return;
          seen.add(el);
        }
        if (isInBottomNav(el) || containsBottomNavLinks(el)) return;
        var root = findBannerRoot(el);
        if (collapse(root, reason) || collapse(el, reason)) hidden++;
      }

      if (document.elementsFromPoint) {
        for (var yi = 0; yi < ys.length; yi++) {
          var y = ys[yi];
          if (y < 0 || y > vh) continue;
          for (var xi = 0; xi < xs.length; xi++) {
            var stack;
            try {
              stack = document.elementsFromPoint(xs[xi], y) || [];
            } catch (e0) {
              continue;
            }
            for (var si = 0; si < stack.length && si < 12; si++) {
              var el = stack[si];
              if (!el || el === document.body || el === document.documentElement) continue;
              var r;
              try {
                r = el.getBoundingClientRect();
              } catch (e1) {
                continue;
              }
              if (r.height > 130 || r.height < 8) continue;
              if (r.bottom < navTop - 80) continue;
              if (r.top > navTop + 8) continue;
              var reason = labelLooksPromo(readableLabel(el));
              // Hit-test geometry fallback: short bar above nav with close affordance.
              if (!reason) {
                var lab = readableLabel(el);
                if (lab && lab.length <= 28 && /\bapp\b/.test(lab)) {
                  reason = 'hit-app-label';
                }
              }
              if (!reason) continue;
              consider(el, reason);
            }
          }
        }
      }

      // DOM fallback in the bottom band (incl. open shadow roots one level).
      var bandTop = vh - 170;
      var bandBot = vh - 36;
      var nodes = document.querySelectorAll(
        'a, button, [role="button"], span, div, p, strong'
      );
      for (var i = 0; i < nodes.length; i++) {
        var node = nodes[i];
        if (node.getAttribute(MARK) === '1') continue;
        if (isInBottomNav(node) || containsBottomNavLinks(node)) continue;
        var nr;
        try {
          nr = node.getBoundingClientRect();
        } catch (e2) {
          continue;
        }
        if (nr.width < 24 || nr.height < 10 || nr.height > 120) continue;
        if (nr.bottom < bandTop || nr.top > bandBot) continue;
        var reason2 = labelLooksPromo(readableLabel(node));
        if (!reason2) continue;
        consider(node, reason2);
        try {
          if (node.shadowRoot) {
            var shadowNodes = node.shadowRoot.querySelectorAll(
              'a, button, [role="button"], span, div'
            );
            for (var s = 0; s < shadowNodes.length; s++) {
              var sn = shadowNodes[s];
              var sr2 = labelLooksPromo(readableLabel(sn));
              if (sr2) consider(sn, sr2);
            }
          }
        } catch (e3) {}
      }

      // Last resort: any fixed/sticky short bar in the band whose label matches.
      var bars = document.querySelectorAll('div, section, aside, footer');
      for (var b = 0; b < bars.length; b++) {
        var bar = bars[b];
        if (bar.getAttribute(MARK) === '1') continue;
        if (isInBottomNav(bar) || containsBottomNavLinks(bar)) continue;
        var br;
        var st;
        try {
          br = bar.getBoundingClientRect();
          st = window.getComputedStyle(bar);
        } catch (e4) {
          continue;
        }
        if (br.height < 24 || br.height > 120) continue;
        if (br.width < vw * 0.45) continue;
        if (br.bottom < bandTop || br.top > bandBot) continue;
        var fixedish =
          st.position === 'fixed' || st.position === 'sticky' || st.position === 'absolute';
        if (!fixedish && br.top < vh * 0.6) continue;
        var reason3 = labelLooksPromo(readableLabel(bar));
        if (!reason3) continue;
        if (collapse(bar, reason3 + '-strip')) hidden++;
      }
      return hidden;
    } catch (e) {
      return 0;
    }
  }

  function containsBottomNavLinks(el) {
    try {
      return !!(
        el &&
        el.querySelector &&
        el.querySelector(
          'a[href="/"], a[href="/explore/"], a[href="/reels/"], a[href*="/direct"], a[href*="/accounts/"]'
        )
      );
    } catch (e) {
      return false;
    }
  }

  function isInBottomNav(el) {
    var n = el;
    while (n && n !== document.body) {
      if (n.getAttribute && n.getAttribute('data-msa-bottom-nav') === '1') return true;
      n = n.parentElement;
    }
    try {
      var r = el.getBoundingClientRect();
      // Bottom tab strip: short chrome hugging the bottom edge.
      if (r.height > 0 && r.height < 88 && r.top > window.innerHeight - 100) {
        if (containsBottomNavLinks(el)) return true;
      }
    } catch (e) {}
    return false;
  }

  function matchPromoText(raw) {
    var t = normText(raw);
    if (!t || t.length > 96) return null;
    if (EXACT[t]) return EXACT[t];
    // Short chrome only — avoid caption false positives.
    if (t.length > 64) return null;
    for (var i = 0; i < CONTAINS.length; i++) {
      if (CONTAINS[i].re.test(t)) return CONTAINS[i].reason;
    }
    return null;
  }

  function looksLikeAppStoreHref(href) {
    if (!href) return false;
    var h = String(href).toLowerCase();
    return (
      h.indexOf('apps.apple.com') !== -1 ||
      h.indexOf('itunes.apple.com') !== -1 ||
      h.indexOf('play.google.com/store') !== -1 ||
      h.indexOf('app.adjust.com') !== -1 ||
      h.indexOf('instagram://') === 0 ||
      h.indexOf('intent://') === 0
    );
  }

  function collapse(el, reason) {
    if (!el || el === document.body || el === document.documentElement) return false;
    if (el.getAttribute(MARK) === '1') return false;
    if (isInBottomNav(el)) return false;
    // Never hide a wrapper that also owns the tab strip (chaos 2325 miss).
    if (containsBottomNavLinks(el)) return false;
    el.setAttribute(MARK, '1');
    el.setAttribute(REASON, reason || 'promo');
    try {
      el.style.setProperty('display', 'none', 'important');
      el.style.setProperty('visibility', 'hidden', 'important');
      el.style.setProperty('pointer-events', 'none', 'important');
      el.style.setProperty('height', '0', 'important');
      el.style.setProperty('max-height', '0', 'important');
      el.style.setProperty('opacity', '0', 'important');
      el.style.setProperty('overflow', 'hidden', 'important');
    } catch (e) {}
    if (window.__msaAppPromo) {
      window.__msaAppPromo.stats.hidden += 1;
      window.__msaAppPromo.stats.lastReasons.push(reason || 'promo');
      if (window.__msaAppPromo.stats.lastReasons.length > 40) {
        window.__msaAppPromo.stats.lastReasons.shift();
      }
    }
    return true;
  }

  function findBannerRoot(el) {
    var best = el;
    var n = el;
    for (var d = 0; d < 14 && n && n !== document.body; d++) {
      try {
        // Stop climbing once an ancestor also owns Home/Explore tabs.
        if (n !== el && containsBottomNavLinks(n)) break;
        var r = n.getBoundingClientRect();
        var st = window.getComputedStyle(n);
        var fixedish =
          st.position === 'fixed' ||
          st.position === 'sticky' ||
          st.position === 'absolute';
        var shortBar = r.height > 20 && r.height < 140 && r.width > window.innerWidth * 0.4;
        var nearBottom = r.bottom > window.innerHeight - 180;
        var nearTop = r.top < 140 && r.height < 140;
        var overlay =
          fixedish &&
          r.width > window.innerWidth * 0.55 &&
          r.height > 60 &&
          r.height < window.innerHeight * 0.98;
        // Classic “Use the app” strip above bottom nav.
        var bottomPromoStrip =
          nearBottom &&
          r.height > 28 &&
          r.height < 120 &&
          r.width > window.innerWidth * 0.55 &&
          r.top > window.innerHeight * 0.55;
        if (
          ((shortBar && (nearBottom || nearTop || fixedish)) || overlay || bottomPromoStrip) &&
          !isInBottomNav(n) &&
          !containsBottomNavLinks(n)
        ) {
          best = n;
        }
        var role = (n.getAttribute && n.getAttribute('role')) || '';
        var tag = (n.tagName || '').toLowerCase();
        if (role === 'dialog' || role === 'alertdialog' || tag === 'dialog') {
          if (!isInBottomNav(n) && !containsBottomNavLinks(n)) return n;
        }
        if (tag === 'section' && r.height > 80 && r.height < window.innerHeight * 0.85) {
          if (!isInBottomNav(n) && !containsBottomNavLinks(n) && (nearBottom || nearTop || fixedish)) {
            best = n;
          }
        }
      } catch (e) {}
      n = n.parentElement;
    }
    return best;
  }

  function scanTextTriggers(root) {
    var out = [];
    var nodes = root.querySelectorAll(
      'a, button, [role="button"], span, div, p, h1, h2, h3, h4, label, li, strong, em'
    );
    for (var i = 0; i < nodes.length; i++) {
      var el = nodes[i];
      if (el.getAttribute(MARK) === '1') continue;
      if (isInBottomNav(el)) continue;
      var own = '';
      try {
        // Prefer own text for short chrome labels (avoid swallowing feed captions).
        own = '';
        for (var c = 0; c < el.childNodes.length; c++) {
          var ch = el.childNodes[c];
          if (ch.nodeType === 3) own += ch.nodeValue || '';
        }
        if (!own) {
          own = el.getAttribute('aria-label') || '';
        }
        if (!own && el.childElementCount === 0) {
          own = el.textContent || '';
        }
        // Nested CTA: element whose visible label is exactly the promo phrase.
        if (!own && el.childElementCount > 0 && el.childElementCount < 4) {
          var joined = normText(el.textContent);
          if (joined.length <= 24 && EXACT[joined]) own = joined;
        }
      } catch (e) {
        own = el.textContent || '';
      }
      var reason = matchPromoText(own);
      if (!reason) {
        var aria = matchPromoText(el.getAttribute('aria-label') || '');
        if (aria) reason = aria;
      }
      if (!reason) continue;
      // Guard: if element text is long, it's likely a feed caption — unless exact use-the-app.
      var full = normText(el.textContent);
      if (full.length > 80 && reason !== 'use-the-app' && reason !== 'open-in-app') continue;
      out.push({ el: el, reason: reason });
    }
    return out;
  }

  /** Text nodes in top/bottom chrome only — full-doc walk jetsams on feed scroll. */
  function scanTextNodesChrome() {
    var out = [];
    if (!document.createTreeWalker) return out;
    try {
      var vh = window.innerHeight || 800;
      var bandTop = 130;
      var bandBottom = vh - 220;
      var walker = document.createTreeWalker(
        document.body || document.documentElement,
        NodeFilter.SHOW_TEXT,
        null
      );
      var node;
      var guard = 0;
      while ((node = walker.nextNode()) && guard < 2500) {
        guard++;
        var reason = matchPromoText(node.nodeValue || '');
        if (!reason) continue;
        var parent = node.parentElement;
        if (!parent || parent.getAttribute(MARK) === '1') continue;
        if (isInBottomNav(parent)) continue;
        try {
          var r = parent.getBoundingClientRect();
          if (r.height < 4 || r.width < 4) continue;
          var inChrome = r.top < bandTop || r.bottom > bandBottom;
          if (!inChrome) continue;
        } catch (e0) {
          continue;
        }
        out.push({ el: parent, reason: reason });
      }
    } catch (e) {}
    return out;
  }

  function scanAppStoreLinks(root) {
    var out = [];
    var links = root.querySelectorAll('a[href]');
    for (var i = 0; i < links.length; i++) {
      var a = links[i];
      if (a.getAttribute(MARK) === '1') continue;
      if (isInBottomNav(a)) continue;
      var href = a.getAttribute('href') || '';
      if (!looksLikeAppStoreHref(href)) continue;
      var t = normText(a.textContent);
      // Skip tiny icon-only share links buried in feed if they don't look like promo chrome.
      var r = a.getBoundingClientRect();
      var nearChrome =
        r.top < 100 ||
        r.bottom > window.innerHeight - 180 ||
        (r.width > window.innerWidth * 0.4 && r.height > 28);
      if (!nearChrome && t.length > 40) continue;
      out.push({ el: a, reason: 'app-store-link' });
    }
    return out;
  }

  function reinforceHidden() {
    var marked = document.querySelectorAll('[' + MARK + '="1"]');
    for (var i = 0; i < marked.length; i++) {
      try {
        marked[i].style.setProperty('display', 'none', 'important');
        marked[i].style.setProperty('visibility', 'hidden', 'important');
        marked[i].style.setProperty('pointer-events', 'none', 'important');
        marked[i].style.setProperty('height', '0', 'important');
        marked[i].style.setProperty('max-height', '0', 'important');
        marked[i].style.setProperty('opacity', '0', 'important');
      } catch (e) {}
    }
  }

  function applyPromoHide() {
    try {
      if (window.__msaAppPromo && window.__msaAppPromo.enabled === false) {
        reinforceHidden();
        return;
      }
      ensureStyle();
      reinforceHidden();
      // Always kill the sticky bottom install strip first (chaos 2325 BUG-2).
      var hiddenNow =
        (hideKnownInstallClasses() || 0) +
        (hideBottomInstallStrip() || 0) +
        (hideGeometricInstallStrip() || 0) +
        (hideUseTheAppTextNodes() || 0);

      // Full document scans wait until scroll is quiet (MSA-36 jetsam).
      if (window.__msaScrollBurst) {
        if (window.__msaAppPromo) {
          window.__msaAppPromo.stats.scans += 1;
          window.__msaAppPromo.stats.lastHiddenBatch = hiddenNow;
          window.__msaAppPromo.stats.visiblePromoText = livePromoLabels();
        }
        return;
      }

      var hits = scanTextTriggers(document).concat(scanTextNodesChrome());
      var seen = typeof WeakSet !== 'undefined' ? new WeakSet() : null;
      for (var i = 0; i < hits.length; i++) {
        var root = findBannerRoot(hits[i].el);
        if (seen) {
          if (seen.has(root)) continue;
          seen.add(root);
        }
        if (collapse(root, hits[i].reason)) hiddenNow++;
      }

      var storeHits = scanAppStoreLinks(document);
      for (var j = 0; j < storeHits.length; j++) {
        var storeRoot = findBannerRoot(storeHits[j].el);
        try {
          var sr = storeRoot.getBoundingClientRect();
          if (sr.height > window.innerHeight * 0.55 && sr.height < window.innerHeight * 0.98) {
            // Full-ish interstitial — OK to hide.
          } else if (sr.height >= 140 && !(sr.top < 120 || sr.bottom > window.innerHeight - 160)) {
            continue;
          }
        } catch (e2) {}
        if (collapse(storeRoot, storeHits[j].reason)) hiddenNow++;
      }

      if (window.__msaAppPromo) {
        window.__msaAppPromo.stats.scans += 1;
        window.__msaAppPromo.stats.lastHiddenBatch = hiddenNow;
        window.__msaAppPromo.stats.visiblePromoText = livePromoLabels();
      }
    } catch (e) {
      if (window.__msaAppPromo) {
        window.__msaAppPromo.stats.lastError = String((e && e.message) || e);
      }
    }
  }

  function livePromoLabels() {
    var labels = [];
    var vh = window.innerHeight || 800;
    var vw = window.innerWidth || 400;
    function pushLabel(el) {
      if (!el || labels.length >= 30) return;
      if (el.getAttribute && el.getAttribute(MARK) === '1') return;
      if (isInBottomNav(el)) return;
      var label = readableLabel(el);
      var reason = labelLooksPromo(label);
      if (!reason) return;
      labels.push({ text: label.slice(0, 48), reason: reason });
    }
    try {
      if (document.elementsFromPoint) {
        var stack = document.elementsFromPoint(vw * 0.5, vh - 80) || [];
        for (var s = 0; s < stack.length && s < 14; s++) pushLabel(stack[s]);
      }
    } catch (e0) {}
    var nodes = document.querySelectorAll('a, button, [role="button"], span, div');
    for (var i = 0; i < nodes.length && labels.length < 30; i++) {
      var el = nodes[i];
      try {
        var r = el.getBoundingClientRect();
        if (r.width < 8 || r.height < 8) continue;
        if (r.bottom < vh - 180 && r.top > 140) continue;
        var st = window.getComputedStyle(el);
        if (st.display === 'none' || st.visibility === 'hidden' || Number(st.opacity) === 0) {
          continue;
        }
      } catch (e) {
        continue;
      }
      pushLabel(el);
    }
    return labels;
  }

  window.__msaAppPromo = {
    enabled: window.__msaAppPromoDisableLaunch ? false : true,
    stats: {
      hidden: 0,
      scans: 0,
      lastHiddenBatch: 0,
      lastReasons: [],
      lastError: null,
      visiblePromoText: []
    },
    scanNow: function () {
      applyPromoHide();
    },
    setEnabled: function (on) {
      this.enabled = !!on;
      if (this.enabled) {
        applyPromoHide();
      } else {
        // Reveal previously hidden nodes for before-proof.
        var marked = document.querySelectorAll('[' + MARK + '="1"]');
        for (var i = 0; i < marked.length; i++) {
          try {
            marked[i].removeAttribute(MARK);
            marked[i].removeAttribute(REASON);
            marked[i].style.removeProperty('display');
            marked[i].style.removeProperty('visibility');
            marked[i].style.removeProperty('pointer-events');
            marked[i].style.removeProperty('height');
            marked[i].style.removeProperty('max-height');
            marked[i].style.removeProperty('opacity');
            marked[i].style.removeProperty('overflow');
          } catch (e) {}
        }
      }
    },
    dump: function () {
      try {
        applyPromoHide();
      } catch (e) {}
      var marked = document.querySelectorAll('[' + MARK + '="1"]');
      var reasons = [];
      for (var i = 0; i < marked.length; i++) {
        reasons.push(marked[i].getAttribute(REASON) || '?');
      }
      return {
        enabled: this.enabled,
        stats: this.stats,
        markedCount: marked.length,
        markedReasons: reasons,
        visiblePromoText: livePromoLabels(),
        hitTestBottom: hitTestBottom(),
        scriptCanary: 'apppromo-v15',
        path: location.pathname,
        hasStyle: !!document.getElementById(STYLE_ID)
      };
    }
  };

  var scheduled = null;
  function schedule() {
    if (scheduled) return;
    scheduled = setTimeout(function () {
      scheduled = null;
      applyPromoHide();
    }, 120);
  }

  var mo = new MutationObserver(function () {
    schedule();
  });

  function start() {
    ensureStyle();
    applyPromoHide();
    var opts = {
      childList: true,
      subtree: true,
      attributes: true,
      attributeFilter: ['class', 'style', 'href', 'aria-label', 'hidden', 'role']
    };
    if (window.__msaRegisterMO) {
      window.__msaRegisterMO(mo, function () { return document.documentElement; }, opts);
    } else {
      try {
        mo.observe(document.documentElement, opts);
      } catch (e) {}
    }
  }

  if (document.documentElement) start();
  else document.addEventListener('DOMContentLoaded', start);

  // History / SPA navigation hooks.
  try {
    var _push = history.pushState;
    history.pushState = function () {
      var r = _push.apply(this, arguments);
      schedule();
      return r;
    };
    var _replace = history.replaceState;
    history.replaceState = function () {
      var r = _replace.apply(this, arguments);
      schedule();
      return r;
    };
  } catch (e) {}

  window.addEventListener('popstate', schedule);
  window.addEventListener('hashchange', schedule);
  window.addEventListener('resize', schedule);
  // Scroll is handled by InstagramScrollCoalesce → flush; avoid per-scroll full scans.
  document.addEventListener('visibilitychange', schedule);
  try {
    var prevFlush = window.__msaFlushAfterScroll;
    window.__msaFlushAfterScroll = function () {
      try {
        if (typeof prevFlush === 'function') prevFlush();
      } catch (e3) {}
      schedule();
    };
  } catch (e4) {}
  // Dense early passes + long tail (chaos 2325: banner can appear ~60s in).
  var early = [0, 40, 120, 280, 600, 1200, 2200, 3500, 6000, 10000, 20000, 45000, 70000];
  for (var ei = 0; ei < early.length; ei++) {
    (function (delay) {
      setTimeout(applyPromoHide, delay);
    })(early[ei]);
  }
  // Sticky bottom strip: always-on lightweight interval (even while scrolling).
  setInterval(function () {
    try {
      if (window.__msaAppPromo && window.__msaAppPromo.enabled === false) return;
      ensureStyle();
      hideKnownInstallClasses();
      hideBottomInstallStrip();
      hideGeometricInstallStrip();
      hideUseTheAppTextNodes();
    } catch (e5) {}
  }, 280);
  // Fuller scan when quiet.
  setInterval(function () {
    if (!window.__msaScrollBurst) applyPromoHide();
  }, 900);
})();
"""#

    /// Evaluate in WKWebView to dump promo-hide state as JSON string.
    static let dumpScript: String = #"""
(function () {
  try {
    if (window.__msaAppPromo && window.__msaAppPromo.dump) {
      return JSON.stringify(window.__msaAppPromo.dump());
    }
    return JSON.stringify({ error: 'app_promo_missing', installed: !!window.__msaAppPromoInstalled });
  } catch (e) {
    return JSON.stringify({ error: String(e) });
  }
})()
"""#
}
