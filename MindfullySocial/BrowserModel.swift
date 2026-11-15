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
        let url = URL(string: "https://www.google.com/search?q=cat&hl=en")!
        webView.load(URLRequest(url: url))
    }

    func openFirstResult() {
        statusText = "Opening first result…"
        let js = Self.openFirstResultJS
        webView.evaluateJavaScript(js) { [weak self] result, error in
            Task { @MainActor in
                guard let self else { return }
                if let error {
                    self.statusText = "Could not open result: \(error.localizedDescription)"
                    return
                }
                if let href = result as? String, !href.isEmpty {
                    self.statusText = "Opened: \(href)"
                    self.didOpenFirstResult = true
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
            statusText = "Google search loaded"
            canOpenFirstResult = true
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
            // Dismiss consent banners if present, then allow manual/auto open.
            webView.evaluateJavaScript(Self.dismissConsentJS, completionHandler: nil)
            // Auto-open first result once search is ready (MVP flow).
            if !didOpenFirstResult {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                    self?.openFirstResult()
                }
            }
        }
    }

    private func isGoogleSearch(_ url: URL) -> Bool {
        let host = url.host?.lowercased() ?? ""
        return host.contains("google.") && (url.path.contains("/search") || (url.query?.contains("q=") ?? false))
    }

    /// Click/accept common consent buttons when shown.
    private static let dismissConsentJS = """
    (function() {
      var texts = ['Accept all', 'I agree', 'Accept', 'Agree'];
      var buttons = Array.from(document.querySelectorAll('button, input[type=submit], div[role=button]'));
      for (var i = 0; i < buttons.length; i++) {
        var t = (buttons[i].innerText || buttons[i].value || '').trim();
        if (texts.some(function(x) { return t.toLowerCase() === x.toLowerCase(); })) {
          buttons[i].click();
          return true;
        }
      }
      return false;
    })();
    """

    /// Find first organic result (non-Google) and navigate to it.
    private static let openFirstResultJS = """
    (function() {
      function isGoogle(href) {
        try {
          var u = new URL(href, location.href);
          return /(^|\\.)google\\./i.test(u.hostname) || /(^|\\.)gstatic\\./i.test(u.hostname) || /(^|\\.)youtube\\./i.test(u.hostname);
        } catch (e) { return true; }
      }
      var anchors = Array.from(document.querySelectorAll('#search a[href], #rso a[href], a[href]'));
      for (var i = 0; i < anchors.length; i++) {
        var a = anchors[i];
        var href = a.href;
        if (!href || href.indexOf('http') !== 0) continue;
        if (isGoogle(href)) continue;
        // Prefer links that look like result titles (have h3)
        if (!a.querySelector('h3') && a.getAttribute('data-ved') == null && !a.closest('#rso')) {
          continue;
        }
        a.click();
        return href;
      }
      // Fallback: first non-google http(s) link in #search/#rso
      for (var j = 0; j < anchors.length; j++) {
        var href2 = anchors[j].href;
        if (href2 && href2.indexOf('http') === 0 && !isGoogle(href2)) {
          anchors[j].click();
          return href2;
        }
      }
      return null;
    })();
    """
}
