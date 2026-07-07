//
//  TTSServiceTests.swift
//  ReadiumSwiftTestApp
//
//  Created by Steven Zeck on 2/6/26.
//

@preconcurrency import ReadiumNavigator
import ReadiumShared
@testable import ReadiumSwiftTestApp
import XCTest

@MainActor
final class TTSServiceTests: XCTestCase {
    var publication: Publication!

    override func setUp() async throws {
        try await super.setUp()
        publication = Publication(manifest: Manifest(metadata: Metadata(title: "Test Pub")))
    }

    func testMockTTSService() throws {
        let mockService = MockTTSService()

        // Test Start
        let locator = try Locator(href: XCTUnwrap(AnyURL(string: "chap1")), mediaType: .html)
        mockService.start(from: locator)
        XCTAssertTrue(mockService.startCalled)
        XCTAssertEqual(mockService.startLocator?.href, locator.href)

        // Test Stop
        mockService.stop()
        XCTAssertTrue(mockService.stopCalled)
        XCTAssertFalse(mockService.isPlaying)
    }

    func testTTSUtteranceStruct() throws {
        // Verify the app's wrapper struct holds data correctly
        let locator = try Locator(href: XCTUnwrap(AnyURL(string: "chap1")), mediaType: .html)
        let utterance = AppTTSUtterance(text: "Hello World", locator: locator)

        XCTAssertEqual(utterance.text, "Hello World")
        XCTAssertEqual(utterance.locator.href, locator.href)
    }
}
