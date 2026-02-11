//
//  AddBookURLView.swift
//  ReadiumSwiftTestApp
//
//  Created by Steven Zeck on 12/30/25.
//

import SwiftData
import SwiftUI

/// A sheet view that allows the user to add a book to their library by entering a direct URL.
struct AddBookURLView: View {
    // MARK: - Environment

    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) var modelContext
    @Environment(DownloadService.self) var downloadService

    // MARK: - State

    @State private var viewModel = AddBookURLViewModel()

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Form {
                Section(footer: Text("Enter the direct URL to an EPUB or PDF file.")) {
                    TextField("URL", text: $viewModel.urlString)
                        .keyboardType(.URL)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                }
            }
            .navigationTitle("Add from URL")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Download") {
                        viewModel.startDownload(downloadService: downloadService, modelContext: modelContext) {
                            dismiss()
                        }
                    }
                    .disabled(viewModel.urlString.isEmpty)
                }
            }
        }
    }
}
