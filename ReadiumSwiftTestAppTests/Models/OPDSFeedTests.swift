//
//  OPDSFeedTests.swift
//  ReadiumSwiftTestApp
//
//  Created by Steven Zeck on 2/4/26.
//

@testable import ReadiumSwiftTestApp
import SwiftData
import XCTest

@MainActor
final class OPDSFeedTests: XCTestCase {
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

    func testFeedInitialization() {
        let id = UUID()
        let date = Date()
        let feed = OPDSFeed(
            id: id,
            title: "Feed Project",
            url: "https://example.com/opds.json",
            addedDate: date
        )

        XCTAssertEqual(feed.id, id)
        XCTAssertEqual(feed.title, "Feed Project")
        XCTAssertEqual(feed.url, "https://example.com/opds.json")
        XCTAssertEqual(feed.addedDate, date)
    }

    func testFeedPersistence() throws {
        let feed = OPDSFeed(
            title: "Standard Ebooks",
            url: "https://standardebooks.org/opds"
        )

        context.insert(feed)
        try context.save()

        let descriptor = FetchDescriptor<OPDSFeed>(predicate: #Predicate { $0.title == "Standard Ebooks" })
        let fetchedFeeds = try context.fetch(descriptor)

        XCTAssertEqual(fetchedFeeds.count, 1)
        XCTAssertEqual(fetchedFeeds.first?.url, "https://standardebooks.org/opds")
    }
}
