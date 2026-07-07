//
//  AudiobookViewModelTests.swift
//  ReadiumSwiftTestApp
//
//  Created by Steven Zeck on 7/2/26
//

import Foundation
@preconcurrency import ReadiumNavigator
import ReadiumShared
@testable import ReadiumSwiftTestApp
import SwiftData
import Testing

@Suite(.serialized) @MainActor
struct AudiobookViewModelTests {
    let viewModel: AudiobookViewModel
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

        let viewModel = AudiobookViewModel(publication: publication, book: book)
        viewModel.modelContext = context
        self.viewModel = viewModel
    }

    @Test func initialState() {
        #expect(viewModel.bookTitle == "Test Audiobook")
        #expect(viewModel.playbackInfo.state == .loading)
    }

    @Test func chapterTitle() {
        let info = MediaPlaybackInfo(resourceIndex: 0, state: .playing, time: 0, duration: 100)
        viewModel.playbackInfo = info
        #expect(viewModel.currentChapterTitle == "Chapter 1")
        #expect(viewModel.chapterNumber == 1)

        let info2 = MediaPlaybackInfo(resourceIndex: 1, state: .playing, time: 0, duration: 100)
        viewModel.playbackInfo = info2
        #expect(viewModel.currentChapterTitle == "Chapter 2")
        #expect(viewModel.chapterNumber == 2)
    }

    @Test func seekSliderChanged() {
        let info = MediaPlaybackInfo(resourceIndex: 0, state: .playing, time: 0, duration: 100)
        viewModel.playbackInfo = info

        viewModel.seekSliderChanged(progress: 0.5)
        #expect(viewModel.playbackInfo.duration == 100)
    }
}
