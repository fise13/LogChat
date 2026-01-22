//
//  SearchService.swift
//  LogChat
//
//  Created by Виктор on 04.01.2026.
//

import Foundation

struct SearchResult: Codable, Identifiable, Equatable {
    let id: String
    let title: String
    let url: String
    let snippet: String
    let source: String?
    
    init(id: String = UUID().uuidString, title: String, url: String, snippet: String, source: String? = nil) {
        self.id = id
        self.title = title
        self.url = url
        self.snippet = snippet
        self.source = source
    }
}

struct SearchResponse: Codable {
    let results: [SearchResult]
    let query: String
    let totalResults: Int?
}

enum SearchServiceError: LocalizedError {
    case missingAPIKey
    case networkError(String)
    case invalidResponse
    case rateLimited
    
    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "Search API key is not configured"
        case .networkError(let message):
            return "Network error: \(message)"
        case .invalidResponse:
            return "Invalid response from search API"
        case .rateLimited:
            return "Rate limit exceeded. Please try again later"
        }
    }
}

@MainActor
class SearchService {
    static let shared = SearchService()
    
    private var apiKey: String {
        UserDefaults.standard.string(forKey: "searchAPIKey") ?? ""
    }
    private var provider: String {
        UserDefaults.standard.string(forKey: "searchProvider") ?? "serper"
    }
    private var location: String {
        UserDefaults.standard.string(forKey: "searchLocation") ?? "Almaty, Kazakhstan"
    }
    
    private let cache = NSCache<NSString, NSData>()
    private let cacheTimeout: TimeInterval = 3600 // 1 hour
    private let requestTimeout: TimeInterval = 30 // 30 seconds
    private let maxRetries: Int = 2
    
    private init() {
        cache.countLimit = 50
    }
    
    // MARK: - Public API
    
    func search(query: String, location: String? = nil, limit: Int = 10) async throws -> SearchResponse {
        guard !apiKey.isEmpty else {
            throw SearchServiceError.missingAPIKey
        }
        
        // Check cache
        let searchLocation = location ?? self.location
        let cacheKey = "\(query)_\(searchLocation)_\(String(limit))" as NSString
        if let cachedData = cache.object(forKey: cacheKey),
           let cached = try? JSONDecoder().decode(SearchResponse.self, from: cachedData as Data) {
            return cached
        }
        
        // Retry logic
        var lastError: Error?
        for attempt in 0...maxRetries {
            do {
                let response: SearchResponse
                
                switch provider {
                case "serper":
                    response = try await searchWithSerper(query: query, location: searchLocation, limit: limit)
                case "contextualweb":
                    response = try await searchWithContextualWeb(query: query, location: searchLocation, limit: limit)
                default:
                    response = try await searchWithSerper(query: query, location: searchLocation, limit: limit)
                }
                
                // Cache the result
                if let data = try? JSONEncoder().encode(response) {
                    cache.setObject(data as NSData, forKey: cacheKey)
                }
                
                return response
            } catch {
                lastError = error
                
                // Don't retry on certain errors
                if let searchError = error as? SearchServiceError {
                    switch searchError {
                    case .missingAPIKey:
                        throw searchError
                    case .rateLimited:
                        // Wait before retrying rate limit errors
                        if attempt < maxRetries {
                            try? await Task.sleep(nanoseconds: UInt64(2_000_000_000 * UInt64(attempt + 1))) // Exponential backoff
                            continue
                        }
                        throw searchError
                    default:
                        break
                    }
                }
                
                // Retry on network errors
                if attempt < maxRetries {
                    try? await Task.sleep(nanoseconds: UInt64(1_000_000_000 * UInt64(attempt + 1))) // Exponential backoff
                    continue
                }
            }
        }
        
        throw lastError ?? SearchServiceError.networkError("Unknown error")
    }
    
    func updateAPIKey(_ key: String) {
        UserDefaults.standard.set(key, forKey: "searchAPIKey")
    }
    
    func updateProvider(_ provider: String) {
        UserDefaults.standard.set(provider, forKey: "searchProvider")
    }
    
