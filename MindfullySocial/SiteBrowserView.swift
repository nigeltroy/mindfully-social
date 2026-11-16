import SwiftUI

struct SiteBrowserView: View {
    let site: Site
    let onClose: () -> Void

    @StateObject private var model = BrowserModel()

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Button {
                    model.goBack()
                } label: {
                    Image(systemName: "chevron.backward")
                        .font(.body.weight(.semibold))
                        .frame(width: 36, height: 36)
                }
                .disabled(!model.canGoBack)
                .accessibilityIdentifier("browserBackButton")

                VStack(alignment: .leading, spacing: 2) {
                    Text(site.name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                    Text(model.titleText)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .accessibilityIdentifier("browserTitle")
                }

                Spacer(minLength: 8)

                if model.isLoading {
                    ProgressView()
                        .controlSize(.small)
                        .tint(.white)
                }

                Button {
                    onClose()
                } label: {
                    Image(systemName: "xmark")
                        .font(.body.weight(.semibold))
                        .frame(width: 36, height: 36)
                }
                .accessibilityIdentifier("browserCloseButton")
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color(white: 0.12))

            WebView(model: model)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .accessibilityIdentifier("browserWebView")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
        // Consume bottom safe-area so WKWebView reaches the home indicator.
        .ignoresSafeArea(edges: .bottom)
        .preferredColorScheme(.dark)
        .onAppear {
            model.load(url: site.url)
        }
    }
}

#Preview {
    SiteBrowserView(site: Site.all[0], onClose: {})
}
