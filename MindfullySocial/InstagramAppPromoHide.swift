import Foundation

/// MSA-21: hide Instagram “Use the app” / open-in-app / get-the-app interstitial banners
/// inside WKWebView. Additive with MSA-16/18/19 scripts.
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
    { re: /\buse the app\b/, reason: 'use-the-app' },
    { re: /\bopen in app\b/, reason: 'open-in-app' },
    { re: /\bopen in the app\b/, reason: 'open-in-app' },
    { re: /\bget the app\b/, reason: 'get-the-app' },
    { re: /\binstall (the )?app\b/, reason: 'install' },
    { re: /\bdownload (the )?app\b/, reason: 'download' },
    { re: /\bcontinue in (the )?app\b/, reason: 'continue-in-app' },
    { re: /\bopen (the )?instagram( app)?\b/, reason: 'open-instagram' },
    { re: /\bsee (this|more).{0,24}in (the )?app\b/, reason: 'see-in-app' },
    { re: /\bapp store\b/, reason: 'app-store' }
  ];

  function normText(s) {
    return String(s || '').replace(/\s+/g, ' ').trim().toLowerCase();
  }

  function ensureStyle() {
    var style = document.getElementById(STYLE_ID);
    if (!style) {
      style = document.createElement('style');
      style.id = STYLE_ID;
      (document.head || document.documentElement).appendChild(style);
    }
    style.textContent = [
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
      '}'
    ].join('\n');
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
        if (el.querySelector && el.querySelector('a[href="/"], a[href="/explore/"], a[href*="/direct"]')) {
          return true;
        }
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
    for (var d = 0; d < 8 && n && n !== document.body; d++) {
      try {
        var r = n.getBoundingClientRect();
        var st = window.getComputedStyle(n);
        var fixedish =
          st.position === 'fixed' ||
          st.position === 'sticky' ||
          st.position === 'absolute';
        var shortBar = r.height > 24 && r.height < 120 && r.width > window.innerWidth * 0.45;
        var nearBottom = r.bottom > window.innerHeight - 160;
        var nearTop = r.top < 120 && r.height < 120;
        var overlay =
          fixedish &&
          r.width > window.innerWidth * 0.55 &&
          r.height > 80 &&
          r.height < window.innerHeight * 0.92;
        // Prefer the shortest fixed/sticky strip that still contains the trigger.
        if ((shortBar && (nearBottom || nearTop || fixedish)) || overlay) {
          if (!isInBottomNav(n)) best = n;
        }
        // Dialog / role=dialog ancestors.
        var role = (n.getAttribute && n.getAttribute('role')) || '';
        if (role === 'dialog' || role === 'alertdialog') {
          if (!isInBottomNav(n)) return n;
        }
      } catch (e) {}
      n = n.parentElement;
    }
    return best;
  }

  function scanTextTriggers(root) {
    var out = [];
    var nodes = root.querySelectorAll(
      'a, button, [role="button"], span, div, p, h1, h2, h3, h4, label'
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
      } catch (e) {
        own = el.textContent || '';
      }
      var reason = matchPromoText(own);
      if (!reason) {
        var aria = matchPromoText(el.getAttribute('aria-label') || '');
        if (aria) reason = aria;
      }
      if (!reason) continue;
      // Guard: if element text is long, it's likely a feed caption.
      var full = normText(el.textContent);
      if (full.length > 80 && reason !== 'use-the-app' && reason !== 'open-in-app') continue;
      out.push({ el: el, reason: reason });
    }
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

      var hits = scanTextTriggers(document);
      var hiddenNow = 0;
      for (var i = 0; i < hits.length; i++) {
        var root = findBannerRoot(hits[i].el);
        if (collapse(root, hits[i].reason)) hiddenNow++;
      }

      var storeHits = scanAppStoreLinks(document);
      for (var j = 0; j < storeHits.length; j++) {
        var storeRoot = findBannerRoot(storeHits[j].el);
        // Only collapse short/top/bottom chrome for store links, not feed media.
        try {
          var sr = storeRoot.getBoundingClientRect();
          if (sr.height > window.innerHeight * 0.55 && sr.height < window.innerHeight * 0.95) {
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
    var nodes = document.querySelectorAll('a, button, [role="button"], span, div');
    for (var i = 0; i < nodes.length && labels.length < 30; i++) {
      var el = nodes[i];
      if (el.getAttribute(MARK) === '1') continue;
      if (isInBottomNav(el)) continue;
      try {
        var r = el.getBoundingClientRect();
        if (r.width < 8 || r.height < 8) continue;
        if (r.bottom < 0 || r.top > window.innerHeight) continue;
      } catch (e) {
        continue;
      }
      var own = '';
      for (var c = 0; c < el.childNodes.length; c++) {
        if (el.childNodes[c].nodeType === 3) own += el.childNodes[c].nodeValue || '';
      }
      if (!own) own = el.getAttribute('aria-label') || '';
      if (!own && el.childElementCount === 0) own = el.textContent || '';
      var reason = matchPromoText(own);
      if (!reason) continue;
      if (normText(el.textContent).length > 80) continue;
      labels.push({ text: normText(own).slice(0, 48), reason: reason });
    }
    return labels;
  }

  window.__msaAppPromo = {
    enabled: true,
    stats: {
      hidden: 0,
      scans: 0,
      lastHiddenBatch: 0,
      lastReasons: [],
      lastError: null,
      visiblePromoText: []
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
        scriptCanary: 'apppromo-v1',
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
    }, 50);
  }

  var mo = new MutationObserver(schedule);
  function start() {
    ensureStyle();
    applyPromoHide();
    try {
      mo.observe(document.documentElement, {
        childList: true,
        subtree: true,
        attributes: true,
        attributeFilter: ['class', 'style', 'href', 'aria-label']
      });
    } catch (e) {}
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
  window.addEventListener('scroll', schedule, { passive: true });
  document.addEventListener('visibilitychange', schedule);
  setInterval(applyPromoHide, 700);
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
