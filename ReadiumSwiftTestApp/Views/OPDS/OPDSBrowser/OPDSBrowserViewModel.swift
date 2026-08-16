//
//  OPDSBrowserViewModel.swift
//  ReadiumSwiftTestApp
//
//  Created by Steven Zeck on 12/30/25.
//

import Foundation
import Observation
import ReadiumOPDS
import ReadiumShared

/// ViewModel for fetching and parsing the OPDS feed.
@MainActor
@Observable
class OPDSBrowserViewModel {
    var feed: Feed?
    var isLoading = false
    var error: OPDSBrowserError?

    private let parsingService: OPDSParsingService

    /// Primary Initializer (Test)
    init(parsingService: OPDSParsingService) {
        self.parsingService = parsingService
    }

    /// Convenience Initializer (Production)
    init(client: HTTPClient) {
        parsingService = ReadiumOPDSParsingService(client: client)
    }

    func loadFeed(url: URL, force: Bool = false) async {
        if !force, feed != nil {
            return
        }

        isLoading = true
        error = nil

        do {
            feed = try await parsingService.parseURL(url: url)
            isLoading = false
        } catch {
            self.error = error
            isLoading = false
        }
    }
}
