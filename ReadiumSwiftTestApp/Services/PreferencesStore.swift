//
//  PreferencesStore.swift
//  ReadiumSwiftTestApp
//
//  Created by Steven Zeck on 2/10/26.
//

import Foundation
import ReadiumNavigator
import ReadiumShared

/// Manages the persistence of user reading preferences (Theme, Font Size, etc.).
class PreferencesStore {
    static let shared = PreferencesStore()
    private let key = "EPUB_PREFERENCES"

    private init() {}

    /// Loads the saved preferences or returns defaults.
    func load() -> EPUBPreferences {
        guard let data = UserDefaults.standard.data(forKey: key),
              let preferences = try? JSONDecoder().decode(EPUBPreferences.self, from: data)
        else {
            return EPUBPreferences()
        }
        return preferences
    }

    /// Saves the current preferences to disk.
    func save(_ preferences: EPUBPreferences) {
        if let data = try? JSONEncoder().encode(preferences) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}
