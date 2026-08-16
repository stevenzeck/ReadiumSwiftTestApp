//
//  PublicationDetailViewModel.swift
//  ReadiumSwiftTestApp
//
//  Created by Steven Zeck on 2/8/26.
//

import Foundation
import Observation
import ReadiumShared
import SwiftData

@MainActor
@Observable
class PublicationDetailViewModel {
    // MARK: - State

    var downloadStatus: LocalizedStringResource = "Download"
    var isDownloading = false
    var currentDownloadID: UUID?

    // MARK: - Actions

    /// Initiates the download of a publication.
    ///
    /// - Parameters:
    ///   - publication: The publication to download.
    ///   - downloadService: The service handling the network task.
    ///   - modelContext: The database context for saving the book.
    func startDownload(publication: Publication, downloadService: DownloadService, modelContext: ModelContext) {
        guard let downloadLink = publication.downloadLink,
              let url = URL(string: downloadLink.href) else { return }

        isDownloading = true
        downloadStatus = "Downloading..."

        let bookID = UUID()
        currentDownloadID = bookID

        // Create the local Book entity
        let newBook = Book(
            id: bookID,
            title: publication.metadata.title ?? "Unknown",
            author: publication.metadata.authors.first?.name,
            format: url.pathExtension,
            filePath: url.lastPathComponent
        )
        modelContext.insert(newBook)

        // Handle Cover Download (if available)
        if let coverURL = publication.coverURL {
            Task {
                do {
                    let filename = try await downloadService.downloadCover(url: coverURL, for: bookID)
                    let descriptor = FetchDescriptor<Book>(predicate: #Predicate { $0.id == bookID })
                    if let book = try? modelContext.fetch(descriptor).first {
                        book.coverPath = filename
                        try? modelContext.save()
                    }
                } catch {
                    print("Failed to download cover: \(error)")
                }
            }
        }

        // Start the main content download
        downloadService.startDownload(url: url, for: bookID)
    }

    /// Handles incoming download events to update UI state.
    func handleDownloadEvent(_ event: DownloadEvent) {
        switch event {
        case let .didFinish(id, _):
            if id == currentDownloadID {
                isDownloading = false
                downloadStatus = "Downloaded"
            }
        case let .didFail(id, _):
            if id == currentDownloadID {
                isDownloading = false
                downloadStatus = "Download Failed"
            }
        default:
            break
        }
    }
}
