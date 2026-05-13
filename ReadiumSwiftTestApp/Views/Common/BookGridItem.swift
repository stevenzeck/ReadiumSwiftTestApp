//
//  BookGridItem.swift
//  ReadiumSwiftTestApp
//
//  Created by Steven Zeck on 12/30/25.
//

@preconcurrency import ReadiumShared
import SwiftUI

/// A unified view for displaying a book item within a grid or list layout.
///
/// This view is versatile and can be initialized with either a local `Book` entity (for the Library)
/// or a remote `Publication` object (for OPDS feeds).
struct BookGridItem: View {
    // MARK: - Properties

    /// The title of the book.
    let title: String

    /// The author of the book.
    let author: String?

    /// The URL for the cover image (remote).
    let remoteCoverURL: URL?

    /// The local path for the cover image.
    let localCoverPath: String?

    /// The loaded local cover image.
    @State private var localCoverImage: UIImage?

    /// Whether the book is fully downloaded (used for local books).
    let isDownloaded: Bool

    /// An optional fixed width for the item. If `nil`, the view is flexible.
    let width: CGFloat?

    // MARK: - Initializers

    /// Initializes the item with a local `Book` entity.
    ///
    /// - Parameters:
    ///   - book: The local `Book` object.
    ///   - width: The preferred width for the item.
    init(book: Book, width: CGFloat? = nil) {
        title = book.title
        author = book.author
        isDownloaded = book.isDownloaded
        self.width = width

        // Resolve cover logic
        if let coverPath = book.coverPath {
            if let url = URL(string: coverPath), url.scheme != nil {
                // Remote URL stored
                remoteCoverURL = url
                localCoverPath = nil
            } else {
                // Local file logic: store path and load asynchronously
                remoteCoverURL = nil
                localCoverPath = coverPath
            }
        } else {
            remoteCoverURL = nil
            localCoverPath = nil
        }
    }

    /// Initializes the item with a remote OPDS `Publication`.
    ///
    /// - Parameters:
    ///   - publication: The Readium `Publication` object.
    ///   - baseURL: The base URL of the feed to resolve relative links.
    ///   - width: The preferred width for the item.
    init(publication: Publication, baseURL: URL, width: CGFloat? = nil) {
        title = publication.metadata.title ?? "No Title"
        author = publication.metadata.authors.first?.name
        isDownloaded = true
        self.width = width
        localCoverPath = nil

        if let coverURL = publication.coverURL {
            remoteCoverURL = URL(string: coverURL.absoluteString, relativeTo: baseURL)
        } else {
            remoteCoverURL = nil
        }
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading) {
            // Cover View
            coverView
                .frame(width: width, height: 210)
                .clipped()
                .cornerRadius(8)
                .overlay {
                    if !isDownloaded {
                        ZStack {
                            Color.black.opacity(0.4)
                            VStack(spacing: 10) {
                                ProgressView()
                                    .tint(.white)
                                Text("Downloading...")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                            }
                        }
                    }
                }

            // Metadata
            Text(title)
                .font(.headline)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .foregroundColor(.primary)

            if let author = author {
                Text(author)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .multilineTextAlignment(.leading)
            }

            Spacer()
        }
        .frame(width: width)
        .frame(maxWidth: width == nil ? .infinity : nil, alignment: .leading)
        .task {
            if let path = localCoverPath, localCoverImage == nil {
                await loadLocalCover(path)
            }
        }
    }

    // MARK: - Subviews

    /// Renders the cover image, handling local, remote, and fallback cases.
    @ViewBuilder
    private var coverView: some View {
        if let image = localCoverImage {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
        } else if let url = remoteCoverURL {
            AsyncImage(url: url) { image in
                image.resizable().aspectRatio(contentMode: .fill)
            } placeholder: {
                Color.gray.opacity(0.3)
            }
        } else {
            // Fallback placeholder (also shown while local image is loading)
            ZStack {
                Rectangle().fill(Color.gray.opacity(0.3))
                VStack {
                    Image(systemName: "book.closed")
                        .font(.largeTitle)
                        .foregroundColor(.gray)
                    Text(title.prefix(1))
                        .font(.largeTitle)
                        .foregroundColor(.gray)
                }
            }
        }
    }

    // MARK: - Helpers

    /// Loads the local cover image from the Documents directory asynchronously.
    @MainActor
    private func loadLocalCover(_ path: String) async {
        let image = await Task.detached(priority: .userInitiated) { () -> UIImage? in
            let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let fullPath = documents.appendingPathComponent(path)

            guard let data = try? Data(contentsOf: fullPath),
                  let rawImage = UIImage(data: data)
            else {
                return nil
            }
            return await rawImage.byPreparingForDisplay()
        }.value

        if let image = image {
            withAnimation {
                self.localCoverImage = image
            }
        }
    }
}
