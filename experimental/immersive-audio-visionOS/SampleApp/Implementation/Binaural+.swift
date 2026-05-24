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
import AVFoundation

enum AudioSessionChange: Equatable {
    case routeChanged
    case interruptionBegan
    case interruptionEnded
}

protocol MediaObservationDelegate {
    func mediaObservation(_ observer: MediaObservation, didDetect change: AudioSessionChange)
}

class MediaObservation {
    
    var delegate: MediaObservationDelegate?
    
    private var routeChangedObserver: NSObjectProtocol?
    private var interruptionObserver: NSObjectProtocol?
    
    var options: AVAudioSession.CategoryOptions {
        // Route policy for showcase playback.
        // Supports wired output plus Bluetooth/AirPlay so device route switches
        // do not require different app logic per transport.
        return [.allowBluetoothHFP, .allowBluetoothA2DP, .allowAirPlay]
    }
    
    func configureAudioSession() {
        // Audio session is treated as a recoverable runtime dependency.
        // Reapplying category/mode/activation here allows the coordinator
        // to recover after route transitions and interruption boundaries.
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .default, options: options)
            try session.overrideOutputAudioPort(.none)
            try session.setActive(true)
            logCurrentRoute(session)
        } catch {
            logError(error)
        }
    }
    
    private func logCurrentRoute(_ s: AVAudioSession) {
        // Diagnostic-only route snapshot.
        // Kept for support/debug workflows; no behavior depends on this output.
        let ports = (s.currentRoute.outputs + s.currentRoute.inputs).map { $0.portType.rawValue }
        print("\(s.category), \(s.mode), [\(ports.joined(separator: ","))]")
    }
    
    private func logError(_ error: Error) {
        print("Unable to configure session: \(error)")
    }

}

extension MediaObservation {
    
    func beginObservingAudioSession() {
        beginObservingRouteChanges()
        beginObservingInterruption()
    }
    
    func beginObservingRouteChanges() {
        let center = NotificationCenter.default

        // Only forward route changes that affect effective output availability.
        // Non-relevant reasons are ignored to avoid unnecessary transport churn.
        let notification1 = AVAudioSession.routeChangeNotification
        routeChangedObserver = center.addObserver(
            forName: notification1, object: nil, queue: .main) { [weak self] notification in
                guard let self, let delegate = self.delegate else { return }
                guard let userInfo = notification.userInfo else { return }
                guard let raw = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt else { return }
                guard let reason = AVAudioSession.RouteChangeReason(rawValue: raw) else { return }
                
                switch reason {
                case .newDeviceAvailable, .oldDeviceUnavailable:
                    logCurrentRoute(AVAudioSession.sharedInstance())
                    delegate.mediaObservation(self, didDetect: .routeChanged)
                default:
                    break
                }
        }
    }
    
    func beginObservingInterruption() {
        let center = NotificationCenter.default
        
        // Interruption lifecycle is translated into coordinator transport actions:
        // `.began` pauses rendering, `.ended` reconfigures session then resumes path.
        let notification2 = AVAudioSession.interruptionNotification
        interruptionObserver = center.addObserver(
            forName: notification2, object: nil, queue: .main) { [weak self] notification in
                guard let self, let delegate = self.delegate else { return }
                guard let userInfo = notification.userInfo else { return }
                guard let raw = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt else { return }
                guard let type = AVAudioSession.InterruptionType(rawValue: raw) else { return }

                switch type {
                case .began:
                    delegate.mediaObservation(self, didDetect: .interruptionBegan)
                case .ended:
                    configureAudioSession()
                    delegate.mediaObservation(self, didDetect: .interruptionEnded)
                default:
                    break
                }
        }
    }

    func endObservingAudioSession() {
        let center = NotificationCenter.default

        if let routeChangedObserver {
            center.removeObserver(routeChangedObserver)
            self.routeChangedObserver = nil
        }

        if let interruptionObserver {
            center.removeObserver(interruptionObserver)
            self.interruptionObserver = nil
        }
    }
}
