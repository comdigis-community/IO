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

nonisolated final class BinauralCoordinator: Component, @unchecked Sendable {

    // Channel layout for the immersive mix.
    // Each entry maps one mono WAV stem to a fixed 3D emitter position.
    // Order matters because `sources` and `connectors` are kept index-aligned.
    private static let channels: [ChannelConfiguration] = [
        .init(assetName: "stem_guitars_mono_l", position: .init(x: -50.0, y: 0.0, z: -25.0)),
        .init(assetName: "stem_guitars_mono_r", position: .init(x: 50.0, y: 0.0, z: -25.0)),
        .init(assetName: "stem_lead_mono", position: .init(x: 0.0, y: 0.0, z: -10.0)),
        .init(assetName: "stem_reverb_mono_l", position: .init(x: -50.0, y: 0.0, z: 50.0)),
        .init(assetName: "stem_reverb_mono_r", position: .init(x: 50.0, y: 0.0, z: 50.0))
    ]

    private static let bedAssetName = "stem_bed_stereo"

    let context: AudioGraph
    
    private let bedSource: FileRenderer
    private let sources: [Renderer]
    private let observer = MediaObservation()
    private let connectors: [AudioNode]

    // Last listener snapshot.
    // Used to estimate physical velocity from pose deltas and frame delta time.
    // This keeps Doppler behavior stable while head tracking updates in real time.
    private var listenerState: ListenerState?

    init() throws {
        let assembler = Assembler(rendering: .live)
        context = assembler.createAudioGraph()

        // Build one source and one binaural processor per channel definition.
        // Arrays are intentionally parallel (same count/order) so routing and
        // position assignment can be done deterministically with `zip`.
        bedSource = FileRenderer(contentsOf: Self.resourceURL(named: Self.bedAssetName))
        bedSource.isLoopEnabled = true
        sources = Self.channels.map(Self.makeSource(for:))
        connectors = Self.channels.map { _ in IO.Binaural(database: BinauralDatabaseLoader.database) }

        super.init(annotation: .component)

        configureConnectors()
        applySourcePositions()
        configureListener()

        observer.delegate = self
        observer.beginObservingAudioSession()
        observer.configureAudioSession()

        #if DEBUG
        // Logs are restricted to control-level events only and is never used within real-time
        // (RT) processing paths, default level is `.none`. It is the responsibility of the client application
        // to configure the desired logging level explicitly before compiling a release build.
        // Logging should only be enabled for development/debug configurations.
        context.debug(level: .debug)
        #endif

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
    func update(position: SIMD3<Float>, forward: SIMD3<Float>, up: SIMD3<Float>, timestamp: TimeInterval) {
        // Position and orientation are authored by the tracking layer (ImmersiveView).
        // Coordinator only applies values to the audio graph, keeping responsibility
        // boundaries clear between tracking (input) and audio rendering (output).
        context.listener.position = position.vector3
        context.listener.forward = forward.vector3
        context.listener.up = up.vector3

        guard let previous = listenerState else {
            context.listener.velocity = .init(x: 0.0, y: 0.0, z: 0.0)
            listenerState = .init(position: position, timestamp: timestamp)
            return
        }

        // Velocity is derived from consecutive snapshots instead of reading sensor velocity.
        // This keeps the behavior deterministic across devices and update rates.
        let delta = max(timestamp - previous.timestamp, .leastNonzeroMagnitude)
        context.listener.velocity = ((position - previous.position) / Float(delta)).vector3
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
            connector.retrieve(parameter: .positionX)?.setValue(to: Float64(configuration.position.x))
            connector.retrieve(parameter: .positionY)?.setValue(to: Float64(configuration.position.y))
            connector.retrieve(parameter: .positionZ)?.setValue(to: Float64(configuration.position.z))
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
