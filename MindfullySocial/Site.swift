import Foundation

struct Site: Identifiable, Hashable {
    let id: String
    let name: String
    let iconAssetName: String
    let url: URL

    static let all: [Site] = [
        Site(
            id: "instagram",
            name: "Instagram",
            iconAssetName: "InstagramIcon",
            url: URL(string: "https://www.instagram.com")!
        ),
        Site(
            id: "youtube",
            name: "YouTube",
            iconAssetName: "YouTubeIcon",
            url: URL(string: "https://www.youtube.com")!
        ),
        Site(
            id: "facebook",
            name: "Facebook",
            iconAssetName: "FacebookIcon",
            url: URL(string: "https://www.facebook.com")!
        ),
    ]
}
