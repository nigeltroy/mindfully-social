import Foundation

/// MSA-29 / MSA-31: hide Instagram Meta AI entry points, AI badges/labels,
/// assistant surfaces, AI stickers, and AI-labeled feed/explore/story cards
/// inside WKWebView. Prefer whole post/card collapse over half-broken UI.
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
  var SCRIPT_CANARY = 'aihide-v3';
  var enabled = true;

  // Exact / short chrome labels (normalized).
  var EXACT = {
    'meta ai': 'meta-ai',
    'ask meta ai': 'ask-meta-ai',
    'ask meta a.i.': 'ask-meta-ai',
    'ask ai': 'ask-meta-ai',
    'ask meta': 'ask-meta-ai',
    'try meta ai': 'try-meta-ai',
    'chat with meta ai': 'chat-meta-ai',
    'talk to meta ai': 'chat-meta-ai',
    'open meta ai': 'meta-ai',
    'use meta ai': 'meta-ai',
    'get meta ai': 'meta-ai',
    'go to meta ai': 'meta-ai',
    'made with ai': 'made-with-ai',
    'made by ai': 'made-with-ai',
    'imagined with ai': 'imagined-with-ai',
    'imagined with meta ai': 'imagined-with-ai',
    'created with ai': 'created-with-ai',
    'generated with ai': 'generated-with-ai',
    'ai generated': 'ai-generated',
    'ai-generated': 'ai-generated',
    'contains ai': 'ai-generated',
    'contains ai-generated content': 'ai-generated',
    'ai may be used': 'ai-info',
    'ai info': 'ai-info',
    'about ai': 'ai-info',
    'about this ai': 'ai-info',
    'ai label': 'ai-info',
    'this media was created using ai': 'ai-info',
    'this media may have been created or edited using ai': 'ai-info',
    'created using ai': 'generated-with-ai',
    'edited using ai': 'ai-info',
    'modified using ai': 'ai-info',
    'ai sticker': 'ai-sticker',
    'ai stickers': 'ai-sticker',
    'add ai sticker': 'ai-sticker',
    'ai stickers tray': 'ai-sticker',
    'ai studio': 'ai-studio',
    'meta ai studio': 'ai-studio',
    'edit with ai': 'edit-with-ai',
    'restyle with ai': 'edit-with-ai',
    'rewrite with ai': 'edit-with-ai',
    'generate with ai': 'generate-with-ai',
    'create with ai': 'generate-with-ai',
    'write with ai': 'write-with-ai',
    'suggested by ai': 'suggested-by-ai',
    'ai creations': 'ai-creations',
    'ai creation': 'ai-creations',
    'ai art': 'ai-creations',
    'imagine with ai': 'imagine-with-ai',
    'imagine with meta ai': 'imagine-with-ai',
    'ask meta ai or search': 'ask-meta-ai',
    'ask meta ai or search…': 'ask-meta-ai',
    'ask meta ai or search...': 'ask-meta-ai',
    'search with meta ai': 'ask-meta-ai'
  };

  var CONTAINS = [
    { re: /\bask meta\s*a\.?i\.?\b/, reason: 'ask-meta-ai' },
    { re: /\bask meta ai or search\b/, reason: 'ask-meta-ai' },
    { re: /\bsearch with meta ai\b/, reason: 'ask-meta-ai' },
    { re: /\btry meta\s*a\.?i\.?\b/, reason: 'try-meta-ai' },
    { re: /\b(chat|talk) with meta\s*a\.?i\.?\b/, reason: 'chat-meta-ai' },
    { re: /\b(open|use|get|go to)\s+meta\s*a\.?i\.?\b/, reason: 'meta-ai' },
    { re: /\bmeta\s*a\.?i\.?\b/, reason: 'meta-ai' },
    { re: /\bmade (with|by) ai\b/, reason: 'made-with-ai' },
    { re: /\bimagined with (meta\s*)?ai\b/, reason: 'imagined-with-ai' },
    { re: /\b(created|generated) with ai\b/, reason: 'generated-with-ai' },
    { re: /\bai[-\s]?generated\b/, reason: 'ai-generated' },
    { re: /\bcontains ai([-\s]generated)?( content)?\b/, reason: 'ai-generated' },
    { re: /\bai may be used\b/, reason: 'ai-info' },
    { re: /\b(ai info|about (this )?ai|ai label)\b/, reason: 'ai-info' },
    { re: /\bthis media (was created|may have been created or edited) using ai\b/, reason: 'ai-info' },
    { re: /\b(created|edited|modified) using ai\b/, reason: 'ai-info' },
    { re: /\bai sticker(s)?\b/, reason: 'ai-sticker' },
    { re: /\badd ai sticker\b/, reason: 'ai-sticker' },
    { re: /\b(meta )?ai studio\b/, reason: 'ai-studio' },
    { re: /\b(edit|restyle|rewrite) with ai\b/, reason: 'edit-with-ai' },
    { re: /\b(generate|create|write) with ai\b/, reason: 'generate-with-ai' },
    { re: /\bsuggested by ai\b/, reason: 'suggested-by-ai' },
    { re: /\bai creation(s)?\b/, reason: 'ai-creations' },
    { re: /\bai art\b/, reason: 'ai-creations' },
    { re: /\bimagine with (meta\s*)?ai\b/, reason: 'imagine-with-ai' }
  ];

  function normText(s) {
    return String(s || '')
      .replace(/\u2026/g, '...')
      .replace(/\s+/g, ' ')
      .trim()
      .toLowerCase();
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
    if (!t || t.length > 120) return null;
    if (EXACT[t]) return EXACT[t];
    // Bare "ai" alone is too risky — require product phrases.
    if (t.length > 96) return null;
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
      h.indexOf('www.meta.ai') !== -1 ||
      h.indexOf('/ai/') !== -1 ||
      h.indexOf('/aistudio') !== -1 ||
      h.indexOf('ai.meta') !== -1 ||
      h.indexOf('imaginea.meta') !== -1 ||
      h.indexOf('imagine.meta') !== -1 ||
      /[?&]ai[_=]/.test(h) ||
      h.indexOf('meta_ai') !== -1 ||
      h.indexOf('meta-ai') !== -1 ||
      h.indexOf('/meta_ai') !== -1
    );
  }

  function isPageShell(el) {
    if (!el || el === document || el === document.documentElement || el === document.body) {
      return true;
    }
    try {
      var tag = (el.tagName || '').toLowerCase();
      if (tag === 'html' || tag === 'body' || tag === 'main' || tag === 'head') return true;
      if (el.getAttribute && el.getAttribute('role') === 'main') return true;
      // Full-viewport shell (never collapse / never promote into).
      var r = el.getBoundingClientRect && el.getBoundingClientRect();
      if (
        r &&
        r.width >= window.innerWidth * 0.95 &&
        r.height >= window.innerHeight * 0.9
      ) {
        return true;
      }
    } catch (e) {}
    return false;
  }

  function collapse(el, reason) {
    if (!el || isPageShell(el)) return false;
    if (el.getAttribute(MARK) === '1') return false;
    if (isInBottomNav(el)) return false;
    el.setAttribute(MARK, '1');
    el.setAttribute(REASON, reason || 'ai');
    el.setAttribute('aria-hidden', 'true');
    try {
      el.style.setProperty('display', 'none', 'important');
      el.style.setProperty('visibility', 'hidden', 'important');
      el.style.setProperty('pointer-events', 'none', 'important');
      el.style.setProperty('height', '0', 'important');
      el.style.setProperty('max-height', '0', 'important');
      el.style.setProperty('min-height', '0', 'important');
      el.style.setProperty('opacity', '0', 'important');
      el.style.setProperty('overflow', 'hidden', 'important');
      el.style.setProperty('margin', '0', 'important');
      el.style.setProperty('padding', '0', 'important');
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

  function isSubstantialCard(n) {
    if (!n || isPageShell(n) || !n.getBoundingClientRect) return false;
    try {
      var r = n.getBoundingClientRect();
      var minW = Math.min(240, window.innerWidth * 0.55);
      // Tall enough to be a post/tile (not a 24px chip); not the page shell.
      if (r.width >= window.innerWidth * 0.95 && r.height >= window.innerHeight * 0.85) {
        return false;
      }
      return r.width >= minW && r.height >= 72;
    } catch (e) {
      return false;
    }
  }

  function findExploreTile(el) {
    var n = el;
    for (var d = 0; d < 12 && n && !isPageShell(n); d++) {
      try {
        var tag = (n.tagName || '').toLowerCase();
        if (tag === 'a') {
          var href = (n.getAttribute('href') || '').toLowerCase();
          if (
            href.indexOf('/p/') !== -1 ||
            href.indexOf('/reel/') !== -1 ||
            href.indexOf('/tv/') !== -1
          ) {
            // Prefer the grid cell wrapper when the <a> is only the media —
            // but never promote into html/body (fixed sim tiles append there).
            var parent = n.parentElement;
            if (
              parent &&
              !isPageShell(parent) &&
              isSubstantialCard(parent) &&
              parent.children.length <= 4
            ) {
              return parent;
            }
            return n;
          }
        }
        // Explore masonry cell: wide-ish sibling in a multi-child row.
        if (isSubstantialCard(n)) {
          var p = n.parentElement;
          if (
            p &&
            !isPageShell(p) &&
            p.children &&
            p.children.length >= 2 &&
            p.children.length <= 12
          ) {
            var media =
              n.querySelector &&
              n.querySelector('img, video, a[href*="/p/"], a[href*="/reel/"]');
            if (media) return n;
          }
        }
      } catch (e) {}
      n = n.parentElement;
    }
    return null;
  }

  function findStoryRoot(el) {
    var n = el;
    for (var d = 0; d < 14 && n && n !== document.body; d++) {
      try {
        var aria = normText((n.getAttribute && n.getAttribute('aria-label')) || '');
        var role = (n.getAttribute && n.getAttribute('role')) || '';
        if (aria.indexOf('story') !== -1 && isSubstantialCard(n)) return n;
        if (role === 'dialog' || role === 'presentation') {
          var path = (location.pathname || '').toLowerCase();
          if (path.indexOf('/stories/') !== -1 && isSubstantialCard(n)) return n;
        }
        // Section-sized story viewer pane.
        var r = n.getBoundingClientRect();
        if (
          r.height > window.innerHeight * 0.55 &&
          r.width > window.innerWidth * 0.45 &&
          (location.pathname || '').indexOf('/stories/') !== -1
        ) {
          return n;
        }
      } catch (e) {}
      n = n.parentElement;
    }
    return null;
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

  /// Whole feed/explore/story card — avoids orphaned headers / black voids.
  function findCardRoot(el) {
    if (!el) return null;
    var n = el;
    for (var d = 0; d < 16 && n && !isPageShell(n); d++) {
      var tag = (n.tagName || '').toLowerCase();
      if (tag === 'article') return n;
      var role = (n.getAttribute && n.getAttribute('role')) || '';
      if (role === 'article') return n;
      n = n.parentElement;
    }

    var story = findStoryRoot(el);
    if (story && !isPageShell(story)) return story;

    var tile = findExploreTile(el);
    if (tile && !isPageShell(tile)) return tile;

    // Feed-unit climb (same idea as MSA-18): wide sibling block.
    n = el;
    for (var depth = 0; depth < 14 && n && !isPageShell(n); depth++) {
      try {
        var r = n.getBoundingClientRect();
        var minW = Math.min(280, window.innerWidth * 0.7);
        if (r && r.height >= 96 && r.width >= minW && !isPageShell(n)) {
          var parent = n.parentElement;
          if (parent && !isPageShell(parent) && parent.children && parent.children.length >= 2) {
            // Prefer a unit that looks like header+media, not media alone.
            var hasHeaderish =
              n.querySelector &&
              n.querySelector('header, h2, a[role="link"], img[alt], [aria-label]');
            if (hasHeaderish || r.height >= 180) return n;
          }
        }
      } catch (e) {}
      n = n.parentElement;
    }
    return null;
  }

  function findPostRoot(el) {
    return findCardRoot(el) || findChromeRoot(el);
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
      reason === 'ai-creations' ||
      reason === 'ai-article' ||
      reason === 'ai-card' ||
      reason === 'imagine-with-ai'
    );
  }

  function isEntryPointReason(reason) {
    return (
      reason === 'meta-ai' ||
      reason === 'ask-meta-ai' ||
      reason === 'try-meta-ai' ||
      reason === 'chat-meta-ai' ||
      reason === 'ai-href' ||
      reason === 'ai-studio' ||
      reason === 'edit-with-ai' ||
      reason === 'generate-with-ai' ||
      reason === 'write-with-ai'
    );
  }

  /// Whole card for AI-labeled posts/tiles; chrome-only for floating Meta AI bars.
  function pickRoot(el, reason) {
    var root = null;
    if (isPostLabelReason(reason)) {
      root = findPostRoot(el);
    } else if (isEntryPointReason(reason)) {
      // Only escalate to a card when the hit is already nested in one —
      // never promote a top search/FAB into a full header collapse.
      var n = el;
      for (var d = 0; d < 16 && n && !isPageShell(n); d++) {
        var tag = (n.tagName || '').toLowerCase();
        if (tag === 'article') {
          root = n;
          break;
        }
        var role = (n.getAttribute && n.getAttribute('role')) || '';
        if (role === 'article') {
          root = n;
          break;
        }
        n = n.parentElement;
      }
      if (!root) {
        var tile = findExploreTile(el);
        if (tile && !isPageShell(tile)) root = tile;
      }
      if (!root) {
        var story = findStoryRoot(el);
        if (story && !isPageShell(story)) root = story;
      }
      if (!root) root = findChromeRoot(el);
    } else {
      root = findChromeRoot(el);
    }
    // If climb hit the page shell, hide the matched node itself (sim tiles,
    // fixed chips) so Made with AI never survives a failed whole-card collapse.
    if (!root || isPageShell(root)) return el;
    return root;
  }

  function collapseHit(el, reason) {
    var root = pickRoot(el, reason);
    if (collapse(root, reason)) return true;
    if (root !== el && collapse(el, reason)) return true;
    return false;
  }

  function ownVisibleText(el) {
    var own = '';
    try {
      for (var c = 0; c < el.childNodes.length; c++) {
        var ch = el.childNodes[c];
        if (ch.nodeType === 3) own += ch.nodeValue || '';
      }
      if (!own) own = el.getAttribute('aria-label') || '';
      if (!own) own = el.getAttribute('alt') || '';
      if (!own) own = el.getAttribute('title') || '';
      if (!own) own = el.getAttribute('placeholder') || '';
      if (!own && el.childElementCount === 0) own = el.textContent || '';
      // Shallow nested label (span > span).
      if (!own && el.childElementCount === 1) {
        var only = el.firstElementChild;
        if (only && only.childElementCount === 0) {
          own = only.textContent || only.getAttribute('aria-label') || '';
        }
      }
    } catch (e) {
      own = el.textContent || '';
    }
    return own;
  }

  function scanTextTriggers(root) {
    var out = [];
    var nodes = root.querySelectorAll(
      'a, button, [role="button"], [role="link"], span, div, p, h1, h2, h3, h4, label, input, textarea, img, svg title, [aria-label], [placeholder]'
    );
    for (var i = 0; i < nodes.length; i++) {
      var el = nodes[i];
      if (el.getAttribute && el.getAttribute(MARK) === '1') continue;
      if (isInBottomNav(el)) continue;
      var own = ownVisibleText(el);
      var reason = matchAIText(own);
      if (!reason) {
        var aria = matchAIText(el.getAttribute && el.getAttribute('aria-label'));
        if (aria) reason = aria;
      }
      if (!reason) {
        var title = matchAIText(el.getAttribute && el.getAttribute('title'));
        if (title) reason = title;
      }
      if (!reason) {
        var alt = matchAIText(el.getAttribute && el.getAttribute('alt'));
        if (alt) reason = alt;
      }
      if (!reason) {
        var ph = matchAIText(el.getAttribute && el.getAttribute('placeholder'));
        if (ph) reason = ph;
      }
      if (!reason) continue;
      var full = normText(el.textContent);
      // Guard: long caption that merely mentions AI once — skip unless label-like.
      if (full.length > 100 && !isPostLabelReason(reason) && reason !== 'meta-ai' && reason !== 'ask-meta-ai') {
        continue;
      }
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

  function articleOrCardLooksAI(node) {
    if (!node) return null;
    var head = normText((node.innerText || node.textContent || '').slice(0, 360));
    var keys = [
      'made with ai',
      'made by ai',
      'imagined with ai',
      'generated with ai',
      'created with ai',
      'ai-generated',
      'ai generated',
      'contains ai',
      'suggested by ai',
      'ai sticker',
      'ask meta ai',
      'meta ai'
    ];
    for (var i = 0; i < keys.length; i++) {
      if (head.indexOf(keys[i]) !== -1) {
        if (keys[i] === 'meta ai' || keys[i] === 'ask meta ai') {
          // Only treat as card-AI when the phrase is a short chrome node inside.
          var nodes = node.querySelectorAll('span, a, div, button, [role="button"], img');
          for (var j = 0; j < nodes.length; j++) {
            var full = nodes[j].textContent || nodes[j].getAttribute('aria-label') || '';
            if (full.length === 0 || full.length > 56) continue;
            var reason = matchAIText(full);
            if (reason) return reason;
          }
          continue;
        }
        return 'ai-card';
      }
    }
    var nodes2 = node.querySelectorAll(
      'span, a, div, button, [role="button"], img, [aria-label]'
    );
    for (var k = 0; k < nodes2.length; k++) {
      var t =
        nodes2[k].textContent ||
        nodes2[k].getAttribute('aria-label') ||
        nodes2[k].getAttribute('alt') ||
        '';
      if (t.length === 0 || t.length > 56) continue;
      var r = matchAIText(t);
      if (r && (isPostLabelReason(r) || r === 'ask-meta-ai' || r === 'meta-ai' || r === 'ai-sticker')) {
        return r;
      }
    }
    return null;
  }

  function scanArticlesForAI(root) {
    var out = [];
    var articles = root.querySelectorAll
      ? root.querySelectorAll('article, [role="article"]')
      : [];
    for (var i = 0; i < articles.length; i++) {
      var a = articles[i];
      if (a.getAttribute(MARK) === '1') continue;
      var reason = articleOrCardLooksAI(a);
      if (reason) out.push({ el: a, reason: reason });
    }
    return out;
  }

  function scanExploreTilesForAI(root) {
    var out = [];
    if (!root.querySelectorAll) return out;
    var tiles = root.querySelectorAll(
      'a[href*="/p/"], a[href*="/reel/"], a[href*="/tv/"]'
    );
    var seen = [];
    for (var i = 0; i < tiles.length; i++) {
      var tile = findExploreTile(tiles[i]) || tiles[i];
      if (!tile || tile.getAttribute(MARK) === '1') continue;
      if (seen.indexOf(tile) !== -1) continue;
      seen.push(tile);
      var reason = articleOrCardLooksAI(tile);
      if (reason) out.push({ el: tile, reason: reason });
    }
    return out;
  }

  function scanStorySurfacesForAI(root) {
    var out = [];
    if (!root.querySelectorAll) return out;
    var path = (location.pathname || '').toLowerCase();
    var inStories = path.indexOf('/stories/') !== -1;
    var candidates = root.querySelectorAll(
      '[aria-label*="story"], [aria-label*="Story"], section, [role="dialog"]'
    );
    for (var i = 0; i < candidates.length; i++) {
      var c = candidates[i];
      if (c.getAttribute(MARK) === '1') continue;
      if (!inStories && !isSubstantialCard(c)) continue;
      var reason = articleOrCardLooksAI(c);
      if (!reason) continue;
      var rootEl = findStoryRoot(c) || c;
      if (isSubstantialCard(rootEl) || inStories) {
        out.push({ el: rootEl, reason: reason });
      }
    }
    // Stickers / Meta AI buttons floating in story chrome.
    if (inStories) {
      var hits = scanTextTriggers(document);
      for (var j = 0; j < hits.length; j++) {
        if (hits[j].reason === 'ai-sticker' || hits[j].reason === 'meta-ai' || hits[j].reason === 'ask-meta-ai') {
          var sr = findStoryRoot(hits[j].el) || pickRoot(hits[j].el, hits[j].reason);
          out.push({ el: sr, reason: hits[j].reason });
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
        marked[i].style.setProperty('height', '0', 'important');
        marked[i].style.setProperty('max-height', '0', 'important');
        marked[i].style.setProperty('opacity', '0', 'important');
        marked[i].style.setProperty('overflow', 'hidden', 'important');
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
        if (collapseHit(hits[i].el, hits[i].reason)) hiddenNow++;
      }

      var hrefHits = scanAIHrefs(document);
      for (var j = 0; j < hrefHits.length; j++) {
        if (collapseHit(hrefHits[j].el, hrefHits[j].reason)) hiddenNow++;
      }

      var articles = scanArticlesForAI(document);
      for (var k = 0; k < articles.length; k++) {
        if (collapse(articles[k].el, articles[k].reason)) hiddenNow++;
      }

      var tiles = scanExploreTilesForAI(document);
      for (var t = 0; t < tiles.length; t++) {
        if (collapse(tiles[t].el, tiles[t].reason)) hiddenNow++;
      }

      var stories = scanStorySurfacesForAI(document);
      for (var s = 0; s < stories.length; s++) {
        if (collapse(stories[s].el, stories[s].reason)) hiddenNow++;
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

  function isMarkedAncestor(el) {
    var n = el;
    while (n && n !== document.body) {
      if (n.getAttribute && n.getAttribute(MARK) === '1') return true;
      n = n.parentElement;
    }
    return false;
  }

  function liveAILabels() {
    var labels = [];
    var nodes = document.querySelectorAll(
      'a, button, [role="button"], span, div, h1, h2, h3, img, input, [aria-label], [placeholder]'
    );
    for (var i = 0; i < nodes.length && labels.length < 40; i++) {
      var el = nodes[i];
      if (el.getAttribute(MARK) === '1') continue;
      if (isMarkedAncestor(el)) continue;
      if (isInBottomNav(el)) continue;
      try {
        var r = el.getBoundingClientRect();
        if (r.width < 6 || r.height < 6) continue;
        if (r.bottom < 0 || r.top > window.innerHeight) continue;
        var st = window.getComputedStyle(el);
        if (st.display === 'none' || st.visibility === 'hidden' || st.opacity === '0') continue;
      } catch (e) {
        continue;
      }
      var own = ownVisibleText(el);
      var reason = matchAIText(own);
      if (!reason) {
        reason =
          matchAIText(el.getAttribute('aria-label')) ||
          matchAIText(el.getAttribute('alt')) ||
          matchAIText(el.getAttribute('placeholder'));
      }
      if (!reason) continue;
      if (normText(el.textContent).length > 100) continue;
      labels.push({ text: normText(own || el.getAttribute('aria-label') || '').slice(0, 56), reason: reason });
    }
    return labels;
  }

  function revealAll() {
    var marked = document.querySelectorAll('[' + MARK + '="1"]');
    for (var i = 0; i < marked.length; i++) {
      try {
        marked[i].removeAttribute(MARK);
        marked[i].removeAttribute(REASON);
        marked[i].removeAttribute('aria-hidden');
        marked[i].style.removeProperty('display');
        marked[i].style.removeProperty('visibility');
        marked[i].style.removeProperty('pointer-events');
        marked[i].style.removeProperty('height');
        marked[i].style.removeProperty('max-height');
        marked[i].style.removeProperty('min-height');
        marked[i].style.removeProperty('opacity');
        marked[i].style.removeProperty('overflow');
        marked[i].style.removeProperty('margin');
        marked[i].style.removeProperty('padding');
      } catch (e) {}
    }
  }

  function simulateAIMarkers(delayMs) {
    try {
      // Plant once per page — dump timers used to re-plant every few seconds and
      // leave a visible window before the delayed hide (false AFTER failures).
      if (window.__msaAISimPlanted && document.querySelector('[data-msa-ai-sim="1"]')) {
        if (enabled) applyAIHide();
        return 'already-planted';
      }
      window.__msaAISimPlanted = true;

      var old = document.querySelectorAll('[data-msa-ai-sim="1"]');
      for (var o = 0; o < old.length; o++) {
        try {
          old[o].parentNode && old[o].parentNode.removeChild(old[o]);
        } catch (e) {}
      }

      var article =
        document.querySelector('article') ||
        document.querySelector('[role="article"]');
      var host =
        article ||
        document.querySelector('[role="main"]') ||
        document.body;
      if (!host) return 'no_host';

      function plant(tag, text, attrs, css) {
        var el = document.createElement(tag);
        el.setAttribute('data-msa-ai-sim', '1');
        if (attrs) {
          for (var k in attrs) {
            if (attrs.hasOwnProperty(k)) el.setAttribute(k, attrs[k]);
          }
        }
        if (text) el.textContent = text;
        el.style.cssText = css;
        return el;
      }

      // 1) Current Meta label "AI info" + legacy "Made with AI" — inside article
      //    so whole-card hide matches SocialLite-style AI post filtering.
      var chip = plant(
        'div',
        'AI info',
        { role: 'button', 'aria-label': 'AI info' },
        'display:inline-block;margin:8px;padding:6px 10px;border-radius:8px;' +
          'background:#111;color:#fff;font:600 12px/1.2 -apple-system,sans-serif;'
      );
      var chipLegacy = plant(
        'div',
        'Made with AI',
        { role: 'button' },
        'display:inline-block;margin:8px;padding:6px 10px;border-radius:8px;' +
          'background:#111;color:#fff;font:600 12px/1.2 -apple-system,sans-serif;'
      );
      var mount = document.body || document.documentElement;
      if (article) {
        article.insertBefore(chip, article.firstChild);
        article.insertBefore(chipLegacy, article.firstChild);
      } else {
        chip.style.cssText +=
          'position:fixed;z-index:2147483646;left:12px;top:96px;';
        chipLegacy.style.cssText +=
          'position:fixed;z-index:2147483646;left:12px;top:132px;';
        mount.appendChild(chip);
        mount.appendChild(chipLegacy);
      }

      // 2) Ask Meta AI entry
      var entry = plant(
        'a',
        'Ask Meta AI',
        { href: 'https://www.meta.ai/', role: 'link' },
        'display:inline-block;margin:8px;padding:6px 10px;border-radius:8px;' +
          'background:#222;color:#fff;font:600 12px/1.2 -apple-system,sans-serif;'
      );
      if (article) {
        article.appendChild(entry);
      } else {
        entry.style.cssText +=
          'position:fixed;z-index:2147483646;right:12px;top:96px;';
        mount.appendChild(entry);
      }

      // 3) AI stickers control
      var sticker = plant(
        'button',
        'AI stickers',
        { type: 'button', 'aria-label': 'AI stickers' },
        'display:inline-block;margin:8px;padding:6px 10px;border-radius:8px;' +
          'background:#333;color:#fff;font:600 12px/1.2 -apple-system,sans-serif;'
      );
      if (article) article.appendChild(sticker);
      else {
        sticker.style.cssText +=
          'position:fixed;z-index:2147483646;left:12px;top:140px;';
        mount.appendChild(sticker);
      }

      // 4) Floating Meta AI search / chrome (when not in an article context)
      var search = plant(
        'input',
        '',
        {
          type: 'search',
          placeholder: 'Ask Meta AI or search',
          'aria-label': 'Ask Meta AI or search'
        },
        'position:fixed;z-index:2147483646;left:12px;right:12px;top:52px;' +
          'padding:10px 12px;border-radius:10px;border:0;background:#1a1a1a;color:#fff;' +
          'font:500 14px/1.2 -apple-system,sans-serif;'
      );
      mount.appendChild(search);

      // 5) Explore-style tile with Made with AI label
      var tile = plant(
        'a',
        '',
        { href: '/p/msa_ai_sim_tile/', role: 'link', 'aria-label': 'Made with AI' },
        'position:fixed;z-index:2147483645;left:12px;bottom:120px;width:120px;height:160px;' +
          'background:#444;color:#fff;display:block;border-radius:4px;' +
          'font:600 11px/1.2 -apple-system,sans-serif;padding:8px;box-sizing:border-box;'
      );
      var tileLabel = document.createElement('span');
      tileLabel.setAttribute('data-msa-ai-sim', '1');
      tileLabel.textContent = 'Made with AI';
      tile.appendChild(tileLabel);
      mount.appendChild(tile);

      // 6) Story-ish AI sticker surface
      var story = plant(
        'div',
        '',
        { role: 'dialog', 'aria-label': 'Story viewer' },
        'position:fixed;z-index:2147483644;right:12px;bottom:120px;width:140px;height:180px;' +
          'background:#222;color:#fff;border-radius:8px;padding:10px;' +
          'font:600 12px/1.2 -apple-system,sans-serif;box-sizing:border-box;'
      );
      var storySticker = document.createElement('span');
      storySticker.setAttribute('data-msa-ai-sim', '1');
      storySticker.textContent = 'AI sticker';
      story.appendChild(storySticker);
      mount.appendChild(story);

      // When hide is on, collapse immediately (SocialLite-style: no flash of AI chrome).
      // Still schedule a reinforce pass for late layout.
      var wait = typeof delayMs === 'number' ? delayMs : 500;
      if (enabled) {
        applyAIHide();
      }
      setTimeout(function () {
        applyAIHide();
      }, wait);
      return 'planted-v2:' + wait + (enabled ? ':hidden' : ':visible');
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
        scriptCanary: SCRIPT_CANARY,
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
        attributeFilter: ['class', 'style', 'href', 'aria-label', 'title', 'alt', 'placeholder']
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
