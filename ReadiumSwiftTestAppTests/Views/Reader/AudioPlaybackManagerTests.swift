//
//  AudioPlaybackManagerTests.swift
//  ReadiumSwiftTestApp
//
//  Created by Steven Zeck on 7/2/26
//

import Foundation
import ReadiumNavigator
import ReadiumShared
@testable import ReadiumSwiftTestApp
import SwiftData
import Testing

@Suite(.serialized) @MainActor
struct AudioPlaybackManagerTests {
    let playbackManager: AudioPlaybackManager
    let mockContainer: ModelContext

    init() throws {
        let container = try TestHelper.makeInMemoryContainer()
        let context = ModelContext(container)
        mockContainer = context

        let metadata = Metadata(title: "Test Audiobook")
        let manifest = Manifest(metadata: metadata, readingOrder: [
            Link(href: "/chap1", title: "Chapter 1"),
            Link(href: "/chap2", title: "Chapter 2"),
        ])
        let publication = Publication(manifest: manifest)

        let book = Book(title: "Test Audiobook", format: "audiobook", filePath: "dummy")

        let playbackManager = AudioPlaybackManager()
        playbackManager.load(publication: publication, book: book, modelContext: context)
        self.playbackManager = playbackManager
    }

    @Test func initialState() {
        #expect(playbackManager.bookTitle == "Test Audiobook")
        #expect(playbackManager.playbackInfo.state == .loading)
    }

    @Test func chapterTitle() {
        let info = MediaPlaybackInfo(resourceIndex: 0, state: .playing, time: 0, duration: 100)
        playbackManager.playbackInfo = info
        #expect(playbackManager.currentChapterTitle == "Chapter 1")
        #expect(playbackManager.chapterNumber == 1)

        let info2 = MediaPlaybackInfo(resourceIndex: 1, state: .playing, time: 0, duration: 100)
        playbackManager.playbackInfo = info2
        #expect(playbackManager.currentChapterTitle == "Chapter 2")
        #expect(playbackManager.chapterNumber == 2)
    }

    @Test func seekSliderChanged() {
        let info = MediaPlaybackInfo(resourceIndex: 0, state: .playing, time: 0, duration: 100)
        playbackManager.playbackInfo = info

        playbackManager.seekSliderChanged(progress: 0.5)
        #expect(playbackManager.playbackInfo.duration == 100)
    }
}
