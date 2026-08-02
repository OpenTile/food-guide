// © 2026 Andrei Chenchik. All rights reserved.
// Unauthorized using, copying, distribution, or modification prohibited.

import Foundation

nonisolated enum AppConfiguration {
    /// The backend URL supplied by the active Xcode build configuration.
    static var backendBaseURL: URL {
        guard
            let value = Bundle.main.object(forInfoDictionaryKey: "BackendBaseURL") as? String,
            let url = URL(string: value)
        else {
            preconditionFailure("BackendBaseURL is missing from the active build configuration")
        }
        return url
    }
}
