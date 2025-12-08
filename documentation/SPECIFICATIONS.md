### 1 — General audio system specification

This section **does not define an API contract nor a compatibility guarantee**, but documents how the system currently operates: which parameters are fixed, which are negotiated or degraded, and at which layers critical decisions occur (backend, hardware interop, graph, or internal buses). The goal is to provide a common and verifiable baseline to understand observed behavior, facilitate technical reasoning about latency, timing, and buffering, and serve as a reference for future design decisions, backend changes, or cross-environment validations (simulator vs real hardware).

The following table organizes this information by functional domains—context and backend, stream and device, internal representation, quantum and buffering, clocking, and audio adaptations—prioritizing **effective behavior** over declarative intent or requested configurations.

|                                                  | Effective behavior / value                                  | Notes                                                        |
| ------------------------------------------------ | ------------------------------------------------------------ | ------------------------------------------------------------ |
| Backend                                          | Adapter (CoreAudio, WASAPI, ALSA)                            | Implemented through the engine hardware interop layer.       |
| Compatibility                                   | Linux, Windows, and macOS. Mobile: Android and iOS.          | -                                                            |
| Render mode (pull / push / hybrid)               | Hybrid model: the backend provides push callbacks, while the internal graph is resolved via pull. | -                                                            |
| Audio routes considered                          | Render (output), Record (input), and Duplex. If the requested route is not available, the system forces render mode. | -                                                            |
| Effective sample rate                            | Fixed `canonicalSampleRate` at 44,100 Hz.                    | No dynamic negotiation with the device.                     |
| Bit depth (stream)                               | 32-bit floating point (f32)                                  | The stream and the engine internal representation are aligned. |
| Sample format                                   | `Float32`.                                                    | No format conversion is performed in the main audio path.   |
| Channel count (output)                           | Explicit support for mono and stereo.                        | Multichannel output beyond stereo is not part of the current public behavior. |
| Channel count (input)                            | In record or duplex modes, the effective input to the graph is mono. | Multichannel capture is reduced to the supported graph input model. |
| Buffer layout                                   | Internally planar. Output to the backend is interleaved. Input from the backend is treated as linear audio data. | Layout conversion occurs at the hardware interop boundary. |
| Fixed vs negotiated parameters                  | Fixed: sample rate, f32 format, and internal quantum. Negotiated: device category (render/record/duplex) based on availability. | The effective category may differ from the originally requested one. |
| Requested vs effective differences               | A duplex request may degrade to render if capture is unavailable; input is not delivered to the graph unless it matches supported input assumptions. | Device availability and capture configuration constrain final behavior. |
| Internal numeric representation                 | Audio: `Float32`. Control and time: `Float64`.               | Audio processing and audio buses operate in `Float32`.      |
| Conversion between internal representation and stream | No format conversion; only planar-to-interleaved interleaving on output. | The backend receives interleaved `Float32` audio.           |
| Conversion point                                | Interleaving in the hardware interop stage.                  | Layout conversion occurs at the hardware boundary, not inside the graph. |
| Effective quantum (frames per buffer)            | `canonicalQuantum = .adaptive (256)` on real hardware; `.balanced (512)` on simulator. | The quantum is fixed for the graph and may vary by environment. |
| Quantum variability                             | Fixed in the internal graph; the backend callback may deliver a different `frameCount`, which is regrouped into internal render blocks. | The backend does not impose the internal quantum directly. |
| Relationship to backend buffer size              | Rendering fills backend callback frames by iterating internal render blocks until remaining frames are consumed. | A callback may span multiple internal blocks or a partial block. |
| Callback periodicity (frames/ms)                 | Defined by the backend. The internal engine operates at 256 frames (~5.80 ms) or 512 frames (~11.61 ms) at 44,100 Hz. | Temporal values derive from `canonicalSampleRate` and the configured quantum. |
| Additional internal buffering                   | Internal buffering is used for capture accumulation and per-quantum render staging. | In record or duplex modes, input can accumulate before being consumed by the graph. |
| Contractual impact of the quantum                | `frameCount` must be a power of two for the binaural panner; the current `canonicalQuantum` (256/512) satisfies this requirement. | Changing the quantum to a non-power-of-two value violates processing preconditions. |
| Primary clock source                             | Frame counter combined with `canonicalSampleRate`. Runtime cursor is updated per rendered block. | -                                                            |
| Internal time unit                               | Frames (`Int`) and `TimeInterval` (seconds) derived from frames/sampleRate. | Runtime time values are derived from the render cursor.     |
| Drift handling                                  | No explicit drift correction or resynchronization logic.     | Any drift depends on the underlying backend.                |
| Reported vs effective latency                   | No global latency API in the public engine surface; latency is primarily observable per processing stage. | Effective latency depends on the backend and the quantum.   |
| Resampling                                      | No resampling in the main path; sample rate is fixed.        | -                                                            |
| Channel remixing                                | Internal buses perform mono↔stereo mixing when there is a mismatch with speaker interpretation. | Remixing occurs in the graph layer, not in the backend.     |
| Format conversion                               | No format conversion; only planar-to-interleaved layout conversion. | The stream delivered to the backend is interleaved `Float32`. |
| Location of adaptations                         | Mixing in the graph layer, interleaving at hardware output, capture via buffered input path. | Adaptations occur at the hardware boundary and in the graph. |
| Observable runtime values                       | `currentTime` and `currentSampleFrame` reflect internal render cursor progression. | They reflect internal block progression, not directly the backend callback `frameCount`. |

