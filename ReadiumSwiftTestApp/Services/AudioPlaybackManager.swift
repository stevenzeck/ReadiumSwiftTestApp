//
//  AudioPlaybackManager.swift
//  ReadiumSwiftTestApp
//

import Observation
import ReadiumNavigator
import ReadiumShared
import SwiftData
import SwiftUI

@MainActor
@Observable
class AudioPlaybackManager: AudioNavigatorDelegate {
    var navigator: AudioNavigator?
    var publication: Publication?
    var book: Book?
    var modelContext: ModelContext?

    var playbackInfo = MediaPlaybackInfo()
    var isSeeking = false
    var seekProgress: Double = 0.0
    var coverImage: UIImage?

    var currentPreferences = AudioPreferences()

    // Visibility state
    var isReaderVisible: Bool = false
    var presentedBookForMiniPlayer: Book?

    var isPlaying: Bool {
        playbackInfo.state == .playing || playbackInfo.state == .loading
    }

    func load(publication: Publication, book: Book, modelContext: ModelContext) {
        if self.book?.id == book.id, navigator != nil {
            return
        }

        self.publication = publication
        self.book = book
        self.modelContext = modelContext
        playbackInfo = MediaPlaybackInfo()
        coverImage = nil

        let initialLocation: Locator? = {
            guard let json = book.lastReadLocationJSON else { return nil }
            return try? Locator(jsonString: json)
        }()

        let nav = AudioNavigator(publication: publication, initialLocation: initialLocation)
        nav.delegate = self
        navigator = nav

        Task {
            if let image = try? await publication.cover().get() {
                self.coverImage = image
            }
        }

        applyPreferences()
        nav.play()
    }

    func togglePlayPause() {
        if isPlaying {
            navigator?.pause()
        } else {
            navigator?.play()
        }
    }

    func seekBackward() {
        Task { await navigator?.seek(by: -30) }
    }

    func seekForward() {
        Task { await navigator?.seek(by: 30) }
    }

    func nextChapter() {
        let wasPlaying = isPlaying
        Task {
            await navigator?.goForward()
            self.playbackInfo = navigator?.playbackInfo ?? self.playbackInfo
            if wasPlaying {
                navigator?.play()
            }
        }
    }

    func previousChapter() {
        let wasPlaying = isPlaying
        Task {
            await navigator?.goBackward()
            self.playbackInfo = navigator?.playbackInfo ?? self.playbackInfo
            if wasPlaying {
                navigator?.play()
            }
        }
    }

    func seekSliderChanged(progress: Double) {
        guard let duration = playbackInfo.duration else { return }
        Task {
            await navigator?.seek(to: progress * duration)
        }
    }

    func applyPreferences() {
        navigator?.submitPreferences(currentPreferences)
    }

    var currentChapterTitle: String? {
        guard let pub = publication, pub.readingOrder.indices.contains(playbackInfo.resourceIndex) else { return nil }
        return pub.readingOrder[playbackInfo.resourceIndex].title
    }

    var authorName: String? {
        return publication?.metadata.authors.map { $0.name }.joined(separator: ", ")
    }

    var bookTitle: String {
        return publication?.metadata.title ?? "Unknown Title"
    }

    var chapterNumber: Int {
        return playbackInfo.resourceIndex + 1
    }

    var canGoBackward: Bool {
        return playbackInfo.resourceIndex > 0
    }

    var canGoForward: Bool {
        guard let pub = publication else { return false }
        return playbackInfo.resourceIndex < pub.readingOrder.count - 1
    }

    // MARK: - AudioNavigatorDelegate

    nonisolated func navigator(_: Navigator, presentError error: NavigatorError) {
        print("AudioNavigator Error: \(error.localizedDescription)")
    }

    func navigator(_ navigator: AudioNavigator, playbackDidChange info: MediaPlaybackInfo) {
        playbackInfo = info
        if !isSeeking {
            seekProgress = info.progress
        }

        if let locator = navigator.currentLocation, let book = book {
            book.lastReadLocationJSON = try? locator.jsonString()
            try? modelContext?.save()
        }
    }

    func navigator(_: AudioNavigator, shouldPlayNextResource _: MediaPlaybackInfo) -> Bool {
        return true
    }

    func close() {
        navigator?.pause()
        navigator = nil
        publication = nil
        book = nil
    }
}
