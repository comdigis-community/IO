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
import SwiftUI

@MainActor
final class Orchestrator: ObservableObject {

    @Published var object: BinauralObject = .o1
    @Published var component = BinauralComponent(description: "Binaural")

    // Build and connect the component node into the coordinator graph, then push current
    // UI values to node controls. This keeps engine state synchronized with the selected component.
    func connect(coordinator: BinauralCoordinator) {
        let node = component.buildInternalGraphNode()
        assertion(throwing: try coordinator.connect(node: node))
        let connector = coordinator.connector
        
        component.settings.forEach {
            connector.retrieve(setting: $0.id)?.setValue(to: Float64($0.value))
        }
        component.parameters.forEach {
            connector.retrieve(parameter: $0.id)?.setValue(to: Float64($0.value))
        }
        
        object = coordinator.object
    }

    // Expose a `Binding` to `component` for SwiftUI editors that need read/write access.
    // This keeps view updates and state changes synchronized through a single source of truth.
    var binding: Binding<BinauralComponent> {
        Binding(
            get: { self.component },
            set: { self.component = $0 }
        )
    }
}

// Represents the demo audio sources available for demo.
// The selected case resolves to a localized WAV asset at runtime.
enum BinauralObject: String, Hashable {
    case o1 = "voiceover"
    
    var id: String { return rawValue }
    var description: String { "\(id)_\(Locale.languageCode)" }
}

// Resolves the selected source into a bundled URL and fails fast if the
// asset is missing. Uses `description` as the resource lookup key in the app bundle.
extension BinauralObject: CaseIterable, Identifiable {
    var url: URL { URL.resource(named: description) ?? { fatalError() }() }
}
