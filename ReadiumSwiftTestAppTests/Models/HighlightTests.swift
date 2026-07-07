//
//  HighlightTests.swift
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
struct HighlightTests {
    let container: ModelContainer
    let context: ModelContext

    init() throws {
        let container = try TestHelper.makeInMemoryContainer()
        self.container = container
        context = container.mainContext
    }

    @Test func highlightInitialization() throws {
        let book = Book(title: "Highlight Book", format: "pdf", filePath: "highlight.pdf")
        context.insert(book)

        let json = """
        {
            "href": "/page1.pdf",
            "type": "application/pdf"
        }
        """
        let locator = try #require(try? Locator(jsonString: json), "Failed to create Locator")

        let id = UUID()
        let highlight = Highlight(id: id, book: book, locator: locator, color: "red", note: "Important")

        #expect(highlight.id == id)
        #expect(highlight.book == book)
        #expect(highlight.color == "red")
        #expect(highlight.note == "Important")
        #expect(highlight.locator != nil)
    }

    @Test func highlightDefaultValues() throws {
        let book = Book(title: "Default Book", format: "epub", filePath: "def.epub")
        context.insert(book)

        let locator = try #require(try? Locator(jsonString: "{\"href\":\"/a\", \"type\":\"text/html\"}"))

        let highlight = Highlight(book: book, locator: locator)

        #expect(highlight.color == "yellow")
        #expect(highlight.note == nil)
    }

    @Test func highlightPersistence() throws {
        let book = Book(title: "Saved Book", format: "epub", filePath: "saved.epub")
        context.insert(book)

        let locator = try #require(try? Locator(jsonString: "{\"href\":\"/saved\", \"type\":\"text/html\"}"))

        let highlight = Highlight(book: book, locator: locator, color: "green", note: "My Note")
        context.insert(highlight)
        try context.save()

        let descriptor = FetchDescriptor<Highlight>()
        let fetched = try context.fetch(descriptor)

        #expect(fetched.count == 1)
        #expect(fetched.first?.color == "green")
        #expect(fetched.first?.note == "My Note")
    }

    @Test func highlightWithInvalidJSON() throws {
        let book = Book(title: "Corrupt Highlight Book", format: "pdf", filePath: "ch.pdf")
        context.insert(book)

        let highlight = try Highlight(
            book: book,
            locator: Locator(href: #require(AnyURL(string: "dummy")), mediaType: .pdf),
            color: "red"
        )

        // Manually corrupt the JSON string
        highlight.locatorJSON = "NOT JSON"

        context.insert(highlight)
        try? context.save()

        let fetchedHighlight = try? context.fetch(FetchDescriptor<Highlight>()).first
        #expect(fetchedHighlight != nil)
        #expect(fetchedHighlight?.locator == nil)

        // Ensure other properties remain valid
        #expect(fetchedHighlight?.color == "red")
    }

    @Test func deleteBookDeletesHighlight() throws {
        let book = Book(title: "Delete Me Highlight", format: "epub", filePath: "delete.epub")
        context.insert(book)

        let locator = try #require(try? Locator(jsonString: "{\"href\":\"/del\", \"type\":\"text/html\"}"))

        let highlight = Highlight(book: book, locator: locator)
        context.insert(highlight)
        try context.save()

        // Verify existence
        var highlights = try context.fetch(FetchDescriptor<Highlight>())
        #expect(highlights.count == 1)

        // Delete book
        context.delete(book)
        try context.save()

        // Verify cascade delete
        highlights = try context.fetch(FetchDescriptor<Highlight>())
        #expect(highlights.isEmpty)
    }
}
