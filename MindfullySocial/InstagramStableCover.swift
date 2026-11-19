import Foundation

/// MSA-32: keep a soft-dark cover over Instagram until the first stable paint
/// after site tweak scripts have run (promo hide + sibling injections), then reveal.
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
  var QUIET_MS = 480;
  var MIN_MS = 320;
  var MAX_MS = 9000;
  var startedAt = Date.now();
  var lastMutationAt = Date.now();
  var revealed = false;
  var enabled = true;
  var revealReason = null;
  var pollTimer = null;
  var mo = null;

  function ensureStyle() {
    var style = document.getElementById(STYLE_ID);
    if (!style) {
      style = document.createElement('style');
      style.id = STYLE_ID;
      (document.documentElement || document.head || document.body).appendChild(style);
    }
    style.textContent = [
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

  function hasMainChrome() {
    try {
      if (document.querySelector('a[href="/"], a[href="/explore/"], a[href*="/direct"]')) {
        return true;
      }
      if (document.querySelector('article, main, [role="main"]')) return true;
      // Logged-out / interstitial still has enough structure to settle.
      if (document.body && document.body.childElementCount > 2) return true;
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
      reveal('timeout');
      return;
    }
    if (!minElapsed()) return;
    if (!hasMainChrome()) return;
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
        hasMainChrome: hasMainChrome(),
        promoClear: promoLooksClear(),
        scriptCanary: 'stablecover-v1',
        path: location.pathname
      };
    }
  };

  ensureCover();
  startObserver();
  pollTimer = setInterval(checkReady, 80);
  // Kick early promo scans so cover can clear sooner.
  for (var d = 0; d < 8; d++) {
    (function (delay) {
      setTimeout(function () {
        try {
          if (window.__msaAppPromo && window.__msaAppPromo.scanNow) {
            window.__msaAppPromo.scanNow();
          }
        } catch (e) {}
        checkReady();
      }, 40 + delay * 90);
    })(d);
  }

  document.addEventListener('DOMContentLoaded', function () {
    bumpMutation();
    checkReady();
  });
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
