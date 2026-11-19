import Foundation

/// MSA-22: blank Instagram Explore / Search landing grid (supersedes MSA-19 reels-only hide).
/// Keeps the search bar; restores content when the user is actively searching.
/// Still injected alongside MSA-16 bottom-nav and MSA-18 feed-ad hide.
enum InstagramSearchReelsHide {
    /// Injected at document start alongside other Instagram user scripts.
    static let searchReelsHideUserScriptSource: String = #"""
(function () {
  if (window.__msaExploreBlankInstalled) return;
  window.__msaExploreBlankInstalled = true;
  // Back-compat probe flag used by feed dump / older scripts.
  window.__msaExploreReelsInstalled = true;

  var STYLE_ID = 'msa-blank-explore-style';
  var ATTR_TILE = 'data-msa-explore-blank-tile';
  var ATTR_GRID = 'data-msa-explore-blank-grid';
  var ATTR_SECTION = 'data-msa-explore-blank-section';
  var enabled = true;

  window.__msaExploreBlank = {
    setEnabled: function (on) {
      enabled = !!on;
      if (!enabled) {
        restoreAll();
      } else {
        applyBlank();
      }
      return enabled;
    },
    isEnabled: function () { return enabled; }
  };

  function ensureStyle() {
    var style = document.getElementById(STYLE_ID);
    if (!style) {
      style = document.createElement('style');
      style.id = STYLE_ID;
      (document.head || document.documentElement).appendChild(style);
    }
    style.textContent = [
      '[' + ATTR_TILE + '="1"],',
      '[' + ATTR_GRID + '="1"],',
      '[' + ATTR_SECTION + '="1"] {',
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
      '  position: absolute !important;',
      '  left: -9999px !important;',
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
    if (path === '/reels' || path === '/reels/') return false;
    if (path.indexOf('/reel/') === 0) return true;
    if (path.indexOf('/reels/') === 0 && path.indexOf('/reels/audio') !== 0) {
      var rest = path.slice('/reels/'.length).replace(/\/$/, '');
      if (rest && rest.indexOf('/') === -1 && rest !== 'audio') return true;
    }
    return false;
  }

  function searchInputs() {
    return document.querySelectorAll(
      'input[placeholder*="Search" i], input[aria-label*="Search" i], input[type="search"], input[name="search"]'
    );
  }

  function inputValue(el) {
    try {
      var v = (el.value != null ? String(el.value) : '') || '';
      if (!v && el.getAttribute) v = el.getAttribute('value') || '';
      return v.replace(/\s+/g, ' ').trim();
    } catch (e) {
      return '';
    }
  }

  /** True when the user typed a query or IG search-results UI is active. */
  function isActivelySearching() {
    var path = (location.pathname || '').toLowerCase();
    if (path.indexOf('/explore/search') === 0) return true;
    if (/[?&]q=/.test(location.search || '')) return true;

    var inputs = searchInputs();
    for (var i = 0; i < inputs.length; i++) {
      if (inputValue(inputs[i]).length > 0) return true;
    }

    // Search results / suggestions panel with a non-empty query field inside.
    var panels = document.querySelectorAll('[role="dialog"], [aria-modal="true"]');
    for (var p = 0; p < panels.length; p++) {
      var panel = panels[p];
      var pin = panel.querySelectorAll('input');
      for (var j = 0; j < pin.length; j++) {
        if (inputValue(pin[j]).length > 0) return true;
      }
    }
    return false;
  }

  function isExploreLanding() {
    var path = (location.pathname || '').toLowerCase();
    if (path.indexOf('/explore') !== 0) return false;
    if (isActivelySearching()) return false;
    return true;
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

  function countMediaLinks(el) {
    if (!el || !el.querySelectorAll) return 0;
    return el.querySelectorAll('a[href*="/p/"], a[href*="/reel/"]').length;
  }

  function isSearchChrome(el) {
    if (!el || !el.querySelector) return false;
    if (el.querySelector('input[placeholder*="Search" i], input[aria-label*="Search" i], input[type="search"]')) {
      return true;
    }
    // Bottom nav / primary site header — never blank those.
    try {
      var r = el.getBoundingClientRect();
      if (r.bottom > window.innerHeight - 110 && r.top > window.innerHeight - 220) return true;
      if (r.top < 90 && r.height < 120 && r.width > window.innerWidth * 0.6) return true;
    } catch (e) {}
    return false;
  }

  // Prefer the smallest single-post cell — never a multi-tile row/grid parent.
  function findTileFrom(el) {
    var node = el;
    var best = null;
    var depth = 0;
    while (node && node !== document.body && depth < 10) {
      if (node.getAttribute && node.getAttribute(ATTR_TILE) === '1') return node;
      var tag = (node.tagName || '').toLowerCase();
      if (tag === 'article' && countMediaLinks(node) <= 1) return node;
      try {
        var r = node.getBoundingClientRect();
        var links = countMediaLinks(node);
        if (
          links <= 1 &&
          r.width >= 72 &&
          r.height >= 72 &&
          r.width < window.innerWidth * 0.55
        ) {
          var ratio = r.width / Math.max(r.height, 1);
          if (ratio > 0.45 && ratio < 1.95) best = node;
        }
      } catch (e) {}
      var parent = node.parentElement;
      if (parent && parent.children && parent.children.length >= 2) {
        var mediaKids = 0;
        for (var i = 0; i < Math.min(parent.children.length, 12); i++) {
          var sr = parent.children[i].getBoundingClientRect();
          if (sr.width >= 72 && sr.height >= 72) mediaKids++;
        }
        if (mediaKids >= 2 && countMediaLinks(node) <= 1) return node;
      }
      node = parent;
      depth++;
    }
    return best || el;
  }

  function hideNode(node, attr) {
    if (!node || node.nodeType !== 1) return;
    if (isSearchChrome(node)) return;
    if (node.getAttribute(attr) === '1') return;
    node.setAttribute(attr, '1');
    try {
      node.style.setProperty('display', 'none', 'important');
      node.style.setProperty('pointer-events', 'none', 'important');
      node.style.setProperty('height', '0', 'important');
      node.style.setProperty('width', '0', 'important');
      node.style.setProperty('margin', '0', 'important');
      node.style.setProperty('padding', '0', 'important');
      node.style.setProperty('overflow', 'hidden', 'important');
      node.style.setProperty('opacity', '0', 'important');
    } catch (e) {}
  }

  function clearAttr(attr) {
    var nodes = document.querySelectorAll('[' + attr + '="1"]');
    for (var i = 0; i < nodes.length; i++) {
      var n = nodes[i];
      n.removeAttribute(attr);
      try {
        n.style.removeProperty('display');
        n.style.removeProperty('pointer-events');
        n.style.removeProperty('height');
        n.style.removeProperty('width');
        n.style.removeProperty('margin');
        n.style.removeProperty('padding');
        n.style.removeProperty('overflow');
        n.style.removeProperty('opacity');
        n.style.removeProperty('visibility');
        n.style.removeProperty('position');
        n.style.removeProperty('left');
        n.style.removeProperty('min-height');
        n.style.removeProperty('max-height');
        n.style.removeProperty('flex');
      } catch (e) {}
    }
  }

  function restoreAll() {
    clearAttr(ATTR_TILE);
    clearAttr(ATTR_GRID);
    clearAttr(ATTR_SECTION);
  }

  function findExploreGridRoot() {
    var anchors = document.querySelectorAll('a[href*="/p/"], a[href*="/reel/"]');
    var best = null;
    var bestScore = 0;
    for (var i = 0; i < anchors.length; i++) {
      var a = anchors[i];
      var node = a.parentElement;
      var depth = 0;
      while (node && node !== document.body && depth < 8) {
        if (isSearchChrome(node)) {
          node = node.parentElement;
          depth++;
          continue;
        }
        var kids = node.children ? node.children.length : 0;
        if (kids >= 3) {
          var mediaKids = 0;
          for (var k = 0; k < Math.min(kids, 36); k++) {
            var child = node.children[k];
            if (child.getAttribute && child.getAttribute(ATTR_TILE) === '1') {
              mediaKids++;
              continue;
            }
            var r = child.getBoundingClientRect();
            if (r.width >= 60 && r.height >= 60) mediaKids++;
            else if (child.querySelector && child.querySelector('a[href*="/p/"], a[href*="/reel/"]')) mediaKids++;
          }
          if (mediaKids > bestScore) {
            bestScore = mediaKids;
            best = node;
          }
        }
        node = node.parentElement;
        depth++;
      }
    }
    return bestScore >= 2 ? best : null;
  }

  function blankGridRoot() {
    var root = findExploreGridRoot();
    if (!root) return;
    // Prefer hiding a parent that owns the whole mosaic, not the search header.
    var wrap = root;
    for (var d = 0; d < 4 && wrap.parentElement; d++) {
      var parent = wrap.parentElement;
      if (isSearchChrome(parent)) break;
      var pr = parent.getBoundingClientRect();
      var rr = wrap.getBoundingClientRect();
      // Climb while parent is still mainly the grid content area.
      if (pr.top < 70) break;
      if (pr.height > rr.height * 1.35 && parent.querySelector &&
          parent.querySelector('input[placeholder*="Search" i], input[aria-label*="Search" i]')) {
        break;
      }
      if (countMediaLinks(parent) >= countMediaLinks(wrap)) {
        wrap = parent;
      } else {
        break;
      }
    }
    hideNode(wrap, ATTR_GRID);
  }

  function blankAllTiles() {
    var anchors = document.querySelectorAll('a[href*="/p/"], a[href*="/reel/"]');
    for (var i = 0; i < anchors.length; i++) {
      var a = anchors[i];
      var p = pathOf(a);
      if (p === '/reels' || p === '/reels/') continue;
      if (!(p.indexOf('/p/') === 0 || isReelPath(p) || p.indexOf('/reel/') === 0)) continue;
      var tile = findTileFrom(a);
      if (!tile || isSearchChrome(tile)) continue;
      try {
        var tr = tile.getBoundingClientRect();
        // Skip full-screen post viewers if any.
        if (tr.width > window.innerWidth * 0.85 && tr.height > window.innerHeight * 0.55) continue;
      } catch (e) {}
      hideNode(tile, ATTR_TILE);
    }
  }

  function blankSuggestedSections() {
    var nodes = document.querySelectorAll('h1, h2, h3, h4, span, div, a, button');
    for (var i = 0; i < nodes.length; i++) {
      var el = nodes[i];
      if (el.getAttribute(ATTR_SECTION) === '1') continue;
      var raw = (el.textContent || '').replace(/\s+/g, ' ').trim();
      if (!raw || raw.length > 48) continue;
      if (!/^(reels|clips|reels for you|suggested for you|for you|popular|accounts|places|tags|audio)$/i.test(raw)) {
        continue;
      }
      var r = el.getBoundingClientRect();
      if (r.width < 20 || r.height < 10 || r.height > 100) continue;
      if (r.bottom > window.innerHeight - 100) continue; // bottom nav
      var wrap = el;
      for (var d = 0; d < 6 && wrap.parentElement; d++) {
        wrap = wrap.parentElement;
        if (wrap.querySelector && wrap.querySelector('a[href*="/reel/"], a[href*="/p/"], img, video')) break;
      }
      if (isSearchChrome(wrap)) continue;
      hideNode(wrap, ATTR_SECTION);
    }
  }

  /** Hide stuck IG loading rings so a blank Explore does not look broken. */
  function blankLoadingChrome() {
    var nodes = document.querySelectorAll(
      '[role="progressbar"], [aria-label*="Loading" i], svg[aria-label*="Loading" i]'
    );
    for (var i = 0; i < nodes.length; i++) {
      var el = nodes[i];
      if (isSearchChrome(el)) continue;
      try {
        var r = el.getBoundingClientRect();
        if (r.width < 8 || r.height < 8) continue;
        if (r.bottom > window.innerHeight - 90) continue;
        // Centered/mid content spinners only.
        if (r.top < 70) continue;
      } catch (e) { continue; }
      hideNode(el, ATTR_SECTION);
    }
    // Circular animated SVGs commonly used as IG spinners (no accessible name).
    var svgs = document.querySelectorAll('svg');
    for (var s = 0; s < svgs.length; s++) {
      var svg = svgs[s];
      if (svg.getAttribute(ATTR_SECTION) === '1') continue;
      if (isSearchChrome(svg)) continue;
      try {
        var sr = svg.getBoundingClientRect();
        if (sr.width < 24 || sr.width > 72 || sr.height < 24 || sr.height > 72) continue;
        if (sr.top < 90 || sr.top > window.innerHeight * 0.55) continue;
        if (Math.abs((sr.left + sr.width / 2) - window.innerWidth / 2) > 80) continue;
        var circle = svg.querySelector('circle');
        if (!circle) continue;
        hideNode(svg, ATTR_SECTION);
      } catch (e2) {}
    }
  }

  function dismissExploreNags() {
    try {
      var nodes = document.querySelectorAll('button, [role="button"], a, div');
      for (var i = 0; i < nodes.length; i++) {
        var el = nodes[i];
        var t = ((el.textContent || '') + ' ' + (el.getAttribute('aria-label') || ''))
          .replace(/\s+/g, ' ')
          .trim()
          .toLowerCase();
        if (t === 'use the app' || t.indexOf('use the app') === 0) {
          var wrap = el.parentElement;
          for (var d = 0; d < 5 && wrap; d++) {
            var closer = wrap.querySelector('[aria-label*="Close" i], [aria-label*="Dismiss" i]');
            if (closer) {
              closer.click();
              return;
            }
            wrap = wrap.parentElement;
          }
        }
        if (t === 'ok' || t === 'not now') {
          var r = el.getBoundingClientRect();
          if (r.width > 40 && r.height > 24 && r.top > 80) {
            el.click();
            return;
          }
        }
      }
    } catch (e) {}
  }

  function applyBlank() {
    try {
      ensureStyle();
      if (!enabled) {
        restoreAll();
        return;
      }
      if (!isExploreLanding()) {
        // Searching or left Explore — restore so results / other pages show normally.
        restoreAll();
        return;
      }

      dismissExploreNags();
      blankGridRoot();
      blankAllTiles();
      blankSuggestedSections();
      blankLoadingChrome();
    } catch (err) {
      // Keep browsing if IG DOM shifts.
    }
  }

  window.__msaDumpExploreReels = function () {
    var tiles = [];
    var hiddenTiles = [];
    var visibleTiles = [];
    var anchors = document.querySelectorAll('a[href]');
    for (var i = 0; i < Math.min(anchors.length, 500); i++) {
      var a = anchors[i];
      var p = pathOf(a);
      if (!(isReelPath(p) || /\/p\//.test(p) || /\/reel\//.test(p))) continue;
      var r = a.getBoundingClientRect();
      var hidden = !!(
        a.closest && (
          a.closest('[' + ATTR_TILE + '="1"]') ||
          a.closest('[' + ATTR_GRID + '="1"]') ||
          a.closest('[' + ATTR_SECTION + '="1"]')
        )
      );
      var entry = {
        href: p,
        reel: isReelPath(p),
        hidden: hidden,
        hrefRaw: (a.getAttribute('href') || '').slice(0, 120),
        label: (a.getAttribute('aria-label') || '').slice(0, 80),
        badge: textBlob(a).slice(0, 80),
        w: Math.round(r.width),
        h: Math.round(r.height),
        y: Math.round(r.top)
      };
      if (hidden) hiddenTiles.push(entry);
      else if (r.width >= 4 && r.height >= 4) visibleTiles.push(entry);
      if (r.width >= 4 && r.height >= 4) tiles.push(entry);
    }
    var bottomNav = [];
    var allA = document.querySelectorAll('a[href]');
    for (var j = 0; j < allA.length; j++) {
      var b = allA[j];
      var br = b.getBoundingClientRect();
      if (br.bottom < window.innerHeight - 120) continue;
      if (br.top < window.innerHeight - 200) continue;
      if (br.width < 20 || br.height < 20) continue;
      bottomNav.push({
        href: pathOf(b),
        hrefRaw: (b.getAttribute('href') || '').slice(0, 120),
        label: ((b.getAttribute('aria-label') || '') + ' ' + textBlob(b)).replace(/\s+/g, ' ').trim().slice(0, 60),
        x: Math.round(br.left)
      });
    }
    var searchCount = 0;
    var searchVals = [];
    var sins = searchInputs();
    for (var s = 0; s < sins.length; s++) {
      searchCount++;
      searchVals.push(inputValue(sins[s]).slice(0, 40));
    }
    return JSON.stringify({
      mode: 'explore-blank-v1',
      path: location.pathname,
      exploreLanding: isExploreLanding(),
      activelySearching: isActivelySearching(),
      enabled: enabled,
      searchInputCount: searchCount,
      searchValues: searchVals,
      hiddenCount:
        document.querySelectorAll('[' + ATTR_TILE + '="1"]').length +
        document.querySelectorAll('[' + ATTR_GRID + '="1"]').length +
        document.querySelectorAll('[' + ATTR_SECTION + '="1"]').length,
      tileHidden: document.querySelectorAll('[' + ATTR_TILE + '="1"]').length,
      gridHidden: document.querySelectorAll('[' + ATTR_GRID + '="1"]').length,
      sectionHidden: document.querySelectorAll('[' + ATTR_SECTION + '="1"]').length,
      visibleMediaTiles: visibleTiles.length,
      bottomNav: bottomNav,
      hiddenTiles: hiddenTiles.slice(0, 40),
      visibleTiles: visibleTiles.slice(0, 40),
      tiles: tiles.slice(0, 80)
    });
  };

  var scheduled = null;
  function schedule() {
    if (window.__msaScrollBurst) return;
    if (scheduled) return;
    scheduled = setTimeout(function () {
      scheduled = null;
      if (window.__msaScrollBurst) return;
      applyBlank();
    }, 180);
  }

  var mo = new MutationObserver(schedule);
  function start() {
    ensureStyle();
    applyBlank();
    var opts = {
      childList: true,
      subtree: true,
      attributes: true,
      attributeFilter: ['href', 'class', 'style', 'aria-label', 'value']
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
  window.addEventListener('hashchange', schedule);
  document.addEventListener('visibilitychange', schedule);
  document.addEventListener('input', schedule, true);
  document.addEventListener('keyup', schedule, true);
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
  setInterval(function () {
    if (!window.__msaScrollBurst) applyBlank();
  }, 1200);
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
