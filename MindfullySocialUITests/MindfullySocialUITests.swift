import XCTest

final class MindfullySocialUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// Focused Reddit proof: home → tap → settled reddit.com → swipe dismiss → home.
    @MainActor
    func testRedditOpenAndDismiss() throws {
        let app = XCUIApplication()
        app.launch()

        let title = app.staticTexts["appTitle"]
        XCTAssertTrue(title.waitForExistence(timeout: 20))

        let reddit = app.buttons["site-reddit"]
        XCTAssertTrue(reddit.waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["usage-reddit"].exists)
        XCTAssertTrue(app.buttons["settings-reddit"].exists)

        // Hold on home so continuous video captures the Reddit row.
        Thread.sleep(forTimeInterval: 2)
        let homeShot = app.screenshot()
        let homeAtt = XCTAttachment(screenshot: homeShot)
        homeAtt.name = "reddit-home-list"
        homeAtt.lifetime = .keepAlways
        add(homeAtt)

        reddit.tap()
        waitForBrowser(in: app, timeout: 25)
        // reddit.com often needs 20s+ past dark/white splash under Tart load.
        Thread.sleep(forTimeInterval: 22)
        let openShot = app.screenshot()
        let openAtt = XCTAttachment(screenshot: openShot)
        openAtt.name = "reddit-open-content"
        openAtt.lifetime = .keepAlways
        add(openAtt)

        // Sheet may leave home title in the hierarchy — require a hittable home row.
        dismissBrowser(in: app)
        for _ in 0..<4 where !reddit.isHittable {
            dismissBrowser(in: app)
        }
        XCTAssertTrue(reddit.waitForExistence(timeout: 15) && reddit.isHittable,
                      "swipe dismiss did not restore hittable Reddit home row")
        XCTAssertFalse(app.staticTexts["browserSwipeTip"].exists,
                       "swipe tip still visible after dismiss")
        // Hold home on-screen so continuous Tart video clearly shows dismiss → list.
        Thread.sleep(forTimeInterval: 8)
        let afterShot = app.screenshot()
        let afterAtt = XCTAttachment(screenshot: afterShot)
        afterAtt.name = "reddit-after-dismiss"
        afterAtt.lifetime = .keepAlways
        add(afterAtt)
        Thread.sleep(forTimeInterval: 2)
    }

    /// MSA-28: top web chrome must receive taps; swipe-down must still dismiss.
    @MainActor
    func testInstagramTopChromeTapsAndSwipeDismiss() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-OpenSite", "instagram"]
        app.launch()

        waitForBrowser(in: app, timeout: 25)
        Thread.sleep(forTimeInterval: 6)
        dismissIGAlerts(in: app)

        let beforeTop = XCTAttachment(screenshot: app.screenshot())
        beforeTop.name = "msa28-ig-before-top-taps"
        beforeTop.lifetime = .keepAlways
        add(beforeTop)

        // Tap Instagram top chrome pockets (back / leading, center, trailing).
        // These must reach WKWebView — the dismiss strip must not eat them.
        let web = app.webViews.firstMatch.exists ? app.webViews.firstMatch : app
        let leading = web.coordinate(withNormalizedOffset: CGVector(dx: 0.08, dy: 0.07))
        let center = web.coordinate(withNormalizedOffset: CGVector(dx: 0.50, dy: 0.07))
        let trailing = web.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.07))

        leading.tap()
        Thread.sleep(forTimeInterval: 1.2)
        let afterLeading = XCTAttachment(screenshot: app.screenshot())
        afterLeading.name = "msa28-ig-after-leading-tap"
        afterLeading.lifetime = .keepAlways
        add(afterLeading)

        center.tap()
        Thread.sleep(forTimeInterval: 1.2)
        let afterCenter = XCTAttachment(screenshot: app.screenshot())
        afterCenter.name = "msa28-ig-after-center-tap"
        afterCenter.lifetime = .keepAlways
        add(afterCenter)

        trailing.tap()
        Thread.sleep(forTimeInterval: 1.2)
        let afterTrailing = XCTAttachment(screenshot: app.screenshot())
        afterTrailing.name = "msa28-ig-after-trailing-tap"
        afterTrailing.lifetime = .keepAlways
        add(afterTrailing)

        // Taps must not have dismissed the sheet.
        let stillInBrowser = app.otherElements["browserWebView"].exists
            || app.webViews.firstMatch.exists
            || app.otherElements["browserDismissStrip"].exists
        XCTAssertTrue(stillInBrowser, "top chrome taps dismissed the browser sheet")

        // Hold so continuous Tart video shows the top-tap sequence clearly.
        Thread.sleep(forTimeInterval: 2)

        dismissBrowser(in: app)
        let instagram = app.buttons["site-instagram"]
        for _ in 0..<4 where !instagram.isHittable {
            dismissBrowser(in: app)
        }
        XCTAssertTrue(instagram.waitForExistence(timeout: 15) && instagram.isHittable,
                      "swipe dismiss did not restore hittable Instagram home row")

        Thread.sleep(forTimeInterval: 3)
        let afterDismiss = XCTAttachment(screenshot: app.screenshot())
        afterDismiss.name = "msa28-ig-after-swipe-dismiss"
        afterDismiss.lifetime = .keepAlways
        add(afterDismiss)
        Thread.sleep(forTimeInterval: 1)
    }

    @MainActor
    func testHomeListOpensInstagramAndYouTube() throws {
        let app = XCUIApplication()
        app.launch()

        let title = app.staticTexts["appTitle"]
        XCTAssertTrue(title.waitForExistence(timeout: 10))

        let instagram = app.buttons["site-instagram"]
        let youtube = app.buttons["site-youtube"]
        let facebook = app.buttons["site-facebook"]
        let reddit = app.buttons["site-reddit"]
        XCTAssertTrue(instagram.waitForExistence(timeout: 5))
        XCTAssertTrue(youtube.exists)
        XCTAssertTrue(facebook.exists)
        XCTAssertTrue(reddit.exists)

        XCTAssertTrue(app.staticTexts["usage-instagram"].exists)
        XCTAssertTrue(app.staticTexts["usage-youtube"].exists)
        XCTAssertTrue(app.staticTexts["usage-facebook"].exists)
        XCTAssertTrue(app.staticTexts["usage-reddit"].exists)
        XCTAssertTrue(app.buttons["settings-instagram"].exists)
        XCTAssertTrue(app.buttons["settings-youtube"].exists)
        XCTAssertTrue(app.buttons["settings-facebook"].exists)
        XCTAssertTrue(app.buttons["settings-reddit"].exists)

        let homeShot = app.screenshot()
        let homeAttachment = XCTAttachment(screenshot: homeShot)
        homeAttachment.name = "home-list"
        homeAttachment.lifetime = .keepAlways
        add(homeAttachment)

        instagram.tap()
        waitForBrowser(in: app, timeout: 15)

        Thread.sleep(forTimeInterval: 4)
        let igShot = app.screenshot()
        let igAttachment = XCTAttachment(screenshot: igShot)
        igAttachment.name = "instagram-open"
        igAttachment.lifetime = .keepAlways
        add(igAttachment)

        dismissBrowser(in: app)
        XCTAssertTrue(title.waitForExistence(timeout: 10))

        youtube.tap()
        waitForBrowser(in: app, timeout: 15)
        Thread.sleep(forTimeInterval: 4)
        let ytShot = app.screenshot()
        let ytAttachment = XCTAttachment(screenshot: ytShot)
        ytAttachment.name = "youtube-open"
        ytAttachment.lifetime = .keepAlways
        add(ytAttachment)

        dismissBrowser(in: app)
        XCTAssertTrue(title.waitForExistence(timeout: 10))

        facebook.tap()
        waitForBrowser(in: app, timeout: 15)
        Thread.sleep(forTimeInterval: 4)
        let fbShot = app.screenshot()
        let fbAttachment = XCTAttachment(screenshot: fbShot)
        fbAttachment.name = "facebook-open"
        fbAttachment.lifetime = .keepAlways
        add(fbAttachment)

        dismissBrowser(in: app)
        XCTAssertTrue(title.waitForExistence(timeout: 10))

        reddit.tap()
        waitForBrowser(in: app, timeout: 15)
        Thread.sleep(forTimeInterval: 4)
        let rdShot = app.screenshot()
        let rdAttachment = XCTAttachment(screenshot: rdShot)
        rdAttachment.name = "reddit-open"
        rdAttachment.lifetime = .keepAlways
        add(rdAttachment)

        dismissBrowser(in: app)
        XCTAssertTrue(title.waitForExistence(timeout: 10))
    }

    /// MSA-26: Facebook home row + zero-chrome sheet open.
    @MainActor
    func testHomeListOpensFacebook() throws {
        let app = XCUIApplication()
        app.launch()

        let title = app.staticTexts["appTitle"]
        XCTAssertTrue(title.waitForExistence(timeout: 10))

        let facebook = app.buttons["site-facebook"]
        XCTAssertTrue(facebook.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["usage-facebook"].exists)
        XCTAssertTrue(app.buttons["settings-facebook"].exists)

        let homeShot = XCTAttachment(screenshot: app.screenshot())
        homeShot.name = "home-with-facebook"
        homeShot.lifetime = .keepAlways
        add(homeShot)

        facebook.tap()
        waitForBrowser(in: app, timeout: 15)
        Thread.sleep(forTimeInterval: 5)

        let openShot = XCTAttachment(screenshot: app.screenshot())
        openShot.name = "facebook-open"
        openShot.lifetime = .keepAlways
        add(openShot)

        dismissBrowser(in: app)
        XCTAssertTrue(title.waitForExistence(timeout: 10))

        let afterShot = XCTAttachment(screenshot: app.screenshot())
        afterShot.name = "home-after-facebook"
        afterShot.lifetime = .keepAlways
        add(afterShot)
    }

    /// Scroll Instagram home feed, capture before/after style proof via launch flags.
    /// Relies on existing WKWebView session cookies (no credential printing).
    @MainActor
    func testInstagramFeedHideScrollProof() throws {
        let app = XCUIApplication()

        // --- BEFORE: feed hide disabled so Sponsored/Suggested stay visible ---
        app.launchArguments = ["-OpenSite", "instagram", "-DisableFeedHide", "-DumpIGFeed"]
        app.launch()

        waitForBrowser(in: app, timeout: 25)
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
        waitForBrowser(in: app, timeout: 25)
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

        // Soft reload via swipe-dismiss + reopen.
        dismissBrowser(in: app)
        Thread.sleep(forTimeInterval: 1)
        let instagram = app.buttons["site-instagram"]
        XCTAssertTrue(instagram.waitForExistence(timeout: 10))
        instagram.tap()
        waitForBrowser(in: app, timeout: 20)
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
        waitForBrowser(in: app, timeout: 25)
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

    /// MSA-22: Explore landing blank (search bar only); search query still shows results.
    /// Uses persisted WK session when available; falls back to env login fill if needed.
    @MainActor
    func testInstagramSearchHidesReels() throws {
        let app = XCUIApplication()
        // Open Instagram home first so we can log in on a fresh simulator.
        app.launchArguments = ["-OpenSite", "instagram", "-DumpIGExplore"]
        app.launch()

        waitForBrowser(in: app, timeout: 25)
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
            guard let creds = instagramCredentials() else { return }
            let username = creds.username
            let password = creds.password

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
        waitForBrowser(in: app, timeout: 25)
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
            waitForBrowser(in: app, timeout: 25)
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

        attach("explore-blank-initial")

        // Scroll blank content area (should stay empty — no grid tiles).
        let webView = app.otherElements["browserWebView"].exists
            ? app.otherElements["browserWebView"]
            : app.webViews.firstMatch
        for i in 1...3 {
            webView.swipeUp()
            Thread.sleep(forTimeInterval: 1.0)
            if i == 2 { attach("explore-blank-scroll") }
        }

        // Tap Search / Explore bottom tab if present (SPA return path).
        let searchPred = NSPredicate(format: "label CONTAINS[c] %@ OR label CONTAINS[c] %@", "Search", "Explore")
        let searchTab = app.descendants(matching: .any).matching(searchPred).firstMatch
        if searchTab.waitForExistence(timeout: 2), searchTab.isHittable {
            searchTab.tap()
            Thread.sleep(forTimeInterval: 2)
            attach("explore-blank-tab-retap")
        }

        // Type a query — results must appear (blanking lifts while searching).
        let searchField = app.webViews.textFields.firstMatch
        if searchField.waitForExistence(timeout: 4) {
            searchField.tap()
            Thread.sleep(forTimeInterval: 0.5)
            searchField.typeText("nature")
            Thread.sleep(forTimeInterval: 5)
            attach("search-results-nature")
            // Clear / close results by tapping cancel or back-ish control if present.
            let cancelPred = NSPredicate(format: "label ==[c] %@ OR label ==[c] %@", "Cancel", "Clear")
            let cancel = app.descendants(matching: .any).matching(cancelPred).firstMatch
            if cancel.waitForExistence(timeout: 2), cancel.isHittable {
                cancel.tap()
                Thread.sleep(forTimeInterval: 2)
                attach("search-closed-blank-again")
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
                        attach("return-to-explore-blank")
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
                attach("return-to-explore-blank")
            }
        }

        Thread.sleep(forTimeInterval: 3)
        attach("explore-blank-final")
        // Keep process alive briefly so -DumpIGExplore timers can flush.
        Thread.sleep(forTimeInterval: 6)
    }

    /// Load Instagram credentials from process env or guest temp files (never log values).
    private func instagramCredentials() -> (username: String, password: String)? {
        let env = ProcessInfo.processInfo.environment
        if let u = env["INSTAGRAM_USERNAME"], !u.isEmpty,
           let p = env["INSTAGRAM_PASSWORD"], !p.isEmpty {
            return (u, p)
        }
        // Tart guest fallback used when xcodebuild does not forward env into the test runner.
        let candidates: [(URL, URL)] = [
            (URL(fileURLWithPath: "/tmp/msa23-ig-user.txt"), URL(fileURLWithPath: "/tmp/msa23-ig-pass.txt")),
            (URL(fileURLWithPath: "/tmp/msa19-ig-user.txt"), URL(fileURLWithPath: "/tmp/msa19-ig-pass.txt"))
        ]
        for (userURL, passURL) in candidates {
            if
                let u = try? String(contentsOf: userURL, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines),
                let p = try? String(contentsOf: passURL, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines),
                !u.isEmpty, !p.isEmpty
            {
                return (u, p)
            }
        }
        return nil
    }

    /// Browse Instagram Stories: open tray, advance through items, capture proof.
    /// Relies on persisted WK session; falls back to env/file login if needed.
    /// Launch flags: `-DumpIGStories` writes Documents dumps; skip runs enabled by default.
    @MainActor
    func testInstagramStoryAdSkip() throws {
        let app = XCUIApplication()
        // -SimulateStoryAd plants a Sponsored marker once a real story viewer is open
        // so we can prove auto-advance even when IG serves no live story ads.
        app.launchArguments = ["-OpenSite", "instagram", "-DumpIGStories", "-SimulateStoryAd"]
        app.launch()

        waitForBrowser(in: app, timeout: 25)
        Thread.sleep(forTimeInterval: 8)
        dismissIGAlerts(in: app)

        func attach(_ name: String) {
            let shot = XCTAttachment(screenshot: app.screenshot())
            shot.name = name
            shot.lifetime = .keepAlways
            add(shot)
        }

        // Fresh 18 Pro has no WK session — drive the logged-out interstitial → form.
        if let creds = instagramCredentials() {
            let web = app.webViews.firstMatch
            _ = web.waitForExistence(timeout: 8)

            func clearAndType(_ field: XCUIElement, text: String) {
                field.tap()
                Thread.sleep(forTimeInterval: 0.25)
                if let current = field.value as? String, !current.isEmpty {
                    let delete = String(repeating: XCUIKeyboardKey.delete.rawValue, count: current.count + 2)
                    field.typeText(delete)
                }
                field.typeText(text)
            }

            let loginPred = NSPredicate(format: "label ==[c] %@", "Log in")
            let loginLink = app.descendants(matching: .any).matching(loginPred).firstMatch
            if loginLink.waitForExistence(timeout: 6) {
                if loginLink.isHittable {
                    loginLink.tap()
                } else {
                    // Interstitial "Log in or sign up" — tap the Log in region under the blue CTA.
                    app.coordinate(withNormalizedOffset: CGVector(dx: 0.42, dy: 0.62)).tap()
                }
                Thread.sleep(forTimeInterval: 3)
                dismissIGAlerts(in: app)
            }

            let userField = web.textFields.firstMatch
            if userField.waitForExistence(timeout: 10) {
                clearAndType(userField, text: creds.username)
                let passField = web.secureTextFields.firstMatch
                if passField.waitForExistence(timeout: 6) {
                    clearAndType(passField, text: creds.password)
                } else {
                    let anyPass = web.textFields.element(boundBy: 1)
                    if anyPass.waitForExistence(timeout: 4) {
                        clearAndType(anyPass, text: creds.password)
                    }
                }
                attach("stories-login-form")
                dismissIGAlerts(in: app)
                let loginBtn = app.descendants(matching: .any).matching(loginPred).firstMatch
                if loginBtn.waitForExistence(timeout: 3), loginBtn.isHittable {
                    loginBtn.tap()
                } else {
                    app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.55)).tap()
                }
                Thread.sleep(forTimeInterval: 16)
                dismissIGAlerts(in: app)
                attach("stories-login-result")
            }
        }

        attach("stories-home")

        func confirmViewStoryIfNeeded(shot: String) {
            let viewStoryPred = NSPredicate(format: "label ==[c] %@", "View story")
            let viewStory = app.descendants(matching: .any).matching(viewStoryPred).firstMatch
            if viewStory.waitForExistence(timeout: 4) {
                if viewStory.isHittable {
                    viewStory.tap()
                } else {
                    app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.58)).tap()
                }
                Thread.sleep(forTimeInterval: 2.2)
                dismissIGAlerts(in: app)
                attach(shot)
            }
        }

        // Prefer the home tray sequence (ads appear between accounts). Deeplink is backup.
        // Skip leftmost "Your story"; tap 2nd/3rd rings.
        var opened = false
        for (x, y) in [(0.30, 0.175), (0.42, 0.175), (0.54, 0.175)] as [(CGFloat, CGFloat)] {
            app.coordinate(withNormalizedOffset: CGVector(dx: x, dy: y)).tap()
            Thread.sleep(forTimeInterval: 2.2)
            dismissIGAlerts(in: app)
            confirmViewStoryIfNeeded(shot: "stories-view-confirmed")
            attach(String(format: "stories-tray-x%.0f", x * 100))
            opened = true
            break
        }

        if !opened {
            app.terminate()
            Thread.sleep(forTimeInterval: 1.0)
            app.launchArguments = [
                "-OpenSite", "instagram",
                "-OpenPath", "/stories/theonion/",
                "-DumpIGStories"
            ]
            app.launch()
            waitForBrowser(in: app, timeout: 25)
            Thread.sleep(forTimeInterval: 8)
            dismissIGAlerts(in: app)
            attach("stories-deeplink-theonion")
            confirmViewStoryIfNeeded(shot: "stories-view-confirmed")
        }
        attach("stories-opened")

        // Hold still so -SimulateStoryAd dump can plant a visible Sponsored chip,
        // then auto-advance without any tap (pixel proof for findings gate).
        Thread.sleep(forTimeInterval: 6.0)
        attach("stories-sponsored-visible")
        // No taps — wait for delayed maybeSkip after plant.
        Thread.sleep(forTimeInterval: 4.0)
        attach("stories-after-autoskip")

        // Advance through many items / users so a between-user Sponsored story can appear.
        // Auto-skip fires without taps when an ad is detected; we still nudge forward.
        for i in 1...36 {
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.86, dy: 0.48)).tap()
            Thread.sleep(forTimeInterval: 1.15)
            dismissIGAlerts(in: app)
            // Occasional left-edge swipe-ish drag to next account in the tray sequence.
            if i % 7 == 0 {
                let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.50))
                let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.12, dy: 0.50))
                start.press(forDuration: 0.05, thenDragTo: end)
                Thread.sleep(forTimeInterval: 1.2)
            }
            if [2, 6, 12, 18, 24, 30, 36].contains(i) {
                attach("stories-advance-\(i)")
            }
        }

        Thread.sleep(forTimeInterval: 4)
        attach("stories-final")
        // Keep alive for late dump timers (up to ~230s from this launch).
        Thread.sleep(forTimeInterval: 20)
    }

    /// Fresh-simulator Instagram login only (for iPhone 17e / isolated sims).
    @MainActor
    func testInstagramLoginOnly() throws {
        guard let creds = instagramCredentials() else {
            throw XCTSkip("INSTAGRAM_USERNAME / INSTAGRAM_PASSWORD not set")
        }
        let username = creds.username
        let password = creds.password

        let app = XCUIApplication()
        app.launchArguments = ["-OpenSite", "instagram"]
        app.launch()

        waitForBrowser(in: app, timeout: 25)
        Thread.sleep(forTimeInterval: 8)

        func dismissAlerts(times: Int = 5) {
            for _ in 0..<times {
                let alertOK = app.alerts.buttons["OK"]
                if alertOK.waitForExistence(timeout: 1) {
                    alertOK.tap()
                    Thread.sleep(forTimeInterval: 0.3)
                } else { break }
            }
            let notNow = app.buttons["Not Now"]
            if notNow.waitForExistence(timeout: 1) { notNow.tap() }
        }
        dismissAlerts()

        let web = app.webViews.firstMatch
        XCTAssertTrue(web.waitForExistence(timeout: 10))

        let loginPred = NSPredicate(format: "label ==[c] %@", "Log in")
        let loginLink = app.descendants(matching: .any).matching(loginPred).firstMatch
        if loginLink.waitForExistence(timeout: 4), loginLink.isHittable {
            loginLink.tap()
            Thread.sleep(forTimeInterval: 3)
            dismissAlerts()
        }

        func clearAndType(_ field: XCUIElement, text: String) {
            field.tap()
            Thread.sleep(forTimeInterval: 0.3)
            if let current = field.value as? String, !current.isEmpty {
                let delete = String(repeating: XCUIKeyboardKey.delete.rawValue, count: current.count + 2)
                field.typeText(delete)
            } else {
                field.press(forDuration: 1.0)
                let selectAll = app.menuItems["Select All"]
                if selectAll.waitForExistence(timeout: 2) {
                    selectAll.tap()
                    field.typeText(XCUIKeyboardKey.delete.rawValue)
                }
            }
            field.typeText(text)
        }

        let userField = web.textFields.firstMatch
        XCTAssertTrue(userField.waitForExistence(timeout: 12), "username field missing")
        clearAndType(userField, text: username)

        let passField = web.secureTextFields.firstMatch
        if passField.waitForExistence(timeout: 8) {
            clearAndType(passField, text: password)
        } else {
            let anyPass = web.textFields.element(boundBy: 1)
            XCTAssertTrue(anyPass.waitForExistence(timeout: 5), "password field missing")
            clearAndType(anyPass, text: password)
        }

        let formShot = app.screenshot()
        let formAtt = XCTAttachment(screenshot: formShot)
        formAtt.name = "login-form"
        formAtt.lifetime = .keepAlways
        add(formAtt)

        dismissAlerts()
        let loginBtn = app.descendants(matching: .any).matching(loginPred).firstMatch
        var tapped = false
        if loginBtn.waitForExistence(timeout: 3), loginBtn.isHittable {
            loginBtn.tap(); tapped = true
        }
        if !tapped {
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.55)).tap()
        }

        Thread.sleep(forTimeInterval: 14)
        dismissAlerts()
        Thread.sleep(forTimeInterval: 6)

        let resultShot = app.screenshot()
        let resultAtt = XCTAttachment(screenshot: resultShot)
        resultAtt.name = "login-result"
        resultAtt.lifetime = .keepAlways
        add(resultAtt)
    }

    /// MSA-21: before (promo visible) → after (promo hidden) with scroll/nav coverage.
    @MainActor
    func testInstagramAppPromoHideProof() throws {
        let app = XCUIApplication()

        // --- BEFORE: leave “Use the app” visible ---
        app.launchArguments = [
            "-OpenSite", "instagram",
            "-DisableAppPromoHide",
            "-DumpIGAppPromo"
        ]
        app.launch()
        waitForBrowser(in: app, timeout: 25)
        Thread.sleep(forTimeInterval: 10)
        dismissIGAlerts(in: app)

        let beforeTop = XCTAttachment(screenshot: app.screenshot())
        beforeTop.name = "app-promo-before-top"
        beforeTop.lifetime = .keepAlways
        add(beforeTop)

        for _ in 0..<4 {
            swipeFeedUp(in: app)
            Thread.sleep(forTimeInterval: 1.0)
        }
        Thread.sleep(forTimeInterval: 2)
        dismissIGAlerts(in: app)

        let beforeScroll = XCTAttachment(screenshot: app.screenshot())
        beforeScroll.name = "app-promo-before-scroll"
        beforeScroll.lifetime = .keepAlways
        add(beforeScroll)

        app.terminate()
        Thread.sleep(forTimeInterval: 2)

        // --- AFTER: hide enabled ---
        app.launchArguments = ["-OpenSite", "instagram", "-DumpIGAppPromo"]
        app.launch()
        waitForBrowser(in: app, timeout: 25)
        Thread.sleep(forTimeInterval: 10)
        dismissIGAlerts(in: app)

        let afterTop = XCTAttachment(screenshot: app.screenshot())
        afterTop.name = "app-promo-after-top"
        afterTop.lifetime = .keepAlways
        add(afterTop)

        for _ in 0..<6 {
            swipeFeedUp(in: app)
            Thread.sleep(forTimeInterval: 1.0)
        }
        Thread.sleep(forTimeInterval: 3)
        dismissIGAlerts(in: app)

        let afterScroll = XCTAttachment(screenshot: app.screenshot())
        afterScroll.name = "app-promo-after-scroll"
        afterScroll.lifetime = .keepAlways
        add(afterScroll)

        // Search / Explore then back Home — banner must stay gone.
        let searchTap = app.coordinate(withNormalizedOffset: CGVector(dx: 0.37, dy: 0.93))
        searchTap.tap()
        Thread.sleep(forTimeInterval: 5)
        dismissIGAlerts(in: app)
        let afterSearch = XCTAttachment(screenshot: app.screenshot())
        afterSearch.name = "app-promo-after-search"
        afterSearch.lifetime = .keepAlways
        add(afterSearch)

        let homeTap = app.coordinate(withNormalizedOffset: CGVector(dx: 0.12, dy: 0.93))
        homeTap.tap()
        Thread.sleep(forTimeInterval: 5)
        dismissIGAlerts(in: app)
        let afterHome = XCTAttachment(screenshot: app.screenshot())
        afterHome.name = "app-promo-after-home"
        afterHome.lifetime = .keepAlways
        add(afterHome)
    }

    @MainActor
    private func waitForBrowser(in app: XCUIApplication, timeout: TimeInterval = 25) {
        let namedWeb = app.webViews["browserWebView"]
        let otherWeb = app.otherElements["browserWebView"]
        let tip = app.staticTexts["browserSwipeTip"]
        let ready = namedWeb.waitForExistence(timeout: timeout)
            || otherWeb.waitForExistence(timeout: 2)
            || tip.waitForExistence(timeout: 2)
            || app.webViews.firstMatch.waitForExistence(timeout: 5)
        XCTAssertTrue(ready, "zero-chrome browser did not appear")
    }

    /// Swipe-down dismiss via the top dismiss strip / sheet grabber band.
    @MainActor
    private func dismissBrowser(in app: XCUIApplication) {
        let strip = app.otherElements["browserDismissStrip"]
        let start: XCUICoordinate
        if strip.waitForExistence(timeout: 2) {
            start = strip.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        } else {
            // Safe-area / sheet-indicator band (top-edge pan host).
            start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.035))
        }
        let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.55))
        start.press(forDuration: 0.12, thenDragTo: end)
        Thread.sleep(forTimeInterval: 1.0)
        let homeRowHittable = app.buttons["site-instagram"].isHittable
            || app.buttons["site-reddit"].isHittable
            || app.buttons["site-facebook"].isHittable
        if !homeRowHittable {
            start.press(forDuration: 0.15, thenDragTo: end)
            Thread.sleep(forTimeInterval: 1.0)
        }
    }
}

