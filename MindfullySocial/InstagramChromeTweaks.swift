import Foundation

/// Injected CSS/JS that hides Instagram’s Reels bottom-nav tab and
/// redistributes the remaining icons evenly. Re-applies after SPA updates.
///
/// Critical: hide **Reels only**. Never hide Direct/Messages (`/direct`).
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

  function isInBottomStrip(el) {
    if (!isVisible(el)) return false;
    var r = el.getBoundingClientRect();
    // Bottom tab bar sits in the lower ~120px (above home indicator).
    return r.bottom >= window.innerHeight - 120 && r.top >= window.innerHeight - 180;
  }

  function pathOf(el) {
    try {
      var href = el.getAttribute('href') || '';
      if (!href && el.href) href = String(el.href);
      if (!href) return '';
      // Absolute or relative.
      var u = href;
      try {
        u = new URL(href, location.origin).pathname || '';
      } catch (e) {
        u = href.split('?')[0].split('#')[0];
      }
      return String(u).toLowerCase();
    } catch (e) {
      return '';
    }
  }

  function accessibleName(el) {
    var parts = [];
    var attrs = ['aria-label', 'title', 'alt'];
    for (var i = 0; i < attrs.length; i++) {
      var v = el.getAttribute(attrs[i]);
      if (v) parts.push(v);
    }
    // Child titles / aria-labels (SVG <title>, nested icons).
    var labeled = el.querySelectorAll('[aria-label], title, [title], img[alt]');
    for (var j = 0; j < labeled.length; j++) {
      var n = labeled[j];
      var t =
        n.getAttribute('aria-label') ||
        n.getAttribute('title') ||
        n.getAttribute('alt') ||
        (n.tagName === 'TITLE' ? (n.textContent || '') : '');
      if (t) parts.push(t);
    }
    return parts.join(' ').toLowerCase().replace(/\s+/g, ' ').trim();
  }

  function isDirectOrMessages(el) {
    var p = pathOf(el);
    if (p.indexOf('/direct') === 0 || p.indexOf('/direct/') !== -1) return true;
    var name = accessibleName(el);
    if (!name) return false;
    // Keep Messenger / Direct / Messages always.
    if (
      name === 'direct' ||
      name === 'messages' ||
      name === 'messaging' ||
      name.indexOf('direct') !== -1 ||
      name.indexOf('message') !== -1 ||
      name.indexOf('messenger') !== -1 ||
      name.indexOf('inbox') !== -1
    ) {
      return true;
    }
    return false;
  }

  function isHomeTab(el) {
    var p = pathOf(el);
    return p === '/' || p === '';
  }

  function isSearchOrExplore(el) {
    var p = pathOf(el);
    if (p.indexOf('/explore') === 0 || p.indexOf('/search') === 0) return true;
    var name = accessibleName(el);
    return name === 'search' || name.indexOf('search') !== -1 || name.indexOf('explore') !== -1;
  }

  function isProfileTab(el) {
    var name = accessibleName(el);
    if (name === 'profile' || name.indexOf('profile') !== -1) return true;
    var p = pathOf(el);
    // /username/ — single segment, not a known app route.
    if (!p || p === '/') return false;
    var known = ['/reels', '/direct', '/explore', '/search', '/accounts', '/stories', '/p/', '/reel/'];
    for (var i = 0; i < known.length; i++) {
      if (p.indexOf(known[i]) === 0 || p.indexOf(known[i]) !== -1) return false;
    }
    // /someuser or /someuser/
    var parts = p.split('/').filter(Boolean);
    return parts.length === 1;
  }

  function isReelsTab(el) {
    // Hard exclude Direct/Messages first — previous bug hid these instead.
    if (isDirectOrMessages(el)) return false;
    if (isHomeTab(el) || isSearchOrExplore(el) || isProfileTab(el)) return false;

    var p = pathOf(el);
    // Path segment /reels or /reels/...  (not /reel/ post URLs in-feed — those aren't bottom nav).
    if (p === '/reels' || p.indexOf('/reels/') === 0) return true;

    var name = accessibleName(el);
    if (!name) return false;
    // Exact / primary label — avoid loose "reel" substring (false positives).
    if (name === 'reels' || name.indexOf('reels') === 0) return true;
    // Whole-word Reels only.
    if (/(^|[^a-z])reels([^a-z]|$)/.test(name)) return true;
    return false;
  }

  function collectBottomTabCandidates() {
    var selector = [
      'a[href]',
      '[role="link"]',
      'div[role="button"][tabindex]',
      'span[role="link"]'
    ].join(',');
    var nodes = Array.prototype.slice.call(document.querySelectorAll(selector));
    return nodes.filter(isInBottomStrip);
  }

  function markReelsTarget(el) {
    var target = el;
    var parent = el.parentElement;
    // Prefer the flex child wrapper when it only wraps this control.
    if (parent && parent !== document.body && parent.children.length === 1) {
      target = parent;
    }
    // Do not climb further — climbing hid adjacent tabs previously.
    target.setAttribute('data-msa-reels-target', '1');
    el.setAttribute('data-msa-reels-target', '1');
    el.setAttribute('aria-hidden', 'true');
    if (el.setAttribute) el.setAttribute('tabindex', '-1');
  }

  function clearStaleMarks(root) {
    var old = root.querySelectorAll('[data-msa-reels-target],[data-msa-bottom-nav]');
    for (var i = 0; i < old.length; i++) {
      old[i].removeAttribute('data-msa-reels-target');
      old[i].removeAttribute('data-msa-bottom-nav');
      if (old[i].getAttribute('aria-hidden') === 'true') {
        old[i].removeAttribute('aria-hidden');
      }
    }
  }

  function pickFlexContainer(tabs) {
    if (!tabs.length) return null;
    var sameParent = true;
    var p0 = tabs[0].parentElement;
    for (var i = 1; i < tabs.length; i++) {
      if (tabs[i].parentElement !== p0) {
        sameParent = false;
        break;
      }
    }
    if (sameParent && p0) return p0;

    var wrappers = [];
    for (var k = 0; k < tabs.length; k++) {
      var el = tabs[k];
      wrappers.push(el.parentElement && el.parentElement.children.length === 1 ? el.parentElement : el);
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

    // Walk up from first tab until all are contained.
    var ancestor = tabs[0].parentElement;
    while (ancestor && ancestor !== document.body && ancestor !== document.documentElement) {
      var ok = true;
      for (var n = 0; n < tabs.length; n++) {
        if (!ancestor.contains(tabs[n])) {
          ok = false;
          break;
        }
      }
      if (ok) return ancestor;
      ancestor = ancestor.parentElement;
    }
    return null;
  }

  function apply() {
    try {
      ensureStyle();
      var bottom = collectBottomTabCandidates();
      if (bottom.length < 3) {
        // Broader fallback: visible controls in bottom third.
        var selector = 'a[href], [role="link"]';
        bottom = Array.prototype.slice
          .call(document.querySelectorAll(selector))
          .filter(function (el) {
            if (!isVisible(el)) return false;
            var r = el.getBoundingClientRect();
            return r.top > window.innerHeight * 0.72;
          });
      }
      if (bottom.length < 3) return;

      clearStaleMarks(document);

      var hid = 0;
      for (var i = 0; i < bottom.length; i++) {
        if (isReelsTab(bottom[i])) {
          markReelsTarget(bottom[i]);
          hid++;
        }
      }

      // If nothing matched Reels by path/label, try path-only scan of bottom strip
      // (aria sometimes empty on IG web).
      if (hid === 0) {
        for (var j = 0; j < bottom.length; j++) {
          if (isDirectOrMessages(bottom[j])) continue;
          var p = pathOf(bottom[j]);
          if (p === '/reels' || p.indexOf('/reels/') === 0) {
            markReelsTarget(bottom[j]);
            hid++;
          }
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
  // IG SPA soft-nav
  setInterval(schedule, 1500);
})();
"""#
}
