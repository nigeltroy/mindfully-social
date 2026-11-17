import Foundation

/// MSA-23: auto-skip Instagram Stories sponsored ads inside WKWebView.
/// Additive to MSA-16 Reels-nav, MSA-18 feed-hide, and MSA-19 Explore Reels hide.
enum InstagramStoryAdSkip {
    /// Injected at document-start alongside other Instagram user scripts.
    static let userScriptSource: String = #"""
(function () {
  if (window.__msaStoryAdSkipInstalled) return;
  window.__msaStoryAdSkipInstalled = true;

  var COOLDOWN_MS = 1100;
  var SCAN_MS = 450;
  var MAX_BURST = 6;

  var lastSkipAt = 0;
  var lastSkipKey = '';
  var burstCount = 0;
  var burstWindowStart = 0;

  function normText(s) {
    return String(s || '').replace(/\s+/g, ' ').trim().toLowerCase();
  }

  function inStoryViewer() {
    var path = location.pathname || '';
    if (/\/stories\//i.test(path)) return true;
    // SPA may keep a modal story viewer without updating the path yet.
    var dialogs = document.querySelectorAll('[role="dialog"], section[aria-modal="true"], div[aria-modal="true"]');
    for (var i = 0; i < dialogs.length; i++) {
      var d = dialogs[i];
      try {
        var r = d.getBoundingClientRect();
        if (r.width < window.innerWidth * 0.55 || r.height < window.innerHeight * 0.55) continue;
      } catch (e) { continue; }
      var html = '';
      try { html = (d.innerHTML || '').slice(0, 4000); } catch (e2) {}
      if (/\/stories\//i.test(html)) return true;
      // Progress segments across the top + a close control are strong story-viewer signals.
      var header = d.querySelector('header');
      if (header && d.querySelector('[aria-label*="Close" i], [aria-label*="Next" i], [aria-label*="Go back" i]')) {
        return true;
      }
    }
    return false;
  }

  function storyRoot() {
    var path = location.pathname || '';
    if (/\/stories\//i.test(path)) {
      var dialog = document.querySelector('[role="dialog"], section[aria-modal="true"], div[aria-modal="true"]');
      if (dialog) return dialog;
      return document.body;
    }
    var dialogs = document.querySelectorAll('[role="dialog"], section[aria-modal="true"], div[aria-modal="true"]');
    for (var i = 0; i < dialogs.length; i++) {
      var d = dialogs[i];
      try {
        var r = d.getBoundingClientRect();
        if (r.width >= window.innerWidth * 0.55 && r.height >= window.innerHeight * 0.55) return d;
      } catch (e) {}
    }
    return document.body;
  }

  function exactAdLabel(raw) {
    var t = normText(raw);
    if (!t || t.length > 48) return null;
    if (t === 'sponsored' || t === 'ad' || t === 'advertisement' || t === 'promoted') return t;
    if (t.indexOf('paid partnership') === 0) return 'paid partnership';
    if (t.indexOf('sponsored') === 0 && t.length <= 24) return 'sponsored';
    return null;
  }

  function findAdMarkers(root) {
    var scope = root || document;
    var hits = [];
    // Explicit ad / stories-ads hrefs.
    try {
      var links = scope.querySelectorAll('a[href*="/stories/ads"], a[href*="sponsored"], a[href*="/ads/"]');
      for (var i = 0; i < links.length; i++) {
        hits.push({ kind: 'href', text: links[i].getAttribute('href') || '' });
      }
    } catch (e) {}

    // aria / data markers Instagram sometimes exposes on ad chrome.
    try {
      var marked = scope.querySelectorAll(
        '[data-ad-preview], [data-ad-rendering-role], [data-ad-media], [aria-label*="Sponsored" i], [aria-label*="Advertisement" i]'
      );
      for (var m = 0; m < marked.length; m++) {
        var al = marked[m].getAttribute('aria-label') || marked[m].getAttribute('data-ad-rendering-role') || 'ad-attr';
        hits.push({ kind: 'attr', text: normText(al) });
      }
    } catch (e2) {}

    // Short visible labels in the story chrome (top band + bottom CTA strip).
    try {
      var nodes = scope.querySelectorAll('span, div, a, h1, h2, h3, button, [role="button"]');
      for (var n = 0; n < nodes.length; n++) {
        var el = nodes[n];
        var full = el.textContent || '';
        if (!full || full.length > 40) continue;
        // Prefer leaf-ish nodes so captions do not false-positive.
        if (el.children && el.children.length > 2) continue;
        var reason = exactAdLabel(full);
        if (!reason) continue;
        try {
          var br = el.getBoundingClientRect();
          // Story "Sponsored" sits in the top chrome; ignore mid-caption noise.
          if (br.top > window.innerHeight * 0.42 && reason !== 'sponsored') continue;
          if (br.width < 2 || br.height < 2) continue;
        } catch (e3) {}
        hits.push({ kind: 'label', text: reason, el: el });
      }
    } catch (e4) {}

    return hits;
  }

  function storyKey(root) {
    var path = location.pathname || '';
    var user = '';
    try {
      var link = (root || document).querySelector('header a[href^="/"], header a[role="link"]');
      if (link) user = link.getAttribute('href') || (link.textContent || '');
    } catch (e) {}
    return path + '|' + normText(user).slice(0, 64);
  }

  function clickAt(x, y) {
    var target = document.elementFromPoint(x, y) || document.body;
    var opts = { bubbles: true, cancelable: true, view: window, clientX: x, clientY: y };
    try {
      target.dispatchEvent(new PointerEvent('pointerdown', opts));
      target.dispatchEvent(new MouseEvent('mousedown', opts));
      target.dispatchEvent(new PointerEvent('pointerup', opts));
      target.dispatchEvent(new MouseEvent('mouseup', opts));
      target.dispatchEvent(new MouseEvent('click', opts));
    } catch (e) {
      try { target.click(); } catch (e2) {}
    }
  }

  function advanceStory(root) {
    var scope = root || document;
    // Prefer explicit Next controls when IG exposes them.
    var nextSelectors = [
      'button[aria-label*="Next" i]',
      '[role="button"][aria-label*="Next" i]',
      'div[aria-label*="Next" i]',
      'button[aria-label*="Forward" i]'
    ];
    for (var i = 0; i < nextSelectors.length; i++) {
      var btn = scope.querySelector(nextSelectors[i]);
      if (btn) {
        try { btn.click(); return 'next-btn'; } catch (e) {}
      }
    }

    // Keyboard advance (desktop story viewer).
    try {
      var ke = { key: 'ArrowRight', code: 'ArrowRight', keyCode: 39, which: 39, bubbles: true, cancelable: true };
      document.dispatchEvent(new KeyboardEvent('keydown', ke));
      document.dispatchEvent(new KeyboardEvent('keyup', ke));
    } catch (e2) {}

    // Tap the right third of the story surface (mobile-style advance).
    try {
      var r = (scope.getBoundingClientRect && scope.getBoundingClientRect()) || {
        left: 0, top: 0, width: window.innerWidth, height: window.innerHeight
      };
      var x = r.left + r.width * 0.86;
      var y = r.top + r.height * 0.48;
      clickAt(x, y);
      return 'tap-right';
    } catch (e3) {
      return 'keyboard';
    }
  }

  function maybeSkip() {
    try {
      if (!window.__msaStoryAdSkip || window.__msaStoryAdSkip.enabled === false) return;
      if (!inStoryViewer()) {
        burstCount = 0;
        return;
      }
      var root = storyRoot();
      var hits = findAdMarkers(root);
      if (!hits.length) return;

      var now = Date.now();
      if (now - lastSkipAt < COOLDOWN_MS) return;

      var key = storyKey(root) + '|' + (hits[0].text || hits[0].kind);
      if (key === lastSkipKey && now - lastSkipAt < 4000) {
        // Same sponsored item still showing — advance again, but track burst.
      }

      if (now - burstWindowStart > 8000) {
        burstWindowStart = now;
        burstCount = 0;
      }
      if (burstCount >= MAX_BURST) return;

      var method = advanceStory(root);
      lastSkipAt = now;
      lastSkipKey = key;
      burstCount += 1;

      var api = window.__msaStoryAdSkip;
      api.stats.skips += 1;
      api.stats.lastMethod = method;
      api.stats.lastKey = key;
      api.stats.lastHits = hits.slice(0, 6).map(function (h) {
        return { kind: h.kind, text: h.text };
      });
      api.stats.lastSkipAt = now;
    } catch (e) {
      if (window.__msaStoryAdSkip) {
        window.__msaStoryAdSkip.stats.lastError = String((e && e.message) || e);
      }
    }
  }

  window.__msaStoryAdSkip = {
    enabled: true,
    stats: {
      skips: 0,
      scans: 0,
      lastMethod: null,
      lastKey: null,
      lastHits: [],
      lastSkipAt: null,
      lastError: null
    },
    setEnabled: function (on) {
      this.enabled = !!on;
    },
    dump: function () {
      var root = null;
      var inStory = false;
      try {
        inStory = inStoryViewer();
        root = inStory ? storyRoot() : null;
      } catch (e) {}
      var hits = [];
      try { hits = findAdMarkers(root || document); } catch (e2) {}
      var labels = [];
      try {
        var nodes = (root || document).querySelectorAll('span, div, a, button');
        for (var i = 0; i < nodes.length && labels.length < 40; i++) {
          var t = (nodes[i].textContent || '').replace(/\s+/g, ' ').trim();
          if (!t || t.length > 36) continue;
          if (/sponsored|^ad$|advertisement|learn more|shop now|install|paid partnership/i.test(t)) {
            labels.push(t);
          }
        }
      } catch (e3) {}
      return {
        enabled: this.enabled,
        inStoryViewer: inStory,
        path: location.pathname,
        href: location.href,
        storyKey: root ? storyKey(root) : null,
        hits: hits.slice(0, 8).map(function (h) { return { kind: h.kind, text: h.text }; }),
        interestingLabels: labels,
        stats: this.stats,
        scriptCanary: 'storyadskip-v1'
      };
    }
  };

  function tick() {
    window.__msaStoryAdSkip.stats.scans += 1;
    maybeSkip();
  }

  function boot() {
    tick();
    try {
      var obs = new MutationObserver(function () { maybeSkip(); });
      obs.observe(document.documentElement || document, {
        childList: true,
        subtree: true,
        characterData: true
      });
    } catch (e) {}
    setInterval(tick, SCAN_MS);
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', boot);
  } else {
    boot();
  }
})();
"""#

    /// Evaluate to JSON string for Tart dump probes.
    static let dumpScript: String = #"""
(function () {
  try {
    var dump = (window.__msaStoryAdSkip && window.__msaStoryAdSkip.dump)
      ? window.__msaStoryAdSkip.dump()
      : { error: 'story_ad_skip_missing' };
    dump.storyInstalled = !!window.__msaStoryAdSkipInstalled;
    return JSON.stringify(dump);
  } catch (e) {
    return JSON.stringify({ error: String(e) });
  }
})()
"""#
}
