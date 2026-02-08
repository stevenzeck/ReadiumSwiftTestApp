//
//  ReaderViewModel.swift
//  ReadiumSwiftTestApp
//
//  Created by Steven Zeck on 2/8/26.
//

import Combine
import Foundation
import Observation
import ReadiumNavigator
@preconcurrency import ReadiumShared
@preconcurrency import ReadiumStreamer
import SwiftData
import SwiftUI

@MainActor
@Observable
class ReaderViewModel {
    // MARK: - State

    var publication: Publication?
    var error: Error?
    var tableOfContents: [ReadiumShared.Link] = []

    // Child ViewModels
    var searchViewModel: SearchViewModel?
    var ttsViewModel = TTSViewModel()

    // MARK: - Actions

    /// Opens the book file using Readium parsers.
    func openBook(book: Book, assetRetriever: AssetRetriever) async {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileURL = documents.appendingPathComponent(book.filePath)

        do {
            guard let sourceURL = AnyURL(url: fileURL).absoluteURL else { throw PublicationError.invalidURL }

            let asset = try await assetRetriever.retrieve(url: sourceURL).get()

            let parsers: [PublicationParser] = [
                EPUBParser(),
                ImageParser(assetRetriever: assetRetriever),
                AudioParser(assetRetriever: assetRetriever),
            ]

            let compositeParser = CompositePublicationParser(parsers)
            let opener = PublicationOpener(parser: compositeParser)

            let result = await opener.open(asset: asset, allowUserInteraction: false)

            switch result {
            case let .success(pub):
                let tocResult = await pub.tableOfContents()
                let toc = (try? tocResult.get()) ?? []

                publication = pub
                tableOfContents = toc
                searchViewModel = SearchViewModel(publication: pub)

            case let .failure(err):
                error = err
            }

        } catch {
            self.error = error
        }
    }

    /// Saves a bookmark to SwiftData.
    func addBookmark(to book: Book, locator: Locator, modelContext: ModelContext) {
        let bookmark = Bookmark(book: book, locator: locator)
        book.bookmarks.append(bookmark)
        try? modelContext.save()
    }

    /// Saves a highlight to SwiftData.
    func saveHighlight(to book: Book, selection: Selection, color: String, note: String, modelContext: ModelContext) {
        let highlight = Highlight(book: book, locator: selection.locator, color: color, note: note)
        book.highlights.append(highlight)
        try? modelContext.save()
    }
}
