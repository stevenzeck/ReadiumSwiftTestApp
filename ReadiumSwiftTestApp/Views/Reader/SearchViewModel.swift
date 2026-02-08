//
//  SearchViewModel.swift
//  ReadiumSwiftTestApp
//
//  Created by Steven Zeck on 12/30/25.
//

import Foundation
import Observation
@preconcurrency import ReadiumShared
import SwiftUI

/// ViewModel responsible for executing full-text search within a publication.
///
/// Wraps the Readium `SearchService` (via `Publication.search`) and manages the state of results.
@MainActor
@Observable
class SearchViewModel {
    // MARK: - Published State

    /// The search query entered by the user.
    var query: String = ""

    /// The list of found locations matching the query.
    var results: [Locator] = []

    /// Indicates if a search operation is currently in progress.
    var isLoading: Bool = false

    /// Any error message resulting from the search attempt.
    var error: String?

    /// Tracks the last selected locator to visually highlight the active result.
    var lastSelectedLocator: Locator?

    /// Tracks the current scroll position within the results list.
    /// This is separate from `lastSelectedLocator` to prevent the UI from auto-selecting the first visible item during scroll.
    var scrollId: Locator?

    // MARK: - Private Properties

    private let searchService: AppSearchService
    private var searchIterator: SearchIterator?
    private var searchTask: Task<Void, Never>?

    // MARK: - Initialization

    /// Initializes the search view model.
    ///
    /// - Parameter publication: The publication to be searched.
    init(publication: Publication) {
        searchService = PublicationSearchService(publication: publication)
    }

    init(searchService: AppSearchService) {
        self.searchService = searchService
    }

    // MARK: - Actions

    /// Executes the search for the current `query`.
    func search() {
        guard !query.isEmpty else { return }

        // Cancel any existing search before starting a new one
        cancel()

        isLoading = true
        results = []
        error = nil
        lastSelectedLocator = nil
        scrollId = nil

        searchTask = Task {
            let result = await searchService.search(query: query)

            switch result {
            case let .success(iterator):
                self.searchIterator = iterator
                await loadAllResults(iterator: iterator)
            case let .failure(error):
                self.error = error.localizedDescription
                self.isLoading = false
            }
        }
    }

    /// Cancels the current search operation.
    func cancel() {
        searchTask?.cancel()
        searchIterator = nil
        isLoading = false
    }

    // MARK: - Helpers

    /// Iterates through all search results and appends them to the results list.
    ///
    /// - Parameter iterator: The search iterator provided by Readium.
    private func loadAllResults(iterator: SearchIterator) async {
        // Readium's SearchIterator yields results in pages (LocatorCollection).
        // We iterate until the collection is nil or the task is cancelled.

        while !Task.isCancelled {
            let result = await iterator.next()

            guard !Task.isCancelled else { break }

            switch result {
            case let .success(collection):
                if let collection = collection {
                    results.append(contentsOf: collection.locators)
                } else {
                    // nil collection indicates end of results
                    isLoading = false
                    return
                }
            case let .failure(error):
                self.error = error.localizedDescription
                isLoading = false
                return
            }
        }
    }
}
