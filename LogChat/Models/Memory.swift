//
//  Memory.swift
//  LogChat
//
//  Created by Виктор on 04.01.2026.
//

import Foundation
import SwiftData

enum MemoryType: String, Codable, CaseIterable {
    case profile = "profile"      // Информация о пользователе
    case preference = "preference" // Предпочтения и стиль
    case project = "project"       // Проекты и задачи
    case fact = "fact"            // Отдельные факты
    
    var displayName: String {
        switch self {
        case .profile: return "Profile"
        case .preference: return "Preferences"
        case .project: return "Projects"
        case .fact: return "Facts"
        }
    }
    
    var icon: String {
        switch self {
        case .profile: return "person.fill"
        case .preference: return "heart.fill"
        case .project: return "folder.fill"
        case .fact: return "info.circle.fill"
        }
    }
}

/// Memory tier (short-term, mid-term, long-term)
enum MemoryTier: String, Codable, CaseIterable {
    case shortTerm = "short_term"  // Days to weeks
    case midTerm = "mid_term"      // Weeks to months
    case longTerm = "long_term"    // Months to years
    
    var displayName: String {
        switch self {
        case .shortTerm: return "Short-term"
        case .midTerm: return "Mid-term"
        case .longTerm: return "Long-term"
        }
    }
    
    var ttlDays: Int {
        switch self {
        case .shortTerm: return 7
        case .midTerm: return 90
        case .longTerm: return 365
        }
    }
    
    var importanceThreshold: Int {
        switch self {
        case .shortTerm: return 3
        case .midTerm: return 5
        case .longTerm: return 7
        }
    }
}

@Model
final class Workspace {
    var id: UUID
    var name: String
    var icon: String
    var color: String
    var createdAt: Date
    var isDefault: Bool
    
    init(
        id: UUID = UUID(),
        name: String,
        icon: String = "folder.fill",
        color: String = "blue",
        createdAt: Date = Date(),
        isDefault: Bool = false
    ) {
        self.id = id
        self.name = name
        self.icon = icon
        self.color = color
        self.createdAt = createdAt
        self.isDefault = isDefault
    }
}

@Model
final class MemoryItem {
    var id: UUID
    var type: String // MemoryType as String
    var key: String // Ключ для категоризации (например, "programming_language", "project_name")
    var content: String // Содержимое памяти
    var importance: Int // Важность (1-10)
    var tier: String? // MemoryTier as String (optional for backward compatibility)
    var workspaceId: UUID? // Workspace ID (optional for backward compatibility)
    var createdAt: Date
    var updatedAt: Date
    var lastUsedAt: Date? // Когда последний раз использовалась
    var usageCount: Int // Счетчик использования
    
    // Type-safe accessors
    var memoryType: MemoryType {
        get {
            MemoryType(rawValue: type) ?? .fact
        }
        set {
            type = newValue.rawValue
        }
    }
    
    var memoryTier: MemoryTier {
        get {
            if let tierStr = tier, let tier = MemoryTier(rawValue: tierStr) {
                return tier
            }
            // Auto-determine tier based on importance
            if importance >= 7 {
                return .longTerm
            } else if importance >= 5 {
                return .midTerm
            } else {
                return .shortTerm
            }
        }
        set {
            tier = newValue.rawValue
        }
    }
    
    init(
        id: UUID = UUID(),
        type: MemoryType,
        key: String,
        content: String,
        importance: Int = 5,
        tier: MemoryTier? = nil,
        workspaceId: UUID? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        lastUsedAt: Date? = nil,
        usageCount: Int = 0
    ) {
        self.id = id
        self.type = type.rawValue
        self.key = key
        self.content = content
        self.importance = importance
        self.tier = tier?.rawValue
        self.workspaceId = workspaceId
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.lastUsedAt = lastUsedAt
        self.usageCount = usageCount
    }
}

