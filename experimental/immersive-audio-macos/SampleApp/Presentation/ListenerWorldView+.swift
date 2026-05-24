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

struct ImmersiveSpace {
    struct CubeStyle {
        var width: CGFloat = 2.25
        var height: CGFloat = 1.25
        var length: CGFloat = 2.5
    }

    let cubeStyle: CubeStyle
    let objectPositions: [SCNVector3]
    let selectedObjectIndex: Int
    let listenerPosition: SCNVector3
}

class ComponentSphere: SCNNode {

    struct Style {
        var radius: CGFloat = 0.075
        var color: NSColor = .lightGray
        var transparency: CGFloat = 1.0
        var doubleSided: Bool = false
        var depthRead: Bool = true
        var depthWrite: Bool = true
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    init(position: SCNVector3, style: Style = .init()) {
        super.init()

        let sphere = SCNSphere(radius: style.radius)
        let material = SCNMaterial()
        material.diffuse.contents = style.color
        material.transparency = style.transparency
        material.isDoubleSided = style.doubleSided
        material.readsFromDepthBuffer = style.depthRead
        material.writesToDepthBuffer = style.depthWrite
        sphere.materials = [material]

        geometry = sphere
        self.position = position
    }
}

enum ImmersiveWorldSceneBuilder {
    private struct SceneArtDirection {
        struct Floor {
            let safeExtra: Float = 2.5
        }
        struct Lighting {
            let ambientIntensity: CGFloat = 700
            let ambientColor = NSColor(calibratedWhite: 0.95, alpha: 1.0)
            let keyIntensity: CGFloat = 1800
            let keyColor = NSColor(calibratedWhite: 0.98, alpha: 1.0)
        }
        let floor = Floor()
        let lighting = Lighting()
    }

    static func build(into root: SCNNode, layout: ImmersiveSpace) {
        let style = SceneArtDirection()
        let worldRoot = SCNNode()
        worldRoot.name = "world-root"
        root.addChildNode(worldRoot)

        let groundRoot = SCNNode()
        groundRoot.name = "ground-root"
        worldRoot.addChildNode(groundRoot)

        let actorRoot = SCNNode()
        actorRoot.name = "actor-root"
        worldRoot.addChildNode(actorRoot)

        addObjectSphere(into: actorRoot)
        addForestModel(into: groundRoot, layout: layout, style: style)
        addLights(into: worldRoot, style: style)
    }

    static func updateObjects(in root: SCNNode?, coordinator: ListenerWorldView.Coordinator, layout: ImmersiveSpace) {
        guard let root else { return }

        while coordinator.objectNodes.count < layout.objectPositions.count {
            let node = ComponentSphere(position: SCNVector3Zero)
            node.opacity = 1.0
            node.scale = SCNVector3(1.0, 1.0, 1.0)
            root.addChildNode(node)
            coordinator.objectNodes.append(node)
        }

        while coordinator.objectNodes.count > layout.objectPositions.count {
            let node = coordinator.objectNodes.removeLast()
            node.removeFromParentNode()
        }

        for (index, node) in coordinator.objectNodes.enumerated() {
            guard layout.objectPositions.indices.contains(index) else { continue }
            node.position = layout.objectPositions[index]
            node.opacity = 0.0
        }

        if let objectSphere = root.childNode(withName: "object-sphere", recursively: true) {
            let selectedIndex = min(max(layout.selectedObjectIndex, 0), max(layout.objectPositions.count - 1, 0))
            if layout.objectPositions.indices.contains(selectedIndex) {
                let p = layout.objectPositions[selectedIndex]
                objectSphere.position = SCNVector3(p.x, p.y + 0.08, p.z)
            }
        }
    }

