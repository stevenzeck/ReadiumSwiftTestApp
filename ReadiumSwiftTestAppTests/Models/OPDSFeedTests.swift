//
//  OPDSFeedTests.swift
//  ReadiumSwiftTestApp
//
//  Created by Steven Zeck on 2/4/26.
//

import Foundation
@testable import ReadiumSwiftTestApp
import SwiftData
import Testing

@Suite(.serialized) @MainActor
struct OPDSFeedTests {
    let container: ModelContainer
    let context: ModelContext

    init() throws {
        let container = try TestHelper.makeInMemoryContainer()
        self.container = container
        context = container.mainContext
    }

    @Test func feedInitialization() {
        let id = UUID()
        let date = Date()
        let feed = OPDSFeed(
            id: id,
            title: "Feed Project",
            url: "https://example.com/opds.json",
            addedDate: date
        )

        #expect(feed.id == id)
        #expect(feed.title == "Feed Project")
        #expect(feed.url == "https://example.com/opds.json")
        #expect(feed.addedDate == date)
    }

    @Test func feedPersistence() throws {
        let feed = OPDSFeed(
            title: "Standard Ebooks",
            url: "https://standardebooks.org/opds"
        )

        context.insert(feed)
        try context.save()

        let descriptor = FetchDescriptor<OPDSFeed>(predicate: #Predicate { $0.title == "Standard Ebooks" })
        let fetchedFeeds = try context.fetch(descriptor)

        #expect(fetchedFeeds.count == 1)
        #expect(fetchedFeeds.first?.url == "https://standardebooks.org/opds")
    }
}
