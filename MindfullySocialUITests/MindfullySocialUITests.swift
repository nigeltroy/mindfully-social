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
        let web = app.otherElements["browserWebView"]
        XCTAssertTrue(web.waitForExistence(timeout: 20))

        Thread.sleep(forTimeInterval: 10)
        dismissIGAlerts(in: app)

        let beforeTop = XCTAttachment(screenshot: app.screenshot())
        beforeTop.name = "before-top"
        beforeTop.lifetime = .keepAlways
        add(beforeTop)

        // Deep scroll to surface ads / suggested blocks.
        for _ in 0..<8 {
            web.swipeUp()
            Thread.sleep(forTimeInterval: 1.2)
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
        XCTAssertTrue(web.waitForExistence(timeout: 20))
        Thread.sleep(forTimeInterval: 10)
        dismissIGAlerts(in: app)

        let afterTop = XCTAttachment(screenshot: app.screenshot())
        afterTop.name = "after-top"
        afterTop.lifetime = .keepAlways
        add(afterTop)

        for _ in 0..<8 {
            web.swipeUp()
            Thread.sleep(forTimeInterval: 1.2)
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
}
