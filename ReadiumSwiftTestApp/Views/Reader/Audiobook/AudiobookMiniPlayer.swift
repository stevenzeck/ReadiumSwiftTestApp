//
//  AudiobookMiniPlayer.swift
//  ReadiumSwiftTestApp
//

import SwiftData
import SwiftUI

struct AudiobookMiniPlayer: View {
    @Environment(AudioPlaybackManager.self) var playbackManager
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        if playbackManager.book != nil {
            VStack {
                Spacer()

                HStack(spacing: 12) {
                    // Cover Art
                    if let image = playbackManager.coverImage {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 44, height: 44)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            .shadow(color: .black.opacity(0.1), radius: 3, x: 0, y: 1)
                    } else {
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                            .frame(width: 44, height: 44)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            .overlay(
                                Image(systemName: "music.note")
                                    .foregroundColor(.gray)
                            )
                    }

                    // Publication Info
                    VStack(alignment: .leading, spacing: 2) {
                        Text(playbackManager.bookTitle)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .lineLimit(1)
                            .foregroundColor(.primary)

                        Text(playbackManager.currentChapterTitle ?? "Playing")
                            .font(.caption)
                            .fontWeight(.medium)
                            .lineLimit(1)
                            .foregroundColor(.primary.opacity(0.8))
                    }

                    Spacer(minLength: 8)

                    // Controls
                    HStack(spacing: 16) {
                        if playbackManager.canGoBackward {
                            Button(action: { playbackManager.previousChapter() }) {
                                Image(systemName: "backward.fill")
                                    .font(.title3)
                                    .foregroundColor(.primary)
                            }
                            .frame(width: 32, height: 32)
                        } else {
                            Color.clear.frame(width: 32, height: 32)
                        }

                        Button(action: { playbackManager.togglePlayPause() }) {
                            Image(systemName: playbackManager.isPlaying ? "pause.fill" : "play.fill")
                                .font(.title2)
                                .foregroundColor(.primary)
                        }
                        .frame(width: 32, height: 32)

                        if playbackManager.canGoForward {
                            Button(action: { playbackManager.nextChapter() }) {
                                Image(systemName: "forward.fill")
                                    .font(.title3)
                                    .foregroundColor(.primary)
                            }
                            .frame(width: 32, height: 32)
                        } else {
                            Color.clear.frame(width: 32, height: 32)
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
                .shadow(color: .black.opacity(0.15), radius: 10, x: 0, y: 5)
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
                .onTapGesture {
                    playbackManager.presentedBookForMiniPlayer = playbackManager.book
                }
                .fullScreenCover(item: Bindable(playbackManager).presentedBookForMiniPlayer) { book in
                    NavigationStack {
                        ReaderLoaderView(book: book)
                            .toolbar {
                                ToolbarItem(placement: .navigationBarLeading) {
                                    Button {
                                        playbackManager.presentedBookForMiniPlayer = nil
                                    } label: {
                                        Image(systemName: "chevron.down")
                                            .fontWeight(.semibold)
                                            .foregroundColor(.primary)
                                    }
                                }
                            }
                    }
                }
            }
            .opacity(playbackManager.isReaderVisible ? 0 : 1)
        }
    }
}
