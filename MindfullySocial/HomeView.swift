import SwiftUI

private enum HomePalette {
    /// Soft deep charcoal (not pure black).
    static let backgroundTop = Color(red: 0.09, green: 0.11, blue: 0.09)
    static let backgroundBottom = Color(red: 0.05, green: 0.06, blue: 0.05)
    /// Elevated inset surface for the destination group.
    static let surface = Color(white: 0.14)
    static let surfaceStroke = Color.white.opacity(0.06)
    /// Soft near-white primary.
    static let primaryText = Color(white: 0.93)
    static let secondaryText = Color(white: 0.58)
    static let tertiaryText = Color(white: 0.42)
    /// N1e grass green (sampled), softened for dark UI.
    static let brandGreen = Color(red: 0.22, green: 0.72, blue: 0.18)
    static let brandGreenSoft = Color(red: 0.22, green: 0.72, blue: 0.18).opacity(0.18)
    static let gearFill = Color.white.opacity(0.08)
    static let rowDivider = Color.white.opacity(0.07)
}

struct HomeView: View {
    @State private var selectedSite: Site?
    @State private var settingsSite: Site?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    header
                    destinationsSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 48)
            }
            .background { atmosphere.ignoresSafeArea() }
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

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Mindfully Social")
                .font(.system(size: 36, weight: .bold, design: .default))
                .foregroundStyle(HomePalette.primaryText)
                .tracking(-0.6)
                .accessibilityIdentifier("appTitle")

            Text("Choose where you spend time today.")
                .font(.subheadline)
                .foregroundStyle(HomePalette.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.trailing, 8)
    }

    private var destinationsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Capsule()
                    .fill(HomePalette.brandGreen)
                    .frame(width: 18, height: 3)
                Text("Destinations")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(HomePalette.secondaryText)
                    .textCase(.uppercase)
                    .tracking(0.8)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 4)

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
                            .frame(height: 1)
                            .padding(.leading, 78)
                    }
                }
            }
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

    private var atmosphere: some View {
        ZStack {
            LinearGradient(
                colors: [HomePalette.backgroundTop, HomePalette.backgroundBottom],
                startPoint: .top,
                endPoint: .bottom
            )
            RadialGradient(
                colors: [HomePalette.brandGreen.opacity(0.14), .clear],
                center: .topLeading,
                startRadius: 20,
                endRadius: 340
            )
            .blendMode(.plusLighter)
            .opacity(0.85)
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
                    ZStack {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(HomePalette.brandGreenSoft)
                            .frame(width: 52, height: 52)
                        Image(site.iconAssetName)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 44, height: 44)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        Text(site.name)
                            .font(.body.weight(.semibold))
                            .foregroundStyle(HomePalette.primaryText)
                        Text("Open site")
                            .font(.caption)
                            .foregroundStyle(HomePalette.tertiaryText)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("site-\(site.id)")

            VStack(alignment: .trailing, spacing: 2) {
                Text(usage.displayString)
                    .font(.system(size: 20, weight: .semibold, design: .rounded).monospacedDigit())
                    .foregroundStyle(HomePalette.primaryText)
                    .accessibilityIdentifier("usage-\(site.id)")
                Text(usage.caption)
                    .font(.caption2.weight(.medium))
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
            .background(HomePalette.backgroundBottom.ignoresSafeArea())
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
