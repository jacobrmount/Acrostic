// API/NotionAPIClient+GET.swift
import Foundation

public extension NotionAPIClient {
    
    func retrieveDatabase(databaseID: String) async throws -> NotionDatabase {
        guard let url = URL(string: "\(baseURL)/databases/\(databaseID)") else {
            throw NotionAPIError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("2022-06-28", forHTTPHeaderField: "Notion-Version")
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await session.data(for: request)
        try validate(response: response, data: data)
        do {
            let database = try decoder.decode(NotionDatabase.self, from: data)
            return database
        } catch {
            throw NotionAPIError.decodingError(error)
        }
    }
    
    func retrievePage(pageID: String) async throws -> NotionPage {
        guard let url = URL(string: "\(baseURL)/pages/\(pageID)") else {
            throw NotionAPIError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("2022-06-28", forHTTPHeaderField: "Notion-Version")
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await session.data(for: request)
        try validate(response: response, data: data)
        do {
            let page = try decoder.decode(NotionPage.self, from: data)
            return page
        } catch {
            throw NotionAPIError.decodingError(error)
        }
    }
    
    func retrievePagePropertyItem(pageID: String, propertyID: String, pageSize: Int? = nil, startCursor: String? = nil) async throws -> NotionPropertyItemResponse {
        var urlString = "\(baseURL)/pages/\(pageID)/properties/\(propertyID)"
        var queryItems = [URLQueryItem]()
        if let pageSize = pageSize {
            queryItems.append(URLQueryItem(name: "page_size", value: "\(pageSize)"))
        }
        if let startCursor = startCursor {
            queryItems.append(URLQueryItem(name: "start_cursor", value: startCursor))
        }
        if !queryItems.isEmpty, var components = URLComponents(string: urlString) {
            components.queryItems = queryItems
            if let newURL = components.url {
                urlString = newURL.absoluteString
            }
        }
        guard let url = URL(string: urlString) else {
            throw NotionAPIError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("2022-06-28", forHTTPHeaderField: "Notion-Version")
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await session.data(for: request)
        try validate(response: response, data: data)
        do {
            let propertyItemResponse = try decoder.decode(NotionPropertyItemResponse.self, from: data)
            return propertyItemResponse
        } catch {
            throw NotionAPIError.decodingError(error)
        }
    }
    
    func retrieveBlock(blockID: String) async throws -> NotionBlock {
        guard let url = URL(string: "\(baseURL)/blocks/\(blockID)") else {
            throw NotionAPIError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("2022-06-28", forHTTPHeaderField: "Notion-Version")
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await session.data(for: request)
        try validate(response: response, data: data)
        do {
            let block = try decoder.decode(NotionBlock.self, from: data)
            return block
        } catch {
            throw NotionAPIError.decodingError(error)
        }
    }
    
    func retrieveBlockChildren(blockID: String, pageSize: Int? = nil, startCursor: String? = nil) async throws -> NotionBlockChildrenResponse {
        var urlString = "\(baseURL)/blocks/\(blockID)/children"
        var queryItems = [URLQueryItem]()
        if let pageSize = pageSize {
            queryItems.append(URLQueryItem(name: "page_size", value: "\(pageSize)"))
        }
        if let startCursor = startCursor {
            queryItems.append(URLQueryItem(name: "start_cursor", value: startCursor))
        }
        if !queryItems.isEmpty, var components = URLComponents(string: urlString) {
            components.queryItems = queryItems
            if let newURL = components.url {
                urlString = newURL.absoluteString
            }
        }
        guard let url = URL(string: urlString) else {
            throw NotionAPIError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("2022-06-28", forHTTPHeaderField: "Notion-Version")
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await session.data(for: request)
        try validate(response: response, data: data)
        do {
            let childrenResponse = try decoder.decode(NotionBlockChildrenResponse.self, from: data)
            return childrenResponse
        } catch {
            throw NotionAPIError.decodingError(error)
        }
    }
    
    func retrieveComments(blockID: String, pageSize: Int? = nil, startCursor: String? = nil) async throws -> NotionCommentListResponse {
        var urlString = "\(baseURL)/comments"
        var queryItems = [URLQueryItem(name: "block_id", value: blockID)]
        if let pageSize = pageSize {
            queryItems.append(URLQueryItem(name: "page_size", value: "\(pageSize)"))
        }
        if let startCursor = startCursor {
            queryItems.append(URLQueryItem(name: "start_cursor", value: startCursor))
        }
        if !queryItems.isEmpty, var components = URLComponents(string: urlString) {
            components.queryItems = queryItems
            if let newURL = components.url {
                urlString = newURL.absoluteString
            }
        }
        guard let url = URL(string: urlString) else {
            throw NotionAPIError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("2022-06-28", forHTTPHeaderField: "Notion-Version")
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await session.data(for: request)
        try validate(response: response, data: data)
        do {
            let commentsResponse = try decoder.decode(NotionCommentListResponse.self, from: data)
            return commentsResponse
        } catch {
            throw NotionAPIError.decodingError(error)
        }
    }
    
    func retrieveUser(userID: String) async throws -> NotionUser {
        guard let url = URL(string: "\(baseURL)/users/\(userID)") else {
            throw NotionAPIError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("2022-06-28", forHTTPHeaderField: "Notion-Version")
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await session.data(for: request)
        try validate(response: response, data: data)
        let user = try decoder.decode(NotionUser.self, from: data)
        return user
    }
    
    func retrieveBotUser() async throws -> NotionUser {
        guard let url = URL(string: "\(baseURL)/users/me") else {
            throw NotionAPIError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("2022-06-28", forHTTPHeaderField: "Notion-Version")
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await session.data(for: request)
        try validate(response: response, data: data)
        let user = try decoder.decode(NotionUser.self, from: data)
        return user
    }
    
    func listUsers(pageSize: Int? = nil, startCursor: String? = nil) async throws -> NotionUserListResponse {
        var urlString = "\(baseURL)/users"
        var queryItems = [URLQueryItem]()
        if let pageSize = pageSize {
            queryItems.append(URLQueryItem(name: "page_size", value: "\(pageSize)"))
        }
        if let startCursor = startCursor {
            queryItems.append(URLQueryItem(name: "start_cursor", value: startCursor))
        }
        if !queryItems.isEmpty, var components = URLComponents(string: urlString) {
            components.queryItems = queryItems
            if let newURL = components.url {
                urlString = newURL.absoluteString
            }
        }
        guard let url = URL(string: urlString) else {
            throw NotionAPIError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("2022-06-28", forHTTPHeaderField: "Notion-Version")
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await session.data(for: request)
        try validate(response: response, data: data)
        do {
            let userList = try decoder.decode(NotionUserListResponse.self, from: data)
            return userList
        } catch {
            throw NotionAPIError.decodingError(error)
        }
    }
}
