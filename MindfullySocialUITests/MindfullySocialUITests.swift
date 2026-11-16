import XCTest

final class MindfullySocialUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testHomeListOpensInstagramAndYouTube() throws {
        let app = XCUIApplication()
        app.launch()

        let title = app.staticTexts["appTitle"]
        XCTAssertTrue(title.waitForExistence(timeout: 10))

        let instagram = app.buttons["site-instagram"]
        let youtube = app.buttons["site-youtube"]
        XCTAssertTrue(instagram.waitForExistence(timeout: 5))
        XCTAssertTrue(youtube.exists)

        XCTAssertTrue(app.staticTexts["usage-instagram"].exists)
        XCTAssertTrue(app.staticTexts["usage-youtube"].exists)
        XCTAssertTrue(app.buttons["settings-instagram"].exists)
        XCTAssertTrue(app.buttons["settings-youtube"].exists)

        let homeShot = app.screenshot()
        let homeAttachment = XCTAttachment(screenshot: homeShot)
        homeAttachment.name = "home-list"
        homeAttachment.lifetime = .keepAlways
        add(homeAttachment)

        instagram.tap()
        let close = app.buttons["browserCloseButton"]
        XCTAssertTrue(close.waitForExistence(timeout: 15))
        let web = app.otherElements["browserWebView"]
        XCTAssertTrue(web.waitForExistence(timeout: 15))

        Thread.sleep(forTimeInterval: 4)
        let igShot = app.screenshot()
        let igAttachment = XCTAttachment(screenshot: igShot)
        igAttachment.name = "instagram-open"
        igAttachment.lifetime = .keepAlways
        add(igAttachment)

        close.tap()
        XCTAssertTrue(title.waitForExistence(timeout: 10))

        youtube.tap()
        XCTAssertTrue(close.waitForExistence(timeout: 15))
        Thread.sleep(forTimeInterval: 4)
        let ytShot = app.screenshot()
        let ytAttachment = XCTAttachment(screenshot: ytShot)
        ytAttachment.name = "youtube-open"
        ytAttachment.lifetime = .keepAlways
        add(ytAttachment)

