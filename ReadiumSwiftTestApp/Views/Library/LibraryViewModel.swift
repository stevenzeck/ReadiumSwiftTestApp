//
//  LibraryViewModel.swift
//  ReadiumSwiftTestApp
//
//  Created by Steven Zeck on 2/7/26.
//

import AppIntents
import CoreSpotlight
import Foundation
import Observation
@preconcurrency import ReadiumShared
import SwiftData
import UIKit

/// A Sendable protocol defining asynchronous file system operations.
protocol FileManaging: Sendable {
    func documentDirectoryURL() async -> URL
    func removeItem(at url: URL) async throws
    func copyItem(at srcURL: URL, to dstURL: URL) async throws
    func fileExists(atPath path: String) async -> Bool
}

/// A stateless, Sendable implementation wrapping standard FileManager operations.
struct DefaultFileManager: FileManaging {
    func documentDirectoryURL() async -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    func removeItem(at url: URL) async throws {
        try FileManager.default.removeItem(at: url)
    }

    func copyItem(at srcURL: URL, to dstURL: URL) async throws {
        try FileManager.default.copyItem(at: srcURL, to: dstURL)
    }

    func fileExists(atPath path: String) async -> Bool {
        FileManager.default.fileExists(atPath: path)
    }
}

enum ImportError: LocalizedError {
    case securityScopeAccessDenied
    case fileSystem(String)

    var errorDescription: String? {
        switch self {
        case .securityScopeAccessDenied:
            return "Unable to access the selected file."
        case let .fileSystem(msg):
            return "File system error: \(msg)"
        }
    }
}

/// ViewModel for the LibraryView, handling file imports and deletions.
@MainActor
@Observable
class LibraryViewModel {
    // MARK: - State

    /// Controls the presentation of the file importer sheet.
    var showingFileImporter = false

    /// Controls the presentation of the "Add from URL" sheet.
    var showingAddURL = false

    /// Controls the book to be deleted
    var bookToDelete: Book?

    private let fileManager: any FileManaging

    init(fileManager: any FileManaging = DefaultFileManager()) {
        self.fileManager = fileManager
    }

    // MARK: - Actions

    /// Deletes a book from the library and the file system.
    ///
    /// - Parameters:
    ///   - book: The `Book` entity to delete.
    ///   - modelContext: The SwiftData context used for deletion.
    func deleteBook(_ book: Book, modelContext: ModelContext) {
        let filePath = book.filePath
        let coverPath = book.coverPath
        let bookId = book.id
        let isAudiobook = book.format.lowercased().contains("audio") || book.format.lowercased().contains("zab")

        // Remove from database
        modelContext.delete(book)
        try? modelContext.save()

        // Perform file cleanup in background
        let fileManager = self.fileManager

        Task.detached(priority: .utility) {
            if isAudiobook {
                try? await CSSearchableIndex.default().deleteAppEntities(identifiedBy: [bookId], ofType: AudiobookEntity.self)
            } else {
                try? await CSSearchableIndex.default().deleteAppEntities(identifiedBy: [bookId], ofType: EbookEntity.self)
            }

            let documents = await fileManager.documentDirectoryURL()
            let fileURL = documents.appendingPathComponent(filePath)

            try? await fileManager.removeItem(at: fileURL)

            if let coverPath = coverPath {
                let coverURL = documents.appendingPathComponent(coverPath)
                try? await fileManager.removeItem(at: coverURL)
            }
        }
    }

    /// Imports a file from a local URL (e.g. Files app).
    ///
    func importFile(from url: URL, modelContext: ModelContext, readium: ReadiumService) async {
        do {
            try await performImport(from: url, modelContext: modelContext, readium: readium)
        } catch {
            print("Import failed: \(error.localizedDescription)")
        }
    }

    private func performImport(from url: URL, modelContext: ModelContext, readium: ReadiumService) async throws(ImportError) {
        guard url.startAccessingSecurityScopedResource() else {
            throw .securityScopeAccessDenied
        }
        defer { url.stopAccessingSecurityScopedResource() }

        do {
            let documents = await fileManager.documentDirectoryURL()
            let filename = url.lastPathComponent
            let destination = documents.appendingPathComponent(filename)

            if await fileManager.fileExists(atPath: destination.path) {
                try await fileManager.removeItem(at: destination)
            }

            try await fileManager.copyItem(at: url, to: destination)

            let (publication, format) = try await readium.openPublication(at: destination)
            let id = UUID()

            let title = publication.metadata.title ?? url.deletingPathExtension().lastPathComponent
            let author = publication.metadata.authors.map { $0.name }.joined(separator: ", ")

            let newBook = Book(
                id: id,
                title: title,
                author: author.isEmpty ? nil : author,
                format: format.mediaType?.string ?? url.pathExtension,
                filePath: filename,
                isDownloaded: true
            )

            if let coverImage = try? await publication.cover().get(), let pngData = coverImage.pngData() {
                let coverFilename = "\(id.uuidString)-cover.png"
                let coverDestination = documents.appendingPathComponent(coverFilename)
                try? pngData.write(to: coverDestination)
                newBook.coverPath = coverFilename
            }

            modelContext.insert(newBook)
            try? modelContext.save()

            Task {
                if newBook.format.lowercased().contains("audio") || newBook.format.lowercased().contains("zab") {
                    try? await CSSearchableIndex.default().indexAppEntities([AudiobookEntity(from: newBook)])
                } else {
                    try? await CSSearchableIndex.default().indexAppEntities([EbookEntity(from: newBook)])
                }
            }

        } catch {
            throw .fileSystem(error.localizedDescription)
        }
    }
}
