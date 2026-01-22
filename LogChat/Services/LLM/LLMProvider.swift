//
//  LLMProvider.swift
//  LogChat
//
//  Created by Виктор on 04.01.2026.
//

import Foundation

/// Request structure for LLM calls
struct LLMRequest {
    let messages: [Message]
    let model: LLMModel
    let mode: AIMode
    let imageData: Data?
    let memoryContext: String?
    let webSearchContext: String?
    let temperature: Double?
    let maxTokens: Int?
}

/// Response structure (legacy - use LLMResult for new code)
struct LLMResponse {
    let content: String
    let model: String
    let usage: TokenUsage?
}

/// Protocol for LLM providers
protocol LLMProvider {
    var providerType: LLMProviderType { get }
    var isAvailable: Bool { get }
    
    /// Get API key for this provider
    func getAPIKey() -> String?
    
    /// Set API key for this provider
    func setAPIKey(_ key: String)
    
    /// Send a message and return streaming response
    func sendMessage(_ request: LLMRequest) async throws -> AsyncThrowingStream<String, Error>
    
    /// Check if provider is configured (has API key)
    func isConfigured() -> Bool
}

/// Base implementation with common functionality
class BaseLLMProvider: LLMProvider {
    let providerType: LLMProviderType
    
    var isAvailable: Bool {
        isConfigured()
    }
    
    private var apiKeyStorageKey: String {
        "\(providerType.rawValue)APIKey"
    }
    
    init(providerType: LLMProviderType) {
        self.providerType = providerType
    }
    
    func getAPIKey() -> String? {
        // Try Keychain first
        if let key = SecurityService.shared.getAPIKey(forProvider: providerType.rawValue) {
            return key
        }
        // Fallback to UserDefaults for backward compatibility
        return UserDefaults.standard.string(forKey: apiKeyStorageKey)
    }
    
    func setAPIKey(_ key: String) {
        // Save to Keychain
        _ = SecurityService.shared.saveAPIKey(key, forProvider: providerType.rawValue)
        // Also save to UserDefaults for backward compatibility
        UserDefaults.standard.set(key, forKey: apiKeyStorageKey)
    }
    
    func isConfigured() -> Bool {
        guard let key = getAPIKey() else { return false }
        return !key.isEmpty
    }
    
    func sendMessage(_ request: LLMRequest) async throws -> AsyncThrowingStream<String, Error> {
        throw LLMProviderError.notImplemented
    }
    
    /// Build system prompt from mode and contexts
    func buildSystemPrompt(mode: AIMode, memoryContext: String?, webSearchContext: String?) -> String {
        var systemPrompt = mode.systemPrompt
        
        if let memoryContext = memoryContext, !memoryContext.isEmpty {
            systemPrompt += "\n\n" + memoryContext
        }
        
        if let webSearchContext = webSearchContext, !webSearchContext.isEmpty {
            systemPrompt += "\n\n--- WEB SEARCH RESULTS ---\n"
            systemPrompt += webSearchContext
            systemPrompt += "\n--- END WEB SEARCH RESULTS ---\n"
            systemPrompt += "\nUse the web search results above to provide accurate, up-to-date information. Always cite sources when using this information."
        }
        
        if memoryContext != nil && !memoryContext!.isEmpty {
            systemPrompt += "\n\nТы — персональный AI-ассистент. Ты постепенно узнаёшь о пользователе, сохраняешь важную информацию и используешь её для лучшей помощи. Ты никогда не скрываешь, что помнишь о пользователе. Используй предоставленный контекст памяти для персонализации ответов."
        }
        
        systemPrompt += "\n\nСТРУКТУРИРОВАНИЕ ОТВЕТОВ:\n"
        systemPrompt += "- Используй **жирный** для основных пунктов и сути\n"
        systemPrompt += "- Используй *курсив* для пояснений и уточнений\n"
        systemPrompt += "- Используй цветовые индикаторы: 🔵 анализ, 🟠 уточнение, 🟣 исследование, 🟢 результат\n"
        systemPrompt += "- Структурируй сложную информацию с помощью разделов и списков\n"
        systemPrompt += "- Форматируй код в блоках с указанием языка\n"
        systemPrompt += "\nПРОЗРАЧНОСТЬ:\n"
        systemPrompt += "- Будь честен о своих ограничениях\n"
        systemPrompt += "- Не повторяй уже данное объяснение\n"
        systemPrompt += "- Прозрачно показывай память и используемые данные\n"
        systemPrompt += "- Проактивные подсказки — аккуратно, без навязчивости"
        
        return systemPrompt
    }
}

enum LLMProviderError: LocalizedError {
    case notImplemented
    case missingAPIKey
    case invalidURL
    case requestFailed(statusCode: Int?)
    case requestFailedWithMessage(statusCode: Int, message: String)
    case networkError(Error)
    case timeout
    case invalidResponse
    case decodingError(Error)
    
    var errorDescription: String? {
        switch self {
        case .notImplemented:
            return "Provider not implemented"
        case .missingAPIKey:
            return "API ключ не установлен. Пожалуйста, установите его в настройках."
        case .invalidURL:
            return "Неверный URL"
        case .requestFailed(let statusCode):
            if let code = statusCode {
                switch code {
                case 401:
                    return "Неверный API ключ. Проверьте ключ в настройках."
                case 402:
                    return "Недостаточно средств на балансе. Пополните баланс в кабинете провайдера."
                case 429:
                    return "Превышен лимит запросов. Попробуйте позже."
                default:
                    return "Ошибка запроса к API (код: \(code))"
                }
            }
            return "Ошибка запроса к API"
        case .requestFailedWithMessage(let statusCode, let message):
            switch statusCode {
            case 401:
                return "Неверный API ключ: \(message)"
            case 402:
                return "Недостаточно средств: \(message). Пополните баланс в кабинете провайдера."
            case 429:
                return "Превышен лимит запросов: \(message). Попробуйте позже."
            default:
                return "Ошибка запроса к API (код: \(statusCode)): \(message)"
            }
        case .networkError(let error):
            return "Ошибка сети: \(error.localizedDescription)"
        case .timeout:
            return "Превышено время ожидания ответа"
        case .invalidResponse:
            return "Неверный формат ответа от сервера"
        case .decodingError(let error):
            return "Ошибка обработки ответа: \(error.localizedDescription)"
        }
    }
}
