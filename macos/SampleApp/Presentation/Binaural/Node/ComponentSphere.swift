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

class ComponentSphere: SCNNode {
    
    struct Style {
        var radius: CGFloat = 0.075
        var color: NSColor = .lightGray
        var transparency: CGFloat = 1.0
        var doubleSided: Bool = false
        var depthRead: Bool = true
        var depthWrite: Bool = true
        
        static var light: Style {
            return Style()
        }
        
        static var dark: Style {
            var style = Style()
            style.color = .darkGray
            style.radius = 0.075
            style.transparency = 0.05
            style.doubleSided = true
            style.depthRead = false
            style.depthWrite = false
            return style
        }
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    init(position: SCNVector3, style: Style = .light) {
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
    
    public func update(radius: CGFloat) {
        guard let geometry = geometry as? SCNSphere else { return }
        geometry.radius = radius
    }
    
}
