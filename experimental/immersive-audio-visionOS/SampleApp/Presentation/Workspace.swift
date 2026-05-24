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
import RealityKit
import RealityKitContent
import AVFoundation
import ARKit
import QuartzCore

struct ImmersiveView: View {
    @Environment(AppModel.self) private var appModel
    @State private var videoSphere = ImmersiveVideoSphere.makePatagoniaSphere()
    @State private var arSession = ARKitSession()
    @State private var worldTracking = WorldTrackingProvider()

    var body: some View {
        RealityView { content in
            if let videoSphere {
                content.add(videoSphere.entity)
            }

            if let immersiveContentEntity = try? await Entity(named: "Immersive", in: realityKitContentBundle) {
                immersiveContentEntity.disableEntitiesForImmersiveVideoBackground()
                content.add(immersiveContentEntity)
            }
        }
        .onAppear {
            videoSphere?.play()
        }
        .onDisappear {
            videoSphere?.stop()
        }
        .task {
            await runWorldTrackingLoop()
        }
    }
}

#Preview(immersionStyle: .full) {
    ImmersiveView()
        .environment(AppModel())
}

private final class ImmersiveVideoSphere {

    private enum Layout {
        static let skyBiasAngle = -8.0 * Float.pi / 180.0
    }

    let entity: ModelEntity

    private let queuePlayer: AVQueuePlayer
    private let looper: AVPlayerLooper

    private init?(url: URL, sourceAspectRatio: Float) {
        let templateItem = AVPlayerItem(url: url)
        let queuePlayer = AVQueuePlayer()
        queuePlayer.isMuted = true
        queuePlayer.actionAtItemEnd = .none
        self.queuePlayer = queuePlayer
        looper = AVPlayerLooper(player: queuePlayer, templateItem: templateItem)

        let material = VideoMaterial(avPlayer: queuePlayer)
        let mesh = MeshResource.generateSphere(radius: 12.0)
        let entity = ModelEntity(mesh: mesh, materials: [material])
        entity.name = "ImmersiveVideoSphere"

        let expectedAspectRatio: Float = 2.0
        let verticalScale = min(1.0, sourceAspectRatio / expectedAspectRatio)
        entity.scale = SIMD3<Float>(x: -1.0, y: verticalScale, z: 1.0)
        entity.position = .zero
        entity.orientation = simd_quatf(angle: Layout.skyBiasAngle, axis: SIMD3<Float>(1.0, 0.0, 0.0))

        self.entity = entity
    }

    static func makePatagoniaSphere() -> ImmersiveVideoSphere? {
        guard let url = Bundle.main.url(forResource: "patagonia", withExtension: "mov") else {
            assertionFailure("Unable to load bundled video resource: patagonia.mov")
            return nil
        }

        return ImmersiveVideoSphere(url: url, sourceAspectRatio: 16.0 / 9.0)
    }

    func play() {
        queuePlayer.play()
    }

    func stop() {
        queuePlayer.pause()
        queuePlayer.seek(to: .zero)
    }
}

private extension ImmersiveView {
    @MainActor
    func runWorldTrackingLoop() async {
        guard WorldTrackingProvider.isSupported else {
            return
        }

        guard await startWorldTrackingSession() else {
            return
        }

        while !Task.isCancelled {
            if let pose = currentListenerPose() {
                appModel.binauralCoordinator?.update(
                    position: .zero,
                    forward: pose.forward,
                    up: pose.up,
                    timestamp: pose.timestamp
                )
            }

            try? await Task.sleep(for: .milliseconds(16))
        }
    }

    func startWorldTrackingSession() async -> Bool {
        do {
            try await arSession.run([worldTracking])
            return true
        } catch {
            return false
        }
    }

    func currentListenerPose() -> (forward: SIMD3<Float>, up: SIMD3<Float>, timestamp: TimeInterval)? {
        guard let anchor = worldTracking.queryDeviceAnchor(atTimestamp: CACurrentMediaTime()) else {
            return nil
        }

        let matrix = anchor.originFromAnchorTransform
        return (
            forward: matrix.forward3.normalized,
            up: matrix.up3.normalized,
            timestamp: ProcessInfo.processInfo.systemUptime
        )
    }
}

private extension Entity {

    func disableEntitiesForImmersiveVideoBackground() {
        let tokens = ["ground", "floor", "grid", "sky", "dome"]
        var stack: [Entity] = [self]

        while let current = stack.popLast() {
            let name = current.name.lowercased()
            if tokens.contains(where: { name.contains($0) }) {
                current.isEnabled = false
            }
            stack.append(contentsOf: current.children)
        }
    }
}
