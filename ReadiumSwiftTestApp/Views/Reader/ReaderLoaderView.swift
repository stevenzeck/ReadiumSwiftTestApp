//
//  ReaderLoaderView.swift
//  ReadiumSwiftTestApp
//
//  Created by Steven Zeck on 12/30/25.
//

@preconcurrency import ReadiumNavigator
@preconcurrency import ReadiumShared
import SwiftData
import SwiftUI

struct ReaderLoaderView: View {
    // MARK: - Properties

    let book: Book

    // MARK: - Environment

    @Environment(ReadiumService.self) var readium
    @Environment(\.modelContext) private var modelContext
    @Environment(AudioPlaybackManager.self) var playbackManager

    // MARK: - ViewModel

    @State private var viewModel = ReaderViewModel()

    // MARK: - UI State

    @State private var isChromeVisible = false
    @State private var showingTOC = false
    @State private var showingPreferences = false
    @State private var showingSearch = false
    @State private var showingHighlightNote = false
    @State private var showingBookmarkAlert = false

    // Transient State (Not persisted in ViewModel)
    @State private var targetLocator: Locator?
    @State private var epubNavigator: EPUBNavigatorViewController?
    @State private var currentPreferences = PreferencesStore.shared.load()

    // Highlight Flow State
    @State private var currentSelectionForHighlight: Selection?
    @State private var currentHighlightColor: String = "yellow"
    @State private var highlightNoteText: String = ""

    // MARK: - Body

    var body: some View {
        ZStack {
            Group {
                if let publication = viewModel.publication {
                    if publication.conforms(to: .audiobook) {
                        AudiobookView(publication: publication, book: book)
                            .onAppear {
                                self.isChromeVisible = true
                            }
                    } else {
                        ReaderView(
                            publication: publication,
                            book: book,
                            isChromeVisible: $isChromeVisible,
                            targetLocator: $targetLocator,
                            initialLocation: initialLocation,
                            onGetNavigator: { navigator in
                                if let epubNav = navigator as? EPUBNavigatorViewController {
                                    self.epubNavigator = epubNav
                                    epubNav.submitPreferences(currentPreferences)
                                    applySavedHighlights(to: epubNav)
                                }
                                viewModel.ttsViewModel.setup(navigator: navigator, publication: publication)
                            },
                            onHighlight: { selection, color in
                                self.currentSelectionForHighlight = selection
                                self.currentHighlightColor = color
                                self.highlightNoteText = ""
                                self.showingHighlightNote = true
                            }
                        )
                        .ignoresSafeArea()
                    }
                } else if let error = viewModel.error {
                    Text("Error opening book: \(error.localizedDescription)")
                } else {
                    ProgressView("Opening...")
                        .task {
                            await viewModel.openBook(book: book, readiumService: readium)
                        }
                }
            }

            if viewModel.ttsViewModel.showControls {
                VStack {
                    Spacer()
                    TTSControlsView(viewModel: viewModel.ttsViewModel)
                        .transition(.move(edge: .bottom))
                }
                .zIndex(2)
            }
        }
        .toolbar(isChromeVisible ? .visible : .hidden, for: .navigationBar)
        .toolbarBackground(isChromeVisible ? .visible : .hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            if isChromeVisible {
                ToolbarItem(placement: .topBarTrailing) {
                    if epubNavigator != nil {
                        HStack {
                            Button(action: {
                                if let nav = epubNavigator, let loc = nav.currentLocation {
                                    viewModel.addBookmark(to: book, locator: loc, modelContext: modelContext)
                                    showingBookmarkAlert = true
                                }
                            }) {
                                Image(systemName: "bookmark")
                            }

                            if viewModel.publication?.isSearchable == true {
                                Button(action: { showingSearch = true }) {
                                    Image(systemName: "magnifyingglass")
                                }
                            }

                            Button(action: {
                                if viewModel.ttsViewModel.isPlaying {
                                    viewModel.ttsViewModel.stop()
                                } else {
                                    viewModel.ttsViewModel.start()
                                }
                            }) {
                                Image(systemName: "speaker.wave.2")
                            }

                            Button(action: { showingPreferences = true }) {
                                Image(systemName: "gear")
                            }

                            Button(action: { showingTOC = true }) {
                                Image(systemName: "list.bullet")
                            }
                        }
                    }
                }
            }
        }
        .onAppear {
            playbackManager.isReaderVisible = true
        }
        .onDisappear {
            playbackManager.isReaderVisible = false
        }
        .sheet(isPresented: $showingTOC) {
            TOCView(
                tableOfContents: viewModel.tableOfContents,
                book: book,
                onSelect: { link in
                    self.targetLocator = Locator(href: link.url(), mediaType: link.mediaType ?? MediaType.html, title: link.title)
                    epubNavigator?.apply(decorations: [], in: "search")
                },
                onSelectLocator: { locator in
                    self.targetLocator = locator
                    epubNavigator?.apply(decorations: [], in: "search")
                }
            )
        }
        .sheet(isPresented: $showingPreferences) {
            if let navigator = epubNavigator {
                SimplePreferencesView(
                    navigator: navigator,
                    currentPreferences: $currentPreferences,
                    ttsViewModel: viewModel.ttsViewModel
                )
                .onDisappear {
                    PreferencesStore.shared.save(currentPreferences)
                }
            }
        }
        .sheet(isPresented: $showingSearch) {
            if let vm = viewModel.searchViewModel {
                SearchView(viewModel: vm) { locator in
                    self.targetLocator = locator
                    if let navigator = epubNavigator {
                        let decorations = vm.results.enumerated().map { index, loc in
                            Decoration(
                                id: "searchResult-\(index)",
                                locator: loc,
                                style: .highlight(tint: .yellow, isActive: loc == locator)
                            )
                        }
                        navigator.apply(decorations: decorations, in: "search")
                    }
                }
            }
        }
        .alert("Bookmark Saved", isPresented: $showingBookmarkAlert) {
            Button("OK", role: .cancel) {}
        }
        .alert("Add Note to Highlight", isPresented: $showingHighlightNote) {
            TextField("Note", text: $highlightNoteText)
            Button("Save") {
                if let selection = currentSelectionForHighlight {
                    viewModel.saveHighlight(to: book, selection: selection, color: currentHighlightColor, note: highlightNoteText, modelContext: modelContext)
                    if let nav = epubNavigator {
                        applySavedHighlights(to: nav)
                    }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Optionally add a note to this highlight.")
        }
    }

    func applySavedHighlights(to navigator: DecorableNavigator) {
        let decorations = book.highlights.compactMap { highlight -> Decoration? in
            guard let locator = highlight.locator else { return nil }
            var tint: UIColor = .yellow
            switch highlight.color {
            case "red": tint = .red
            case "green": tint = .green
            case "blue": tint = .blue
            case "purple": tint = .purple
            default: tint = .yellow
            }
            return Decoration(id: highlight.id.uuidString, locator: locator, style: .highlight(tint: tint))
        }
        navigator.apply(decorations: decorations, in: "highlights")
    }

    private var initialLocation: Locator? {
        guard let json = book.lastReadLocationJSON else { return nil }
        return try? Locator(jsonString: json)
    }
}

/// Errors specific to opening a publication.
enum PublicationError: Error {
    case serviceNotReady
    case invalidURL
}
