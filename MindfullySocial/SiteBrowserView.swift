import SwiftUI

struct SiteBrowserView: View {
    let site: Site
    let onClose: () -> Void

    @StateObject private var model = BrowserModel()
    @State private var showSwipeTip = true

    var body: some View {
        ZStack(alignment: .top) {
            WebView(model: model)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .accessibilityIdentifier("browserWebView")

            // Invisible top strip: sites like Reddit capture scroll so the system
            // grabber alone is unreliable — swipe-down here calls onClose.
            Color.clear
                .frame(height: 36)
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
                .highPriorityGesture(dismissDrag)
                .accessibilityIdentifier("browserDismissStrip")

            if showSwipeTip {
                Text("Swipe down to leave")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(Color(white: 0.93))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(
                        Capsule(style: .continuous)
                            .fill(Color(white: 0.16).opacity(0.92))
                            .overlay(
                                Capsule(style: .continuous)
                                    .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                            )
                    )
                    .padding(.top, 12)
                    .accessibilityIdentifier("browserSwipeTip")
                    .transition(.opacity.combined(with: .move(edge: .top)))
                    .allowsHitTesting(false)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(white: 0.11))
        // Full-bleed into top and bottom safe areas (Instagram/YouTube chrome owns insets).
        .ignoresSafeArea()
        .preferredColorScheme(.dark)
        .onAppear {
            model.installSiteTweaks(for: site.id)
            model.startFeedHideProbeIfRequested()
            model.startAppPromoProbeIfRequested()
            model.startStoryAdSkipProbeIfRequested()
            UsageTimeStore.beginSession(for: site.id)
            model.load(url: resolveLaunchURL(for: site))
            model.startExploreDumpIfRequested()
            scheduleSwipeTipHide()
        }
        .onDisappear {
            UsageTimeStore.endSession(for: site.id)
        }
    }

    private var dismissDrag: some Gesture {
        DragGesture(minimumDistance: 24, coordinateSpace: .local)
            .onEnded { value in
                if value.translation.height > 70, abs(value.translation.width) < 120 {
                    onClose()
                }
            }
    }

    private func scheduleSwipeTipHide() {
        showSwipeTip = true
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_400_000_000)
            withAnimation(.easeOut(duration: 0.35)) {
                showSwipeTip = false
            }
        }
    }

    /// Optional `-OpenPath /explore/` (with `-OpenSite instagram`) for Tart proof.
    private func resolveLaunchURL(for site: Site) -> URL {
        let args = ProcessInfo.processInfo.arguments
        guard
            site.id == "instagram",
            let idx = args.firstIndex(of: "-OpenPath"),
            args.index(after: idx) < args.endIndex
        else {
            return site.url
        }
        var path = args[args.index(after: idx)]
        if !path.hasPrefix("/") { path = "/" + path }
        return URL(string: "https://www.instagram.com\(path)") ?? site.url
    }
}

#Preview {
    SiteBrowserView(site: Site.all[0], onClose: {})
}
