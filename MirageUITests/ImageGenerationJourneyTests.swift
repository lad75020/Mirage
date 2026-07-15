import XCTest

final class ImageGenerationJourneyTests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--ui-testing"]
        app.launch()
    }

    func testSinglePageExposesModelPromptAndSendControls() {
        XCTAssertTrue(app.staticTexts["Selected model"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Files location"].exists)
        XCTAssertTrue(app.textViews["Image prompt"].exists)
        XCTAssertTrue(app.buttons["SEND"].exists)
    }

    func testResultAppearsAbovePromptAfterGeneration() {
        selectDefaultModel()
        let prompt = app.textViews["Image prompt"]
        XCTAssertTrue(prompt.waitForExistence(timeout: 5))
        prompt.tap()
        prompt.typeText("A quiet lake beneath the northern lights")

        let send = app.buttons["SEND"]
        XCTAssertTrue(send.isEnabled)
        send.tap()

        XCTAssertTrue(app.images["Generated image"].waitForExistence(timeout: 5))
        XCTAssertLessThan(
            app.images["Generated image"].frame.minY,
            prompt.frame.minY
        )
    }

    func testSaveAppearsOnlyAfterResult() {
        XCTAssertFalse(app.buttons["Save generated image"].exists)

        selectDefaultModel()
        let prompt = app.textViews["Image prompt"]
        prompt.tap()
        prompt.typeText("A geometric blue bird on a white background")
        app.buttons["SEND"].tap()

        XCTAssertTrue(app.buttons["Save generated image"].waitForExistence(timeout: 5))
    }

    func testUnavailableCatalogDisablesSend() {
        launch(with: ["--ui-test-no-model"])
        let send = app.buttons["SEND"]
        XCTAssertTrue(send.waitForExistence(timeout: 3))
        XCTAssertFalse(send.isEnabled)
        XCTAssertTrue(app.staticTexts["No model selected"].exists)
    }

    func testFeaturedSourcesAreExactAndOrdered() {
        for reference in [
            "jc-builds/Z-Image-Turbo-iOS",
            "jc-builds/ERNIE-Image-Turbo-iOS",
            "jc-builds/Chroma1-HD-iOS"
        ] {
            XCTAssertTrue(app.staticTexts[reference].waitForExistence(timeout: 3), "Missing featured source: \(reference)")
        }
    }

    func testRefusalIsNonDestructiveAndRecoverable() {
        launch(with: ["--ui-test-refusal"])
        selectDefaultModel()
        enterPromptAndSend("A harmless paper landscape")
        XCTAssertTrue(app.staticTexts["That description can’t be used. Try a different idea."].waitForExistence(timeout: 3))
        XCTAssertTrue(app.textViews["Image prompt"].exists)
    }

    func testGenerationFailureKeepsEditorUsable() {
        launch(with: ["--ui-test-generation-failure"])
        selectDefaultModel()
        enterPromptAndSend("A harmless paper landscape")
        XCTAssertTrue(
            app.staticTexts["The image could not be generated. Your previous image is still available."]
                .waitForExistence(timeout: 4)
        )
        XCTAssertTrue(app.textViews["Image prompt"].isHittable)
    }

    func testSaveSuccessAndDeniedGuidance() {
        selectDefaultModel()
        enterPromptAndSend("A calm lake at sunrise")
        let save = app.buttons["Save generated image"]
        XCTAssertTrue(save.waitForExistence(timeout: 8))
        save.tap()
        XCTAssertTrue(app.staticTexts["Saved to Photos"].waitForExistence(timeout: 3))

        launch(with: ["--ui-test-photos-denied"])
        selectDefaultModel()
        enterPromptAndSend("A calm lake at sunrise")
        let deniedSave = app.buttons["Save generated image"]
        XCTAssertTrue(deniedSave.waitForExistence(timeout: 8))
        deniedSave.tap()
        XCTAssertTrue(app.buttons["Open Settings"].waitForExistence(timeout: 3))
    }

    func testAccessibilityXXXLAndDarkAppearanceKeepPrimaryControlsReachable() {
        launch(with: [
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityExtraExtraExtraLarge",
            "-AppleInterfaceStyle", "Dark",
            "-UIAccessibilityReduceMotionEnabled", "YES"
        ])
        XCTAssertTrue(app.staticTexts["Selected model"].exists)
        XCTAssertTrue(app.textViews["Image prompt"].exists)
        XCTAssertTrue(app.buttons["SEND"].exists)
    }

    func testDownloadConfirmationCustomAndRetryControlsAreDeterministic() {
        let featuredDownload = app.buttons["Download jc-builds/Z-Image-Turbo-iOS"]
        XCTAssertTrue(featuredDownload.waitForExistence(timeout: 5))
        XCTAssertTrue(waitUntilEnabled(featuredDownload))
        featuredDownload.tap()
        revealDownloadConfirmation()
        XCTAssertTrue(app.descendants(matching: .any)["Download confirmation"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["Confirm download"].exists)
        XCTAssertTrue(app.buttons["Cancel confirmation"].exists)
        app.buttons["Cancel confirmation"].tap()
        XCTAssertFalse(app.descendants(matching: .any)["Download confirmation"].exists)

        let custom = app.textFields["Custom model reference"]
        XCTAssertTrue(custom.exists)
        custom.tap()
        custom.typeText("jc-builds/Chroma1-HD-iOS")
        let customDownload = app.buttons["Download custom model"]
        XCTAssertTrue(waitUntilEnabled(customDownload))
        customDownload.tap()
        revealDownloadConfirmation()
        XCTAssertTrue(app.descendants(matching: .any)["Download confirmation"].waitForExistence(timeout: 3))
    }

    func testDownloadFailureOffersRetry() {
        launch(with: ["--ui-test-download-failure"])
        let download = app.buttons["Download jc-builds/Z-Image-Turbo-iOS"]
        XCTAssertTrue(download.waitForExistence(timeout: 5))
        XCTAssertTrue(waitUntilEnabled(download))
        download.tap()
        XCTAssertTrue(app.buttons["Retry jc-builds/Z-Image-Turbo-iOS"].waitForExistence(timeout: 3))
    }

    func testConfirmedSlowDownloadShowsProgressAndCancels() {
        launch(with: ["--ui-test-slow-download"])
        let download = app.buttons["Download jc-builds/Z-Image-Turbo-iOS"]
        XCTAssertTrue(download.waitForExistence(timeout: 5))
        XCTAssertTrue(waitUntilEnabled(download))
        download.tap()
        revealDownloadConfirmation()
        XCTAssertTrue(app.buttons["Confirm download"].waitForExistence(timeout: 3))
        app.buttons["Confirm download"].tap()
        let cancel = app.buttons["Cancel jc-builds/Z-Image-Turbo-iOS"]
        XCTAssertTrue(cancel.waitForExistence(timeout: 3))
        XCTAssertTrue(app.progressIndicators["Progress jc-builds/Z-Image-Turbo-iOS"].exists)
        cancel.tap()
        XCTAssertTrue(app.staticTexts["Download cancelled"].waitForExistence(timeout: 3))
    }

    private func launch(with extraArguments: [String]) {
        app.terminate()
        app = XCUIApplication()
        app.launchArguments = ["--ui-testing"] + extraArguments
        app.launch()
    }

    private func enterPromptAndSend(_ prompt: String) {
        let editor = app.textViews["Image prompt"]
        XCTAssertTrue(editor.waitForExistence(timeout: 3))
        editor.tap()
        editor.typeText(prompt)
        app.buttons["SEND"].tap()
    }

    private func selectDefaultModel() {
        let select = app.buttons["Select jc-builds/ERNIE-Image-Turbo-iOS"]
        XCTAssertTrue(select.waitForExistence(timeout: 5))
        select.tap()
        XCTAssertTrue(app.staticTexts["Selected jc-builds/ERNIE-Image-Turbo-iOS"].waitForExistence(timeout: 3))
    }

    private func waitUntilEnabled(_ element: XCUIElement, timeout: TimeInterval = 5) -> Bool {
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "enabled == true"),
            object: element
        )
        return XCTWaiter.wait(for: [expectation], timeout: timeout) == .completed
    }

    private func revealDownloadConfirmation() {
        for _ in 0..<3 where !app.buttons["Confirm download"].exists {
            app.swipeUp()
        }
    }
}
