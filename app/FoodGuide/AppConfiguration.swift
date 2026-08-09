import Foundation

nonisolated enum AppConfiguration {
    /// The staging URL for Debug builds and production URL for Release builds.
    static let backendBaseURL: URL = {
        guard
            let fileURL = Bundle.main.url(forResource: "Config", withExtension: "plist"),
            let data = try? Data(contentsOf: fileURL),
            let values = try? PropertyListDecoder().decode(Values.self, from: data)
        else {
            preconditionFailure(
                "Config.plist is missing or invalid; copy Config.example.plist and configure it"
            )
        }

        #if DEBUG
        let value = values.stagingBackendBaseURL
        #else
        let value = values.productionBackendBaseURL
        #endif

        guard let url = URL(string: value), url.scheme == "https", url.host != nil else {
            preconditionFailure("The backend URL in Config.plist must be a valid HTTPS URL")
        }
        return url
    }()

    private struct Values: Decodable {
        let productionBackendBaseURL: String
        let stagingBackendBaseURL: String

        enum CodingKeys: String, CodingKey {
            case productionBackendBaseURL = "ProductionBackendBaseURL"
            case stagingBackendBaseURL = "StagingBackendBaseURL"
        }
    }
}
