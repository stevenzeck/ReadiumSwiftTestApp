//
//  SearchService.swift
//  ReadiumSwiftTestApp
//
//  Created by Steven Zeck on 2/5/26.
//

import Foundation
@preconcurrency import ReadiumShared

/// Protocol definition for search capabilities.
@MainActor
protocol AppSearchService {
    func search(query: String) async -> SearchResult<SearchIterator>
}

@MainActor
class PublicationSearchService: AppSearchService {
    private let publication: Publication

    init(publication: Publication) {
        self.publication = publication
    }

    func search(query: String) async -> SearchResult<SearchIterator> {
        return await publication.search(query: query)
    }
}
