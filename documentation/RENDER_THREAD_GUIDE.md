#### Considerations for the audio render thread

The *render thread* of an audio engine is the core where real-time sample processing takes place. It operates under a deterministic execution model, with a fixed time interval between each invocation (blocks of 64, 128, or 512 frames depending on the hardware). Any operation that breaks this temporal determinism—through blocking, latency, or unpredictable allocation—degrades the continuous audio flow, producing audible artifacts or complete stream dropouts. The primary objective of this document is to ensure that the *render thread* is never interrupted, blocked, or forced to wait on non-deterministic resources from the operating system or the engine itself.

#### **Dynamic allocations and memory management**

Any form of **dynamic allocation on the render thread is prohibited**. This includes direct or indirect calls to *heap* mechanisms (`malloc`, `new`, `allocate`, `calloc`, `realloc`, `free`, or equivalent runtime-managed allocations).

Each of these operations may:

- Block the global *heap lock*.
- Trigger page faults.
- Cause severe cache misses.
- Introduce non-predictable latency in an environment that requires microsecond-level precision.

The *render thread* must operate exclusively on **preallocated and persistent memory structures**, with fixed size and direct access. Any temporary buffer, working structure, or intermediate vector must have been allocated before audio processing begins, typically during the graph’s `prepare()` or `initialize()` phase. In this context, **a dynamic allocation is equivalent to a real-time violation**, even if it occurs sporadically or appears harmless.

#### **Buffer underrun and overrun on the render thread**

A **buffer underrun** occurs when the render thread attempts to consume more data than the producer has filled, resulting in invalid samples, discontinuities, or silence. A **buffer overrun**, conversely, occurs when the producer attempts to write more data than the buffer can hold before the consumer reads it.

Both situations represent critical synchronization and memory failures.

Their consequences include:

- *Clicks*, *pops*, or transient noise.
- Pointer overruns and memory corruption.
- Channel desynchronization (for example, in stereo or binaural systems).
- Progressive instability of the audio graph.

Mitigating these errors requires:

- Strict validation of read/write indices in circular buffers.
- Explicit control of `frameCount` on each render iteration.
- *Graceful recovery* mechanisms in the event of underrun, returning null samples instead of invalid data.
- Guarantees that pointers never advance beyond the buffer `capacity` nor move in a negative direction.

The system must be designed so that **the graph topology can never cause an imbalance between producers and consumers** within the same render quantum.

#### **Priority inversion**

**Priority inversion** occurs when a low-priority thread holds a resource (for example, a mutex or spinlock) that the *render thread* requires. As a result, the higher-priority thread—responsible for real-time audio—becomes blocked while waiting, breaking the processing cadence and producing an audible dropout. In audio systems, this is considered a severe concurrency design violation.

The *render thread* must never depend on:

- General-purpose locks (`pthread_mutex`, `NSLock`, `DispatchSemaphore`).
- Thread-safe containers that internally lock shared resources.
- Synchronization mechanisms that allow active waiting or conditional blocking.

Shared access must be implemented using **lock-free** or **wait-free** strategies, such as:

- Atomic variables.
- *Single-producer / single-consumer ring buffers*.
- Snapshots or immutable memory copies.

If the engine architecture requires synchronization with other threads (for example, to update parameters from the UI), it must be done through **one-way messaging mechanisms**, never via direct waiting. The *render thread* must not relinquish its temporal control under any circumstances.

#### **Starvation of critical tasks**

**Starvation** occurs when the *render thread* does not receive sufficient CPU time due to contention with other threads or processes of lower priority that occupy scheduler resources. Even with real-time scheduling, this can happen if:

- Other threads execute intensive tasks without explicit *yield*.
- Global queues are used with inappropriate priorities.
- There is an excess of threads with similar priority on the same logical core.
- The operating system reassigns CPU affinity under thermal or power pressure.

The result is disruption of the audio cycle, manifested as intermittent sample loss. 

To prevent this:

- The *render thread* must run with **real-time priority** using the best-practice policy for each target system.
- Auxiliary threads (for example, analysis, UI, or logging) must operate at **significantly lower priority levels**.
- No I/O operations, logging, or metrics collection should coexist on the same thread that performs rendering.
- Maintenance tasks (cleanup, GC, or deallocation) must be deferred to *background threads*.

Proper scheduling ensures that no non-critical task competes for CPU time with the audio engine.

#### **Instrumentation**

Early detection of non-deterministic behavior on the *render thread* is essential to guarantee temporal stability and perceptual integrity of the audio output. Because the render thread operates under strict real-time constraints, any instruction that triggers dynamic allocation, resource locking, or I/O waiting can interrupt processing continuity and degrade audio quality. An effective strategy to mitigate these risks is to **audit, instrument, and systematically monitor** the entire execution flow—from render entry down to internal `process()` calls—in order to identify points where unsafe operations or dependencies on non-deterministic subsystems occur.

In summary, best practices include:

1. **Structural auditing**: Review the full render-thread *call stack* to detect calls that may involve *heap allocation*, *locking*, or *I/O*.
2. **Targeted instrumentation**: Use allocation and time profilers with wait-state visibility to identify unsafe behavior during render time.
3. **Execution guards**: Implement an audio-thread verifier that asserts on unsafe operations within the render context.
4. **Static analysis and runtime logging**: Search for dangerous constructs (dynamic collections, debug printing, global queue dispatch) inside `process()`, and trace when they are invoked during render.
5. **High-priority stress testing**: Run prolonged render loops under constrained CPU conditions to detect real *starvation* or *priority inversion* scenarios under load.

#### **Conclusion**

The render thread must be treated as an **absolute real-time zone**, where conventional programming rules do not apply. The design must assume that any blocking, dynamic allocation, or non-deterministic access can interrupt audio continuity. 

In summary:

- **No heap allocations.**
- **No blocking locks.**
- **No non-deterministic synchronization.**
- **No dependency on lower-priority tasks.**

All processing must be predictable, bounded, and based on preallocated memory. Any operation that does not meet these principles must be moved to a lower-priority context, outside the render thread.

Only in this way can the temporal and perceptual integrity of real-time audio signals be guaranteed.

#### License

This project is distributed under a license that allows its use, modification, and distribution, provided that the specified terms are respected (<http://opensource.org/licenses/mit-license.php>)

Copyright © 2019 - 2027 - ***Comdigis***, *Buenos Aires, Argentina*
