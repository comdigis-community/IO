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

struct WindowView: View {

    @StateObject var session: Orchestrator
    @EnvironmentObject var coordinator: BinauralCoordinator

    var body: some View {
        VStack(alignment: .leading, spacing: .zero) {
            Workspace(container: session.binding)
                .padding(.top, 10)
        }
        .frame(width: 1333, height: 750)
        .toolbar {
            ToolbarItemGroup(placement: .automatic) {
                Picker(selection: $session.object) {
                    ForEach(BinauralObject.allCases) {
                        Text($0.id).tag($0)
                    }
                } label: {
                    EmptyView()
                }
                .frame(width: 350)

                CoordinatorControls()
            }
        }
        .onAppear {
            session.connect(coordinator: coordinator)
        }
    }
}

struct CoordinatorControls: View {
    
    @EnvironmentObject var coordinator: BinauralCoordinator
    
    var body: some View {
        Button(action: { coordinator.toggle() }, label: {
            Image(systemName: coordinator.isPlaying ? "pause.fill" : "play.fill")
        })
        .padding(.horizontal, 4)
    }

}
