//
//  BookmarkTests.swift
//  ReadiumSwiftTestApp
//
//  Created by Steven Zeck on 2/5/26.
//

import ReadiumShared
@testable import ReadiumSwiftTestApp
import SwiftData
import XCTest

@MainActor
final class BookmarkTests: XCTestCase {
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

    func testBookmarkInitialization() {
        let book = Book(title: "Test Book", format: "epub", filePath: "test.epub")
        context.insert(book)

        let json = """
        {
            "href": "/chapter1.html",
            "type": "text/html",
            "title": "Chapter 1",
            "locations": {
                "progression": 0.5
            }
        }
        """

        guard let locator = try? Locator(jsonString: json) else {
            XCTFail("Failed to create Locator from JSON")
            return
        }

        let bookmarkID = UUID()
        let bookmark = Bookmark(id: bookmarkID, book: book, locator: locator)

        XCTAssertEqual(bookmark.id, bookmarkID)
        XCTAssertEqual(bookmark.book, book)
        XCTAssertNotNil(bookmark.locator)
        XCTAssertEqual(bookmark.locator?.href.string, "/chapter1.html")
        XCTAssertEqual(bookmark.locator?.locations.progression, 0.5)

        // Verify JSON string persistence
        XCTAssertTrue(bookmark.locatorJSON.contains("/chapter1.html"))
    }

    func testBookmarkPersistence() throws {
        let book = Book(title: "Persisted Book", format: "epub", filePath: "persist.epub")
        context.insert(book)

        let json = """
        {
            "href": "/chapter2.html",
            "type": "text/html"
        }
        """
        guard let locator = try? Locator(jsonString: json) else {
            XCTFail("Could not create locator")
            return
        }

        let bookmark = Bookmark(book: book, locator: locator)

        context.insert(bookmark)
        try context.save()

        let descriptor = FetchDescriptor<Bookmark>()
        let fetchedBookmarks = try context.fetch(descriptor)

        XCTAssertEqual(fetchedBookmarks.count, 1)
        XCTAssertEqual(fetchedBookmarks.first?.book?.title, "Persisted Book")
        XCTAssertEqual(fetchedBookmarks.first?.locator?.href.string, "/chapter2.html")
    }

    func testBookmarkWithInvalidJSON() throws {
        let book = Book(title: "Corrupt Book", format: "epub", filePath: "corrupt.epub")
        context.insert(book)

        // Simulating a case where the JSON stored in the database is malformed
        let bookmarkID = UUID()
        let bookmark = try Bookmark(id: bookmarkID, book: book, locator: Locator(href: XCTUnwrap(AnyURL(string: "dummy")), mediaType: .html))

        // Manually corrupt the JSON string
        bookmark.locatorJSON = "{ \"invalid\": json_structure "

        context.insert(bookmark)
        try? context.save()

        // Fetch and verify it doesn't crash accessing the computed property
        let fetchedBookmark = try? context.fetch(FetchDescriptor<Bookmark>()).first
        XCTAssertNotNil(fetchedBookmark)
        XCTAssertNil(fetchedBookmark?.locator, "Locator should be nil when JSON is invalid")
    }

    func testDeleteBookDeletesBookmark() throws {
        let book = Book(title: "Delete Me", format: "epub", filePath: "delete.epub")
        context.insert(book)

        let json = """
        {
            "href": "/chap.html",
            "type": "text/html"
        }
        """
        guard let locator = try? Locator(jsonString: json) else { return }

        let bookmark = Bookmark(book: book, locator: locator)
        context.insert(bookmark)
        try context.save()

        // Verify existence
        var bookmarks = try context.fetch(FetchDescriptor<Bookmark>())
        XCTAssertEqual(bookmarks.count, 1)

        // Delete book
        context.delete(book)
        try context.save()

        // Verify cascade delete
        bookmarks = try context.fetch(FetchDescriptor<Bookmark>())
        XCTAssertTrue(bookmarks.isEmpty, "Bookmark should be deleted when Book is deleted")
    }
}
