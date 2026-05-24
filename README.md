## Comdigis I/O - Community Edition

<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="./images/comdigis-dark.svg">
    <source media="(prefers-color-scheme: light)" srcset="./images/comdigis-light.svg">
    <img alt="Comdigis" src="./images/comdigis-light.svg" width="280">
  </picture>
</p>

<p align="center">
  <img alt="Swift" src="https://img.shields.io/badge/Swift-5.x-orange?logo=swift">
  <img alt="SwiftPM" src="https://img.shields.io/badge/SwiftPM-supported-brightgreen?logo=swift">
  <img alt="Platforms" src="https://img.shields.io/badge/platforms-iOS%20%7C%20macOS%20%7C%20visionOS%20%7C%20Android-blue">
  <img alt="Release" src="https://img.shields.io/github/v/release/comdigis-community/IO?label=release">
  <img alt="License" src="https://img.shields.io/badge/license-MIT-green">
</p>


**Comdigis I/O** is a **multiplatform spatial audio engine**, written entirely in ***Swift***, focused on delivering high-performance, low-latency audio processing for **immersive experiences**. Designed around a flexible real-time audio graph architecture, that enables developers and creators to build advanced pipelines for **spatial audio, 3D positioning, XR, interactive media, and next-generation entertainment apps**.

At its core, I/O provides a modular ecosystem of interconnected *nodes* capable of generating, routing, transforming, analyzing, and rendering audio with deterministic precision. Audio flows through an extensible processing graph where nodes can be combined into simple chains or highly sophisticated networks, enabling custom signal paths for **real-time DSP, spatialization, mixing, visualization, analysis, and immersive playback**. 

The engine is specifically designed to support **spatial audio workflows**, reproducing depth, direction, distance, and movement with high precision for headphone-based experiences and modern spatial computing environments. Its architecture allows multiple audio sources to coexist and interact dynamically within a shared audio context, enabling scalable and adaptive sound environments across platforms.

By combining a clean modular design with an optimized Swift implementation, **Comdigis I/O** delivers the performance, scalability, and flexibility required for professional-grade audio applications while maintaining a developer-friendly architecture suitable for both experimentation and production environments.

Learn more on [comdigis.com](https://www.comdigis.com) or explore the [documentation](https://docs.comdigis.com/user-guide-io)

#### Preview (iOS)

This demo showcases I/O running on **iOS** with **RealityKit**, highlighting real-time audio graph processing in an interactive and spatial context. It demonstrates how audio sources and processing nodes can be dynamically updated in response to changes, making it suitable for immersive experiences.

[![Mobile demo](./images/comdigis.png)](https://youtu.be/jB82GUj6mIA)

#### Preview (iOS)

This demo showcases I/O running on **iOS** with **RealityKit**, highlighting real-time audio graph processing in an interactive and spatial context. It demonstrates how audio sources and processing nodes can be dynamically updated in response to changes, making it suitable for immersive experiences.

[![Mobile demo](./images/comdigis.png)](https://youtu.be/wd83_5iCI0k)

#### Preview (Desktop)

This demo presents I/O in a **macOS** environment through a configurable desktop application. It focuses on exploring the engine’s core capabilities—audio routing, parameter control, and real-time processing—allowing developers to experiment with different graph configurations and better understand the system’s behavior in a controlled, non-immersive setting.

[![macOS demo](./images/comdigis.png)](https://youtu.be/zn6s1bCa9eQ)

### Getting Started

Thank you for your interest in our platform. We appreciate your curiosity and are delighted that you are exploring I/O as part of your audio development workflow.

The distributed package currently includes stable Apple platform binaries (`xcframework`) for **iOS** and **macOS**. This repository also includes an **experimental Android implementation** for COMMUNITY, distributed as a versioned `.aar` through GitHub Releases and validated with an Android sample project.

The project includes three sample applications demonstrating key use cases: 

An **iOS sample** showcasing integration with *RealityKit*, illustrating how to drive spatial audio experience in interactive environments.  A **macOS sample** offering a configurable application where parameters can be adjusted to explore and experiment with the engine’s capabilities. An **Android experimental sample** is available under `/android` and demonstrates client-side integration of the released COMMUNITY AAR.

We invite you, as an audio developer, to explore the extended documentation available in the root of the repository under the **/documentation** directory. There you will find detailed technical guides, installation instructions, examples, and patterns to accelerate your adoption.

For further technical information, comprehensive guides, didactic resources, and the full API reference, please visit our official documentation site at https://docs.comdigis.com/ where content is continually updated and expanded to support your work.

### Installation (Apple)

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

### Installation (Android)

Android COMMUNITY is distributed as a versioned `.aar` in GitHub Releases (no Maven repository required).

- Download `IO-<version>-community.aar` and `IO-<version>-community.aar.sha256` from release tag.
- Verify integrity before integration.

```bash
shasum -a 256 IO-<version>-community.aar
```

- Add the artifact to your app (for example, `app/libs/`) and reference it from Gradle:

```kotlin
dependencies {
    implementation(files("libs/IO-<version>-community.aar"))
}
```

### Experimental (Labs)

The `/experimental` directory contains standalone showcase projects, demos, and educational apps built around I/O. These samples are meant to be explored as practical references rather than core distribution artifacts: they make it easier to inspect how the engine behaves inside complete app contexts, compare platform-specific integrations, and experiment with real-time audio workflows without starting from an empty project.

Inside that area you will find examples covering mobile and desktop playback flows, spatial and head-tracked audio, immersive interfaces, and Android validation for the COMMUNITY AAR. Each project is intentionally scoped as a focused learning surface, useful for testing ideas, understanding integration, or adapting a small apps.

For the full list of available samples, screenshots, and per-project context, see the [Experimental README](./experimental/README.md).

### Issues

If you would like to report an issue or submit a feature request, please use the official GitHub issue tracker. This helps ensure we receive all the necessary information to properly review and address your request.

https://github.com/comdigis-community/IO/issues

#### License

This project is distributed under a license that allows its use, modification, and distribution, provided that the specified terms are respected (http://opensource.org/licenses/mit-license.php)

Copyright © 2019 - 2027 - ***Comdigis***, *Buenos Aires, Argentina*.
