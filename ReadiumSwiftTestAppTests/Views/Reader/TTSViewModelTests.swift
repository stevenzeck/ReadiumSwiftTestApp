//
//  TTSViewModelTests.swift
//  ReadiumSwiftTestApp
//
//  Created by Steven Zeck on 2/5/26.
//

import Foundation
import ReadiumNavigator
import ReadiumShared
@testable import ReadiumSwiftTestApp
import Testing

@MainActor
class MockTTSService: TTSService {
    weak var delegate: TTSServiceDelegate?
    var config = PublicationSpeechSynthesizer.Configuration()
    var availableVoices: [TTSVoice] = []

    var startLocator: Locator?
    var startCalled = false
    var stopCalled = false
    var isPlaying = false

    func start(from locator: Locator?) {
        startCalled = true
        startLocator = locator
        isPlaying = true

        let safeLocator = locator ?? Locator(href: AnyURL(string: "chap1")!, mediaType: MediaType.html)
        let utterance = AppTTSUtterance(text: "Test", locator: safeLocator)
        delegate?.ttsService(self, stateDidChange: .playing(utterance, nil))
    }

    func pauseOrResume() {
        isPlaying.toggle()
        let locator = Locator(href: AnyURL(string: "chap1")!, mediaType: MediaType.html)
        let utterance = AppTTSUtterance(text: "Test", locator: locator)

        if isPlaying {
            delegate?.ttsService(self, stateDidChange: .playing(utterance, nil))
        } else {
            delegate?.ttsService(self, stateDidChange: .paused(utterance))
        }
    }

    func stop() {
        stopCalled = true
        isPlaying = false
        delegate?.ttsService(self, stateDidChange: .stopped)
    }

    func next() {}
    func previous() {}
}

@MainActor
class MockTTSServiceFactory: TTSServiceFactory {
    @MainActor let service = MockTTSService()

    @MainActor
    func makeService(publication _: Publication, delegate: TTSServiceDelegate) -> TTSService {
        service.delegate = delegate
        return service
    }
}

class MockNavigator: Navigator, DecorableNavigator {
    var currentLocation: Locator? = Locator(href: AnyURL(string: "chap1")!, mediaType: MediaType.html)
    var decorations: [String: [Decoration]] = [:]

    /// DecorableNavigator
    func apply(decorations: [Decoration], in group: String) {
        self.decorations[group] = decorations
    }

    func supports(decorationStyle _: Decoration.Style.Id) -> Bool {
        return true
    }

    func observeDecorationInteractions(inGroup _: String, onActivated _: @escaping OnActivatedCallback) {
        // No-op for tests
    }

    /// Navigator (Minimal stubs)
    var publication: Publication {
        fatalError("Not implemented")
    }

    var readingProgression: ReadiumShared.ReadingProgression = .ltr

    func go(to _: Locator, options _: NavigatorGoOptions) async -> Bool {
        return true
    }

    func go(to _: Link, options _: NavigatorGoOptions) async -> Bool {
        return true
    }

    func goForward(options _: NavigatorGoOptions) async -> Bool {
        return true
    }

    func goBackward(options _: NavigatorGoOptions) async -> Bool {
        return true
    }
}

@Suite(.serialized) @MainActor
struct TTSViewModelTests {
    let viewModel: TTSViewModel
    let mockFactory: MockTTSServiceFactory
    let mockNavigator: MockNavigator

    init() {
        let mockFactory = MockTTSServiceFactory()
        let mockNavigator = MockNavigator()
        self.mockFactory = mockFactory
        self.mockNavigator = mockNavigator
        viewModel = TTSViewModel(ttsFactory: mockFactory)
    }

    @Test func startStop() async {
        let metadata = Metadata(title: "Test Book")
        let manifest = Manifest(metadata: metadata)
        let publication = Publication(manifest: manifest)

        // Pass MockNavigator as Navigator
        viewModel.setup(navigator: mockNavigator, publication: publication)

        viewModel.start()

        #expect(mockFactory.service.startCalled)

        // Check ViewModel state
        var attempts = 0
        while !viewModel.isPlaying || !viewModel.showControls, attempts < 200 {
            try? await Task.sleep(nanoseconds: 10_000_000) // 10ms
            attempts += 1
        }
        #expect(viewModel.isPlaying)
        #expect(viewModel.showControls)

        viewModel.stop()

        #expect(mockFactory.service.stopCalled)

        attempts = 0
        while viewModel.isPlaying || viewModel.showControls, attempts < 200 {
            try? await Task.sleep(nanoseconds: 10_000_000) // 10ms
            attempts += 1
        }
        #expect(!viewModel.isPlaying)
        #expect(!viewModel.showControls)
    }

    @Test func playPause() async {
        let metadata = Metadata(title: "Test Book")
        let manifest = Manifest(metadata: metadata)
        let publication = Publication(manifest: manifest)

        viewModel.setup(navigator: mockNavigator, publication: publication)

        viewModel.start()

        var attempts = 0
        while !viewModel.isPlaying, attempts < 200 {
            try? await Task.sleep(nanoseconds: 10_000_000)
            attempts += 1
        }
        #expect(viewModel.isPlaying)

        viewModel.playPause()

        attempts = 0
        while viewModel.isPlaying, attempts < 200 {
            try? await Task.sleep(nanoseconds: 10_000_000)
            attempts += 1
        }
        #expect(!viewModel.isPlaying)

        viewModel.playPause()

        attempts = 0
        while !viewModel.isPlaying, attempts < 200 {
            try? await Task.sleep(nanoseconds: 10_000_000)
            attempts += 1
        }
        #expect(viewModel.isPlaying)
    }

    @Test func configurationUpdates() {
        let metadata = Metadata(title: "Config Book")
        let manifest = Manifest(metadata: metadata)
        let publication = Publication(manifest: manifest)

        viewModel.setup(navigator: mockNavigator, publication: publication)

        // Initial State
        #expect(mockFactory.service.config.defaultLanguage == nil)

        // Change Language
        let newLang = Language(code: .bcp47("fr"))
        viewModel.configLanguage = newLang

        // Verify service config updated
        #expect(mockFactory.service.config.defaultLanguage == newLang)

        // Change Voice
        let voice = TTSVoice(identifier: "com.test.voice", language: newLang, name: "Test Voice", gender: .female, quality: .high)
        viewModel.availableVoices = [voice]
        viewModel.configVoice = voice

        #expect(mockFactory.service.config.voiceIdentifier == "com.test.voice")
    }
}
