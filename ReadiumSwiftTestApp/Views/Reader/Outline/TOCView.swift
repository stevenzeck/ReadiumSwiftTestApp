//
//  TOCView.swift
//  ReadiumSwiftTestApp
//
//  Created by Steven Zeck on 12/30/25.
//

import ReadiumShared
import SwiftUI

/// A view displaying the Table of Contents, Bookmarks, and Highlights.
///
/// Provides navigation to specific locations in the publication via a segmented control interface.
struct TOCView: View {
    // MARK: - Properties

    /// The hierarchical table of contents.
    let tableOfContents: [ReadiumShared.Link]

    /// The book entity containing user annotations.
    let book: Book

    /// Callback when a TOC link is selected.
    let onSelect: (ReadiumShared.Link) -> Void

    /// Callback when a bookmark or highlight locator is selected.
    let onSelectLocator: (Locator) -> Void

    // MARK: - State

    @State private var selectedTab = 0
    @Environment(\.dismiss) var dismiss

    // MARK: - Body

    var body: some View {
        NavigationStack {
            VStack {
                Picker("Tabs", selection: $selectedTab) {
                    Text("Contents").tag(0)
                    Text("Bookmarks").tag(1)
                    Text("Highlights").tag(2)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding()

                TabView(selection: $selectedTab) {
                    tocList
                        .tag(0)

                    bookmarksList
                        .tag(1)

                    highlightsList
                        .tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
            .navigationTitle(titleForTab)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }

    // MARK: - Subviews

    private var tocList: some View {
        List(tableOfContents, id: \.href, children: \.outlineChildren) { link in
            Button(action: {
                onSelect(link)
                dismiss()
            }) {
                Text(link.title ?? "Untitled")
                    .font(.body)
                    .foregroundColor(.primary)
            }
        }
        .listStyle(.plain)
    }

    private var bookmarksList: some View {
        List(book.bookmarks.sorted(by: { $0.creationDate > $1.creationDate })) { bookmark in
            Button(action: {
                if let locator = bookmark.locator {
                    onSelectLocator(locator)
                    dismiss()
                }
            }) {
                VStack(alignment: .leading) {
                    Text(bookmark.locator?.title ?? "Bookmark")
                        .font(.headline)
                    Text(bookmark.creationDate.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .listStyle(.plain)
    }

    private var highlightsList: some View {
        List(book.highlights.sorted(by: { $0.creationDate > $1.creationDate })) { highlight in
            Button(action: {
                if let locator = highlight.locator {
                    onSelectLocator(locator)
                    dismiss()
                }
            }) {
                VStack(alignment: .leading) {
                    if let text = highlight.locator?.text.highlight {
                        Text(text)
                            .font(.subheadline)
                            .italic()
                            .lineLimit(2)
                    } else {
                        Text("Highlight")
                    }

                    if let note = highlight.note, !note.isEmpty {
                        Text("Note: \(note)")
                            .font(.caption)
                            .bold()
                            .padding(.top, 2)
                    }
                }
            }
        }
        .listStyle(.plain)
    }

    // MARK: - Helpers

    private var titleForTab: String {
        switch selectedTab {
        case 0: return "Contents"
        case 1: return "Bookmarks"
        case 2: return "Highlights"
        default: return ""
        }
    }
}

// MARK: - Extensions

extension ReadiumShared.Link {
    /// Helper to provide an optional array for SwiftUI's List hierarchy.
    var outlineChildren: [ReadiumShared.Link]? {
        return children.isEmpty ? nil : children
    }
}
