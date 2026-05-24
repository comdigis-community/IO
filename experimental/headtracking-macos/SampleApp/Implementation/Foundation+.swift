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
import Foundation
import CoreMotion
import simd
import QuartzCore

struct ListenerNativePose: Hashable, Sendable {
    let position: SIMD3<Double>
    let orientation: simd_quatd
}

struct ListenerNativeSnapshot: Hashable, Sendable {
    let pose: ListenerNativePose?
}

final class ListenerSensors {

    private let stateQueue = DispatchQueue(label: "com.comdigis.sampleapp.sensors.state")
    private let headphoneMotionManager = CMHeadphoneMotionManager()
    private var snapshotStorage = ListenerNativeSnapshot(pose: nil)
    private var lastPollTime: TimeInterval = 0

    func startHeadTracking() {
        if headphoneMotionManager.isDeviceMotionActive == false {
            headphoneMotionManager.startDeviceMotionUpdates()
        }
    }

    func poll() -> ListenerNativeSnapshot {
        let now = CACurrentMediaTime()
        if now - lastPollTime < 0.01 {
            return snapshot()
        }
        lastPollTime = now

        guard headphoneMotionManager.isDeviceMotionAvailable,
              let motion = headphoneMotionManager.deviceMotion else {
            stateQueue.sync {
                snapshotStorage = ListenerNativeSnapshot(pose: nil)
            }
            return snapshot()
        }

        let q = motion.attitude.quaternion
        let pose = ListenerNativePose(
            position: SIMD3<Double>(0, 0, 0),
            orientation: simd_quatd(ix: q.x, iy: q.y, iz: q.z, r: q.w).normalized
        )

        stateQueue.sync {
            snapshotStorage = ListenerNativeSnapshot(pose: pose)
        }

        return snapshot()
    }
    
    func stop() {
        headphoneMotionManager.stopDeviceMotionUpdates()
    }

    private func snapshot() -> ListenerNativeSnapshot {
        stateQueue.sync { snapshotStorage }
    }

}

extension URL {
    static func HRTF() -> URL {
        Bundle.main.resourceURL ?? { fatalError() }()
    }
    static func resource(named name: String) -> URL? {
        Bundle.main.url(forResource: name, withExtension: "mp3")
    }
}
