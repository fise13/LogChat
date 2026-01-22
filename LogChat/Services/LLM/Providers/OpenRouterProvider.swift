//
//  OpenRouterProvider.swift
//  LogChat
//
//  Created by Виктор on 04.01.2026.
//

import Foundation

class OpenRouterProvider: BaseLLMProvider {
    private let baseURL = "https://openrouter.ai/api/v1/chat/completions"
    
    init() {
        super.init(providerType: .openRouter)
        // Migrate old UserDefaults keys to Keychain
        migrateOldAPIKey()
    }
    
    private func migrateOldAPIKey() {
        // Check if key exists in UserDefaults but not in Keychain
        if let oldKey = UserDefaults.standard.string(forKey: "openRouterAPIKey") ?? UserDefaults.standard.string(forKey: "openrouterAPIKey"),
           getAPIKey() == nil {
            // Migrate to Keychain
            setAPIKey(oldKey)
            // Clean up old keys
            UserDefaults.standard.removeObject(forKey: "openRouterAPIKey")
            UserDefaults.standard.removeObject(forKey: "openrouterAPIKey")
        }
    }
    
    override func getAPIKey() -> String? {
        // Try Keychain first (from BaseLLMProvider)
        if let key = super.getAPIKey() {
            return key
        }
        // Backward compatibility with old key name
        return UserDefaults.standard.string(forKey: "openRouterAPIKey") ?? UserDefaults.standard.string(forKey: "openrouterAPIKey")
    }
    
    override func setAPIKey(_ key: String) {
        // Save to Keychain (via BaseLLMProvider)
        super.setAPIKey(key)
        // Also save to UserDefaults for backward compatibility (will be cleaned up on next migration)
        UserDefaults.standard.set(key, forKey: "openRouterAPIKey")
        UserDefaults.standard.set(key, forKey: "openrouterAPIKey")
    }
    
    override func sendMessage(_ request: LLMRequest) async throws -> AsyncThrowingStream<String, Error> {
        guard let apiKey = getAPIKey(), !apiKey.isEmpty else {
            throw LLMProviderError.missingAPIKey
        }
        
        let systemPrompt = buildSystemPrompt(
            mode: request.mode,
            memoryContext: request.memoryContext,
            webSearchContext: request.webSearchContext
        )
        
        var requestMessages: [[String: Any]] = [
            ["role": "system", "content": systemPrompt]
        ]
        
        // Add conversation messages
        for (index, message) in request.messages.enumerated() {
            var messageDict: [String: Any] = [
                "role": message.role.rawValue
            ]
            
            let imageToUse = (index == request.messages.count - 1 && request.imageData != nil) ? request.imageData : message.imageData
            
            var contentArray: [[String: Any]] = []
            
            if let imageData = imageToUse {
                let base64Image = imageData.base64EncodedString()
                contentArray.append([
                    "type": "image_url",
                    "image_url": [
                        "url": "data:image/jpeg;base64,\(base64Image)"
                    ]
                ])
            }
            
            if !message.content.isEmpty {
                contentArray.append([
                    "type": "text",
                    "text": message.content
                ])
            }
            
            if contentArray.count == 1, let first = contentArray.first, first["type"] as? String == "text" {
                messageDict["content"] = first["text"] as? String ?? message.content
            } else {
                messageDict["content"] = contentArray
            }
            
            requestMessages.append(messageDict)
        }
        
        // OpenRouter model format: provider/model-id
        let modelId = request.model.provider == .openRouter 
            ? request.model.id 
            : "\(request.model.provider.rawValue)/\(request.model.id)"
        
        var requestBody: [String: Any] = [
            "model": modelId,
            "messages": requestMessages,
            "stream": true
        ]
        
        if let temperature = request.temperature {
            requestBody["temperature"] = temperature
        }
        
        // max_tokens is now handled centrally in LLMService with TokenLimits
        if let maxTokens = request.maxTokens {
            requestBody["max_tokens"] = maxTokens
        }
        
        guard let url = URL(string: baseURL) else {
            throw LLMProviderError.invalidURL
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue("LogChat/1.0", forHTTPHeaderField: "HTTP-Referer")
        urlRequest.setValue("LogChat", forHTTPHeaderField: "X-Title")
        
        urlRequest.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 60
        configuration.timeoutIntervalForResource = 120
        let session = URLSession(configuration: configuration)
        
        let maxRetries = 3
        var lastError: Error?
        
        for attempt in 1...maxRetries {
            do {
                let (asyncBytes, response) = try await session.bytes(for: urlRequest)
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw LLMProviderError.invalidResponse
                }
                
                guard (200...299).contains(httpResponse.statusCode) else {
                    // Read error response body for better error messages
                    var errorMessage: String?
                    do {
                        var errorData = Data()
                        for try await byte in asyncBytes {
                            errorData.append(byte)
                        }
                        if let errorJson = try? JSONSerialization.jsonObject(with: errorData) as? [String: Any],
                           let error = errorJson["error"] as? [String: Any],
                           let message = error["message"] as? String {
                            errorMessage = message
                        } else if let errorString = String(data: errorData, encoding: .utf8), !errorString.isEmpty {
                            errorMessage = errorString
                        }
                    } catch {
                        // Ignore parsing errors, use status code
                    }
                    
                    // Create detailed error
                    if let message = errorMessage {
                        throw LLMProviderError.requestFailedWithMessage(statusCode: httpResponse.statusCode, message: message)
                    } else {
                        throw LLMProviderError.requestFailed(statusCode: httpResponse.statusCode)
                    }
                }
                
                return createStream(from: asyncBytes)
                
            } catch let error as URLError {
                lastError = error
                if error.code == .timedOut || error.code == .networkConnectionLost {
                    if attempt < maxRetries {
                        try? await Task.sleep(nanoseconds: UInt64(pow(2.0, Double(attempt)) * 1_000_000_000))
                        continue
                    }
                    throw LLMProviderError.timeout
                }
                throw LLMProviderError.networkError(error)
            } catch {
                lastError = error
                if attempt < maxRetries {
                    try? await Task.sleep(nanoseconds: UInt64(pow(2.0, Double(attempt)) * 1_000_000_000))
                    continue
                }
                throw error
            }
        }
        
        throw lastError ?? LLMProviderError.requestFailed(statusCode: nil)
    }
    
    private func createStream(from asyncBytes: URLSession.AsyncBytes) -> AsyncThrowingStream<String, Error> {
        return AsyncThrowingStream { continuation in
            Task {
                do {
                    for try await line in asyncBytes.lines {
                        if line.hasPrefix("data: ") {
                            let jsonString = String(line.dropFirst(6))
                            if jsonString == "[DONE]" {
                                continuation.finish()
                                return
                            }
                            
                            guard let data = jsonString.data(using: .utf8),
                                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                                  let choices = json["choices"] as? [[String: Any]],
                                  let firstChoice = choices.first,
                                  let delta = firstChoice["delta"] as? [String: Any],
                                  let content = delta["content"] as? String else {
                                continue
                            }
                            
                            continuation.yield(content)
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}
