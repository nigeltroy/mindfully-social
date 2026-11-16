import Foundation

/// Injected CSS/JS that hides Instagram’s Reels bottom-nav tab and
/// redistributes the remaining icons evenly. Re-applies after SPA updates.
///
/// Critical: hide **Reels only** (`/reels` / `/reels/`). Never hide Direct/Messages (`/direct`).
enum InstagramChromeTweaks {
    static let userScriptSource: String = #"""
(function () {
  if (window.__msaReelsInstalled) return;
  window.__msaReelsInstalled = true;

  var STYLE_ID = 'msa-hide-reels-style';

  function ensureStyle() {
    var style = document.getElementById(STYLE_ID);
    if (!style) {
      style = document.createElement('style');
      style.id = STYLE_ID;
      (document.head || document.documentElement).appendChild(style);
    }
    // Durable href CSS: IG recreates nodes and drops data-* marks; exact /reels path
    // is only the bottom-tab entry (in-feed uses /reels/audio/... or /reel/...).
    style.textContent = [
      'a[href="/reels/"],',
      'a[href="/reels"],',
      'a[href="/reels/?hl=en"],',
      'a[href^="/reels/?"] {',
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
      '  border: 0 !important;',
      '  position: absolute !important;',
      '  height: 0 !important;',
      '}',
      /* Marked wrappers (flex children) also collapse */
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
      '}',
      '[data-msa-bottom-nav="1"] {',
      '  display: flex !important;',
      '  justify-content: space-evenly !important;',
      '  align-items: stretch !important;',
      '  width: 100% !important;',
      '  padding-left: 0 !important;',
      '  padding-right: 0 !important;',
      '  gap: 0 !important;',
      '}',
      '[data-msa-bottom-nav="1"] > * {',
      '  flex: 1 1 0 !important;',
      '  display: flex !important;',
      '  justify-content: center !important;',
      '  align-items: center !important;',
      '  min-width: 0 !important;',
      '  max-width: none !important;',
      '  margin: 0 !important;',
      '}',
      '[data-msa-bottom-nav="1"] > [data-msa-reels-target="1"],',
      '[data-msa-bottom-nav="1"] > *:has(> a[href="/reels/"]),',
      '[data-msa-bottom-nav="1"] > *:has(> a[href="/reels"]) {',
      '  display: none !important;',
      '  flex: 0 0 0 !important;',
      '  width: 0 !important;',
      '  min-width: 0 !important;',
      '  max-width: 0 !important;',
      '  padding: 0 !important;',
      '  margin: 0 !important;',
      '  overflow: hidden !important;',
      '  height: 0 !important;',
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
      var h = (el.getAttribute('href') || '').split('?')[0].split('#')[0].toLowerCase();
      return h;
    }
  }

  function isExactReelsPath(path) {
    return path === '/reels' || path === '/reels/';
  }

  function isDirectPath(path) {
    return path === '/direct' || path.indexOf('/direct/') === 0;
  }

  function markReelsTarget(el) {
    var target = el;
    var parent = el.parentElement;
    if (parent && parent !== document.body && parent.children.length === 1) {
      target = parent;
    }
    target.setAttribute('data-msa-reels-target', '1');
    el.setAttribute('data-msa-reels-target', '1');
    el.setAttribute('aria-hidden', 'true');
    el.setAttribute('tabindex', '-1');
  }

  function clearStaleMarks(root) {
    var old = root.querySelectorAll('[data-msa-reels-target],[data-msa-bottom-nav]');
    for (var i = 0; i < old.length; i++) {
      old[i].removeAttribute('data-msa-reels-target');
      old[i].removeAttribute('data-msa-bottom-nav');
    }
  }

  function findBottomNavHome() {
    var anchors = document.querySelectorAll('a[href]');
    for (var i = 0; i < anchors.length; i++) {
      var a = anchors[i];
      if (!isVisible(a)) continue;
      var r = a.getBoundingClientRect();
      if (r.bottom < window.innerHeight - 110) continue;
      if (r.top < window.innerHeight - 180) continue;
      if (r.width < 36 || r.height < 36) continue;
      var p = pathOf(a);
      if (p === '/' || p === '') {
        // Prefer Home labeled control when several "/" exist.
        var label = (
          a.getAttribute('aria-label') ||
          (a.querySelector('title') && a.querySelector('title').textContent) ||
          ''
        ).toLowerCase();
        if (!label || label.indexOf('home') !== -1) return a;
      }
    }
    return null;
  }

  function findNavContainer(home) {
    if (!home) return null;
    // Walk up until we find a parent that also contains Direct or Explore.
    var el = home.parentElement;
    while (el && el !== document.body) {
      var links = el.querySelectorAll('a[href]');
      var hasExplore = false;
      var hasDirect = false;
      var hasReels = false;
      for (var i = 0; i < links.length; i++) {
        var p = pathOf(links[i]);
        if (p.indexOf('/explore') === 0) hasExplore = true;
        if (isDirectPath(p)) hasDirect = true;
        if (isExactReelsPath(p)) hasReels = true;
      }
      if ((hasExplore || hasDirect) && (hasReels || links.length >= 4)) {
        return el;
      }
      el = el.parentElement;
    }
    return home.parentElement;
  }

  function apply() {
    try {
      ensureStyle();
      clearStaleMarks(document);

      // Mark exact Reels tab anchors (not /reels/audio/..., not /reel/...).
      var anchors = document.querySelectorAll('a[href]');
      for (var i = 0; i < anchors.length; i++) {
        var a = anchors[i];
        var p = pathOf(a);
        if (!isExactReelsPath(p)) continue;
        if (isDirectPath(p)) continue;
        if (!isVisible(a)) continue;
        var r = a.getBoundingClientRect();
        // Bottom tab row only.
        if (r.bottom < window.innerHeight - 120) continue;
        if (r.top < window.innerHeight - 200) continue;
        markReelsTarget(a);
      }

      var home = findBottomNavHome();
      var container = findNavContainer(home);
      if (container) {
        container.setAttribute('data-msa-bottom-nav', '1');
        // Also mark any exact-reels child wrappers inside the nav for flex collapse.
        var navLinks = container.querySelectorAll('a[href]');
        for (var j = 0; j < navLinks.length; j++) {
          if (isExactReelsPath(pathOf(navLinks[j]))) {
            markReelsTarget(navLinks[j]);
          }
        }
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
        attributeFilter: ['href', 'class', 'style']
      });
    } catch (e) {}
  }

  if (document.documentElement) start();
  else document.addEventListener('DOMContentLoaded', start);

  window.addEventListener('resize', schedule);
  window.addEventListener('popstate', schedule);
  document.addEventListener('visibilitychange', schedule);
  setInterval(apply, 1000);
})();
"""#
}
