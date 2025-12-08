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

@MainActor
class BinauralCoordinator: ObservableObject, @unchecked Sendable {
    
    var source: Renderer
    var connector: AudioNode
    var context: AudioGraph
    var intermediate: Gain
    
    @Published var isPlaying: Bool = false
    @Published var object: BinauralObject = .o1
    @Published var reset: Bool = false
    
    init(rendering: AudioGraph.Rendering, object: BinauralObject = .o1) {
        // Build the graph through `Assembler` to keep coordinator code focused
        // on runtime behavior. The resulting root graph owns routing and destination output.
        let assembler = Assembler(rendering: rendering)
        context = assembler.createAudioGraph()
        
        // Initialize endpoints and source together so the chain starts in a coherent
        // state. Two gain stages keep insertion points stable when swapping processing nodes.
        self.connector = Gain(defaultGain: 1.0)
        self.source = FileRenderer(contentsOf: object.url)
        self.intermediate = Gain(defaultGain: 1.0)
        self.object = object
        
        #if DEBUG
        // Restrict logs to control-plane events and keep them out of real-time
        // processing paths. Default is `.none`; enable explicitly only for development builds.
        context.debug(level: .debug)
        #endif
        
        configureSpatialSettings()
        
        // Build output routing in deterministic order for clarity and safe processor replacement.
        // Order: source -> intermediate -> active node -> destination.
        assertion(throwing: try context.connect(source: source, to: intermediate))
        assertion(throwing: try context.connect(source: intermediate, to: connector))
        assertion(throwing: try context.connect(source: connector, to: context.destination))
    }

    // Rewire only the final segment to replace the active processing node.
    // Existing links are removed first; routing remains intermediate -> connector -> destination.
    func connect(node: AudioNode) throws {
        try context.disconnect(source: intermediate, from: connector)
        try context.disconnect(source: connector, from: context.destination)
        
        connector = node
        
        try context.connect(source: intermediate, to: connector)
        try context.connect(source: connector, to: context.destination)
    }
    
    // Toggle transport state for the current source and return the resulting playback flag.
    // `forceStop` bypasses toggling semantics and guarantees a stopped state.
    @discardableResult func toggle(forceStop: Bool = false) -> Bool {
        isPlaying = forceStop ? false : !isPlaying
        isPlaying ? source.play(after: .zero) : source.stop(after: .zero)
        reset.toggle()
        return isPlaying
    }
    
}

extension BinauralCoordinator {
    
    // Apply a setting control change to the currently connected processing node.
    // A failed lookup is treated as a precondition mismatch in component wiring.
    func apply(setting change: Control) {
        guard let setting = connector.retrieve(setting: change.id) else {
            return assertion(false, message: "Unexpected precondition failure: Condition mismatch")
        }
        setting.setValue(to: Float64(change.value))
    }
    
    // Apply a parameter control change to the currently connected processing node.
    // A failed lookup is treated as a precondition mismatch in component wiring.
    func apply(parameter change: Control) {
        guard let parameter = connector.retrieve(parameter: change.id) else {
            return assertion(false, message: "Unexpected precondition failure: Condition mismatch")
        }
        parameter.setValue(to: Float64(change.value))
    }
}

private extension BinauralCoordinator {
    
    // Configure a neutral listener reference for deterministic spatial behavior.
    // Uses right-handed orientation (+Y up, -Z forward) and baseline physical defaults.
    func configureSpatialSettings() {
        context.listener.up = Vector3<Float64>(x: 0.0, y: 1.0, z: 0.0)
        context.listener.forward = Vector3<Float64>(x: 0.0, y: 0.0, z: -1.0)
        context.listener.position = Vector3<Float64>(x: 0.0, y: 0.0, z: 0.0)
        context.listener.velocity = Vector3<Float64>(x: 0.0, y: 0.0, z: 0.0)
        context.listener.doppler = 1.0
        context.listener.speedOfSound = 343.0
    }
}
