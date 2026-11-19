import Foundation

/// MSA-29: hide Instagram Meta AI entry points, AI badges/labels, assistant
/// surfaces, and AI-generated post chrome inside WKWebView.
/// Additive with MSA-16/18/19/21/22/23 scripts.
enum InstagramAIContentHide {
    /// Injected at document-start alongside other Instagram site tweaks.
    static let userScriptSource: String = #"""
(function () {
  if (window.__msaAIHideInstalled) return;
  window.__msaAIHideInstalled = true;

  var STYLE_ID = 'msa-hide-ai-content-style';
  var MARK = 'data-msa-ai-hide';
  var REASON = 'data-msa-ai-hide-reason';
  var enabled = true;

  // Exact / short chrome labels (normalized).
  var EXACT = {
    'meta ai': 'meta-ai',
    'ask meta ai': 'ask-meta-ai',
    'ask meta a.i.': 'ask-meta-ai',
    'try meta ai': 'try-meta-ai',
    'chat with meta ai': 'chat-meta-ai',
    'made with ai': 'made-with-ai',
    'imagined with ai': 'imagined-with-ai',
    'created with ai': 'created-with-ai',
    'generated with ai': 'generated-with-ai',
    'ai generated': 'ai-generated',
    'ai-generated': 'ai-generated',
    'ai info': 'ai-info',
    'about ai': 'ai-info',
    'ai sticker': 'ai-sticker',
    'ai stickers': 'ai-sticker',
    'ai studio': 'ai-studio',
    'meta ai studio': 'ai-studio',
    'edit with ai': 'edit-with-ai',
    'restyle with ai': 'edit-with-ai',
    'generate with ai': 'generate-with-ai',
    'create with ai': 'generate-with-ai',
    'write with ai': 'write-with-ai',
    'suggested by ai': 'suggested-by-ai',
    'ai creations': 'ai-creations',
    'ai creation': 'ai-creations'
  };

  var CONTAINS = [
    { re: /\bmeta\s*ai\b/, reason: 'meta-ai' },
    { re: /\bask meta ai\b/, reason: 'ask-meta-ai' },
    { re: /\btry meta ai\b/, reason: 'try-meta-ai' },
    { re: /\bchat with meta ai\b/, reason: 'chat-meta-ai' },
    { re: /\bmade with ai\b/, reason: 'made-with-ai' },
    { re: /\bimagined with ai\b/, reason: 'imagined-with-ai' },
    { re: /\b(created|generated) with ai\b/, reason: 'generated-with-ai' },
    { re: /\bai[-\s]?generated\b/, reason: 'ai-generated' },
    { re: /\bai info\b/, reason: 'ai-info' },
    { re: /\bai sticker(s)?\b/, reason: 'ai-sticker' },
    { re: /\b(meta )?ai studio\b/, reason: 'ai-studio' },
    { re: /\b(edit|restyle|rewrite) with ai\b/, reason: 'edit-with-ai' },
    { re: /\b(generate|create|write) with ai\b/, reason: 'generate-with-ai' },
    { re: /\bsuggested by ai\b/, reason: 'suggested-by-ai' },
    { re: /\bai creation(s)?\b/, reason: 'ai-creations' },
    { re: /\bimagine with (meta )?ai\b/, reason: 'imagine-with-ai' }
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
      if (r.height > 0 && r.height < 88 && r.top > window.innerHeight - 100) {
        if (el.querySelector && el.querySelector('a[href="/"], a[href="/explore/"], a[href*="/direct"]')) {
          return true;
        }
      }
    } catch (e) {}
    return false;
  }

  function matchAIText(raw) {
    var t = normText(raw);
    if (!t || t.length > 96) return null;
    if (EXACT[t]) return EXACT[t];
    // Bare "ai" alone is too risky — require product phrases.
    if (t.length > 72) return null;
    for (var i = 0; i < CONTAINS.length; i++) {
      if (CONTAINS[i].re.test(t)) return CONTAINS[i].reason;
    }
    return null;
  }

  function looksLikeAIHref(href) {
    if (!href) return false;
    var h = String(href).toLowerCase();
    return (
      h.indexOf('meta.ai') !== -1 ||
      h.indexOf('/ai/') !== -1 ||
      h.indexOf('/aistudio') !== -1 ||
      h.indexOf('ai.meta') !== -1 ||
      h.indexOf('imaginea.meta') !== -1 ||
      /[?&]ai[_=]/.test(h) ||
      h.indexOf('meta_ai') !== -1
    );
  }

  function collapse(el, reason) {
    if (!el || el === document.body || el === document.documentElement) return false;
    if (el.getAttribute(MARK) === '1') return false;
    if (isInBottomNav(el)) return false;
    el.setAttribute(MARK, '1');
    el.setAttribute(REASON, reason || 'ai');
    try {
      el.style.setProperty('display', 'none', 'important');
      el.style.setProperty('visibility', 'hidden', 'important');
      el.style.setProperty('pointer-events', 'none', 'important');
      el.style.setProperty('height', '0', 'important');
      el.style.setProperty('max-height', '0', 'important');
      el.style.setProperty('opacity', '0', 'important');
      el.style.setProperty('overflow', 'hidden', 'important');
    } catch (e) {}
    if (window.__msaAIHide) {
      window.__msaAIHide.stats.hidden += 1;
      window.__msaAIHide.stats.lastReasons.push(reason || 'ai');
      if (window.__msaAIHide.stats.lastReasons.length > 40) {
        window.__msaAIHide.stats.lastReasons.shift();
      }
    }
    return true;
  }

  function findChromeRoot(el) {
    var best = el;
    var n = el;
    for (var d = 0; d < 10 && n && n !== document.body; d++) {
      try {
        var tag = (n.tagName || '').toLowerCase();
        if (tag === 'article') return n;
        var role = (n.getAttribute && n.getAttribute('role')) || '';
        if (role === 'dialog' || role === 'alertdialog' || role === 'article') {
          if (!isInBottomNav(n)) return n;
        }
        var r = n.getBoundingClientRect();
        var st = window.getComputedStyle(n);
        var fixedish =
          st.position === 'fixed' ||
          st.position === 'sticky' ||
          st.position === 'absolute';
        var shortBar = r.height > 18 && r.height < 140 && r.width > window.innerWidth * 0.35;
        var nearTop = r.top < 140 && r.height < 140;
        var nearBottom = r.bottom > window.innerHeight - 180;
        var overlay =
          fixedish &&
          r.width > window.innerWidth * 0.5 &&
          r.height > 60 &&
          r.height < window.innerHeight * 0.95;
        if ((shortBar && (nearTop || nearBottom || fixedish)) || overlay) {
          if (!isInBottomNav(n)) best = n;
        }
      } catch (e) {}
      n = n.parentElement;
    }
    return best;
  }

  function findPostRoot(el) {
    var n = el;
    for (var d = 0; d < 14 && n && n !== document.body; d++) {
      var tag = (n.tagName || '').toLowerCase();
      if (tag === 'article') return n;
      var role = (n.getAttribute && n.getAttribute('role')) || '';
      if (role === 'article') return n;
      n = n.parentElement;
    }
    return findChromeRoot(el);
  }

  function isPostLabelReason(reason) {
    return (
      reason === 'made-with-ai' ||
      reason === 'imagined-with-ai' ||
      reason === 'generated-with-ai' ||
      reason === 'created-with-ai' ||
      reason === 'ai-generated' ||
      reason === 'ai-info' ||
      reason === 'ai-sticker' ||
      reason === 'suggested-by-ai' ||
      reason === 'ai-creations'
    );
  }

  function scanTextTriggers(root) {
    var out = [];
    var nodes = root.querySelectorAll(
      'a, button, [role="button"], span, div, p, h1, h2, h3, h4, label, svg title'
    );
    for (var i = 0; i < nodes.length; i++) {
      var el = nodes[i];
      if (el.getAttribute && el.getAttribute(MARK) === '1') continue;
      if (isInBottomNav(el)) continue;
      var own = '';
      try {
        for (var c = 0; c < el.childNodes.length; c++) {
          var ch = el.childNodes[c];
          if (ch.nodeType === 3) own += ch.nodeValue || '';
        }
        if (!own) own = el.getAttribute('aria-label') || '';
        if (!own && el.childElementCount === 0) own = el.textContent || '';
      } catch (e) {
        own = el.textContent || '';
      }
      var reason = matchAIText(own);
      if (!reason) {
        var aria = matchAIText(el.getAttribute && el.getAttribute('aria-label'));
        if (aria) reason = aria;
      }
      if (!reason) {
        var title = matchAIText(el.getAttribute && el.getAttribute('title'));
        if (title) reason = title;
      }
      if (!reason) continue;
      var full = normText(el.textContent);
      // Guard: long caption that merely mentions AI once — skip unless label-like reason.
      if (full.length > 90 && !isPostLabelReason(reason) && reason !== 'meta-ai') continue;
      out.push({ el: el, reason: reason });
    }
    return out;
  }

  function scanAIHrefs(root) {
    var out = [];
    var links = root.querySelectorAll('a[href], [role="link"]');
    for (var i = 0; i < links.length; i++) {
      var a = links[i];
      if (a.getAttribute(MARK) === '1') continue;
      if (isInBottomNav(a)) continue;
      var href = a.getAttribute('href') || '';
      if (!looksLikeAIHref(href)) continue;
      out.push({ el: a, reason: 'ai-href' });
    }
    return out;
  }

  function scanArticlesForAI(root) {
    var out = [];
    var articles = root.querySelectorAll
      ? root.querySelectorAll('article, [role="article"]')
      : [];
    for (var i = 0; i < articles.length; i++) {
      var a = articles[i];
      if (a.getAttribute(MARK) === '1') continue;
      var head = normText((a.innerText || a.textContent || '').slice(0, 280));
      if (
        head.indexOf('made with ai') !== -1 ||
        head.indexOf('imagined with ai') !== -1 ||
        head.indexOf('generated with ai') !== -1 ||
        head.indexOf('created with ai') !== -1 ||
        head.indexOf('ai-generated') !== -1 ||
        head.indexOf('ai generated') !== -1 ||
        head.indexOf('suggested by ai') !== -1
      ) {
        out.push({ el: a, reason: 'ai-article' });
        continue;
      }
      var nodes = a.querySelectorAll('span, a, div, button, [role="button"]');
      for (var j = 0; j < nodes.length; j++) {
        var full = nodes[j].textContent || '';
        if (full.length === 0 || full.length > 48) continue;
        var reason = matchAIText(full);
        if (reason && isPostLabelReason(reason)) {
          out.push({ el: a, reason: reason });
          break;
        }
      }
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

  function applyAIHide() {
    try {
      if (!enabled) {
        reinforceHidden();
        return;
      }
      ensureStyle();
      reinforceHidden();

      var hiddenNow = 0;
      var hits = scanTextTriggers(document);
      for (var i = 0; i < hits.length; i++) {
        var root = isPostLabelReason(hits[i].reason)
          ? findPostRoot(hits[i].el)
          : findChromeRoot(hits[i].el);
        if (collapse(root, hits[i].reason)) hiddenNow++;
      }

      var hrefHits = scanAIHrefs(document);
      for (var j = 0; j < hrefHits.length; j++) {
        var hrefRoot = findChromeRoot(hrefHits[j].el);
        if (collapse(hrefRoot, hrefHits[j].reason)) hiddenNow++;
      }

      var articles = scanArticlesForAI(document);
      for (var k = 0; k < articles.length; k++) {
        if (collapse(articles[k].el, articles[k].reason)) hiddenNow++;
      }

      if (window.__msaAIHide) {
        window.__msaAIHide.stats.scans += 1;
        window.__msaAIHide.stats.lastHiddenBatch = hiddenNow;
        window.__msaAIHide.stats.visibleAIText = liveAILabels();
      }
    } catch (e) {
      if (window.__msaAIHide) {
        window.__msaAIHide.stats.lastError = String((e && e.message) || e);
      }
    }
  }

  function liveAILabels() {
    var labels = [];
    var nodes = document.querySelectorAll(
      'a, button, [role="button"], span, div, h1, h2, h3'
    );
    for (var i = 0; i < nodes.length && labels.length < 40; i++) {
      var el = nodes[i];
      if (el.getAttribute(MARK) === '1') continue;
      if (isInBottomNav(el)) continue;
      try {
        var r = el.getBoundingClientRect();
        if (r.width < 6 || r.height < 6) continue;
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
      var reason = matchAIText(own);
      if (!reason) continue;
      if (normText(el.textContent).length > 90) continue;
      labels.push({ text: normText(own).slice(0, 56), reason: reason });
    }
    return labels;
  }

  function revealAll() {
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

  function simulateAIMarkers(delayMs) {
    try {
      var host =
        document.querySelector('article') ||
        document.querySelector('[role="main"]') ||
        document.body;
      if (!host) return 'no_host';
      var chip = document.createElement('div');
      chip.setAttribute('data-msa-ai-sim', '1');
      chip.setAttribute('role', 'button');
      chip.textContent = 'Made with AI';
      chip.style.cssText =
        'position:fixed;z-index:2147483646;left:12px;top:96px;' +
        'padding:8px 12px;border-radius:8px;background:#111;color:#fff;' +
        'font:600 13px/1.2 -apple-system,sans-serif;';
      document.documentElement.appendChild(chip);

      var entry = document.createElement('a');
      entry.setAttribute('data-msa-ai-sim', '1');
      entry.href = 'https://www.meta.ai/';
      entry.textContent = 'Ask Meta AI';
      entry.style.cssText =
        'position:fixed;z-index:2147483646;right:12px;top:96px;' +
        'padding:8px 12px;border-radius:8px;background:#222;color:#fff;' +
        'font:600 13px/1.2 -apple-system,sans-serif;';
      document.documentElement.appendChild(entry);

      var wait = typeof delayMs === 'number' ? delayMs : 2000;
      setTimeout(function () {
        applyAIHide();
      }, wait);
      return 'planted:' + wait;
    } catch (e) {
      return String(e);
    }
  }

  window.__msaAIHide = {
    enabled: true,
    stats: {
      hidden: 0,
      scans: 0,
      lastHiddenBatch: 0,
      lastReasons: [],
      lastError: null,
      visibleAIText: []
    },
    setEnabled: function (on) {
      enabled = !!on;
      this.enabled = enabled;
      if (enabled) {
        applyAIHide();
      } else {
        revealAll();
      }
      return enabled;
    },
    isEnabled: function () { return enabled; },
    simulateAI: simulateAIMarkers,
    dump: function () {
      try {
        applyAIHide();
      } catch (e) {}
      var marked = document.querySelectorAll('[' + MARK + '="1"]');
      var reasons = [];
      for (var i = 0; i < marked.length; i++) {
        reasons.push(marked[i].getAttribute(REASON) || '?');
      }
      return {
        enabled: enabled,
        stats: this.stats,
        markedCount: marked.length,
        markedReasons: reasons,
        visibleAIText: liveAILabels(),
        scriptCanary: 'aihide-v1',
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
      applyAIHide();
    }, 50);
  }

  var mo = new MutationObserver(schedule);
  function start() {
    ensureStyle();
    applyAIHide();
    try {
      mo.observe(document.documentElement, {
        childList: true,
        subtree: true,
        attributes: true,
        attributeFilter: ['class', 'style', 'href', 'aria-label', 'title']
      });
    } catch (e) {}
  }

  if (document.documentElement) start();
  else document.addEventListener('DOMContentLoaded', start);

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
  setInterval(applyAIHide, 700);
})();
"""#

    /// Evaluate in WKWebView to dump AI-hide state as JSON string.
    static let dumpScript: String = #"""
(function () {
  try {
    if (window.__msaAIHide && window.__msaAIHide.dump) {
      return JSON.stringify(window.__msaAIHide.dump());
    }
    return JSON.stringify({ error: 'ai_hide_missing', installed: !!window.__msaAIHideInstalled });
  } catch (e) {
    return JSON.stringify({ error: String(e) });
  }
})()
"""#
}
