//
//  ReadiumAppIntents.swift
//  ReadiumSwiftTestApp
//

import AppIntents
import Foundation

struct OpenBookIntent: OpenIntent {
    static let title: LocalizedStringResource = "Open Book"
    static let description = IntentDescription("Opens a book in the library.")

    @Parameter(title: "Book")
    var target: EbookEntity

    init() {}

    @MainActor
    func perform() async throws -> some IntentResult {
        NotificationCenter.default.post(name: .openBookIntentRun, object: target.id)
        return .result()
    }
}

struct PlayAudiobookIntent: OpenIntent {
    static let title: LocalizedStringResource = "Play Audiobook"
    static let description = IntentDescription("Plays an audiobook from your library.")
    static let openAppWhenRun: Bool = true

    @Parameter(title: "Audiobook")
    var target: AudiobookEntity

    init() {}

    @MainActor
    func perform() async throws -> some IntentResult {
        NotificationCenter.default.post(name: .openBookIntentRun, object: target.id)
        return .result()
    }
}

struct OpenOPDSFeedIntent: AppIntent {
    static let title: LocalizedStringResource = "Open OPDS Feed"
    static let description = IntentDescription("Opens an OPDS feed.")
    static let openAppWhenRun: Bool = true

    @Parameter(title: "Feed")
    var feed: OPDSFeedEntity

    init() {}

    @MainActor
    func perform() async throws -> some IntentResult {
        NotificationCenter.default.post(name: .openFeedIntentRun, object: feed.id)
        return .result()
    }
}
