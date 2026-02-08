//
//  LibraryViewModel.swift
//  ReadiumSwiftTestApp
//
//  Created by Steven Zeck on 2/7/26.
//

import Foundation
import Observation
import SwiftData

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

    // MARK: - Actions

    /// Deletes a book from the library and the file system.
    ///
    /// - Parameters:
    ///   - book: The `Book` entity to delete.
    ///   - modelContext: The SwiftData context used for deletion.
    func deleteBook(_ book: Book, modelContext: ModelContext) {
        let filePath = book.filePath
        let coverPath = book.coverPath

        // Remove from database
        modelContext.delete(book)

        // Perform file cleanup in background
        Task.detached(priority: .utility) {
            let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let fileURL = documents.appendingPathComponent(filePath)

            try? FileManager.default.removeItem(at: fileURL)

            if let coverPath = coverPath {
                let coverURL = documents.appendingPathComponent(coverPath)
                try? FileManager.default.removeItem(at: coverURL)
            }
        }
    }

    /// Imports a file from a local URL (e.g. Files app).
    ///
    /// - Parameters:
    ///   - url: The security-scoped URL of the file to import.
    ///   - modelContext: The SwiftData context used for insertion.
    func importFile(from url: URL, modelContext: ModelContext) {
        guard url.startAccessingSecurityScopedResource() else { return }
        defer { url.stopAccessingSecurityScopedResource() }

        do {
            let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let filename = url.lastPathComponent
            let destination = documents.appendingPathComponent(filename)

            if FileManager.default.fileExists(atPath: destination.path) {
                try FileManager.default.removeItem(at: destination)
            }

            try FileManager.default.copyItem(at: url, to: destination)

            let newBook = Book(
                title: url.deletingPathExtension().lastPathComponent,
                format: url.pathExtension,
                filePath: filename
            )
            modelContext.insert(newBook)

        } catch {
            print("Error importing file: \(error)")
        }
    }
}
