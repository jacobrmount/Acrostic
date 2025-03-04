// API/NotionAPIClient.swift

import Foundation

public class NotionAPIClient {
    internal let baseURL = "https://api.notion.com/v1"
    internal let token: String
    internal let session: URLSession

    public init(token: String, session: URLSession = .shared) {
        self.token = token
        self.session = session
    }
    
    internal var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        let formatter = ISO8601DateFormatter()
        // Include fractional seconds in the date format.
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)
            if let date = formatter.date(from: dateString) {
                return date
            }
            throw DecodingError.dataCorruptedError(in: container,
                                                   debugDescription: "Expected date string to be ISO8601-formatted.")
        }
        return decoder
    }
    
    /// Validates an HTTP response.
    internal func validate(response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else {
            throw NotionAPIError.invalidResponse
        }
        guard (200...299).contains(http.statusCode) else {
            if let errorResponse: NotionErrorResponse = try? decoder.decode(NotionErrorResponse.self, from: data) {
                throw NotionAPIError.httpError(statusCode: http.statusCode,
                                               message: errorResponse.message ?? "Unknown error",
                                               code: errorResponse.code)
            }
            let message = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw NotionAPIError.httpError(statusCode: http.statusCode,
                                           message: message,
                                           code: nil as String?)
        }
    }
}
