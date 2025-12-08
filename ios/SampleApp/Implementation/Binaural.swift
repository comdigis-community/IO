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
import simd

final class BinauralCoordinator: Component, @unchecked Sendable {

    private let source: Renderer
    private let connector: AudioNode
    private let context: AudioGraph
    
    private var lastListenerPosition: SIMD3<Float> = .zero
    private var lastListenerTimestamp: TimeInterval = .zero
    private var hasListenerState = false
    
    private let observer = MediaObservation()

    init(contentsOf url: URL) throws {
        // Build the graph through `Assembler` to keep coordinator code focused
        // on runtime behavior. The resulting root graph owns routing and destination output.
        let assembler = Assembler(rendering: .live)
        context = assembler.createAudioGraph()

        // Initialize source and processing node together so the chain starts in a coherent
        // state. The binaural node remains the single insertion point before destination output.
        let source = FileRenderer(contentsOf: url)
        source.isLoopEnabled = true
        self.source = source

        connector = IO.Binaural(database: BinauralDatabaseLoader.database)
        super.init(annotation: .component)
        
        configureSpatialSettings()
        
        observer.delegate = self
        observer.configureAudioSession()
        observer.beginObservingAudioSession()
        
        #if DEBUG
        // Restrict logs to control-plane events and keep them out of real-time
        // processing paths. Default is `.none`; enable explicitly only for development builds.
        context.debug(level: .debug)
        #endif

        // Build output routing in deterministic order for clarity and safe processor replacement.
        // Order: source -> active node -> destination.
        try context.connect(source: source, to: connector)
        try context.connect(source: connector, to: context.destination)

        observer.configureAudioSession()
    }

    func play(after timeInterval: TimeInterval = .zero) {
        observer.configureAudioSession()
        source.play(after: timeInterval, completion: nil)
    }

    func stop(after timeInterval: TimeInterval = .zero) {
        source.stop(after: timeInterval)
    }
    
    deinit {
        observer.endObservingAudioSession()
    }
}

extension BinauralCoordinator: MediaObservationDelegate {
    func onRouteChanged(_ change: Notification) {
        switch change {
        case .changed:
            play(after: .zero)
        case .interruptionBegan:
            stop(after: .zero)
        case .interruptionEnded:
            play(after: .zero)
        }
    }
}

extension BinauralCoordinator {
    // Apply object-space position updates directly to the active binaural node
    // controls. Coordinates are expected in audio units to match listener and world conversion.
    func updateObjectPosition(_ position: SIMD3<Float>) {
        connector.retrieve(parameter: .positionX)?.setValue(to: Float64(position.x))
        connector.retrieve(parameter: .positionY)?.setValue(to: Float64(position.y))
        connector.retrieve(parameter: .positionZ)?.setValue(to: Float64(position.z))
    }

    // Apply listener transform and derive velocity from timestamped position
    // deltas. The first update seeds state with zero velocity to avoid startup spikes.
    func update(position: SIMD3<Float>, forward: SIMD3<Float>, up: SIMD3<Float>, timestamp: TimeInterval) {
        context.listener.position = position.vector3
        context.listener.forward = forward.vector3
        context.listener.up = up.vector3

        guard hasListenerState else {
            context.listener.velocity = .init(x: 0.0, y: 0.0, z: 0.0)
            lastListenerPosition = position
            lastListenerTimestamp = timestamp
            hasListenerState = true
            return
        }

        let delta = max(timestamp - lastListenerTimestamp, .leastNonzeroMagnitude)
        let velocity = (position - lastListenerPosition) / Float(delta)

        context.listener.velocity = velocity.vector3
        lastListenerPosition = position
        lastListenerTimestamp = timestamp
    }
}

private extension BinauralCoordinator {
    // Configure a neutral listener reference for deterministic spatial behavior.
    // Uses right-handed orientation (+Y up, -Z forward) and baseline physical defaults.
    func configureSpatialSettings() {
        connector.retrieve(setting: .innerRadius)?.setValue(to: 5.0)
        connector.retrieve(setting: .outerRadius)?.setValue(to: 15.0)
        connector.retrieve(setting: .rollOff)?.setValue(to: 4.5)
        connector.retrieve(setting: .innerAngle)?.setValue(to: 40.0)
        connector.retrieve(setting: .outerAngle)?.setValue(to: 120.0)
        connector.retrieve(setting: .outerAngleGain)?.setValue(to: 0.2)
        connector.retrieve(setting: .distanceModel)?.setValue(to: 1.0)
        
        context.listener.up = .init(x: 0.0, y: 1.0, z: 0.0)
        context.listener.forward = .init(x: 0.0, y: 0.0, z: -1.0)
        context.listener.position = .init(x: 0.0, y: 0.0, z: 0.0)
        context.listener.velocity = .init(x: 0.0, y: 0.0, z: 0.0)
        context.listener.doppler = 1.0
        context.listener.speedOfSound = 343.0
    }
}

// Represents the demo audio sources available for demo.
// The selected case resolves to a localized WAV asset at runtime.
enum BinauralObject: String, CaseIterable {
    case o1 = "voiceover"
    
    var id: String { return rawValue }
    var description: String {  "\(id)_\(Locale.languageCode)" }
}

// Resolves the selected source into a bundled URL and fails fast if the
// asset is missing. Uses `description` as the resource lookup key in the app bundle.
extension BinauralObject: Identifiable, Hashable {
    var url: URL { URL.resource(named: description) ?? { fatalError() }() }
}
