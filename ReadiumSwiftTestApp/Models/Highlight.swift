//
//  Highlight.swift
//  ReadiumSwiftTestApp
//
//  Created by Steven Zeck on 12/30/25.
//

import Foundation
import ReadiumShared
import SwiftData

/// Represents a highlighted range of text in a book, optionally with a user note and color.
@Model
final class Highlight {
    /// The unique identifier for the highlight.
    var id: UUID

    /// The parent book associated with this highlight.
    var book: Book?

    /// The JSON representation of the Readium `Locator` defining the highlighted range.
    var locatorJSON: String

    /// The color of the highlight (e.g., "yellow", "red", or hex code).
    var color: String

    /// An optional user-provided note attached to the highlight.
    var note: String?

    /// The date the highlight was created.
    var creationDate: Date

    /// Initializes a new `Highlight`.
    ///
    /// - Parameters:
    ///   - id: The unique identifier. Defaults to a new UUID.
    ///   - book: The parent `Book` instance.
    ///   - locator: The Readium `Locator` defining the text range.
    ///   - color: The color string identifier. Defaults to "yellow".
    ///   - note: An optional text note.
    init(id: UUID = UUID(), book: Book, locator: Locator, color: String = "yellow", note: String? = nil) {
        self.id = id
        self.book = book
        locatorJSON = locator.jsonString ?? "{}"
        self.color = color
        self.note = note
        creationDate = Date()
    }

    /// The deserialized Readium `Locator` object.
    ///
    /// - Returns: A `Locator` if the JSON is valid, otherwise `nil`.
    var locator: Locator? {
        try? Locator(jsonString: locatorJSON)
    }
}
