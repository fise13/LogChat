//
//  AnthropicProvider.swift
//  LogChat
//
//  Created by Виктор on 04.01.2026.
//

import Foundation

class AnthropicProvider: BaseLLMProvider {
    private let baseURL = "https://api.anthropic.com/v1/messages"
    
    init() {
        super.init(providerType: .anthropic)
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
        
        var messages: [[String: Any]] = []
        
        for (index, message) in request.messages.enumerated() {
            var messageDict: [String: Any] = [
                "role": message.role == .user ? "user" : "assistant",
                "content": message.content
            ]
            
            // Anthropic supports images in content array
            if let imageData = (index == request.messages.count - 1 && request.imageData != nil) ? request.imageData : message.imageData {
                let base64Image = imageData.base64EncodedString()
                messageDict["content"] = [
                    [
                        "type": "image",
                        "source": [
                            "type": "base64",
                            "media_type": "image/jpeg",
                            "data": base64Image
                        ]
                    ],
                    [
                        "type": "text",
                        "text": message.content
                    ]
                ]
            }
            
            messages.append(messageDict)
        }
        
        var requestBody: [String: Any] = [
            "model": request.model.id,
            "max_tokens": request.maxTokens ?? 4096,
            "system": systemPrompt,
            "messages": messages
        ]
        
        if let temperature = request.temperature {
            requestBody["temperature"] = temperature
        }
        
        guard let url = URL(string: baseURL) else {
            throw LLMProviderError.invalidURL
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        urlRequest.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        
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
                                  let type = json["type"] as? String,
                                  type == "content_block_delta",
                                  let delta = json["delta"] as? [String: Any],
                                  let text = delta["text"] as? String else {
                                continue
                            }
                            
                            continuation.yield(text)
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
