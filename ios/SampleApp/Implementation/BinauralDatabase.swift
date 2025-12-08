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
    
    static let database = BinauralDatabase(location: URL.HRTF())
    
    private static var isLoading = false
    private static let queue = DispatchQueue(label: "com.comdigis.io.database")
    private static var isLoaded = false
    private static var completions: [(Result<Bool, Error>) -> Void] = []
    
    enum DatabasePreloadError: LocalizedError {
        case didNotLoad
    }

    // Serialize preload calls through a dedicated queue and fan out the normalized
    // result to all waiting completions. This keeps database boot deterministic for UI flows.
    static func preload(completion: @escaping (Result<Bool, Error>) -> Void) {
        queue.async {
            if isLoading {
                DispatchQueue.main.async {
                    completion(.success(true))
                }
                return
            }

            completions.append(completion)
            guard !isLoaded else { return }
            isLoaded = true

            database.loadAsynchronously { result in
                queue.async {
                    isLoaded = false
                    let localCompletions = completions
                    completions.removeAll()

                    // Normalize loader output so callers handle a single success
                    // path and explicit failures for "did not load" or underlying errors.
                    let normalizedResult: Result<Bool, Error>
                    switch result {
                    case .success(let loaded) where loaded:
                        isLoading = true
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
