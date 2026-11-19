import Foundation

/// Injected CSS/JS that hides Instagram’s Reels bottom-nav tab and
/// redistributes the remaining icons evenly. Re-applies after SPA updates.
///
/// Critical: hide **Reels only** (`/reels` / `/reels/` / aria Reels). Never hide
/// Direct/Messages (`/direct`). MSA-30: harden for Create/Shop 5-tab chrome
/// (chaos-soak BUG-2 — SocialLite removes Reels tab entirely).
enum InstagramChromeTweaks {
    static let userScriptSource: String = #"""
(function () {
  if (window.__msaReelsInstalled) return;
  window.__msaReelsInstalled = true;
  window.__msaReelsCanary = 'reels-nav-v2';

  var STYLE_ID = 'msa-hide-reels-style';

  function ensureStyle() {
    var style = document.getElementById(STYLE_ID);
    if (!style) {
      style = document.createElement('style');
      style.id = STYLE_ID;
      (document.head || document.documentElement).appendChild(style);
    }
    style.textContent = [
      /* Exact bottom-tab href only (in-feed uses /reels/audio/... or /…/reel/…). */
      'a[href="/reels/"],',
      'a[href="/reels"],',
      'a[href^="/reels/?"],',
      'a[href^="https://www.instagram.com/reels"],',
      'a[href^="https://instagram.com/reels"],',
      /* Chaos-soak BUG-2: some builds label the tab without a stable /reels href. */
      'a[aria-label="Reels" i],',
      'a[aria-label^="Reels" i],',
      '[role="link"][aria-label="Reels" i],',
      '[role="link"][aria-label^="Reels" i],',
      '[role="tab"][aria-label="Reels" i],',
      '[role="tab"][aria-label^="Reels" i] {',
      '  display: none !important;',
      '  pointer-events: none !important;',
      '}',
      '[data-msa-reels-target="1"] {',
      '  display: none !important;',
      '  width: 0 !important;',
      '  min-width: 0 !important;',
      '  max-width: 0 !important;',
      '  flex: 0 0 0 !important;',
      '  grid-area: unset !important;',
      '  grid-column: unset !important;',
      '  padding: 0 !important;',
      '  margin: 0 !important;',
      '  overflow: hidden !important;',
      '  opacity: 0 !important;',
      '  pointer-events: none !important;',
      '  height: 0 !important;',
      '  border: 0 !important;',
      '}',
      /* IG often uses CSS grid with 5 columns — force flex so removing Reels reflows. */
      '[data-msa-bottom-nav="1"] {',
      '  display: flex !important;',
      '  flex-direction: row !important;',
      '  justify-content: space-evenly !important;',
      '  align-items: center !important;',
      '  width: 100% !important;',
      '  gap: 0 !important;',
      '  grid-template-columns: none !important;',
      '  grid-template-rows: none !important;',
      '  grid-auto-flow: unset !important;',
      '  grid-auto-columns: unset !important;',
      '}',
      '[data-msa-bottom-nav="1"] > *:not([data-msa-reels-target="1"]) {',
      '  flex: 1 1 0 !important;',
      '  display: flex !important;',
      '  justify-content: center !important;',
      '  align-items: center !important;',
      '  min-width: 0 !important;',
      '  max-width: none !important;',
      '  width: auto !important;',
      '  margin: 0 !important;',
      '  grid-column: unset !important;',
      '  grid-row: unset !important;',
      '}'
    ].join('\n');
  }

  function isVisible(el) {
    var r = el.getBoundingClientRect();
    return r.width >= 8 && r.height >= 8 && r.bottom > 0 && r.top < window.innerHeight;
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
    try { parts.push(el.getAttribute('aria-label') || ''); } catch (e) {}
    try {
      var t = el.querySelector && el.querySelector('title');
      if (t) parts.push(t.textContent || '');
    } catch (e2) {}
    try { parts.push(el.getAttribute('href') || ''); } catch (e3) {}
    return parts.join(' ').replace(/\s+/g, ' ').trim().toLowerCase();
  }

  function isReelsTabControl(el) {
    if (!el) return false;
    var p = pathOf(el);
    if (isDirectPath(p)) return false;
    if (isExactReelsPath(p)) return true;
    var label = tabLabel(el);
    // Exact / leading "reels" only — avoid captions that mention reels.
    if (label === 'reels' || label.indexOf('reels ') === 0 || label.indexOf('reels/') !== -1) {
      return true;
    }
    if (/\breels\b/.test(label) && label.length <= 24) return true;
    return false;
  }

  function inBottomBand(el) {
    try {
      var r = el.getBoundingClientRect();
      if (r.width < 28 || r.height < 28) return false;
      if (r.bottom < window.innerHeight - 120) return false;
      if (r.top < window.innerHeight - 220) return false;
      return true;
    } catch (e) {
      return false;
    }
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
      if (!isVisible(a)) continue;
      if (!inBottomBand(a)) continue;
      var p = pathOf(a);
      var label = tabLabel(a);
      if (p !== '/' && p !== '' && label.indexOf('home') === -1) continue;
      if (label.indexOf('home') !== -1) return a;
      if ((p === '/' || p === '') && !best) best = a;
    }
    return best;
  }

  function findNavRow(home) {
    if (!home) return null;
    var el = home.parentElement;
    while (el && el !== document.body) {
      // Prefer the shallowest parent that directly owns ~4–6 tab links.
      var directTabs = [];
      for (var c = 0; c < el.children.length; c++) {
        var child = el.children[c];
        var link = child.tagName === 'A' || child.getAttribute('role') === 'link' || child.getAttribute('role') === 'tab'
          ? child
          : child.querySelector('a[href], [role="link"], [role="tab"]');
        if (!link) continue;
        if (!inBottomBand(link) && !inBottomBand(child)) continue;
        var r = link.getBoundingClientRect();
        if (r.width < 28 || r.height < 28) continue;
        directTabs.push(link);
      }
      if (directTabs.length >= 4 && directTabs.length <= 6) {
        return { container: el, tabs: directTabs };
      }
      el = el.parentElement;
    }
    return null;
  }

  function markReelsSlot(node, container) {
    var slot = container ? climbToDirectChild(node, container) : (node.parentElement || node);
    try {
      slot.remove();
      return true;
    } catch (err) {
      slot.setAttribute('data-msa-reels-target', '1');
      slot.style.setProperty('display', 'none', 'important');
      slot.style.setProperty('flex', '0 0 0', 'important');
      slot.style.setProperty('width', '0', 'important');
      node.setAttribute('data-msa-reels-target', '1');
      return false;
    }
  }

  function hideBottomReelsFallback() {
    var nodes = document.querySelectorAll(
      'a[href], [role="link"], [role="tab"], [role="button"], button, div[aria-label], span[aria-label]'
    );
    for (var i = 0; i < nodes.length; i++) {
      var a = nodes[i];
      if (!isVisible(a) || !inBottomBand(a)) continue;
      if (!isReelsTabControl(a)) continue;
      markReelsSlot(a, null);
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
      // Inline overrides beat IG stylesheet grid (5-col holes after hide).
      container.style.setProperty('display', 'flex', 'important');
      container.style.setProperty('flex-direction', 'row', 'important');
      container.style.setProperty('justify-content', 'space-evenly', 'important');
      container.style.setProperty('align-items', 'center', 'important');
      container.style.setProperty('grid-template-columns', 'none', 'important');
      container.style.setProperty('padding-left', '0', 'important');
      container.style.setProperty('padding-right', '0', 'important');
      container.style.setProperty('gap', '0', 'important');

      var keep = [];
      for (var j = 0; j < container.children.length; j++) {
        var child = container.children[j];
        child.removeAttribute('data-msa-reels-target');
        var link = child.tagName === 'A' || child.getAttribute('role') === 'link' || child.getAttribute('role') === 'tab'
          ? child
          : child.querySelector('a[href], [role="link"], [role="tab"]');
        if (!link) {
          // Non-link child (rare) — keep unless it looks like Reels chrome.
          if (isReelsTabControl(child)) {
            markReelsSlot(child, container);
          } else {
            keep.push(child);
          }
          continue;
        }
        if (isReelsTabControl(link) && !isDirectPath(pathOf(link))) {
          markReelsSlot(link, container);
          continue;
        }
        keep.push(child);
      }

      // Second pass: catch Reels controls that are not direct children links.
      hideBottomReelsFallback();

      var n = keep.length || 1;
      var pct = (100 / n).toFixed(4) + '%';
      for (var k = 0; k < keep.length; k++) {
        var slotKeep = keep[k];
        if (!slotKeep || !slotKeep.isConnected) continue;
        if (slotKeep.getAttribute('data-msa-reels-target') === '1') continue;
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
        slotKeep.style.setProperty('padding-left', '0', 'important');
        slotKeep.style.setProperty('padding-right', '0', 'important');
      }
    } catch (e) {
      // Keep browsing even if Instagram DOM shifts.
    }
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
  setInterval(apply, 600);

  window.__msaReelsNav = {
    scriptCanary: 'reels-nav-v2',
    apply: apply
  };
})();
"""#
}
