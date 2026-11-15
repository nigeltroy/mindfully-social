import SwiftUI
import WebKit

struct BrowserView: View {
    @StateObject private var model = BrowserModel()

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Text(model.statusText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .accessibilityIdentifier("statusLabel")
                Spacer()
                Button("Open first result") {
                    model.openFirstResult()
                }
                .accessibilityIdentifier("openFirstResultButton")
                .disabled(!model.canOpenFirstResult)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            WebView(model: model)
                .accessibilityIdentifier("browserWebView")
        }
        .onAppear {
            model.startCatSearch()
        }
    }
}

#Preview {
    BrowserView()
}
