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
@preconcurrency import AVFoundation
import Foundation

@MainActor
final class VideoController: ObservableObject {
    @Published private(set) var isPlaying = false
    @Published private(set) var isReadyForPlayback = false
    var isPreparingSelection: Bool { isReadyForPlayback == false }

    let player = AVPlayer()

    private let runtime = BinauralCoordinator(rendering: .live)

    private var prepareTask: Task<Void, Never>?
    private var endTask: Task<Void, Never>?
    private let listenerSensors = ListenerSensors()
    private var listenerHeadTrackingTask: Task<Void, Never>?

    init() {
        configurePlayer()
        prepareRuntime()
        startHeadTracking()
    }

    func togglePlayback() {
        isPlaying ? pauseAndReset() : play()
    }
    
    deinit {
        prepareTask?.cancel()
        endTask?.cancel()
        listenerHeadTrackingTask?.cancel()
        listenerSensors.stop()
    }

}

extension VideoController {

    private func configurePlayer() {
        guard let url = Bundle.main.url(forResource: "pink_pompeii", withExtension: "mov") else {
            return
        }

        let item = AVPlayerItem(url: url)
        player.replaceCurrentItem(with: item)
        player.actionAtItemEnd = .pause
        player.isMuted = true

        endTask?.cancel()
        endTask = Task { [weak self] in
            for await _ in NotificationCenter.default.notifications(
                named: .AVPlayerItemDidPlayToEndTime,
                object: item
            ) {
                guard let self, Task.isCancelled == false else {
                    return
                }
                self.pauseAndReset()
            }
        }
    }

    private func prepareRuntime() {
        prepareTask?.cancel()
        prepareTask = Task(priority: .userInitiated) { [weak self] in
            guard let self else { return }
            _ = await Task.detached(priority: .userInitiated) {
                BinauralComponent.database
            }.value

            guard Task.isCancelled == false else { return }
            self.isReadyForPlayback = true
        }
    }

    private func startHeadTracking() {
        listenerSensors.startHeadTracking()
        guard listenerHeadTrackingTask == nil else { return }

        listenerHeadTrackingTask = Task { [weak self] in
            while Task.isCancelled == false {
                try? await Task.sleep(for: .milliseconds(16))
                guard let self, Task.isCancelled == false else { return }
                self.pollHeadTracking()
            }
        }
    }

    private func pollHeadTracking() {
        let snapshot = listenerSensors.poll()
        guard let pose = snapshot.pose else { return }

        let basePosition = SIMD3<Float>(0.0, 0.5, 0.0)
        let orientation = simd_quatf(
            ix: Float(pose.orientation.imag.x),
            iy: Float(pose.orientation.imag.z),
            iz: -Float(pose.orientation.imag.y),
            r: Float(pose.orientation.real)
        ).normalized

        let matrix = simd_float4x4(orientation)
        let forward = SIMD3<Float64>(
            Float64(-matrix.columns.2.x),
            Float64(-matrix.columns.2.y),
            Float64(-matrix.columns.2.z)
        )
        let up = SIMD3<Float64>(
            Float64(matrix.columns.1.x),
            Float64(matrix.columns.1.y),
            Float64(matrix.columns.1.z)
        )
        let position = SIMD3<Float64>(
            Float64(basePosition.x + Float(pose.position.x)),
            Float64(basePosition.y + Float(pose.position.y)),
            Float64(basePosition.z + Float(pose.position.z))
        )

        runtime.updateListener(position: position, forward: forward, up: up)
    }

    private func play() {
        guard isReadyForPlayback else { return }
        isPlaying = runtime.toggle(forceStop: false)
        
        player.play()
    }

    private func pauseAndReset() {
        player.pause()
        isPlaying = runtime.toggle(forceStop: true)

        player.seek(to: .zero, toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] _ in
            Task { @MainActor in
                self?.isPlaying = self?.runtime.isPlaying ?? false
            }
        }
    }
}
