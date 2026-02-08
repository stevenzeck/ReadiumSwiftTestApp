//
//  SearchView.swift
//  ReadiumSwiftTestApp
//
//  Created by Steven Zeck on 12/30/25.
//

@preconcurrency import ReadiumShared
import SwiftUI

/// A view displaying the search interface.
///
/// Includes a search bar and a scrollable list of results with text highlighting.
struct SearchView: View {
    // MARK: - Properties

    @Bindable var viewModel: SearchViewModel

    /// Callback triggered when a search result is selected.
    var onResultSelected: (Locator) -> Void

    @Environment(\.dismiss) var dismiss

    // MARK: - Body

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search Bar Header
                HStack {
                    TextField("Search...", text: $viewModel.query)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .onSubmit {
                            viewModel.search()
                        }

                    if viewModel.isLoading {
                        ProgressView()
                    } else {
                        Button("Search") {
                            viewModel.search()
                        }
                    }
                }
                .padding()
                .background(.background)

                // Error Display
                if let error = viewModel.error {
                    Text("Error: \(error)")
                        .foregroundColor(.red)
                        .padding()
                }

                ScrollViewReader { proxy in
                    List {
                        ForEach(viewModel.results, id: \.self) { locator in
                            VStack(alignment: .leading, spacing: 8) {
                                let text = locator.text
                                if text.highlight != nil {
                                    Text(highlightedText(from: text))
                                        .font(.subheadline)
                                        .multilineTextAlignment(.leading)
                                } else {
                                    Text(locator.title ?? "Unknown location")
                                        .font(.subheadline)
                                }
                            }
                            .listRowBackground(locator == viewModel.lastSelectedLocator ? Color.gray.opacity(0.1) : Color.clear)
                            .contentShape(Rectangle())
                            .id(locator)
                            .onTapGesture {
                                viewModel.lastSelectedLocator = locator
                                onResultSelected(locator)
                                dismiss()
                            }
                        }
                    }
                    .listStyle(.plain)
                    .onAppear {
                        if let lastSelected = viewModel.lastSelectedLocator {
                            proxy.scrollTo(lastSelected, anchor: .center)
                        }
                    }
                }
            }
            .navigationTitle("Search")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        viewModel.cancel()
                        dismiss()
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    /// Creates an AttributedString with the 'highlight' portion styled.
    func highlightedText(from text: Locator.Text) -> AttributedString {
        var attributed = AttributedString("")

        if let before = text.before {
            attributed.append(AttributedString(before + " "))
        }

        if let highlight = text.highlight {
            var highlighted = AttributedString(highlight)
            highlighted.backgroundColor = .yellow
            highlighted.inlinePresentationIntent = .emphasized
            attributed.append(highlighted)
        }

        if let after = text.after {
            attributed.append(AttributedString(" " + after))
        }

        return attributed
    }
}
