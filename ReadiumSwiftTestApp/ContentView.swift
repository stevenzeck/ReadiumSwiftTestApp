//
//  ContentView.swift
//  ReadiumSwiftTestApp
//
//  Created by Steven Zeck on 12/30/25.
//

import AppIntents
import CoreSpotlight
import SwiftData
import SwiftUI

/// The root view of the application interface.
struct ContentView: View {
    // MARK: - Environment

    @Environment(\.modelContext) private var modelContext
    @Environment(DownloadService.self) var downloadService

    @State private var errorMessage: String?
    @State private var showingError: Bool = false
    @State private var selectedTab: Int = 0

    // MARK: - Body

    var body: some View {
        TabView(selection: $selectedTab) {
            // Tab 1: Local Library
            LibraryView()
                .tabItem {
                    Label("Library", systemImage: "books.vertical")
                }
                .tag(0)

            // Tab 2: OPDS Catalog Browser
            OPDSFeedListView()
                .tabItem {
                    Label("OPDS", systemImage: "globe")
                }
                .tag(1)
        }
        .overlay(alignment: .bottom) {
            AudiobookMiniPlayer()
                .padding(.bottom, 49)
        }
        .task {
            // Consume the stream for database side-effects
            for await event in await downloadService.downloadEvents {
                handleDownloadFinish(event)
            }
        }
        .alert("Download Error", isPresented: $showingError, actions: {
            Button("OK", role: .cancel) { errorMessage = nil }
        }, message: {
            Text(errorMessage ?? "An unknown error occurred.")
        })
        .onReceive(NotificationCenter.default.publisher(for: .openBookIntentRun)) { _ in
            selectedTab = 0
        }
        .onReceive(NotificationCenter.default.publisher(for: .openFeedIntentRun)) { _ in
            selectedTab = 1
        }
    }

    // MARK: - Private Methods

    private func handleDownloadFinish(_ event: DownloadEvent) {
        switch event {
        case let .didFinish(id, location):
            let descriptor = FetchDescriptor<Book>(predicate: #Predicate { $0.id == id })
            if let book = try? modelContext.fetch(descriptor).first {
                book.filePath = location.lastPathComponent
                book.isDownloaded = true
                try? modelContext.save()

                Task {
                    if book.format.lowercased().contains("audio") || book.format.lowercased().contains("zab") {
                        try? await CSSearchableIndex.default().indexAppEntities([AudiobookEntity(from: book)])
                    } else {
                        try? await CSSearchableIndex.default().indexAppEntities([EbookEntity(from: book)])
                    }
                }
            }

        case let .didFail(id, error):
            switch error {
            case let .network(urlError):
                errorMessage = "Network error: \(urlError.localizedDescription)"
            case let .fileSystem(msg):
                errorMessage = "File error: \(msg)"
            case let .invalidResponse(code):
                errorMessage = "Server returned error code: \(code)"
            case let .unknown(msg):
                errorMessage = "Error: \(msg)"
            }
            showingError = true

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
