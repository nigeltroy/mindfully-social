import SwiftUI

private enum HomePalette {
    /// Slightly lifted dark (not pure #000).
    static let background = Color(white: 0.08)
    /// Slightly muted white (not pure #FFF).
    static let primaryText = Color(white: 0.92)
    static let secondaryText = Color(white: 0.92).opacity(0.72)
    static let rowDivider = Color(white: 0.18)
}

struct HomeView: View {
    @State private var selectedSite: Site?
    @State private var settingsSite: Site?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    Text("Mindfully Social")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(HomePalette.primaryText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 20)
                        .padding(.top, 12)
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
                                Divider()
                                    .background(HomePalette.rowDivider)
                                    .padding(.leading, 72)
                            }
                        }
                    }
                    .padding(.horizontal, 12)
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
        HStack(spacing: 14) {
            Button(action: onOpen) {
                HStack(spacing: 14) {
                    Image(site.iconAssetName)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 44, height: 44)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                    Text(site.name)
                        .font(.body.weight(.medium))
                        .foregroundStyle(HomePalette.primaryText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("site-\(site.id)")

            Text(usage.displayString)
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(HomePalette.secondaryText)
                .accessibilityIdentifier("usage-\(site.id)")

            Button(action: onSettings) {
                Image(systemName: "gearshape")
                    .font(.body.weight(.medium))
                    .foregroundStyle(HomePalette.secondaryText)
                    .frame(width: 36, height: 36)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("settings-\(site.id)")
        }
        .padding(.horizontal, 8)
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
