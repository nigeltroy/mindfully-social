import Foundation

/// MSA-30: stop Instagram in-feed reels from auto-opening fullscreen / reel viewer
/// without a real user gesture. Intentional taps still open reels.
enum InstagramReelAutoOpenGuard {
    /// Injected at document-start alongside other Instagram user scripts.
    static let userScriptSource: String = #"""
(function () {
  if (window.__msaReelGuardInstalled) return;
  window.__msaReelGuardInstalled = true;

  var GESTURE_MS = 2500;
  var lastTrustedGestureAt = 0;
  var stats = {
    blockedFullscreen: 0,
    blockedReelNav: 0,
    blockedReelClick: 0,
    forcedPlaysinline: 0,
    allowedTrusted: 0
  };
  var recent = [];
  var enabled = true;

  function note(kind, detail) {
    recent.push({ t: Date.now(), kind: kind, detail: String(detail || '').slice(0, 120) });
    if (recent.length > 40) recent.shift();
  }

  function hasTrustedGesture() {
    return (Date.now() - lastTrustedGestureAt) <= GESTURE_MS;
  }

  function markTrusted(ev) {
    try {
      if (ev && ev.isTrusted) lastTrustedGestureAt = Date.now();
    } catch (e) {}
  }

  ['pointerdown', 'touchstart', 'mousedown', 'keydown', 'click'].forEach(function (type) {
    try {
      document.addEventListener(type, markTrusted, true);
    } catch (e) {}
  });

  function pathLooksReel(path) {
    var p = String(path || '').toLowerCase();
    if (p.indexOf('/reel/') === 0) return true;
    if (p.indexOf('/reels/') === 0 && p.indexOf('/reels/audio') !== 0) {
      var rest = p.slice('/reels/'.length).replace(/\/$/, '');
      return !!rest && rest.indexOf('audio') !== 0;
    }
    return false;
  }

  function hrefLooksReel(href) {
    try {
      var u = new URL(href, location.origin);
      return pathLooksReel(u.pathname || '');
    } catch (e) {
      return /\/reel\//i.test(String(href || '')) || /\/reels\/(?!audio)/i.test(String(href || ''));
    }
  }

  function forcePlaysinline(video) {
    if (!video || video.nodeType !== 1) return;
    try {
      if (!video.hasAttribute('playsinline')) {
        video.setAttribute('playsinline', '');
        stats.forcedPlaysinline += 1;
      }
      if (!video.hasAttribute('webkit-playsinline')) {
        video.setAttribute('webkit-playsinline', '');
      }
      try { video.playsInline = true; } catch (e1) {}
    } catch (e2) {}
  }

  function scanVideos(root) {
    var scope = root || document;
    var vids = scope.querySelectorAll ? scope.querySelectorAll('video') : [];
    for (var i = 0; i < vids.length; i++) forcePlaysinline(vids[i]);
  }

  function blockFullscreenCall(label) {
    if (!enabled) return false;
    if (hasTrustedGesture()) {
      stats.allowedTrusted += 1;
      note('allow-fs', label);
      return false;
    }
    stats.blockedFullscreen += 1;
    note('block-fs', label);
    return true;
  }

  function patchVideoFullscreen() {
    try {
      var proto = window.HTMLVideoElement && window.HTMLVideoElement.prototype;
      if (!proto) return;
      ['webkitEnterFullscreen', 'webkitEnterFullScreen', 'requestFullscreen'].forEach(function (name) {
        var orig = proto[name];
        if (typeof orig !== 'function') return;
        proto[name] = function () {
          forcePlaysinline(this);
          if (blockFullscreenCall(name)) return;
          return orig.apply(this, arguments);
        };
      });
    } catch (e) {}
    try {
      var elProto = window.Element && window.Element.prototype;
      if (elProto && typeof elProto.requestFullscreen === 'function') {
        var origRF = elProto.requestFullscreen;
        elProto.requestFullscreen = function () {
          if (blockFullscreenCall('Element.requestFullscreen')) {
            return Promise.reject(new Error('msa-block-fullscreen'));
          }
          return origRF.apply(this, arguments);
        };
      }
    } catch (e2) {}
  }

  function blockReelNavigation(reason, href) {
    if (!enabled) return false;
    if (!hrefLooksReel(href) && !pathLooksReel(href)) return false;
    if (hasTrustedGesture()) {
      stats.allowedTrusted += 1;
      note('allow-nav', reason + ':' + href);
      return false;
    }
    stats.blockedReelNav += 1;
    note('block-nav', reason + ':' + href);
    return true;
  }

  function patchHistory() {
    try {
      var origPush = history.pushState;
      var origReplace = history.replaceState;
      history.pushState = function (state, title, url) {
        if (url && blockReelNavigation('pushState', String(url))) return;
        return origPush.apply(this, arguments);
      };
      history.replaceState = function (state, title, url) {
        if (url && blockReelNavigation('replaceState', String(url))) return;
        return origReplace.apply(this, arguments);
      };
    } catch (e) {}
  }

  function closestReelAnchor(el) {
    var n = el;
    for (var i = 0; i < 8 && n; i++) {
      if (n.tagName === 'A') {
        var href = n.getAttribute('href') || '';
        if (hrefLooksReel(href)) return n;
      }
      n = n.parentElement;
    }
    return null;
  }

  function onClickCapture(ev) {
    try {
      if (!enabled) return;
      if (ev && ev.isTrusted) {
        lastTrustedGestureAt = Date.now();
        return;
      }
      var a = closestReelAnchor(ev.target);
      if (!a) return;
      if (hasTrustedGesture()) {
        stats.allowedTrusted += 1;
        note('allow-click', a.getAttribute('href') || '');
        return;
      }
      stats.blockedReelClick += 1;
      note('block-click', a.getAttribute('href') || '');
      ev.preventDefault();
      ev.stopPropagation();
      if (typeof ev.stopImmediatePropagation === 'function') ev.stopImmediatePropagation();
    } catch (e) {}
  }

  // Remember intentional reel landings so we never bounce a tapped-open viewer.
  var intentionalReelPath = '';

  function watchPath() {
    try {
      var path = location.pathname || '';
      if (!pathLooksReel(path)) {
        intentionalReelPath = '';
        return;
      }
      if (hasTrustedGesture()) {
        intentionalReelPath = path;
        return;
      }
      if (intentionalReelPath && intentionalReelPath === path) return;
      // Soft recovery only for unsolicited /reel/ landings (no recent tap).
      if (!enabled) return;
      stats.blockedReelNav += 1;
      note('recover-path', path);
      try {
        if (history.length > 1) history.back();
        else history.replaceState(null, '', '/');
      } catch (e) {}
    } catch (e2) {}
  }

  function apply() {
    try {
      scanVideos(document);
      watchPath();
    } catch (e) {}
  }

  patchVideoFullscreen();
  patchHistory();
  document.addEventListener('click', onClickCapture, true);

  var mo = new MutationObserver(function (muts) {
    for (var i = 0; i < muts.length; i++) {
      var m = muts[i];
      if (m.type === 'childList') {
        for (var j = 0; j < m.addedNodes.length; j++) {
          var node = m.addedNodes[j];
          if (!node || node.nodeType !== 1) continue;
          if (node.tagName === 'VIDEO') forcePlaysinline(node);
          else if (node.querySelectorAll) scanVideos(node);
        }
      } else if (m.type === 'attributes' && m.target && m.target.tagName === 'VIDEO') {
        forcePlaysinline(m.target);
      }
    }
  });
  try {
    mo.observe(document.documentElement || document, {
      childList: true,
      subtree: true,
      attributes: true,
      attributeFilter: ['playsinline', 'webkit-playsinline', 'src']
    });
  } catch (e3) {}

  setInterval(apply, 1200);
  ['pushState', 'replaceState'].forEach(function () {});
  window.addEventListener('popstate', function () { setTimeout(apply, 0); });
  document.addEventListener('DOMContentLoaded', apply);
  apply();

  window.__msaReelGuard = {
    enabled: true,
    scriptCanary: 'reelguard-v1',
    setEnabled: function (on) {
      enabled = !!on;
      this.enabled = enabled;
      return enabled;
    },
    dump: function () {
      return {
        scriptCanary: 'reelguard-v1',
        enabled: enabled,
        path: location.pathname,
        href: location.href,
        hasTrustedGesture: hasTrustedGesture(),
        lastTrustedGestureAt: lastTrustedGestureAt,
        stats: {
          blockedFullscreen: stats.blockedFullscreen,
          blockedReelNav: stats.blockedReelNav,
          blockedReelClick: stats.blockedReelClick,
          forcedPlaysinline: stats.forcedPlaysinline,
          allowedTrusted: stats.allowedTrusted
        },
        recent: recent.slice(-12),
        videoCount: document.querySelectorAll('video').length,
        videosMissingPlaysinline: Array.prototype.slice.call(document.querySelectorAll('video')).filter(function (v) {
          return !v.hasAttribute('playsinline');
        }).length
      };
    },
    /// Mechanism proof: try to open a reel / enter fullscreen without a gesture.
    simulateAutoOpen: function () {
      var result = { clicked: false, fullscreen: false, pushState: false, blocked: false };
      try {
        var a = document.querySelector('a[href*="/reel/"], a[href*="/reels/"]');
        if (a) {
          try {
            a.dispatchEvent(new MouseEvent('click', { bubbles: true, cancelable: true, view: window }));
            result.clicked = true;
          } catch (e1) {}
        }
      } catch (e2) {}
      try {
        history.pushState(null, '', '/reel/msa30sim/');
        result.pushState = pathLooksReel(location.pathname);
      } catch (e3) {}
      try {
        var v = document.querySelector('video') || document.createElement('video');
        forcePlaysinline(v);
        if (typeof v.webkitEnterFullscreen === 'function') {
          v.webkitEnterFullscreen();
          result.fullscreen = true;
        } else if (typeof v.requestFullscreen === 'function') {
          v.requestFullscreen();
          result.fullscreen = true;
        }
      } catch (e4) {}
      result.blocked = (stats.blockedFullscreen + stats.blockedReelNav + stats.blockedReelClick) > 0;
      result.stats = {
        blockedFullscreen: stats.blockedFullscreen,
        blockedReelNav: stats.blockedReelNav,
        blockedReelClick: stats.blockedReelClick
      };
      result.path = location.pathname;
      note('simulate', JSON.stringify(result).slice(0, 120));
      // Undo synthetic path if we landed on the sim reel without a gesture.
      try {
        if (pathLooksReel(location.pathname) && !hasTrustedGesture()) {
          history.replaceState(null, '', '/');
        }
      } catch (e5) {}
      return result;
    }
  };
})();
"""#

    static let dumpScript: String = #"""
(function () {
  try {
    if (window.__msaReelGuard && window.__msaReelGuard.dump) {
      return JSON.stringify(window.__msaReelGuard.dump());
    }
    return JSON.stringify({ error: 'reel_guard_missing', path: location.pathname });
  } catch (e) {
    return JSON.stringify({ error: String(e) });
  }
})()
"""#
}
