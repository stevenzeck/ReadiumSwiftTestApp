//
//  SimplePreferencesView.swift
//  ReadiumSwiftTestApp
//
//  Created by Steven Zeck on 12/30/25.
//

import ReadiumNavigator
import ReadiumShared
import SwiftUI

/// A view allowing users to customize reading preferences.
///
/// Supports changing appearance (theme), layout (scroll/paginated), text size,
/// and Text-to-Speech configuration.
struct SimplePreferencesView: View {
    // MARK: - Properties

    /// The navigator instance to which preferences are applied.
    let navigator: EPUBNavigatorViewController

    /// Binding to the current set of preferences.
    @Binding var currentPreferences: EPUBPreferences

    /// ViewModel managing TTS state and configuration.
    var ttsViewModel: TTSViewModel

    // MARK: - Environment

    @Environment(\.dismiss) var dismiss

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Appearance")) {
                    Picker("Theme", selection: Binding(
                        get: { currentPreferences.theme ?? .light },
                        set: {
                            currentPreferences.theme = $0
                            applyPreferences()
                        }
                    )) {
                        Text("Light").tag(Theme.light)
                        Text("Dark").tag(Theme.dark)
                        Text("Sepia").tag(Theme.sepia)
                    }
                    .pickerStyle(.segmented)
                }

                Section(header: Text("Layout")) {
                    Toggle("Scroll", isOn: Binding(
                        get: { currentPreferences.scroll ?? false },
                        set: {
                            currentPreferences.scroll = $0
                            applyPreferences()
                        }
                    ))
                }

                Section(header: Text("Text")) {
                    Stepper(value: Binding(
                        get: { currentPreferences.fontSize ?? 1.0 },
                        set: {
                            currentPreferences.fontSize = $0
                            applyPreferences()
                        }
                    ), in: 0.5 ... 3.0, step: 0.1) {
                        Text("Font Size: \(Int((currentPreferences.fontSize ?? 1.0) * 100))%")
                    }
                }

                Section(header: Text("Text to Speech")) {
                    Picker("Language", selection: Bindable(ttsViewModel).configLanguage) {
                        Text("Default").tag(Language?.none)
                        ForEach(ttsViewModel.availableLanguages, id: \.self) { language in
                            Text(language.localizedDescription()).tag(Language?.some(language))
                        }
                    }

                    Picker("Voice", selection: Bindable(ttsViewModel).configVoice) {
                        Text("Default").tag(TTSVoice?.none)
                        ForEach(filteredVoices, id: \.identifier) { voice in
                            Text(voice.name).tag(TTSVoice?.some(voice))
                        }
                    }
                }
            }
            .navigationTitle("Preferences")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }

    // MARK: - Helpers

    /// Filters available voices based on the selected language.
    private var filteredVoices: [TTSVoice] {
        if let language = ttsViewModel.configLanguage {
            return ttsViewModel.availableVoices.filter { $0.language.code == language.code }
        } else {
            return ttsViewModel.availableVoices
        }
    }

    /// Submits the current preferences to the navigator.
    private func applyPreferences() {
        navigator.submitPreferences(currentPreferences)
    }
}
