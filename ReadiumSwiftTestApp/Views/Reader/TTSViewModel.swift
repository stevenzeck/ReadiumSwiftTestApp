//
//  TTSViewModel.swift
//  ReadiumSwiftTestApp
//
//  Created by Steven Zeck on 12/30/25.
//

import Combine
import Foundation
import ReadiumNavigator
import ReadiumShared
import SwiftUI

/// ViewModel managing Text-To-Speech (TTS) functionality.
///
/// Handles playback controls, configuration (voice/language), and synchronization
/// with the navigator (highlighting the spoken text and auto-page turning).
@Observable
@MainActor
class TTSViewModel: TTSServiceDelegate {
    // MARK: - Published State

    /// Indicates whether the TTS is currently playing.
    var isPlaying: Bool = false

    /// Controls the visibility of the TTS playback overlay.
    var showControls: Bool = false

    // MARK: - Configuration

    /// The list of available voices from the synthesis engine.
    var availableVoices: [TTSVoice] = []

    /// The list of available languages derived from the voices.
    var availableLanguages: [Language] = []

    /// The currently selected language preference.
    var configLanguage: Language? {
        didSet {
            updateConfig()
        }
    }

    /// The currently selected voice preference.
    var configVoice: TTSVoice? {
        didSet {
            updateConfig()
        }
    }

    // MARK: - Private Properties

    private let ttsFactory: TTSServiceFactory
    private var service: TTSService?
    private var navigator: DecorableNavigator?
    private var publication: Publication?

    private let decorationGroup = "tts-highlight"

    init(ttsFactory: TTSServiceFactory? = nil) {
        self.ttsFactory = ttsFactory ?? DefaultTTSServiceFactory()
    }

    // MARK: - Setup

    /// Initializes the TTS engine with the current navigator and publication.
    ///
    /// - Parameters:
    ///   - navigator: The navigator instance to control (must conform to `DecorableNavigator` for highlighting).
    ///   - publication: The publication to read.
    func setup(navigator: Navigator, publication: Publication) {
        guard let decorable = navigator as? DecorableNavigator else { return }
        self.navigator = decorable
        self.publication = publication

        if service == nil {
            service = ttsFactory.makeService(publication: publication, delegate: self)
            loadSettings()
        }
    }

    private func loadSettings() {
        guard let service = service else { return }

        // Load voices
        availableVoices = service.availableVoices
        let languages = Set(availableVoices.map { $0.language })
        availableLanguages = Array(languages).sorted { $0.localizedDescription() < $1.localizedDescription() }

        // Load current config
        configLanguage = service.config.defaultLanguage

        // Voice is stored as identifier in config; map back to object
        if let voiceId = service.config.voiceIdentifier {
            configVoice = availableVoices.first { $0.identifier == voiceId }
        } else {
            configVoice = nil
        }
    }

    private func updateConfig() {
        guard var config = service?.config else { return }

        if config.defaultLanguage != configLanguage {
            config.defaultLanguage = configLanguage
        }

        if config.voiceIdentifier != configVoice?.identifier {
            config.voiceIdentifier = configVoice?.identifier
        }

        service?.config = config
    }

    // MARK: - Actions

    /// Starts playback from the current location.
    func start() {
        guard let service = service else { return }

        if let navigator = navigator as? Navigator, let currentLocation = navigator.currentLocation {
            service.start(from: currentLocation)
            showControls = true
            isPlaying = true
        } else {
            service.start(from: nil)
            showControls = true
            isPlaying = true
        }
    }

    /// Toggles between play and pause states.
    func playPause() {
        guard let service = service else { return }
        service.pauseOrResume()
    }

    /// Stops playback and hides controls.
    func stop() {
        service?.stop()
        showControls = false
    }

    /// Skips to the next utterance.
    func next() {
        service?.next()
    }

    /// Skips to the previous utterance.
    func previous() {
        service?.previous()
    }

    // MARK: - TTSServiceDelegate

    nonisolated func ttsService(_: TTSService, stateDidChange state: TTSState) {
        Task { @MainActor in
            self.handleStateChange(state)
        }
    }

    nonisolated func ttsService(_: TTSService, utterance _: AppTTSUtterance, didFailWithError error: PublicationSpeechSynthesizer.Error) {
        Task { @MainActor in
            print("TTS Error: \(error)")
            self.isPlaying = false
            self.showControls = false
        }
    }

    private func handleStateChange(_ state: TTSState) {
        var utteranceLocator: Locator? = nil

        switch state {
        case .stopped:
            isPlaying = false
            utteranceLocator = nil

        case let .paused(utterance):
            isPlaying = false
            utteranceLocator = utterance.locator.toReadiumLocator

        case let .playing(utterance, range):
            isPlaying = true
            utteranceLocator = utterance.locator.toReadiumLocator

            // Auto page turn logic
            if let nav = navigator as? Navigator {
                Task {
                    if let range = range {
                        await nav.go(to: range)
                    } else {
                        await nav.go(to: utterance.locator.toReadiumLocator)
                    }
                }
            }
        }

        // Apply visual highlighting decoration
        var decorations: [Decoration] = []
        if let locator = utteranceLocator {
            decorations.append(Decoration(
                id: "tts-current",
                locator: locator,
                style: Decoration.Style.highlight(tint: .red, isActive: true)
            ))
        }
        navigator?.apply(decorations: decorations, in: decorationGroup)
    }
}
