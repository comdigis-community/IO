//
//  Copyright (c) 2019 - 2027 Comdigis, Argentina
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.

import SwiftUI
import AVFoundation
import AVKit
import UIKit

struct MusicLibraryView: View {
    private enum Layout {
        static let outerPadding = 20.0
        static let cornerRadius = 32.0
        static let miniPlayerMaxWidth = 760.0
    }

    private enum Song {
        static let title = "Shine On You Crazy Diamond"
        static let artist = "Pink Floyd"
        static let coverAssetName = "cover"
    }

    @Environment(AppModel.self) private var appModel
    @Environment(\.openImmersiveSpace) private var openImmersiveSpace
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace

    @State private var lyricsEnabled = false
    @State private var queueEnabled = false
    @State private var pinkVideo = WindowLoopingVideo.makePinkVideo()

    var body: some View {
        GeometryReader { geometry in
            backgroundArtwork(for: geometry)
        }
        .onAppear {
            updatePinkVideoPlayback()
        }
        .onChange(of: appModel.immersiveSpaceState) { _, _ in
            updatePinkVideoPlayback()
        }
        .ornament(
            visibility: .visible,
            attachmentAnchor: .scene(.bottom),
            contentAlignment: .center
        ) {
            MiniPlayerView(
                songTitle: Song.title,
                artistName: Song.artist,
                coverAssetName: Song.coverAssetName,
                immersiveState: appModel.immersiveSpaceState,
                lyricsEnabled: $lyricsEnabled,
                queueEnabled: $queueEnabled,
                onPlayPause: toggleImmersivePlayback
            )
            .frame(maxWidth: Layout.miniPlayerMaxWidth)
        }
    }

    @ViewBuilder
    private func backgroundArtwork(for geometry: GeometryProxy) -> some View {
        framedBackground(for: geometry) {
            if appModel.immersiveSpaceState == .open, let pinkVideo {
                PlayerLayerView(player: pinkVideo.player)
                    .allowsHitTesting(false)
            } else {
                Image("comdigis")
                    .resizable()
                    .scaledToFill()
            }
        }
    }

    private func framedBackground<Content: View>(
        for geometry: GeometryProxy,
        @ViewBuilder content: () -> Content
    ) -> some View {
        content()
            .frame(
                width: max(geometry.size.width - (Layout.outerPadding * 2.0), 0.0),
                height: max(geometry.size.height - (Layout.outerPadding * 2.0), 0.0)
            )
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: Layout.cornerRadius, style: .continuous))
            .padding(Layout.outerPadding)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func updatePinkVideoPlayback() {
        if appModel.immersiveSpaceState == .open {
            pinkVideo?.play()
        } else {
            pinkVideo?.stop()
        }
    }

    private func toggleImmersivePlayback() {
        Task { @MainActor in
            switch appModel.immersiveSpaceState {
            case .open:
                appModel.immersiveSpaceState = .inTransition
                await dismissImmersiveSpace()
            case .closed:
                appModel.immersiveSpaceState = .inTransition
                switch await openImmersiveSpace(id: appModel.immersiveSpaceID) {
                case .opened:
                    break
                case .userCancelled, .error:
                    fallthrough
                @unknown default:
                    appModel.immersiveSpaceState = .closed
                }
            case .inTransition:
                break
            }
        }
    }
}

private struct PlayerLayerView: UIViewRepresentable {
    let player: AVPlayer

    func makeUIView(context: Context) -> PlayerLayerContainerView {
        let view = PlayerLayerContainerView()
        view.playerLayer.videoGravity = .resizeAspectFill
        view.playerLayer.player = player
        return view
    }

    func updateUIView(_ uiView: PlayerLayerContainerView, context: Context) {
        uiView.playerLayer.player = player
    }
}

private final class PlayerLayerContainerView: UIView {
    override static var layerClass: AnyClass {
        AVPlayerLayer.self
    }

    var playerLayer: AVPlayerLayer {
        layer as! AVPlayerLayer
    }
}

private final class WindowLoopingVideo {

    let player: AVQueuePlayer

    private let looper: AVPlayerLooper

    private init?(url: URL) {
        let templateItem = AVPlayerItem(url: url)
        let player = AVQueuePlayer()
        player.isMuted = true
        player.actionAtItemEnd = .none
        self.player = player
        looper = AVPlayerLooper(player: player, templateItem: templateItem)
    }

    static func makePinkVideo() -> WindowLoopingVideo? {
        guard let url = Bundle.main.url(forResource: "pink_pompeii", withExtension: "mov") else {
            assertionFailure("Unable to load bundled video resource: pink_pompeii.mov")
            return nil
        }

        return WindowLoopingVideo(url: url)
    }

    func play() {
        player.play()
    }

    func stop() {
        player.pause()
        player.seek(to: .zero)
    }
}

private struct MiniPlayerView: View {
    let songTitle: String
    let artistName: String
    let coverAssetName: String
    let immersiveState: AppModel.ImmersiveSpaceState
    @Binding var lyricsEnabled: Bool
    @Binding var queueEnabled: Bool
    let onPlayPause: () -> Void

    private var transportEnabled: Bool {
        immersiveState != .inTransition
    }

    private var playPauseIconName: String {
        immersiveState == .open ? "pause.fill" : "play.fill"
    }

    var body: some View {
        HStack(spacing: 14.0) {
            songInfo
            Spacer()
            transportControls
            Spacer()
            utilityControls
        }
        .font(.body)
        .padding(.horizontal, 16.0)
        .padding(.vertical, 10.0)
        .glassBackgroundEffect(in: .capsule)
    }

    private var songInfo: some View {
        HStack(spacing: 10.0) {
            Image(coverAssetName)
                .resizable()
                .aspectRatio(1.0, contentMode: .fill)
                .frame(width: 46.0, height: 46.0)
                .clipShape(RoundedRectangle(cornerRadius: 8.0, style: .continuous))

            VStack(alignment: .leading, spacing: 0.0) {
                Text(songTitle)
                    .font(.headline.weight(.semibold))
                    .lineLimit(1)
                Text(artistName)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }

    private var transportControls: some View {
        HStack(spacing: 18.0) {
            TransportIconButton(systemImage: "backward.fill", font: .title3)

            Button(action: onPlayPause) {
                Image(systemName: playPauseIconName)
                    .font(.system(size: 17.0, weight: .semibold))
                    .frame(width: 36.0, height: 36.0)
                    .background(.regularMaterial.opacity(transportEnabled ? 1.0 : 0.5), in: Circle())
            }
            .disabled(!transportEnabled)
            .buttonStyle(.plain)

            TransportIconButton(systemImage: "forward.fill", font: .title3)
        }
    }

    private var utilityControls: some View {
        HStack(spacing: 8.0) {
            Toggle(isOn: $lyricsEnabled) {
                Image(systemName: "quote.bubble")
            }
            .toggleStyle(.button)

            Toggle(isOn: $queueEnabled) {
                Image(systemName: "list.bullet")
            }
            .toggleStyle(.button)

            TransportIconButton(systemImage: "airplayaudio", extraHorizontalPadding: 6.0)
        }
        .labelStyle(.iconOnly)
        .controlSize(.regular)
    }
}

private struct TransportIconButton: View {
    let systemImage: String
    var font: Font = .body
    var extraHorizontalPadding: Double = 0.0

    var body: some View {
        Button {} label: {
            Image(systemName: systemImage)
                .font(font)
                .padding(.horizontal, extraHorizontalPadding)
        }
        .disabled(true)
        .buttonStyle(.plain)
    }
}
