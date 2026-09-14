import XCTest

final class MapGestureTests: XCTestCase {
    private func launch(_ screen: String = "gestures", labels: Bool = true) -> XCUIApplication {
        let app = XCUIApplication(bundleIdentifier: "local.trollroute.workspacepreview")
        app.launchArguments = ["--screen", screen, "--labels", labels ? "yes" : "no"]
        app.launch()
        XCTAssertTrue(app.buttons["Search"].waitForExistence(timeout: 15))
        return app
    }

    private func mapState(_ app: XCUIApplication) -> [Double] {
        let probe = app.otherElements["map-observation"]
        XCTAssertTrue(probe.waitForExistence(timeout: 5))
        return (probe.value as? String ?? "").split(separator: ",").compactMap { Double($0) }
    }

    func testDragBelowStopPansMapWithoutMovingToolbar() {
        for labels in [true, false] {
            let app = launch(labels: labels)
            let stop = app.buttons["Stop"]
            XCTAssertTrue(stop.isHittable)
            let stopBefore = stop.frame
            let before = mapState(app)
            XCTAssertEqual(before.count, 4)
            guard before.count == 4 else { return }
            let start = app.coordinate(withNormalizedOffset: .zero)
                .withOffset(CGVector(dx: stopBefore.midX, dy: stopBefore.maxY + 140))
            let end = app.coordinate(withNormalizedOffset: .zero)
                .withOffset(CGVector(dx: stopBefore.midX, dy: stopBefore.maxY + 60))
            start.press(forDuration: 0.05, thenDragTo: end)
            let moved = NSPredicate { _, _ in
                let after = self.mapState(app)
                return after.count == 4 && abs(after[0] - before[0]) + abs(after[1] - before[1]) > 0.0001
            }
            expectation(for: moved, evaluatedWith: app)
            waitForExpectations(timeout: 5)
            XCTAssertEqual(stop.frame.minY, stopBefore.minY, accuracy: 1)
            XCTAssertEqual(stop.frame.minX, stopBefore.minX, accuracy: 1)
            let toolbar = app.scrollViews["map-toolbar"]
            XCTAssertLessThan(toolbar.frame.maxY, start.screenPoint.y)
            let screenshot = XCTAttachment(screenshot: app.screenshot())
            screenshot.name = labels ? "toolbar-labels-after-map-pan" : "toolbar-icons-after-map-pan"
            screenshot.lifetime = .keepAlways
            add(screenshot)
            app.terminate()
        }
    }

    func testShortWorkspaceKeepsStopReachableByScrolling() {
        let app = launch("gestures-short")
        let toolbar = app.scrollViews["map-toolbar"]
        XCTAssertLessThanOrEqual(toolbar.frame.height, 240)
        toolbar.swipeUp()
        XCTAssertTrue(app.buttons["Stop"].isHittable)
        app.buttons["Stop"].tap()
        XCTAssertTrue(app.alerts["Stop location spoofing?"].waitForExistence(timeout: 3))
        app.alerts.buttons["Cancel"].tap()
        XCTAssertFalse(app.alerts["Stop location spoofing?"].exists)
    }

    func testLongPressSingleTapAndDoubleTapAreSeparate() {
        let app = launch("gestures-long")
        let spot = app.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.65))
        spot.press(forDuration: 1)
        XCTAssertEqual(app.staticTexts["gesture-counts"].label, "presses=1,taps=0")
        let before = mapState(app)
        XCTAssertEqual(before.count, 4)
        guard before.count == 4 else { return }
        spot.doubleTap()
        let zoomed = NSPredicate { _, _ in
            let after = self.mapState(app)
            return after.count == 4 && after[2] < before[2] * 0.9
        }
        expectation(for: zoomed, evaluatedWith: app)
        waitForExpectations(timeout: 5)
        XCTAssertEqual(app.staticTexts["gesture-counts"].label, "presses=1,taps=0")
        spot.tap()
        let tapped = NSPredicate(format: "label == %@", "presses=1,taps=1")
        expectation(for: tapped, evaluatedWith: app.staticTexts["gesture-counts"])
        waitForExpectations(timeout: 5)
    }
}
