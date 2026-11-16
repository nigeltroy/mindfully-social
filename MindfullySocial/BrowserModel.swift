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

    /// Site-specific WKUserScripts (Instagram Reels hide). Safe to call once before load.
    func installSiteTweaks(for siteID: String) {
        guard installedTweaksSiteID != siteID else { return }
        installedTweaksSiteID = siteID

        guard siteID == "instagram" else { return }

        let script = WKUserScript(
            source: InstagramChromeTweaks.userScriptSource,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: false
        )
        webView.configuration.userContentController.addUserScript(script)
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
}
