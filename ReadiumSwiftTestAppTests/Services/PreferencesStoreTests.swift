//
//  PreferencesStoreTests.swift
//  ReadiumSwiftTestApp
//
//  Created by Steven Zeck on 2/22/26.
//

import ReadiumNavigator
import ReadiumShared
@testable import ReadiumSwiftTestApp
import XCTest

@MainActor
final class PreferencesStoreTests: XCTestCase {
    var userDefaults: UserDefaults!
    var store: PreferencesStore!

    override func setUp() async throws {
        try await super.setUp()
        userDefaults = UserDefaults(suiteName: "PreferencesStoreTests")
        userDefaults.removePersistentDomain(forName: "PreferencesStoreTests")
        store = PreferencesStore(userDefaults: userDefaults)
    }

    override func tearDown() async throws {
        userDefaults.removePersistentDomain(forName: "PreferencesStoreTests")
        userDefaults = nil
        store = nil
        try await super.tearDown()
    }

    func testLoadDefaults() {
        let prefs = store.load()
        XCTAssertEqual(prefs, EPUBPreferences())
    }

    func testSaveAndLoad() {
        let prefs = EPUBPreferences()

        store.save(prefs)

        XCTAssertNotNil(userDefaults.data(forKey: "EPUB_PREFERENCES"))

        let loaded = store.load()
        XCTAssertEqual(loaded, prefs)
    }
}