    private static func addForestModel(into root: SCNNode, layout: ImmersiveSpace, style: SceneArtDirection) {
        guard
            let modelURL = Bundle.main.url(forResource: "model2", withExtension: "usd"),
            let modelScene = try? SCNScene(url: modelURL, options: nil)
        else {
            return
        }

        let modelNode = SCNNode()
        modelNode.name = "forest-model"
        for child in modelScene.rootNode.childNodes {
            modelNode.addChildNode(child.clone())
        }

        let bounds = modelNode.boundingBox
        let sizeX = bounds.max.x - bounds.min.x
        let sizeZ = bounds.max.z - bounds.min.z
        guard sizeX > .leastNonzeroMagnitude, sizeZ > .leastNonzeroMagnitude else {
            root.addChildNode(modelNode)
            return
        }

        let floorHalfX = Float(layout.cubeStyle.width) / 2.0 + style.floor.safeExtra
        let floorHalfZ = Float(layout.cubeStyle.length) / 2.0 + style.floor.safeExtra
        let floorWidth = floorHalfX * 2.0
        let floorLength = floorHalfZ * 2.0
        let sizeY = bounds.max.y - bounds.min.y
        let planarScale = min(CGFloat(floorWidth) / sizeX, CGFloat(floorLength) / sizeZ)
        let targetMaxHeight = CGFloat(layout.cubeStyle.height) * 1.35
        let heightScale: CGFloat
        if sizeY > .leastNonzeroMagnitude {
            heightScale = targetMaxHeight / sizeY
        } else {
            heightScale = planarScale
        }
        let targetScale = min(planarScale, heightScale)
        modelNode.scale = SCNVector3(targetScale, targetScale, targetScale)

        let centerX = (bounds.min.x + bounds.max.x) * 0.5
        let centerZ = (bounds.min.z + bounds.max.z) * 0.5
        let baseY = bounds.min.y
        modelNode.pivot = SCNMatrix4MakeTranslation(centerX, baseY, centerZ)
        modelNode.position = SCNVector3Zero

        root.addChildNode(modelNode)
    }

    private static func addObjectSphere(into root: SCNNode) {
        let sphere = SCNSphere(radius: 0.22)
        sphere.segmentCount = 36
        sphere.materials = [objectSphereMaterial()]

        let objectSphere = SCNNode(geometry: sphere)
        objectSphere.name = "object-sphere"
        objectSphere.position = SCNVector3(0.0, 0.6, 0.0)
        objectSphere.castsShadow = false
        root.addChildNode(objectSphere)
    }

    private static func objectSphereMaterial() -> SCNMaterial {
        let material = SCNMaterial()
        material.lightingModel = .physicallyBased
        material.diffuse.contents = NSColor(calibratedRed: 0.97, green: 0.98, blue: 1.0, alpha: 0.97)
        material.specular.contents = NSColor(calibratedWhite: 0.25, alpha: 0.25)
        material.roughness.contents = 0.8
        material.metalness.contents = 0.0
        material.emission.contents = NSColor.black
        material.transparency = 0.97
        material.isDoubleSided = true
        return material
    }

    private static func addLights(into root: SCNNode, style: SceneArtDirection) {
        let ambientNode = SCNNode()
        let ambientLight = SCNLight()
        ambientLight.type = .ambient
        ambientLight.intensity = style.lighting.ambientIntensity
        ambientLight.color = style.lighting.ambientColor
        ambientNode.light = ambientLight
        root.addChildNode(ambientNode)

        let keyNode = SCNNode()
        let keyLight = SCNLight()
        keyLight.type = .directional
        keyLight.intensity = style.lighting.keyIntensity
        keyLight.color = style.lighting.keyColor
        keyNode.light = keyLight
        keyNode.position = SCNVector3(-1.2, 2.7, 1.2)
        keyNode.look(at: SCNVector3Zero)
        root.addChildNode(keyNode)
    }

    static func configurePostProcessing(for camera: SCNCamera?) {
        guard let camera else { return }
        camera.wantsHDR = false
        camera.wantsExposureAdaptation = false

        camera.bloomIntensity = 0.0
        camera.bloomThreshold = 1.0
        camera.bloomBlurRadius = 2.0

        camera.saturation = 0.0
        camera.contrast = 1.0

        camera.colorFringeStrength = 0.0
        camera.colorFringeIntensity = 0.0
        camera.vignettingIntensity = 0.0
        camera.vignettingPower = 0.0
        camera.grainIntensity = 0.0
        camera.grainScale = 1.0
    }
}
