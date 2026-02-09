//
//  TTSViewModelTests.swift
//  ReadiumSwiftTestApp
//
//  Created by Steven Zeck on 2/5/26.
//

import ReadiumNavigator
import ReadiumShared
@testable import ReadiumSwiftTestApp
import XCTest

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
        let utterance = AppTTSUtterance(text: "Test", locator: SendableLocator(locator: safeLocator))
        delegate?.ttsService(self, stateDidChange: .playing(utterance, nil))
    }

    func pauseOrResume() {
        isPlaying.toggle()
        let locator = Locator(href: AnyURL(string: "chap1")!, mediaType: MediaType.html)
        let utterance = AppTTSUtterance(text: "Test", locator: SendableLocator(locator: locator))

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

    func go(to _: Locator, animated _: Bool, completion: @escaping () -> Void) -> Bool {
        completion()
        return true
    }

    func go(to _: Locator, animated _: Bool) async -> Bool {
        return true
    }

    func go(to _: Link, animated _: Bool, completion _: @escaping () -> Void) -> Bool {
        return true
    }

    func go(to _: Link, animated _: Bool) async -> Bool {
        return true
    }
}

@MainActor
final class TTSViewModelTests: XCTestCase {
    var viewModel: TTSViewModel!
    var mockFactory: MockTTSServiceFactory!
    var mockNavigator: MockNavigator!

    override func setUp() async throws {
        try await super.setUp()
        mockFactory = MockTTSServiceFactory()
        mockNavigator = MockNavigator()
        viewModel = TTSViewModel(ttsFactory: mockFactory)
    }

    override func tearDown() async throws {
        viewModel = nil
        mockFactory = nil
        mockNavigator = nil
        try await super.tearDown()
    }

    func testStartStop() throws {
        let metadata = Metadata(title: "Test Book")
        let manifest = Manifest(metadata: metadata)
        let publication = Publication(manifest: manifest)

        // Pass MockNavigator as Navigator
        try viewModel.setup(navigator: XCTUnwrap(mockNavigator), publication: publication)

        viewModel.start()

        XCTAssertTrue(mockFactory.service.startCalled)

        // Check ViewModel state
        let pred = NSPredicate { _, _ in
            self.viewModel.isPlaying && self.viewModel.showControls
        }
        let exp = XCTNSPredicateExpectation(predicate: pred, object: nil)
        wait(for: [exp], timeout: 2.0)

        viewModel.stop()

        XCTAssertTrue(mockFactory.service.stopCalled)

        let predStop = NSPredicate { _, _ in
            !self.viewModel.isPlaying && !self.viewModel.showControls
        }
        let expStop = XCTNSPredicateExpectation(predicate: predStop, object: nil)
        wait(for: [expStop], timeout: 2.0)
    }

    func testPlayPause() throws {
        let metadata = Metadata(title: "Test Book")
        let manifest = Manifest(metadata: metadata)
        let publication = Publication(manifest: manifest)

        try viewModel.setup(navigator: XCTUnwrap(mockNavigator), publication: publication)

        viewModel.start()

        let pred = NSPredicate { _, _ in self.viewModel.isPlaying }
        wait(for: [XCTNSPredicateExpectation(predicate: pred, object: nil)], timeout: 2.0)

        viewModel.playPause()

        let predPause = NSPredicate { _, _ in !self.viewModel.isPlaying }
        wait(for: [XCTNSPredicateExpectation(predicate: predPause, object: nil)], timeout: 2.0)

        viewModel.playPause()

        let predResume = NSPredicate { _, _ in self.viewModel.isPlaying }
        wait(for: [XCTNSPredicateExpectation(predicate: predResume, object: nil)], timeout: 2.0)
    }

    func testConfigurationUpdates() throws {
        let metadata = Metadata(title: "Config Book")
        let manifest = Manifest(metadata: metadata)
        let publication = Publication(manifest: manifest)

        try viewModel.setup(navigator: XCTUnwrap(mockNavigator), publication: publication)

        // Initial State
        XCTAssertNil(mockFactory.service.config.defaultLanguage)

        // Change Language
        let newLang = Language(code: .bcp47("fr"))
        viewModel.configLanguage = newLang

        // Verify service config updated
        XCTAssertEqual(mockFactory.service.config.defaultLanguage, newLang)

        // Change Voice
        let voice = TTSVoice(identifier: "com.test.voice", language: newLang, name: "Test Voice", gender: .female, quality: .high)
        viewModel.availableVoices = [voice]
        viewModel.configVoice = voice

        XCTAssertEqual(mockFactory.service.config.voiceIdentifier, "com.test.voice")
    }
}
