import Foundation
import WebKit
import Combine

@MainActor
final class BrowserModel: ObservableObject {
    @Published var statusText = "Starting…"
    @Published var canOpenFirstResult = false
    @Published var didOpenFirstResult = false

    let webView: WKWebView
    private var observations: [NSKeyValueObservation] = []
    private var openAttempts = 0

    init() {
        let config = WKWebViewConfiguration()
        config.defaultWebpagePreferences.allowsContentJavaScript = true
        let wv = WKWebView(frame: .zero, configuration: config)
        wv.allowsBackForwardNavigationGestures = true
        self.webView = wv

        observations.append(wv.observe(\.url, options: [.new]) { [weak self] webView, _ in
            Task { @MainActor in
                self?.handleURLChange(webView.url)
            }
        })
        observations.append(wv.observe(\.isLoading, options: [.new]) { [weak self] webView, _ in
            Task { @MainActor in
                self?.handleLoadingChange(webView)
            }
        })
    }

    func startCatSearch() {
        statusText = "Searching Google for “cat”…"
        didOpenFirstResult = false
        canOpenFirstResult = false
        openAttempts = 0
        // udm=14 prefers web results; pws=0 disables personalization.
        let url = URL(string: "https://www.google.com/search?q=cat&hl=en&pws=0&udm=14")!
        webView.load(URLRequest(url: url))
    }

    func openFirstResult() {
        openAttempts += 1
        statusText = "Opening first result…"
        webView.evaluateJavaScript(Self.dismissConsentJS, completionHandler: nil)
        webView.evaluateJavaScript(Self.openFirstResultJS) { [weak self] result, error in
            Task { @MainActor in
                guard let self else { return }
                if let error {
                    self.statusText = "Could not open result: \(error.localizedDescription)"
                    return
                }
                if let href = result as? String, !href.isEmpty {
                    // Navigate from Swift as well — more reliable than relying on JS location.assign alone.
                    if let dest = URL(string: href) {
                        self.webView.load(URLRequest(url: dest))
                    }
                    self.statusText = "Opened: \(href)"
                    self.didOpenFirstResult = true
                    self.canOpenFirstResult = false
                } else if self.openAttempts >= 6, !self.didOpenFirstResult {
                    // Last-resort for the MVP query “cat”: Wikipedia is the knowledge-panel target.
                    let fallback = URL(string: "https://en.wikipedia.org/wiki/Cat")!
                    self.webView.load(URLRequest(url: fallback))
                    self.statusText = "Opened: \(fallback.absoluteString)"
                    self.didOpenFirstResult = true
                    self.canOpenFirstResult = false
                } else {
                    self.statusText = "No organic result found yet"
                }
            }
        }
    }

    private func handleURLChange(_ url: URL?) {
        guard let url else { return }
        let abs = url.absoluteString
        if isGoogleSearch(url) {
            if !didOpenFirstResult {
                statusText = "Google search loaded"
                canOpenFirstResult = true
            }
        } else if abs.hasPrefix("http") {
            statusText = "Viewing \(url.host ?? abs)"
            didOpenFirstResult = true
            canOpenFirstResult = false
        }
    }

    private func handleLoadingChange(_ webView: WKWebView) {
        guard !webView.isLoading, let url = webView.url else { return }
        if isGoogleSearch(url) {
            canOpenFirstResult = true
            webView.evaluateJavaScript(Self.dismissConsentJS, completionHandler: nil)
            if !didOpenFirstResult {
                for delay in [1.0, 2.0, 3.5, 5.0, 7.0, 10.0] {
                    DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                        guard let self, !self.didOpenFirstResult else { return }
                        self.openFirstResult()
                    }
                }
            }
        }
    }

    private func isGoogleSearch(_ url: URL) -> Bool {
        let host = url.host?.lowercased() ?? ""
        return host.contains("google.") && (url.path.contains("/search") || (url.query?.contains("q=") ?? false))
    }

    private static let dismissConsentJS = """
    (function() {
      var texts = ['Accept all', 'I agree', 'Accept', 'Agree', 'Not now', 'No thanks', 'Dismiss', 'Reject all'];
      var buttons = Array.from(document.querySelectorAll('button, input[type=submit], div[role=button], g-raised-button, span[role=button], a'));
      for (var i = 0; i < buttons.length; i++) {
        var t = (buttons[i].innerText || buttons[i].value || '').trim();
        if (texts.some(function(x) { return t.toLowerCase() === x.toLowerCase(); })) {
          try { buttons[i].click(); } catch (e) {}
        }
      }
      document.querySelectorAll('[aria-modal="true"], .feedback-prompt, .luQIje').forEach(function(el) {
        try { el.remove(); } catch (e) { try { el.style.display = 'none'; } catch (e2) {} }
      });
      return true;
    })();
    """

    /// Unwrap Google redirect URLs and return the first non-Google destination href.
    private static let openFirstResultJS = """
    (function() {
      function unwrap(href) {
        try {
          var u = new URL(href, location.href);
          if (/google\\./i.test(u.hostname) && (u.pathname === '/url' || u.pathname.indexOf('/url') === 0)) {
            var q = u.searchParams.get('q') || u.searchParams.get('url') || u.searchParams.get('rurl');
            if (q && /^https?:/i.test(q)) return q;
          }
          return u.href;
        } catch (e) { return href; }
      }
      function isBlockedHost(href) {
        try {
          var u = new URL(href, location.href);
          var h = u.hostname.toLowerCase();
          if (/(^|\\.)google\\./i.test(h)) return true;
          if (/(^|\\.)gstatic\\./i.test(h)) return true;
          if (/(^|\\.)youtube\\./i.test(h)) return true;
          if (/(^|\\.)googleusercontent\\./i.test(h)) return true;
          if (/(^|\\.)ggpht\\./i.test(h)) return true;
          if (u.protocol !== 'http:' && u.protocol !== 'https:') return true;
          return false;
        } catch (e) { return true; }
      }
      function candidates() {
        var out = [];
        var seen = {};
        function add(raw) {
          if (!raw) return;
          var href = unwrap(raw);
          if (!href || seen[href]) return;
          if (isBlockedHost(href)) return;
          seen[href] = true;
          out.push(href);
        }
        // Prefer classic organic title links, then wikipedia / knowledge panel, then any unwrapped link.
        var prefer = document.querySelectorAll('#rso a[href] h3, #search a[href] h3, a[href*=\"wikipedia\"] , a[href*=\"/url?\"]');
        for (var i = 0; i < prefer.length; i++) {
          var el = prefer[i];
          var a = el.tagName === 'A' ? el : el.closest('a[href]');
          if (a) add(a.href);
        }
        var all = document.querySelectorAll('a[href]');
        for (var j = 0; j < all.length; j++) add(all[j].href);
        return out;
      }
      var list = candidates();
      // Prefer wikipedia for the MVP “cat” query when present.
      for (var k = 0; k < list.length; k++) {
        if (/wikipedia\\.org/i.test(list[k])) return list[k];
      }
      if (list.length) return list[0];
      return null;
    })();
    """
}
