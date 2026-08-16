//
//  TTSServiceTests.swift
//  ReadiumSwiftTestApp
//
//  Created by Steven Zeck on 2/6/26.
//

import Foundation
import ReadiumNavigator
import ReadiumShared
@testable import ReadiumSwiftTestApp
import Testing

@Suite(.serialized) @MainActor
struct TTSServiceTests {
    let publication: Publication

    init() {
        publication = Publication(manifest: Manifest(metadata: Metadata(title: "Test Pub")))
    }

    @Test func mockTTSService() throws {
        let mockService = MockTTSService()

        // Test Start
        let locator = try Locator(href: #require(AnyURL(string: "chap1")), mediaType: .html)
        mockService.start(from: locator)
        #expect(mockService.startCalled)
        #expect(try #require(mockService.startLocator?.href).isEquivalentTo(locator.href))

        // Test Stop
        mockService.stop()
        #expect(mockService.stopCalled)
        #expect(!mockService.isPlaying)
    }

    @Test func ttsUtteranceStruct() throws {
        // Verify the app's wrapper struct holds data correctly
        let locator = try Locator(href: #require(AnyURL(string: "chap1")), mediaType: .html)
        let utterance = AppTTSUtterance(text: "Hello World", locator: locator)

        #expect(utterance.text == "Hello World")
        #expect(utterance.locator.href.isEquivalentTo(locator.href))
    }
}
