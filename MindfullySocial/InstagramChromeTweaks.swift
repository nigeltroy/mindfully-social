import Foundation

/// Injected CSS/JS that hides Instagram’s Reels bottom-nav tab and
/// redistributes the remaining icons evenly. Re-applies after SPA updates.
///
/// Critical: hide **Reels only**. Never hide Direct/Messages (`/direct`).
/// MSA-34 / chaos BUG-2: `reels-nav-v3` — deeper label walk + tab classifier
/// so the clapperboard tab dies even when aria/href are nested oddly.
enum InstagramChromeTweaks {
    static let userScriptSource: String = #"""
(function () {
  if (window.__msaReelsInstalled && window.__msaReelsCanary === 'reels-nav-v3') return;
  window.__msaReelsInstalled = true;
  window.__msaReelsCanary = 'reels-nav-v3';

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
      return r.width >= 6 && r.height >= 6 && r.bottom > 0 && r.top < window.innerHeight + 2;
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
    try {
      var nodes = el.querySelectorAll ? el.querySelectorAll('[aria-label], title, svg') : [];
      for (var i = 0; i < nodes.length && i < 20; i++) {
        push(nodes[i].getAttribute && nodes[i].getAttribute('aria-label'));
        if ((nodes[i].tagName || '').toLowerCase() === 'title') push(nodes[i].textContent);
        try {
          var t = nodes[i].querySelector && nodes[i].querySelector('title');
          if (t) push(t.textContent);
        } catch (e3) {}
      }
    } catch (e4) {}
    return parts.join(' ').toLowerCase();
  }

  function inBottomBand(el) {
    try {
      var r = el.getBoundingClientRect();
      if (r.width < 24 || r.height < 24) return false;
      // Bottom ~28% — iPhone home-indicator chrome sits lower than older cuts.
      if (r.top < window.innerHeight * 0.72) return false;
      if (r.bottom < window.innerHeight - 160) return false;
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
    // Bare /username/ profile tab — single segment, not reserved.
    if (/^\/[a-z0-9._]+\/?$/i.test(p) && p.indexOf('/reels') !== 0) return 'profile';
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
        if (child.tagName === 'A' || child.getAttribute('role') === 'link' || child.getAttribute('role') === 'tab') {
          link = child;
        } else {
          link = child.querySelector('a[href], [role="link"], [role="tab"]');
        }
        if (!link) continue;
        if (!inBottomBand(link) && !inBottomBand(child)) continue;
        var r = link.getBoundingClientRect();
        if (r.width < 24 || r.height < 24) continue;
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

  function collectBottomCandidates() {
    return Array.prototype.slice.call(document.querySelectorAll(
      'a[href], [role="link"], [role="tab"], [role="button"], button, div[aria-label], span[aria-label], svg[aria-label]'
    ));
  }

  function hideBottomReelsFallback() {
    var nodes = collectBottomCandidates();
    for (var i = 0; i < nodes.length; i++) {
      var a = nodes[i];
      if (!isVisible(a) || !inBottomBand(a)) continue;
      if (!isReelsTabControl(a)) continue;
      markReelsSlot(a, null);
    }
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
      var row = findNavRow(home);
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

      var keep = [];
      var kids = Array.prototype.slice.call(container.children);
      for (var j = 0; j < kids.length; j++) {
        var child = kids[j];
        child.removeAttribute('data-msa-reels-target');
        var link = child.tagName === 'A' || child.getAttribute('role') === 'link' || child.getAttribute('role') === 'tab'
          ? child
          : child.querySelector('a[href], [role="link"], [role="tab"], svg[aria-label]');
        var target = link || child;
        var kind = classifyTab(target);
        if (kind === 'reels' && !isDirectPath(pathOf(target))) {
          markReelsSlot(target, container);
          continue;
        }
        // Nested SVG labeled Reels inside an otherwise-unknown slot.
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

  function dumpNav() {
    var tabs = [];
    var home = findBottomNavHome();
    var row = findNavRow(home);
    var list = row ? row.tabs : [];
    if (!list.length) {
      var nodes = collectBottomCandidates();
      for (var i = 0; i < nodes.length; i++) {
        if (isVisible(nodes[i]) && inBottomBand(nodes[i])) list.push(nodes[i]);
      }
    }
    for (var t = 0; t < list.length; t++) {
      var el = list[t];
      var r = { w: 0, h: 0, top: 0, left: 0 };
      try {
        var br = el.getBoundingClientRect();
        r = { w: Math.round(br.width), h: Math.round(br.height), top: Math.round(br.top), left: Math.round(br.left) };
      } catch (e) {}
      tabs.push({
        tag: el.tagName,
        role: el.getAttribute('role') || '',
        href: el.getAttribute('href') || '',
        path: pathOf(el),
        aria: el.getAttribute('aria-label') || '',
        label: tabLabel(el).slice(0, 120),
        kind: classifyTab(el),
        marked: el.getAttribute('data-msa-reels-target') === '1' ||
          !!(el.closest && el.closest('[data-msa-reels-target="1"]')),
        rect: r
      });
    }
    return {
      scriptCanary: 'reels-nav-v3',
      path: location.pathname,
      bottomNav: !!document.querySelector('[data-msa-bottom-nav="1"]'),
      markedCount: document.querySelectorAll('[data-msa-reels-target="1"]').length,
      visibleReelsKind: tabs.filter(function (x) { return x.kind === 'reels' && !x.marked; }).length,
      tabs: tabs
    };
  }

  var scheduled = null;
  function schedule() {
    if (scheduled) return;
    scheduled = setTimeout(function () {
      scheduled = null;
      apply();
    }, 50);
  }

  var mo = new MutationObserver(schedule);
  function start() {
    ensureStyle();
    apply();
    try {
      mo.observe(document.documentElement, {
        childList: true,
        subtree: true,
        attributes: true,
        attributeFilter: ['href', 'class', 'style', 'aria-label', 'role']
      });
    } catch (e) {}
  }

  if (document.documentElement) start();
  else document.addEventListener('DOMContentLoaded', start);

  window.addEventListener('resize', schedule);
  window.addEventListener('popstate', schedule);
  document.addEventListener('visibilitychange', schedule);
  setInterval(apply, 500);

  window.__msaReelsNav = {
    scriptCanary: 'reels-nav-v3',
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
