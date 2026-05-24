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

class BinauralDatabaseLoader {

    // Process-wide HRTF database.
    // All binaural nodes reuse this instance to avoid duplicate loads and
    // to guarantee every processor resolves spatialization from the same dataset.
    static let database = BinauralDatabase(location: URL.HRTF())

    private static var isDatabaseReady = false
    private static let queue = DispatchQueue(label: "com.comdigis.io.database")
    private static var isPreloadInFlight = false
    private static var completions: [(Result<Bool, Error>) -> Void] = []

    enum DatabasePreloadError: LocalizedError {
        case didNotLoad
    }

    static func preload(completion: @escaping (Result<Bool, Error>) -> Void) {
        // Preload requests are serialized through `queue`.
        // If multiple callers ask at startup, only one async load is performed;
        // all waiting completions are resolved with the same normalized result.
        queue.async {
            if isDatabaseReady {
                DispatchQueue.main.async {
                    completion(.success(true))
                }
                return
            }

            completions.append(completion)
            guard !isPreloadInFlight else {
                return
            }

            isPreloadInFlight = true
            database.loadAsynchronously { result in
                queue.async {
                    isPreloadInFlight = false
                    let localCompletions = completions
                    completions.removeAll()

                    let normalizedResult: Result<Bool, Error>
                    // Normalize completion semantics:
                    // - `.success(true)` only when assets are fully loaded.
                    // - explicit failure for false-success and underlying errors.
                    // This keeps window bootstrap logic simple and predictable.
                    switch result {
                    case .success(let loaded) where loaded:
                        isDatabaseReady = true
                        normalizedResult = .success(true)
                    case .success:
                        normalizedResult = .failure(DatabasePreloadError.didNotLoad)
                    case .failure(let error):
                        normalizedResult = .failure(error)
                    }

                    DispatchQueue.main.async {
                        localCompletions.forEach { $0(normalizedResult) }
                    }
                }
            }
        }
    }
}
