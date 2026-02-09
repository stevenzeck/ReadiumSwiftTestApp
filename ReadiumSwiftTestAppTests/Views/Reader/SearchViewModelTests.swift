//
//  SearchViewModelTests.swift
//  ReadiumSwiftTestApp
//
//  Created by Steven Zeck on 2/5/26.
//

import ReadiumShared
@testable import ReadiumSwiftTestApp
import XCTest

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

@MainActor
final class SearchViewModelTests: XCTestCase {
    var viewModel: SearchViewModel!
    var mockService: MockSearchService!

    override func setUp() async throws {
        try await super.setUp()
        mockService = MockSearchService()
        viewModel = SearchViewModel(searchService: mockService)
    }

    override func tearDown() async throws {
        viewModel = nil
        mockService = nil
        try await super.tearDown()
    }

    func testSearchSuccess() async throws {
        let iterator = MockSearchIterator()
        // Create a minimal valid locator
        let locator = try Locator(href: XCTUnwrap(AnyURL(string: "href")), mediaType: .html, locations: .init(progression: 0))
        let collection = LocatorCollection(locators: [locator])
        iterator.pages = [collection, nil]

        mockService.iterator = iterator
        viewModel.query = "test"

        viewModel.search()

        // Wait for async task to complete
        let pred = NSPredicate { _, _ in
            !self.viewModel.isLoading && !self.viewModel.results.isEmpty
        }
        let exp = XCTNSPredicateExpectation(predicate: pred, object: nil)
        await fulfillment(of: [exp], timeout: 2.0)

        XCTAssertEqual(viewModel.results.count, 1)
        XCTAssertEqual(viewModel.results.first?.href, "href")
        XCTAssertNil(viewModel.error)
    }

    func testSearchFailure() async {
        mockService.error = .badQuery(NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Search failed"]))
        viewModel.query = "fail"

        viewModel.search()

        let pred = NSPredicate { _, _ in
            !self.viewModel.isLoading && self.viewModel.error != nil
        }
        let exp = XCTNSPredicateExpectation(predicate: pred, object: nil)
        await fulfillment(of: [exp], timeout: 2.0)

        XCTAssertNotNil(viewModel.error)
        XCTAssertTrue(viewModel.results.isEmpty)
    }

    func testCancelSearch() {
        let iterator = MockSearchIterator()
        iterator.pages = Array(repeating: LocatorCollection(locators: []), count: 100)
        mockService.iterator = iterator
        viewModel.query = "long"

        viewModel.search()

        // Ensure the task has started and set isLoading to true
        XCTAssertTrue(viewModel.isLoading)

        viewModel.cancel()
        XCTAssertFalse(viewModel.isLoading)
    }
}
