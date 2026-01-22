//
//  LLMService.swift
//  LogChat
//
//  Created by Виктор on 04.01.2026.
//

import Foundation

/// Unified LLM service that routes requests to appropriate providers
@MainActor
class LLMService {
    static let shared = LLMService()
    
    private var providers: [LLMProviderType: LLMProvider] = [:]
    private let retryService = LLMRetryService.shared
    private var modelsConfig: ModelsConfig
    
    private init() {
        // Initialize all providers
        providers[.openAI] = OpenAIProvider()
        providers[.anthropic] = AnthropicProvider()
        providers[.google] = GoogleProvider()
        providers[.openRouter] = OpenRouterProvider()
        // Add other providers as needed
        
        // Load models configuration
        modelsConfig = ModelsConfig.load()
    }
    
    /// Reload models configuration (for future remote config support)
    func reloadModelsConfig() {
        modelsConfig = ModelsConfig.load()
    }
    
    /// Get provider for a model
    func getProvider(for model: LLMModel) -> LLMProvider? {
        // If model provider is OpenRouter, use OpenRouter provider
        // Otherwise use the model's provider
        if model.provider == .openRouter {
            return providers[.openRouter]
        }
        
        // Check if direct provider exists and is configured
        if let provider = providers[model.provider], provider.isConfigured() {
            return provider
        }
        
        // Fallback to OpenRouter if available
        return providers[.openRouter]
    }
    
    /// Send message using specified model (legacy - returns stream directly)
    func sendMessage(_ request: LLMRequest) async throws -> AsyncThrowingStream<String, Error> {
        guard let provider = getProvider(for: request.model) else {
            throw LLMProviderError.missingAPIKey
        }
        
        guard provider.isConfigured() else {
            throw LLMProviderError.missingAPIKey
        }
        
        // Apply token limits
        let tokenLimits = TokenLimits.forModel(request.model)
        let safeMaxTokens = tokenLimits.applyLimit(request.maxTokens)
        
        // Create request with safe limits
        let safeRequest = LLMRequest(
            messages: request.messages,
            model: request.model,
            mode: request.mode,
            imageData: request.imageData,
            memoryContext: request.memoryContext,
            webSearchContext: request.webSearchContext,
            temperature: request.temperature,
            maxTokens: safeMaxTokens
        )
        
        // Execute with retry logic
        return try await retryService.executeWithRetry(
            config: .default,
            operation: {
                try await provider.sendMessage(safeRequest)
            },
            shouldRetry: { [weak self] error in
                self?.retryService.isRetryable(error) ?? false
            }
        )
    }
    
    /// Send message and return unified LLMResult
    func sendMessageWithResult(_ request: LLMRequest) async throws -> LLMResult {
        guard let provider = getProvider(for: request.model) else {
            throw LLMProviderError.missingAPIKey
        }
        
        guard provider.isConfigured() else {
            throw LLMProviderError.missingAPIKey
        }
        
        // Apply token limits
        let tokenLimits = TokenLimits.forModel(request.model)
        let safeMaxTokens = tokenLimits.applyLimit(request.maxTokens)
        
        // Create request with safe limits
        let safeRequest = LLMRequest(
            messages: request.messages,
            model: request.model,
            mode: request.mode,
            imageData: request.imageData,
            memoryContext: request.memoryContext,
            webSearchContext: request.webSearchContext,
            temperature: request.temperature,
            maxTokens: safeMaxTokens
        )
        
        let requestId = UUID().uuidString
        let timestamp = Date()
        
        // Execute with retry logic
        let stream = try await retryService.executeWithRetry(
            config: .default,
            operation: {
                try await provider.sendMessage(safeRequest)
            },
            shouldRetry: { [weak self] error in
                self?.retryService.isRetryable(error) ?? false
            }
        )
        
        return LLMResult(
            stream: stream,
            finalContent: nil,
            usage: nil,
            model: request.model,
            requestId: requestId,
            timestamp: timestamp
        )
    }
    
    /// Get API key for provider
    func getAPIKey(for providerType: LLMProviderType) -> String? {
        providers[providerType]?.getAPIKey()
    }
    
    /// Set API key for provider
    func setAPIKey(_ key: String, for providerType: LLMProviderType) {
        providers[providerType]?.setAPIKey(key)
    }
    
    /// Check if provider is configured
    func isProviderConfigured(_ providerType: LLMProviderType) -> Bool {
        providers[providerType]?.isConfigured() ?? false
    }
    
    /// Get all available models (filtered by configured providers)
    func getAvailableModels() -> [LLMModel] {
        // Get configured providers
        let configuredProviders = Set(providers.compactMap { providerType, provider in
            provider.isConfigured() ? providerType : nil
        })
        
        // Get models from config
        var availableModels = modelsConfig.getAvailableModels(configuredProviders: configuredProviders)
        
        // Add custom models (only if provider is configured)
        let customModels = CustomModelService.shared.getCustomModels()
        for model in customModels {
            if let provider = providers[model.provider], provider.isConfigured() {
                // Don't add duplicates
                if !availableModels.contains(where: { $0.id == model.id && $0.provider == model.provider }) {
                    availableModels.append(model)
                }
            }
        }
        
        return availableModels
    }
    
    /// Get model capabilities
    func getCapabilities(for model: LLMModel) -> ModelCapabilities {
        return ModelCapabilities.forModel(model)
    }
}
