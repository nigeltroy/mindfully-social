import SwiftUI

private enum HomePalette {
    /// Soft dark gray (not pure black).
    static let background = Color(white: 0.11)
    /// Elevated inset surface for the destination group.
    static let surface = Color(white: 0.16)
    static let surfaceStroke = Color.white.opacity(0.06)
    static let primaryText = Color(white: 0.93)
    static let secondaryText = Color(white: 0.58)
    static let tertiaryText = Color(white: 0.42)
    static let gearFill = Color.white.opacity(0.08)
}

struct HomeView: View {
    @State private var selectedSite: Site?
    @State private var settingsSite: Site?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text("Mindfully Social")
                        .font(.system(size: 28, weight: .bold, design: .default))
                        .foregroundStyle(HomePalette.primaryText)
                        .tracking(-0.3)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityIdentifier("appTitle")

                    VStack(spacing: 12) {
                        ForEach(Site.all) { site in
                            SiteRowView(
                                site: site,
                                usage: UsageTimeStore.daily(for: site.id),
                                onOpen: { selectedSite = site },
                                onSettings: { settingsSite = site }
                            )
                            .background(
                                RoundedRectangle(cornerRadius: 22, style: .continuous)
                                    .fill(HomePalette.surface)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 22, style: .continuous)
                                    .strokeBorder(HomePalette.surfaceStroke, lineWidth: 1)
                            )
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 48)
            }
            .background(HomePalette.background.ignoresSafeArea())
            .navigationBarHidden(true)
            .sheet(item: $selectedSite) { site in
                SiteBrowserView(site: site) {
                    selectedSite = nil
                }
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                // `.automatic` lets the system grabber dismiss even when the site
                // webview (e.g. Reddit "Get the App" overlay) aggressively captures scrolls.
                // Feed scrolling still wins for typical mid-sheet pans.
                .presentationContentInteraction(.automatic)
                .interactiveDismissDisabled(false)
            }
            .sheet(item: $settingsSite) { site in
                SiteSettingsPlaceholderSheet(site: site) {
                    settingsSite = nil
                }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            // Proof / automation: -OpenSite instagram|youtube|facebook|reddit
            let args = ProcessInfo.processInfo.arguments
            if let idx = args.firstIndex(of: "-OpenSite"), args.index(after: idx) < args.endIndex {
                let raw = args[args.index(after: idx)].lowercased()
                if let site = Site.all.first(where: { $0.id == raw }) {
                    selectedSite = site
                }
            }
        }
    }
}

private struct SiteRowView: View {
    let site: Site
    let usage: UsageTime
    let onOpen: () -> Void
    let onSettings: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Button(action: onOpen) {
                HStack(alignment: .center, spacing: 14) {
                    Image(site.iconAssetName)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 44, height: 44)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                    Text(site.name)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(HomePalette.primaryText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("site-\(site.id)")

            VStack(alignment: .trailing, spacing: 2) {
                Text(usage.displayString)
                    .font(.footnote.monospacedDigit())
                    .foregroundStyle(HomePalette.secondaryText)
                    .accessibilityIdentifier("usage-\(site.id)")
                Text(usage.caption)
                    .font(.caption2)
                    .foregroundStyle(HomePalette.tertiaryText)
            }
            .frame(minWidth: 44, alignment: .trailing)

            Button(action: onSettings) {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(HomePalette.secondaryText)
                    .frame(width: 36, height: 36)
                    .background(
                        Circle()
                            .fill(HomePalette.gearFill)
                    )
                    .frame(width: 44, height: 44)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("settings-\(site.id)")
            .accessibilityLabel("Settings for \(site.name)")
        }
        .padding(.leading, 14)
        .padding(.trailing, 10)
        .padding(.vertical, 14)
    }
}

private struct SiteSettingsPlaceholderSheet: View {
    let site: Site
    let onDismiss: () -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                Text("Settings for \(site.name) will land soon.")
                    .font(.body)
                    .foregroundStyle(HomePalette.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding()
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(HomePalette.background.ignoresSafeArea())
            .navigationTitle(site.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done", action: onDismiss)
                }
            }
        }
        .preferredColorScheme(.dark)
        .presentationDetents([.medium])
    }
}

#Preview {
    HomeView()
}
