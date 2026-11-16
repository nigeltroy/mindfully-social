import Foundation

/// MSA-19: hide Reels tiles on Instagram Search / Explore inside WKWebView.
/// Separate from `InstagramChromeTweaks` (MSA-16 bottom-nav) and MSA-18 feed-ad hide.
enum InstagramSearchReelsHide {
    /// Injected at document start alongside other Instagram user scripts.
    static let searchReelsHideUserScriptSource: String = #"""
(function () {
  if (window.__msaExploreReelsInstalled) return;
  window.__msaExploreReelsInstalled = true;

  var STYLE_ID = 'msa-hide-explore-reels-style';
  var ATTR = 'data-msa-explore-reel';
  var ATTR_SECTION = 'data-msa-explore-reel-section';

  function ensureStyle() {
    var style = document.getElementById(STYLE_ID);
    if (!style) {
      style = document.createElement('style');
      style.id = STYLE_ID;
      (document.head || document.documentElement).appendChild(style);
    }
    style.textContent = [
      '[' + ATTR + '="1"] {',
      '  display: none !important;',
      '  visibility: hidden !important;',
      '  pointer-events: none !important;',
      '  width: 0 !important;',
      '  min-width: 0 !important;',
      '  max-width: 0 !important;',
      '  height: 0 !important;',
      '  min-height: 0 !important;',
      '  max-height: 0 !important;',
      '  margin: 0 !important;',
      '  padding: 0 !important;',
      '  overflow: hidden !important;',
      '  opacity: 0 !important;',
      '  border: 0 !important;',
      '  flex: 0 0 0 !important;',
      '  grid-column: unset !important;',
      '  grid-row: unset !important;',
      '}',
      '[' + ATTR_SECTION + '="1"] {',
      '  display: none !important;',
      '  pointer-events: none !important;',
      '  height: 0 !important;',
      '  overflow: hidden !important;',
      '  margin: 0 !important;',
      '  padding: 0 !important;',
      '}'
    ].join('\n');
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

  function isReelPath(path) {
    if (!path) return false;
    // Individual reel watch pages — not the /reels bottom-nav tab (MSA-16).
    if (path === '/reels' || path === '/reels/') return false;
    if (path.indexOf('/reel/') === 0) return true;
    if (path.indexOf('/reels/') === 0 && path.indexOf('/reels/audio') !== 0) {
      var rest = path.slice('/reels/'.length).replace(/\/$/, '');
      if (rest && rest.indexOf('/') === -1 && rest !== 'audio') return true;
    }
    return false;
  }

  function isExploreOrSearchContext() {
    var path = (location.pathname || '').toLowerCase();
    if (path.indexOf('/explore') === 0) return true;
    if (document.querySelector('input[placeholder*="Search" i], input[aria-label*="Search" i], input[type="search"]')) {
      if (document.querySelector('a[href*="/reel/"], a[href*="/p/"]')) {
        var active = document.activeElement;
        if (active && active.tagName === 'INPUT') return true;
        var searchPanel = document.querySelector('[role="dialog"], [aria-modal="true"]');
        if (searchPanel && searchPanel.querySelector('a[href*="/reel/"], a[href*="/p/"]')) return true;
      }
    }
    return false;
  }

  function textBlob(el) {
    try {
      var parts = [];
      if (el.getAttribute) {
        parts.push(el.getAttribute('aria-label') || '');
        parts.push(el.getAttribute('alt') || '');
        parts.push(el.getAttribute('title') || '');
      }
      var t = el.querySelector && el.querySelector('title');
      if (t && t.textContent) parts.push(t.textContent);
      return parts.join(' ').toLowerCase();
    } catch (e) {
      return '';
    }
  }

  function hasClapperOrReelBadge(root) {
    if (!root || !root.querySelectorAll) return false;
    var blob = textBlob(root);
    if (/\breels?\b|\bclips?\b|\bclapper/.test(blob)) return true;
    var labeled = root.querySelectorAll('[aria-label], [alt], title, svg, img');
    for (var i = 0; i < labeled.length; i++) {
      var b = textBlob(labeled[i]);
      if (/\breels?\b|\bclips?\b|\bclapper/.test(b)) return true;
    }
    return false;
  }

  function findTileFrom(el) {
    var node = el;
    var best = null;
    var depth = 0;
    while (node && node !== document.body && depth < 12) {
      if (node.getAttribute && node.getAttribute(ATTR) === '1') return node;
      var tag = (node.tagName || '').toLowerCase();
      if (tag === 'article') return node;
      try {
        var r = node.getBoundingClientRect();
        if (r.width >= 72 && r.height >= 72 && r.width < window.innerWidth * 0.55) {
          var ratio = r.width / Math.max(r.height, 1);
          if (ratio > 0.55 && ratio < 1.85) best = node;
        }
      } catch (e) {}
      var parent = node.parentElement;
      if (parent && parent.children && parent.children.length >= 3) {
        var siblings = parent.children;
        var mediaKids = 0;
        for (var i = 0; i < Math.min(siblings.length, 12); i++) {
          var sr = siblings[i].getBoundingClientRect();
          if (sr.width >= 72 && sr.height >= 72) mediaKids++;
        }
        if (mediaKids >= 3) return node;
      }
      node = parent;
      depth++;
    }
    return best || el;
  }

  function hideTile(tile) {
    if (!tile || tile.nodeType !== 1) return;
    if (tile.getAttribute(ATTR) === '1') return;
    tile.setAttribute(ATTR, '1');
    try {
      tile.style.setProperty('display', 'none', 'important');
      tile.style.setProperty('pointer-events', 'none', 'important');
    } catch (e) {}
  }

  function hideReelSections() {
    var nodes = document.querySelectorAll('h1, h2, h3, h4, span, div, a');
    for (var i = 0; i < nodes.length; i++) {
      var el = nodes[i];
      if (el.getAttribute(ATTR_SECTION) === '1') continue;
      var raw = (el.textContent || '').replace(/\s+/g, ' ').trim();
      if (!raw) continue;
      if (!/^(reels|clips)$/i.test(raw) && !/^reels for you$/i.test(raw)) continue;
      var r = el.getBoundingClientRect();
      if (r.width < 20 || r.height < 10 || r.height > 80) continue;
      var wrap = el;
      for (var d = 0; d < 6 && wrap.parentElement; d++) {
        wrap = wrap.parentElement;
        if (wrap.querySelector && wrap.querySelector('a[href*="/reel/"]')) break;
      }
      if (!wrap.querySelector || !wrap.querySelector('a[href*="/reel/"]')) continue;
      wrap.setAttribute(ATTR_SECTION, '1');
      try {
        wrap.style.setProperty('display', 'none', 'important');
      } catch (e) {}
    }
  }

  function hideReelFilterChips() {
    var chips = document.querySelectorAll('a, button, [role="tab"], [role="button"]');
    for (var i = 0; i < chips.length; i++) {
      var el = chips[i];
      var label = (
        (el.getAttribute('aria-label') || '') + ' ' + (el.textContent || '')
      ).replace(/\s+/g, ' ').trim().toLowerCase();
      if (label !== 'reels' && label !== 'clips') continue;
      var r = el.getBoundingClientRect();
      if (r.height < 20 || r.height > 64) continue;
      if (r.width < 28 || r.width > 160) continue;
      // Mid-page chips only — bottom-nav /reels owned by MSA-16.
      if (r.bottom > window.innerHeight - 100) continue;
      el.setAttribute(ATTR_SECTION, '1');
      try {
        el.style.setProperty('display', 'none', 'important');
      } catch (e) {}
    }
  }

  function applyExplore() {
    try {
      ensureStyle();
      if (!isExploreOrSearchContext()) return;

      hideReelSections();
      hideReelFilterChips();

      var anchors = document.querySelectorAll('a[href]');
      for (var i = 0; i < anchors.length; i++) {
        var a = anchors[i];
        var p = pathOf(a);
        var reelHref = isReelPath(p);
        var reelBadge = !reelHref && hasClapperOrReelBadge(a);
        if (!reelHref && !reelBadge) continue;
        if (p === '/reels' || p === '/reels/') continue;

        var tile = findTileFrom(a);
        try {
          var tr = tile.getBoundingClientRect();
          if (tr.width > window.innerWidth * 0.7 && tr.height > window.innerHeight * 0.5) {
            continue;
          }
        } catch (e) {}
        hideTile(tile);
      }

      var media = document.querySelectorAll('article, a[href*="/p/"], a[href*="/reel/"]');
      for (var j = 0; j < media.length; j++) {
        var m = media[j];
        if (m.getAttribute && m.getAttribute(ATTR) === '1') continue;
        if (!hasClapperOrReelBadge(m)) continue;
        var innerReel = m.querySelector && m.querySelector('a[href*="/reel/"]');
        var labelHit = /\breels?\b|\bclips?\b/.test(textBlob(m));
        if (!innerReel && !labelHit) continue;
        hideTile(findTileFrom(innerReel || m));
      }

      try {
        var grids = document.querySelectorAll('[style*="grid"], main, [role="main"]');
        for (var g = 0; g < grids.length; g++) {
          var grid = grids[g];
          if (!grid.querySelector('[' + ATTR + '="1"]')) continue;
          grid.style.setProperty('grid-auto-flow', 'dense');
        }
      } catch (e3) {}
    } catch (err) {
      // Keep browsing if IG DOM shifts.
    }
  }

  window.__msaDumpExploreReels = function () {
    var tiles = [];
    var anchors = document.querySelectorAll('a[href]');
    for (var i = 0; i < Math.min(anchors.length, 400); i++) {
      var a = anchors[i];
      var p = pathOf(a);
      if (!(isReelPath(p) || /\/p\//.test(p) || /\/reel\//.test(p))) continue;
      var r = a.getBoundingClientRect();
      if (r.width < 4 && r.height < 4) continue;
      tiles.push({
        href: p,
        reel: isReelPath(p),
        hidden: !!(a.closest && a.closest('[' + ATTR + '="1"]')),
        label: (a.getAttribute('aria-label') || '').slice(0, 80),
        w: Math.round(r.width),
        h: Math.round(r.height),
        y: Math.round(r.top)
      });
    }
    return JSON.stringify({
      path: location.pathname,
      exploreContext: isExploreOrSearchContext(),
      hiddenCount: document.querySelectorAll('[' + ATTR + '="1"]').length,
      sectionHidden: document.querySelectorAll('[' + ATTR_SECTION + '="1"]').length,
      tiles: tiles.slice(0, 80)
    });
  };

  var scheduled = null;
  function schedule() {
    if (scheduled) return;
    scheduled = setTimeout(function () {
      scheduled = null;
      applyExplore();
    }, 60);
  }

  var mo = new MutationObserver(schedule);
  function start() {
    ensureStyle();
    applyExplore();
    try {
      mo.observe(document.documentElement, {
        childList: true,
        subtree: true,
        attributes: true,
        attributeFilter: ['href', 'class', 'style', 'aria-label']
      });
    } catch (e) {}
  }

  if (document.documentElement) start();
  else document.addEventListener('DOMContentLoaded', start);

  window.addEventListener('resize', schedule);
  window.addEventListener('popstate', schedule);
  window.addEventListener('hashchange', schedule);
  document.addEventListener('visibilitychange', schedule);
  try {
    var _push = history.pushState;
    history.pushState = function () {
      var ret = _push.apply(this, arguments);
      schedule();
      return ret;
    };
    var _replace = history.replaceState;
    history.replaceState = function () {
      var ret = _replace.apply(this, arguments);
      schedule();
      return ret;
    };
  } catch (e) {}
  setInterval(applyExplore, 700);
})();
"""#

    /// Evaluated from Swift during Tart hardening to capture explore/search tile signatures.
    static let dumpExploreScript: String = #"""
(function () {
  try {
    if (typeof window.__msaDumpExploreReels === 'function') {
      return window.__msaDumpExploreReels();
    }
    return JSON.stringify({ error: 'dump_fn_missing', path: location.pathname });
  } catch (e) {
    return JSON.stringify({ error: String(e) });
  }
})()
"""#
}
