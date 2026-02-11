//
//  OPDSFeedListView.swift
//  ReadiumSwiftTestApp
//
//  Created by Steven Zeck on 12/30/25.
//

import SwiftData
import SwiftUI

/// Displays a list of saved OPDS feeds.
///
/// Allows the user to browse existing feeds or add/edit new ones.
struct OPDSFeedListView: View {
    // MARK: - Environment & State

    @Environment(\.modelContext) private var modelContext
    @Query private var feeds: [OPDSFeed]

    @State private var viewModel = OPDSFeedListViewModel()

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Group {
                if feeds.isEmpty {
                    ContentUnavailableView(
                        "No OPDS Feeds",
                        systemImage: "books.vertical",
                        description: Text("Add feeds using the + button.")
                    )
                } else {
                    List {
                        ForEach(feeds) { feed in
                            if let url = URL(string: feed.url) {
                                NavigationLink(value: OPDSRoute.feedBrowser(url: url, title: feed.title)) {
                                    feedRow(feed)
                                }
                                .swipeActions(edge: .leading) {
                                    Button {
                                        viewModel.feedToEdit = feed
                                    } label: {
                                        Label("Edit", systemImage: "pencil")
                                    }
                                    .tint(.blue)
                                }
                            } else {
                                // Invalid URL fallback
                                HStack {
                                    feedRow(feed)
                                    Spacer()
                                    Image(systemName: "exclamationmark.triangle")
                                        .foregroundColor(.red)
                                }
                                .swipeActions(edge: .leading) {
                                    Button {
                                        viewModel.feedToEdit = feed
                                    } label: {
                                        Label("Edit", systemImage: "pencil")
                                    }
                                    .tint(.blue)
                                }
                            }
                        }
                        .onDelete { offsets in
                            viewModel.requestDeletion(at: offsets, in: feeds)
                        }
                    }
                    .animation(.default, value: feeds)
                }
            }
            .navigationTitle("OPDS Feeds")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { viewModel.showingAddFeed = true }) {
                        Label("Add Feed", systemImage: "plus")
                    }
                }
            }
            .navigationDestination(for: OPDSRoute.self) { route in
                switch route {
                case let .feedBrowser(url, title):
                    OPDSBrowserView(url: url, title: title)
                case let .publicationDetail(pub):
                    PublicationDetailView(publication: pub)
                }
            }
            .sheet(isPresented: $viewModel.showingAddFeed) { AddFeedView() }
            .sheet(item: $viewModel.feedToEdit) { feed in EditFeedView(feed: feed) }
            .alert("Delete Feed?", isPresented: $viewModel.showingDeleteAlert) {
                Button("Delete", role: .destructive) {
                    viewModel.confirmDeletion(modelContext: modelContext)
                }
                Button("Cancel", role: .cancel) {
                    viewModel.feedsToDelete = []
                }
            } message: {
                if viewModel.feedsToDelete.count == 1 {
                    Text("Are you sure you want to delete '\(viewModel.feedsToDelete.first?.title ?? "this feed")'?")
                } else {
                    Text("Are you sure you want to delete these \(viewModel.feedsToDelete.count) feeds?")
                }
            }
        }
    }

    // MARK: - Subviews

    private func feedRow(_ feed: OPDSFeed) -> some View {
        VStack(alignment: .leading) {
            Text(feed.title)
                .font(.headline)
            Text(feed.url)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

/// A form view to edit an existing OPDS feed.
struct EditFeedView: View {
    @Environment(\.dismiss) var dismiss
    @Bindable var feed: OPDSFeed

    var body: some View {
        NavigationStack {
            Form {
                TextField("Title", text: $feed.title)
                TextField("URL", text: $feed.url)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
                    .autocorrectionDisabled()
            }
            .navigationTitle("Edit Feed")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .disabled(feed.title.isEmpty || feed.url.isEmpty)
                }
            }
        }
    }
}

/// A form view to add a new OPDS feed.
struct AddFeedView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) var modelContext

    @State private var title = ""
    @State private var url = ""

    var body: some View {
        NavigationStack {
            Form {
                TextField("Title", text: $title)
                TextField("URL", text: $url)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
                    .autocorrectionDisabled()
            }
            .navigationTitle("Add Feed")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        let newFeed = OPDSFeed(title: title, url: url)
                        modelContext.insert(newFeed)
                        dismiss()
                    }
                    .disabled(title.isEmpty || url.isEmpty)
                }
            }
        }
    }
}
