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
import SceneKit
import simd

struct WorkspaceView: View {
    @EnvironmentObject private var coordinator: BinauralCoordinator

    var body: some View {
        ZStack {
            listenerWorld
            ExploreOverlay()
        }
    }
}

private extension WorkspaceView {
    var listenerWorld: some View {
        ListenerWorldView(
            layout: immersiveSpace,
            listenerCameraTransform: nil,
            onListenerSceneChanged: handleListenerChange
        )
        .padding(.top, 10)
    }

    var immersiveSpace: ImmersiveSpace {
        ImmersiveSpace(
            cubeStyle: .init(),
            objectPositions: [.init(0.0, 0.5, coordinator.visualSourceZ)],
            selectedObjectIndex: 0,
            listenerPosition: .init(0.0, 0.5, 0.0)
        )
    }

    func handleListenerChange(
        transform: simd_float4x4,
        listenerPosition: SIMD3<Float>,
        timestamp: TimeInterval
    ) {
        coordinator.updateListener(
            position: listenerPosition,
            forward: (-transform.columns.2.xyz).normalized,
            up: transform.columns.1.xyz.normalized,
            timestamp: timestamp
        )
    }
}

private struct ExploreOverlay: View {
    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "rotate.3d")
                .font(.system(size: 78, weight: .regular))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.white)

            Text("Press Play and Drag to explore")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 26)
        .padding(.vertical, 22)
        .background(Color.black.opacity(0.58))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .allowsHitTesting(false)
    }
}

private extension SIMD3 where Scalar == Float {
    var normalized: SIMD3<Float> {
        let length = simd_length(self)
        guard length > .leastNonzeroMagnitude else {
            return .init(0.0, 0.0, 0.0)
        }
        return self / length
    }
}

private extension simd_float4 {
    var xyz: SIMD3<Float> {
        .init(x, y, z)
    }
}