### 2 — Binaural / spatial audio specification

This section documents the **effective specification of the binaural and spatial audio system**, as it behaves at runtime within the engine, based on analysis of data flow, implicit preconditions, and integration with the general rendering system.

The goal is not to describe the mathematical HRTF model nor detail internal node implementations, but to **establish the spatial conventions, operational assumptions, and contractual constraints** that an integrator must understand to use spatialization correctly: coordinate system, listener orientation, units of measurement, expected value ranges, sampling timing, and the relationship between sources, listener, and audio backend.

The table organizes this information from a functional perspective—coordinate system, listener, spatial sources, binaural processing, and integration with the final stream—emphasizing **observable behavior**, points where clamping, degradation, or silencing occur, and conditions that, if unmet, violate binaural pipeline preconditions. As such, it serves as a technical reference to avoid ambiguity, facilitate runtime validation, and ensure coherence between the expected acoustic space and the effective render.

|                                           | Effective value / behavior                                  | Notes                                                        |
| ----------------------------------------- | ------------------------------------------------------------ | ------------------------------------------------------------ |
| Coordinate system                          | **Right-handed** coordinate system.                          | Explicitly documented in the listener-facing API.           |
| Orientation / axes                         | Positive X to the right, positive Y up, positive Z backward; perceptual forward corresponds to −Z. | Negative Z values represent positions “in front of” the listener. |
| Forward vector convention                 | `forward = −Z`, per documentation. Calculations use normalized listener forward vector. | An orthonormal basis derived from forward and up vectors is assumed. |
| Up vector convention                      | The up vector is defined by listener state and used to build right and up axes for spatial angle evaluation. | Non-orthogonal vectors are conceptually normalized or orthogonalized. |
| Spatial unit of measure                   | Implicitly meters.                                           | Inferred from parameters such as `speedOfSound` (m/s) and inner/outer radii; no explicit conversion exists. |
| System origin                             | World-centric system.                                       | Source and listener positions are evaluated in the same coordinate space. |
| Listener role                             | Acoustic reference point defining position, orientation, and velocity, along with global parameters such as doppler and speed of sound. | Spatialization is computed relative to the active listener in the graph. |
| Relevant spatial parameters               | `position`, `forward`, `up`, and `velocity`. `doppler` and `speedOfSound` influence doppler behavior. | Sampled from runtime context on render blocks.              |
| Sampling moment                           | Sampled per render block (`frameCount`) during spatial processing. | -                                                            |
| Synchronization requirements              | Listener state must be synchronized before render to keep runtime spatial behavior coherent. | Recommended whenever listener parameters change.            |
| Source definition space                   | World space, with absolute position, orientation, and velocity. | Source vectors are compared directly against listener position. |
| Source → listener relationship            | The vector `(source − listener)` is computed and normalized to obtain azimuth, elevation, and distance. | If the resulting vector is zero, azimuth and elevation are set to 0. |
| Expected value ranges                     | Typical value ranges are broad, with no strict hard clamping on all axes. | Non-finite values are considered invalid for processing.    |
| Out-of-range behavior                     | Elevation is clamped to supported HRTF ranges; out-of-range azimuth may reduce or silence perceived output depending on available data. | Behavior depends on loaded spatial data coverage.           |
| Binaural processing type                  | HRTF processing via FFT convolution, delay lines, and kernel crossfades. | The result is stereo binaural processing.                   |
| Processing domain                         | Frequency domain for convolution with complementary time-domain delay stages. | The pipeline combines frequency- and time-domain processing. |
| Expected sample rate                      | Uses `canonicalSampleRate`. Spatial data is expected to be compatible with supported sample rates. | Incompatible rates are treated as invalid for binaural processing. |
| Channel requirements (in/out)             | Mono or stereo input; strictly stereo output.                | No multichannel output support exists in binaural processing. |
| Implicit assumptions                     | `frameCount` must be a power of two and the binaural data set must be available for real-time render. | Otherwise, spatial output may be reduced or silenced.       |
| Binaural ↔ final stream relationship      | Binaural processing produces a stereo output bus; hardware may apply additional mixing based on final layout. | Interleaving to the final format occurs at the hardware layer. |
| Pre/post conversion                       | No prior format conversion; output is interleaved only at the final stage. | Sample format remains `Float32` until reaching the backend. |
| Backend impact on spatial render          | The backend defines the callback `frameCount`; the panner operates internally in fixed render blocks. | Segmentation and crossfades are conditioned by internal quantum configuration. |

#### Summary

The engine assumes a fixed canonical sample rate (44,100 Hz), planar internal Float32 buffers, and a fixed per-block quantum; it also assumes a right-handed coordinate system with forward = −Z and a global listener provided by the graph. The integrator should assume that the I/O category may degrade based on device availability, and that binaural rendering requires stereo output, block-based timing, and a loaded and compatible HRTF data set. Stable parameters are: Float32 format, planar internal layout, `canonicalSampleRate`, platform-specific `canonicalQuantum`, and coordinate conventions; runtime-varying parameters are: backend callback `frameCount`, effective category (render/record/duplex), and actual input usage when it is not mono.

#### License

This project is distributed under a license that allows its use, modification, and distribution, provided that the specified terms are respected (<http://opensource.org/licenses/mit-license.php>)

Copyright © 2019 - 2027 - ***Comdigis***, *Buenos Aires, Argentina*
