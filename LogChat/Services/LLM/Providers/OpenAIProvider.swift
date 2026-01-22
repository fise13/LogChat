//
//  OpenAIProvider.swift
//  LogChat
//
//  Created by Виктор on 04.01.2026.
//

import Foundation

class OpenAIProvider: BaseLLMProvider {
    private let baseURL = "https://api.openai.com/v1/chat/completions"
    
    init() {
        super.init(providerType: .openAI)
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
            
            if let imageData = imageToUse {
                let base64Image = imageData.base64EncodedString()
                messageDict["content"] = [
                    [
                        "type": "image_url",
                        "image_url": [
                            "url": "data:image/jpeg;base64,\(base64Image)"
                        ]
                    ],
                    [
                        "type": "text",
                        "text": message.content
                    ]
                ]
            } else {
                messageDict["content"] = message.content
            }
            
            requestMessages.append(messageDict)
        }
        
        var requestBody: [String: Any] = [
            "model": request.model.id,
            "messages": requestMessages,
            "stream": true
        ]
        
        if let temperature = request.temperature {
            requestBody["temperature"] = temperature
        }
        
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
        
        urlRequest.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 60
        configuration.timeoutIntervalForResource = 120
        let session = URLSession(configuration: configuration)
        
        let (asyncBytes, response) = try await session.bytes(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw LLMProviderError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            throw LLMProviderError.requestFailed(statusCode: httpResponse.statusCode)
        }
        
        return createStream(from: asyncBytes)
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
