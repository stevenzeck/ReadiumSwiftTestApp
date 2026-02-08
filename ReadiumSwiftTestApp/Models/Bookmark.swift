//
//  Bookmark.swift
//  ReadiumSwiftTestApp
//
//  Created by Steven Zeck on 12/30/25.
//

import Foundation
import ReadiumShared
import SwiftData

/// Represents a specific location in a book saved by the user.
///
/// Bookmarks are persisted using SwiftData and link back to a parent `Book`.
@Model
final class Bookmark {
    /// The unique identifier for the bookmark.
    var id: UUID

    /// The parent book associated with this bookmark.
    var book: Book?

    /// The JSON representation of the Readium `Locator`.
    var locatorJSON: String

    /// The date the bookmark was created.
    var creationDate: Date

    /// Initializes a new `Bookmark`.
    ///
    /// - Parameters:
    ///   - id: The unique identifier. Defaults to a new UUID.
    ///   - book: The parent `Book` instance.
    ///   - locator: The Readium `Locator` object representing the position in the publication.
    init(id: UUID = UUID(), book: Book, locator: Locator) {
        self.id = id
        self.book = book
        locatorJSON = locator.jsonString ?? "{}"
        creationDate = Date()
    }

    /// The deserialized Readium `Locator` object.
    ///
    /// - Returns: A `Locator` if the JSON is valid, otherwise `nil`.
    var locator: Locator? {
        try? Locator(jsonString: locatorJSON)
    }
}
