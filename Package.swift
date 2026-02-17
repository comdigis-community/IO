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
    .binaryTarget(name: "IO", url: "https://github.com/comdigis-community/IO/releases/download/2026.1.7/IO-2026.1.7-community.xcframework.zip", checksum: "c6af3059c96f7f56cfe5e1efedef2e5869daf33944400d4988a057c4cb04c633")
]
