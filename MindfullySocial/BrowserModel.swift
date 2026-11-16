import Foundation
import WebKit
import Combine

@MainActor
final class BrowserModel: ObservableObject {
    @Published var titleText = ""
    @Published var canGoBack = false
    @Published var isLoading = false

    let webView: WKWebView
    private var observations: [NSKeyValueObservation] = []
    private var installedTweaksSiteID: String?
    private var feedDumpTimer: Timer?

    init() {
        let config = WKWebViewConfiguration()
        // Persist cookies/localStorage across force-quit via WebKit's default store.
        // Do not use WKWebsiteDataStore.nonPersistent().
        config.websiteDataStore = .default()
        config.defaultWebpagePreferences.allowsContentJavaScript = true
        let wv = WKWebView(frame: .zero, configuration: config)
        wv.allowsBackForwardNavigationGestures = true
        wv.scrollView.contentInsetAdjustmentBehavior = .never
        self.webView = wv

        observations.append(wv.observe(\.title, options: [.new]) { [weak self] webView, _ in
            Task { @MainActor in
                self?.titleText = webView.title ?? webView.url?.host ?? ""
            }
        })
        observations.append(wv.observe(\.canGoBack, options: [.new]) { [weak self] webView, _ in
            Task { @MainActor in
                self?.canGoBack = webView.canGoBack
            }
        })
        observations.append(wv.observe(\.isLoading, options: [.new]) { [weak self] webView, _ in
            Task { @MainActor in
                self?.isLoading = webView.isLoading
                if !webView.isLoading {
                    self?.titleText = webView.title ?? webView.url?.host ?? ""
                    self?.canGoBack = webView.canGoBack
                    self?.applyFeedHideLaunchFlagsIfNeeded()
                }
            }
        })
        observations.append(wv.observe(\.url, options: [.new]) { [weak self] webView, _ in
            Task { @MainActor in
                if (self?.titleText.isEmpty ?? true) {
                    self?.titleText = webView.url?.host ?? ""
                }
            }
        })
    }

    /// Site-specific WKUserScripts (Instagram Reels nav + feed-ad hide). Safe once before load.
    func installSiteTweaks(for siteID: String) {
        guard installedTweaksSiteID != siteID else { return }
        installedTweaksSiteID = siteID

        guard siteID == "instagram" else { return }

        let sources = [
            InstagramChromeTweaks.userScriptSource,
            InstagramChromeTweaks.feedHideUserScriptSource
        ]
        for source in sources {
            let script = WKUserScript(
                source: source,
                injectionTime: .atDocumentStart,
                forMainFrameOnly: false
            )
            webView.configuration.userContentController.addUserScript(script)
        }
    }

    func load(url: URL) {
        titleText = url.host ?? url.absoluteString
        webView.load(URLRequest(url: url))
    }

    func goBack() {
        if webView.canGoBack {
            webView.goBack()
        }
    }

    /// Tart proof helpers:
    /// `-DisableFeedHide` → leave Sponsored/Suggested visible for before shots
    /// `-DumpIGFeed` → write Documents/msa-feed-hide-dump.json periodically
    func startFeedHideProbeIfRequested() {
        let args = ProcessInfo.processInfo.arguments
        guard args.contains("-DumpIGFeed") || args.contains("-DisableFeedHide") else { return }
        applyFeedHideLaunchFlagsIfNeeded()
        guard args.contains("-DumpIGFeed") else { return }
        feedDumpTimer?.invalidate()
        let timer = Timer.scheduledTimer(withTimeInterval: 4, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.writeFeedHideDump()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        feedDumpTimer = timer
        // First dump after IG has a chance to paint.
        DispatchQueue.main.asyncAfter(deadline: .now() + 6) { [weak self] in
            self?.writeFeedHideDump()
        }
    }

    private func applyFeedHideLaunchFlagsIfNeeded() {
        let args = ProcessInfo.processInfo.arguments
        guard args.contains("-DisableFeedHide") else { return }
        let js = #"(function(){try{if(window.__msaFeedHide&&window.__msaFeedHide.setEnabled){window.__msaFeedHide.setEnabled(false);return 'disabled';}return 'missing';}catch(e){return String(e);}})()"#
        webView.evaluateJavaScript(js, completionHandler: nil)
    }

    private func writeFeedHideDump() {
        let js = #"""
(function () {
  try {
    var dump = (window.__msaFeedHide && window.__msaFeedHide.dump)
      ? window.__msaFeedHide.dump()
      : { error: 'feed_hide_missing' };
    dump.reelsInstalled = !!window.__msaReelsInstalled;
    dump.feedInstalled = !!window.__msaFeedHideInstalled;
    dump.hasReelsStyle = !!document.getElementById('msa-hide-reels-style');
    dump.hasFeedStyle = !!document.getElementById('msa-hide-feed-ads-style');
    dump.bottomNav = !!document.querySelector('[data-msa-bottom-nav="1"]');
    dump.hrefSample = Array.prototype.slice.call(document.querySelectorAll('a[href]'), 0, 30).map(function (a) {
      return a.getAttribute('href');
    });
    // Collect short visible labels that look like feed chrome.
    var shorts = [];
    var nodes = document.querySelectorAll('span, div, h1, h2, h3');
    for (var i = 0; i < nodes.length && shorts.length < 60; i++) {
      var t = (nodes[i].textContent || '').replace(/\s+/g, ' ').trim();
      if (!t || t.length > 40) continue;
      if (/sponsored|suggested|follow|for you|paid partnership|^ad$/i.test(t)) {
        shorts.push(t);
      }
    }
    dump.interestingLabels = shorts;
    return JSON.stringify(dump);
  } catch (e) {
    return JSON.stringify({ error: String(e) });
  }
})()
"""#
        webView.evaluateJavaScript(js) { result, error in
            let payload: String
            if let error {
                payload = "{\"error\":\"evaluate:\(String(describing: error))\"}"
            } else if let s = result as? String {
                payload = s
            } else {
                payload = "{\"error\":\"non_string_result\"}"
            }
            guard let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
                return
            }
            let url = docs.appendingPathComponent("msa-feed-hide-dump.json")
            try? payload.write(to: url, atomically: true, encoding: .utf8)
            NSLog("FeedHideDump: wrote %d bytes", payload.utf8.count)
        }
    }
}