    func updateLocation(_ location: String) {
        UserDefaults.standard.set(location, forKey: "searchLocation")
    }
    
    /// Проверяет валидность API ключа
    func testAPIKey() async -> Bool {
        guard !apiKey.isEmpty else {
            return false
        }
        
        do {
            // Простой тестовый запрос
            _ = try await search(query: "test", limit: 1)
            return true
        } catch {
            return false
        }
    }
    
    /// Получает статус конфигурации
    var isConfigured: Bool {
        !apiKey.isEmpty
    }
    
    // MARK: - Private Implementation
    
    private func searchWithSerper(query: String, location: String, limit: Int) async throws -> SearchResponse {
        guard let url = URL(string: "https://google.serper.dev/search") else {
            throw SearchServiceError.invalidResponse
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "X-API-KEY")
        request.timeoutInterval = requestTimeout
        
        let requestBody: [String: Any] = [
            "q": query,
            "num": limit,
            "gl": "kz", // Kazakhstan
            "hl": "ru" // Russian language
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw SearchServiceError.invalidResponse
            }
            
            if httpResponse.statusCode == 429 {
                throw SearchServiceError.rateLimited
            }
            
            guard httpResponse.statusCode == 200 else {
                throw SearchServiceError.networkError("HTTP \(httpResponse.statusCode)")
            }
            
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            
            var results: [SearchResult] = []
            
            if let organic = json?["organic"] as? [[String: Any]] {
                for item in organic {
                    if let title = item["title"] as? String,
                       let link = item["link"] as? String,
                       let snippet = item["snippet"] as? String {
                        results.append(SearchResult(
                            title: title,
                            url: link,
                            snippet: snippet,
                            source: item["source"] as? String
                        ))
                    }
                }
            }
            
            let totalResults: Int? = {
                if let searchInfo = json?["searchInformation"] as? [String: Any],
                   let total = searchInfo["totalResults"] as? String {
                    return Int(total)
                }
                return nil
            }()
            
            return SearchResponse(
                results: results,
                query: query,
                totalResults: totalResults
            )
        } catch let error as SearchServiceError {
            throw error
        } catch {
            throw SearchServiceError.networkError(error.localizedDescription)
        }
    }
    
    private func searchWithContextualWeb(query: String, location: String, limit: Int) async throws -> SearchResponse {
        guard let url = URL(string: "https://api.contextualwebsearch.com/v1/search") else {
            throw SearchServiceError.invalidResponse
        }
        
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "pageNumber", value: "1"),
            URLQueryItem(name: "pageSize", value: "\(limit)"),
            URLQueryItem(name: "autoCorrect", value: "true"),
            URLQueryItem(name: "safeSearch", value: "false")
        ]
        
        guard let finalURL = components?.url else {
            throw SearchServiceError.invalidResponse
        }
        
        var request = URLRequest(url: finalURL)
        request.setValue(apiKey, forHTTPHeaderField: "X-RapidAPI-Key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = requestTimeout
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw SearchServiceError.invalidResponse
            }
            
            if httpResponse.statusCode == 429 {
                throw SearchServiceError.rateLimited
            }
            
            guard httpResponse.statusCode == 200 else {
                throw SearchServiceError.networkError("HTTP \(httpResponse.statusCode)")
            }
            
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            
            var results: [SearchResult] = []
            
            if let value = json?["value"] as? [[String: Any]] {
                for item in value {
                    if let title = item["title"] as? String,
                       let urlString = item["url"] as? String,
                       let description = item["description"] as? String {
                        let sourceName: String? = {
                            if let provider = item["provider"] as? [String: Any],
                               let name = provider["name"] as? String {
                                return name
                            }
                            return nil
                        }()
                        
                        results.append(SearchResult(
                            title: title,
                            url: urlString,
                            snippet: description,
                            source: sourceName
                        ))
                    }
                }
            }
            
            let totalResults = json?["totalCount"] as? Int
            
            return SearchResponse(
                results: results,
                query: query,
                totalResults: totalResults
            )
        } catch let error as SearchServiceError {
            throw error
        } catch {
            throw SearchServiceError.networkError(error.localizedDescription)
        }
    }
}

