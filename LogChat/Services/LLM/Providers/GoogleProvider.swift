//
//  GoogleProvider.swift
//  LogChat
//
//  Created by Виктор on 04.01.2026.
//

import Foundation

class GoogleProvider: BaseLLMProvider {
    private let baseURL = "https://generativelanguage.googleapis.com/v1beta/models"
    
    init() {
        super.init(providerType: .google)
    }
    
    override func sendMessage(_ request: LLMRequest) async throws -> AsyncThrowingStream<String, Error> {
        guard let apiKey = getAPIKey(), !apiKey.isEmpty else {
            throw LLMProviderError.missingAPIKey
        }
        
        // Google uses model name directly in the URL
        let modelName = request.model.id
        guard let url = URL(string: "\(baseURL)/\(modelName):streamGenerateContent?key=\(apiKey)") else {
            throw LLMProviderError.invalidURL
        }
        
        let systemPrompt = buildSystemPrompt(
            mode: request.mode,
            memoryContext: request.memoryContext,
            webSearchContext: request.webSearchContext
        )
        
        // Build content parts for messages
        var contents: [[String: Any]] = []
        
        // Add system instruction if available
        var systemInstruction: [String: Any]? = nil
        if !systemPrompt.isEmpty {
            systemInstruction = [
                "parts": [
                    ["text": systemPrompt]
                ]
            ]
        }
        
        // Process messages
        for (index, message) in request.messages.enumerated() {
            var parts: [[String: Any]] = []
            
            // Add image if present
            let imageToUse = (index == request.messages.count - 1 && request.imageData != nil) ? request.imageData : message.imageData
            if let imageData = imageToUse {
                let base64Image = imageData.base64EncodedString()
                parts.append([
                    "inline_data": [
                        "mime_type": "image/jpeg",
                        "data": base64Image
                    ]
                ])
            }
            
            // Add text content
            if !message.content.isEmpty {
                parts.append([
                    "text": message.content
                ])
            }
            
            if !parts.isEmpty {
                contents.append([
                    "role": message.role == .user ? "user" : "model",
                    "parts": parts
                ])
            }
        }
        
        var requestBody: [String: Any] = [
            "contents": contents
        ]
        
        if let systemInstruction = systemInstruction {
            requestBody["system_instruction"] = systemInstruction
        }
        
        if let temperature = request.temperature {
            requestBody["generationConfig"] = [
                "temperature": temperature
            ]
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
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
                    var buffer = ""
                    for try await line in asyncBytes.lines {
                        // Google uses Server-Sent Events format
                        if line.hasPrefix("data: ") {
                            let jsonString = String(line.dropFirst(6))
                            
                            if jsonString == "[DONE]" {
                                continuation.finish()
                                return
                            }
                            
                            guard let data = jsonString.data(using: .utf8),
                                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                                continue
                            }
                            
                            // Check for candidates array
                            if let candidates = json["candidates"] as? [[String: Any]],
                               let firstCandidate = candidates.first,
                               let content = firstCandidate["content"] as? [String: Any],
                               let parts = content["parts"] as? [[String: Any]],
                               let firstPart = parts.first,
                               let text = firstPart["text"] as? String {
                                continuation.yield(text)
                            }
                        } else if !line.isEmpty {
                            // Handle non-SSE lines (shouldn't happen with proper SSE, but handle gracefully)
                            buffer += line
                        }
                    }
                    
                    // Process remaining buffer if any
                    if !buffer.isEmpty {
                        if let data = buffer.data(using: .utf8),
                           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                           let candidates = json["candidates"] as? [[String: Any]],
                           let firstCandidate = candidates.first,
                           let content = firstCandidate["content"] as? [String: Any],
                           let parts = content["parts"] as? [[String: Any]],
                           let firstPart = parts.first,
                           let text = firstPart["text"] as? String {
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
