// swift-tools-version:5.9
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

import PackageDescription

let package = Package(
    name: "IO",
    platforms: [
        .macOS(.v11), .iOS(.v13)
    ],
    products: [
        .library(name: "IO", targets: ["IO"]),
    ],
    dependencies: [],
    cxxLanguageStandard: .cxx11
)

package.targets += [
    .binaryTarget(name: "IO", url: "https://github.com/comdigis-community/IO/releases/download/2026.2.11/IO-2026.2.11-community.xcframework.zip", checksum: "6af22c0b0d0ea11f0d14a7855e66ea6405faf124a6d2137a07e1eb08fe8d49b4")
]
