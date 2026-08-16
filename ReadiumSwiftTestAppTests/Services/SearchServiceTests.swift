//
//  SearchServiceTests.swift
//  ReadiumSwiftTestApp
//
//  Created by Steven Zeck on 2/6/26.
//

import Foundation
import ReadiumShared
@testable import ReadiumSwiftTestApp
import Testing

/// Mock for the internal Readium Search Service (Protocol from ReadiumShared)
final class MockReadiumSearchService: ReadiumShared.SearchService, @unchecked Sendable {
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
final class MinimalMockIterator: SearchIterator, @unchecked Sendable {
    /// Protocol requirement: resultCount
    var resultCount: Int? {
        0
    }

    func next() async -> SearchResult<LocatorCollection?> {
        return .success(nil)
    }
}

@Suite(.serialized) @MainActor
struct SearchServiceTests {
    @Test func searchInvocation() async throws {
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
        do {
            _ = try await service.search(query: query)
        } catch {
            Issue.record("Search failed with error: \(error)")
        }
    }

    @Test func searchWhenNotSearchable() async throws {
        // 1. Setup a Publication WITHOUT a search service
        let publication = Publication(
            manifest: Manifest(metadata: Metadata(title: "Plain Book"))
        )

        // 2. Initialize the App's wrapper service
        let service = PublicationSearchService(publication: publication)

        do {
            _ = try await service.search(query: "query")
            Issue.record("Should fail if publication is not searchable")
        } catch {
            if case .publicationNotSearchable = error {
                #expect(true)
            } else {
                Issue.record("Expected .publicationNotSearchable, got \(error)")
            }
        }
    }
}
