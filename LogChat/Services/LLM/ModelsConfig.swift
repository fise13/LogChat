//
//  ModelsConfig.swift
//  LogChat
//
//  Created by Виктор on 04.01.2026.
//

import Foundation

/// Configuration for LLM models and their capabilities
struct ModelsConfig {
    let models: [LLMModel]
    let lastUpdated: Date
    let version: String
    
    static func load() -> ModelsConfig {
        // Try to load from remote config first (future enhancement)
        // For now, use built-in models
        return ModelsConfig(
            models: LLMModel.allModels,
            lastUpdated: Date(),
            version: "1.0"
        )
    }
    
    /// Get model by ID
    func getModel(id: String, provider: LLMProviderType) -> LLMModel? {
        return models.first { $0.id == id && $0.provider == provider }
    }
    
    /// Get models for provider
    func getModels(for provider: LLMProviderType) -> [LLMModel] {
        return models.filter { $0.provider == provider }
    }
    
    /// Get available models (filtered by configured providers)
    func getAvailableModels(configuredProviders: Set<LLMProviderType>) -> [LLMModel] {
        return models.filter { model in
            // Include if provider is configured
            if configuredProviders.contains(model.provider) {
                return true
            }
            // Always include OpenRouter as fallback
            if model.provider == .openRouter && configuredProviders.contains(.openRouter) {
                return true
            }
            return false
        }
    }
}

/// Model capabilities
struct ModelCapabilities {
    let supportsImages: Bool
    let supportsStreaming: Bool
    let supportsFunctionCalling: Bool
    let maxContextLength: Int
    let defaultMaxTokens: Int
    
    static func forModel(_ model: LLMModel) -> ModelCapabilities {
        let contextLength = model.contextLength ?? 4096
        
        switch model.provider {
        case .openAI:
            return ModelCapabilities(
                supportsImages: true,
                supportsStreaming: true,
                supportsFunctionCalling: true,
                maxContextLength: contextLength,
                defaultMaxTokens: 1024
            )
        case .anthropic:
            return ModelCapabilities(
                supportsImages: true,
                supportsStreaming: true,
                supportsFunctionCalling: false,
                maxContextLength: contextLength,
                defaultMaxTokens: 2048
            )
        case .google:
            return ModelCapabilities(
                supportsImages: true,
                supportsStreaming: true,
                supportsFunctionCalling: false,
                maxContextLength: contextLength,
                defaultMaxTokens: 2048
            )
        case .openRouter:
            // OpenRouter capabilities depend on underlying model
            // Default to conservative settings
            return ModelCapabilities(
                supportsImages: true,
                supportsStreaming: true,
                supportsFunctionCalling: false,
                maxContextLength: contextLength,
                defaultMaxTokens: 512
            )
        default:
            return ModelCapabilities(
                supportsImages: false,
                supportsStreaming: true,
                supportsFunctionCalling: false,
                maxContextLength: contextLength,
                defaultMaxTokens: 512
            )
        }
    }
}
