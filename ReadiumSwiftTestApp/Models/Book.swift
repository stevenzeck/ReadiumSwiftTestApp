//
//  Book.swift
//  ReadiumSwiftTestApp
//
//  Created by Steven Zeck on 12/30/25.
//

import Foundation
import SwiftData

/// Represents a book saved in the local library.
///
/// This class is managed by SwiftData and serves as the primary data model for user-imported publications.
@Model
final class Book {
    typealias Id = UUID

    // MARK: - Properties

    /// Unique identifier for the book.
    var id: UUID

    /// The title of the book.
    var title: String

    /// The author's name, if available.
    var author: String?

    /// The file format extension (e.g., "epub", "pdf").
    var format: String

    /// The relative file path to the book file stored in the Documents directory.
    var filePath: String

    /// The relative file path to the cover image stored in the Documents directory, if available.
    var coverPath: String?

    /// The date the book was added to the library.
    var createdDate: Date

    /// The collection of user-created bookmarks associated with this book.
    @Relationship(deleteRule: .cascade, inverse: \Bookmark.book)
    var bookmarks: [Bookmark] = []

    /// The collection of user-created highlights associated with this book.
    @Relationship(deleteRule: .cascade, inverse: \Highlight.book)
    var highlights: [Highlight] = []

    // MARK: - Initialization

    /// Initializes a new `Book` instance.
    ///
    /// - Parameters:
    ///   - id: The unique identifier for the book. Defaults to a new UUID.
    ///   - title: The title of the book.
    ///   - author: The author of the book, if known.
    ///   - format: The file format of the publication (e.g., "epub").
    ///   - filePath: The relative path to the book file.
    ///   - coverPath: The relative path to the cover image file, if any.
    ///   - createdDate: The date of import. Defaults to the current date.
    init(id: UUID = UUID(), title: String, author: String? = nil, format: String, filePath: String, coverPath: String? = nil, createdDate: Date = Date()) {
        self.id = id
        self.title = title
        self.author = author
        self.format = format
        self.filePath = filePath
        self.coverPath = coverPath
        self.createdDate = createdDate
    }
}
