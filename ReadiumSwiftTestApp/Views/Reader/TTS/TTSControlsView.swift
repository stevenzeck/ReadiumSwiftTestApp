//
//  TTSControlsView.swift
//  ReadiumSwiftTestApp
//
//  Created by Steven Zeck on 2/10/26.
//

import SwiftUI

/// Overlay view for controlling Text-to-Speech playback.
struct TTSControlsView: View {
    var viewModel: TTSViewModel

    var body: some View {
        HStack(spacing: 30) {
            Button(action: { viewModel.previous() }) {
                Image(systemName: "backward.fill")
            }

            Button(action: { viewModel.playPause() }) {
                Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
                    .font(.title)
            }

            Button(action: { viewModel.stop() }) {
                Image(systemName: "stop.fill")
            }

            Button(action: { viewModel.next() }) {
                Image(systemName: "forward.fill")
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(12)
        .padding(.bottom, 20)
    }
}
