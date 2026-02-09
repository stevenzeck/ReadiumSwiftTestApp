//
//  OPDSBrowserViewModelTests.swift
//  ReadiumSwiftTestApp
//
//  Created by Steven Zeck on 2/5/26.
//

import ReadiumOPDS
import ReadiumShared
@testable import ReadiumSwiftTestApp
import XCTest

@MainActor
class MockOPDSParsingService: OPDSParsingService {
    var result: Result<Feed?, OPDSBrowserError>?

    func parseURL(url _: URL) async throws(OPDSBrowserError) -> Feed? {
        guard let result = result else {
            throw .unknown
        }

        switch result {
        case let .success(feed):
            return feed
        case let .failure(error):
            throw error
        }
    }
}

@MainActor
final class OPDSBrowserViewModelTests: XCTestCase {
    var viewModel: OPDSBrowserViewModel!
    var mockService: MockOPDSParsingService!

    override func setUp() async throws {
        try await super.setUp()
        mockService = MockOPDSParsingService()
        viewModel = OPDSBrowserViewModel(parsingService: mockService)
    }

    override func tearDown() async throws {
        viewModel = nil
        mockService = nil
        try await super.tearDown()
    }

    func testLoadFeedSuccess() async throws {
        let url = try XCTUnwrap(URL(string: "https://example.com/opds"))
        let feed = Feed(title: "Test Feed")

        mockService.result = .success(feed)

        await viewModel.loadFeed(url: url)

        XCTAssertNotNil(viewModel.feed)
        XCTAssertEqual(viewModel.feed?.metadata.title, "Test Feed")
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNil(viewModel.error)
    }

    func testLoadFeedFailure() async throws {
        let url = try XCTUnwrap(URL(string: "https://example.com/opds"))
        mockService.result = .failure(.unknown)

        await viewModel.loadFeed(url: url)

        XCTAssertNil(viewModel.feed)
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNotNil(viewModel.error)
    }

    func testLoadFeedCached() async throws {
        let url = try XCTUnwrap(URL(string: "https://example.com/opds"))
        let feed = Feed(title: "Cached Feed")

        // Pre-populate
        mockService.result = .success(feed)
        await viewModel.loadFeed(url: url)
        XCTAssertNotNil(viewModel.feed)

        // Clear result in mock to ensure it's not called
        mockService.result = nil

        // Call again without force
        await viewModel.loadFeed(url: url)

        // Should still be the old feed, and no error (mock would throw if called)
        XCTAssertEqual(viewModel.feed?.metadata.title, "Cached Feed")
    }

    func testLoadFeedForce() async throws {
        let url = try XCTUnwrap(URL(string: "https://example.com/opds"))
        let feed1 = Feed(title: "Feed 1")
        let feed2 = Feed(title: "Feed 2")

        mockService.result = .success(feed1)
        await viewModel.loadFeed(url: url)
        XCTAssertEqual(viewModel.feed?.metadata.title, "Feed 1")

        mockService.result = .success(feed2)
        await viewModel.loadFeed(url: url, force: true)
        XCTAssertEqual(viewModel.feed?.metadata.title, "Feed 2")
    }
}
