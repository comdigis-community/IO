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
import Foundation
import SceneKit
import AppKit
import simd

struct ListenerWorldView: NSViewRepresentable {
    let layout: ImmersiveSpace
    let listenerCameraTransform: simd_float4x4?
    let onListenerSceneChanged: (_ transform: simd_float4x4, _ listenerPosition: SIMD3<Float>, _ timestamp: TimeInterval) -> Void

    final class Coordinator: NSObject, SCNSceneRendererDelegate {
        private let lock = NSLock()
        private var callback: ((simd_float4x4, SIMD3<Float>, TimeInterval) -> Void)?
        private var listenerCameraTransformStorage: simd_float4x4?

        var camera: SCNNode?
        var sceneRoot: SCNNode?
        var objectNodes: [ComponentSphere] = []
        private var currentLayout: ImmersiveSpace?

        func update(
            layout: ImmersiveSpace,
            listenerCameraTransform: simd_float4x4?,
            callback: @escaping (simd_float4x4, SIMD3<Float>, TimeInterval) -> Void
        ) {
            lock.lock()
            currentLayout = layout
            listenerCameraTransformStorage = listenerCameraTransform
            self.callback = callback
            lock.unlock()
        }

        func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
            guard let pointOfView = renderer.pointOfView ?? camera else { return }

            lock.lock()
            guard let layout = currentLayout, let callback = self.callback else {
                lock.unlock()
                return
            }
            let listenerPosition = layout.listenerPosition
            let listenerCameraTransform = listenerCameraTransformStorage
            lock.unlock()

            pointOfView.position = listenerPosition
            if let listenerCameraTransform {
                var synchronizedTransform = listenerCameraTransform
                synchronizedTransform.columns.3 = SIMD4<Float>(
                    Float(listenerPosition.x),
                    Float(listenerPosition.y),
                    Float(listenerPosition.z),
                    1
                )
                pointOfView.simdWorldTransform = synchronizedTransform
            }

            let transform = pointOfView.presentation.simdWorldTransform
            callback(
                transform,
                SIMD3<Float>(Float(listenerPosition.x), Float(listenerPosition.y), Float(listenerPosition.z)),
                time
            )
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> SCNView {
        let view = SCNView()
        view.autoresizingMask = [.width, .height]
        view.autoresizesSubviews = true
        view.allowsCameraControl = true
        view.defaultCameraController.interactionMode = .fly
        view.defaultCameraController.minimumVerticalAngle = -89.0
        view.defaultCameraController.maximumVerticalAngle = 89.0
        view.isPlaying = true
        view.autoenablesDefaultLighting = false
        view.backgroundColor = NSColor(calibratedRed: 0.85, green: 0.92, blue: 0.98, alpha: 1.0)

        let scene = SCNScene()
        view.scene = scene

        let camera = SCNNode()
        camera.camera = SCNCamera()
        camera.camera?.zNear = 0.01
        camera.camera?.zFar = 100.0
        ImmersiveWorldSceneBuilder.configurePostProcessing(for: camera.camera)
        camera.position = layout.listenerPosition
        camera.look(at: SCNVector3(Float(layout.listenerPosition.x), 0.12, Float(layout.listenerPosition.z) - Float(layout.cubeStyle.length)))
        scene.rootNode.addChildNode(camera)
        view.pointOfView = camera
        context.coordinator.camera = camera

        let root = SCNNode()
        scene.rootNode.addChildNode(root)
        context.coordinator.sceneRoot = root
        ImmersiveWorldSceneBuilder.build(into: root, layout: layout)

        view.delegate = context.coordinator
        return view
    }

    func updateNSView(_ view: SCNView, context: Context) {
        context.coordinator.update(
            layout: layout,
            listenerCameraTransform: listenerCameraTransform,
            callback: onListenerSceneChanged
        )
        view.allowsCameraControl = listenerCameraTransform == nil

        ImmersiveWorldSceneBuilder.updateObjects(
            in: context.coordinator.sceneRoot,
            coordinator: context.coordinator,
            layout: layout
        )
    }
}
