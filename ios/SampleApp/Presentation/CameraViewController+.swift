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

import UIKit
import RealityKit
import IO

extension CameraViewController {
    
    // Start playback with the selected demo source and align initial object
    // position with the visual placement distance used when creating the AR anchor.
    func play(with object: BinauralObject, distance: Float) throws {
        let coordinator = try BinauralCoordinator(contentsOf: object.url)
        coordinator.updateObjectPosition(.init(.zero, .zero, -distance * listenerScale))
        self.coordinator = coordinator
        coordinator.play(after: .zero)
    }
    
    // Push listener pose updates only when movement exceeds small thresholds.
    // This keeps spatial output responsive while reducing redundant audio parameter traffic.
    internal func update(timestamp: CFTimeInterval) {
        guard let coordinator else { return }

        let matrix = arView.cameraTransform.matrix
        let transform = arView.session.currentFrame?.camera.transform ?? matrix
        let position = transform.position3 * listenerScale
        let forward = transform.forward3.normalized
        let up = transform.up3.normalized

        guard shouldSendListener(position: position, forward: forward, up: up) else { return }

        objectAnchor.map { $0.position(relativeTo: nil) * listenerScale }.map(coordinator.updateObjectPosition)
        coordinator.update(position: position, forward: forward, up: up, timestamp: timestamp)
    }
    
}

struct ListenerUpdate {
    
    let worldMetersToAudioUnits: Float = 15.0
    let positionThreshold: Float = 0.05
    let orientationThreshold: Float = 0.0002
    let updateInterval: CFTimeInterval = 1.0 / 20.0

    private var lastUpdateTime: CFTimeInterval = 0
    private var lastSentPosition: SIMD3<Float>?
    private var lastSentForward: SIMD3<Float>?
    private var lastSentUp: SIMD3<Float>?

    // `shouldUpdate` applies time-based throttling, while `shouldSend` applies
    // movement/orientation thresholds and updates cached listener state on accepted samples.
    mutating func shouldUpdate(at timestamp: CFTimeInterval) -> Bool {
        guard (timestamp - lastUpdateTime) >= updateInterval else { return false }
        lastUpdateTime = timestamp
        return true
    }

    // Accept and forward only meaningful listener pose changes according to
    // position/orientation thresholds, then persist the accepted sample as baseline.
    mutating func shouldSend(position: SIMD3<Float>, forward: SIMD3<Float>, up: SIMD3<Float>) -> Bool {
        guard let lastPosition = lastSentPosition, let lastForward = lastSentForward, let lastUp = lastSentUp else {
            lastSentPosition = position
            lastSentForward = forward
            lastSentUp = up
            return true
        }
        let positionDelta = position.distance(to: lastPosition)
        let forwardDelta = forward.alignmentDelta(to: lastForward)
        let upDelta = up.alignmentDelta(to: lastUp)

        guard positionDelta >= positionThreshold || max(forwardDelta, upDelta) >= orientationThreshold else {
            return false
        }
        lastSentPosition = position
        lastSentForward = forward
        lastSentUp = up
        return true
    }
}
