import SwiftUI

private enum HomePalette {
    /// Softened charcoal — not pure black.
    static let background = Color(white: 0.07)
    /// Soft near-white primary.
    static let primaryText = Color(white: 0.90)
    /// Secondary labels (usage time, gear) — Screen Time–like mute.
    static let secondaryText = Color(white: 0.55)
    /// Hairline separators.
    static let rowDivider = Color(white: 1.0).opacity(0.08)
}

struct HomeView: View {
    @State private var selectedSite: Site?
    @State private var settingsSite: Site?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Mindfully Social")
                        .font(.system(size: 34, weight: .bold, design: .default))
                        .foregroundStyle(HomePalette.primaryText)
                        .tracking(-0.4)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                        .accessibilityIdentifier("appTitle")

                    VStack(spacing: 0) {
                        ForEach(Array(Site.all.enumerated()), id: \.element.id) { index, site in
                            SiteRowView(
                                site: site,
                                usage: UsageTimeStore.daily(for: site.id),
                                onOpen: { selectedSite = site },
                                onSettings: { settingsSite = site }
                            )
                            if index < Site.all.count - 1 {
                                Rectangle()
                                    .fill(HomePalette.rowDivider)
                                    .frame(height: 0.33)
                                    .padding(.leading, 76)
                            }
                        }
                    }
                    .padding(.horizontal, 8)
                }
                .padding(.bottom, 40)
            }
            .background(HomePalette.background.ignoresSafeArea())
            .navigationBarHidden(true)
            .fullScreenCover(item: $selectedSite) { site in
                SiteBrowserView(site: site) {
                    selectedSite = nil
                }
            }
            .sheet(item: $settingsSite) { site in
                SiteSettingsPlaceholderSheet(site: site) {
                    settingsSite = nil
                }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            // Proof / automation: -OpenSite instagram|youtube
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
        HStack(spacing: 0) {
            Button(action: onOpen) {
                HStack(spacing: 14) {
                    Image(site.iconAssetName)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 40, height: 40)
                        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))

                    Text(site.name)
                        .font(.body.weight(.regular))
                        .foregroundStyle(HomePalette.primaryText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .contentShape(Rectangle())
                .padding(.vertical, 12)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("site-\(site.id)")

            HStack(spacing: 6) {
                Text(usage.displayString)
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(HomePalette.secondaryText)
                    .frame(minWidth: 36, alignment: .trailing)
                    .accessibilityIdentifier("usage-\(site.id)")

                Button(action: onSettings) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 17, weight: .regular))
                        .foregroundStyle(HomePalette.secondaryText)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("settings-\(site.id)")
            }
        }
        .padding(.leading, 12)
        .padding(.trailing, 4)
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
