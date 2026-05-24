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
import Foundation
import simd

struct ContentView: View {
    @State private var state = PlaybackState()
    @State private var headphoneTracking = HeadphoneTrackingProvider()
    @State private var coordinator: BinauralCoordinator?
    
    struct PlaybackState {
        var isDatabaseReady = false
        var isPlaying = false
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.surface.ignoresSafeArea()

            AirPodsPromptView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, 28.0)
                .offset(y: -44.0)

            FloatingPlaybackView(
                title: "Shine On You Crazy Diamond",
                artist: "Pink Floyd",
                coverAssetName: "cover",
                isPlaying: state.isPlaying,
                isEnabled: state.isDatabaseReady,
                onPlayPause: togglePlayback
            )
            .padding(.horizontal, 14.0)
            .padding(.bottom, 18.0)
        }
        .onAppear {
            preloadDatabaseIfNeeded()
            headphoneTracking.start()
        }
        .onDisappear {
            stopPlayback()
            headphoneTracking.stop()
        }
        .task {
            await runListenerUpdates()
        }
    }
}

extension ContentView {

    fileprivate func togglePlayback() {
        guard state.isDatabaseReady else { return }
        if state.isPlaying {
            return stopPlayback()
        }

        do {
            if coordinator == nil {
                coordinator = try BinauralCoordinator()
            }
            coordinator?.play()
            state.isPlaying = true
        } catch {
            state.isPlaying = false
        }
    }
    
    fileprivate func preloadDatabaseIfNeeded() {
        guard !state.isDatabaseReady else { return }
        BinauralDatabaseLoader.preload { result in
            Task { @MainActor in
                state.isDatabaseReady = {
                    if case .success(let loaded) = result {
                        return loaded
                    }
                    return false
                }()
            }
        }
    }

    @MainActor
    fileprivate func runListenerUpdates() async {
        while !Task.isCancelled {
            let orientation = headphoneTracking.currentOrientation()
            if state.isPlaying, let orientation {
                coordinator?.update(
                    position: .zero,
                    forward: orientation.forward,
                    up: orientation.up,
                    timestamp: ProcessInfo.processInfo.systemUptime
                )
            }

            try? await Task.sleep(for: .milliseconds(16))
        }
    }
    
    fileprivate func stopPlayback() {
        coordinator?.stop()
        state.isPlaying = false
    }

}

fileprivate extension Color {
    static let surface = Color(red: 25.0 / 255.0, green: 25.0 / 255.0, blue: 23.0 / 255.0)
}

#Preview {
    ContentView()
}
