//
//  AudiobookViewModel.swift
//  ReadiumSwiftTestApp
//
//  Created by Steven Zeck on 7/2/26
//

import Foundation
import Observation
@preconcurrency import ReadiumNavigator
@preconcurrency import ReadiumShared
import SwiftData
import SwiftUI

@MainActor
@Observable
class AudiobookViewModel: AudioNavigatorDelegate {
    let publication: Publication
    let book: Book
    let navigator: AudioNavigator
    var modelContext: ModelContext?

    var playbackInfo = MediaPlaybackInfo()
    var isSeeking = false
    var seekProgress: Double = 0.0
    var coverImage: UIImage?

    var currentPreferences = AudioPreferences()

    init(publication: Publication, book: Book) {
        self.publication = publication
        self.book = book

        let initialLocation: Locator? = {
            guard let json = book.lastReadLocationJSON else { return nil }
            return try? Locator(jsonString: json)
        }()

        navigator = AudioNavigator(publication: publication, initialLocation: initialLocation)
        navigator.delegate = self

        Task {
            if let image = try? await publication.cover().get() {
                self.coverImage = image
            }
        }
    }

    func applyPreferences() {
        navigator.submitPreferences(currentPreferences)
    }

    func togglePlayPause() {
        if playbackInfo.state == .playing {
            navigator.pause()
        } else {
            navigator.play()
        }
    }

    func seekBackward() {
        Task { await navigator.seek(by: -30) }
    }

    func seekForward() {
        Task { await navigator.seek(by: 30) }
    }

    func nextChapter() {
        Task { await navigator.goForward() }
    }

    func previousChapter() {
        Task { await navigator.goBackward() }
    }

    func seekSliderChanged(progress: Double) {
        guard let duration = playbackInfo.duration else { return }
        Task {
            await navigator.seek(to: progress * duration)
        }
    }

    var currentChapterTitle: String? {
        guard publication.readingOrder.indices.contains(playbackInfo.resourceIndex) else { return nil }
        let link = publication.readingOrder[playbackInfo.resourceIndex]
        return link.title
    }

    var authorName: String? {
        return publication.metadata.authors.map { $0.name }.joined(separator: ", ")
    }

    var bookTitle: String {
        return publication.metadata.title ?? "Unknown Title"
    }

    var chapterNumber: Int {
        return playbackInfo.resourceIndex + 1
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

        if let locator = navigator.currentLocation {
            book.lastReadLocationJSON = try? locator.jsonString()
            try? modelContext?.save()
        }
    }

    func navigator(_: AudioNavigator, shouldPlayNextResource _: MediaPlaybackInfo) -> Bool {
        return true
    }
}