        close.tap()
        XCTAssertTrue(title.waitForExistence(timeout: 10))
    }

    /// Scroll Instagram home feed, capture before/after style proof via launch flags.
    /// Relies on existing WKWebView session cookies (no credential printing).
    @MainActor
    func testInstagramFeedHideScrollProof() throws {
        let app = XCUIApplication()

        // --- BEFORE: feed hide disabled so Sponsored/Suggested stay visible ---
        app.launchArguments = ["-OpenSite", "instagram", "-DisableFeedHide", "-DumpIGFeed"]
        app.launch()

        let close = app.buttons["browserCloseButton"]
        XCTAssertTrue(close.waitForExistence(timeout: 25), "browser chrome missing")
        // WKWebView accessibility type varies; prefer webViews, fall back to any.
        let web = app.webViews.firstMatch
        XCTAssertTrue(web.waitForExistence(timeout: 20) || app.otherElements["browserWebView"].waitForExistence(timeout: 5))

        Thread.sleep(forTimeInterval: 10)
        dismissIGAlerts(in: app)

        let beforeTop = XCTAttachment(screenshot: app.screenshot())
        beforeTop.name = "before-top"
        beforeTop.lifetime = .keepAlways
        add(beforeTop)

        // Deep scroll via coordinates — identifier swipe is flaky on WKWebView.
        for _ in 0..<10 {
            swipeFeedUp(in: app)
            Thread.sleep(forTimeInterval: 1.1)
        }
        Thread.sleep(forTimeInterval: 3)
        dismissIGAlerts(in: app)

        let beforeScroll = XCTAttachment(screenshot: app.screenshot())
        beforeScroll.name = "before-scroll"
        beforeScroll.lifetime = .keepAlways
        add(beforeScroll)

        app.terminate()
        Thread.sleep(forTimeInterval: 2)

        // --- AFTER: feed hide enabled ---
        app.launchArguments = ["-OpenSite", "instagram", "-DumpIGFeed"]
        app.launch()
        XCTAssertTrue(close.waitForExistence(timeout: 25))
        _ = web.waitForExistence(timeout: 20)
        Thread.sleep(forTimeInterval: 10)
        dismissIGAlerts(in: app)

        let afterTop = XCTAttachment(screenshot: app.screenshot())
        afterTop.name = "after-top"
        afterTop.lifetime = .keepAlways
        add(afterTop)

        for _ in 0..<10 {
            swipeFeedUp(in: app)
            Thread.sleep(forTimeInterval: 1.1)
        }
        Thread.sleep(forTimeInterval: 4)
        dismissIGAlerts(in: app)

        let afterScroll = XCTAttachment(screenshot: app.screenshot())
        afterScroll.name = "after-scroll"
        afterScroll.lifetime = .keepAlways
        add(afterScroll)

        // Navigate away (Search) and back (Home) via bottom coords.
        let searchTap = app.coordinate(withNormalizedOffset: CGVector(dx: 0.37, dy: 0.93))
        searchTap.tap()
        Thread.sleep(forTimeInterval: 4)
        let searchShot = XCTAttachment(screenshot: app.screenshot())
        searchShot.name = "nav-search"
        searchShot.lifetime = .keepAlways
        add(searchShot)

        let homeTap = app.coordinate(withNormalizedOffset: CGVector(dx: 0.12, dy: 0.93))
        homeTap.tap()
        Thread.sleep(forTimeInterval: 5)
        let backHome = XCTAttachment(screenshot: app.screenshot())
        backHome.name = "nav-back-home"
        backHome.lifetime = .keepAlways
        add(backHome)

        // Soft reload via close + reopen.
        close.tap()
        Thread.sleep(forTimeInterval: 1)
        let instagram = app.buttons["site-instagram"]
        XCTAssertTrue(instagram.waitForExistence(timeout: 10))
        instagram.tap()
        XCTAssertTrue(close.waitForExistence(timeout: 20))
        Thread.sleep(forTimeInterval: 8)
        let softReload = XCTAttachment(screenshot: app.screenshot())
        softReload.name = "after-soft-reload"
        softReload.lifetime = .keepAlways
        add(softReload)
    }


    /// Short after-only proof: 3 scrolls, one screenshot. No before pass.
    @MainActor
    func testInstagramFeedHideAfterOnly() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-OpenSite", "instagram", "-DumpIGFeed"]
        app.launch()
        let close = app.buttons["browserCloseButton"]
        XCTAssertTrue(close.waitForExistence(timeout: 25))
        Thread.sleep(forTimeInterval: 12)
        dismissIGAlerts(in: app)
        let top = XCTAttachment(screenshot: app.screenshot())
        top.name = "after-top"
        top.lifetime = .keepAlways
        add(top)
        for _ in 0..<3 {
            swipeFeedUp(in: app)
            Thread.sleep(forTimeInterval: 1.2)
        }
        Thread.sleep(forTimeInterval: 3)
        let scroll = XCTAttachment(screenshot: app.screenshot())
        scroll.name = "after-scroll"
        scroll.lifetime = .keepAlways
        add(scroll)
    }

    @MainActor
    private func swipeFeedUp(in app: XCUIApplication) {
        let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.72))
        let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.28))
        start.press(forDuration: 0.05, thenDragTo: end)
    }

    @MainActor
    private func dismissIGAlerts(in app: XCUIApplication) {
        for _ in 0..<4 {
            let ok = app.alerts.buttons["OK"]
            if ok.waitForExistence(timeout: 0.8) {
                ok.tap()
                continue
            }
            let notNow = app.buttons["Not Now"]
            if notNow.waitForExistence(timeout: 0.5) {
                notNow.tap()
                continue
            }
            break
        }
    }

    /// Opens Instagram Explore, exercises Search, scrolls, and captures proof screenshots.
    /// Uses persisted WK session when available; falls back to env login fill if needed.
    @MainActor
    func testInstagramSearchHidesReels() throws {
        let app = XCUIApplication()
        // Open Instagram home first so we can log in on a fresh simulator.
        app.launchArguments = ["-OpenSite", "instagram", "-DumpIGExplore"]
        app.launch()

        let close = app.buttons["browserCloseButton"]
        XCTAssertTrue(close.waitForExistence(timeout: 25))
        Thread.sleep(forTimeInterval: 6)

        func dismissAlerts(times: Int = 4) {
            for _ in 0..<times {
                let alertOK = app.alerts.buttons["OK"]
                if alertOK.waitForExistence(timeout: 1) {
                    alertOK.tap()
                    Thread.sleep(forTimeInterval: 0.3)
                } else {
                    break
                }
            }
            let notNow = app.buttons["Not Now"]
            if notNow.waitForExistence(timeout: 1) { notNow.tap() }
        }
        dismissAlerts()

        let web = app.webViews.firstMatch
        XCTAssertTrue(web.waitForExistence(timeout: 10))
        let env = ProcessInfo.processInfo.environment

        func clearAndType(_ field: XCUIElement, text: String) {
            field.tap()
            Thread.sleep(forTimeInterval: 0.25)
            if let current = field.value as? String, !current.isEmpty {
                let delete = String(repeating: XCUIKeyboardKey.delete.rawValue, count: current.count + 2)
                field.typeText(delete)
            }
            field.typeText(text)
        }

        func attemptLoginIfNeeded() {
            guard
                let username = env["INSTAGRAM_USERNAME"], !username.isEmpty,
                let password = env["INSTAGRAM_PASSWORD"], !password.isEmpty
            else { return }

            // Logged-out explore/home often shows a Log in link before fields.
            let loginPred = NSPredicate(format: "label ==[c] %@", "Log in")
            let loginLink = app.descendants(matching: .any).matching(loginPred).firstMatch
            if loginLink.waitForExistence(timeout: 3), loginLink.isHittable {
                loginLink.tap()
                Thread.sleep(forTimeInterval: 3)
                dismissAlerts()
            }

            let userField = web.textFields.firstMatch
            guard userField.waitForExistence(timeout: 8) else { return }
            clearAndType(userField, text: username)
            let passField = web.secureTextFields.firstMatch
            if passField.waitForExistence(timeout: 5) {
                clearAndType(passField, text: password)
            } else {
                let anyPass = web.textFields.element(boundBy: 1)
                if anyPass.waitForExistence(timeout: 3) {
                    clearAndType(anyPass, text: password)
                }
            }
            dismissAlerts()
            let loginBtn = app.descendants(matching: .any).matching(loginPred).firstMatch
            if loginBtn.waitForExistence(timeout: 3), loginBtn.isHittable {
                loginBtn.tap()
            } else {
                app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.55)).tap()
            }
            Thread.sleep(forTimeInterval: 14)
            dismissAlerts()
        }

        attemptLoginIfNeeded()

        // Navigate to Explore after login (or if already logged in).
        app.terminate()
        app.launchArguments = [
            "-OpenSite", "instagram",
            "-OpenPath", "/explore/",
            "-DumpIGExplore"
        ]
        app.launch()
        XCTAssertTrue(close.waitForExistence(timeout: 25))
        Thread.sleep(forTimeInterval: 8)
        dismissAlerts()
        // If still logged out on explore, login once more then reopen explore.
        let stillLogin = app.descendants(matching: .any).matching(
            NSPredicate(format: "label ==[c] %@", "Log in")
        ).firstMatch
        if stillLogin.waitForExistence(timeout: 2) {
            attemptLoginIfNeeded()
            app.terminate()
            app.launchArguments = [
                "-OpenSite", "instagram",
                "-OpenPath", "/explore/",
                "-DumpIGExplore"
            ]
            app.launch()
            XCTAssertTrue(close.waitForExistence(timeout: 25))
            Thread.sleep(forTimeInterval: 8)
            dismissAlerts()
        }

        func attach(_ name: String) {
            let shot = app.screenshot()
            let att = XCTAttachment(screenshot: shot)
            att.name = name
            att.lifetime = .keepAlways
            add(att)
        }

        attach("explore-initial")

        // Scroll explore grid (drag webview).
        let webView = app.otherElements["browserWebView"].exists
            ? app.otherElements["browserWebView"]
            : app.webViews.firstMatch
        for i in 1...4 {
            webView.swipeUp()
            Thread.sleep(forTimeInterval: 1.2)
            if i == 2 || i == 4 { attach("explore-scroll-\(i)") }
        }

        // Tap Search / Explore bottom tab if present (SPA return path).
        let searchPred = NSPredicate(format: "label CONTAINS[c] %@ OR label CONTAINS[c] %@", "Search", "Explore")
        let searchTab = app.descendants(matching: .any).matching(searchPred).firstMatch
        if searchTab.waitForExistence(timeout: 2), searchTab.isHittable {
            searchTab.tap()
            Thread.sleep(forTimeInterval: 2)
            attach("explore-tab-retap")
        }

        // Type a query into search field if available.
        let searchField = app.webViews.textFields.firstMatch
        if searchField.waitForExistence(timeout: 4) {
            searchField.tap()
            Thread.sleep(forTimeInterval: 0.5)
            searchField.typeText("nature")
            Thread.sleep(forTimeInterval: 4)
            attach("search-query-nature")
            // Clear / close results by tapping cancel or back-ish control if present.
            let cancelPred = NSPredicate(format: "label ==[c] %@ OR label ==[c] %@", "Cancel", "Clear")
            let cancel = app.descendants(matching: .any).matching(cancelPred).firstMatch
            if cancel.waitForExistence(timeout: 2), cancel.isHittable {
                cancel.tap()
                Thread.sleep(forTimeInterval: 2)
                attach("search-closed")
            } else {
                // Tap outside / navigate home then back to explore.
                let homePred = NSPredicate(format: "label ==[c] %@", "Home")
                let home = app.descendants(matching: .any).matching(homePred).firstMatch
                if home.waitForExistence(timeout: 2), home.isHittable {
                    home.tap()
                    Thread.sleep(forTimeInterval: 3)
                    attach("left-to-home")
                    if searchTab.waitForExistence(timeout: 3), searchTab.isHittable {
                        searchTab.tap()
                        Thread.sleep(forTimeInterval: 3)
                        attach("return-to-explore")
                    }
                }
            }
        } else {
            // No search field — still exercise leave/return via Home if visible.
            let homePred = NSPredicate(format: "label ==[c] %@", "Home")
            let home = app.descendants(matching: .any).matching(homePred).firstMatch
            if home.waitForExistence(timeout: 2), home.isHittable {
                home.tap()
                Thread.sleep(forTimeInterval: 3)
                attach("left-to-home")
            }
            if searchTab.waitForExistence(timeout: 3), searchTab.isHittable {
                searchTab.tap()
                Thread.sleep(forTimeInterval: 3)
                attach("return-to-explore")
            }
        }

        Thread.sleep(forTimeInterval: 3)
        attach("explore-final")
        // Keep process alive briefly so -DumpIGExplore timers can flush.
        Thread.sleep(forTimeInterval: 6)
}
}
