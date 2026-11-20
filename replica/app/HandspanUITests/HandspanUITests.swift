import XCTest

/// The core flow on the simulator (/replica-test). Every run launches with the in-memory
/// backend (`HANDSPAN_FAKE_BACKEND`: any 6-digit code signs in, no email, no network) and a
/// fresh local state (`HANDSPAN_RESET_STATE`, DEBUG builds only). The learner picks "No piano
/// yet" and plays on the screen keys, so no microphone is needed.
final class HandspanUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    // MARK: Flows

    /// F01: welcome → price → instrument → experience → goal → sign in → Home, with the
    /// course map (S07).
    @MainActor
    func testOnboardingReachesHomeWithTheCourseMap() throws {
        let app = launch()
        onboard(app)
        XCTAssertTrue(element(app, startingWith: "Find middle C").waitForExistence(timeout: 5),
                      "Home offers lesson 1")
        XCTAssertTrue(element(app, startingWith: "Courses").exists, "the course row is on Home")
        XCTAssertTrue(element(app, startingWith: "First steps").exists, "with the free course")
        XCTAssertTrue(element(app, startingWith: "Two hands").exists, "and the course that comes next")
    }

    /// F02: lesson 1 on the screen keys, from the concept card to the result, and Home moves
    /// on to lesson 2.
    @MainActor
    func testFirstLessonOnTheScreenKeys() throws {
        let app = launch()
        onboard(app)
        tap(app.buttons.matching(label: "Start lesson"), "Start lesson")
        tap(app.buttons.matching(label: "Start the exercises"), "Start the exercises")

        // Exercise 1: middle C once.
        XCTAssertTrue(element(app, startingWith: "Play middle C").waitForExistence(timeout: 5))
        tap(app.buttons.matching(label: "C4"), "the C4 key")

        // Exercise 2: middle C three times. Wait for it, the first one moves on after a pause.
        XCTAssertTrue(element(app, startingWith: "Middle C, three times").waitForExistence(timeout: 5))
        for _ in 0..<3 {
            tap(app.buttons.matching(label: "C4"), "the C4 key")
            pause(0.3)
        }

        XCTAssertTrue(element(app, startingWith: "Find middle C: done").waitForExistence(timeout: 5),
                      "the result screen")
        tap(app.buttons.matching(label: "Continue"), "Continue")
        XCTAssertTrue(element(app, startingWith: "C, D and E").waitForExistence(timeout: 5),
                      "Home offers lesson 2")
    }

    /// App Review: the privacy policy and terms are linked from Settings, and the account
    /// can be deleted in the app (5.1.1(v)), which goes back to the welcome screen.
    @MainActor
    func testSettingsLinksAndAccountDeletion() throws {
        let app = launch()
        onboard(app)
        tap(app.buttons.matching(label: "Settings"), "Settings")
        XCTAssertTrue(element(app, startingWith: "Privacy policy").waitForExistence(timeout: 5))
        XCTAssertTrue(element(app, startingWith: "Terms of use").exists)

        app.swipeUp()
        tap(app.buttons.matching(label: "Delete account"), "Delete account")
        // The confirmation dialog repeats the same title; the last match is its button.
        tap(app.buttons.matching(label: "Delete account"), "Delete account (confirm)")
        XCTAssertTrue(element(app, startingWith: "Learn piano for real").waitForExistence(timeout: 5),
                      "back to the welcome screen")
    }

    // MARK: Steps

    @MainActor
    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["HANDSPAN_FAKE_BACKEND"] = "1"
        app.launchEnvironment["HANDSPAN_RESET_STATE"] = "1"
        app.launch()
        return app
    }

    @MainActor
    private func onboard(_ app: XCUIApplication, name: String = "Ana") {
        tap(app.buttons.matching(label: "Start the free course"), "Start the free course")
        XCTAssertTrue(element(app, startingWith: "What it costs").waitForExistence(timeout: 5))
        tap(app.buttons.matching(label: "Continue"), "Continue after the price")

        tap(app.buttons.matching(prefix: "No piano yet"), "No piano yet")
        tap(app.buttons.matching(label: "Continue"), "Continue after the instrument")
        tap(app.buttons.matching(prefix: "I'm new to the piano"), "I'm new to the piano")
        tap(app.buttons.matching(label: "Continue"), "Continue after experience")
        tap(app.buttons.matching(prefix: "Songs I know"), "Songs I know")
        tap(app.buttons.matching(label: "Continue"), "Continue after the goal")

        // No piano: the sound check is skipped, sign-in comes next.
        XCTAssertTrue(element(app, startingWith: "Save your progress").waitForExistence(timeout: 5))
        type(app, "ana@example.com")
        tap(app.buttons.matching(label: "Send code"), "Send code")
        XCTAssertTrue(element(app, startingWith: "Check your email").waitForExistence(timeout: 5))
        type(app, "482913")                       // six digits check themselves
        XCTAssertTrue(element(app, startingWith: "What should we call you").waitForExistence(timeout: 5))
        type(app, name)
        tap(app.buttons.matching(label: "Start lesson 1"), "Start lesson 1")
        XCTAssertTrue(element(app, startingWith: "Hi, \(name)").waitForExistence(timeout: 5), "Home")
    }

    // MARK: Helpers

    /// Any element whose label starts with `prefix`: SwiftUI often combines a card's texts
    /// into one element, so exact matches are brittle.
    @MainActor
    private func element(_ app: XCUIApplication, startingWith prefix: String) -> XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(format: "label BEGINSWITH %@", prefix)).firstMatch
    }

    /// Taps the last hittable, enabled match. A NavigationStack keeps earlier screens in the
    /// hierarchy, so "Continue" can match more than one button.
    @MainActor
    private func tap(_ query: XCUIElementQuery, _ what: String, timeout: TimeInterval = 8,
                     file: StaticString = #filePath, line: UInt = #line) {
        let deadline = Date().addingTimeInterval(timeout)
        repeat {
            if let target = query.allElementsBoundByIndex.last(where: { $0.exists && $0.isHittable && $0.isEnabled }) {
                target.tap()
                return
            }
            pause(0.25)
        } while Date() < deadline
        XCTFail("Couldn't tap \(what)", file: file, line: line)
    }

    /// Types into the text field that's on screen.
    @MainActor
    private func type(_ app: XCUIApplication, _ text: String,
                      file: StaticString = #filePath, line: UInt = #line) {
        tap(app.textFields, "the text field", file: file, line: line)
        app.typeText(text)
    }

    private func pause(_ seconds: TimeInterval) {
        RunLoop.current.run(until: Date().addingTimeInterval(seconds))
    }
}

private extension XCUIElementQuery {
    func matching(label: String) -> XCUIElementQuery {
        matching(NSPredicate(format: "label == %@", label))
    }

    func matching(prefix: String) -> XCUIElementQuery {
        matching(NSPredicate(format: "label BEGINSWITH %@", prefix))
    }
}
