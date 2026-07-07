//
//  SearchViewModelTests.swift
//  ReadiumSwiftTestApp
//
//  Created by Steven Zeck on 2/5/26.
//

import Foundation
import ReadiumShared
@testable import ReadiumSwiftTestApp
import Testing

class MockSearchIterator: SearchIterator {
    var resultCount: Int?
    var pages: [LocatorCollection?] = []
    var error: SearchError?

    private var pageIndex = 0

    func next() async -> SearchResult<LocatorCollection?> {
        if let error = error {
            return .failure(error)
        }

        guard pageIndex < pages.count else {
            return .success(nil)
        }

        let page = pages[pageIndex]
        pageIndex += 1
        return .success(page)
    }
}

class MockSearchService: AppSearchService {
    var iterator: MockSearchIterator?
    var error: SearchError?

    func search(query _: String) async throws(SearchError) -> SearchIterator {
        if let error = error {
            throw error
        }
        if let iterator = iterator {
            return iterator
        }
        throw .publicationNotSearchable
    }
}

@Suite(.serialized) @MainActor
struct SearchViewModelTests {
    let viewModel: SearchViewModel
    let mockService: MockSearchService

    init() {
        let mockService = MockSearchService()
        self.mockService = mockService
        viewModel = SearchViewModel(searchService: mockService)
    }

    @Test func searchSuccess() async throws {
        let iterator = MockSearchIterator()
        // Create a minimal valid locator
        let locator = try Locator(href: #require(AnyURL(string: "href")), mediaType: .html, locations: .init(progression: 0))
        let collection = LocatorCollection(locators: [locator])
        iterator.pages = [collection, nil]

        mockService.iterator = iterator
        viewModel.query = "test"

        viewModel.search()

        // Wait for async task to complete
        var attempts = 0
        while viewModel.isLoading || viewModel.results.isEmpty, attempts < 200 {
            try await Task.sleep(nanoseconds: 10_000_000) // 10ms
            attempts += 1
        }

        #expect(viewModel.results.count == 1)
        #expect(viewModel.results.first?.href.string == "href")
        #expect(viewModel.error == nil)
    }

    @Test func searchFailure() async throws {
        mockService.error = .badQuery(NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Search failed"]))
        viewModel.query = "fail"

        viewModel.search()

        // Wait for async task to complete
        var attempts = 0
        while viewModel.isLoading || viewModel.error == nil, attempts < 200 {
            try await Task.sleep(nanoseconds: 10_000_000) // 10ms
            attempts += 1
        }

        #expect(viewModel.error != nil)
        #expect(viewModel.results.isEmpty)
    }

    @Test func cancelSearch() {
        let iterator = MockSearchIterator()
        iterator.pages = Array(repeating: LocatorCollection(locators: []), count: 100)
        mockService.iterator = iterator
        viewModel.query = "long"

        viewModel.search()

        // Ensure the task has started and set isLoading to true
        #expect(viewModel.isLoading)

        viewModel.cancel()
        #expect(!viewModel.isLoading)
    }
}
