// API/NotionAPIError.swift
import Foundation

public enum NotionAPIError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(statusCode: Int, message: String, code: String?)
    case decodingError(Error)
    case requestFailed(Error)
    
    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "The URL is invalid."
        case .invalidResponse:
            return "The response is invalid."
        case .httpError(let statusCode, let message, let code):
            if let code = code {
                return "HTTP Error \(statusCode) (\(code)): \(message)"
            } else {
                return "HTTP Error \(statusCode): \(message)"
            }
        case .decodingError(let error):
            return "Decoding error: \(error.localizedDescription)"
        case .requestFailed(let error):
            return "Request failed: \(error.localizedDescription)"
        }
    }
}

public struct NotionErrorResponse: Codable {
    public let code: String?
    public let message: String?
}
