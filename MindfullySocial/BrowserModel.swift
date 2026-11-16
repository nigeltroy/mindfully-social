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

    init() {
        let config = WKWebViewConfiguration()
        config.defaultWebpagePreferences.allowsContentJavaScript = true
        let wv = WKWebView(frame: .zero, configuration: config)
        wv.allowsBackForwardNavigationGestures = true
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
