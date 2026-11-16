import SwiftUI

struct HomeView: View {
    @State private var selectedSite: Site?

    private let columns = [
        GridItem(.flexible(), spacing: 24),
        GridItem(.flexible(), spacing: 24),
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    HStack(spacing: 12) {
                        Image("AppLogo")
                            .resizable()
                            .scaledToFill()
                            .frame(width: 44, height: 44)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .accessibilityHidden(true)

                        Text("Mindfully Social")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .accessibilityIdentifier("appTitle")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.top, 12)

                    LazyVGrid(columns: columns, spacing: 28) {
                        ForEach(Site.all) { site in
                            Button {
                                selectedSite = site
                            } label: {
                                VStack(spacing: 10) {
                                    Image(site.iconAssetName)
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 72, height: 72)
                                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                                    Text(site.name)
                                        .font(.subheadline.weight(.medium))
                                        .foregroundStyle(.white.opacity(0.9))
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("site-\(site.id)")
                        }
                    }
                    .padding(.horizontal, 28)
                }
                .padding(.bottom, 40)
            }
            .background(Color.black.ignoresSafeArea())
            .navigationBarHidden(true)
            .fullScreenCover(item: $selectedSite) { site in
                SiteBrowserView(site: site) {
                    selectedSite = nil
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

#Preview {
    HomeView()
}
