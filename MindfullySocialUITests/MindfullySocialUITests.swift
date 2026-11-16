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
}
