import SwiftUI
import WebKit
import UIKit

struct WebView: UIViewRepresentable {
    @ObservedObject var model: BrowserModel

    func makeCoordinator() -> Coordinator {
        Coordinator(model: model)
    }

    func makeUIView(context: Context) -> WKWebView {
        let wv = model.webView
        wv.scrollView.contentInsetAdjustmentBehavior = .never
        wv.scrollView.automaticallyAdjustsScrollIndicatorInsets = false
        wv.backgroundColor = .black
        wv.isOpaque = true

        // MSA-30: record real taps without stealing them from Instagram.
        let tap = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleTap(_:))
        )
        tap.cancelsTouchesInView = false
        tap.delegate = context.coordinator
        wv.addGestureRecognizer(tap)
        context.coordinator.tapRecognizer = tap

        return wv
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        let model: BrowserModel
        var tapRecognizer: UITapGestureRecognizer?

        init(model: BrowserModel) {
            self.model = model
        }

        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            model.markTrustedInteraction()
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            true
        }
    }
}
