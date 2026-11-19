import Foundation

/// MSA-36: shared scroll-burst flag + MutationObserver pause so IG tweak scripts
/// do not timer-storm or walk the DOM while the home feed is scrolling
/// (chaos BUG-3 process death ~80s).
enum InstagramScrollCoalesce {
    static let userScriptSource: String = #"""
(function () {
  if (window.__msaScrollCoalesceInstalled) return;
  window.__msaScrollCoalesceInstalled = true;

  window.__msaScrollBurst = false;
  window.__msaMORegistry = [];
  var quietTimer = null;
  var QUIET_MS = 700;
  var paused = false;

  window.__msaRegisterMO = function (mo, getTarget, opts) {
    try {
      window.__msaMORegistry.push({ mo: mo, getTarget: getTarget, opts: opts });
      var t = typeof getTarget === 'function' ? getTarget() : getTarget;
      if (t) mo.observe(t, opts);
    } catch (e) {}
  };

  function pauseObservers() {
    if (paused) return;
    paused = true;
    for (var i = 0; i < window.__msaMORegistry.length; i++) {
      try {
        window.__msaMORegistry[i].mo.disconnect();
      } catch (e) {}
    }
  }

  function resumeObservers() {
    if (!paused) return;
    paused = false;
    for (var j = 0; j < window.__msaMORegistry.length; j++) {
      var r = window.__msaMORegistry[j];
      try {
        var t = typeof r.getTarget === 'function' ? r.getTarget() : r.getTarget;
        if (t) r.mo.observe(t, r.opts);
      } catch (e2) {}
    }
  }

  function markBurst() {
    window.__msaScrollBurst = true;
    pauseObservers();
    if (quietTimer) clearTimeout(quietTimer);
    quietTimer = setTimeout(function () {
      window.__msaScrollBurst = false;
      quietTimer = null;
      resumeObservers();
      try {
        if (typeof window.__msaFlushAfterScroll === 'function') {
          window.__msaFlushAfterScroll();
        }
      } catch (e3) {}
    }, QUIET_MS);
  }

  window.addEventListener('scroll', markBurst, { passive: true, capture: true });
  window.addEventListener('wheel', markBurst, { passive: true, capture: true });
  window.addEventListener('touchmove', markBurst, { passive: true, capture: true });

  /** Run fn now if quiet; otherwise wait for flush (do NOT busy-loop timers). */
  window.__msaRunWhenQuiet = function (fn) {
    if (window.__msaScrollBurst) return;
    try {
      fn();
    } catch (e4) {}
  };
})();
"""#
}
