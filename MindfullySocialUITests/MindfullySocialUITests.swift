import XCTest

final class MindfullySocialUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testSearchesGoogleForCatAndOpensFirstResult() throws {
        let app = XCUIApplication()
        app.launch()

        let status = app.staticTexts["statusLabel"]
        XCTAssertTrue(status.waitForExistence(timeout: 10))

        let openButton = app.buttons["openFirstResultButton"]
        XCTAssertTrue(openButton.waitForExistence(timeout: 10))

        // Wait until search is ready or first result already opened (auto-open).
        let deadline = Date().addingTimeInterval(45)
        var opened = false
        while Date() < deadline {
            let text = status.label
            if text.hasPrefix("Opened:") || text.hasPrefix("Viewing") {
                opened = true
                break
            }
            if openButton.isEnabled {
                openButton.tap()
                // give navigation time
                Thread.sleep(forTimeInterval: 2)
            }
            Thread.sleep(forTimeInterval: 1)
        }

        let finalText = status.label
        XCTAssertTrue(
            opened || finalText.hasPrefix("Opened:") || finalText.hasPrefix("Viewing"),
            "Expected first result to open; status was: \(finalText)"
        )

        // Capture proof screenshot from XCTest
        let shot = app.screenshot()
        let attachment = XCTAttachment(screenshot: shot)
        attachment.name = "first-result-opened"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
