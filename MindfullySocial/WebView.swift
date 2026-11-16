import SwiftUI
import WebKit

struct WebView: UIViewRepresentable {
    @ObservedObject var model: BrowserModel

    func makeUIView(context: Context) -> WKWebView {
        let wv = model.webView
        wv.scrollView.contentInsetAdjustmentBehavior = .never
        wv.scrollView.automaticallyAdjustsScrollIndicatorInsets = false
        wv.backgroundColor = .black
        wv.isOpaque = true
        return wv
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}
}
