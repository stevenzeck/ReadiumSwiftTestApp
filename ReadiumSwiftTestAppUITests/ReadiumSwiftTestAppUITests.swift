//
//  ReadiumSwiftTestAppUITests.swift
//  ReadiumSwiftTestAppUITests
//
//  Created by Steven Zeck on 2/6/26.
//

import XCTest

@MainActor
final class ReadiumSwiftTestAppUITests: XCTestCase {
    override func setUpWithError() throws {
        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false
    }

    func testAppLaunchAndTabNavigation() {
        // Launch the application
        let app = XCUIApplication()
        app.launch()

        // 1. Verify Library Tab Exists and is selected by default
        let libraryTab = app.tabBars.buttons["Library"]
        XCTAssertTrue(libraryTab.exists, "Library tab should exist")
        XCTAssertTrue(libraryTab.isSelected, "Library tab should be selected at launch")

        // 2. Check for "Add Book" button availability in the navigation bar
        let addButton = app.navigationBars["Library"].buttons["Add Book"]
        XCTAssertTrue(addButton.exists, "Add Book button should exist")

        // 3. Navigate to OPDS Tab
        let opdsTab = app.tabBars.buttons["OPDS"]
        XCTAssertTrue(opdsTab.exists, "OPDS tab should exist")
        opdsTab.tap()

        // 4. Verify Navigation Title changes to "OPDS Feeds"
        XCTAssertTrue(app.navigationBars["OPDS Feeds"].exists, "Navigation title should update to OPDS Feeds")
    }

    func testAddURLSheet() {
        let app = XCUIApplication()
        app.launch()

        // 1. Open Add Menu
        let addButton = app.navigationBars["Library"].buttons["Add Book"]
        XCTAssertTrue(addButton.exists)
        addButton.tap()

        // 2. Tap "Add from URL" in the menu
        let addFromUrlButton = app.buttons["Add from URL"]
        XCTAssertTrue(addFromUrlButton.waitForExistence(timeout: 2.0), "Add from URL button should appear")
        addFromUrlButton.tap()

        // 3. Verify Sheet Appears
        let instructionText = app.staticTexts["Enter the direct URL to an EPUB or PDF file."]
        XCTAssertTrue(instructionText.waitForExistence(timeout: 2.0), "Sheet should appear with instructions")

        // 4. Verify Download button is initially disabled (because text field is empty)
        let downloadButton = app.buttons["Download"]
        XCTAssertTrue(downloadButton.exists)
        XCTAssertFalse(downloadButton.isEnabled, "Download button should be disabled when input is empty")

        // 5. Close Sheet via Cancel
        let cancelButton = app.buttons["Cancel"]
        XCTAssertTrue(cancelButton.exists)
        cancelButton.tap()

        // Verify sheet dismissed
        XCTAssertFalse(instructionText.exists, "Sheet should be dismissed")
    }
}
