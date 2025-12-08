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

struct ImmersiveWorkspace: NSViewRepresentable {

    @Binding var reset: Bool
    let layout: ImmersiveSpace

    final class Coordinator {
        var object: ComponentSphere?
        var listener: ComponentSubject?
        var sphere: ComponentSphere?
        var cube: ComponentCube?
        var camera: SCNNode?
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> SCNView {
        let view = SCNView()
        view.allowsCameraControl = true
        view.autoenablesDefaultLighting = true
        view.backgroundColor = .clear

        let scene = SCNScene()
        view.scene = scene

        let camera = SCNNode()
        camera.camera = SCNCamera()
        camera.position = layout.cameraPosition
        camera.look(at: SCNVector3(0, 0, 0))

        context.coordinator.camera = camera
        view.pointOfView = camera
        scene.rootNode.addChildNode(camera)

        let cube = ComponentCube(position: layout.cubeCenter, style: layout.cubeStyle)
        scene.rootNode.addChildNode(cube)
        context.coordinator.cube = cube

        let object = ComponentSphere(position: layout.objectPosition)
        scene.rootNode.addChildNode(object)
        context.coordinator.object = object

        if let url = Bundle.main.url(forResource: "Obj", withExtension: "obj") {
            let listener = ComponentSubject(url: url, position: layout.listenerPosition)
            scene.rootNode.addChildNode(listener)
            context.coordinator.listener = listener
        }

        return view
    }

    func updateNSView(_ view: SCNView, context: Context) {
        if reset, let camera = context.coordinator.camera {
            view.pointOfView = camera
            DispatchQueue.main.async { reset = false }
        }

        let object = context.coordinator.object ?? {
            let node = ComponentSphere(position: layout.objectPosition)
            view.scene?.rootNode.addChildNode(node)
            context.coordinator.object = node
            return node
        }()

        let sphere = context.coordinator.sphere ?? {
            let node = ComponentSphere(position: layout.listenerPosition, style: .dark)
            node.renderingOrder = 999
            view.scene?.rootNode.addChildNode(node)
            context.coordinator.sphere = node
            return node
        }()

        object.position = layout.objectPosition
        sphere.position = layout.listenerPosition
        sphere.update(radius: layout.projectedRadius)
    }
}
