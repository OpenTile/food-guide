import ComposableArchitecture
import Foundation

/// Retrieves Entries from the backend using the saved bearer token.
@DependencyClient
nonisolated struct EntryClient {
    var list: @Sendable (_ dayWindow: DayWindow, _ bearerToken: BearerToken) async throws -> [Entry]
}

extension EntryClient: DependencyKey {
    static var liveValue: Self {
        Self(list: LiveEntryClient.list)
    }
}

private nonisolated enum LiveEntryClient {
    enum ClientError: Error {
        case invalidResponse
        case invalidURL
    }

    static func list(
        dayWindow: DayWindow,
        bearerToken: BearerToken
    ) async throws -> [Entry] {
        guard var components = URLComponents(
            url: AppConfiguration.backendBaseURL.appendingPathComponent("entries"),
            resolvingAgainstBaseURL: false
        ) else {
            throw ClientError.invalidURL
        }
        components.queryItems = [
            URLQueryItem(name: "from", value: instantString(dayWindow.from)),
            URLQueryItem(name: "to", value: instantString(dayWindow.to)),
        ]
        guard let url = components.url else {
            throw ClientError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue(
            "Bearer \(bearerToken.rawValue)",
            forHTTPHeaderField: "Authorization"
        )
        let (data, response) = try await URLSession.shared.data(for: request)
        guard
            let response = response as? HTTPURLResponse,
            200..<300 ~= response.statusCode
        else {
            throw ClientError.invalidResponse
        }

        let entries = try JSONDecoder().decode([EntryResponse].self, from: data)
        let formatter = makeInstantFormatter()
        return try entries.map { entry in
            guard let eatenAt = formatter.date(from: entry.eatenAt) else {
                throw ClientError.invalidResponse
            }
            return Entry(id: entry.id, text: entry.text, eatenAt: eatenAt)
        }
    }

    private static func instantString(_ date: Date) -> String {
        makeInstantFormatter().string(from: date)
    }

    private static func makeInstantFormatter() -> ISO8601DateFormatter {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }

    private struct EntryResponse: Decodable {
        let id: UUID
        let text: String
        let eatenAt: String
    }
}
