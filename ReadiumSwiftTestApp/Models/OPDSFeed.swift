//
//  OPDSFeed.swift
//  ReadiumSwiftTestApp
//
//  Created by Steven Zeck on 12/30/25.
//

import Foundation
import SwiftData

/// Represents a saved OPDS feed source.
///
/// This class is managed by SwiftData and stores the configuration for external OPDS catalogs.
@Model
final class OPDSFeed {
    // MARK: - Properties

    /// The unique identifier for the feed.
    var id: UUID

    /// The user-visible title of the feed.
    var title: String

    /// The absolute URL of the OPDS feed (supporting OPDS 1.x or 2.0).
    var url: String

    /// The date the feed was added to the application.
    var addedDate: Date

    // MARK: - Initialization

    /// Initializes a new `OPDSFeed`.
    ///
    /// - Parameters:
    ///   - id: The unique identifier. Defaults to a new UUID.
    ///   - title: The display title for the feed.
    ///   - url: The URL of the feed endpoint.
    ///   - addedDate: The date of creation. Defaults to the current date.
    init(id: UUID = UUID(), title: String, url: String, addedDate: Date = Date()) {
        self.id = id
        self.title = title
        self.url = url
        self.addedDate = addedDate
    }
}
