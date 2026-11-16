import Foundation
import WebKit

/// Launch-arg helpers to prove WKWebsiteDataStore.default cookie persistence
/// without Instagram/YouTube credentials.
///
/// -SeedPersistCookie  → write distinguishable cookie
/// -CheckPersistCookie → read cookie; write Documents/msa-persist-probe.txt
enum PersistProbe {
    static let cookieName = "msa_persist_probe"
    static let cookieValue = "mindfully-social-ok"
    static let cookieDomain = "example.com"
    static let reportFileName = "msa-persist-probe.txt"

    static func runIfRequested() {
        let args = ProcessInfo.processInfo.arguments
        if args.contains("-SeedPersistCookie") {
            seedCookie()
        }
        if args.contains("-CheckPersistCookie") {
            checkCookie()
        }
    }

    private static func seedCookie() {
        let store = WKWebsiteDataStore.default()
        precondition(store.isPersistent, "Expected persistent default website data store")

        let cookie = HTTPCookie(properties: [
            .domain: cookieDomain,
            .path: "/",
            .name: cookieName,
            .value: cookieValue,
            .secure: "TRUE",
            .expires: Date().addingTimeInterval(60 * 60 * 24 * 30),
        ])!

        // Avoid main-thread semaphore deadlock: completion may hop to main.
        store.httpCookieStore.setCookie(cookie) {
            writeReport("seeded isPersistent=\(store.isPersistent) cookie=\(cookieName)")
        }
    }

    private static func checkCookie() {
        let store = WKWebsiteDataStore.default()
        store.httpCookieStore.getAllCookies { cookies in
            let found = cookies.contains {
                $0.name == cookieName && $0.value == cookieValue && $0.domain.contains(cookieDomain)
            }
            writeReport(
                "check isPersistent=\(store.isPersistent) found=\(found) cookie=\(cookieName)"
            )
        }
    }

    private static func writeReport(_ line: String) {
        guard let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return
        }
        let url = docs.appendingPathComponent(reportFileName)
        let body = line + "\n"
        try? body.write(to: url, atomically: true, encoding: .utf8)
        NSLog("PersistProbe: %@", line)
    }
}
