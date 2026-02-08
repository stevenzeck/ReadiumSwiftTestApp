//
//  BookTests.swift
//  ReadiumSwiftTestApp
//
//  Created by Steven Zeck on 2/4/26.
//

import ReadiumShared
@testable import ReadiumSwiftTestApp
import SwiftData
import XCTest

@MainActor
final class BookTests: XCTestCase {
    var container: ModelContainer!
    var context: ModelContext!

    override func setUp() async throws {
        try await super.setUp()
        container = try TestHelper.makeInMemoryContainer()
        context = container.mainContext
    }

    override func tearDown() async throws {
        container = nil
        context = nil
        try await super.tearDown()
    }

    func testBookInitialization() {
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

        XCTAssertEqual(book.id, id)
        XCTAssertEqual(book.title, "Test Book")
        XCTAssertEqual(book.author, "Test Author")
        XCTAssertEqual(book.format, "epub")
        XCTAssertEqual(book.filePath, "test.epub")
        XCTAssertEqual(book.coverPath, "cover.jpg")
        XCTAssertEqual(book.createdDate, date)
        XCTAssertTrue(book.bookmarks.isEmpty)
        XCTAssertTrue(book.highlights.isEmpty)
    }

    func testBookPersistence() throws {
        let book = Book(
            title: "Persistent Book",
            format: "pdf",
            filePath: "persistent.pdf"
        )

        context.insert(book)
        try context.save()

        let descriptor = FetchDescriptor<Book>(predicate: #Predicate { $0.title == "Persistent Book" })
        let fetchedBooks = try context.fetch(descriptor)

        XCTAssertEqual(fetchedBooks.count, 1)
        XCTAssertEqual(fetchedBooks.first?.title, "Persistent Book")
    }

    func testBookDeletion() throws {
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

        XCTAssertTrue(fetchedBooks.isEmpty)
    }

    func testBookRelationshipCascades() throws {
        // Verify that deleting a book properly deletes associated Highlights and Bookmarks
        // This reinforces the relationship deletion rules defined in the models.

        let book = Book(title: "Parent Book", format: "epub", filePath: "p.epub")
        context.insert(book)

        let locator = try Locator(href: XCTUnwrap(AnyURL(string: "chap1")), mediaType: .html)
        let bookmark = Bookmark(book: book, locator: locator)
        let highlight = Highlight(book: book, locator: locator)

        book.bookmarks.append(bookmark)
        book.highlights.append(highlight)

        try context.save()

        XCTAssertEqual(try context.fetch(FetchDescriptor<Bookmark>()).count, 1)
        XCTAssertEqual(try context.fetch(FetchDescriptor<Highlight>()).count, 1)

        // Delete Parent
        context.delete(book)
        try context.save()

        XCTAssertEqual(try context.fetch(FetchDescriptor<Bookmark>()).count, 0)
        XCTAssertEqual(try context.fetch(FetchDescriptor<Highlight>()).count, 0)
    }
}
