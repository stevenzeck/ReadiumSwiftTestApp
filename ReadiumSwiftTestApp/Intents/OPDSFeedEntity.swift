//
//  OPDSFeedEntity.swift
//  ReadiumSwiftTestApp
//

import AppIntents
import Foundation

struct OPDSFeedEntity: AppEntity {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "OPDS Feed"

    static let defaultQuery = OPDSFeedEntityQuery()

    let id: UUID

    @Property(title: "Title")
    var title: String

    @Property(title: "URL")
    var url: String

    init(id: UUID, title: String, url: String) {
        self.id = id
        self.title = title
        self.url = url
    }

    init(from feed: OPDSFeed) {
        id = feed.id
        title = feed.title
        url = feed.url
    }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(title)", subtitle: "\(url)")
    }
}

struct OPDSFeedEntityQuery: EntityQuery {
    init() {}

    func entities(for identifiers: [UUID]) async throws -> [OPDSFeedEntity] {
        return await MainActor.run {
            identifiers.compactMap { id in
                if let feed = try? DatabaseHelper.fetchFeed(id: id) {
                    return OPDSFeedEntity(from: feed)
                }
                return nil
            }
        }
    }

    func suggestedEntities() async throws -> [OPDSFeedEntity] {
        return await MainActor.run {
            let feeds = (try? DatabaseHelper.fetchFeeds()) ?? []
            return feeds.map { OPDSFeedEntity(from: $0) }
        }
    }
}
