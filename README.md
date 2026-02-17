#### Overview

I/O is a **multiplatform audio graph engine**, written entirely in ***Swift***, designed to offer a flexible and high-performance system for creating, processing, and routing audio in real time. The engine provides a comprehensive set of tools to select audio sources, apply effects, generate visualizations, and more. All operations are executed within an **audio context**, conceived to enable ***modular*** and scalable routing. Core operations are performed through *nodes*, which are linked together to form a processing graph. These nodes can be arranged into ***simple chains or more complex networks***, connecting their inputs and outputs to establish custom signal paths. Typically, processing begins with one or more sources delivering samples at extremely small time intervals—often tens of thousands per second. The output of each node can be routed to others, mixing, transforming, or processing the audio signal in different ways, enabling sophisticated paths for ***production, analysis, or final rendering***. Thanks to its modular architecture and optimized implementation in ***Swift***, I/O combines design clarity with high performance, ensuring accuracy and low latency across multiple environments.

### Getting Started

Thank you for your interest in our platform. We appreciate your curiosity and are delighted that you are exploring I/O as part of your audio development workflow.

At this stage, the distributed binary package in the form of an **xcframework** provides support exclusively for **iOS and macOS** platforms. We are actively working on expanding compatibility to include **Android**, with support for **Linux** and **Windows** planned for future releases.

The project includes two sample applications demonstrating key use cases: 

An **iOS sample** showcasing integration with *RealityKit*, illustrating how to drive spatial audio experience in interactive environments. 

 A **macOS sample** offering a configurable application where parameters can be adjusted to explore and experiment with the engine’s capabilities.

We invite you, as an audio developer, to explore the extended documentation available in the root of the repository under the **/documentation** directory. There you will find detailed technical guides, installation instructions, examples, and patterns to accelerate your adoption.

For further technical information, comprehensive guides, didactic resources, and the full API reference, please visit our official documentation site at https://docs.comdigis.com/ where content is continually updated and expanded to support your work.

### Installation

This package supports installation via `SwiftPM` only and requires the following configuration:

- *Xcode 14.x and Swift 5.x*
- *Minimum deployment target iOS 17.6*

**Integrate this package in your `Package.swift` as follows:**

```swift
import PackageDescription

let package = Package(
    name: "YourProject",
    platforms: [.macOS(.v11), .iOS(.v13)],
    dependencies: [
        .package(url: "https://github.com/comdigis-community/IO.git", from: "X.X.X")
    ],
    targets: [
        .target(
            name: "YourProject",
            dependencies: [.product(name: "IO", package: "IO")]
        )
    ]
)
```

### Issues

If you would like to report an issue or submit a feature request, please use the official GitHub issue tracker. This helps ensure we receive all the necessary information to properly review and address your request.

https://github.com/comdigis-community/IO/issues

#### License

This project is distributed under a license that allows its use, modification, and distribution, provided that the specified terms are respected (http://opensource.org/licenses/mit-license.php)

Copyright © 2019 - 2027 - ***Comdigis***, *Buenos Aires, Argentina*.
