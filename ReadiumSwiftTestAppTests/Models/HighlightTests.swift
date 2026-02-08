//
//  HighlightTests.swift
//  ReadiumSwiftTestApp
//
//  Created by Steven Zeck on 2/5/26.
//

import ReadiumShared
@testable import ReadiumSwiftTestApp
import SwiftData
import XCTest

@MainActor
final class HighlightTests: XCTestCase {
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

    func testHighlightInitialization() {
        let book = Book(title: "Highlight Book", format: "pdf", filePath: "highlight.pdf")
        context.insert(book)

        let json = """
        {
            "href": "/page1.pdf",
            "type": "application/pdf"
        }
        """
        guard let locator = try? Locator(jsonString: json) else {
            XCTFail("Failed to create Locator")
            return
        }

        let id = UUID()
        let highlight = Highlight(id: id, book: book, locator: locator, color: "red", note: "Important")

        XCTAssertEqual(highlight.id, id)
        XCTAssertEqual(highlight.book, book)
        XCTAssertEqual(highlight.color, "red")
        XCTAssertEqual(highlight.note, "Important")
        XCTAssertNotNil(highlight.locator)
    }

    func testHighlightDefaultValues() {
        let book = Book(title: "Default Book", format: "epub", filePath: "def.epub")
        context.insert(book)

        guard let locator = try? Locator(jsonString: "{\"href\":\"/a\", \"type\":\"b\"}") else { return }

        let highlight = Highlight(book: book, locator: locator)

        XCTAssertEqual(highlight.color, "yellow")
        XCTAssertNil(highlight.note)
    }

    func testHighlightPersistence() throws {
        let book = Book(title: "Saved Book", format: "epub", filePath: "saved.epub")
        context.insert(book)

        guard let locator = try? Locator(jsonString: "{\"href\":\"/saved\", \"type\":\"text/html\"}") else { return }

        let highlight = Highlight(book: book, locator: locator, color: "green", note: "My Note")
        context.insert(highlight)
        try context.save()

        let descriptor = FetchDescriptor<Highlight>()
        let fetched = try context.fetch(descriptor)

        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.color, "green")
        XCTAssertEqual(fetched.first?.note, "My Note")
    }

    func testHighlightWithInvalidJSON() throws {
        let book = Book(title: "Corrupt Highlight Book", format: "pdf", filePath: "ch.pdf")
        context.insert(book)

        let highlight = try Highlight(
            book: book,
            locator: Locator(href: XCTUnwrap(AnyURL(string: "dummy")), mediaType: .pdf),
            color: "red"
        )

        // Manually corrupt the JSON string
        highlight.locatorJSON = "NOT JSON"

        context.insert(highlight)
        try? context.save()

        let fetchedHighlight = try? context.fetch(FetchDescriptor<Highlight>()).first
        XCTAssertNotNil(fetchedHighlight)
        XCTAssertNil(fetchedHighlight?.locator, "Locator should be nil when JSON is invalid")

        // Ensure other properties remain valid
        XCTAssertEqual(fetchedHighlight?.color, "red")
    }

    func testDeleteBookDeletesHighlight() throws {
        let book = Book(title: "Delete Me Highlight", format: "epub", filePath: "delete.epub")
        context.insert(book)

        guard let locator = try? Locator(jsonString: "{\"href\":\"/del\", \"type\":\"t\"}") else { return }

        let highlight = Highlight(book: book, locator: locator)
        context.insert(highlight)
        try context.save()

        // Verify existence
        var highlights = try context.fetch(FetchDescriptor<Highlight>())
        XCTAssertEqual(highlights.count, 1)

        // Delete book
        context.delete(book)
        try context.save()

        // Verify cascade delete
        highlights = try context.fetch(FetchDescriptor<Highlight>())
        XCTAssertTrue(highlights.isEmpty, "Highlight should be deleted when Book is deleted")
    }
}
