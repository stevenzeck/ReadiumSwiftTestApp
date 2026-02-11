//
//  OPDSBrowserView.swift
//  ReadiumSwiftTestApp
//
//  Created by Steven Zeck on 12/30/25.
//

@preconcurrency import ReadiumOPDS
@preconcurrency import ReadiumShared
import SwiftUI

/// A recursive browser view for OPDS feeds.
struct OPDSBrowserView: View {
    // MARK: - Properties

    /// The URL of the current OPDS feed.
    let url: URL

    /// The title of the current feed.
    let title: String

    /// ReadiumService to get the shared HTTPClient
    @Environment(ReadiumService.self) private var readium

    /// The ViewModel responsible for fetching and parsing the feed.
    /// It is optional because we initiate it in .task using the environment client.
    @State private var viewModel: OPDSBrowserViewModel?

    /// Tracks available width for layout calculations.
    @State private var availableWidth: CGFloat = 0

    // MARK: - Body

    var body: some View {
        Group {
            if let viewModel = viewModel {
                if viewModel.isLoading {
                    ProgressView("Loading Feed...")
                } else if let error = viewModel.error {
                    errorView(error, viewModel: viewModel)
                } else if let feed = viewModel.feed {
                    feedList(feed)
                } else {
                    ProgressView("Initializing...")
                }
            } else {
                ProgressView("Setting up...")
            }
        }
        .navigationTitle(title)
        .task(id: url) {
            // Initialize ViewModel if needed
            if viewModel == nil {
                viewModel = OPDSBrowserViewModel(client: readium.httpClient)
            }
            await viewModel?.loadFeed(url: url)
        }
        .background(
            GeometryReader { geo in
                Color.clear
                    .onAppear { availableWidth = geo.size.width }
                    .onChange(of: geo.size.width) { _, new in availableWidth = new }
            }
        )
    }

    // MARK: - Subviews

    /// Displays an error message with a retry button.
    ///
    /// - Parameters:
    ///   - error: The error that occurred.
    ///   - viewModel: The OPDSBrowserViewModel
    private func errorView(_ error: Error, viewModel: OPDSBrowserViewModel) -> some View {
        VStack {
            Text("Error loading feed")
            Text(error.localizedDescription).font(.caption)
            Button("Retry") {
                Task {
                    await viewModel.loadFeed(url: url, force: true)
                }
            }
        }
    }

    /// The main list content of the feed.
    private func feedList(_ feed: Feed) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if !feed.navigation.isEmpty {
                    navigationSection(feed.navigation)
                        .padding(.horizontal)
                }

                if !feed.groups.isEmpty {
                    groupsSection(feed.groups)
                }

                if !feed.publications.isEmpty {
                    publicationsSection(feed.publications, availableWidth: availableWidth)
                        .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
    }

    /// Displays navigation links.
    private func navigationSection(_ links: [ReadiumShared.Link]) -> some View {
        VStack(alignment: .leading) {
            Text("Navigation").font(.title2).bold()

            ForEach(Array(links.enumerated()), id: \.offset) { _, link in
                if let nextURL = URL(string: link.href, relativeTo: url) {
                    NavigationLink(value: OPDSRoute.feedBrowser(url: nextURL, title: link.title ?? "Link")) {
                        HStack {
                            Text(link.title ?? "Unknown Link")
                            Spacer()
                            Image(systemName: "chevron.right")
                        }
                        .padding(.vertical, 8)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    Divider()
                } else {
                    Text(link.title ?? "Invalid Link")
                        .foregroundColor(.gray)
                }
            }
        }
    }

    /// Displays grouped sections.
    private func groupsSection(_ groups: [ReadiumShared.Group]) -> some View {
        ForEach(groups, id: \.metadata.title) { group in
            VStack(alignment: .leading) {
                HStack {
                    Text(group.metadata.title).font(.title2).bold()
                    Spacer()

                    if let seeAllLink = group.links.first,
                       let nextURL = URL(string: seeAllLink.href, relativeTo: url)
                    {
                        NavigationLink(value: OPDSRoute.feedBrowser(url: nextURL, title: group.metadata.title)) {
                            Text("See All")
                                .font(.subheadline)
                                .foregroundColor(.blue)
                        }
                    }
                }
                .padding(.horizontal)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 15) {
                        ForEach(Array(group.publications.enumerated()), id: \.offset) { _, publication in
                            NavigationLink(value: OPDSRoute.publicationDetail(publication)) {
                                BookGridItem(publication: publication, baseURL: url, width: 140)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)
                }

                if !group.navigation.isEmpty {
                    VStack(alignment: .leading) {
                        ForEach(Array(group.navigation.enumerated()), id: \.offset) { _, link in
                            if let nextURL = URL(string: link.href, relativeTo: url) {
                                NavigationLink(value: OPDSRoute.feedBrowser(url: nextURL, title: link.title ?? "More")) {
                                    HStack {
                                        Text(link.title ?? "More")
                                            .foregroundColor(.primary)
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .foregroundColor(.secondary)
                                    }
                                    .padding(.vertical, 8)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                Divider()
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
    }

    /// Displays publications in a left-aligned grid.
    ///
    /// - Parameters:
    ///   - publications: The list of publications to display.
    ///   - availableWidth: The view's current width to calculate columns.
    private func publicationsSection(_ publications: [Publication], availableWidth: CGFloat) -> some View {
        VStack(alignment: .leading) {
            Text("Publications").font(.title2).bold()

            if availableWidth > 0 {
                let contentWidth = availableWidth - 32
                let itemWidth: CGFloat = 140
                let spacing: CGFloat = 15

                let columnCount = max(1, Int((contentWidth + spacing) / (itemWidth + spacing)))
                let columns = Array(repeating: GridItem(.fixed(itemWidth), spacing: spacing, alignment: .topLeading), count: columnCount)

                LazyVGrid(columns: columns, alignment: .leading, spacing: spacing) {
                    ForEach(Array(publications.enumerated()), id: \.offset) { _, publication in
                        NavigationLink(value: OPDSRoute.publicationDetail(publication)) {
                            BookGridItem(publication: publication, baseURL: url, width: 140)
                        }
                        .buttonStyle(.plain)
                    }
                }
            } else {
                Color.clear.frame(height: 1)
            }
        }
    }
}
