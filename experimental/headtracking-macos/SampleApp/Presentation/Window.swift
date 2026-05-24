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

import SwiftUI

struct WindowView: View {

    @StateObject private var controller = VideoController()

    var body: some View {
        Workspace(controller: controller)
            .frame(width: Layout.width, height: Layout.height)
            .toolbar {
                ToolbarItemGroup(placement: .automatic) {
                    PlaybackButton(controller: controller)
                }
            }
    }
}

private extension WindowView {
    enum Layout {
        static let width: CGFloat = 1200
        static let height: CGFloat = 760
    }
}

private struct PlaybackButton: View {
    @ObservedObject var controller: VideoController

    var body: some View {
        Button(action: controller.togglePlayback) {
            Image(systemName: controller.isPlaying ? "pause.fill" : "play.fill")
        }
        .disabled(controller.isPreparingSelection || controller.isReadyForPlayback == false)
        .keyboardShortcut(.space, modifiers: [])
    }
}
