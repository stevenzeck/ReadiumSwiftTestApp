//
//  PreferencesStoreTests.swift
//  ReadiumSwiftTestApp
//
//  Created by Steven Zeck on 2/22/26.
//

import Foundation
import ReadiumNavigator
import ReadiumShared
@testable import ReadiumSwiftTestApp
import Testing

@Suite(.serialized) @MainActor
final class PreferencesStoreTests {
    let userDefaults: UserDefaults
    let store: PreferencesStore

    init() {
        let defaults = UserDefaults(suiteName: "PreferencesStoreTests")!
        defaults.removePersistentDomain(forName: "PreferencesStoreTests")
        userDefaults = defaults
        store = PreferencesStore(userDefaults: defaults)
    }

    deinit {
        UserDefaults(suiteName: "PreferencesStoreTests")?.removePersistentDomain(forName: "PreferencesStoreTests")
    }

    @Test func loadDefaults() {
        let prefs = store.load()
        #expect(prefs == EPUBPreferences())
    }

    @Test func saveAndLoad() {
        let prefs = EPUBPreferences()

        store.save(prefs)

        #expect(userDefaults.data(forKey: "EPUB_PREFERENCES") != nil)

        let loaded = store.load()
        #expect(loaded == prefs)
    }
}
