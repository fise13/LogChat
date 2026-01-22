//
//  Chat.swift
//  LogChat
//
//  Created by Виктор on 04.01.2026.
//

import Foundation
import SwiftData

@Model
final class Chat {
    var id: UUID
    var title: String
    var modeRawValue: String // Храним как String для SwiftData, но используем computed property
    var modelId: String? // ID выбранной модели LLM
    var modelProviderRawValue: String? // Provider выбранной модели
    var createdAt: Date
    var updatedAt: Date
    var tags: [String] // Метки и теги
    var isPinned: Bool // Закрепление
    var summary: String? // Суммаризация
    var tokenCount: Int // Счетчик токенов
    var isIncognito: Bool // Режим инкогнито
    @Relationship(deleteRule: .cascade) var messages: [ChatMessage]?
    
    // Type-safe accessor
    var mode: AIMode {
        get {
            AIMode(rawValue: modeRawValue) ?? .daily
        }
        set {
            modeRawValue = newValue.rawValue
        }
    }
    
    // Selected model accessor
    var selectedModel: LLMModel? {
        get {
            guard let modelId = modelId,
                  let providerRaw = modelProviderRawValue,
                  let provider = LLMProviderType(rawValue: providerRaw) else {
                return nil
            }
            return LLMModel.allModels.first { $0.id == modelId && $0.provider == provider }
        }
        set {
            modelId = newValue?.id
            modelProviderRawValue = newValue?.provider.rawValue
        }
    }
    
    init(id: UUID = UUID(), title: String, mode: AIMode, createdAt: Date = Date(), updatedAt: Date = Date(), tags: [String] = [], isPinned: Bool = false, summary: String? = nil, tokenCount: Int = 0, isIncognito: Bool = false, model: LLMModel? = nil) {
        self.id = id
        self.title = title
        self.modeRawValue = mode.rawValue
        self.modelId = model?.id
        self.modelProviderRawValue = model?.provider.rawValue
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.tags = tags
        self.isPinned = isPinned
        self.summary = summary
        self.tokenCount = tokenCount
        self.isIncognito = isIncognito
        self.messages = []
    }
}

@Model
final class ChatMessage {
    var id: UUID
    var content: String
    var roleRawValue: String // Храним как String для SwiftData, но используем computed property
    var timestamp: Date
    var imageData: Data?
    var isPinned: Bool // Закрепление важных сообщений
    var tokenCount: Int // Токены для этого сообщения
    var language: String? // Детекция языка кода
    var chat: Chat?
    
    // Type-safe accessor
    var role: MessageRole {
        get {
            MessageRole(rawValue: roleRawValue) ?? .user
        }
        set {
            roleRawValue = newValue.rawValue
        }
    }
    
    init(id: UUID = UUID(), content: String, role: MessageRole, timestamp: Date = Date(), imageData: Data? = nil, isPinned: Bool = false, tokenCount: Int = 0, language: String? = nil) {
        self.id = id
        self.content = content
        self.roleRawValue = role.rawValue
        self.timestamp = timestamp
        self.imageData = imageData
        self.isPinned = isPinned
        self.tokenCount = tokenCount
        self.language = language
    }
}

// Модель для кастомных режимов
@Model
final class CustomMode {
    var id: UUID
    var name: String
    var systemPrompt: String
    var icon: String
    var color: String
    var createdAt: Date
    
    init(id: UUID = UUID(), name: String, systemPrompt: String, icon: String, color: String, createdAt: Date = Date()) {
        self.id = id
        self.name = name
        self.systemPrompt = systemPrompt
        self.icon = icon
        self.color = color
        self.createdAt = createdAt
    }
}

// Модель для шаблонов запросов
@Model
final class QueryTemplate {
    var id: UUID
    var title: String
    var content: String
    var mode: String
    var category: String
    var usageCount: Int
    var createdAt: Date
    
    init(id: UUID = UUID(), title: String, content: String, mode: String, category: String = "general", usageCount: Int = 0, createdAt: Date = Date()) {
        self.id = id
        self.title = title
        self.content = content
        self.mode = mode
        self.category = category
        self.usageCount = usageCount
        self.createdAt = createdAt
    }
}

// Модель для избранных ответов
@Model
final class FavoriteResponse {
    var id: UUID
    var content: String
    var chatId: UUID?
    var messageId: UUID?
    var createdAt: Date
    
    init(id: UUID = UUID(), content: String, chatId: UUID? = nil, messageId: UUID? = nil, createdAt: Date = Date()) {
        self.id = id
        self.content = content
        self.chatId = chatId
        self.messageId = messageId
        self.createdAt = createdAt
    }
}

// Модель для статистики
@Model
final class UsageStatistics {
    var id: UUID
    var date: Date
    var mode: String
    var messageCount: Int
    var tokenCount: Int
    var sessionDuration: TimeInterval
    
    init(id: UUID = UUID(), date: Date = Date(), mode: String, messageCount: Int = 0, tokenCount: Int = 0, sessionDuration: TimeInterval = 0) {
        self.id = id
        self.date = date
        self.mode = mode
        self.messageCount = messageCount
        self.tokenCount = tokenCount
        self.sessionDuration = sessionDuration
    }
}
