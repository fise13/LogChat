//
//  LLMModel.swift
//  LogChat
//
//  Created by Виктор on 04.01.2026.
//

import Foundation
import SwiftUI

/// Represents an LLM model with metadata
struct LLMModel: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let provider: LLMProviderType
    let contextLength: Int?
    let description: String?
    let speedTier: SpeedTier
    
    enum SpeedTier: String, Codable {
        case fast = "fast"
        case balanced = "balanced"
        case smart = "smart"
        
        var displayName: String {
            switch self {
            case .fast: return "Fast"
            case .balanced: return "Balanced"
            case .smart: return "Smart"
            }
        }
    }
    
    var displayName: String {
        name
    }
    
    var providerIcon: String {
        provider.icon
    }
    
    var providerColor: String {
        provider.color
    }
    
    var providerColorValue: Color {
        switch provider {
        case .openAI: return .green
        case .anthropic: return .orange
        case .google: return .blue
        case .mistral: return .purple
        case .meta: return .indigo
        case .openRouter: return .gray
        }
    }
}

/// Provider type enumeration
enum LLMProviderType: String, Codable, CaseIterable, Identifiable {
    case openAI = "openai"
    case anthropic = "anthropic"
    case google = "google"
    case mistral = "mistral"
    case meta = "meta"
    case openRouter = "openrouter"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .openAI: return "OpenAI"
        case .anthropic: return "Anthropic"
        case .google: return "Google"
        case .mistral: return "Mistral"
        case .meta: return "Meta"
        case .openRouter: return "OpenRouter"
        }
    }
    
    var icon: String {
        switch self {
        case .openAI: return "sparkles"
        case .anthropic: return "brain.head.profile"
        case .google: return "circle.grid.cross.fill"
        case .mistral: return "wind"
        case .meta: return "cube"
        case .openRouter: return "network"
        }
    }
    
    var color: String {
        switch self {
        case .openAI: return "green"
        case .anthropic: return "orange"
        case .google: return "blue"
        case .mistral: return "purple"
        case .meta: return "indigo"
        case .openRouter: return "gray"
        }
    }
    
    var colorValue: Color {
        switch self {
        case .openAI: return .green
        case .anthropic: return .orange
        case .google: return .blue
        case .mistral: return .purple
        case .meta: return .indigo
        case .openRouter: return .gray
        }
    }
}

/// Predefined models for each provider
extension LLMModel {
    static let allModels: [LLMModel] = [
        // OpenAI
        LLMModel(id: "gpt-4.1", name: "GPT-4.1", provider: .openAI, contextLength: 128000, description: "Most capable", speedTier: .smart),
        LLMModel(id: "gpt-4o", name: "GPT-4o", provider: .openAI, contextLength: 128000, description: "Fast and smart", speedTier: .balanced),
        LLMModel(id: "gpt-4o-mini", name: "GPT-4o Mini", provider: .openAI, contextLength: 128000, description: "Fast and affordable", speedTier: .fast),
        LLMModel(id: "gpt-3.5-turbo", name: "GPT-3.5 Turbo", provider: .openAI, contextLength: 16385, description: "Fast and cheap", speedTier: .fast),
        
        // Anthropic
        LLMModel(id: "claude-3-opus", name: "Claude 3 Opus", provider: .anthropic, contextLength: 200000, description: "Most capable", speedTier: .smart),
        LLMModel(id: "claude-3-sonnet", name: "Claude 3 Sonnet", provider: .anthropic, contextLength: 200000, description: "Balanced", speedTier: .balanced),
        LLMModel(id: "claude-3-haiku", name: "Claude 3 Haiku", provider: .anthropic, contextLength: 200000, description: "Fast", speedTier: .fast),
        
        // Google
        LLMModel(id: "gemini-1.5-pro", name: "Gemini 1.5 Pro", provider: .google, contextLength: 1000000, description: "Long context", speedTier: .smart),
        LLMModel(id: "gemini-1.5-flash", name: "Gemini 1.5 Flash", provider: .google, contextLength: 1000000, description: "Fast", speedTier: .fast),
        
        // Mistral
        LLMModel(id: "mistral-large", name: "Mistral Large", provider: .mistral, contextLength: 32000, description: "Most capable", speedTier: .smart),
        LLMModel(id: "mistral-medium", name: "Mistral Medium", provider: .mistral, contextLength: 32000, description: "Balanced", speedTier: .balanced),
        LLMModel(id: "mistral-small", name: "Mistral Small", provider: .mistral, contextLength: 32000, description: "Fast", speedTier: .fast),
        
        // Meta
        LLMModel(id: "llama-3-70b", name: "Llama 3 70B", provider: .meta, contextLength: 8192, description: "Most capable", speedTier: .smart),
        LLMModel(id: "llama-3-8b", name: "Llama 3 8B", provider: .meta, contextLength: 8192, description: "Fast", speedTier: .fast),
        
        // OpenRouter (most popular models)
        LLMModel(id: "openai/gpt-4o", name: "GPT-4o (OpenRouter)", provider: .openRouter, contextLength: 128000, description: "Fast and smart", speedTier: .balanced),
        LLMModel(id: "openai/gpt-4o-mini", name: "GPT-4o Mini (OpenRouter)", provider: .openRouter, contextLength: 128000, description: "Fast and affordable", speedTier: .fast),
        LLMModel(id: "anthropic/claude-3.5-sonnet", name: "Claude 3.5 Sonnet (OpenRouter)", provider: .openRouter, contextLength: 200000, description: "Most capable", speedTier: .smart),
    ]
    
    static var defaultModel: LLMModel {
        // Default to OpenRouter GPT-4o Mini
        allModels.first { $0.provider == .openRouter && $0.id == "openai/gpt-4o-mini" } ?? 
        allModels.first { $0.provider == .openRouter } ?? 
        allModels.first!
    }
    
    static func models(for provider: LLMProviderType) -> [LLMModel] {
        allModels.filter { $0.provider == provider }
    }
}
