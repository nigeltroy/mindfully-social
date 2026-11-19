import Foundation

/// MSA-32: keep a soft-dark cover over Instagram until the first stable paint
/// after site tweak scripts have run (promo hide + sibling injections), then reveal.
/// Chaos BUG-1: first paint must not be empty white (grabber-only sheet).
enum InstagramStableCover {
    /// Injected first at document-start so the page never flashes unstable chrome.
    static let userScriptSource: String = #"""
(function () {
  if (window.__msaStableCoverInstalled) return;
  window.__msaStableCoverInstalled = true;

  var COVER_ID = 'msa-stable-cover';
  var STYLE_ID = 'msa-stable-cover-style';
  // Soft dark gray ≈ Color(white: 0.11)
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
    var style = document.getElementById(STYLE_ID);
    if (!style) {
      style = document.createElement('style');
      style.id = STYLE_ID;
      (document.documentElement || document.head || document.body).appendChild(style);
    }
    style.textContent = [
      'html, body {',
      '  background: ' + COVER_BG + ' !important;',
      '  background-color: ' + COVER_BG + ' !important;',
      '}',
      '#' + COVER_ID + ' {',
      '  position: fixed !important;',
      '  inset: 0 !important;',
      '  width: 100vw !important;',
      '  height: 100vh !important;',
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
  }

  function ensureCover() {
    if (!enabled || revealed) return;
    paintShellDark();
    ensureStyle();
    var el = document.getElementById(COVER_ID);
    if (el) return el;
    el = document.createElement('div');
    el.id = COVER_ID;
    el.setAttribute('data-msa-stable-cover', '1');
    el.setAttribute('aria-hidden', 'true');
    var root = document.documentElement || document.body;
    if (root) root.appendChild(el);
    return el;
  }

  function removeCoverNow() {
    var el = document.getElementById(COVER_ID);
    if (el && el.parentNode) el.parentNode.removeChild(el);
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
      for (var i = 0; i < articles.length; i++) {
        var ar = visibleRect(articles[i]);
        if (ar && ar.height > 120 && ar.width > window.innerWidth * 0.5) return true;
      }
      var media = document.querySelectorAll('img, video, canvas');
      var mediaHits = 0;
      for (var m = 0; m < media.length && mediaHits < 3; m++) {
        var mr = visibleRect(media[m]);
        if (mr && mr.height > 64 && mr.width > 64) mediaHits++;
      }
      if (mediaHits >= 2) return true;

      // Bottom nav with real tab links painted near the bottom.
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
          // Still require some main content above nav (not blank).
          var main = document.querySelector('main, [role="main"], section');
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
    // Promo script not ready yet — keep cover until it is, unless timed out.
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
    if (!enabled) {
      reveal('disabled');
      return;
    }
    if (revealed) return;
    ensureCover();
    if (timedOut()) {
      // Prefer revealing only if something real painted; else keep dark shell.
      if (hasRealContent()) reveal('timeout');
      else reveal('timeout-empty');
      return;
    }
    if (!minElapsed()) return;
    if (!hasRealContent()) return;
    if (!promoLooksClear()) return;
    if (!quietLongEnough()) return;
    reveal('stable');
  }

  function bumpMutation() {
    lastMutationAt = Date.now();
    if (!revealed) ensureCover();
  }

  function startObserver() {
    try {
      mo = new MutationObserver(function () {
        bumpMutation();
      });
      var target = document.documentElement || document.body;
      if (target) {
        mo.observe(target, {
          childList: true,
          subtree: true,
          attributes: true,
          characterData: true
        });
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
        scriptCanary: 'stablecover-v2',
        path: location.pathname
      };
    }
  };

  paintShellDark();
  ensureCover();
  startObserver();
  pollTimer = setInterval(checkReady, 80);
  // Kick early promo scans so cover can clear sooner.
  for (var d = 0; d < 10; d++) {
    (function (delay) {
      setTimeout(function () {
        try {
          if (window.__msaAppPromo && window.__msaAppPromo.scanNow) {
            window.__msaAppPromo.scanNow();
          }
        } catch (e) {}
        checkReady();
      }, 40 + delay * 100);
    })(d);
  }

  document.addEventListener('DOMContentLoaded', function () {
    paintShellDark();
    bumpMutation();
    checkReady();
  });
  window.addEventListener('load', function () {
    paintShellDark();
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

    /// True when JS reports ready (or missing → treat as ready so UI never sticks).
    static let isReadyScript: String = #"""
(function () {
  try {
    if (!window.__msaStableCoverInstalled) return true;
    if (!window.__msaStableCover) return false;
    return !!window.__msaStableCover.isReady();
  } catch (e) {
    return true;
  }
})()
"""#
}
