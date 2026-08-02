import Foundation

/// A normalized, non-empty bearer token accepted by app and storage boundaries.
nonisolated struct BearerToken: Equatable, Sendable {
    let rawValue: String

    /// Creates a token from user or stored text, returning `nil` when it is blank.
    init?(_ rawValue: String) {
        let rawValue = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !rawValue.isEmpty else { return nil }
        self.rawValue = rawValue
    }
}
