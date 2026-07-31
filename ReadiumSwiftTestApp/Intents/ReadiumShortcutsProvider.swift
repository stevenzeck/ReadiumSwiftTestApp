//
//  ReadiumShortcutsProvider.swift
//  ReadiumSwiftTestApp
//

import AppIntents

struct ReadiumShortcutsProvider: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: OpenBookIntent(),
            phrases: [
                "Read \(.applicationName)",
                "Read \(\.$target) in \(.applicationName)",
                "Open \(\.$target) using \(.applicationName)",
            ],
            shortTitle: "Read Book",
            systemImageName: "book"
        )

        AppShortcut(
            intent: PlayAudiobookIntent(),
            phrases: [
                "Play \(\.$target) on \(.applicationName)",
                "Listen to \(\.$target) in \(.applicationName)",
            ],
            shortTitle: "Play Audiobook",
            systemImageName: "play.circle"
        )

        AppShortcut(
            intent: OpenOPDSFeedIntent(),
            phrases: [
                "Browse \(\.$feed) in \(.applicationName)",
            ],
            shortTitle: "Open Feed",
            systemImageName: "globe"
        )
    }
}
