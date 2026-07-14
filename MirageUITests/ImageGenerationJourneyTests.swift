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
        XCTAssertTrue(app.buttons["Model selection"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.textViews["Image prompt"].exists)
        XCTAssertTrue(app.buttons["SEND"].exists)
    }

    func testResultAppearsAbovePromptAfterGeneration() {
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
        XCTAssertTrue(app.staticTexts["No model available"].exists)
    }

    func testModelMenuListsAllSupportedFamilies() {
        let modelMenu = app.buttons["Model selection"]
        XCTAssertTrue(modelMenu.waitForExistence(timeout: 3))
        modelMenu.tap()
        for family in [
            "Stable Diffusion 1.x / 2.x", "SDXL / SDXL-Turbo", "SD3 / SD3.5",
            "FLUX.1 schnell / dev", "Chroma1-HD", "Qwen-Image",
            "ERNIE-Image-Turbo", "Z-Image-Turbo"
        ] {
            XCTAssertTrue(app.staticTexts[family].exists, "Missing model family: \(family)")
        }
    }

    func testRefusalIsNonDestructiveAndRecoverable() {
        launch(with: ["--ui-test-refusal"])
        enterPromptAndSend("A harmless paper landscape")
        XCTAssertTrue(app.staticTexts["That description can’t be used. Try a different idea."].waitForExistence(timeout: 3))
        XCTAssertTrue(app.textViews["Image prompt"].exists)
    }

    func testGenerationFailureKeepsEditorUsable() {
        launch(with: ["--ui-test-generation-failure"])
        enterPromptAndSend("A harmless paper landscape")
        XCTAssertTrue(
            app.staticTexts["The image could not be generated. Your previous image is still available."]
                .waitForExistence(timeout: 4)
        )
        XCTAssertTrue(app.textViews["Image prompt"].isHittable)
    }

    func testSaveSuccessAndDeniedGuidance() {
        enterPromptAndSend("A calm lake at sunrise")
        let save = app.buttons["Save generated image"]
        XCTAssertTrue(save.waitForExistence(timeout: 8))
        save.tap()
        XCTAssertTrue(app.staticTexts["Saved"].waitForExistence(timeout: 3))

        launch(with: ["--ui-test-photos-denied"])
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
        XCTAssertTrue(app.otherElements["Model selection"].exists || app.buttons["Model selection"].exists)
        XCTAssertTrue(app.textViews["Image prompt"].exists)
        XCTAssertTrue(app.buttons["SEND"].exists)
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
}
