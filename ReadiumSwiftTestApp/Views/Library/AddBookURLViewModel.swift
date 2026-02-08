//
//  AddBookURLViewModel.swift
//  ReadiumSwiftTestApp
//
//  Created by Steven Zeck on 2/7/26.
//

import Foundation
import Observation
import SwiftData

/// ViewModel for AddBookURLView, managing URL input and initiating downloads.
@MainActor
@Observable
class AddBookURLViewModel {
    // MARK: - State

    /// The input string for the URL.
    var urlString = ""

    // MARK: - Actions

    /// Validates the URL and initiates the background download.
    ///
    /// - Parameters:
    ///   - downloadService: The service handling the download.
    ///   - modelContext: The SwiftData context for creating the placeholder book.
    ///   - onComplete: A closure to dismiss the view or perform post-start actions.
    func startDownload(downloadService: DownloadService, modelContext: ModelContext, onComplete: () -> Void) {
        guard let url = URL(string: urlString) else { return }

        let id = UUID()
        let filename = url.lastPathComponent

        // The file path and metadata might be refined once the download completes.
        let newBook = Book(
            id: id,
            title: filename,
            format: url.pathExtension,
            filePath: filename
        )
        modelContext.insert(newBook)

        downloadService.startDownload(url: url, for: id)

        onComplete()
    }
}
