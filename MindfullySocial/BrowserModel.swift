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
    private var appPromoDumpTimer: Timer?

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
                    self?.applyAppPromoHideLaunchFlagsIfNeeded()
                    self?.applyExploreBlankLaunchFlagsIfNeeded()
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

    /// Site-specific WKUserScripts (Instagram). Safe once before load.
    /// Injects MSA-16 Reels-nav, MSA-18 feed-ad hide, MSA-19/22 Explore scripts,
    /// MSA-21 app-promo hide, and MSA-23 Stories sponsored-ad auto-skip.
    func installSiteTweaks(for siteID: String) {
        guard installedTweaksSiteID != siteID else { return }
        installedTweaksSiteID = siteID

        guard siteID == "instagram" else { return }

        let sources = [
            InstagramChromeTweaks.userScriptSource,
            InstagramChromeTweaks.feedHideUserScriptSource,
            InstagramSearchReelsHide.searchReelsHideUserScriptSource,
            InstagramAppPromoHide.userScriptSource,
            InstagramStoryAdSkip.userScriptSource
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
    dump.exploreInstalled = !!(window.__msaExploreBlankInstalled || window.__msaExploreReelsInstalled);
    dump.hasReelsStyle = !!document.getElementById('msa-hide-reels-style');
    dump.hasFeedStyle = !!document.getElementById('msa-hide-feed-ads-style');
    dump.hasExploreBlankStyle = !!document.getElementById('msa-blank-explore-style');
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

    /// `-DisableExploreBlank` → show Explore grid for before shots (MSA-22).
    private func applyExploreBlankLaunchFlagsIfNeeded() {
        let args = ProcessInfo.processInfo.arguments
        guard args.contains("-DisableExploreBlank") else { return }
        let js = #"(function(){try{if(window.__msaExploreBlank&&window.__msaExploreBlank.setEnabled){window.__msaExploreBlank.setEnabled(false);return 'disabled';}return 'missing';}catch(e){return String(e);}})()"#
        webView.evaluateJavaScript(js, completionHandler: nil)
    }

    /// When launched with `-DumpIGExplore`, periodically write explore tile dump to Documents.
    func startExploreDumpIfRequested() {
        let args = ProcessInfo.processInfo.arguments
        guard args.contains("-DumpIGExplore") else { return }
        applyExploreBlankLaunchFlagsIfNeeded()
        // Delay until IG SPA paints; repeat a few times for scroll/nav hardening.
        for delay in [4.0, 8.0, 14.0, 22.0] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                self?.applyExploreBlankLaunchFlagsIfNeeded()
                self?.writeExploreDump(suffix: String(Int(delay)))
            }
        }
        // Optional Tart search-results proof: `-IGSearchQuery nature`
        if let idx = args.firstIndex(of: "-IGSearchQuery"),
           args.index(after: idx) < args.endIndex {
            let query = args[args.index(after: idx)]
            DispatchQueue.main.asyncAfter(deadline: .now() + 10) { [weak self] in
                self?.typeExploreSearchQuery(query)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 16) { [weak self] in
                self?.writeExploreDump(suffix: "search")
            }
        }
    }

    /// Focus Explore search and type a query via DOM (XCUITest often misses the field).
    private func typeExploreSearchQuery(_ query: String) {
        let escaped = query
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "\\'")
        let js = """
        (function () {
          try {
            var q = '\(escaped)';
            var inputs = document.querySelectorAll(
              'input[placeholder*="Search" i], input[aria-label*="Search" i], input[type="search"], input[name="search"]'
            );
            var input = inputs[0];
            if (!input) return 'no_input';
            input.focus();
            input.click();
            var setter = Object.getOwnPropertyDescriptor(window.HTMLInputElement.prototype, 'value');
            if (setter && setter.set) setter.set.call(input, q);
            else input.value = q;
            input.dispatchEvent(new Event('input', { bubbles: true }));
            input.dispatchEvent(new Event('change', { bubbles: true }));
            input.dispatchEvent(new KeyboardEvent('keyup', { bubbles: true, key: 'a' }));
            return 'typed:' + (input.value || '').slice(0, 40);
          } catch (e) { return String(e); }
        })()
        """
        webView.evaluateJavaScript(js) { result, _ in
            NSLog("MSA IGSearchQuery: %@", String(describing: result))
        }
    }

    private func writeExploreDump(suffix: String) {
        webView.evaluateJavaScript(InstagramSearchReelsHide.dumpExploreScript) { result, error in
            let body: String
            if let error {
                body = "{\"error\":\"evaluate\",\"detail\":\"\(error.localizedDescription)\"}\n"
            } else if let text = result as? String {
                body = text + "\n"
            } else {
                body = "{\"error\":\"non_string_result\"}\n"
            }
            guard let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
                return
            }
            let url = docs.appendingPathComponent("msa-explore-dump-\(suffix).json")
            try? body.write(to: url, atomically: true, encoding: .utf8)
            NSLog("MSA ExploreDump: wrote %@", url.lastPathComponent)
        }
    }

    /// Tart proof helpers:
    /// `-DisableAppPromoHide` → leave “Use the app” banners visible for before shots
    /// `-DumpIGAppPromo` → write Documents/msa-app-promo-dump.json periodically
    func startAppPromoProbeIfRequested() {
        let args = ProcessInfo.processInfo.arguments
        guard args.contains("-DumpIGAppPromo") || args.contains("-DisableAppPromoHide") else { return }
        applyAppPromoHideLaunchFlagsIfNeeded()
        guard args.contains("-DumpIGAppPromo") else { return }
        appPromoDumpTimer?.invalidate()
        let timer = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.writeAppPromoDump()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        appPromoDumpTimer = timer
        for delay in [4.0, 8.0, 14.0, 22.0] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                self?.writeAppPromoDump()
            }
        }
    }

    private func applyAppPromoHideLaunchFlagsIfNeeded() {
        let args = ProcessInfo.processInfo.arguments
        guard args.contains("-DisableAppPromoHide") else { return }
        let js = #"(function(){try{if(window.__msaAppPromo&&window.__msaAppPromo.setEnabled){window.__msaAppPromo.setEnabled(false);return 'disabled';}return 'missing';}catch(e){return String(e);}})()"#
        webView.evaluateJavaScript(js, completionHandler: nil)
    }

    private func writeAppPromoDump() {
        webView.evaluateJavaScript(InstagramAppPromoHide.dumpScript) { result, error in
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
            let url = docs.appendingPathComponent("msa-app-promo-dump.json")
            try? payload.write(to: url, atomically: true, encoding: .utf8)
            NSLog("AppPromoDump: wrote %d bytes", payload.utf8.count)
        }
    }

    /// `-DumpIGStories` → Documents/msa-story-ad-skip-dump-*.json while browsing Stories.
    /// `-DisableStoryAdSkip` → leave sponsored stories alone for before shots.
    /// Dumps keep running well past login so story-viewer opens are captured.
    func startStoryAdSkipProbeIfRequested() {
        let args = ProcessInfo.processInfo.arguments
        guard args.contains("-DumpIGStories") || args.contains("-DisableStoryAdSkip") else { return }
        applyStoryAdSkipLaunchFlagsIfNeeded()
        guard args.contains("-DumpIGStories") else { return }
        // Early samples + dense samples through the XCUITest stories window (~3–4 min).
        let delays: [Double] = [
            4, 8, 12, 18, 26, 36, 48,
            70, 90, 110, 130, 150, 170, 190, 210, 230
        ]
        for delay in delays {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                self?.applyStoryAdSkipLaunchFlagsIfNeeded()
                self?.maybeSimulateStoryAdIfRequested()
                self?.writeStoryAdSkipDump(suffix: String(Int(delay)))
            }
        }
    }

    /// `-SimulateStoryAd` → plant a Sponsored label inside the story viewer (Tart mechanism proof).
    /// Uses a short delay so XCUITest can screenshot Sponsored before auto-advance.
    private func maybeSimulateStoryAdIfRequested() {
        let args = ProcessInfo.processInfo.arguments
        guard args.contains("-SimulateStoryAd") else { return }
        let js = #"(function(){try{if(window.__msaStoryAdSkip&&window.__msaStoryAdSkip.simulateSponsored){return window.__msaStoryAdSkip.simulateSponsored(2500);}return 'missing';}catch(e){return String(e);}})()"#
        webView.evaluateJavaScript(js, completionHandler: nil)
    }

    private func applyStoryAdSkipLaunchFlagsIfNeeded() {
        let args = ProcessInfo.processInfo.arguments
        guard args.contains("-DisableStoryAdSkip") else { return }
        let js = #"(function(){try{if(window.__msaStoryAdSkip&&window.__msaStoryAdSkip.setEnabled){window.__msaStoryAdSkip.setEnabled(false);return 'disabled';}return 'missing';}catch(e){return String(e);}})()"#
        webView.evaluateJavaScript(js, completionHandler: nil)
    }

    private func writeStoryAdSkipDump(suffix: String) {
        webView.evaluateJavaScript(InstagramStoryAdSkip.dumpScript) { result, error in
            let body: String
            if let error {
                body = "{\"error\":\"evaluate\",\"detail\":\"\(error.localizedDescription)\"}\n"
            } else if let text = result as? String {
                body = text + "\n"
            } else {
                body = "{\"error\":\"non_string_result\"}\n"
            }
            guard let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
                return
            }
            let url = docs.appendingPathComponent("msa-story-ad-skip-dump-\(suffix).json")
            try? body.write(to: url, atomically: true, encoding: .utf8)
            NSLog("MSA StoryAdSkipDump: wrote %@", url.lastPathComponent)
        }
    }
}
