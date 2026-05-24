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

    private static let channels: [ChannelConfiguration] = [
        .init(assetName: "stem_guitars_mono_l", position: .init(x: -50.0, y: 0.0, z: -25.0)),
        .init(assetName: "stem_guitars_mono_r", position: .init(x: 50.0, y: 0.0, z: -25.0)),
        .init(assetName: "stem_lead_mono", position: .init(x: 0.0, y: 0.0, z: -10.0)),
        .init(assetName: "stem_reverb_mono_l", position: .init(x: -50.0, y: 0.0, z: 50.0)),
        .init(assetName: "stem_reverb_mono_r", position: .init(x: 50.0, y: 0.0, z: 50.0))
    ]

    private static let bedAssetName = "stem_bed_stereo"

    private let context: AudioGraph
    private let bedSource: FileRenderer
    private let sources: [Renderer]
    private let connectors: [AudioNode]
    private let observer = MediaObservation()

    private var listenerState: ListenerState?

    init() throws {
        // Build the graph through `Assembler` to keep coordinator code focused
        // on runtime behavior. The resulting root graph owns routing and destination output.
        let assembler = Assembler(rendering: .live)
        context = assembler.createAudioGraph()

        // Initialize sources and processing nodes together so every channel starts in a coherent
        // state. Each binaural node remains the insertion point before destination output.
        bedSource = FileRenderer(contentsOf: Self.resourceURL(named: Self.bedAssetName))
        bedSource.isLoopEnabled = true
        sources = Self.channels.map { configuration in
            Self.makeSource(for: configuration)
        }
        connectors = Self.channels.map { _ in IO.Binaural(database: BinauralDatabaseLoader.database) }

        super.init(annotation: .component)

        configureConnectors()
        applySourcePositions()
        configureListener()

        observer.delegate = self
        observer.beginObservingAudioSession()
        observer.configureAudioSession()

        #if DEBUG
        // Logs are restricted to control-level events only and are never used within real-time
        // (RT) processing paths, default level is `.none`. It is the responsibility of the client
        // application to configure the desired logging level explicitly before compiling a release build.
        // Logging should only be enabled for development/debug configurations.
        context.debug(level: .none)
        #endif

        // Build output routing in deterministic order for clarity and safe processor replacement.
        // Per channel order: source -> active node -> destination.
        try connectAudioGraph()
    }

    func play(after timeInterval: TimeInterval = .zero) {
        observer.configureAudioSession()
        bedSource.play(after: timeInterval, completion: nil)
        sources.forEach { $0.play(after: timeInterval, completion: nil) }
    }

    func stop(after timeInterval: TimeInterval = .zero) {
        bedSource.stop(after: timeInterval)
        bedSource.seek(to: .zero)
        sources.forEach {
            $0.stop(after: timeInterval)
            $0.seek(to: .zero)
        }
    }

    deinit {
        observer.endObservingAudioSession()
    }

}

extension BinauralCoordinator: MediaObservationDelegate {
    func mediaObservation(_ observer: MediaObservation, didDetect change: AudioSessionChange) {
        switch change {
        case .routeChanged, .interruptionEnded:
            play()
        case .interruptionBegan:
            stop()
        }
    }
}

extension BinauralCoordinator {
    // Apply source-space position updates directly to the active binaural node controls.
    // Coordinates are expected in audio units and map one-to-one with channel placement intent.
    func updateSourcePosition(_ position: SIMD3<Float>, for connector: AudioNode) {
        connector.retrieve(parameter: .positionX)?.setValue(to: Float64(position.x))
        connector.retrieve(parameter: .positionY)?.setValue(to: Float64(position.y))
        connector.retrieve(parameter: .positionZ)?.setValue(to: Float64(position.z))
    }

    // Apply listener transform and derive velocity from timestamped position
    // deltas. The first update seeds state with zero velocity to avoid startup spikes.
    func update(position: SIMD3<Float>, forward: SIMD3<Float>, up: SIMD3<Float>, timestamp: TimeInterval) {
        context.listener.position = .init(x: Float64(position.x), y: Float64(position.y), z: Float64(position.z))
        context.listener.forward = .init(x: Float64(forward.x), y: Float64(forward.y), z: Float64(forward.z))
        context.listener.up = .init(x: Float64(up.x), y: Float64(up.y), z: Float64(up.z))

        guard let previous = listenerState else {
            context.listener.velocity = .init(x: 0.0, y: 0.0, z: 0.0)
            listenerState = .init(position: position, timestamp: timestamp)
            return
        }

        let delta = max(timestamp - previous.timestamp, .leastNonzeroMagnitude)
        let velocity = (position - previous.position) / Float(delta)

        context.listener.velocity = .init(x: Float64(velocity.x), y: Float64(velocity.y), z: Float64(velocity.z))
        listenerState = .init(position: position, timestamp: timestamp)
    }
}

private extension BinauralCoordinator {
    static func makeSource(for configuration: ChannelConfiguration) -> Renderer {
        let source = FileRenderer(contentsOf: resourceURL(named: configuration.assetName))
        source.isLoopEnabled = true
        return source
    }

    func connectAudioGraph() throws {
        for (source, connector) in zip(sources, connectors) {
            try context.connect(source: source, to: connector)
            try context.connect(source: connector, to: context.destination)
        }

        try context.connect(source: bedSource, to: context.destination)
    }

    func applySourcePositions() {
        for (connector, configuration) in zip(connectors, Self.channels) {
            updateSourcePosition(configuration.position, for: connector)
        }
    }

    func configureConnectors() {
        for connector in connectors {
            connector.retrieve(setting: .innerRadius)?.setValue(to: 5.0)
            connector.retrieve(setting: .outerRadius)?.setValue(to: 15.0)
            connector.retrieve(setting: .rollOff)?.setValue(to: 4.5)
            connector.retrieve(setting: .innerAngle)?.setValue(to: 40.0)
            connector.retrieve(setting: .outerAngle)?.setValue(to: 120.0)
            connector.retrieve(setting: .outerAngleGain)?.setValue(to: 0.2)
            connector.retrieve(setting: .distanceModel)?.setValue(to: 1.0)
        }
    }

    func configureListener() {
        // Configure a neutral listener reference for deterministic spatial behavior.
        // Uses right-handed orientation (+Y up, -Z forward) and baseline physical defaults.
        context.listener.up = .init(x: 0.0, y: 1.0, z: 0.0)
        context.listener.forward = .init(x: 0.0, y: 0.0, z: -1.0)
        context.listener.position = .init(x: 0.0, y: 0.0, z: 0.0)
        context.listener.velocity = .init(x: 0.0, y: 0.0, z: 0.0)
        context.listener.doppler = 1.0
        context.listener.speedOfSound = 343.0
    }

    static func resourceURL(named name: String) -> URL {
        URL.resource(named: name) ?? { fatalError("Missing audio resource: \(name).mp3") }()
    }

}
