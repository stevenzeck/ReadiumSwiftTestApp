//
//  AudiobookPreferencesView.swift
//  ReadiumSwiftTestApp
//

@preconcurrency import ReadiumNavigator
@preconcurrency import ReadiumShared
import SwiftUI

struct AudiobookPreferencesView: View {
    @Bindable var viewModel: AudiobookViewModel
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Playback Speed")) {
                    Stepper(value: Binding(
                        get: { viewModel.currentPreferences.speed ?? 1.0 },
                        set: {
                            viewModel.currentPreferences.speed = $0
                            viewModel.applyPreferences()
                        }
                    ), in: 0.5 ... 2.5, step: 0.25) {
                        Text("Speed: \(String(format: "%.2fx", viewModel.currentPreferences.speed ?? 1.0))")
                    }
                }
            }
            .navigationTitle("Audio Preferences")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
}
