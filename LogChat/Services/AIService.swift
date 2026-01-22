//
//  AIService.swift
//  LogChat
//
//  Created by Виктор on 04.01.2026.
//

import Foundation

@MainActor
class AIService {
    static let shared = AIService()
    
    private let llmService = LLMService.shared
    
    private init() {}
    
    func updateAPIKey(_ key: String) {
        // Backward compatibility - update OpenRouter key
        llmService.setAPIKey(key, for: .openRouter)
    }
    
    func sendMessage(
        messages: [Message],
        mode: AIMode,
        model: LLMModel? = nil,
        imageData: Data? = nil,
        memoryContext: String? = nil,
        webSearchContext: String? = nil
    ) async throws -> AsyncThrowingStream<String, Error> {
        // Use provided model or default
        let selectedModel = model ?? LLMModel.defaultModel
        
        let request = LLMRequest(
            messages: messages,
            model: selectedModel,
            mode: mode,
            imageData: imageData,
            memoryContext: memoryContext,
            webSearchContext: webSearchContext,
            temperature: nil,
            maxTokens: nil
        )
        
        do {
            return try await llmService.sendMessage(request)
        } catch let error as LLMProviderError {
            // Convert LLMProviderError to AIServiceError
            switch error {
            case .missingAPIKey:
                throw AIServiceError.missingAPIKey
            case .invalidURL:
                throw AIServiceError.invalidURL
            case .requestFailed(let statusCode):
                throw AIServiceError.requestFailed(statusCode: statusCode)
            case .requestFailedWithMessage(let statusCode, let message):
                throw AIServiceError.requestFailedWithMessage(statusCode: statusCode, message: message)
            case .networkError(let err):
                throw AIServiceError.networkError(err)
            case .timeout:
                throw AIServiceError.timeout
            case .invalidResponse:
                throw AIServiceError.invalidResponse
            case .decodingError(let err):
                throw AIServiceError.decodingError(err)
            case .notImplemented:
                throw AIServiceError.requestFailed(statusCode: nil)
            }
        }
    }
    
    enum AIServiceError: LocalizedError {
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
            case .missingAPIKey:
                return "API ключ не установлен. Пожалуйста, установите его в настройках."
            case .invalidURL:
                return "Неверный URL"
            case .requestFailed(let statusCode):
                if let code = statusCode {
                    switch code {
                    case 401:
                        return "Недействительный или просроченный API ключ (код: 401). Проверьте ключ в настройках."
                    case 402:
                        return """
                        Ошибка оплаты / недостаточно средств (код: 402).
                        Проверьте баланс и тариф в кабинете провайдера (например, OpenRouter или OpenAI), затем повторите запрос.
                        """
                    case 403:
                        return "Доступ к модели запрещён (код: 403). Проверьте права доступа и включён ли нужный провайдер."
                    case 404:
                        return "Модель или эндпоинт не найдены (код: 404). Проверьте ID модели в настройках."
                    case 429:
                        return "Превышен лимит запросов или квоты (код: 429). Подождите немного или уменьшите частоту запросов."
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
                case 403:
                    return "Доступ запрещён: \(message)"
                case 404:
                    return "Модель не найдена: \(message). Проверьте ID модели в настройках."
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
}
