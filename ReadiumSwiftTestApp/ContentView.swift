//
//  ContentView.swift
//  ReadiumSwiftTestApp
//
//  Created by Steven Zeck on 12/30/25.
//

import SwiftData
import SwiftUI

/// The root view of the application interface.
///
/// Sets up the main `TabView` navigation structure and acts as a global listener for
/// background download completions to update the data model.
struct ContentView: View {
    // MARK: - Environment

    @Environment(\.modelContext) private var modelContext
    @Environment(DownloadService.self) var downloadService

    // MARK: - Body

    var body: some View {
        TabView {
            // Tab 1: Local Library
            LibraryView()
                .tabItem {
                    Label("Library", systemImage: "books.vertical")
                }

            // Tab 2: OPDS Catalog Browser
            OPDSFeedListView()
                .tabItem {
                    Label("OPDS", systemImage: "globe")
                }
        }
        .task {
            for await event in downloadService.downloadEvents {
                handleDownloadFinish(event)
            }
        }
    }

    // MARK: - Private Methods

    /// Updates the SwiftData `Book` entity when a background download finishes.
    ///
    /// - Parameter event: The download event containing the UUID and file location.
    private func handleDownloadFinish(_ event: DownloadEvent) {
        switch event {
        case let .didFinish(id, location):
            let descriptor = FetchDescriptor<Book>(predicate: #Predicate { $0.id == id })
            if let book = try? modelContext.fetch(descriptor).first {
                book.filePath = location.lastPathComponent
                try? modelContext.save()
            }

        case let .didFail(id, _):
            let descriptor = FetchDescriptor<Book>(predicate: #Predicate { $0.id == id })
            if let book = try? modelContext.fetch(descriptor).first {
                modelContext.delete(book)
                try? modelContext.save()
            }

        default:
            break
        }
    }
}
