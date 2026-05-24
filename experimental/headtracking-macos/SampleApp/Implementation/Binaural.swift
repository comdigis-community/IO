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

@MainActor
class BinauralCoordinator: ObservableObject, @unchecked Sendable {

    private static let channels: [ChannelConfiguration] = [
        .init(assetName: "stem_lead_mono", position: SIMD3<Float>(x: 0.0, y: 0.0, z: -15.0)),
        .init(assetName: "stem_chorus_mono", position: SIMD3<Float>(x: 0.0, y: 0.0, z: -15.0)),
        .init(assetName: "stem_reverb_mono_l", position: SIMD3<Float>(x: -25.0, y: 0.0, z: 15.0)),
        .init(assetName: "stem_reverb_mono_r", position: SIMD3<Float>(x: 25.0, y: 0.0, z: 15.0))
    ]

    private static let bedAssetName = "stem_bed_stereo"

    var context: AudioGraph

    private let bedSource: FileRenderer
    private let objectSources: [FileRenderer]
    private let objectConnectors: [AudioNode]

    @Published var isPlaying: Bool = false

    init(rendering: AudioGraph.Rendering) {
        // Build the graph through `Assembler` to keep coordinator code focused
        // on runtime behavior. The resulting root graph owns routing and destination output.
        let assembler = Assembler(rendering: rendering)
        context = assembler.createAudioGraph()

        // Build static channel layout once and keep source/processor pairs aligned by index.
        objectSources = Self.channels.map(Self.makeObjectSource(for:))
        objectConnectors = Self.channels.map { _ in IO.Binaural(database: BinauralComponent.database) }
        bedSource = FileRenderer(contentsOf: Self.resourceURL(named: Self.bedAssetName))

        #if DEBUG
        // Logs are restricted to control-level events only and is never used within real-time
        // (RT) processing paths, default level is `.none`. It is the responsibility of the client application
        // to configure the desired logging level explicitly before compiling a release build.
        // Logging should only be enabled for development/debug configurations.
        context.debug(level: .debug)
        #endif

        configureSpatialSettings()
        configureObjectConnectors()
        applyObjectSourcePositions()
        
        assertion(throwing: try connectAudioGraph())
    }

    @discardableResult func toggle(forceStop: Bool = false) -> Bool {
        isPlaying = forceStop ? false : !isPlaying

        if isPlaying {
            playAllSources()
        } else {
            stopAllSources()
        }

        return isPlaying
    }

    func updateListener(position: SIMD3<Float64>, forward: SIMD3<Float64>, up: SIMD3<Float64>) {
        context.listener.forward = .init(x: forward.x, y: forward.y, z: forward.z)
        context.listener.up = .init(x: up.x, y: up.y, z: up.z)
        context.listener.position = .init(x: position.x, y: position.y, z: position.z)
    }
}

private extension BinauralCoordinator {

    static func makeObjectSource(for configuration: ChannelConfiguration) -> FileRenderer {
        let source = FileRenderer(contentsOf: resourceURL(named: configuration.assetName))
        source.isLoopEnabled = true
        return source
    }

    static func resourceURL(named name: String) -> URL {
        URL.resource(named: name) ?? { fatalError("Missing audio resource: \(name).mp3") }()
    }

    func connectAudioGraph() throws {
        for (source, connector) in zip(objectSources, objectConnectors) {
            try context.connect(source: source, to: connector)
            try context.connect(source: connector, to: context.destination)
        }

        try context.connect(source: bedSource, to: context.destination)
    }

    func configureObjectConnectors() {
        for connector in objectConnectors {
            connector.retrieve(setting: .innerRadius)?.setValue(to: 5.0)
            connector.retrieve(setting: .outerRadius)?.setValue(to: 15.0)
            connector.retrieve(setting: .rollOff)?.setValue(to: 4.5)
            connector.retrieve(setting: .innerAngle)?.setValue(to: 40.0)
            connector.retrieve(setting: .outerAngle)?.setValue(to: 120.0)
            connector.retrieve(setting: .outerAngleGain)?.setValue(to: 0.2)
            connector.retrieve(setting: .distanceModel)?.setValue(to: 1.0)
        }
    }

    func applyObjectSourcePositions() {
        for (connector, configuration) in zip(objectConnectors, Self.channels) {
            connector.retrieve(parameter: .positionX)?.setValue(to: Float64(configuration.position.x))
            connector.retrieve(parameter: .positionY)?.setValue(to: Float64(configuration.position.y))
            connector.retrieve(parameter: .positionZ)?.setValue(to: Float64(configuration.position.z))
        }
    }

    func playAllSources() {
        bedSource.play(after: .zero, completion: nil)
        objectSources.forEach { $0.play(after: .zero, completion: nil) }
    }

    func stopAllSources() {
        bedSource.stop(after: .zero, reset: true)
        objectSources.forEach {
            $0.stop(after: .zero)
            $0.seek(to: .zero)
        }
    }

    func configureSpatialSettings() {
        context.listener.up = Vector3<Float64>(x: 0.0, y: 1.0, z: 0.0)
        context.listener.forward = Vector3<Float64>(x: 0.0, y: 0.0, z: -1.0)
        context.listener.position = Vector3<Float64>(x: 0.0, y: 0.0, z: 0.0)
        context.listener.velocity = Vector3<Float64>(x: 0.0, y: 0.0, z: 0.0)
        context.listener.doppler = 1.0
        context.listener.speedOfSound = 343.0
    }
}

private struct ChannelConfiguration {
    let assetName: String
    let position: SIMD3<Float>
}
