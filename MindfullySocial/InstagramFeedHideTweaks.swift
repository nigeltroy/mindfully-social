import Foundation

/// MSA-18: collapse Instagram home-feed Sponsored ads and “Suggested for you” posts.
/// Lives in a separate file so it stays additive with MSA-16 Reels-nav and MSA-19 Explore scripts.
extension InstagramChromeTweaks {
    /// Injected at document-start alongside `userScriptSource`.
    static let feedHideUserScriptSource: String = #"""
(function () {
  if (window.__msaFeedHideInstalled) return;
  window.__msaFeedHideInstalled = true;

  var STYLE_ID = 'msa-hide-feed-ads-style';
  var FEED_MARK = 'data-msa-feed-hide';
  var FEED_REASON = 'data-msa-feed-hide-reason';

  // Exact short labels only (normalized). Do not substring-match full article text —
  // captions that mention “sponsored” must not hide real followed posts.
  var EXACT_LABELS = {
    'sponsored': 'sponsored',
    'ad': 'sponsored',
    'advertisement': 'sponsored',
    'promoted': 'sponsored',
    'suggested for you': 'suggested',
    'suggestions for you': 'suggested',
    'suggested posts': 'suggested-section',
    'suggested post': 'suggested',
    'suggested': 'suggested'
  };
  var PREFIX_LABELS = [
    { prefix: 'paid partnership', reason: 'sponsored' },
    { prefix: 'suggestions for you', reason: 'suggested' },
    { prefix: 'suggested for you', reason: 'suggested' },
    { prefix: 'suggested posts', reason: 'suggested-section' }
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
    // Collapse — do not use display:none on feed units (breaks IG infinite scroll).
    style.textContent = [
      '[' + FEED_MARK + '="1"] {',
      '  visibility: hidden !important;',
      '  height: 0 !important;',
      '  min-height: 0 !important;',
      '  max-height: 0 !important;',
      '  margin: 0 !important;',
      '  padding: 0 !important;',
      '  overflow: hidden !important;',
      '  opacity: 0 !important;',
      '  pointer-events: none !important;',
      '  border: 0 !important;',
      '}'
    ].join('\n');
  }

  function matchLabel(raw) {
    var t = normText(raw);
    if (!t || t.length > 64) return null;
    if (EXACT_LABELS[t]) return EXACT_LABELS[t];
    for (var i = 0; i < PREFIX_LABELS.length; i++) {
      if (t.indexOf(PREFIX_LABELS[i].prefix) === 0) return PREFIX_LABELS[i].reason;
    }
    // IG often concatenates "Suggestions for you" + "See all" with no space.
    if (t.indexOf('suggestions for you') !== -1 && t.length <= 40) {
      return 'suggested';
    }
    if (t.indexOf('suggested for you') !== -1 && t.length <= 40) {
      return 'suggested';
    }
    return null;
  }

  function isInBottomNav(el) {
    var n = el;
    while (n && n !== document.body) {
      if (n.getAttribute && n.getAttribute('data-msa-bottom-nav') === '1') return true;
      n = n.parentElement;
    }
    try {
      var r = el.getBoundingClientRect();
      if (r.top > window.innerHeight - 120) return true;
    } catch (e) {}
    return false;
  }

  function isStoriesTray(el) {
    try {
      var r = el.getBoundingClientRect();
      if (r.height > 0 && r.height < 160 && r.width > window.innerWidth * 0.7 && r.top < 220) {
        if (el.querySelector && el.querySelector('ul')) return true;
      }
    } catch (e) {}
    return false;
  }

  function findFeedUnit(fromEl) {
    if (!fromEl || !fromEl.closest) return null;
    var article = fromEl.closest('article');
    if (article && !isInBottomNav(article)) return article;

    var node = fromEl;
    for (var depth = 0; depth < 12 && node && node !== document.body; depth++) {
      if (node.getAttribute && node.getAttribute(FEED_MARK) === '1') return node;
      var tag = (node.tagName || '').toLowerCase();
      if (tag === 'main' || tag === 'body' || tag === 'html') break;
      var r = node.getBoundingClientRect ? node.getBoundingClientRect() : null;
      if (r && r.height >= 40 && r.width >= Math.min(280, window.innerWidth * 0.7)) {
        var parent = node.parentElement;
        if (parent && parent.children && parent.children.length >= 2) {
          return node;
        }
      }
      node = node.parentElement;
    }
    return fromEl.closest('div') || fromEl;
  }

  function labelInHeaderBand(labelEl, unit) {
    try {
      var lr = labelEl.getBoundingClientRect();
      var ur = unit.getBoundingClientRect();
      if (ur.height <= 0) return true;
      return (lr.top - ur.top) < Math.min(160, Math.max(72, ur.height * 0.35));
    } catch (e) {
      return true;
    }
  }

  function collapseUnit(unit, reason) {
    if (!unit || unit.nodeType !== 1) return false;
    if (isInBottomNav(unit)) return false;
    if (isStoriesTray(unit)) return false;
    unit.setAttribute(FEED_MARK, '1');
    unit.setAttribute(FEED_REASON, reason || 'unknown');
    unit.setAttribute('aria-hidden', 'true');
    unit.style.setProperty('visibility', 'hidden', 'important');
    unit.style.setProperty('height', '0', 'important');
    unit.style.setProperty('min-height', '0', 'important');
    unit.style.setProperty('max-height', '0', 'important');
    unit.style.setProperty('overflow', 'hidden', 'important');
    unit.style.setProperty('opacity', '0', 'important');
    unit.style.setProperty('pointer-events', 'none', 'important');
    unit.style.setProperty('margin', '0', 'important');
    unit.style.setProperty('padding', '0', 'important');
    return true;
  }

  function reinforceCollapsed() {
    var nodes = document.querySelectorAll('[' + FEED_MARK + '="1"]');
    for (var i = 0; i < nodes.length; i++) {
      var el = nodes[i];
      var h = el.style.getPropertyValue('height');
      if (el.style.getPropertyValue('visibility') !== 'hidden' || (h !== '0px' && h !== '0')) {
        el.style.setProperty('visibility', 'hidden', 'important');
        el.style.setProperty('height', '0', 'important');
        el.style.setProperty('max-height', '0', 'important');
        el.style.setProperty('overflow', 'hidden', 'important');
        el.style.setProperty('opacity', '0', 'important');
      }
    }
  }

  function leafishText(el) {
    if (!el) return '';
    if (el.childElementCount === 0) return el.textContent || '';
    if (el.childNodes.length === 1 && el.childNodes[0].nodeType === 3) {
      return el.textContent || '';
    }
    if (el.childElementCount === 1) {
      var only = el.firstElementChild;
      if (only && only.childElementCount === 0) return only.textContent || '';
    }
    // Concatenate shallow text without descending into deep caption trees.
    var parts = [];
    for (var i = 0; i < el.childNodes.length; i++) {
      var n = el.childNodes[i];
      if (n.nodeType === 3) {
        parts.push(n.nodeValue || '');
      } else if (n.nodeType === 1 && n.childElementCount === 0) {
        var bit = (n.textContent || '').replace(/\s+/g, ' ').trim();
        if (bit && bit.length <= 32) parts.push(bit);
      }
    }
    return parts.join('');
  }

  function scanLabelNodes(root) {
    var scope = root || document;
    var nodes = scope.querySelectorAll
      ? scope.querySelectorAll('span, div, a, h1, h2, h3, h4, [role="button"]')
      : [];
    var hits = [];
    for (var i = 0; i < nodes.length; i++) {
      var el = nodes[i];
      var raw = leafishText(el);
      var reason = matchLabel(raw);
      if (!reason) {
        // Short full textContent (e.g. nested “Ad” span wrappers).
        var full = el.textContent || '';
        if (normText(full).length > 0 && normText(full).length <= 24) {
          reason = matchLabel(full);
          if (reason) raw = full;
        }
      }
      if (!reason) continue;
      if (isInBottomNav(el)) continue;
      hits.push({ el: el, reason: reason, text: normText(raw) });
    }
    return hits;
  }

  function articleLooksSponsored(article) {
    if (!article || !article.querySelectorAll) return false;
    if (article.querySelector('[data-ad-preview="message"], [data-ad-rendering-role], [data-ad-media]')) {
      return true;
    }
    // First ~160 chars of article text often contain “Ad” / “Sponsored” in the header.
    var head = normText((article.innerText || '').slice(0, 160));
    if (/(^|[^a-z])ad([^a-z]|$)/.test(head) || head.indexOf('sponsored') !== -1 ||
        head.indexOf('paid partnership') !== -1) {
      return true;
    }
    // Header strip node walk — avoid caption false positives deeper in the post.
    var headerBudget = 0;
    var nodes = article.querySelectorAll('span, a, div, h1, h2, h3');
    for (var i = 0; i < nodes.length; i++) {
      var el = nodes[i];
      var raw = leafishText(el);
      if (!raw) {
        var full = el.textContent || '';
        if (normText(full).length > 0 && normText(full).length <= 24) raw = full;
      }
      var t = normText(raw);
      if (!t || t.length > 24) continue;
      try {
        var lr = el.getBoundingClientRect();
        var ar = article.getBoundingClientRect();
        if (ar.height > 0 && (lr.top - ar.top) > 160) continue;
      } catch (e) {}
      if (t === 'ad' || t === 'sponsored' || t === 'promoted' || t.indexOf('paid partnership') === 0) {
        return true;
      }
      headerBudget++;
      if (headerBudget > 100) break;
    }
    return false;
  }

  function scanArticlesForAdAttrs(root) {
    var scope = root || document;
    var articles = scope.querySelectorAll ? scope.querySelectorAll('article') : [];
    var out = [];
    for (var i = 0; i < articles.length; i++) {
      var a = articles[i];
      if (a.getAttribute(FEED_MARK) === '1') continue;
      if (articleLooksSponsored(a)) out.push(a);
    }
    return out;
  }

  function dismissChromeNags() {
    try {
      var nodes = document.querySelectorAll('button, [role="button"], div[role="button"], a');
      for (var i = 0; i < nodes.length; i++) {
        var el = nodes[i];
        var t = normText(el.textContent);
        if (t === 'not now' || t === 'ok' || t === 'allow all cookies' || t === 'decline optional cookies') {
          el.click();
          return;
        }
      }
      // "Use the app" install banner — close via nearby x if present.
      for (var j = 0; j < nodes.length; j++) {
        var n = nodes[j];
        if (normText(n.textContent) !== 'use the app') continue;
        var wrap = n.parentElement;
        for (var d = 0; d < 4 && wrap; d++) {
          var closer = wrap.querySelector('[aria-label*="Close" i], [aria-label*="Dismiss" i], button');
          if (closer && closer !== n) {
            closer.click();
            return;
          }
          wrap = wrap.parentElement;
        }
      }
    } catch (e) {}
  }

  function applyFeedHide() {
    try {
      dismissChromeNags();
      if (window.__msaFeedHide && window.__msaFeedHide.enabled === false) {
        reinforceCollapsed();
        return;
      }
      ensureStyle();
      reinforceCollapsed();

      var hiddenNow = 0;
      var hits = scanLabelNodes(document);
      for (var i = 0; i < hits.length; i++) {
        var hit = hits[i];
        var unit = findFeedUnit(hit.el);
        if (!unit) continue;
        if (unit.getAttribute(FEED_MARK) === '1') continue;
        if (!labelInHeaderBand(hit.el, unit) && hit.reason !== 'suggested-section') continue;
        if (collapseUnit(unit, hit.reason)) {
          hiddenNow++;
          if (window.__msaFeedHide) {
            window.__msaFeedHide.stats.hidden += 1;
            window.__msaFeedHide.stats.lastReasons.push(hit.reason + ':' + hit.text);
            if (window.__msaFeedHide.stats.lastReasons.length > 40) {
              window.__msaFeedHide.stats.lastReasons.shift();
            }
          }
        }
      }

      var adArticles = scanArticlesForAdAttrs(document);
      for (var j = 0; j < adArticles.length; j++) {
        if (collapseUnit(adArticles[j], 'ad-attr')) {
          hiddenNow++;
          if (window.__msaFeedHide) {
            window.__msaFeedHide.stats.hidden += 1;
            window.__msaFeedHide.stats.lastReasons.push('ad-attr');
          }
        }
      }

      if (window.__msaFeedHide) {
        window.__msaFeedHide.stats.scans += 1;
        window.__msaFeedHide.stats.lastHiddenBatch = hiddenNow;
      }
    } catch (e) {
      if (window.__msaFeedHide) {
        window.__msaFeedHide.stats.lastError = String((e && e.message) || e);
      }
    }
  }

  window.__msaFeedHide = {
    enabled: true,
    stats: { hidden: 0, scans: 0, lastHiddenBatch: 0, lastReasons: [], lastError: null },
    setEnabled: function (on) {
      this.enabled = !!on;
      if (this.enabled) applyFeedHide();
    },
    dump: function () {
      var labels = [];
      var hits = scanLabelNodes(document);
      for (var i = 0; i < hits.length; i++) {
        labels.push({ text: hits[i].text, reason: hits[i].reason });
      }
      var marked = document.querySelectorAll('[' + FEED_MARK + '="1"]');
      var reasons = [];
      for (var j = 0; j < marked.length; j++) {
        reasons.push(marked[j].getAttribute(FEED_REASON) || '?');
      }
      return {
        enabled: this.enabled,
        stats: this.stats,
        articleCount: document.querySelectorAll('article').length,
        markedCount: marked.length,
        markedReasons: reasons,
        liveLabelHits: labels,
        path: location.pathname,
        sampleText: (function () {
          try {
            var arts = document.querySelectorAll('article');
            var chunks = [];
            for (var k = 0; k < Math.min(arts.length, 4); k++) {
              chunks.push((arts[k].innerText || '').replace(/\s+/g, ' ').slice(0, 220));
            }
            return chunks;
          } catch (e) { return []; }
        })()
      };
    }
  };

  var scheduled = null;
  function schedule() {
    if (scheduled) return;
    scheduled = setTimeout(function () {
      scheduled = null;
      applyFeedHide();
    }, 60);
  }

  var mo = new MutationObserver(schedule);
  function start() {
    ensureStyle();
    applyFeedHide();
    try {
      mo.observe(document.documentElement, {
        childList: true,
        subtree: true,
        attributes: true,
        attributeFilter: ['class', 'style']
      });
    } catch (e) {}
  }

  if (document.documentElement) start();
  else document.addEventListener('DOMContentLoaded', start);

  window.addEventListener('resize', schedule);
  window.addEventListener('popstate', schedule);
  window.addEventListener('scroll', schedule, { passive: true });
  document.addEventListener('visibilitychange', schedule);
  setInterval(applyFeedHide, 900);
})();
"""#
}
