#### Overview

I/O Android COMMUNITY provides a client-ready Android distribution of the I/O audio engine. It is published as a versioned `.aar` in GitHub Releases, so Android clients can integrate it directly without a Maven repository.

For updates and release notes, please refer to `https://github.com/comdigis-community/IO/releases` 

This Android package exposes a public Kotlin API in `com.comdigis.io.android.audio` and includes a reference client sample under `/android/app`. The `/android/experimental` module in this repository is a consumer-side wrapper used by the sample to fetch and verify published release artifacts.

#### Installation

Android COMMUNITY release artifacts follow this naming convention: `IO-<version>-community.aar`, `IO-<version>-community.aar.sha256`, `IO-<version>-community-android.json`, and `IO-community-android-latest.json`.

Release URLs and Checksum:

```text
https://github.com/comdigis-community/IO/releases/download/<version>/IO-<version>-community.aar
https://github.com/comdigis-community/IO/releases/download/<version>/IO-<version>-community.aar.sha256
```

#### Quickstart (External Android App)

Download the `.aar` and `.sha256` from the desired release tag, verify checksum integrity, copy the `.aar` into your app (for example `app/libs/`), and reference it from Gradle:

```kotlin
dependencies {
    implementation(files("libs/IO-<version>-community.aar"))
}
```

After dependency setup, initialize and use the public Kotlin API from `com.comdigis.io.android.audio`.

#### Public Kotlin API

Clients should use the public API surface under `com.comdigis.io.android.audio`. Common entry points include `NativeLoader`, `Assemble`, `AudioGraph`, `AudioNode`, `Binaural`, `Listener`, `BinauralDatabase`, `FileRenderer`, `Vector3`, and `DistanceModel`. A minimal client flow is to load native runtime, create an `Assemble` instance, build an `AudioGraph`, connect required nodes, and start rendering.

Android COMMUNITY follows semantic versioning expectations. Major versions may introduce incompatible API or behavior changes, minor versions add backward-compatible features, and patch versions deliver backward-compatible fixes. For production usage, clients should pin explicit versions and upgrade intentionally.

#### Common Integration Issues

If you receive a `404` during artifact download, confirm the release tag exists and the requested version in the URL is correct. If checksum verification fails, re-download both files from the same release tag and validate again. If runtime fails with `UnsatisfiedLinkError`, verify ABI compatibility on the device/emulator (typically `arm64-v8a` or `x86_64`). If the app compiles but graph startup fails, check initialization order: load runtime first, then create graph, connect nodes, and start rendering.

### Issues

If you would like to report an issue or submit a feature request, please use the official GitHub issue tracker. This helps ensure we receive all the necessary information to properly review and address your request.

https://github.com/comdigis-community/IO/issues

#### License

This project is distributed under a license that allows its use, modification, and distribution, provided that the specified terms are respected (http://opensource.org/licenses/mit-license.php)

Copyright © 2019 - 2027 - ***Comdigis***, *Buenos Aires, Argentina*.
