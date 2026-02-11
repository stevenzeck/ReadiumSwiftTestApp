//
//  ReadiumSwiftTestApp.swift
//  ReadiumSwiftTestApp
//
//  Created by Steven Zeck on 12/30/25.
//

import SwiftData
import SwiftUI

/// The main entry point of the Readium iOS Application.
@main
struct ReadiumSwiftTestApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    // MARK: - Services

    @State private var readium = ReadiumService()
    @State private var downloadService = DownloadService()

    // MARK: - Body

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(readium)
                .environment(downloadService)
                .onAppear {
                    downloadService.setupBackgroundHandler(appDelegate: appDelegate)
                }
        }
        .modelContainer(for: [Book.self, OPDSFeed.self, Bookmark.self, Highlight.self])
    }
}
