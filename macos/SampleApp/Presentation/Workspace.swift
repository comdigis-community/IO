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

struct Workspace: View {

    @Binding var container: BinauralComponent
    @EnvironmentObject var coordinator: BinauralCoordinator

    var body: some View {
        HStack(alignment: .top, spacing: .zero) {
            ImmersiveWorkspace(
                reset: $coordinator.reset,
                layout: ImmersiveSpace.resolve(from: container)
            )
                .frame(width: 900)

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Parameters")
                        .font(.headline)

                    // Render one slider per exposed parameter in the current component model.
                    // Propagate each value change to the active engine node through `apply(parameter:)`.
                    ForEach(container.parameters.indices, id: \.self) { index in
                        CompatibleSlider(item: $container.parameters[index])
                            .onChange(of: container.parameters[index].value) { _, _ in
                                apply(parameter: container.parameters[index])
                            }
                    }

                    Text("Settings")
                        .font(.headline)

                    // Render one slider per exposed setting in the current component model.
                    // Propagate each value change to the active engine node through `apply(setting:)`.
                    ForEach(container.settings.indices, id: \.self) { index in
                        CompatibleSlider(item: $container.settings[index])
                            .onChange(of: container.settings[index].value) { _, _ in
                                apply(setting: container.settings[index])
                            }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
            }
        }
    }
}

extension Workspace {
    
    // Delegate setting changes from UI to the coordinator integration layer.
    fileprivate func apply(setting change: Control) {
        coordinator.apply(setting: change)
    }
    
    // Delegate parameter changes from UI to the coordinator integration layer.
    fileprivate func apply(parameter change: Control) {
        coordinator.apply(parameter: change)
    }
    
}

struct CompatibleSlider: View {
    
    @Binding var item: Control
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("\(item.label): \(String(format: "%.2f", item.value))")
                .font(.subheadline)
            if let step = item.variant.stepValue {
                Slider(value: $item.value, in: item.variant.range, step: step)
                    .tint(.gray)
            } else {
                Slider(value: $item.value, in: item.variant.range)
                    .tint(.gray)
            }
        }
    }
}
