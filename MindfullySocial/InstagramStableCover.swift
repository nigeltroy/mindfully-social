import Foundation

/// MSA-32: keep a soft-dark cover over Instagram until the first stable paint
/// after site tweak scripts have run (promo hide + sibling injections), then reveal.
/// Chaos BUG-1: first paint must not be empty white (grabber-only sheet).
enum InstagramStableCover {
    /// Injected first at document-start so the page never flashes unstable chrome.
    /// Keep this script light at document-start: heavy DOM work is deferred.
    /// (A prior version hung/blanked WK on Tart/iOS 27.2 when it ran fully sync.)
    static let userScriptSource: String = #"""
(function () {
  if (window.__msaStableCoverInstalled) return;
  window.__msaStableCoverInstalled = true;

  var COVER_ID = 'msa-stable-cover';
  var STYLE_ID = 'msa-stable-cover-style';
  var COVER_BG = '#1c1c1c';
  var QUIET_MS = 520;
  var MIN_MS = 480;
  var MAX_MS = 10000;
  var startedAt = Date.now();
  var lastMutationAt = Date.now();
  var revealed = false;
  var enabled = true;
  var revealReason = null;
  var pollTimer = null;
  var mo = null;
  var started = false;

  function paintShellDark() {
    try {
      var root = document.documentElement;
      if (root) {
        root.style.setProperty('background', COVER_BG, 'important');
        root.style.setProperty('background-color', COVER_BG, 'important');
      }
      if (document.body) {
        document.body.style.setProperty('background', COVER_BG, 'important');
        document.body.style.setProperty('background-color', COVER_BG, 'important');
      }
    } catch (e) {}
  }

  function ensureStyle() {
    try {
      var style = document.getElementById(STYLE_ID);
      if (!style) {
        style = document.createElement('style');
        style.id = STYLE_ID;
        var parent = document.head || document.documentElement || document.body;
        if (!parent) return;
        parent.appendChild(style);
      }
      style.textContent = [
        'html, body {',
        '  background: ' + COVER_BG + ' !important;',
        '  background-color: ' + COVER_BG + ' !important;',
        '}',
        '#' + COVER_ID + ' {',
        '  position: fixed !important;',
        '  inset: 0 !important;',
        '  width: 100% !important;',
        '  height: 100% !important;',
        '  z-index: 2147483646 !important;',
        '  background: ' + COVER_BG + ' !important;',
        '  opacity: 1 !important;',
        '  pointer-events: none !important;',
        '  transition: opacity 0.28s ease-out !important;',
        '}',
        '#' + COVER_ID + '[data-msa-revealing="1"] {',
        '  opacity: 0 !important;',
        '}'
      ].join('\n');
    } catch (e) {}
  }

  function ensureCover() {
    if (!enabled || revealed) return;
    try {
      paintShellDark();
      ensureStyle();
      var el = document.getElementById(COVER_ID);
      if (el) return el;
      var parent = document.documentElement || document.body;
      if (!parent) return null;
      el = document.createElement('div');
      el.id = COVER_ID;
      el.setAttribute('data-msa-stable-cover', '1');
      el.setAttribute('aria-hidden', 'true');
      parent.appendChild(el);
      return el;
    } catch (e) {
      return null;
    }
  }

  function removeCoverNow() {
    try {
      var el = document.getElementById(COVER_ID);
      if (el && el.parentNode) el.parentNode.removeChild(el);
    } catch (e) {}
  }

  function visibleRect(el) {
    try {
      var r = el.getBoundingClientRect();
      if (r.width < 8 || r.height < 8) return null;
      if (r.bottom < 0 || r.top > window.innerHeight) return null;
      return r;
    } catch (e) {
      return null;
    }
  }

  /** Real painted feed/chrome — not an empty white sheet with a grabber. */
  function hasRealContent() {
    try {
      var articles = document.querySelectorAll('article');
      var i;
      for (i = 0; i < articles.length; i++) {
        var ar = visibleRect(articles[i]);
        if (ar && ar.height > 120 && ar.width > window.innerWidth * 0.5) return true;
      }
      var media = document.querySelectorAll('img, video');
      var mediaHits = 0;
      for (var m = 0; m < media.length && mediaHits < 3; m++) {
        var mr = visibleRect(media[m]);
        if (mr && mr.height > 64 && mr.width > 64) mediaHits++;
      }
      if (mediaHits >= 2) return true;

      var home = document.querySelector('a[href="/"]');
      var explore = document.querySelector('a[href="/explore/"]');
      if (home && explore) {
        var hr = visibleRect(home);
        var er = visibleRect(explore);
        if (
          hr &&
          er &&
          hr.top > window.innerHeight - 120 &&
          er.top > window.innerHeight - 120
        ) {
          var main = document.querySelector('main, [role="main"]');
          if (main) {
            var mainR = visibleRect(main);
            if (mainR && mainR.height > 160) return true;
          }
          if (mediaHits >= 1) return true;
        }
      }
    } catch (e) {}
    return false;
  }

  function promoLooksClear() {
    try {
      if (window.__msaAppPromo) {
        if (window.__msaAppPromo.enabled === false) return true;
        if (typeof window.__msaAppPromo.scanNow === 'function') {
          window.__msaAppPromo.scanNow();
        }
        var live = window.__msaAppPromo.stats && window.__msaAppPromo.stats.visiblePromoText;
        if (Array.isArray(live) && live.length > 0) return false;
        return true;
      }
    } catch (e) {}
    return false;
  }

  function quietLongEnough() {
    return Date.now() - lastMutationAt >= QUIET_MS;
  }

  function minElapsed() {
    return Date.now() - startedAt >= MIN_MS;
  }

  function timedOut() {
    return Date.now() - startedAt >= MAX_MS;
  }

  function reveal(reason) {
    if (revealed) return;
    revealed = true;
    revealReason = reason || 'stable';
    var el = document.getElementById(COVER_ID);
    if (el) {
      try {
        el.setAttribute('data-msa-revealing', '1');
      } catch (e) {}
      setTimeout(removeCoverNow, 320);
    }
    if (pollTimer) {
      clearInterval(pollTimer);
      pollTimer = null;
    }
    try {
      if (mo) mo.disconnect();
    } catch (e2) {}
  }

  function checkReady() {
    try {
      if (!enabled) {
        reveal('disabled');
        return;
      }
      if (revealed) return;
      ensureCover();
      if (timedOut()) {
        if (hasRealContent() && promoLooksClear()) reveal('timeout');
        else ensureCover();
        return;
      }
      if (!minElapsed()) return;
      if (!hasRealContent()) return;
      if (!promoLooksClear()) return;
      if (!quietLongEnough()) return;
      reveal('stable');
    } catch (e) {}
  }

  function bumpMutation() {
    lastMutationAt = Date.now();
    if (!revealed) ensureCover();
  }

  function startObserver() {
    try {
      if (mo) return;
      mo = new MutationObserver(function () {
        if (window.__msaScrollBurst) return;
        bumpMutation();
      });
      var opts = {
        childList: true,
        subtree: true,
        attributes: false,
        characterData: false
      };
      if (window.__msaRegisterMO) {
        window.__msaRegisterMO(mo, function () { return document.documentElement || document.body; }, opts);
      } else {
        var target = document.documentElement || document.body;
        if (target) mo.observe(target, opts);
      }
    } catch (e) {}
  }

  window.__msaStableCover = {
    enabled: true,
    isReady: function () {
      return revealed;
    },
    setEnabled: function (on) {
      enabled = !!on;
      this.enabled = enabled;
      if (!enabled) {
        reveal('disabled');
      } else if (!revealed) {
        ensureCover();
      }
    },
    forceReveal: function (reason) {
      reveal(reason || 'force');
    },
    dump: function () {
      return {
        enabled: enabled,
        revealed: revealed,
        revealReason: revealReason,
        ageMs: Date.now() - startedAt,
        quietMs: Date.now() - lastMutationAt,
        hasCover: !!document.getElementById(COVER_ID),
        hasRealContent: hasRealContent(),
        promoClear: promoLooksClear(),
        scriptCanary: 'stablecover-v3',
        path: location.pathname
      };
    }
  };

  function boot() {
    if (started) return;
    started = true;
    try {
      paintShellDark();
      ensureCover();
      startObserver();
      if (!pollTimer) pollTimer = setInterval(checkReady, 120);
      checkReady();
    } catch (e) {}
  }

  // Defer heavy work: sync document-start work blanked WK on Tart/iOS 27.2.
  try {
    paintShellDark();
  } catch (e0) {}
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', boot);
  } else {
    setTimeout(boot, 0);
  }
  window.addEventListener('load', function () {
    bumpMutation();
    checkReady();
  });
})();
"""#

    /// Evaluate in WKWebView to dump stable-cover state as JSON string.
    static let dumpScript: String = #"""
(function () {
  try {
    if (window.__msaStableCover && window.__msaStableCover.dump) {
      return JSON.stringify(window.__msaStableCover.dump());
    }
    return JSON.stringify({ error: 'stable_cover_missing', installed: !!window.__msaStableCoverInstalled });
  } catch (e) {
    return JSON.stringify({ error: String(e) });
  }
})()
"""#

    /// True only when JS cover has revealed. Missing install → false so native
    /// cover stays up (chaos BUG-1).
    static let isReadyScript: String = #"""
(function () {
  try {
    if (!window.__msaStableCoverInstalled) return false;
    if (!window.__msaStableCover) return false;
    return !!window.__msaStableCover.isReady();
  } catch (e) {
    return false;
  }
})()
"""#
}
