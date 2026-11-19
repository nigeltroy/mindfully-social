import SwiftUI
import UIKit

/// Installs a top-edge vertical pan on the UIKit host so swipe-down can leave the
/// browser without a hit-testing overlay that steals taps from WKWebView chrome.
struct TopEdgeDismissGesture: UIViewRepresentable {
    var onDismiss: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onDismiss: onDismiss)
    }

    func makeUIView(context: Context) -> UIView {
        let probe = HitThroughProbeView()
        probe.isUserInteractionEnabled = false
        context.coordinator.attach(from: probe)
        return probe
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.onDismiss = onDismiss
        context.coordinator.attach(from: uiView)
    }

    static func dismantleUIView(_ uiView: UIView, coordinator: Coordinator) {
        coordinator.uninstall()
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var onDismiss: () -> Void
        private weak var host: UIView?
        private var pan: UIPanGestureRecognizer?

        init(onDismiss: @escaping () -> Void) {
            self.onDismiss = onDismiss
        }

        func attach(from probe: UIView) {
            DispatchQueue.main.async { [weak self, weak probe] in
                guard let self, let probe else { return }
                guard let host = Self.findHost(from: probe) else { return }
                if self.host === host, self.pan != nil { return }
                self.uninstall()
                let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
                pan.cancelsTouchesInView = false
                pan.delaysTouchesBegan = false
                pan.delaysTouchesEnded = false
                pan.delegate = self
                host.addGestureRecognizer(pan)
                self.host = host
                self.pan = pan
            }
        }

        func uninstall() {
            if let pan, let host {
                host.removeGestureRecognizer(pan)
            }
            pan = nil
            host = nil
        }

        private static func findHost(from probe: UIView) -> UIView? {
            var current: UIView? = probe.superview
            while let view = current {
                if view.bounds.height > 200 {
                    return view
                }
                current = view.superview
            }
            return probe.superview
        }

        private func topBandHeight(in view: UIView) -> CGFloat {
            // Sheet indicator / safe-area edge only — below this, site nav owns taps + pans.
            max(view.safeAreaInsets.top + 12, 48)
        }

        @objc func handlePan(_ pan: UIPanGestureRecognizer) {
            guard pan.state == .ended else { return }
            guard let view = pan.view else { return }
            let translation = pan.translation(in: view)
            if translation.y > 70, abs(translation.x) < 120 {
                onDismiss()
            }
        }

        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            guard let pan = gestureRecognizer as? UIPanGestureRecognizer,
                  let view = pan.view else { return false }
            let location = pan.location(in: view)
            guard location.y <= topBandHeight(in: view) else { return false }
            let velocity = pan.velocity(in: view)
            if abs(velocity.y) < 30, abs(velocity.x) < 30 {
                return true
            }
            return velocity.y > abs(velocity.x) && velocity.y > 0
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            true
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldReceive touch: UITouch
        ) -> Bool {
            guard let view = gestureRecognizer.view else { return false }
            return touch.location(in: view).y <= topBandHeight(in: view)
        }
    }
}

/// Never participates in hit testing; only used to find a host view for the pan.
private final class HitThroughProbeView: UIView {
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? { nil }

    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool { false }
}
