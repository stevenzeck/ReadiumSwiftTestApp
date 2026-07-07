//
//  BookmarkTests.swift
//  ReadiumSwiftTestApp
//
//  Created by Steven Zeck on 2/5/26.
//

import Foundation
import ReadiumShared
@testable import ReadiumSwiftTestApp
import SwiftData
import Testing

@Suite(.serialized) @MainActor
struct BookmarkTests {
    let container: ModelContainer
    let context: ModelContext

    init() throws {
        let container = try TestHelper.makeInMemoryContainer()
        self.container = container
        context = container.mainContext
    }

    @Test func bookmarkInitialization() throws {
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

        let locator = try #require(try? Locator(jsonString: json), "Failed to create Locator from JSON")

        let bookmarkID = UUID()
        let bookmark = Bookmark(id: bookmarkID, book: book, locator: locator)

        #expect(bookmark.id == bookmarkID)
        #expect(bookmark.book == book)
        #expect(bookmark.locator != nil)
        #expect(bookmark.locator?.href.string == "/chapter1.html")
        #expect(bookmark.locator?.locations.progression == 0.5)

        // Verify JSON string persistence
        #expect(bookmark.locatorJSON.contains("/chapter1.html"))
    }

    @Test func bookmarkPersistence() throws {
        let book = Book(title: "Persisted Book", format: "epub", filePath: "persist.epub")
        context.insert(book)

        let json = """
        {
            "href": "/chapter2.html",
            "type": "text/html"
        }
        """
        let locator = try #require(try? Locator(jsonString: json), "Could not create locator")

        let bookmark = Bookmark(book: book, locator: locator)

        context.insert(bookmark)
        try context.save()

        let descriptor = FetchDescriptor<Bookmark>()
        let fetchedBookmarks = try context.fetch(descriptor)

        #expect(fetchedBookmarks.count == 1)
        #expect(fetchedBookmarks.first?.book?.title == "Persisted Book")
        #expect(fetchedBookmarks.first?.locator?.href.string == "/chapter2.html")
    }

    @Test func bookmarkWithInvalidJSON() throws {
        let book = Book(title: "Corrupt Book", format: "epub", filePath: "corrupt.epub")
        context.insert(book)

        // Simulating a case where the JSON stored in the database is malformed
        let bookmarkID = UUID()
        let bookmark = try Bookmark(id: bookmarkID, book: book, locator: Locator(href: #require(AnyURL(string: "dummy")), mediaType: .html))

        // Manually corrupt the JSON string
        bookmark.locatorJSON = "{ \"invalid\": json_structure "

        context.insert(bookmark)
        try? context.save()

        // Fetch and verify it doesn't crash accessing the computed property
        let fetchedBookmark = try? context.fetch(FetchDescriptor<Bookmark>()).first
        #expect(fetchedBookmark != nil)
        #expect(fetchedBookmark?.locator == nil)
    }

    @Test func deleteBookDeletesBookmark() throws {
        let book = Book(title: "Delete Me", format: "epub", filePath: "delete.epub")
        context.insert(book)

        let json = """
        {
            "href": "/chap.html",
            "type": "text/html"
        }
        """
        let locator = try #require(try? Locator(jsonString: json))

        let bookmark = Bookmark(book: book, locator: locator)
        context.insert(bookmark)
        try context.save()

        // Verify existence
        var bookmarks = try context.fetch(FetchDescriptor<Bookmark>())
        #expect(bookmarks.count == 1)

        // Delete book
        context.delete(book)
        try context.save()

        // Verify cascade delete
        bookmarks = try context.fetch(FetchDescriptor<Bookmark>())
        #expect(bookmarks.isEmpty)
    }
}
