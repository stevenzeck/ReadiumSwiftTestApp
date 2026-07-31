//
//  BookEntity.swift
//  ReadiumSwiftTestApp
//

import AppIntents
import CoreSpotlight
import Foundation

// MARK: - Ebook Entity

struct EbookEntity: IndexedEntity {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Book"

    static let defaultQuery = EbookEntityQuery()

    let id: UUID

    @Property(title: "Title")
    var title: String

    @Property(title: "Author")
    var author: String?

    @Property(title: "Format")
    var format: String

    init(id: UUID, title: String, author: String?, format: String) {
        self.id = id
        self.title = title
        self.author = author
        self.format = format
    }

    init(from book: Book) {
        id = book.id
        title = book.title
        author = book.author
        format = book.format
    }

    var displayRepresentation: DisplayRepresentation {
        if let author = author, !author.isEmpty {
            return DisplayRepresentation(title: "\(title)", subtitle: "\(author)")
        } else {
            return DisplayRepresentation(title: "\(title)")
        }
    }
}

struct EbookEntityQuery: EntityQuery {
    init() {}

    func entities(for identifiers: [UUID]) async throws -> [EbookEntity] {
        return await MainActor.run {
            identifiers.compactMap { id in
                if let book = try? DatabaseHelper.fetchBook(id: id), !book.format.lowercased().contains("audio"), !book.format.lowercased().contains("zab") {
                    return EbookEntity(from: book)
                }
                return nil
            }
        }
    }

    func suggestedEntities() async throws -> [EbookEntity] {
        return await MainActor.run {
            let books = (try? DatabaseHelper.fetchEbooks()) ?? []
            return books.map { EbookEntity(from: $0) }
        }
    }
}

// MARK: - Audiobook Entity

struct AudiobookEntity: IndexedEntity {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Audiobook"

    static let defaultQuery = AudiobookEntityQuery()

    let id: UUID

    @Property(title: "Title")
    var title: String

    @Property(title: "Author")
    var author: String?

    @Property(title: "Format")
    var format: String

    init(id: UUID, title: String, author: String?, format: String) {
        self.id = id
        self.title = title
        self.author = author
        self.format = format
    }

    init(from book: Book) {
        id = book.id
        title = book.title
        author = book.author
        format = book.format
    }

    var displayRepresentation: DisplayRepresentation {
        if let author = author, !author.isEmpty {
            return DisplayRepresentation(title: "\(title)", subtitle: "\(author)")
        } else {
            return DisplayRepresentation(title: "\(title)")
        }
    }
}

struct AudiobookEntityQuery: EntityQuery {
    init() {}

    func entities(for identifiers: [UUID]) async throws -> [AudiobookEntity] {
        return await MainActor.run {
            identifiers.compactMap { id in
                if let book = try? DatabaseHelper.fetchBook(id: id), book.format.lowercased().contains("audio") || book.format.lowercased().contains("zab") {
                    return AudiobookEntity(from: book)
                }
                return nil
            }
        }
    }

    func suggestedEntities() async throws -> [AudiobookEntity] {
        return await MainActor.run {
            let books = (try? DatabaseHelper.fetchAudiobooks()) ?? []
            return books.map { AudiobookEntity(from: $0) }
        }
    }
}
