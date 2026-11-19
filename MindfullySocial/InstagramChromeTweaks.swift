import Foundation

/// Injected CSS/JS that hides Instagram’s Reels bottom-nav tab and
/// redistributes the remaining icons evenly. Re-applies after SPA updates.
///
/// Critical: hide **Reels only**. Never hide Direct/Messages (`/direct`).
/// MSA-34 / chaos BUG-2: `reels-nav-v4` — geometry-first bottom row (div chrome
/// without aria/href), richer dump probe, position fallback for 4-tab layout.
enum InstagramChromeTweaks {
    static let userScriptSource: String = #"""
(function () {
  if (window.__msaReelsInstalled && window.__msaReelsCanary === 'reels-nav-v4') return;
  window.__msaReelsInstalled = true;
  window.__msaReelsCanary = 'reels-nav-v4';

  var STYLE_ID = 'msa-hide-reels-style';

  function ensureStyle() {
    var style = document.getElementById(STYLE_ID);
    if (!style) {
      style = document.createElement('style');
      style.id = STYLE_ID;
      (document.head || document.documentElement).appendChild(style);
    }
    style.textContent = [
      'a[href="/reels/"],',
      'a[href="/reels"],',
      'a[href^="/reels/?"],',
      'a[href*="instagram.com/reels"],',
      'a[aria-label="Reels" i],',
      'a[aria-label^="Reels" i],',
      '[role="link"][aria-label="Reels" i],',
      '[role="link"][aria-label^="Reels" i],',
      '[role="tab"][aria-label="Reels" i],',
      '[role="tab"][aria-label^="Reels" i],',
      'svg[aria-label="Reels" i],',
      'svg[aria-label^="Reels" i] {',
      '  display: none !important;',
      '  pointer-events: none !important;',
      '}',
      '[data-msa-reels-target="1"] {',
      '  display: none !important;',
      '  width: 0 !important;',
      '  min-width: 0 !important;',
      '  max-width: 0 !important;',
      '  flex: 0 0 0 !important;',
      '  padding: 0 !important;',
      '  margin: 0 !important;',
      '  overflow: hidden !important;',
      '  opacity: 0 !important;',
      '  pointer-events: none !important;',
      '  height: 0 !important;',
      '  border: 0 !important;',
      '}',
      '[data-msa-bottom-nav="1"] {',
      '  display: flex !important;',
      '  flex-direction: row !important;',
      '  justify-content: space-evenly !important;',
      '  align-items: center !important;',
      '  width: 100% !important;',
      '  gap: 0 !important;',
      '  grid-template-columns: none !important;',
      '}',
      '[data-msa-bottom-nav="1"] > *:not([data-msa-reels-target="1"]) {',
      '  flex: 1 1 0 !important;',
      '  display: flex !important;',
      '  justify-content: center !important;',
      '  align-items: center !important;',
      '  min-width: 0 !important;',
      '  width: auto !important;',
      '  margin: 0 !important;',
      '}'
    ].join('\n');
  }

  function isVisible(el) {
    try {
      var r = el.getBoundingClientRect();
      return r.width >= 4 && r.height >= 4 && r.bottom > 0 && r.top < window.innerHeight + 4;
    } catch (e) { return false; }
  }

  function pathOf(el) {
    try {
      var abs = el.href || el.getAttribute('href') || '';
      if (!abs) return '';
      return new URL(abs, location.origin).pathname.toLowerCase();
    } catch (e) {
      return (el.getAttribute('href') || '').split('?')[0].split('#')[0].toLowerCase();
    }
  }

  function isExactReelsPath(path) {
    var p = String(path || '').toLowerCase().split('?')[0].split('#')[0];
    return p === '/reels' || p === '/reels/';
  }

  function isDirectPath(path) {
    return path === '/direct' || path.indexOf('/direct/') === 0;
  }

  function tabLabel(el) {
    var parts = [];
    function push(s) {
      s = String(s || '').replace(/\s+/g, ' ').trim();
      if (s) parts.push(s);
    }
    try { push(el.getAttribute('aria-label')); } catch (e) {}
    try { push(el.getAttribute('href')); } catch (e2) {}
    try { push(el.getAttribute('title')); } catch (e2b) {}
    try {
      var nodes = el.querySelectorAll ? el.querySelectorAll('[aria-label], title, svg, img') : [];
      for (var i = 0; i < nodes.length && i < 30; i++) {
        push(nodes[i].getAttribute && nodes[i].getAttribute('aria-label'));
        push(nodes[i].getAttribute && nodes[i].getAttribute('alt'));
        if ((nodes[i].tagName || '').toLowerCase() === 'title') push(nodes[i].textContent);
        try {
          var t = nodes[i].querySelector && nodes[i].querySelector('title');
          if (t) push(t.textContent);
        } catch (e3) {}
      }
    } catch (e4) {}
    return parts.join(' ').toLowerCase();
  }

  // Looser than v3: iPhone 17 home-indicator chrome + IG fixed bar sit mid-low.
  function inBottomBand(el) {
    try {
      var r = el.getBoundingClientRect();
      if (r.width < 16 || r.height < 16) return false;
      if (r.top < window.innerHeight * 0.55) return false;
      if (r.bottom < window.innerHeight - 220) return false;
      return true;
    } catch (e) {
      return false;
    }
  }

  function classifyTab(el) {
    var p = pathOf(el);
    var label = tabLabel(el);
    if (isDirectPath(p) || /\b(messages?|messenger|direct)\b/.test(label)) return 'direct';
    if (isExactReelsPath(p) || /(^|\b)reels?\b/.test(label) || label.indexOf('/reels') !== -1) return 'reels';
    if (p === '/' || p === '' || /\bhome\b/.test(label)) return 'home';
    if (p.indexOf('/explore') === 0 || /\b(search|explore)\b/.test(label)) return 'search';
    if (p.indexOf('/shop') === 0 || /\bshop\b/.test(label) || /\bstore\b/.test(label) || /\bbag\b/.test(label)) return 'shop';
    if (/\b(create|new post|new reel)\b/.test(label)) return 'create';
    if (/\bprofile\b/.test(label) || /\baccount\b/.test(label)) return 'profile';
    if (/^\/[a-z0-9._]+\/?$/i.test(p) && p.indexOf('/reels') !== 0) return 'profile';
    // Clapper SVG often has a play triangle path and a square/rect outline.
    try {
      var html = (el.innerHTML || '').toLowerCase();
      if (html.indexOf('reels') !== -1) return 'reels';
      // IG Reels glyph: nested rect + polygon/play-ish path near bottom chrome.
      if (el.querySelector && el.querySelector('svg') && /(clapper|reel)/i.test(html)) return 'reels';
    } catch (e5) {}
    return 'unknown';
  }

  function isReelsTabControl(el) {
    if (!el) return false;
    if (isDirectPath(pathOf(el))) return false;
    return classifyTab(el) === 'reels';
  }

  function climbToDirectChild(el, ancestor) {
    var node = el;
    while (node.parentElement && node.parentElement !== ancestor) {
      node = node.parentElement;
    }
    return node;
  }

  function rectOf(el) {
    try {
      var br = el.getBoundingClientRect();
      return { w: Math.round(br.width), h: Math.round(br.height), top: Math.round(br.top), left: Math.round(br.left), bottom: Math.round(br.bottom) };
    } catch (e) {
      return { w: 0, h: 0, top: 0, left: 0, bottom: 0 };
    }
  }

  function looksInteractive(el) {
    if (!el || !el.tagName) return false;
    var tag = el.tagName.toLowerCase();
    if (tag === 'a' || tag === 'button') return true;
    var role = (el.getAttribute('role') || '').toLowerCase();
    if (role === 'link' || role === 'tab' || role === 'button') return true;
    if (el.hasAttribute('href') || el.hasAttribute('tabindex')) return true;
    return false;
  }

  function collectBottomCandidates() {
    return Array.prototype.slice.call(document.querySelectorAll(
      'a[href], [role="link"], [role="tab"], [role="button"], button, div[aria-label], span[aria-label], svg[aria-label], div[tabindex], span[tabindex]'
    ));
  }

  // Geometry-first: find a horizontal row of similar-sized slots near the bottom,
  // even when IG uses bare divs with no aria/href (current 4-tab chrome).
  function findBottomNavByGeometry() {
    var vh = window.innerHeight || 0;
    var vw = window.innerWidth || 0;
    if (vh < 200 || vw < 200) return null;

    var all = document.querySelectorAll('div, a, span, button, nav, section');
    var slots = [];
    for (var i = 0; i < all.length; i++) {
      var el = all[i];
      if (!el || !el.getBoundingClientRect) continue;
      var r = el.getBoundingClientRect();
      if (r.width < 36 || r.width > vw * 0.34) continue;
      if (r.height < 28 || r.height > 96) continue;
      if (r.top < vh * 0.62) continue;
      if (r.bottom < vh - 200) continue;
      if (r.left < -4 || r.right > vw + 4) continue;
      // Prefer leaf-ish slots: few children, or wraps a single svg/a.
      var childCount = el.children ? el.children.length : 0;
      if (childCount > 6) continue;
      slots.push({ el: el, r: r, midY: r.top + r.height / 2, midX: r.left + r.width / 2 });
    }
    if (slots.length < 3) return null;

    // Cluster by midY
    slots.sort(function (a, b) { return a.midY - b.midY || a.midX - b.midX; });
    var bestGroup = [];
    for (var s = 0; s < slots.length; s++) {
      var seed = slots[s];
      var group = [seed];
      for (var t = 0; t < slots.length; t++) {
        if (t === s) continue;
        if (Math.abs(slots[t].midY - seed.midY) <= 18) group.push(slots[t]);
      }
      // Dedup overlapping / nested
      group.sort(function (a, b) { return a.midX - b.midX; });
      var dedup = [];
      for (var g = 0; g < group.length; g++) {
        var ok = true;
        for (var d = 0; d < dedup.length; d++) {
          if (Math.abs(group[g].midX - dedup[d].midX) < 20) {
            // Keep the smaller (more leaf-like) node.
            if (group[g].r.width * group[g].r.height < dedup[d].r.width * dedup[d].r.height) {
              dedup[d] = group[g];
            }
            ok = false;
            break;
          }
        }
        if (ok) dedup.push(group[g]);
      }
      if (dedup.length >= 3 && dedup.length <= 6 && dedup.length > bestGroup.length) {
        // Prefer the lowest row.
        if (!bestGroup.length || seed.midY >= bestGroup[0].midY - 8) {
          bestGroup = dedup;
        }
      }
    }
    if (bestGroup.length < 3) return null;

    bestGroup.sort(function (a, b) { return a.midX - b.midX; });
    // Climb to a common parent that owns these slots as descendants.
    var container = bestGroup[0].el.parentElement;
    var guard = 0;
    while (container && container !== document.body && guard++ < 12) {
      var owned = 0;
      for (var b = 0; b < bestGroup.length; b++) {
        if (container.contains(bestGroup[b].el)) owned++;
      }
      if (owned === bestGroup.length && container.children.length >= bestGroup.length && container.children.length <= 10) {
        break;
      }
      container = container.parentElement;
    }
    if (!container) container = bestGroup[0].el.parentElement;

    var tabs = bestGroup.map(function (x) {
      // Prefer an interactive descendant if present.
      var link = null;
      if (looksInteractive(x.el)) link = x.el;
      else if (x.el.querySelector) {
        link = x.el.querySelector('a[href], [role="link"], [role="tab"], button, svg[aria-label]');
      }
      return link || x.el;
    });
    return { container: container, tabs: tabs, slots: bestGroup.map(function (x) { return x.el; }) };
  }

  function findBottomNavHome() {
    var anchors = document.querySelectorAll('a[href], [role="link"], [role="tab"]');
    var best = null;
    for (var i = 0; i < anchors.length; i++) {
      var a = anchors[i];
      if (!isVisible(a) || !inBottomBand(a)) continue;
      if (classifyTab(a) === 'home') return a;
      var p = pathOf(a);
      if ((p === '/' || p === '') && !best) best = a;
    }
    return best;
  }

  function findNavRow(home) {
    if (!home) return null;
    var el = home.parentElement;
    while (el && el !== document.body) {
      var directTabs = [];
      for (var c = 0; c < el.children.length; c++) {
        var child = el.children[c];
        var link = null;
        if (looksInteractive(child)) {
          link = child;
        } else {
          link = child.querySelector('a[href], [role="link"], [role="tab"], svg[aria-label]');
        }
        if (!link) continue;
        if (!inBottomBand(link) && !inBottomBand(child)) continue;
        var r = link.getBoundingClientRect();
        if (r.width < 16 || r.height < 16) continue;
        directTabs.push(link);
      }
      if (directTabs.length >= 3 && directTabs.length <= 7) {
        return { container: el, tabs: directTabs };
      }
      el = el.parentElement;
    }
    return null;
  }

  function markReelsSlot(node, container) {
    var slot = container ? climbToDirectChild(node, container) : (node.parentElement || node);
    try {
      slot.setAttribute('data-msa-reels-target', '1');
      slot.style.setProperty('display', 'none', 'important');
      slot.style.setProperty('flex', '0 0 0', 'important');
      slot.style.setProperty('width', '0', 'important');
      slot.style.setProperty('pointer-events', 'none', 'important');
      node.setAttribute('data-msa-reels-target', '1');
      try { slot.remove(); } catch (e2) {}
      return true;
    } catch (err) {
      try {
        node.setAttribute('data-msa-reels-target', '1');
        node.style.setProperty('display', 'none', 'important');
      } catch (e3) {}
      return false;
    }
  }

  function hideBottomReelsFallback() {
    var nodes = collectBottomCandidates();
    for (var i = 0; i < nodes.length; i++) {
      var a = nodes[i];
      if (!isVisible(a) || !inBottomBand(a)) continue;
      if (!isReelsTabControl(a)) continue;
      markReelsSlot(a, null);
    }
    // Exact /reels anchors anywhere in the lower third.
    var anchors = document.querySelectorAll('a[href]');
    for (var j = 0; j < anchors.length; j++) {
      var link = anchors[j];
      if (!isExactReelsPath(pathOf(link))) continue;
      if (!isVisible(link)) continue;
      var r = link.getBoundingClientRect();
      if (r.top < window.innerHeight * 0.55) continue;
      markReelsSlot(link, null);
    }
  }

  function resolveKinds(tabs) {
    var kinds = tabs.map(function (el) { return classifyTab(el); });
    // Never overwrite a confident direct/messages classification — MSA-16/34
    // must not hide Direct. Current IG 4-tab chrome is often
    // Home / Explore / Messages / Profile (no Reels tab at all).
    function canGuess(i) {
      return kinds[i] === 'unknown';
    }
    if (tabs.length === 4) {
      var hasReels = kinds.indexOf('reels') !== -1;
      var hasDirect = kinds.indexOf('direct') !== -1;
      if (!hasReels && !hasDirect) {
        // Only guess Reels when slot 2 is unknown AND neighbors look like home/search + profile.
        if (canGuess(2) &&
            (kinds[0] === 'home' || canGuess(0)) &&
            (kinds[1] === 'search' || canGuess(1)) &&
            (kinds[3] === 'profile' || canGuess(3))) {
          kinds[2] = 'reels';
        }
      }
    }
    // 5-tab classic: Home / Search / Reels / Shop-or-Create / Profile — index 2 only if unknown.
    if (tabs.length === 5 && kinds.indexOf('reels') === -1) {
      if (canGuess(2) && (kinds[0] === 'home' || canGuess(0)) && kinds.indexOf('direct') === -1) {
        kinds[2] = 'reels';
      }
    }
    return kinds;
  }

  function redistribute(container, keep) {
    var alive = [];
    for (var i = 0; i < keep.length; i++) {
      if (keep[i] && keep[i].isConnected && keep[i].getAttribute('data-msa-reels-target') !== '1') {
        alive.push(keep[i]);
      }
    }
    var n = alive.length || 1;
    var pct = (100 / n).toFixed(4) + '%';
    for (var k = 0; k < alive.length; k++) {
      var slotKeep = alive[k];
      slotKeep.style.setProperty('flex', '1 1 0', 'important');
      slotKeep.style.setProperty('flex-grow', '1', 'important');
      slotKeep.style.setProperty('flex-basis', '0', 'important');
      slotKeep.style.setProperty('width', pct, 'important');
      slotKeep.style.setProperty('max-width', pct, 'important');
      slotKeep.style.setProperty('min-width', '0', 'important');
      slotKeep.style.setProperty('display', 'flex', 'important');
      slotKeep.style.setProperty('justify-content', 'center', 'important');
      slotKeep.style.setProperty('align-items', 'center', 'important');
      slotKeep.style.setProperty('margin', '0', 'important');
    }
  }

  function dismissBlockingTips() {
    try {
      var nodes = document.querySelectorAll('button, [role="button"]');
      for (var i = 0; i < nodes.length; i++) {
        var t = (nodes[i].textContent || '').replace(/\s+/g, ' ').trim();
        if (t === 'OK' || t === 'Ok') {
          nodes[i].click();
          return;
        }
      }
    } catch (e) {}
  }

  function apply() {
    try {
      ensureStyle();
      dismissBlockingTips();

      var home = findBottomNavHome();
      var row = findNavRow(home) || findBottomNavByGeometry();
      if (!row) {
        hideBottomReelsFallback();
        return;
      }

      var container = row.container;
      container.setAttribute('data-msa-bottom-nav', '1');
      container.style.setProperty('display', 'flex', 'important');
      container.style.setProperty('flex-direction', 'row', 'important');
      container.style.setProperty('justify-content', 'space-evenly', 'important');
      container.style.setProperty('align-items', 'center', 'important');
      container.style.setProperty('grid-template-columns', 'none', 'important');
      container.style.setProperty('gap', '0', 'important');

      var kids = Array.prototype.slice.call(container.children);
      var tabEls = row.tabs || [];
      var kinds = resolveKinds(tabEls);

      // Mark reels via resolved kinds on discovered tabs.
      for (var t = 0; t < tabEls.length; t++) {
        if (kinds[t] === 'reels' && !isDirectPath(pathOf(tabEls[t]))) {
          markReelsSlot(tabEls[t], container);
        }
      }

      var keep = [];
      for (var j = 0; j < kids.length; j++) {
        var child = kids[j];
        if (child.getAttribute('data-msa-reels-target') === '1') continue;
        if (!child.isConnected) continue;
        var link = looksInteractive(child)
          ? child
          : (child.querySelector && child.querySelector('a[href], [role="link"], [role="tab"], svg[aria-label]'));
        var target = link || child;
        var kind = classifyTab(target);
        // If this child contains a marked reels descendant, skip.
        if (child.querySelector && child.querySelector('[data-msa-reels-target="1"]')) {
          markReelsSlot(child, container);
          continue;
        }
        if (kind === 'reels' && !isDirectPath(pathOf(target))) {
          markReelsSlot(target, container);
          continue;
        }
        if (target.querySelector && target.querySelector('svg[aria-label*="Reel" i], [aria-label*="Reel" i]')) {
          var nestedLabel = tabLabel(target);
          if (/(^|\b)reels?\b/.test(nestedLabel) || isExactReelsPath(pathOf(target))) {
            markReelsSlot(target, container);
            continue;
          }
        }
        keep.push(child);
      }

      hideBottomReelsFallback();
      redistribute(container, keep);
    } catch (e) {}
  }

  function rawBottomProbe() {
    var vh = window.innerHeight || 0;
    var out = [];
    var nodes = document.querySelectorAll('a, button, [role="link"], [role="tab"], svg, div, span, nav');
    for (var i = 0; i < nodes.length && out.length < 40; i++) {
      var el = nodes[i];
      var r = rectOf(el);
      if (r.top < vh * 0.58) continue;
      if (r.w < 8 || r.h < 8) continue;
      if (r.w > (window.innerWidth || 0) * 0.9 && r.h > 120) continue;
      out.push({
        tag: el.tagName,
        role: el.getAttribute('role') || '',
        href: (el.getAttribute('href') || '').slice(0, 80),
        path: pathOf(el),
        aria: (el.getAttribute('aria-label') || '').slice(0, 60),
        label: tabLabel(el).slice(0, 80),
        kind: classifyTab(el),
        rect: r,
        kids: el.children ? el.children.length : 0
      });
    }
    return out;
  }

  function dumpNav() {
    var tabs = [];
    var home = findBottomNavHome();
    var row = findNavRow(home) || findBottomNavByGeometry();
    var list = row ? row.tabs : [];
    var kinds = list.length ? resolveKinds(list) : [];
    if (!list.length) {
      var nodes = collectBottomCandidates();
      for (var i = 0; i < nodes.length; i++) {
        if (isVisible(nodes[i]) && inBottomBand(nodes[i])) list.push(nodes[i]);
      }
      kinds = list.length ? resolveKinds(list) : [];
    }
    for (var t = 0; t < list.length; t++) {
      var el = list[t];
      tabs.push({
        tag: el.tagName,
        role: el.getAttribute('role') || '',
        href: el.getAttribute('href') || '',
        path: pathOf(el),
        aria: el.getAttribute('aria-label') || '',
        label: tabLabel(el).slice(0, 120),
        kind: kinds[t] || classifyTab(el),
        marked: el.getAttribute('data-msa-reels-target') === '1' ||
          !!(el.closest && el.closest('[data-msa-reels-target="1"]')),
        rect: rectOf(el)
      });
    }
    var reelsHrefs = [];
    try {
      var allA = document.querySelectorAll('a[href]');
      for (var a = 0; a < allA.length && reelsHrefs.length < 12; a++) {
        var p = pathOf(allA[a]);
        if (p.indexOf('/reel') !== -1) {
          reelsHrefs.push({ href: (allA[a].getAttribute('href') || '').slice(0, 100), path: p, rect: rectOf(allA[a]) });
        }
      }
    } catch (e) {}
    return {
      scriptCanary: 'reels-nav-v4',
      path: location.pathname,
      vh: window.innerHeight || 0,
      vw: window.innerWidth || 0,
      bottomNav: !!document.querySelector('[data-msa-bottom-nav="1"]'),
      hasStyle: !!document.getElementById(STYLE_ID),
      markedCount: document.querySelectorAll('[data-msa-reels-target="1"]').length,
      visibleReelsKind: tabs.filter(function (x) { return x.kind === 'reels' && !x.marked; }).length,
      rowSource: row ? (home && findNavRow(home) ? 'home-walk' : 'geometry') : 'none',
      tabs: tabs,
      reelsHrefs: reelsHrefs,
      rawBottom: rawBottomProbe()
    };
  }

  var scheduled = null;
  function schedule() {
    if (window.__msaScrollBurst) return;
    if (scheduled) return;
    scheduled = setTimeout(function () {
      scheduled = null;
      if (window.__msaScrollBurst) return;
      apply();
    }, 180);
  }

  var mo = new MutationObserver(schedule);
  function start() {
    ensureStyle();
    apply();
    var opts = {
      childList: true,
      subtree: true,
      attributes: true,
      attributeFilter: ['href', 'class', 'style', 'aria-label', 'role']
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

  window.addEventListener('resize', schedule);
  window.addEventListener('popstate', schedule);
  document.addEventListener('visibilitychange', schedule);
  try {
    var prevFlush = window.__msaFlushAfterScroll;
    window.__msaFlushAfterScroll = function () {
      try {
        if (typeof prevFlush === 'function') prevFlush();
      } catch (e2) {}
      schedule();
    };
  } catch (e3) {}
  setInterval(function () {
    if (!window.__msaScrollBurst) apply();
  }, 1200);

  window.__msaReelsNav = {
    scriptCanary: 'reels-nav-v4',
    apply: apply,
    dump: dumpNav
  };
})();
"""#

    static let dumpNavScript: String = #"""
(function () {
  try {
    if (window.__msaReelsNav && window.__msaReelsNav.dump) {
      return JSON.stringify(window.__msaReelsNav.dump());
    }
    return JSON.stringify({ error: 'reels_nav_missing', path: location.pathname });
  } catch (e) {
    return JSON.stringify({ error: String(e) });
  }
})()
"""#
}
