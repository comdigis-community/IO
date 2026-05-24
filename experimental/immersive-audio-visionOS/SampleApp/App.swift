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

@main
struct SampleApp: App {

    private enum LaunchState {
        case loading
        case ready
        case failed(String)
    }

    private enum Layout {
        static let width = 1536.0
        static let height = 864.0
    }

    @State private var appModel = AppModel()
    @State private var launchState = LaunchState.loading
    @State private var didStartPreload = false

    var body: some Scene {
        WindowGroup {
            launchView
                .frame(width: Layout.width, height: Layout.height)
                .onAppear {
                    startDatabasePreloadIfNeeded()
                }
        }
        .defaultSize(width: Layout.width, height: Layout.height)
        .windowResizability(.contentSize)

        ImmersiveSpace(id: appModel.immersiveSpaceID) {
            ImmersiveView()
                .environment(appModel)
                .onAppear {
                    appModel.immersiveSpaceState = .open
                    if appModel.binauralCoordinator == nil {
                        appModel.binauralCoordinator = try? BinauralCoordinator()
                    }
                    appModel.binauralCoordinator?.play()
                }
                .onDisappear {
                    appModel.immersiveSpaceState = .closed
                    appModel.binauralCoordinator?.stop()
                }
        }
        .immersionStyle(selection: .constant(.full), in: .full)
    }

    @ViewBuilder
    private var launchView: some View {
        switch launchState {
        case .loading:
            LoadingView()
        case .ready:
            ContentView()
                .environment(appModel)
        case .failed(let message):
            FailureView(message: message) {
                didStartPreload = false
                launchState = .loading
                startDatabasePreloadIfNeeded()
            }
        }
    }

    private func startDatabasePreloadIfNeeded() {
        guard !didStartPreload else {
            return
        }

        didStartPreload = true
        BinauralDatabaseLoader.preload { result in
            switch result {
            case .success(let loaded) where loaded:
                launchState = .ready
            case .success:
                let message = "loadAsynchronously returned false"
                assertionFailure("Unable to preload HRTF database: \(message)")
                launchState = .failed(message)
            case .failure(let error):
                assertionFailure("Unable to preload HRTF database: \(error)")
                launchState = .failed(error.localizedDescription)
            }
        }
    }
}

@MainActor
@Observable
class AppModel {
    let immersiveSpaceID = "ImmersiveSpace"

    enum ImmersiveSpaceState {
        case closed
        case inTransition
        case open
    }

    var immersiveSpaceState = ImmersiveSpaceState.closed
    var binauralCoordinator: BinauralCoordinator?
}

private struct LoadingView: View {
    var body: some View {
        VStack(spacing: 18.0) {
            ProgressView()
                .controlSize(.regular)
                .scaleEffect(2.0)
            Text("Loading binaural database...")
                .font(.title3.weight(.semibold))
        }
        .padding(28.0)
    }
}

private struct FailureView: View {
    let message: String
    let retry: () -> Void

    var body: some View {
        VStack(spacing: 12.0) {
            Text("Unable to preload HRTF database")
                .font(.headline)
            Text(message)
                .font(.footnote)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Button("Retry", action: retry)
        }
        .padding()
    }
}
