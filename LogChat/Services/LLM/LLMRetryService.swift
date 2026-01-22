//
//  LLMRetryService.swift
//  LogChat
//
//  Created by Виктор on 04.01.2026.
//

import Foundation

/// Centralized retry logic for LLM requests
@MainActor
class LLMRetryService {
    static let shared = LLMRetryService()
    
    private init() {}
    
    /// Execute request with retry logic
    func executeWithRetry<T>(
        config: RetryConfig = .default,
        operation: @escaping () async throws -> T,
        shouldRetry: @escaping (Error) -> Bool = { _ in true }
    ) async throws -> T {
        var lastError: Error?
        
        for attempt in 1...config.maxRetries {
            do {
                return try await operation()
            } catch let error {
                lastError = error
                
                // Check if we should retry this error
                guard shouldRetry(error) else {
                    throw error
                }
                
                // Don't retry on last attempt
                guard attempt < config.maxRetries else {
                    break
                }
                
                // Calculate delay
                let delay = config.delay(for: attempt)
                
                // Log retry attempt
                print("🔄 LLM retry attempt \(attempt)/\(config.maxRetries) after \(String(format: "%.1f", delay))s")
                
                // Wait before retry
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
        }
        
        // All retries exhausted
        throw lastError ?? LLMProviderError.networkError(NSError(domain: "LLMRetryService", code: -1))
    }
    
    /// Determine if error is retryable
    func isRetryable(_ error: Error) -> Bool {
        if let llmError = error as? LLMProviderError {
            switch llmError {
            case .networkError, .timeout, .invalidResponse:
                return true
            case .requestFailed(let statusCode):
                // Retry on 429 (rate limit) and 5xx errors
                if let code = statusCode {
                    return code == 429 || (code >= 500 && code < 600)
                }
                return false
            case .requestFailedWithMessage(let statusCode, _):
                return statusCode == 429 || (statusCode >= 500 && statusCode < 600)
            default:
                return false
            }
        }
        
        // Check for network-related errors
        if let urlError = error as? URLError {
            switch urlError.code {
            case .timedOut, .networkConnectionLost, .notConnectedToInternet,
                 .cannotConnectToHost, .cannotFindHost, .dnsLookupFailed:
                return true
            default:
                return false
            }
        }
        
        return false
    }
    
    /// Get retry config based on error type
    func retryConfig(for error: Error) -> RetryConfig {
        if let llmError = error as? LLMProviderError {
            switch llmError {
            case .requestFailed(let statusCode):
                if let code = statusCode, code == 429 {
                    // Rate limit - use aggressive retry
                    return .aggressive
                }
            case .requestFailedWithMessage(let statusCode, _):
                if statusCode == 429 {
                    return .aggressive
                }
            default:
                break
            }
        }
        
        return .default
    }
}
