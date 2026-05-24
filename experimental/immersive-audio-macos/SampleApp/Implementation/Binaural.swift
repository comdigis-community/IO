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
final class BinauralCoordinator: ObservableObject, @unchecked Sendable {

    let context: AudioGraph
    
    private let source: Renderer
    private var listenerState: ListenerState?
    private var connector: AudioNode

    @Published var isPlaying: Bool = false
    @Published private(set) var sourceDistance: Float = 15.0

    init(rendering: AudioGraph.Rendering) {
        // Build the graph through `Assembler` to keep coordinator code focused
        // on runtime behavior. The resulting root graph owns routing and destination output.
        let assembler = Assembler(rendering: rendering)
        context = assembler.createAudioGraph()

        // Initialize source and active processing node together so playback starts in
        // a coherent state for the demo scene.
        source = FileRenderer(contentsOf: Self.mustLoadResource(named: "voiceover_interactive_en", ext: "mp3"))
        connector = IO.Binaural(database: Self.database)
        
        #if DEBUG
        // Logs are restricted to control-level events only and is never used within real-time
        // (RT) processing paths, default level is `.none`. It is the responsibility of the client application
        // to configure the desired logging level explicitly before compiling a release build.
        // Logging should only be enabled for development/debug configurations.
        context.debug(level: .debug)
        #endif

        configureSpatialSettings()

        // Build output routing in deterministic order for clarity.
        // Order: source -> active node -> destination.
        assertion(throwing: try context.connect(source: source, to: connector))
        assertion(throwing: try context.connect(source: connector, to: context.destination))

        placeSourceInFrontOfListener(distance: Float64(sourceDistance))
    }

    // Toggle transport state for the current source and return the resulting playback flag.
    @discardableResult
    func togglePlayback() -> Bool {
        isPlaying.toggle()
        isPlaying ? source.play(after: .zero) : source.stop(after: .zero)
        return isPlaying
    }

    // Apply scene listener transform to the audio graph and derive velocity from frame deltas.
    func updateListener(
        position: SIMD3<Float>,
        forward: SIMD3<Float>,
        up: SIMD3<Float>,
        timestamp: TimeInterval
    ) {
        context.listener.position = position.vector3
        context.listener.forward = forward.vector3
        context.listener.up = up.vector3

        guard let previous = listenerState else {
            context.listener.velocity = .init(x: 0.0, y: 0.0, z: 0.0)
            listenerState = .init(position: position, timestamp: timestamp)
            return
        }

        let delta = max(timestamp - previous.timestamp, .leastNonzeroMagnitude)
        context.listener.velocity = ((position - previous.position) / Float(delta)).vector3
        listenerState = .init(position: position, timestamp: timestamp)
    }

    var visualSourceZ: Float {
        -(sourceDistance / 14.0)
    }
}

private extension BinauralCoordinator {

    // Configure initial emitter coordinates relative to listener origin.
    func placeSourceInFrontOfListener(distance: Float64) {
        guard let x = connector.retrieve(parameter: .positionX),
              let y = connector.retrieve(parameter: .positionY),
              let z = connector.retrieve(parameter: .positionZ) else {
            return
        }

        x.setValue(to: 0.0)
        y.setValue(to: 0.0)
        z.setValue(to: -distance)
    }

    // Configure a neutral listener reference for deterministic spatial behavior.
    // Uses right-handed orientation (+Y up, -Z forward) and baseline physical defaults.
    func configureSpatialSettings() {
        context.listener.up = .init(x: 0.0, y: 1.0, z: 0.0)
        context.listener.forward = .init(x: 0.0, y: 0.0, z: -1.0)
        context.listener.position = .init(x: 0.0, y: 0.0, z: 0.0)
        context.listener.velocity = .init(x: 0.0, y: 0.0, z: 0.0)
        context.listener.doppler = 1.0
        context.listener.speedOfSound = 343.0
    }

    static let database: BinauralDatabase = {
        let database = BinauralDatabase(location: .HRTF())
        database.loadSynchronously()
        return database
    }()

    // Resolve the selected source into a bundled URL and fail fast if the asset is missing.
    static func mustLoadResource(named name: String, ext: String) -> URL {
        guard let url = Bundle.main.url(forResource: name, withExtension: ext) else {
            fatalError("Missing required bundled resource: \(name).\(ext)")
        }
        return url
    }
}
