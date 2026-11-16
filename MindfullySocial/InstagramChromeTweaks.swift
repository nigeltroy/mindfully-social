import Foundation

/// Injected CSS/JS that hides Instagram’s Reels bottom-nav tab and
/// redistributes the remaining icons evenly. Re-applies after SPA updates.
enum InstagramChromeTweaks {
    static let userScriptSource: String = #"""
(function () {
  if (window.__msaReelsInstalled) return;
  window.__msaReelsInstalled = true;

  var STYLE_ID = 'msa-hide-reels-style';

  function ensureStyle() {
    if (document.getElementById(STYLE_ID)) return;
    var style = document.createElement('style');
    style.id = STYLE_ID;
    style.textContent = [
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
      '  border: 0 !important;',
      '}',
      '[data-msa-bottom-nav="1"] {',
      '  display: flex !important;',
      '  justify-content: space-evenly !important;',
      '  align-items: center !important;',
      '  width: 100% !important;',
      '}',
      '[data-msa-bottom-nav="1"] > *:not([data-msa-reels-target="1"]) {',
      '  flex: 1 1 0 !important;',
      '  display: flex !important;',
      '  justify-content: center !important;',
      '  align-items: center !important;',
      '  min-width: 0 !important;',
      '}'
    ].join('\n');
    (document.head || document.documentElement).appendChild(style);
  }

  function isVisible(el) {
    var r = el.getBoundingClientRect();
    return r.width >= 8 && r.height >= 8 && r.bottom > 0 && r.top < window.innerHeight;
  }

  function isBottomNavCandidate(el) {
    if (!isVisible(el)) return false;
    var r = el.getBoundingClientRect();
    return r.bottom >= window.innerHeight - 110 && r.top >= window.innerHeight - 160;
  }

  function isReelsAnchor(a) {
    var href = (a.getAttribute('href') || '').toLowerCase();
    if (href.indexOf('/reels') !== -1) return true;
    var label = (
      a.getAttribute('aria-label') ||
      a.getAttribute('title') ||
      ''
    ).toLowerCase();
    if (label === 'reels' || label.indexOf('reel') !== -1) return true;
    return false;
  }

  function markReelsTarget(a) {
    var target = a;
    var parent = a.parentElement;
    // Prefer the flex child wrapper when it only wraps this link.
    if (parent && parent !== document.body && parent.children.length === 1) {
      target = parent;
    }
    target.setAttribute('data-msa-reels-target', '1');
    a.setAttribute('data-msa-reels-target', '1');
    a.setAttribute('aria-hidden', 'true');
    a.setAttribute('tabindex', '-1');
  }

  function clearStaleMarks(root) {
    var old = root.querySelectorAll('[data-msa-reels-target],[data-msa-bottom-nav]');
    for (var i = 0; i < old.length; i++) {
      old[i].removeAttribute('data-msa-reels-target');
      old[i].removeAttribute('data-msa-bottom-nav');
    }
  }

  function sharedParent(nodes) {
    if (!nodes.length) return null;
    var ancestor = nodes[0].parentElement;
    while (ancestor && ancestor !== document.body && ancestor !== document.documentElement) {
      var ok = true;
      for (var i = 0; i < nodes.length; i++) {
        if (!ancestor.contains(nodes[i])) {
          ok = false;
          break;
        }
      }
      if (ok) {
        // Prefer the closest parent that directly contains all (or wrappers).
        var direct = true;
        for (var j = 0; j < nodes.length; j++) {
          var n = nodes[j];
          var p = n.parentElement;
          if (!(p === ancestor || (p && p.parentElement === ancestor))) {
            // still accept ancestor; keep walking up only if needed
          }
        }
        return ancestor;
      }
      ancestor = ancestor.parentElement;
    }
    return null;
  }

  function pickFlexContainer(links) {
    if (!links.length) return null;
    // Same immediate parent → that is the row.
    var sameParent = true;
    var p0 = links[0].parentElement;
    for (var i = 1; i < links.length; i++) {
      if (links[i].parentElement !== p0) {
        sameParent = false;
        break;
      }
    }
    if (sameParent && p0) return p0;

    // Wrappers share a parent.
    var wrappers = [];
    for (var k = 0; k < links.length; k++) {
      var a = links[k];
      wrappers.push(a.parentElement && a.parentElement.children.length === 1 ? a.parentElement : a);
    }
    var wp0 = wrappers[0] && wrappers[0].parentElement;
    var sameWrapParent = !!wp0;
    for (var m = 1; m < wrappers.length; m++) {
      if (!wrappers[m] || wrappers[m].parentElement !== wp0) {
        sameWrapParent = false;
        break;
      }
    }
    if (sameWrapParent) return wp0;

    return sharedParent(links);
  }

  function apply() {
    try {
      ensureStyle();
      var anchors = Array.prototype.slice.call(document.querySelectorAll('a[href]'));
      var bottom = anchors.filter(isBottomNavCandidate);
      if (bottom.length < 3) {
        // Fallback: any /reels link near the bottom third of the page.
        bottom = anchors.filter(function (a) {
          if (!isVisible(a)) return false;
          var r = a.getBoundingClientRect();
          return r.top > window.innerHeight * 0.7;
        });
      }
      if (bottom.length < 3) return;

      clearStaleMarks(document);

      for (var i = 0; i < bottom.length; i++) {
        if (isReelsAnchor(bottom[i])) {
          markReelsTarget(bottom[i]);
        }
      }

      var container = pickFlexContainer(bottom);
      if (container) {
        container.setAttribute('data-msa-bottom-nav', '1');
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
    }, 60);
  }

  var mo = new MutationObserver(schedule);
  function start() {
    ensureStyle();
    apply();
    try {
      mo.observe(document.documentElement, { childList: true, subtree: true });
    } catch (e) {}
  }

  if (document.documentElement) start();
  else document.addEventListener('DOMContentLoaded', start);

  window.addEventListener('resize', schedule);
  window.addEventListener('popstate', schedule);
  document.addEventListener('visibilitychange', schedule);
})();
"""#
}
