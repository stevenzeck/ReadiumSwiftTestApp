//
//  SearchServiceTests.swift
//  ReadiumSwiftTestApp
//
//  Created by Steven Zeck on 2/6/26.
//

import ReadiumShared
@testable import ReadiumSwiftTestApp
import XCTest

/// Mock for the internal Readium Search Service (Protocol from ReadiumShared)
class MockReadiumSearchService: ReadiumShared.SearchService {
    /// Protocol requirement: options property
    var options: SearchOptions = .init()

    var closeCalled = false

    func search(query _: String, options: SearchOptions?) async -> SearchResult<SearchIterator> {
        // Update options if provided
        if let options = options {
            self.options = options
        }

        // Return a dummy iterator
        let iterator = MinimalMockIterator()
        return .success(iterator)
    }

    /// Protocol requirement: close method
    func close() {
        closeCalled = true
    }
}

/// Minimal iterator mock for this test
class MinimalMockIterator: SearchIterator {
    /// Protocol requirement: resultCount
    var resultCount: Int? = 0

    func next() async -> SearchResult<LocatorCollection?> {
        return .success(nil)
    }
}

@MainActor
final class SearchServiceTests: XCTestCase {
    func testSearchInvocation() async {
        // 1. Setup a Publication with our MockReadiumSearchService injected
        let mockReadiumService = MockReadiumSearchService()

        // PublicationServicesBuilder allows injecting mock services
        let publication = Publication(
            manifest: Manifest(metadata: Metadata(title: "Searchable Book")),
            servicesBuilder: PublicationServicesBuilder(
                search: { _ in mockReadiumService }
            )
        )

        // 2. Initialize the App's wrapper service
        let service = PublicationSearchService(publication: publication)

        // 3. Call search
        let query = "Find Me"
        let result = await service.search(query: query)

        // 4. Verify the call went through to the mock
        switch result {
        case .success:
            XCTAssertTrue(true, "Search should succeed")
        case let .failure(error):
            XCTFail("Search failed: \(error)")
        }
    }

    func testSearchWhenNotSearchable() async {
        // 1. Setup a Publication WITHOUT a search service
        let publication = Publication(
            manifest: Manifest(metadata: Metadata(title: "Plain Book"))
        )

        // 2. Initialize the App's wrapper service
        let service = PublicationSearchService(publication: publication)

        // 3. Call search
        let result = await service.search(query: "query")

        // 4. Verify it returns the standard "not searchable" failure
        switch result {
        case .success:
            XCTFail("Should fail if publication is not searchable")
        case let .failure(error):
            // Check matching error case using pattern matching since SearchError might not be Equatable
            if case .publicationNotSearchable = error {
                XCTAssertTrue(true)
            } else {
                XCTFail("Expected .publicationNotSearchable, got \(error)")
            }
        }
    }
}
