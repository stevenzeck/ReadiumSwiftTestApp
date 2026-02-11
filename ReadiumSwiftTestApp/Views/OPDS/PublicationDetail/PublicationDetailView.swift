//
//  PublicationDetailView.swift
//  ReadiumSwiftTestApp
//
//  Created by Steven Zeck on 12/30/25.
//

@preconcurrency import ReadiumShared
import SwiftData
import SwiftUI

struct PublicationDetailView: View {
    // MARK: - Properties

    let publication: Publication

    @Environment(\.modelContext) private var modelContext
    @Environment(DownloadService.self) var downloadService

    @State private var viewModel = PublicationDetailViewModel()

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Cover Image
                    HStack {
                        Spacer()
                        if let coverURL = publication.coverURL {
                            AsyncImage(url: coverURL) { image in
                                image.resizable().aspectRatio(contentMode: .fit)
                            } placeholder: {
                                Color.gray
                            }
                            .frame(height: 200)
                        }
                        Spacer()
                    }

                    // Metadata
                    Text(publication.metadata.title ?? "Unknown")
                        .font(.title)
                        .multilineTextAlignment(.center)

                    if !publication.metadata.authors.isEmpty {
                        Text(publication.metadata.authors.map { $0.name }.joined(separator: ", "))
                            .font(.headline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }

                    if let description = publication.metadata.description {
                        Text(description)
                            .font(.body)
                    }

                    Spacer(minLength: 20)
                }
                .padding()
            }

            // Sticky Download Footer
            VStack {
                Divider()
                downloadButton
                    .padding()
            }
            .background(Color(UIColor.systemBackground))
        }
        .navigationTitle("Details")
        .task {
            // Listen to events for this specific view (updating button state)
            for await event in await downloadService.downloadEvents {
                viewModel.handleDownloadEvent(event)
            }
        }
    }

    // MARK: - Subviews

    @ViewBuilder
    private var downloadButton: some View {
        if let downloadLink = publication.downloadLink,
           let _ = URL(string: downloadLink.href)
        {
            Button(action: {
                viewModel.startDownload(
                    publication: publication,
                    downloadService: downloadService,
                    modelContext: modelContext
                )
            }) {
                if viewModel.isDownloading {
                    ProgressView()
                } else {
                    Text(viewModel.downloadStatus)
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
            }
            .disabled(viewModel.isDownloading)
        } else {
            Text("No download available")
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity)
                .padding()
        }
    }
}
