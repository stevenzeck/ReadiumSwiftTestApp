//
//  DatabaseHelper.swift
//  ReadiumSwiftTestApp
//

import Foundation
import SwiftData

@MainActor
struct DatabaseHelper {
    static let sharedContainer: ModelContainer = {
        do {
            return try ModelContainer(for: Book.self, OPDSFeed.self, Bookmark.self, Highlight.self)
        } catch {
            fatalError("Failed to create shared ModelContainer for Intents: \(error)")
        }
    }()

    static func fetchBooks() throws -> [Book] {
        let context = ModelContext(sharedContainer)
        let descriptor = FetchDescriptor<Book>()
        return try context.fetch(descriptor)
    }

    static func fetchEbooks() throws -> [Book] {
        let books = try fetchBooks()
        return books.filter { !$0.format.lowercased().contains("audio") && !$0.format.lowercased().contains("zab") }
    }

    static func fetchAudiobooks() throws -> [Book] {
        let books = try fetchBooks()
        return books.filter { $0.format.lowercased().contains("audio") || $0.format.lowercased().contains("zab") }
    }

    static func fetchBook(id: UUID) throws -> Book? {
        let context = ModelContext(sharedContainer)
        // Predicate macro can sometimes be tricky with UUIDs, but usually works in SwiftData.
        let descriptor = FetchDescriptor<Book>(predicate: #Predicate { $0.id == id })
        return try context.fetch(descriptor).first
    }

    static func fetchFeeds() throws -> [OPDSFeed] {
        let context = ModelContext(sharedContainer)
        let descriptor = FetchDescriptor<OPDSFeed>()
        return try context.fetch(descriptor)
    }

    static func fetchFeed(id: UUID) throws -> OPDSFeed? {
        let context = ModelContext(sharedContainer)
        let descriptor = FetchDescriptor<OPDSFeed>(predicate: #Predicate { $0.id == id })
        return try context.fetch(descriptor).first
    }
}
