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

import IO
import AppKit
@preconcurrency import AVFoundation
import QuartzCore
import SwiftUI

struct Workspace: View {
    @ObservedObject var controller: VideoController

    var body: some View {
        ZStack {
            PlayerSurface(player: controller.player)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black)

            AirPodsOverlay()

            if controller.isPreparingSelection {
                PreloaderOverlay()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
    }
}

private struct AirPodsOverlay: View {
    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "airpodsmax")
                .font(.system(size: 78, weight: .regular))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.white)

            Text("Connect your AirPods for the best experience")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 26)
        .padding(.vertical, 22)
        .background(Color.black.opacity(0.58))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .allowsHitTesting(false)
    }
}

private struct PreloaderOverlay: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.7)

            VStack(spacing: 10) {
                ProgressView()
                    .controlSize(.large)
                Text("Loading database...")
                    .font(.headline)
                Text("Preparing resources, please wait...")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 20)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .allowsHitTesting(true)
    }
}

private struct PlayerSurface: NSViewRepresentable {
    let player: AVPlayer

    func makeNSView(context: Context) -> PlayerContainerView {
        let view = PlayerContainerView()
        view.configure(with: player)
        return view
    }

    func updateNSView(_ nsView: PlayerContainerView, context: Context) {
        nsView.configure(with: player)
    }
}

private final class PlayerContainerView: NSView {
    private let playerLayer = AVPlayerLayer()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer = CALayer()
        layer?.backgroundColor = NSColor.black.cgColor

        playerLayer.videoGravity = .resize
        layer?.addSublayer(playerLayer)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layout() {
        super.layout()
        playerLayer.frame = bounds
    }

    func configure(with player: AVPlayer) {
        if playerLayer.player !== player {
            playerLayer.player = player
        }
    }
}
