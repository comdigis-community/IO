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

import IO
import Foundation
import simd

extension SIMD3 where Scalar == Float {
    var vector3: Vector3<Float64> {
        .init(x: Float64(x), y: Float64(y), z: Float64(z))
    }
    var normalized: SIMD3<Float> {
        simd_normalize(self)
    }
}

extension Locale {
    static var languageCode: String {
        preferredLanguages.first?.hasPrefix("es") == true ? "es" : "en"
    }
}

extension SIMD3 where Scalar == Float {
    func distance(to other: SIMD3<Float>) -> Float {
        simd_distance(self, other)
    }
    func alignmentDelta(to other: SIMD3<Float>) -> Float {
        1.0 - simd_dot(self, other)
    }
}

extension URL {
    static func HRTF() -> URL {
        Bundle.main.resourceURL ?? { fatalError() }()
    }
    static func resource(named name: String) -> URL? {
        Bundle.main.url(forResource: name, withExtension: "wav")
    }
}

extension simd_float4x4 {
    var position3: SIMD3<Float> {
        columns.3.xyz
    }
    var forward3: SIMD3<Float> {
        -columns.2.xyz
    }
    var up3: SIMD3<Float> {
        columns.1.xyz
    }
}

extension simd_float4 {
    var xyz: SIMD3<Float> {
        .init(x, y, z)
    }
}
