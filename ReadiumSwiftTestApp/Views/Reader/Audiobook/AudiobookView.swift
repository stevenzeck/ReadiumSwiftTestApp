//
//  AudiobookView.swift
//  ReadiumSwiftTestApp
//
//  Created by Steven Zeck on 07/02/26
//

@preconcurrency import ReadiumNavigator
@preconcurrency import ReadiumShared
import SwiftData
import SwiftUI

struct AudiobookView: View {
    @Environment(AudioPlaybackManager.self) var viewModel
    @Environment(\.modelContext) private var modelContext
    @State private var showingPreferences = false

    let publication: Publication
    let book: Book

    var body: some View {
        VStack(spacing: 30) {
            Spacer()

            // Cover Art
            if let image = viewModel.coverImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 300)
                    .cornerRadius(12)
                    .shadow(radius: 10)
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: 300)
                    .cornerRadius(12)
                    .overlay(
                        Image(systemName: "music.note")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                    )
            }

            // Publication info
            VStack(spacing: 8) {
                Text(viewModel.bookTitle)
                    .font(.headline)
                    .multilineTextAlignment(.center)

                if let author = viewModel.authorName, !author.isEmpty {
                    Text(author)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }

                Text("Chapter \(viewModel.chapterNumber): \(viewModel.currentChapterTitle ?? "Unknown")")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, 4)
            }
            .padding(.horizontal)

            // Slider
            VStack(spacing: 4) {
                @Bindable var bViewModel = viewModel
                Slider(value: $bViewModel.seekProgress, in: 0 ... 1, onEditingChanged: { editing in
                    viewModel.isSeeking = editing
                    if !editing {
                        viewModel.seekSliderChanged(progress: viewModel.seekProgress)
                    }
                })
                .accentColor(.blue)

                HStack {
                    Text(formatTime(viewModel.playbackInfo.time))
                    Spacer()
                    Text(formatTime(viewModel.playbackInfo.duration ?? 0))
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
            .padding(.horizontal, 32)

            // Controls
            HStack(spacing: 40) {
                Button(action: {
                    viewModel.previousChapter()
                }) {
                    Image(systemName: "backward.end.fill")
                        .font(.title2)
                }
                .disabled(!viewModel.canGoBackward)
                .opacity(viewModel.canGoBackward ? 1.0 : 0.3)

                Button(action: {
                    viewModel.seekBackward()
                }) {
                    Image(systemName: "gobackward.30")
                        .font(.title)
                }

                Button(action: {
                    viewModel.togglePlayPause()
                }) {
                    Image(systemName: viewModel.playbackInfo.state == .playing ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 64))
                }

                Button(action: {
                    viewModel.seekForward()
                }) {
                    Image(systemName: "goforward.30")
                        .font(.title)
                }

                Button(action: {
                    viewModel.nextChapter()
                }) {
                    Image(systemName: "forward.end.fill")
                        .font(.title2)
                }
                .disabled(!viewModel.canGoForward)
                .opacity(viewModel.canGoForward ? 1.0 : 0.3)
            }
            .foregroundColor(.primary)

            Spacer()
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: {
                    showingPreferences = true
                }) {
                    Image(systemName: "gear")
                }
            }
        }
        .sheet(isPresented: $showingPreferences) {
            AudiobookPreferencesView(viewModel: viewModel)
        }
        .onAppear {
            viewModel.load(publication: publication, book: book, modelContext: modelContext)
        }
    }

    private func formatTime(_ time: Double) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = time >= 3600 ? [.hour, .minute, .second] : [.minute, .second]
        formatter.unitsStyle = .positional
        formatter.zeroFormattingBehavior = .pad
        return formatter.string(from: time) ?? "0:00"
    }
}
