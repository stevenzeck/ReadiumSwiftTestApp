//
//  AudiobookViewModelTests.swift
//  ReadiumSwiftTestApp
//
//  Created by Steven Zeck on 7/2/26
//

@preconcurrency import ReadiumNavigator
import ReadiumShared
@testable import ReadiumSwiftTestApp
import SwiftData
import XCTest

@MainActor
final class AudiobookViewModelTests: XCTestCase {
    var viewModel: AudiobookViewModel!
    var mockContainer: ModelContext!

    override func setUp() async throws {
        try await super.setUp()
        let container = try TestHelper.makeInMemoryContainer()
        mockContainer = ModelContext(container)

        let metadata = Metadata(title: "Test Audiobook")
        let manifest = Manifest(metadata: metadata, readingOrder: [
            Link(href: "/chap1", title: "Chapter 1"),
            Link(href: "/chap2", title: "Chapter 2"),
        ])
        let publication = Publication(manifest: manifest)

        let book = Book(title: "Test Audiobook", format: "audiobook", filePath: "dummy")

        viewModel = AudiobookViewModel(publication: publication, book: book)
        viewModel.modelContext = mockContainer
    }

    override func tearDown() async throws {
        viewModel = nil
        mockContainer = nil
        try await super.tearDown()
    }

    func testInitialState() {
        XCTAssertEqual(viewModel.bookTitle, "Test Audiobook")
        XCTAssertEqual(viewModel.playbackInfo.state, .loading)
    }

    func testChapterTitle() {
        let info = MediaPlaybackInfo(resourceIndex: 0, state: .playing, time: 0, duration: 100)
        viewModel.playbackInfo = info
        XCTAssertEqual(viewModel.currentChapterTitle, "Chapter 1")
        XCTAssertEqual(viewModel.chapterNumber, 1)

        let info2 = MediaPlaybackInfo(resourceIndex: 1, state: .playing, time: 0, duration: 100)
        viewModel.playbackInfo = info2
        XCTAssertEqual(viewModel.currentChapterTitle, "Chapter 2")
        XCTAssertEqual(viewModel.chapterNumber, 2)
    }

    func testSeekSliderChanged() {
        let info = MediaPlaybackInfo(resourceIndex: 0, state: .playing, time: 0, duration: 100)
        viewModel.playbackInfo = info

        viewModel.seekSliderChanged(progress: 0.5)
        XCTAssertEqual(viewModel.playbackInfo.duration, 100)
    }
}
