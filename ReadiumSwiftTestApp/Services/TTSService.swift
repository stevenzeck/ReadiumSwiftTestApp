//
//  TTSService.swift
//  ReadiumSwiftTestApp
//
//  Created by Steven Zeck on 2/5/26.
//

import Foundation
@preconcurrency import ReadiumNavigator
@preconcurrency import ReadiumShared

/// A Sendable wrapper for TTS Utterances.
///
/// We use `SendableLocator` (DTO) to ensure strict concurrency safety.
struct AppTTSUtterance: Equatable {
    let text: String
    let locator: SendableLocator
}

protocol TTSServiceDelegate: AnyObject {
    func ttsService(_ service: TTSService, stateDidChange state: TTSState)
    func ttsService(_ service: TTSService, utterance: AppTTSUtterance, didFailWithError error: PublicationSpeechSynthesizer.Error)
}

/// Abstract state to decouple from PublicationSpeechSynthesizer.State
enum TTSState {
    case stopped
    case paused(AppTTSUtterance)
    case playing(AppTTSUtterance, Locator?)
}

protocol TTSService: AnyObject {
    var config: PublicationSpeechSynthesizer.Configuration { get set }
    var availableVoices: [TTSVoice] { get }

    func start(from locator: Locator?)
    func pauseOrResume()
    func stop()
    func next()
    func previous()
}

protocol TTSServiceFactory {
    func makeService(publication: Publication, delegate: TTSServiceDelegate) -> TTSService
}

class PublicationTTSService: TTSService, PublicationSpeechSynthesizerDelegate {
    private var synthesizer: PublicationSpeechSynthesizer?
    private weak var delegate: TTSServiceDelegate?

    init(publication: Publication, delegate: TTSServiceDelegate) {
        self.delegate = delegate
        synthesizer = PublicationSpeechSynthesizer(publication: publication, delegate: self)
    }

    var config: PublicationSpeechSynthesizer.Configuration {
        get { return synthesizer?.config ?? PublicationSpeechSynthesizer.Configuration(defaultLanguage: nil) }
        set { synthesizer?.config = newValue }
    }

    var availableVoices: [TTSVoice] {
        synthesizer?.availableVoices ?? []
    }

    func start(from locator: Locator?) {
        synthesizer?.start(from: locator)
    }

    func pauseOrResume() {
        synthesizer?.pauseOrResume()
    }

    func stop() {
        synthesizer?.stop()
    }

    func next() {
        synthesizer?.next()
    }

    func previous() {
        synthesizer?.previous()
    }

    /// Delegate forwarding
    func publicationSpeechSynthesizer(_: PublicationSpeechSynthesizer, stateDidChange state: PublicationSpeechSynthesizer.State) {
        let appState: TTSState
        switch state {
        case .stopped:
            appState = .stopped
        case let .paused(utterance):
            let locatorDTO = SendableLocator(locator: utterance.locator)
            appState = .paused(AppTTSUtterance(text: utterance.text, locator: locatorDTO))
        case let .playing(utterance, _):
            let locatorDTO = SendableLocator(locator: utterance.locator)
            appState = .playing(AppTTSUtterance(text: utterance.text, locator: locatorDTO), nil)
        }
        delegate?.ttsService(self, stateDidChange: appState)
    }

    func publicationSpeechSynthesizer(_: PublicationSpeechSynthesizer, utterance: PublicationSpeechSynthesizer.Utterance, didFailWithError error: PublicationSpeechSynthesizer.Error) {
        let locatorDTO = SendableLocator(locator: utterance.locator)
        delegate?.ttsService(self, utterance: AppTTSUtterance(text: utterance.text, locator: locatorDTO), didFailWithError: error)
    }
}

class DefaultTTSServiceFactory: TTSServiceFactory {
    func makeService(publication: Publication, delegate: TTSServiceDelegate) -> TTSService {
        return PublicationTTSService(publication: publication, delegate: delegate)
    }
}
