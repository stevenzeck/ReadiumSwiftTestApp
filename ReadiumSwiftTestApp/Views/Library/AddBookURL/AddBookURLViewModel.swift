//
//  AddBookURLViewModel.swift
//  ReadiumSwiftTestApp
//
//  Created by Steven Zeck on 2/7/26.
//

import Foundation
import Observation
import ReadiumShared
import ReadiumStreamer
import SwiftData
import UIKit

/// ViewModel for AddBookURLView, managing URL input and initiating downloads.
@MainActor
@Observable
class AddBookURLViewModel {
    // MARK: - State

    /// The input string for the URL.
    var urlString = ""

    /// Indicates if an import operation is currently in progress.
    var isLoading = false

    /// Contains the error message if an operation fails.
    var errorMessage: String?

    // MARK: - Actions

    /// Smart-imports the book.
    /// - If it's a Manifest (Audiobook/WebPub), it downloads and imports immediately with metadata.
    /// - If it's a Binary (EPUB/PDF), it opens it remotely to get metadata/cover, then queues a background download.
    func startImport(
        readium: ReadiumService,
        downloadService: DownloadService,
        modelContext: ModelContext
    ) async -> Bool {
        guard let url = URL(string: urlString) else {
            errorMessage = "Invalid URL"
            return false
        }

        isLoading = true
        errorMessage = nil

        defer { isLoading = false }

        do {
            if url.pathExtension.localizedCaseInsensitiveContains("json") {
                try await importManifest(url: url, readium: readium, modelContext: modelContext)
                return true
            } else {
                let (publication, format) = try await readium.openPublication(at: url)

                let id = UUID()

                await persistBook(
                    id: id,
                    publication: publication,
                    format: format,
                    filename: url.lastPathComponent,
                    fallbackTitle: url.lastPathComponent,
                    fallbackFormat: url.pathExtension,
                    isDownloaded: false,
                    modelContext: modelContext
                )

                downloadService.startDownload(url: url, for: id)
                return true
            }
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    /// Downloads and parses a Readium Manifest (JSON), extracting full metadata.
    private func importManifest(
        url: URL,
        readium: ReadiumService,
        modelContext: ModelContext
    ) async throws {
        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }

        let id = UUID()
        let filename = "\(id.uuidString).json"
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let destination = documents.appendingPathComponent(filename)

        if FileManager.default.fileExists(atPath: destination.path) {
            try FileManager.default.removeItem(at: destination)
        }
        try data.write(to: destination)

        let (publication, format) = try await readium.openPublication(at: destination)

        await persistBook(
            id: id,
            publication: publication,
            format: format,
            filename: filename,
            fallbackTitle: url.lastPathComponent,
            fallbackFormat: MediaType.binary.string,
            isDownloaded: true,
            modelContext: modelContext
        )
    }

    // MARK: - Shared Logic

    private func persistBook(
        id: UUID,
        publication: Publication,
        format: Format,
        filename: String,
        fallbackTitle: String,
        fallbackFormat: String,
        isDownloaded: Bool,
        modelContext: ModelContext
    ) async {
        let title = publication.metadata.title ?? fallbackTitle
        let author = publication.metadata.authors.map { $0.name }.joined(separator: ", ")
        let formatString = format.mediaType?.string ?? fallbackFormat

        let newBook = Book(
            id: id,
            title: title,
            author: author.isEmpty ? nil : author,
            format: formatString,
            filePath: filename,
            isDownloaded: isDownloaded
        )

        if let coverImage = try? await publication.cover().get() {
            let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let coverFilename = "\(id.uuidString)-cover.png"
            let coverDestination = documents.appendingPathComponent(coverFilename)

            if let pngData = coverImage.pngData() {
                do {
                    try pngData.write(to: coverDestination)
                    newBook.coverPath = coverFilename
                } catch {
                    print("Failed to save cover image: \(error)")
                }
            }
        }

        modelContext.insert(newBook)
    }
}
