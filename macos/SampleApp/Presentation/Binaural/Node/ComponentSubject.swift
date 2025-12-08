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

class ComponentSubject: SCNNode {
    
    struct Style {
        var color: NSColor = .gray
        var rotation: SCNVector3 = SCNVector3(0, CGFloat.pi, 0)
        var scale: SCNVector3 = SCNVector3(1, 1, 1)
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    init(url: URL, position: SCNVector3, style: Style = .init()) {
        super.init()
        
        guard let child = SCNReferenceNode(url: url) else { return }
        
        child.load()
        
        let (minVec, maxVec) = child.boundingBox
        
        let centerX = (minVec.x + maxVec.x) / 2
        let centerY = (minVec.y + maxVec.y) / 2
        let centerZ = (minVec.z + maxVec.z) / 2
        
        let center = SCNVector3(centerX, centerY, centerZ)
        
        child.position = position
        child.pivot = SCNMatrix4MakeTranslation(center.x, center.y, center.z)
        child.eulerAngles = style.rotation
        child.scale = style.scale
        
        child.enumerateChildNodes { node, _ in
            node.geometry?.materials.forEach {
                $0.diffuse.contents = style.color
            }
        }
        addChildNode(child)
    }
    
}
