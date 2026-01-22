//
//  CacheService.swift
//  LogChat
//
//  Created by Виктор on 04.01.2026.
//

import Foundation

struct CachedResponse: Codable {
    let query: String
    let response: String
    let timestamp: Date
    let mode: String
}

class CacheService {
    static let shared = CacheService()
    
    private let cacheKey = "cached_responses"
    private var cache: [String: CachedResponse] = [:]
    private let maxCacheSize = 100
    
    init() {
        loadCache()
    }
    
    private func loadCache() {
        if let data = UserDefaults.standard.data(forKey: cacheKey),
           let decoded = try? JSONDecoder().decode([String: CachedResponse].self, from: data) {
            cache = decoded
        }
    }
    
    private func saveCache() {
        if let encoded = try? JSONEncoder().encode(cache) {
            UserDefaults.standard.set(encoded, forKey: cacheKey)
        }
    }
    
    func getCacheKey(query: String, mode: String) -> String {
        return "\(mode):\(query.hashValue)"
    }
    
    func getCachedResponse(query: String, mode: String) -> String? {
        let key = getCacheKey(query: query, mode: mode)
        if let cached = cache[key],
           Date().timeIntervalSince(cached.timestamp) < 3600 { // Кэш на 1 час
            return cached.response
        }
        return nil
    }
    
    func cacheResponse(query: String, response: String, mode: String) {
        let key = getCacheKey(query: query, mode: mode)
        cache[key] = CachedResponse(query: query, response: response, timestamp: Date(), mode: mode)
        
        // Ограничиваем размер кэша
        if cache.count > maxCacheSize {
            let sorted = cache.sorted { $0.value.timestamp < $1.value.timestamp }
            for (key, _) in sorted.prefix(cache.count - maxCacheSize) {
                cache.removeValue(forKey: key)
            }
        }
        
        saveCache()
    }
    
    func clearCache() {
        cache.removeAll()
        saveCache()
    }
}

