import ComposableArchitecture
import Foundation

/// Creates, deletes, and retrieves Entries using a supplied bearer token.
@DependencyClient
nonisolated struct EntryClient {
    var create: @Sendable (_ submission: DraftSubmission, _ bearerToken: BearerToken) async throws -> Entry
    var delete: @Sendable (_ entryID: Entry.ID, _ bearerToken: BearerToken) async throws -> Void
    var list: @Sendable (_ dayWindow: DayWindow, _ bearerToken: BearerToken) async throws -> [Entry]
}

extension EntryClient: DependencyKey {
    static var liveValue: Self {
        Self(
            create: LiveEntryClient.create,
            delete: LiveEntryClient.delete,
            list: LiveEntryClient.list
        )
    }
}

private nonisolated enum LiveEntryClient {
    enum ClientError: Error {
        case invalidResponse
        case invalidURL
    }

    static func create(
        submission: DraftSubmission,
        bearerToken: BearerToken
    ) async throws -> Entry {
        let url = AppConfiguration.backendBaseURL.appendingPathComponent("entries")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = try JSONEncoder().encode(
            EntryRequest(
                id: submission.id,
                text: submission.text,
                eatenAt: instantString(submission.eatenAt)
            )
        )
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let data = try await authenticatedData(for: request, bearerToken: bearerToken)

        return try decodeEntry(JSONDecoder().decode(EntryResponse.self, from: data))
    }

    static func delete(
        entryID: Entry.ID,
        bearerToken: BearerToken
    ) async throws {
        let url = AppConfiguration.backendBaseURL
            .appendingPathComponent("entries")
            .appendingPathComponent(entryID.uuidString)
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"

        _ = try await authenticatedData(for: request, bearerToken: bearerToken)
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

        let request = URLRequest(url: url)
        let data = try await authenticatedData(for: request, bearerToken: bearerToken)

        let entries = try JSONDecoder().decode([EntryResponse].self, from: data)
        return try entries.map(decodeEntry)
    }

    private static func authenticatedData(
        for request: URLRequest,
        bearerToken: BearerToken
    ) async throws -> Data {
        var request = request
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
        return data
    }

    private static func decodeEntry(_ response: EntryResponse) throws -> Entry {
        guard let eatenAt = makeInstantFormatter().date(from: response.eatenAt) else {
            throw ClientError.invalidResponse
        }
        return Entry(id: response.id, text: response.text, eatenAt: eatenAt)
    }

    private static func instantString(_ instant: Date) -> String {
        makeInstantFormatter().string(from: instant)
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

    private struct EntryRequest: Encodable {
        let id: UUID
        let text: String
        let eatenAt: String
    }
}
