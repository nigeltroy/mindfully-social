import SwiftUI

@main
struct MindfullySocialApp: App {
    init() {
        PersistProbe.runIfRequested()
    }

    var body: some Scene {
        WindowGroup {
            HomeView()
                .preferredColorScheme(.dark)
        }
    }
}
