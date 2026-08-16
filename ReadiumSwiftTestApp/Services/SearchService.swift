//
//  SearchService.swift
//  ReadiumSwiftTestApp
//
//  Created by Steven Zeck on 2/5/26.
//

import Foundation
import ReadiumShared

/// Protocol definition for search capabilities.
@MainActor
protocol AppSearchService {
    func search(query: String) async throws(SearchError) -> SearchIterator
}

@MainActor
class PublicationSearchService: AppSearchService {
    private let publication: Publication

    init(publication: Publication) {
        self.publication = publication
    }

    func search(query: String) async throws(SearchError) -> SearchIterator {
        let result = await publication.search(query: query)

        switch result {
        case let .success(iterator):
            return iterator
        case let .failure(error):
            throw error
        }
    }
}
