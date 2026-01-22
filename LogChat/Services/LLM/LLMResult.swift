//
//  LLMResult.swift
//  LogChat
//
//  Created by Виктор on 04.01.2026.
//

import Foundation

/// Unified result structure for LLM responses
struct LLMResult {
    /// Streaming content chunks
    let stream: AsyncThrowingStream<String, Error>
    
    /// Final complete response (populated after stream completes)
    var finalContent: String?
    
    /// Token usage information
    var usage: TokenUsage?
    
    /// Model used for this request
    let model: LLMModel
    
    /// Request metadata
    let requestId: String
    let timestamp: Date
}

/// Token usage information
struct TokenUsage {
    let promptTokens: Int
    let completionTokens: Int
    let totalTokens: Int
    
    /// Cost estimation (if available)
    var estimatedCost: Double?
}

/// Retry configuration for LLM requests
struct RetryConfig {
    let maxRetries: Int
    let baseDelay: TimeInterval
    let maxDelay: TimeInterval
    let backoffMultiplier: Double
    
    static let `default` = RetryConfig(
        maxRetries: 3,
        baseDelay: 1.0,
        maxDelay: 10.0,
        backoffMultiplier: 2.0
    )
    
    static let aggressive = RetryConfig(
        maxRetries: 5,
        baseDelay: 0.5,
        maxDelay: 15.0,
        backoffMultiplier: 1.5
    )
    
    static let conservative = RetryConfig(
        maxRetries: 2,
        baseDelay: 2.0,
        maxDelay: 5.0,
        backoffMultiplier: 2.0
    )
    
    /// Calculate delay for retry attempt
    func delay(for attempt: Int) -> TimeInterval {
        let calculatedDelay = baseDelay * Foundation.pow(backoffMultiplier, Double(attempt - 1))
        return min(calculatedDelay, maxDelay)
    }
}

/// Token limits configuration per provider/model
struct TokenLimits {
    let maxTokens: Int
    let maxContextTokens: Int
    let defaultMaxTokens: Int
    
    static func forModel(_ model: LLMModel) -> TokenLimits {
        // Default safe limits
        let defaultMax = 512
        let maxContext = model.contextLength ?? 4096
        
        // Provider-specific adjustments
        switch model.provider {
        case .openRouter:
            // OpenRouter: be conservative for free/low-balance accounts
            return TokenLimits(
                maxTokens: min(2048, maxContext / 4),
                maxContextTokens: maxContext,
                defaultMaxTokens: defaultMax
            )
        case .openAI:
            return TokenLimits(
                maxTokens: min(4096, maxContext / 2),
                maxContextTokens: maxContext,
                defaultMaxTokens: 1024
            )
        case .anthropic:
            return TokenLimits(
                maxTokens: min(4096, maxContext / 2),
                maxContextTokens: maxContext,
                defaultMaxTokens: 2048
            )
        case .google:
            return TokenLimits(
                maxTokens: min(8192, maxContext / 2),
                maxContextTokens: maxContext,
                defaultMaxTokens: 2048
            )
        default:
            return TokenLimits(
                maxTokens: min(2048, maxContext / 4),
                maxContextTokens: maxContext,
                defaultMaxTokens: defaultMax
            )
        }
    }
    
    /// Apply safe limits to requested maxTokens
    func applyLimit(_ requested: Int?) -> Int {
        guard let requested = requested else {
            return defaultMaxTokens
        }
        return min(requested, maxTokens)
    }
}
