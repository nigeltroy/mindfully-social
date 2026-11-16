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
            HStack(spacing: 8) {
                Text(usage.displayString)
                    .font(.footnote.monospacedDigit().weight(.medium))
                    .foregroundStyle(BrowserChromePalette.secondary)
                    .accessibilityIdentifier("browserUsageTime")

                Spacer(minLength: 8)

                Button {
                    finishAndClose()
                } label: {
                    Image(systemName: "xmark")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(BrowserChromePalette.primary)
                        .frame(width: 44, height: 32)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("browserCloseButton")
                .accessibilityLabel("Close")
            }
            .padding(.leading, 16)
            .padding(.trailing, 6)
            .padding(.vertical, 2)
            .frame(minHeight: 36)
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
