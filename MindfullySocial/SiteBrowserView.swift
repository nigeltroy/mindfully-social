import SwiftUI

private enum BrowserChromePalette {
    static let bar = Color(white: 0.11)
    static let primary = Color(white: 0.93)
    static let secondary = Color(white: 0.58)
}

struct SiteBrowserView: View {
    let site: Site
    let onClose: () -> Void

    @StateObject private var model = BrowserModel()
    @State private var usage = UsageTime.placeholder
    @State private var usageTick: Timer?

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                Text(usage.displayString)
                    .font(.footnote.monospacedDigit().weight(.medium))
                    .foregroundStyle(BrowserChromePalette.secondary)
                    .frame(minWidth: 44, alignment: .leading)
                    .accessibilityIdentifier("browserUsageTime")

                Spacer(minLength: 0)

                Button {
                    finishAndClose()
                } label: {
                    Image(systemName: "xmark")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(BrowserChromePalette.primary)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("browserCloseButton")
                .accessibilityLabel("Close")
            }
            // Symmetric inset aligned with home cards (~20 visual with safe area).
            .padding(.horizontal, 16)
            .frame(height: 44)
            .background(BrowserChromePalette.bar)

            WebView(model: model)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .accessibilityIdentifier("browserWebView")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(white: 0.11))
        // Consume bottom safe-area so WKWebView reaches the home indicator.
        .ignoresSafeArea(edges: .bottom)
        .preferredColorScheme(.dark)
        .onAppear {
            model.installSiteTweaks(for: site.id)
            model.startFeedHideProbeIfRequested()
            UsageTimeStore.beginSession(for: site.id)
            refreshUsage()
            startUsageTicker()
            model.load(url: site.url)
        }
        .onDisappear {
            stopUsageTicker()
            UsageTimeStore.endSession(for: site.id)
        }
    }

    private func refreshUsage() {
        usage = UsageTimeStore.daily(for: site.id)
    }

    private func startUsageTicker() {
        stopUsageTicker()
        let timer = Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { _ in
            Task { @MainActor in
                refreshUsage()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        usageTick = timer
    }

    private func stopUsageTicker() {
        usageTick?.invalidate()
        usageTick = nil
    }

    private func finishAndClose() {
        stopUsageTicker()
        UsageTimeStore.endSession(for: site.id)
        onClose()
    }
}

#Preview {
    SiteBrowserView(site: Site.all[0], onClose: {})
}
