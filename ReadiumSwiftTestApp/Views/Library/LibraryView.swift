//
//  LibraryView.swift
//  ReadiumSwiftTestApp
//
//  Created by Steven Zeck on 12/30/25.
//

import SwiftData
import SwiftUI
import UniformTypeIdentifiers

/// The main view for the user's library.
///
/// Displays a grid of downloaded books and provides options to add new books via file or URL.
struct LibraryView: View {
    // MARK: - Environment & State

    /// Access to the SwiftData context for CRUD operations on Books.
    @Environment(\.modelContext) private var modelContext

    /// Fetches all Book entities, sorted by creation date (newest first).
    @Query(sort: \Book.createdDate, order: .reverse) private var books: [Book]

    /// The ViewModel handling business logic for file imports and deletions.
    @State private var viewModel = LibraryViewModel()

    /// Access to the DownloadService to check status (if needed).
    @Environment(DownloadService.self) var downloadService

    // MARK: - Layout

    /// Adaptive grid layout for book covers.
    let columns = [
        GridItem(.adaptive(minimum: 140), spacing: 15),
    ]

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Group {
                if books.isEmpty {
                    ContentUnavailableView(
                        "Library is Empty",
                        systemImage: "books.vertical",
                        description: Text("Add books using the + button.")
                    )
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 20) {
                            ForEach(books) { book in
                                // Navigation to the Reader
                                NavigationLink(destination: ReaderLoaderView(book: book)) {
                                    BookGridItem(book: book, width: 140)
                                }
                                // Context Menu for deletion
                                .contextMenu {
                                    Button(role: .destructive) {
                                        viewModel.bookToDelete = book
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                            }
                        }
                        .padding()
                    }
                }
            }
            .animation(.default, value: books)
            .navigationTitle("Library")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button("Add from File") {
                            viewModel.showingFileImporter = true
                        }
                        Button("Add from URL") {
                            viewModel.showingAddURL = true
                        }
                    } label: {
                        Label("Add Book", systemImage: "plus")
                    }
                }
            }
            // File Importer for local files (EPUB/PDF)
            .fileImporter(isPresented: $viewModel.showingFileImporter, allowedContentTypes: [.epub, .pdf]) { result in
                switch result {
                case let .success(url):
                    viewModel.importFile(from: url, modelContext: modelContext)
                case let .failure(error):
                    print("Import failed: \(error)")
                }
            }
            // Sheet for URL import
            .sheet(isPresented: $viewModel.showingAddURL) {
                AddBookURLView()
            }
            .alert(
                "Delete Book?",
                isPresented: Binding(
                    get: { viewModel.bookToDelete != nil },
                    set: { if !$0 { viewModel.bookToDelete = nil } }
                )
            ) {
                Button("Delete", role: .destructive) {
                    if let book = viewModel.bookToDelete {
                        viewModel.deleteBook(book, modelContext: modelContext)
                    }
                }
                Button("Cancel", role: .cancel) {
                    viewModel.bookToDelete = nil
                }
            } message: {
                Text("Are you sure you want to delete '\(viewModel.bookToDelete?.title ?? "this book")'? This cannot be undone.")
            }
        }
    }
}
