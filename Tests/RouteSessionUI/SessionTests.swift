import XCTest

final class RouteSessionTests: XCTestCase {
    private func launch(_ arguments: [String] = []) -> XCUIApplication {
        let app = XCUIApplication(bundleIdentifier: "local.trollroute.sessionui")
        app.launchArguments = arguments
        app.launch()
        return app
    }
    private func capture(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
    private func waitState(_ app: XCUIApplication, _ text: String) {
        let state = app.staticTexts["session-state"]
        let expected = NSPredicate(format: "label CONTAINS %@", text)
        expectation(for: expected, evaluatedWith: state)
        waitForExpectations(timeout: 10)
    }
    private func stop(_ app: XCUIApplication) {
        let button = app.buttons["Stop route"]
        XCTAssertTrue(button.waitForExistence(timeout: 10))
        button.tap()
        XCTAssertTrue(app.buttons["confirm-route-stop"].waitForExistence(timeout: 5))
    }
    func testRealStartStopChoicesCancelAndConfirm() {
        let app = launch()
        stop(app)
        XCTAssertFalse(app.buttons["route-stop-previous"].exists)
        XCTAssertTrue(app.buttons["route-stop-specific"].exists)
        XCTAssertEqual(app.buttons["route-stop-current"].value as? String, "Selected")
        capture(app, "route-stop-real-start")
        app.buttons["Cancel"].tap()
        waitState(app, "running=true")
        stop(app)
        app.buttons["route-stop-current"].tap()
        app.buttons["confirm-route-stop"].tap()
        waitState(app, "running=false")
        waitState(app, "active=true")
        waitState(app, "stops=0")
    }
    func testPreviousStopAndExplicitReal() {
        let app = launch(["--previous"])
        stop(app)
        XCTAssertTrue(app.buttons["route-stop-previous"].exists)
        XCTAssertFalse(app.buttons["route-stop-specific"].exists)
        XCTAssertEqual(app.buttons["route-stop-previous"].value as? String, "Selected")
        capture(app, "route-stop-previous-spoof")
        app.buttons["route-stop-real"].tap()
        app.buttons["confirm-route-stop"].tap()
        waitState(app, "running=false")
        waitState(app, "active=false")
        XCTAssertFalse(app.alerts["Stop location spoofing?"].exists)
    }
    func testLiveFinishAndPanelCredits() {
        let app = launch()
        XCTAssertTrue(app.buttons["edit-route-finish"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.staticTexts.matching(identifier: "active-route-credit").count, 1)
        capture(app, "route-panel-finish-credit-expanded")
        app.buttons["edit-route-finish"].tap()
        XCTAssertTrue(app.buttons["route-finish-action"].waitForExistence(timeout: 5))
        app.buttons["route-finish-action"].tap()
        app.buttons["Drive back to start"].tap()
        capture(app, "live-finish-current-leg")
        app.buttons["Done"].tap()
        waitState(app, "action=returnOnce")
        waitState(app, "default=stay")
        app.buttons["Collapse route controls"].tap()
        XCTAssertTrue(app.buttons["Expand route controls"].exists)
        XCTAssertEqual(app.staticTexts.matching(identifier: "active-route-credit").count, 1)
        capture(app, "route-panel-credit-collapsed")
    }
    func testPreparedFinishInActualNavigation() {
        let app = launch(["--navigation"])
        XCTAssertTrue(app.navigationBars["TrollRoute Navigation"].waitForExistence(timeout: 10))
        let picker = app.buttons["route-finish-action"]
        for _ in 0..<8 {
            if picker.isHittable { break }
            app.swipeUp()
        }
        XCTAssertTrue(picker.isHittable)
        capture(app, "navigation-per-route-finish")
        picker.tap()
        app.buttons["Drive back to start"].tap()
        app.buttons["Close"].tap()
        waitState(app, "action=returnOnce")
        waitState(app, "default=stay")
    }
}
