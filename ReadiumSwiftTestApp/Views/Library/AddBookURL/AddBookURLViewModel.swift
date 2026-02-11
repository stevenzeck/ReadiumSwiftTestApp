//
//  AddBookURLViewModel.swift
//  ReadiumSwiftTestApp
//
//  Created by Steven Zeck on 2/7/26.
//

import Foundation
import Observation
@preconcurrency import ReadiumShared
@preconcurrency import ReadiumStreamer
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
    /// - If it's a Binary (EPUB/PDF), it queues a background download.
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
                try await importManifest(url: url, readium: readium, downloadService: downloadService, modelContext: modelContext)
                return true
            } else {
                let id = UUID()
                let filename = url.lastPathComponent
                let newBook = Book(
                    id: id,
                    title: filename,
                    format: url.pathExtension,
                    filePath: filename
                )
                modelContext.insert(newBook)

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
        downloadService _: DownloadService,
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

        guard let absoluteURL = FileURL(url: destination) else {
            throw NSError(domain: "AddBook", code: 2, userInfo: [NSLocalizedDescriptionKey: "Invalid local file path"])
        }

        let asset = try await readium.assetRetriever.retrieve(url: absoluteURL).get()

        let publication = try await readium.publicationOpener.open(asset: asset, allowUserInteraction: false, sender: nil).get()

        let title = publication.metadata.title ?? url.lastPathComponent
        let author = publication.metadata.authors.map { $0.name }.joined(separator: ", ")
        let format = asset.format.mediaType?.string ?? MediaType.binary.string

        let newBook = Book(
            id: id,
            title: title,
            author: author.isEmpty ? nil : author,
            format: format,
            filePath: filename
        )

        if let coverImage = try? await publication.cover().get() {
            let coverFilename = "\(id.uuidString)-cover.png"
            let coverDestination = documents.appendingPathComponent(coverFilename)

            if let pngData = coverImage.pngData() {
                do {
                    try pngData.write(to: coverDestination)
                    newBook.coverPath = coverFilename
                } catch {
                    print("Failed to save cover image to disk: \(error)")
                }
            }
        }

        modelContext.insert(newBook)
    }
}
