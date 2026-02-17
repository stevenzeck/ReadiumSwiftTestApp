//
//  ReaderViewModel.swift
//  ReadiumSwiftTestApp
//
//  Created by Steven Zeck on 2/8/26.
//

import Foundation
import Observation
@preconcurrency import ReadiumNavigator
@preconcurrency import ReadiumShared
import SwiftData
import SwiftUI

enum BookOpenError: LocalizedError {
    case invalidURL
    case openFailed(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "The book file could not be found."
        case let .openFailed(error):
            return "Failed to open book: \(error.localizedDescription)"
        }
    }
}

@MainActor
@Observable
class ReaderViewModel {
    // MARK: - State

    var publication: Publication?
    var error: BookOpenError?
    var tableOfContents: [ReadiumShared.Link] = []

    // Child ViewModels
    var searchViewModel: SearchViewModel?
    var ttsViewModel = TTSViewModel()

    // MARK: - Actions

    /// Opens the book file using Readium parsers.
    func openBook(book: Book, readiumService: ReadiumService) async {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileURL = documents.appendingPathComponent(book.filePath)

        // Ensure book file exists before trying to open
        var isReachable = false
        do {
            isReachable = try fileURL.checkResourceIsReachable()
        } catch {
            self.error = .openFailed(NSError(domain: "FileSystem", code: 404, userInfo: [NSLocalizedDescriptionKey: "Book file not found at path: \(fileURL.path)"]))
            return
        }

        if !isReachable {
            error = .openFailed(NSError(domain: "FileSystem", code: 404, userInfo: [NSLocalizedDescriptionKey: "Book file missing."]))
            return
        }

        do {
            try await loadPublication(url: fileURL, readiumService: readiumService)
        } catch {
            self.error = error
        }
    }

    private func loadPublication(url: URL, readiumService: ReadiumService) async throws(BookOpenError) {
        do {
            let (pub, _) = try await readiumService.openPublication(at: url)

            let tocResult = await pub.tableOfContents()
            let toc = (try? tocResult.get()) ?? []

            publication = pub
            tableOfContents = toc
            searchViewModel = SearchViewModel(publication: pub)

        } catch {
            throw BookOpenError.openFailed(error)
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
