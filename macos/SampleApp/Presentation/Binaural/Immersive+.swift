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

struct ImmersiveSpace {

    let cubeStyle: ComponentCube.Style
    let objectPosition: SCNVector3
    let listenerPosition: SCNVector3
    let projectedRadius: CGFloat

    let cameraPosition = SCNVector3(-2.75, 2.5, 2.5)

    var cubeCenter: SCNVector3 {
        SCNVector3(0, cubeStyle.height / 2, 0)
    }

    static func resolve(from container: BinauralComponent) -> ImmersiveSpace {
        let style = ComponentCube.Style()
        let padding: Float = 0.10

        func clamp(_ v: Float, _ min: Float, _ max: Float) -> Float {
            Swift.max(min, Swift.min(v, max))
        }

        func coordinate(_ id: Control.ID, span: Float, offset: Float = 0) -> Float {
            guard let c = container.parameters.first(where: { $0.id == id }) else { return offset }
            let r = c.variant.range
            let m = max(r.upperBound - r.lowerBound, .leastNonzeroMagnitude)
            let n = ((c.value - r.lowerBound) / m) - 0.5
            return (n * span) + offset
        }

        let halfW = Float(style.width) / 2 - padding
        let halfL = Float(style.length) / 2 - padding

        var x = coordinate(.positionX, span: Float(style.width))
        var y = coordinate(.positionY, span: Float(style.height), offset: Float(style.height) / 2)
        var z = coordinate(.positionZ, span: Float(style.length))

        x = clamp(x, -halfW, halfW)
        y = clamp(y, padding, Float(style.height) - padding)
        z = clamp(z, -halfL, halfL)

        let radius: CGFloat = {
            guard let c = container.settings.first(where: { $0.id == .innerRadius }) else { return 0 }
            let r = c.variant.range
            let m = max(r.upperBound - r.lowerBound, .leastNonzeroMagnitude)
            return min(CGFloat(c.value) * style.width / CGFloat(m), style.width / 2)
        }()

        return ImmersiveSpace(
            cubeStyle: style,
            objectPosition: SCNVector3(x, y, z),
            listenerPosition: SCNVector3(0, Float(style.height) / 2, 0),
            projectedRadius: radius
        )
    }
}
