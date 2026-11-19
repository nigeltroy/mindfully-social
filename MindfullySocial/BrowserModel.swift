import Foundation
import WebKit
import Combine

@MainActor
final class BrowserModel: ObservableObject {
    @Published var titleText = ""
    @Published var canGoBack = false
    @Published var isLoading = false
    /// MSA-32: soft-dark cover until first stable paint after IG injections.
    @Published var showStableCover = false

    let webView: WKWebView
    private var observations: [NSKeyValueObservation] = []
    private var installedTweaksSiteID: String?
    private var feedDumpTimer: Timer?
    private var appPromoDumpTimer: Timer?
    private var aiHideDumpTimer: Timer?
    private var reelGuardDumpTimer: Timer?
    private var reelsNavDumpTimer: Timer?
    /// MSA-30: last real tap on the WKWebView (gesture-gated reel opens).
    private var lastTrustedInteractionAt: Date?
    private var intentionalReelPath: String?
    private var isBouncingReelURL = false
    private var stableCoverPollTimer: Timer?
    private var stableCoverStartedAt: Date?

    init() {
        let config = WKWebViewConfiguration()
        // Persist cookies/localStorage across force-quit via WebKit's default store.
        // Do not use WKWebsiteDataStore.nonPersistent().
        config.websiteDataStore = .default()
        config.defaultWebpagePreferences.allowsContentJavaScript = true
        // iOS WKWebView defaults allowsInlineMediaPlayback=false, which forces HTML5
        // video into the system fullscreen player when it autoplays (in-feed reels).
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
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
                    self?.applyAIHideLaunchFlagsIfNeeded()
                }
            }
        })
        observations.append(wv.observe(\.url, options: [.new]) { [weak self] webView, _ in
            Task { @MainActor in
                if (self?.titleText.isEmpty ?? true) {
                    self?.titleText = webView.url?.host ?? ""
                }
                self?.enforceReelURLGuard(webView.url)
            }
        })
    }

    /// Called from WebView tap recognizer (cancelsTouchesInView=false).
    func markTrustedInteraction() {
        lastTrustedInteractionAt = Date()
    }

    private func hasRecentTrustedInteraction(within seconds: TimeInterval = 2.5) -> Bool {
        guard let lastTrustedInteractionAt else { return false }
        return Date().timeIntervalSince(lastTrustedInteractionAt) <= seconds
    }

    /// True for Reels tab and single-reel paths (not /reels/audio).
    static func isInstagramReelPath(_ url: URL?) -> Bool {
        guard let url else { return false }
        let host = (url.host ?? "").lowercased()
        guard host.contains("instagram.com") else { return false }
        let path = url.path.lowercased()
        if path == "/reels" || path == "/reels/" { return true }
        if path.hasPrefix("/reel/") { return true }
        if path.hasPrefix("/reels/") && !path.hasPrefix("/reels/audio") {
            let rest = String(path.dropFirst("/reels/".count))
                .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            return !rest.isEmpty && !rest.hasPrefix("audio")
        }
        return false
    }

    /// Belt-and-suspenders with JS reelguard: bounce unsolicited /reels landings.
    private func enforceReelURLGuard(_ url: URL?) {
        guard installedTweaksSiteID == "instagram" else { return }
        guard Self.isInstagramReelPath(url) else {
            intentionalReelPath = nil
            return
        }
        let path = url?.path ?? ""
        if hasRecentTrustedInteraction() {
            intentionalReelPath = path
            return
        }
        if let keep = intentionalReelPath, keep == path {
            return
        }
        guard !isBouncingReelURL else { return }
        isBouncingReelURL = true
        NSLog("MSA-30: bouncing unsolicited reel URL %@", path)
        if webView.canGoBack {
            webView.goBack()
        } else if let home = URL(string: "https://www.instagram.com/") {
            webView.load(URLRequest(url: home))
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) { [weak self] in
            self?.isBouncingReelURL = false
        }
    }

    /// Site-specific WKUserScripts (Instagram). Safe once before load.
    /// Injects MSA-32 stable cover first, then MSA-16 Reels-nav, MSA-18 feed-ad hide,
    /// MSA-19/22 Explore scripts, MSA-21/32 app-promo hide, MSA-23 Stories sponsored-ad
    /// auto-skip, MSA-29/31 Meta AI / AI-content hide, and MSA-30 reel auto-open guard.
    func installSiteTweaks(for siteID: String) {
        guard installedTweaksSiteID != siteID else { return }
        installedTweaksSiteID = siteID

        guard siteID == "instagram" else { return }

        let sources = [
            InstagramStableCover.userScriptSource,
            InstagramChromeTweaks.userScriptSource,
            InstagramChromeTweaks.feedHideUserScriptSource,
            InstagramSearchReelsHide.searchReelsHideUserScriptSource,
            InstagramAppPromoHide.userScriptSource,
            InstagramStoryAdSkip.userScriptSource,
            InstagramAIContentHide.userScriptSource,
            InstagramReelAutoOpenGuard.userScriptSource
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

    /// MSA-32: show native cover immediately; poll JS until first stable paint (or timeout).
    /// `-DisableStableCover` skips the native cover (JS cover still runs unless also disabled in JS).
    func beginStableCoverIfNeeded(for siteID: String) {
        guard siteID == "instagram" else { return }
        let args = ProcessInfo.processInfo.arguments
        if args.contains("-DisableStableCover") {
            showStableCover = false
            return
        }
        showStableCover = true
        stableCoverStartedAt = Date()
        stableCoverPollTimer?.invalidate()
        let timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.pollStableCoverReady()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        stableCoverPollTimer = timer
        // Hard cap so the UI never sticks if JS never signals.
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) { [weak self] in
            self?.revealStableCoverIfNeeded()
        }
    }

    private func pollStableCoverReady() {
        guard showStableCover else {
            stableCoverPollTimer?.invalidate()
            stableCoverPollTimer = nil
            return
        }
        if let started = stableCoverStartedAt, Date().timeIntervalSince(started) > 10 {
            revealStableCoverIfNeeded()
            return
        }
        webView.evaluateJavaScript(InstagramStableCover.isReadyScript) { [weak self] result, _ in
            Task { @MainActor in
                if let ready = result as? Bool, ready {
                    self?.revealStableCoverIfNeeded()
                }
            }
        }
    }

    private func revealStableCoverIfNeeded() {
        guard showStableCover else { return }
        showStableCover = false
        stableCoverPollTimer?.invalidate()
        stableCoverPollTimer = nil
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
    /// `-DumpIGStableCover` → also write Documents/msa-stable-cover-dump.json
    func startAppPromoProbeIfRequested() {
        let args = ProcessInfo.processInfo.arguments
        guard args.contains("-DumpIGAppPromo")
            || args.contains("-DisableAppPromoHide")
            || args.contains("-DumpIGStableCover")
        else { return }
        applyAppPromoHideLaunchFlagsIfNeeded()
        applyStableCoverLaunchFlagsIfNeeded()
        let dumpPromo = args.contains("-DumpIGAppPromo")
        let dumpCover = args.contains("-DumpIGStableCover")
        guard dumpPromo || dumpCover else { return }
        appPromoDumpTimer?.invalidate()
        let timer = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { [weak self] _ in
            Task { @MainActor in
                if dumpPromo { self?.writeAppPromoDump() }
                if dumpCover { self?.writeStableCoverDump() }
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        appPromoDumpTimer = timer
        for delay in [2.0, 4.0, 8.0, 14.0, 22.0] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                if dumpPromo { self?.writeAppPromoDump() }
                if dumpCover { self?.writeStableCoverDump() }
            }
        }
    }

    private func applyAppPromoHideLaunchFlagsIfNeeded() {
        let args = ProcessInfo.processInfo.arguments
        guard args.contains("-DisableAppPromoHide") else { return }
        let js = #"(function(){try{if(window.__msaAppPromo&&window.__msaAppPromo.setEnabled){window.__msaAppPromo.setEnabled(false);return 'disabled';}return 'missing';}catch(e){return String(e);}})()"#
        webView.evaluateJavaScript(js, completionHandler: nil)
    }

    private func applyStableCoverLaunchFlagsIfNeeded() {
        let args = ProcessInfo.processInfo.arguments
        guard args.contains("-DisableStableCover") else { return }
        let js = #"(function(){try{if(window.__msaStableCover&&window.__msaStableCover.setEnabled){window.__msaStableCover.setEnabled(false);return 'disabled';}return 'missing';}catch(e){return String(e);}})()"#
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

    private func writeStableCoverDump() {
        webView.evaluateJavaScript(InstagramStableCover.dumpScript) { result, error in
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
            let url = docs.appendingPathComponent("msa-stable-cover-dump.json")
            try? payload.write(to: url, atomically: true, encoding: .utf8)
            NSLog("StableCoverDump: wrote %d bytes", payload.utf8.count)
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

    /// Tart proof helpers:
    /// `-DisableAIHide` → leave Meta AI / Made-with-AI chrome visible for before shots
    /// `-DumpIGAI` → write Documents/msa-ai-hide-dump-*.json periodically
    /// `-SimulateAIContent` → plant Made with AI / Ask Meta AI / stickers / explore+story markers
    func startAIHideProbeIfRequested() {
        let args = ProcessInfo.processInfo.arguments
        guard args.contains("-DumpIGAI") || args.contains("-DisableAIHide") || args.contains("-SimulateAIContent") else {
            return
        }
        applyAIHideLaunchFlagsIfNeeded()
        guard args.contains("-DumpIGAI") || args.contains("-SimulateAIContent") else { return }
        aiHideDumpTimer?.invalidate()
        let timer = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.maybeSimulateAIContentIfRequested()
                self?.writeAIHideDump(suffix: "live")
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        aiHideDumpTimer = timer
        let delays: [Double] = [4, 8, 12, 18, 26, 36, 48, 70, 90, 110, 130]
        for delay in delays {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                self?.applyAIHideLaunchFlagsIfNeeded()
                self?.maybeSimulateAIContentIfRequested()
                self?.writeAIHideDump(suffix: String(Int(delay)))
            }
        }
    }

    /// `-SimulateAIContent` → plant AI chrome markers (Tart mechanism proof).
    private func maybeSimulateAIContentIfRequested() {
        let args = ProcessInfo.processInfo.arguments
        guard args.contains("-SimulateAIContent") else { return }
        let js = #"(function(){try{if(window.__msaAIHide&&window.__msaAIHide.simulateAI){return window.__msaAIHide.simulateAI(2200);}return 'missing';}catch(e){return String(e);}})()"#
        webView.evaluateJavaScript(js, completionHandler: nil)
    }

    private func applyAIHideLaunchFlagsIfNeeded() {
        let args = ProcessInfo.processInfo.arguments
        guard args.contains("-DisableAIHide") else { return }
        let js = #"(function(){try{if(window.__msaAIHide&&window.__msaAIHide.setEnabled){window.__msaAIHide.setEnabled(false);return 'disabled';}return 'missing';}catch(e){return String(e);}})()"#
        webView.evaluateJavaScript(js, completionHandler: nil)
    }

    private func writeAIHideDump(suffix: String) {
        webView.evaluateJavaScript(InstagramAIContentHide.dumpScript) { result, error in
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
            let url = docs.appendingPathComponent("msa-ai-hide-dump-\(suffix).json")
            try? body.write(to: url, atomically: true, encoding: .utf8)
            NSLog("MSA AIHideDump: wrote %@", url.lastPathComponent)
        }
    }

    /// Tart proof helpers:
    /// `-DumpIGReelGuard` → Documents/msa-reel-guard-dump-*.json while scrolling feed
    /// `-DisableReelGuard` → leave auto-open guard off for before shots
    /// `-SimulateReelAutoOpen` → plant synthetic reel open / fullscreen attempts
    func startReelGuardProbeIfRequested() {
        let args = ProcessInfo.processInfo.arguments
        guard args.contains("-DumpIGReelGuard")
            || args.contains("-DisableReelGuard")
            || args.contains("-SimulateReelAutoOpen")
        else {
            return
        }
        applyReelGuardLaunchFlagsIfNeeded()
        guard args.contains("-DumpIGReelGuard") || args.contains("-SimulateReelAutoOpen") else { return }
        reelGuardDumpTimer?.invalidate()
        let timer = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.maybeSimulateReelAutoOpenIfRequested()
                self?.writeReelGuardDump(suffix: "live")
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        reelGuardDumpTimer = timer
        let delays: [Double] = [4, 8, 12, 18, 26, 36, 48, 70, 90, 110]
        for delay in delays {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                self?.applyReelGuardLaunchFlagsIfNeeded()
                self?.maybeSimulateReelAutoOpenIfRequested()
                self?.writeReelGuardDump(suffix: String(Int(delay)))
            }
        }
    }

    private func maybeSimulateReelAutoOpenIfRequested() {
        let args = ProcessInfo.processInfo.arguments
        guard args.contains("-SimulateReelAutoOpen") else { return }
        let js = #"(function(){try{if(window.__msaReelGuard&&window.__msaReelGuard.simulateAutoOpen){return JSON.stringify(window.__msaReelGuard.simulateAutoOpen());}return 'missing';}catch(e){return String(e);}})()"#
        webView.evaluateJavaScript(js, completionHandler: nil)
    }

    private func applyReelGuardLaunchFlagsIfNeeded() {
        let args = ProcessInfo.processInfo.arguments
        guard args.contains("-DisableReelGuard") else { return }
        let js = #"(function(){try{if(window.__msaReelGuard&&window.__msaReelGuard.setEnabled){window.__msaReelGuard.setEnabled(false);return 'disabled';}return 'missing';}catch(e){return String(e);}})()"#
        webView.evaluateJavaScript(js, completionHandler: nil)
    }

    private func writeReelGuardDump(suffix: String) {
        webView.evaluateJavaScript(InstagramReelAutoOpenGuard.dumpScript) { result, error in
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
            let url = docs.appendingPathComponent("msa-reel-guard-dump-\(suffix).json")
            try? body.write(to: url, atomically: true, encoding: .utf8)
            NSLog("MSA ReelGuardDump: wrote %@", url.lastPathComponent)
        }
    }

    /// `-DumpIGNav` → Documents/msa-reels-nav-dump-*.json (MSA-34 clapper / bottom-nav proof).
    func startReelsNavProbeIfRequested() {
        let args = ProcessInfo.processInfo.arguments
        guard args.contains("-DumpIGNav") else { return }
        reelsNavDumpTimer?.invalidate()
        let timer = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.writeReelsNavDump(suffix: "live")
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        reelsNavDumpTimer = timer
        for delay in [4.0, 8.0, 12.0, 18.0, 26.0, 36.0, 48.0, 70.0] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                self?.writeReelsNavDump(suffix: String(Int(delay)))
            }
        }
    }

    private func writeReelsNavDump(suffix: String) {
        webView.evaluateJavaScript(InstagramChromeTweaks.dumpNavScript) { result, error in
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
            let url = docs.appendingPathComponent("msa-reels-nav-dump-\(suffix).json")
            try? body.write(to: url, atomically: true, encoding: .utf8)
            NSLog("MSA ReelsNavDump: wrote %@", url.lastPathComponent)
        }
    }
}
