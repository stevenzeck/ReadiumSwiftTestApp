//
//  BookTests.swift
//  ReadiumSwiftTestApp
//
//  Created by Steven Zeck on 2/4/26.
//

import Foundation
import ReadiumShared
@testable import ReadiumSwiftTestApp
import SwiftData
import Testing

@Suite(.serialized) @MainActor
struct BookTests {
    let container: ModelContainer
    let context: ModelContext

    init() throws {
        let container = try TestHelper.makeInMemoryContainer()
        self.container = container
        context = container.mainContext
    }

    @Test func bookInitialization() {
        let id = UUID()
        let date = Date()
        let book = Book(
            id: id,
            title: "Test Book",
            author: "Test Author",
            format: "epub",
            filePath: "test.epub",
            coverPath: "cover.jpg",
            createdDate: date
        )

        #expect(book.id == id)
        #expect(book.title == "Test Book")
        #expect(book.author == "Test Author")
        #expect(book.format == "epub")
        #expect(book.filePath == "test.epub")
        #expect(book.coverPath == "cover.jpg")
        #expect(book.createdDate == date)
        #expect(book.bookmarks.isEmpty)
        #expect(book.highlights.isEmpty)
    }

    @Test func bookPersistence() throws {
        let book = Book(
            title: "Persistent Book",
            format: "pdf",
            filePath: "persistent.pdf"
        )

        context.insert(book)
        try context.save()

        let descriptor = FetchDescriptor<Book>(predicate: #Predicate { $0.title == "Persistent Book" })
        let fetchedBooks = try context.fetch(descriptor)

        #expect(fetchedBooks.count == 1)
        #expect(fetchedBooks.first?.title == "Persistent Book")
    }

    @Test func bookDeletion() throws {
        let book = Book(
            title: "Book to Delete",
            format: "epub",
            filePath: "delete.epub"
        )
        context.insert(book)
        try context.save()

        context.delete(book)
        try context.save()

        let descriptor = FetchDescriptor<Book>(predicate: #Predicate { $0.title == "Book to Delete" })
        let fetchedBooks = try context.fetch(descriptor)

        #expect(fetchedBooks.isEmpty)
    }

    @Test func bookRelationshipCascades() throws {
        // Verify that deleting a book properly deletes associated Highlights and Bookmarks
        // This reinforces the relationship deletion rules defined in the models.

        let book = Book(title: "Parent Book", format: "epub", filePath: "p.epub")
        context.insert(book)

        let locator = try Locator(href: #require(AnyURL(string: "chap1")), mediaType: .html)
        let bookmark = Bookmark(book: book, locator: locator)
        let highlight = Highlight(book: book, locator: locator)

        book.bookmarks.append(bookmark)
        book.highlights.append(highlight)

        try context.save()

        #expect(try context.fetch(FetchDescriptor<Bookmark>()).count == 1)
        #expect(try context.fetch(FetchDescriptor<Highlight>()).count == 1)

        // Delete Parent
        context.delete(book)
        try context.save()

        #expect(try context.fetch(FetchDescriptor<Bookmark>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<Highlight>()).isEmpty)
    }
}
