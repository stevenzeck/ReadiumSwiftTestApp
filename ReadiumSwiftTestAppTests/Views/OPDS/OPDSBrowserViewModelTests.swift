//
//  OPDSBrowserViewModelTests.swift
//  ReadiumSwiftTestApp
//
//  Created by Steven Zeck on 2/5/26.
//

import Foundation
import ReadiumOPDS
import ReadiumShared
@testable import ReadiumSwiftTestApp
import Testing

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

@Suite(.serialized) @MainActor
struct OPDSBrowserViewModelTests {
    let viewModel: OPDSBrowserViewModel
    let mockService: MockOPDSParsingService

    init() {
        let mockService = MockOPDSParsingService()
        self.mockService = mockService
        viewModel = OPDSBrowserViewModel(parsingService: mockService)
    }

    @Test func loadFeedSuccess() async throws {
        let url = try #require(URL(string: "https://example.com/opds"))
        let feed = Feed(title: "Test Feed")

        mockService.result = .success(feed)

        await viewModel.loadFeed(url: url)

        #expect(viewModel.feed != nil)
        #expect(viewModel.feed?.metadata.title == "Test Feed")
        #expect(!viewModel.isLoading)
        #expect(viewModel.error == nil)
    }

    @Test func loadFeedFailure() async throws {
        let url = try #require(URL(string: "https://example.com/opds"))
        mockService.result = .failure(.unknown)

        await viewModel.loadFeed(url: url)

        #expect(viewModel.feed == nil)
        #expect(!viewModel.isLoading)
        #expect(viewModel.error != nil)
    }

    @Test func loadFeedCached() async throws {
        let url = try #require(URL(string: "https://example.com/opds"))
        let feed = Feed(title: "Cached Feed")

        // Pre-populate
        mockService.result = .success(feed)
        await viewModel.loadFeed(url: url)
        #expect(viewModel.feed != nil)

        // Clear result in mock to ensure it's not called
        mockService.result = nil

        // Call again without force
        await viewModel.loadFeed(url: url)

        // Should still be the old feed, and no error (mock would throw if called)
        #expect(viewModel.feed?.metadata.title == "Cached Feed")
    }

    @Test func loadFeedForce() async throws {
        let url = try #require(URL(string: "https://example.com/opds"))
        let feed1 = Feed(title: "Feed 1")
        let feed2 = Feed(title: "Feed 2")

        mockService.result = .success(feed1)
        await viewModel.loadFeed(url: url)
        #expect(viewModel.feed?.metadata.title == "Feed 1")

        mockService.result = .success(feed2)
        await viewModel.loadFeed(url: url, force: true)
        #expect(viewModel.feed?.metadata.title == "Feed 2")
    }
}
