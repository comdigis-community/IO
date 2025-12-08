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

class ComponentCube: SCNNode {
    
    struct Style {
        var width: CGFloat = 2.25
        var height: CGFloat = 1.25
        var length: CGFloat = 2.5
        var baseColor: NSColor = .black
        var baseTransparency: CGFloat = 0.35
        var frontColor: NSColor = .darkGray
        var frontTransparency: CGFloat = 0.35
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    init(position: SCNVector3, style: Style = .init()) {
        super.init()
        
        let w = style.width, h = style.height, l = style.length
        let box = SCNBox(width: w, height: h, length: l, chamferRadius: .zero)
        
        let baseMaterial = SCNMaterial()
        baseMaterial.diffuse.contents = style.baseColor
        baseMaterial.transparency = style.baseTransparency
        baseMaterial.isDoubleSided = true
        baseMaterial.blendMode = .alpha
        baseMaterial.cullMode = .front
        
        let frontMaterial = SCNMaterial()
        frontMaterial.diffuse.contents = style.frontColor
        frontMaterial.transparency = style.frontTransparency
        frontMaterial.isDoubleSided = true
        frontMaterial.blendMode = .alpha
        frontMaterial.cullMode = .back
        
        box.materials = []
        
        box.materials.append(frontMaterial)
        box.materials.append(baseMaterial)
        box.materials.append(baseMaterial)
        box.materials.append(frontMaterial)
        box.materials.append(frontMaterial)
        box.materials.append(baseMaterial)
        
        self.position = position
        self.geometry = box
    }
    
}
